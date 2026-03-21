// deno-lint-ignore-file no-explicit-any
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

type Mode = "notification" | "retry";

type PushRequest = {
  notification_id?: string;
  mode?: Mode;
  max_retry_items?: number;
};

type DispatchRow = {
  notification_id: string;
  recipient_profile_id: string;
  fcm_token: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
const FIREBASE_PRIVATE_KEY = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");
const FUNCTION_AUTH_TOKEN = Deno.env.get("FUNCTION_AUTH_TOKEN") ?? "";

const SEND_CONCURRENCY = 8;
const RETRY_BATCH_LIMIT = 200;
const RETRY_MAX_ATTEMPTS = 5;

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    if (!isRequestAuthorized(request)) {
      return json({ error: "Unauthorized" }, 401);
    }

    validateEnv();

    const payload = (await request.json().catch(() => ({}))) as PushRequest;
    const mode: Mode = payload.mode === "retry" ? "retry" : "notification";

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    const oauthToken = await getGoogleAccessToken();

    if (mode === "retry") {
      const maxRetryItems = clamp(payload.max_retry_items ?? RETRY_BATCH_LIMIT, 1, RETRY_BATCH_LIMIT);
      const result = await processRetryQueue({
        supabase,
        oauthToken,
        maxItems: maxRetryItems,
      });
      return json(result);
    }

    const notificationId = payload.notification_id?.trim();
    if (!notificationId) {
      return json({ error: "notification_id is required for notification mode" }, 400);
    }

    const result = await processNotification({
      supabase,
      oauthToken,
      notificationId,
    });

    return json(result);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});

function isRequestAuthorized(request: Request): boolean {
  if (!FUNCTION_AUTH_TOKEN) {
    return false;
  }

  const authHeader = request.headers.get("authorization") ?? "";
  const bearerPrefix = "Bearer ";
  if (!authHeader.startsWith(bearerPrefix)) {
    return false;
  }

  const token = authHeader.substring(bearerPrefix.length).trim();
  return token === FUNCTION_AUTH_TOKEN;
}

function validateEnv(): void {
  const missing = [
    ["SUPABASE_URL", SUPABASE_URL],
    ["SUPABASE_SERVICE_ROLE_KEY", SUPABASE_SERVICE_ROLE_KEY],
    ["FIREBASE_PROJECT_ID", FIREBASE_PROJECT_ID],
    ["FIREBASE_CLIENT_EMAIL", FIREBASE_CLIENT_EMAIL],
    ["FIREBASE_PRIVATE_KEY", FIREBASE_PRIVATE_KEY],
    ["FUNCTION_AUTH_TOKEN", FUNCTION_AUTH_TOKEN],
  ]
    .filter(([, value]) => !value)
    .map(([name]) => name);

  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(", ")}`);
  }
}

async function processNotification(args: {
  supabase: SupabaseClient;
  oauthToken: string;
  notificationId: string;
}) {
  const { supabase, oauthToken, notificationId } = args;

  const { data: notification, error: notificationError } = await supabase
    .from("notifications")
    .select("id, title, body, data, type")
    .eq("id", notificationId)
    .maybeSingle();

  if (notificationError) {
    throw new Error(`Failed to load notification: ${notificationError.message}`);
  }

  if (!notification) {
    return {
      mode: "notification",
      notification_id: notificationId,
      processed: 0,
      skipped: true,
      reason: "notification_not_found",
    };
  }

  const dispatchRows = await getDispatchRowsForNotification(supabase, notificationId);
  if (dispatchRows.length === 0) {
    return {
      mode: "notification",
      notification_id: notificationId,
      processed: 0,
      skipped: true,
      reason: "no_active_tokens",
    };
  }

  const sendResults = await sendToDispatchRows({
    supabase,
    oauthToken,
    notification,
    dispatchRows,
    mode: "notification",
  });

  return {
    mode: "notification",
    notification_id: notificationId,
    ...sendResults,
  };
}

async function processRetryQueue(args: {
  supabase: SupabaseClient;
  oauthToken: string;
  maxItems: number;
}) {
  const { supabase, oauthToken, maxItems } = args;

  const nowIso = new Date().toISOString();

  const { data: queueRows, error: queueError } = await supabase
    .from("notification_push_retry_queue")
    .select("id, notification_id, recipient_profile_id, fcm_token, attempts, payload")
    .is("processed_at", null)
    .lte("next_attempt_at", nowIso)
    .order("next_attempt_at", { ascending: true })
    .limit(maxItems);

  if (queueError) {
    throw new Error(`Failed to load retry queue: ${queueError.message}`);
  }

  if (!queueRows || queueRows.length === 0) {
    return {
      mode: "retry",
      processed: 0,
      sent_success: 0,
      sent_failed: 0,
      queued_retry: 0,
      invalid_tokens: 0,
      skipped: true,
      reason: "no_due_retries",
    };
  }

  const notificationIds = Array.from(
    new Set(queueRows.map((row) => row.notification_id as string).filter(Boolean)),
  );

  const { data: notifications, error: notificationsError } = await supabase
    .from("notifications")
    .select("id, title, body, data, type")
    .in("id", notificationIds);

  if (notificationsError) {
    throw new Error(`Failed to load retry notifications: ${notificationsError.message}`);
  }

  const notificationMap = new Map<string, any>();
  for (const n of notifications ?? []) {
    notificationMap.set(n.id as string, n);
  }

  const dispatchRows: DispatchRow[] = [];
  for (const row of queueRows) {
    const notificationId = row.notification_id as string;
    if (!notificationMap.has(notificationId)) {
      await markRetryProcessed(supabase, row.id as string);
      continue;
    }

    dispatchRows.push({
      notification_id: notificationId,
      recipient_profile_id: row.recipient_profile_id as string,
      fcm_token: row.fcm_token as string,
    });
  }

  if (dispatchRows.length === 0) {
    return {
      mode: "retry",
      processed: 0,
      sent_success: 0,
      sent_failed: 0,
      queued_retry: 0,
      invalid_tokens: 0,
      skipped: true,
      reason: "retry_items_not_dispatchable",
    };
  }

  const sendResults = await sendToDispatchRows({
    supabase,
    oauthToken,
    notificationMap,
    dispatchRows,
    mode: "retry",
  });

  return {
    mode: "retry",
    processed: sendResults.processed,
    sent_success: sendResults.sent_success,
    sent_failed: sendResults.sent_failed,
    queued_retry: sendResults.queued_retry,
    invalid_tokens: sendResults.invalid_tokens,
  };
}

async function getDispatchRowsForNotification(
  supabase: SupabaseClient,
  notificationId: string,
): Promise<DispatchRow[]> {
  const { data: recipients, error: recipientsError } = await supabase
    .from("notification_recipients")
    .select("profile_id")
    .eq("notification_id", notificationId);

  if (recipientsError) {
    throw new Error(`Failed to load recipients: ${recipientsError.message}`);
  }

  const profileIds = Array.from(
    new Set((recipients ?? []).map((item) => item.profile_id as string).filter(Boolean)),
  );

  if (profileIds.length === 0) {
    return [];
  }

  const { data: tokens, error: tokensError } = await supabase
    .from("device_tokens")
    .select("profile_id, fcm_token")
    .in("profile_id", profileIds)
    .eq("is_active", true);

  if (tokensError) {
    throw new Error(`Failed to load device tokens: ${tokensError.message}`);
  }

  const dedupe = new Set<string>();
  const rows: DispatchRow[] = [];
  for (const tokenRow of tokens ?? []) {
    const profileId = tokenRow.profile_id as string;
    const fcmToken = (tokenRow.fcm_token as string | null)?.trim() ?? "";
    if (!profileId || !fcmToken) {
      continue;
    }

    const key = `${notificationId}|${profileId}|${fcmToken}`;
    if (dedupe.has(key)) {
      continue;
    }
    dedupe.add(key);

    rows.push({
      notification_id: notificationId,
      recipient_profile_id: profileId,
      fcm_token: fcmToken,
    });
  }

  return rows;
}

async function sendToDispatchRows(args: {
  supabase: SupabaseClient;
  oauthToken: string;
  notification?: any;
  notificationMap?: Map<string, any>;
  dispatchRows: DispatchRow[];
  mode: Mode;
}) {
  const { supabase, oauthToken, notification, notificationMap, dispatchRows, mode } = args;

  const tasks = dispatchRows.map((row) => async () => {
    const sourceNotification =
      notification ?? notificationMap?.get(row.notification_id) ?? null;

    if (!sourceNotification) {
      return {
        ok: false,
        retryable: false,
        invalidToken: false,
        row,
        errorCode: "notification_missing",
        errorMessage: "Notification not found",
      };
    }

    const payload = buildFcmPayload({
      token: row.fcm_token,
      notification: sourceNotification,
      recipientProfileId: row.recipient_profile_id,
    });

    return await sendSingleMessage({
      oauthToken,
      payload,
      row,
    });
  });

  const results = await runWithConcurrency(tasks, SEND_CONCURRENCY);

  let sentSuccess = 0;
  let sentFailed = 0;
  let queuedRetry = 0;
  let invalidTokens = 0;

  const processedKeys = new Set<string>();

  for (const result of results) {
    const row = result.row;
    const key = `${row.notification_id}|${row.recipient_profile_id}|${row.fcm_token}`;
    processedKeys.add(key);

    if (result.ok) {
      sentSuccess += 1;
      await upsertDelivery(supabase, {
        ...row,
        status: "success",
        attemptCountIncrement: 1,
        providerMessageId: result.providerMessageId,
        providerResponse: result.responseBody,
        sentAt: new Date().toISOString(),
      });

      await clearRetryQueueEntry(supabase, row);
      continue;
    }

    sentFailed += 1;

    if (result.invalidToken) {
      invalidTokens += 1;
      await deactivateToken(supabase, row.fcm_token);
      await upsertDelivery(supabase, {
        ...row,
        status: "invalid_token",
        attemptCountIncrement: 1,
        errorCode: result.errorCode,
        errorMessage: result.errorMessage,
        providerResponse: result.responseBody,
      });
      await clearRetryQueueEntry(supabase, row);
      continue;
    }

    if (result.retryable) {
      queuedRetry += 1;
      const attempts = await incrementRetryQueue(supabase, row, {
        errorCode: result.errorCode,
        errorMessage: result.errorMessage,
        httpStatus: result.httpStatus,
      });
      const status = attempts >= RETRY_MAX_ATTEMPTS ? "failed" : "retry_queued";

      await upsertDelivery(supabase, {
        ...row,
        status,
        attemptCountIncrement: 1,
        errorCode: result.errorCode,
        errorMessage: result.errorMessage,
        providerResponse: result.responseBody,
      });
      continue;
    }

    await upsertDelivery(supabase, {
      ...row,
      status: "failed",
      attemptCountIncrement: 1,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage,
      providerResponse: result.responseBody,
    });
    await clearRetryQueueEntry(supabase, row);
  }

  if (mode === "notification") {
    const notificationId = dispatchRows[0]?.notification_id;
    if (notificationId) {
      await markEnqueueProcessed(supabase, notificationId, sentFailed === 0 ? "invoked" : "failed");
    }
  }

  return {
    processed: results.length,
    sent_success: sentSuccess,
    sent_failed: sentFailed,
    queued_retry: queuedRetry,
    invalid_tokens: invalidTokens,
    processedKeys,
  };
}

function buildFcmPayload(args: {
  token: string;
  notification: any;
  recipientProfileId: string;
}) {
  const { token, notification, recipientProfileId } = args;

  const data = {
    ...(notification.data ?? {}),
    notification_id: String(notification.id),
    recipient_profile_id: recipientProfileId,
    type: String(notification.type ?? "system"),
  };

  const stringData: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    stringData[String(key)] = value == null ? "" : String(value);
  }

  return {
    message: {
      token,
      notification: {
        title: String(notification.title ?? ""),
        body: String(notification.body ?? ""),
      },
      data: stringData,
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
      webpush: {
        headers: {
          Urgency: "high",
        },
      },
    },
  };
}

async function sendSingleMessage(args: {
  oauthToken: string;
  payload: Record<string, unknown>;
  row: DispatchRow;
}) {
  const { oauthToken, payload, row } = args;

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(FIREBASE_PROJECT_ID)}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${oauthToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    },
  );

  const responseBody = await response.json().catch(() => ({}));

  if (response.ok) {
    return {
      ok: true,
      retryable: false,
      invalidToken: false,
      row,
      httpStatus: response.status,
      providerMessageId: (responseBody?.name as string | undefined) ?? null,
      responseBody,
    };
  }

  const firebaseError = responseBody?.error;
  const details = Array.isArray(firebaseError?.details) ? firebaseError.details : [];
  const errorCode = String(firebaseError?.status ?? "UNKNOWN");
  const errorMessage = String(firebaseError?.message ?? "Failed to send push");

  const invalidToken =
    errorCode === "INVALID_ARGUMENT" ||
    errorCode === "NOT_FOUND" ||
    details.some((detail: any) => String(detail?.errorCode ?? "") === "UNREGISTERED");

  const retryable =
    !invalidToken &&
    (response.status >= 500 ||
      errorCode === "UNAVAILABLE" ||
      errorCode === "INTERNAL" ||
      errorCode === "DEADLINE_EXCEEDED" ||
      errorCode === "RESOURCE_EXHAUSTED");

  return {
    ok: false,
    retryable,
    invalidToken,
    row,
    httpStatus: response.status,
    errorCode,
    errorMessage,
    responseBody,
  };
}

async function upsertDelivery(
  supabase: SupabaseClient,
  args: {
    notification_id: string;
    recipient_profile_id: string;
    fcm_token: string;
    status: string;
    attemptCountIncrement: number;
    errorCode?: string;
    errorMessage?: string;
    providerMessageId?: string | null;
    providerResponse?: Record<string, unknown>;
    sentAt?: string;
  },
) {
  const { data: existing, error: existingError } = await supabase
    .from("notification_push_deliveries")
    .select("id, attempt_count")
    .eq("notification_id", args.notification_id)
    .eq("recipient_profile_id", args.recipient_profile_id)
    .eq("fcm_token", args.fcm_token)
    .maybeSingle();

  if (existingError) {
    throw new Error(`Failed to query delivery row: ${existingError.message}`);
  }

  const nextAttemptCount = (existing?.attempt_count ?? 0) + args.attemptCountIncrement;

  const payload = {
    notification_id: args.notification_id,
    recipient_profile_id: args.recipient_profile_id,
    fcm_token: args.fcm_token,
    status: args.status,
    error_code: args.errorCode ?? null,
    error_message: args.errorMessage ?? null,
    provider_message_id: args.providerMessageId ?? null,
    provider_response: args.providerResponse ?? null,
    attempt_count: nextAttemptCount,
    sent_at: args.sentAt ?? null,
    updated_at: new Date().toISOString(),
  };

  if (existing?.id) {
    const { error } = await supabase
      .from("notification_push_deliveries")
      .update(payload)
      .eq("id", existing.id as string);

    if (error) {
      throw new Error(`Failed to update delivery row: ${error.message}`);
    }
    return;
  }

  const { error: insertError } = await supabase
    .from("notification_push_deliveries")
    .insert({ ...payload, created_at: new Date().toISOString() });

  if (insertError) {
    throw new Error(`Failed to insert delivery row: ${insertError.message}`);
  }
}

async function incrementRetryQueue(
  supabase: SupabaseClient,
  row: DispatchRow,
  args: {
    errorCode?: string;
    errorMessage?: string;
    httpStatus?: number;
  },
): Promise<number> {
  const { data: existing, error: existingError } = await supabase
    .from("notification_push_retry_queue")
    .select("id, attempts")
    .eq("notification_id", row.notification_id)
    .eq("recipient_profile_id", row.recipient_profile_id)
    .eq("fcm_token", row.fcm_token)
    .maybeSingle();

  if (existingError) {
    throw new Error(`Failed to query retry queue row: ${existingError.message}`);
  }

  const attempts = (existing?.attempts ?? 0) + 1;
  const backoffSeconds = Math.min(3600, Math.pow(2, attempts) * 30);
  const nextAttemptAt = new Date(Date.now() + backoffSeconds * 1000).toISOString();

  if (attempts >= RETRY_MAX_ATTEMPTS) {
    await clearRetryQueueEntry(supabase, row);
    return attempts;
  }

  const payload = {
    notification_id: row.notification_id,
    recipient_profile_id: row.recipient_profile_id,
    fcm_token: row.fcm_token,
    attempts,
    next_attempt_at: nextAttemptAt,
    last_http_status: args.httpStatus ?? null,
    last_error_code: args.errorCode ?? null,
    last_error_message: args.errorMessage ?? null,
    payload: null,
    processed_at: null,
    updated_at: new Date().toISOString(),
  };

  if (existing?.id) {
    const { error } = await supabase
      .from("notification_push_retry_queue")
      .update(payload)
      .eq("id", existing.id as string);

    if (error) {
      throw new Error(`Failed to update retry queue row: ${error.message}`);
    }
    return attempts;
  }

  const { error: insertError } = await supabase
    .from("notification_push_retry_queue")
    .insert({ ...payload, created_at: new Date().toISOString() });

  if (insertError) {
    throw new Error(`Failed to insert retry queue row: ${insertError.message}`);
  }

  return attempts;
}

async function clearRetryQueueEntry(supabase: SupabaseClient, row: DispatchRow): Promise<void> {
  const { error } = await supabase
    .from("notification_push_retry_queue")
    .delete()
    .eq("notification_id", row.notification_id)
    .eq("recipient_profile_id", row.recipient_profile_id)
    .eq("fcm_token", row.fcm_token);

  if (error) {
    throw new Error(`Failed to clear retry queue entry: ${error.message}`);
  }
}

async function markRetryProcessed(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase
    .from("notification_push_retry_queue")
    .update({ processed_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq("id", id);

  if (error) {
    throw new Error(`Failed to mark retry row processed: ${error.message}`);
  }
}

async function deactivateToken(supabase: SupabaseClient, fcmToken: string): Promise<void> {
  const { error } = await supabase
    .from("device_tokens")
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq("fcm_token", fcmToken);

  if (error) {
    throw new Error(`Failed to deactivate invalid token: ${error.message}`);
  }
}

async function markEnqueueProcessed(
  supabase: SupabaseClient,
  notificationId: string,
  status: "invoked" | "failed",
): Promise<void> {
  const { data: existing, error: existingError } = await supabase
    .from("notification_push_enqueue")
    .select("invoke_attempts")
    .eq("notification_id", notificationId)
    .maybeSingle();

  if (existingError) {
    throw new Error(`Failed to read enqueue row: ${existingError.message}`);
  }

  const nextAttempts = (existing?.invoke_attempts ?? 0) + 1;

  const { error } = await supabase
    .from("notification_push_enqueue")
    .update({
      status,
      last_invoked_at: new Date().toISOString(),
      last_error: status === "failed" ? "One or more sends failed" : null,
      invoke_attempts: nextAttempts,
    })
    .eq("notification_id", notificationId);

  if (error) {
    throw new Error(`Failed to update enqueue row: ${error.message}`);
  }
}

async function getGoogleAccessToken(): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const jwtHeader = { alg: "RS256", typ: "JWT" };
  const jwtClaimSet = {
    iss: FIREBASE_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };

  const encoder = new TextEncoder();
  const headerEncoded = base64UrlEncode(JSON.stringify(jwtHeader));
  const claimEncoded = base64UrlEncode(JSON.stringify(jwtClaimSet));
  const unsignedToken = `${headerEncoded}.${claimEncoded}`;

  const key = await importPrivateKey(FIREBASE_PRIVATE_KEY);
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    encoder.encode(unsignedToken),
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncode(signature)}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  const tokenJson = await tokenResponse.json().catch(() => ({}));
  if (!tokenResponse.ok || !tokenJson.access_token) {
    throw new Error(`Failed to obtain Firebase OAuth token: ${JSON.stringify(tokenJson)}`);
  }

  return tokenJson.access_token as string;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleanPem = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  const keyData = base64Decode(cleanPem);

  return crypto.subtle.importKey(
    "pkcs8",
    keyData,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
}

function base64UrlEncode(input: string | ArrayBuffer): string {
  let bytes: Uint8Array;
  if (typeof input === "string") {
    bytes = new TextEncoder().encode(input);
  } else {
    bytes = new Uint8Array(input);
  }

  const binary = Array.from(bytes)
    .map((b) => String.fromCharCode(b))
    .join("");

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64Decode(input: string): ArrayBuffer {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

async function runWithConcurrency<T>(
  tasks: Array<() => Promise<T>>,
  concurrency: number,
): Promise<T[]> {
  const results: T[] = new Array(tasks.length);
  let index = 0;

  async function worker() {
    while (true) {
      const current = index;
      index += 1;
      if (current >= tasks.length) {
        return;
      }

      results[current] = await tasks[current]();
    }
  }

  const workers = Array.from({ length: Math.max(1, concurrency) }, () => worker());
  await Promise.all(workers);
  return results;
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
