// @ts-nocheck
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (request) => {
  try {
    if (request.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({ error: "Missing required environment variables" }, 500);
    }

    const authHeader = request.headers.get("authorization") ?? "";
    const token = extractBearerToken(authHeader);
    if (!token) {
      return json({ error: "Unauthorized" }, 401);
    }

    // Resolve the caller identity using the caller's JWT.
    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      },
      auth: { persistSession: false },
    });

    const {
      data: { user },
      error: getUserError,
    } = await callerClient.auth.getUser();

    if (getUserError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    // Service-role client can safely remove profile data and auth user.
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // Safety guard: never allow deletion of already-approved accounts.
    // This function is intended for failed signup rollback only.
    const { data: existingProfile, error: profileLookupError } = await adminClient
      .from("profiles")
      .select("id, approved")
      .eq("user_id", user.id)
      .maybeSingle();

    if (profileLookupError) {
      return json(
        {
          error: "Failed to validate profile state",
          details: profileLookupError.message,
        },
        500,
      );
    }

    if (existingProfile?.approved === true) {
      return json(
        {
          error: "Refusing to delete approved account",
        },
        403,
      );
    }

    const { error: profileDeleteError } = await adminClient
      .from("profiles")
      .delete()
      .eq("user_id", user.id);

    if (profileDeleteError) {
      return json(
        {
          error: "Failed to delete profile",
          details: profileDeleteError.message,
        },
        500,
      );
    }

    const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(user.id);

    if (deleteUserError) {
      return json(
        {
          error: "Failed to delete auth user",
          details: deleteUserError.message,
        },
        500,
      );
    }

    return json({ success: true, user_id: user.id }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});

function extractBearerToken(authHeader: string): string | null {
  const bearerPrefix = "Bearer ";
  if (!authHeader.startsWith(bearerPrefix)) {
    return null;
  }

  const token = authHeader.substring(bearerPrefix.length).trim();
  return token.length > 0 ? token : null;
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
