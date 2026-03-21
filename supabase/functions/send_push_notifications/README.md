# send_push_notifications

Supabase Edge Function for backend-owned FCM delivery.

## What It Does
- Accepts a notification dispatch request with `notification_id`.
- Loads recipients and active device tokens from Supabase.
- Deduplicates token sends.
- Sends push messages through Firebase HTTP v1.
- Tracks outcomes in `notification_push_deliveries`.
- Queues transient failures in `notification_push_retry_queue`.
- Deactivates invalid tokens.

## Required Secrets
Set these with Supabase CLI:

```bash
supabase secrets set SUPABASE_URL="https://<project-ref>.supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
supabase secrets set FIREBASE_PROJECT_ID="<firebase-project-id>"
supabase secrets set FIREBASE_CLIENT_EMAIL="<service-account-email>"
supabase secrets set FIREBASE_PRIVATE_KEY="<service-account-private-key-with-escaped-newlines>"
supabase secrets set FUNCTION_AUTH_TOKEN="<shared-secret-for-http-invocations>"
```

## Deploy
```bash
supabase functions deploy send_push_notifications --no-verify-jwt
```

## Invoke Manually
```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/send_push_notifications" \
  -H "Authorization: Bearer <FUNCTION_AUTH_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"notification_id":"<uuid>"}'
```

Retry mode:

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/send_push_notifications" \
  -H "Authorization: Bearer <FUNCTION_AUTH_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"mode":"retry","max_retry_items":100}'
```

## Notes
- Client app must never send FCM directly.
- Notification creation stays in app data layer; push dispatch is backend-triggered.
- SQL migration helper must use the same secret in `v_edge_secret` as `FUNCTION_AUTH_TOKEN`.
- TODO: scheduled delivery windows.
- TODO: silent/background push payload variants.
- TODO: topic broadcasts for coarse audiences.
- TODO: push analytics rollups.
