# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run static analysis (run before marking any task complete)
flutter analyze

# Run the app
flutter run -d <device-id>

# List connected devices
flutter devices

# Clean build cache
flutter clean

# Build release APK/AAB
flutter build appbundle --release

# Run a single test file
flutter test test/widget_test.dart
```

`.env` must exist in the project root (see `.env.example`):
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

Android emulator may need: `emulator -avd Pixel_6 -gpu swiftshader_indirect`

## Architecture

**State management:** `provider` package with `ChangeNotifier`. `flutter_riverpod` is in pubspec but is NOT used.

**Routing:** Manual `MaterialApp` routes via `AppRouter` (`lib/routing/app_router.dart`). `go_router` is in pubspec but is NOT used. Navigate with `Navigator.pushNamed` and `AppRouter.*` constants.

**Backend:** Supabase only — all DB/auth calls live in `data/` layer services/repositories.

**Feature folder structure:**
```
lib/<feature>/
  data/    ← Supabase calls, models, services
  logic/   ← ChangeNotifier providers
  ui/
    components/   ← feature-local widgets
    <page>.dart
```

Home admin features follow this pattern under `lib/home/pages/<feature>/`.

Shared widgets → `lib/core/widgets/`
Shared utilities → `lib/core/utils/`
Theme/colors → `lib/core/config/`
Route constants → `lib/routing/app_router.dart`

**Provider wiring:** All providers registered in `lib/main.dart` via `MultiProvider`. Providers that depend on `AuthProvider` use `ChangeNotifierProxyProvider<AuthProvider, XProvider>`.

**Route guards:** Protected routes use `_ProtectedRoutePage` in `app_router.dart`, which evaluates auth state + role rank before rendering the child.

## RBAC — Canonical Roles and Ranks

| Role Key | Rank |
|---|---:|
| system_admin | 100 |
| system_moderator | 90 |
| leadership | 80 |
| clan_leader | 75 |
| troop_head | 70 |
| troop_leader | 60 |
| rover | 50 |
| rover_aspirant | 45 |
| patrol_leader | 30 |
| patrol_assistant_1 | 25 |
| patrol_assistant_2 | 20 |
| scouts | 10 |
| public | 0 |

- Access check: `authProvider.currentUserRoleRank >= minRank`
- Admin/scoped features gate at rank 60 (troop_leader and above)
- Season management gates at rank 90
- Role management gates at rank 100
- Troop-scoped features (rank 60–70) use `ScopedServiceMixin.applyScopeFilter()` in the service layer — system-wide roles (90+) have `troop_context = NULL` and see all data automatically
- Use `AdminScopeBanner()` widget on any scoped admin page

## Non-Negotiable Rules

1. **No hardcoded colors.** Use `AppColors.*` or `Theme.of(context).colorScheme.*` only. `Colors.*` is forbidden except `Colors.transparent`.
2. **Supabase calls only in `data/` layer.** Never call Supabase from providers or UI.
3. **No go_router patterns.** Use `Navigator.pushNamed` / `AppRouter.*` helpers.
4. **No Riverpod.** Use Provider.
5. **AuthProvider is the source of truth** for current user — use its cached values from SharedPreferences, not direct Supabase auth calls.
6. **Dropdowns must have `isExpanded: true`** on `DropdownButtonFormField`.
7. **Dispose all controllers/timers/listeners.** Never call `context.read/watch` or `Provider.of` inside `dispose()`.

## Scoped Admin Feature Checklist

When adding a new admin/troop feature:
- [ ] Service: `with ScopedServiceMixin`, methods take `required UserProfile currentUser`
- [ ] Service queries: call `applyScopeFilter(query, currentUser, 'troop_column')`
- [ ] Provider: injected via `ChangeNotifierProxyProvider<AuthProvider, YourProvider>`
- [ ] Page: gate at `rank >= 60`, include `AdminScopeBanner()`
- [ ] Test with both rank 100 (system-wide) and rank 60/70 (troop-scoped) accounts

## Done Checklist

Before marking any task complete:
- [ ] Feature in correct `data/logic/ui` layers
- [ ] `flutter analyze` passes for touched files
- [ ] No hardcoded colors
- [ ] Loading, error, and empty states handled
- [ ] Dropdowns overflow-safe
- [ ] Controllers/listeners disposed correctly
- [ ] Modal errors shown inside modal, not behind it with a SnackBar

## Known Gotchas

- `go_router` and `flutter_riverpod` are in `pubspec.yaml` but are not the active patterns
- OTP email verification requires Supabase email provider configured externally
- After successful OTP signup, `updateUser(password: ...)` must be called before profile finalization so email+password login stays valid
- Failed signup rollback must go through a service-role edge function — `deleteCurrentUser()` alone does not remove the `auth.users` row
- Role filter queries: use two-phase filtering (fetch profiles, then intersect with `profile_roles`) rather than embedded relation filtering with pagination
- Attendance QR scanner needs `WidgetsBindingObserver` lifecycle gating to stop camera on background; sort modified profile IDs before building batch payloads

## Key Reference Files

- `lib/main.dart` ��� provider wiring and app initialization order
- `lib/routing/app_router.dart` — all route constants, guards, and nav helpers
- `lib/core/config/` — `app_colors.dart`, `theme_config.dart`, `theme_provider.dart`
- `lib/auth/logic/auth_provider.dart` — current user, role rank, profile helpers
- `database/RLS_Current_Policies.md` — Supabase RLS reference
- `database/schema_copy.txt` — DB schema reference
