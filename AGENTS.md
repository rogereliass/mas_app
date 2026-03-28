# AGENTS.md - Agentic Coding Guidelines

This file provides guidance for AI agents operating in this repository.

## Quick Reference Commands

```bash
# Install dependencies
flutter pub get

# Run static analysis (required before marking any task complete)
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
flutter test test/routing/protected_route_guard_test.dart

# Run all tests
flutter test

# Build runner (for code generation)
dart run build_runner build
```

## Project Overview

- **App**: Flutter mobile app for Scout Digital Library
- **Backend**: Supabase
- **State Management**: Provider (not Riverpod, despite being in pubspec)
- **Routing**: Manual MaterialApp routes (not go_router, despite being in pubspec)
- **Offline**: Hive metadata + local file caching
- **Theme**: Material 3 with centralized app color constants

## Architecture

### Feature Folder Structure
```
lib/<feature>/
  data/          ← Supabase calls, models, services
  logic/         ← ChangeNotifier providers
  ui/
    components/ ← feature-local widgets
    <page>.dart
```

### Shared Locations
- Shared widgets: `lib/core/widgets/`
- Shared utilities: `lib/core/utils/`
- Theme/colors: `lib/core/config/`
- Route constants: `lib/routing/app_router.dart`

### Provider Wiring
All providers registered in `lib/main.dart` via `MultiProvider`. Providers depending on `AuthProvider` use `ChangeNotifierProxyProvider<AuthProvider, XProvider>`.

## Code Style Guidelines

### Imports

```dart
// Package imports first (alphabetical within group)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Relative imports for local code
import '../../../core/data/scoped_service_mixin.dart';
import '../data/models/season.dart';
```

### Formatting

- Use 2 spaces for indentation (Dart standard)
- Use trailing commas for better formatting
- Maximum line length: 80-100 characters
- Use const constructors where possible

### Types

- Prefer explicit return types on public methods
- Use `final` by default, `var` only when mutation needed
- Use `late` sparingly and only when initialization is guaranteed before use
- Nullable types: `String?` not `String | null`

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Classes | PascalCase | `SeasonService` |
| Enums | PascalCase | `ProtectedRouteState` |
| Constants | camelCase | `maxRetries` |
| Methods | camelCase | `fetchSeasons` |
| Private members | _camelCase | `_service` |
| Files | snake_case | `season_service.dart` |
| Database tables | snake_case | `seasons` |

### Model Pattern

```dart
class Season {
  final String id;
  final String seasonCode;

  const Season({
    required this.id,
    required this.seasonCode,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] as String,
      seasonCode: json['season_code'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'season_code': seasonCode,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Season &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

### Service Pattern

```dart
class SeasonService with ScopedServiceMixin {
  static const String _tableName = 'seasons';
  final SupabaseClient _supabase;

  SeasonService(this._supabase);

  factory SeasonService.instance() {
    return SeasonService(Supabase.instance.client);
  }

  Future<List<Season>> fetchSeasons() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('start_date', ascending: false);

      return (response as List)
          .map((json) => Season.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ SeasonService.fetchSeasons error: $e');
      rethrow;
    }
  }
}
```

### Provider Pattern

```dart
class SeasonManagementProvider with ChangeNotifier {
  final SeasonService _service;

  SeasonManagementProvider({SeasonService? service})
      : _service = service ?? SeasonService.instance();

  List<Season> _seasons = [];
  bool _isLoading = false;
  String? _error;

  List<Season> get seasons => _seasons;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSeasons() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _seasons = await _service.fetchSeasons();
    } catch (e) {
      _error = 'Failed to load seasons. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

## Non-Negotiable Rules

1. **No hardcoded colors** - Use `AppColors.*` or `Theme.of(context).colorScheme.*` only. `Colors.*` is forbidden except `Colors.transparent`.
2. **Supabase calls only in data/ layer** - Never call Supabase from providers or UI.
3. **No go_router patterns** - Use `Navigator.pushNamed` / `AppRouter.*` helpers.
4. **No Riverpod** - Use Provider.
5. **AuthProvider is the source of truth** - Use its cached values from SharedPreferences, not direct Supabase auth calls.
6. **Dropdowns must have `isExpanded: true`** on `DropdownButtonFormField`.
7. **Dispose all controllers/timers/listeners** - Never call `context.read/watch` or `Provider.of` inside `dispose()`.
8. **Comments** - Do NOT add comments unless explicitly requested.

## RBAC - Canonical Roles

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

Access check: `authProvider.currentUserRoleRank >= minRank`

## Error Handling

- Services catch, log, and rethrow exceptions
- Providers set user-friendly error messages, log details with debugPrint
- UI displays loading, error, and empty states explicitly
- Modal errors shown inside modal, not with SnackBars behind overlays

## Responsive Design

- Use `LayoutBuilder` or `MediaQuery` for adaptive layout
- Support widths: 360, 500, 600, 1024 pixels minimum
- Set `overflow: TextOverflow.ellipsis` with `maxLines` in constrained layouts

## Done Checklist

Before marking any task complete:
- [ ] Feature in correct `data/logic/ui` layers
- [ ] `flutter analyze` passes for touched files
- [ ] No hardcoded colors
- [ ] Loading, error, and empty states handled
- [ ] Dropdowns overflow-safe (`isExpanded: true`)
- [ ] Controllers/listeners disposed correctly
- [ ] Modal errors shown inside modal

## Known Gotchas

- `go_router` and `flutter_riverpod` are in pubspec.yaml but are NOT used
- OTP email verification requires external Supabase email provider setup
- After successful OTP signup, `updateUser(password: ...)` must be called before profile finalization
- Failed signup rollback must use a service-role edge function
- Role filter queries: use two-phase filtering (fetch profiles, then intersect with profile_roles)
- Attendance QR scanner needs WidgetsBindingObserver lifecycle gating
- Android emulator may need: `emulator -avd Pixel_6 -gpu swiftshader_indirect`

## Reference Files

- `lib/main.dart` - Provider wiring and app initialization
- `lib/routing/app_router.dart` - Route constants and guards
- `lib/core/config/app_colors.dart` - Color definitions
- `lib/core/config/theme_provider.dart` - Theme configuration
- `lib/auth/logic/auth_provider.dart` - Current user and role helpers
- `database/RLS_Current_Policies.md` - Supabase RLS reference
- `database/schema_copy.txt` - DB schema reference

## Environment Requirements

`.env` file required in project root:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```
