# delete_signup_user Edge Function

Purpose: delete the currently authenticated user during signup rollback, so failed registrations can restart cleanly.

## Security model

- Requires caller JWT (`Authorization: Bearer <access-token>`).
- Resolves caller identity via `auth.getUser()` using anon key.
- Uses service role only after caller identity is validated.
- Refuses deletion if the caller profile is already approved.
- Deletes `profiles` row(s) for `user_id` first, then deletes the auth user.

## Required secrets

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
```

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are expected to be available in the function runtime.

## Deploy

```bash
supabase functions deploy delete_signup_user
```

## Manual invocation example

```bash
curl -X POST "https://<project-ref>.functions.supabase.co/delete_signup_user" \
  -H "Authorization: Bearer <user-access-token>" \
  -H "Content-Type: application/json"
```
