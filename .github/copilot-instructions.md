# MAS App - Copilot Implementation Playbook

This file is optimized for fast scanning while implementing features.

## 1) Rapid Workflow (Use This First)

When implementing any feature, follow this order:

1. Confirm scope and where the feature belongs in `lib/`.
2. Implement in the correct layer order: `data -> logic -> ui`.
3. Validate non-negotiables: routing, theme colors, RBAC, responsive layout.
4. Run checks: `flutter analyze` and targeted tests.
5. Complete the done checklist in section 12.

If a task conflicts with this playbook, ask before proceeding.

## 2) User Preferences (Persistent)

Use this section for user-specific working preferences that should remain available in future sessions.

Update rules:
- Keep each preference to one line.
- Add date when changed.
- Keep only active preferences; remove outdated ones.

Template:

| Date | Preference | Status | Notes |
|---|---|---|---|
| YYYY-MM-DD | Example: Prefer small, incremental PR-style changes | Active | Added from chat |

Current preferences:
- 2026-03-20 | Prefer instruction docs to be scan-first with a rapid workflow at the top | Active | Added from chat
- 2026-03-20 | Keep dedicated sections for persistent preferences and agent lessons | Active | Added from chat
- 2026-03-20 | Allow proactive useful defaults when explicitly approved | Active | "add anything if needed"

## 3) Agent Lessons Learned (Ongoing Notes)

Use this section to capture mistakes and prevention steps so quality improves over time.

Update rules:
- Keep entries short and concrete.
- Focus on root cause and prevention.
- Add newest entries at the top.

Template:

| Date | Mistake | Root Cause | Prevention |
|---|---|---|---|
| YYYY-MM-DD | Example: Broke dropdown layout on narrow screen | Missing `isExpanded: true` | Add dropdown checklist item before submit |

Current lessons:
- 2026-03-20 | Wrote memory file content with escaped newlines | Used literal `\\n` text in initial create payload | Verify memory file formatting immediately after create and fix if needed

## 4) Project Snapshot

- App: Flutter mobile app for Scout Digital Library.
- Backend: Supabase.
- State: Provider (not Riverpod in practice).
- Routing: Manual `MaterialApp` routes (not `go_router`).
- Offline: Hive metadata + local file caching.
- Theme: Material 3 with centralized app color constants.

## 5) Architecture and File Placement

### Feature Structure

```
lib/
|- core/       shared config, widgets, utils
|- auth/       auth + role system
|- library/    folder/file browsing
|- offline/    local cache
|- routing/    app_router.dart
|- startup/    landing/onboarding
`- home/       homepage and admin-related features
   |- home_page.dart
   |- components/
   `- pages/
      `- <feature>/
         |- data/
         |- logic/
         `- ui/
```

### Placement Rules

- Page-specific features belong under parent page `pages/`.
- Reusable widgets go to `lib/core/widgets/`.
- Feature-local widgets go to that feature's `ui/components/`.
- Shared utilities go to `lib/core/utils/`.

## 6) Non-Negotiable Implementation Rules

1. Use Provider for state wiring; follow existing `MultiProvider` in `lib/main.dart`.
2. Use manual route constants and `Navigator.pushNamed`; do not introduce `go_router` patterns.
3. Call Supabase only from `data/` layer services/repositories.
4. Use singleton service patterns where established (for example, `LibraryService.instance()`).
5. Apply RBAC before display: filter client-side using rank checks.
6. Keep role keys and rank values canonical (see section 7).
7. Use `AuthProvider` helpers for cached current-user values from SharedPreferences.
8. Use only `AppColors.*` or `Theme.of(context).colorScheme.*` for UI colors.
9. Never hardcode color literals like `Colors.*` (except transparent where needed), `.shade`, or `Color(0x...)`.
10. Keep files manageable; extract components if file size or widget complexity grows too large.

## 7) RBAC Canonical Roles

Use these role keys and ranks when checking `min_rank` access:

| Role Key | Display Name | Rank |
|---|---|---:|
| system_admin | System Admin | 100 |
| system_moderator | System Moderator | 90 |
| leadership | Leadership | 80 |
| clan_leader | Clan Leader | 75 |
| troop_head | Troop Head | 70 |
| troop_leader | Troop Leader | 60 |
| rover | Rover | 50 |
| patrol_leader | Patrol Leader | 30 |
| patrol_assistant_1 | Patrol Assistant 1 | 25 |
| patrol_assistant_2 | Patrol Assistant 2 | 20 |
| scouts | Scout | 10 |
| public | Public | 0 |

Rule:
- Public content (`min_rank = 0`) is always visible.
- All other content requires `roleRank >= min_rank`.

## 8) Responsive and Performance Guardrails

### Dropdown Safety (Required)

- Always set `isExpanded: true` on `DropdownButtonFormField`.
- If item UI is rich or multi-line, provide `selectedItemBuilder`.
- Ensure `itemHeight` is large enough for custom item content.

### Layout Safety

- Use `LayoutBuilder` or `MediaQuery` for adaptive layout.
- Support widths at minimum: 360, 500, 600, 1024.

### Text Overflow Safety

- In constrained layouts, set `overflow: TextOverflow.ellipsis` and appropriate `maxLines`.

### Debounce and Caching

- Debounce high-frequency actions (search, form change detection).
- Cache expensive filtered computations in providers.
- Clear caches when source data changes.

### Lifecycle Safety

- Dispose timers/controllers/listeners correctly.
- Do not call `context.read/watch` or `Provider.of` in `dispose()`.
- Do not use `addPostFrameCallback` in `dispose()`.
- Implement `didUpdateWidget` for widgets with mutable initial values.

### List Performance

- Use stable keys like `ValueKey(item.id)` in changing lists.

### Dialog and Modal Safety

- Wrap long dialog content in `SingleChildScrollView`.
- Prefer `Dialog` with width constraints for complex layouts.
- Surface errors inside modal UI, not with SnackBars behind overlays.

## 9) Home Smart Card Data Fetching

For dashboard smart cards under `lib/home/components/smart_stack/`:

1. Do not fetch before auth/profile state is ready.
2. Cache by scope (`userId`, `profileId`, `troopId`, role, season).
3. Deduplicate in-flight requests.
4. Separate states clearly: signed out, loading profile, no troop, no active season, no data, request failure.
5. Keep card heading stable; show dynamic record in body text.
6. Use keep-alive as UI optimization only, not as data cache.
7. Do not auto-refresh on tab switch unless scope changes.

## 10) Setup and Validation Commands

### Initial Local Setup

```bash
flutter pub get
dart run build_runner build
flutter run
```

`.env` is required in project root:

```env
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

### Useful Commands

```bash
flutter analyze
flutter clean
flutter pub get
flutter run -d <device-id>
```

## 11) Common Implementation Playbooks

### Add a Page-Specific Feature

1. Create under parent page: `lib/<parent>/pages/<feature>/`.
2. Create `data/`, `logic/`, `ui/` subfolders.
3. Register provider in `lib/main.dart` if needed.
4. Add routes in `lib/routing/app_router.dart`.
5. Add `README.md` for feature notes.

### Add a Standalone Feature Module

1. Create `lib/<feature>/data`, `lib/<feature>/logic`, `lib/<feature>/ui`.
2. Wire provider and routes.
3. Keep all Supabase access in `data/`.

### Add or Update Supabase Fetching

1. Add repository/service method in `data/`.
2. Call from provider in `logic/`.
3. Expose clean UI states in `ui/`.

### Role-Based Filtering

1. Fetch complete data set in repository.
2. Filter by `canAccess(minRank)` in provider.
3. Expose already-filtered data to UI.

## 12) Done Checklist (Before Marking Complete)

### Architecture

- [ ] Feature is in correct folder and layer (`data/logic/ui`).
- [ ] Supabase calls only in `data/` layer.
- [ ] Route wiring follows current router pattern.

### UI and Responsiveness

- [ ] Dropdowns are overflow-safe (`isExpanded`, etc.).
- [ ] Constrained text uses overflow handling.
- [ ] Layout adapts across phone/tablet/desktop widths.

### Performance and Lifecycle

- [ ] Debounce applied where needed.
- [ ] Expensive filters cached.
- [ ] Controllers/listeners/timers disposed safely.
- [ ] No provider lookups in `dispose()`.

### Theme and Colors

- [ ] No hardcoded color values.
- [ ] Colors map to `AppColors` or `colorScheme`.
- [ ] Verified in light and dark modes.

### UX and Error Handling

- [ ] Loading, error, and empty states are explicit.
- [ ] Modal errors shown inside modal.
- [ ] Unsaved changes handling exists for complex forms.

### Quality Gates

- [ ] `flutter analyze` passes for touched files.
- [ ] Relevant tests updated and passing where applicable.

## 13) Known Gotchas

- `go_router` exists in dependencies but is not the active routing pattern.
- `flutter_riverpod` exists in dependencies but Provider is the active state pattern.
- OTP verification needs external provider setup in Supabase.
- Some Android emulator setups may need: `-gpu swiftshader_indirect`.

## 14) Reference Files

- `ARCHITECTURE.md`
- `lib/main.dart`
- `lib/app.dart`
- `lib/routing/app_router.dart`
- `lib/core/config/app_colors.dart`
- `lib/core/config/theme_provider.dart`
- `lib/auth/AUTH_SETUP.md`
- `database/migrations/`

Current focus:
- Premium Troop Standings Card complete.
- Next focus is refining role-specific dashboard views (meeting and attendance) in HomePage.