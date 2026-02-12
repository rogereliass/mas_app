# MAS App - AI Coding Agent Instructions

## Project Overview
Flutter mobile app for Scout Digital Library with Supabase backend. Supports offline caching, role-based content access (0-100 rank system), and Material 3 theming.

## Architecture

### Feature-Based Structure
```
lib/
├── core/          # Shared: config, theme, widgets, utils
├── auth/          # Authentication with role system
├── library/       # Main content (folders/files)
├── offline/       # Hive-based offline storage
├── routing/       # Centralized navigation (app_router.dart)
├── startup/       # Landing/onboarding pages
└── home/          # Home page and admin features
    ├── home_page.dart
    ├── components/      # Home-specific UI components
    └── pages/           # Feature pages grouped under home
        └── admin_approval/  # Example: Admin features
            ├── data/
            ├── logic/
            ├── ui/
            └── README.md
```

**IMPORTANT**: For page-specific features (like admin panels, user management, etc.), organize them under the relevant parent page in a `pages/` subdirectory. Each feature follows the same 3-layer architecture.

Each feature follows **3-layer clean architecture**:
- `data/` - Models, repositories, services (Supabase calls)
- `logic/` - Providers (state management)
- `ui/` - Pages, components (presentation)

**File Organization Rules**:
- **Feature-specific code**: Group under parent page (e.g., `home/pages/admin_approval/`)
- **Reusable widgets**: Place in `core/widgets/` (e.g., `loading_view.dart`, `error_view.dart`)
- **Feature components**: Keep in feature's `ui/components/` subdirectory
- **Shared utilities**: Place in `core/utils/`

### Key Dependencies
- **State**: Provider (not Riverpod despite pubspec) - see [main.dart](lib/main.dart) MultiProvider
- **Backend**: Supabase (auth, storage, database)
- **Routing**: Manual MaterialApp routes via [app_router.dart](lib/routing/app_router.dart), NOT go_router
- **Offline**: Hive + path_provider (metadata + file storage)
- **Config**: flutter_dotenv for `.env` (SUPABASE_URL, SUPABASE_ANON_KEY)

## Critical Patterns

### 1. Role-Based Access Control (RBAC)
Files have `min_rank` field (0-100). Users have `roleRank` from joined tables (profiles → profile_roles → roles).
```dart
// Check access in UserProfile model
user.canAccess(file.minRank)  // roleRank >= minRank

// Repository helper (auth/data/role_repository.dart)
await roleRepo.canCurrentUserAccess(minRank)
```
**Rule**: Filter files/folders client-side BEFORE displaying. Public content (min_rank=0) always visible.

### 2. Supabase Integration
All data fetching happens in `data/` layer repositories/services:
```dart
// Example: library/data/library_service.dart
final response = await supabase
  .from('folders')
  .select('*')
  .eq('parent_folder_id', parentId);
```
**Always** use `LibraryService.instance()` singleton pattern. Never call Supabase directly from UI/logic.

### 3. Offline Storage Pattern
Files cached with expiry tracking (default 180 days) and version control:
```dart
// Save: offline/offline_storage.dart
await OfflineStorageService.saveFile(
  fileId: id,
  bytes: data,
  serverVersion: version,
  expiryDays: 180
);

// Check: Returns cached path or null
final cachedPath = await OfflineStorageService.getFilePath(fileId);
```
Metadata stored in Hive, files in `getApplicationDocumentsDirectory()/offline_files/`.

### 4. Theme System
Centralized Material 3 theme with dark/light mode:
- **Single source**: [core/config/app_colors.dart](lib/core/config/app_colors.dart) - **NO hardcoded colors elsewhere**
- **Access**: Use `AppColors.colorName` for all custom colors, `Theme.of(context).colorScheme` for Material 3 colors
- **Toggle**: `ThemeProvider().toggleTheme()` - persists to SharedPreferences
- **CRITICAL RULE**: Every color in the UI must be wired to either `AppColors.*` constants or `Theme.of(context).colorScheme.*`
  - ❌ WRONG: `Colors.green`, `Colors.grey[600]`, `Color(0xFF...)` hardcoded
  - ✅ RIGHT: `AppColors.success`, `AppColors.textSecondaryLight`, `Theme.of(context).primaryColor`
  - If a color isn't available in AppColors, add it to [app_colors.dart](lib/core/config/app_colors.dart) with clear documentation

### 5. Navigation Pattern
```dart
// Route constants in app_router.dart
Navigator.pushNamed(context, AppRouter.library);

// With arguments (see onGenerateRoute)
Navigator.pushNamed(
  context, 
  '/folder-detail',
  arguments: FolderDetailArgs(folderId: id, folderName: name)
);
```
Do NOT use go_router methods - it's in pubspec but not implemented.

### 6. Design System & Theming (Scout Elite)
- **Primary Palette**: from color constants in `AppColors` (e.g., `primaryBlue`, `accentBlue`, etc.)
- **Secondary Palette**: from color constants in `AppColors` (e.g., `sectionHeaderGray`, `dividerLight`, etc.)
- **Dark Mode Standard**: Use `AppColors.backgroundDark` (Navy) and `AppColors.cardDark` (Slate 800) for ALL dark mode surfaces.
- **Card Styling**:
  - Border radius: 24px for media cards, 16px for standard containers.
  - Shadows: Subtle drop shadows using `AppColors.overlay` or `Theme.of(context).shadowColor` blur 10, offset 0,4.
  - Aspect Ratio: Recent asset cards should be squarish (~170x180), not tall/portrait.
- **Role Visibility**: 
  - Hide sensitive UI sections (Settings > Account) for unauthenticated users.
  - Check `AuthProvider.isAuthenticated` before rendering admin features.

## Development Workflows

### Initial Setup
```bash
# 1. Create .env file in project root (not committed)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# 2. Install dependencies
flutter pub get

# 3. Run build_runner for Hive adapters
dart run build_runner build

# 4. Start emulator (example)
emulator -avd Pixel_6 -gpu swiftshader_indirect

# 5. Run app
flutter run
```

### Testing/Building
```bash
flutter clean         # Clear build cache
flutter pub get       # Reinstall dependencies
flutter analyze       # Static analysis (flutter_lints rules)
flutter run -d <device-id>  # Target specific device
```

### Debugging Role Access Issues
1. Check user's `roleRank` in `AuthProvider.currentUserProfile`
2. Verify file's `min_rank` in database
3. Test with `UserProfile.canAccess(minRank)` helper
4. Ensure filtering happens in `LibraryProvider` BEFORE setting state

## Code Conventions

### File Organization
- **Page-specific features**: Organize under parent page in `pages/` subdirectory (e.g., `home/pages/admin_approval/`)
- **Reusable widgets**: Place in `core/widgets/` (e.g., `loading_view.dart`, `error_view.dart`, etc.)
- **Feature-specific components**: Keep in feature's `ui/components/` subdirectory
- **Models**: Immutable with `copyWith()` and JSON factories
- **Services**: Singleton pattern with `.instance()` factory constructor

### Provider Pattern
```dart
// Consume provider
final provider = Provider.of<LibraryProvider>(context);
final folders = provider.rootFolders;

// Listen to changes with Consumer
Consumer<ThemeProvider>(
  builder: (context, theme, child) => Widget()
)
```

### Error Handling
```dart
// Repository pattern (in data/ layer)
try {
  final data = await supabase.from('table').select();
  return Result.success(data);
} catch (e) {
  return Result.error('User-friendly message: $e');
}

// Provider updates error state, UI shows error_view.dart
```

### Database Queries
Reference [database/migrations/](database/migrations/) for schema. Key tables:
- `folders` (id, name, parent_folder_id, depth)
- `files` (id, name, folder_id, min_rank, version, url)
- `profiles` → `profile_roles` → `roles` (for RBAC)

## Common Tasks page**: 
1. Create under parent page: `parent_page/pages/feature_name/`
2. Follow 3-layer architecture: `data/`, `logic/`, `ui/` subdirectories
3. Add provider to [main.dart](lib/main.dart) MultiProvider
4. Add routes to [app_router.dart](lib/routing/app_router.dart)
5. Create feature exports file: `feature_name.dart`
6. Document in feature's `README.md`

Example: `home/pages/admin_approval/` with data/logic/ui structure

**Add standalone feature module**: Create `feature/` folder with `data/`, `logic/`, `ui/` subdirectories at lib root level. Use for major features like `auth/`, `library/`, etc

**Add new feature**: Create `feature/` folder with `data/`, `logic/`, `ui/` subdirectories. Add provider to [main.dart](lib/main.dart) MultiProvider. Add routes to [app_router.dart](lib/routing/app_router.dart).

**Add new page**: Create in `ui/`, add route constant + handler to `AppRouter`, use `Navigator.pushNamed()`.

**Fetch Supabase data**: Add method to existing service (e.g., `LibraryService`) or create new repository in `data/`. Call from Provider, update state, notify listeners.

**Implement role check**: Filter data using `user.canAccess(item.minRank)` in Provider BEFORE exposing to UI. See [auth/models/user_profile.dart](lib/auth/models/user_profile.dart).

**Style consistency**: Use `Theme.of(context)` and `AppColors` constants. Never hardcode color values.

## Known Issues & Gotchas
- `go_router` in pubspec but **NOT USED** - manual routing only
- `flutter_riverpod` in pubspec but **Provider** is actual state management
- `.env` file required but not in repo - must create locally
- OTP verification not fully configured (requires Twilio/MessageBird setup in Supabase)
- Android emulator may need `-gpu swiftshader_indirect` flag (see [start_instructions.txt](lib/start_instructions.txt))

## Reference Files
- Architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Auth setup: [lib/auth/AUTH_SETUP.md](lib/auth/AUTH_SETUP.md)
- Main entry: [lib/main.dart](lib/main.dart)
- App root: [lib/app.dart](lib/app.dart)
- Current focus: Implementing role-based file visibility filtering
