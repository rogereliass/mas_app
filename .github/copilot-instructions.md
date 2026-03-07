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
        └── user_approval/  # Example: Admin features
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
- **Feature-specific code**: Group under parent page (e.g., `home/pages/user_approval/`)
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

### Role Definitions & Rankings

The app uses the following canonical roles and numeric rankings (0-100). Use these identifiers when assigning roles, checking access, or filtering content by `min_rank`.

| Role Key | Display Name | Rank |
|---|---:|---:|
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

Keep this list authoritative — update here when adding new roles so other developers and automation reference the correct canonical values.

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
- **Theme logic**: Always use `ThemeProvider` from [core/config/theme_provider.dart](lib/core/config/theme_provider.dart) to read and apply light/dark mode. Do not re-implement theme mode logic per page; every page must reflect app colors via `AppColors` or `Theme.of(context)`.
- **CRITICAL RULE**: Every color in the UI must be wired to either `AppColors.*` constants or `Theme.of(context).colorScheme.*`
  - ❌ WRONG: `Colors.green`, `Colors.grey[600]`, `Color(0xFF...)` hardcoded
  - ✅ RIGHT: `AppColors.success`, `AppColors.textSecondaryLight`, `Theme.of(context).primaryColor`
  - If a color isn't available in AppColors, add it to [app_colors.dart](lib/core/config/app_colors.dart) with clear documentation

### 4.1 Current User Data (SharedPreferences)
When you only need the currently logged-in user's cached data (ID, name, phone, auth status), fetch it from SharedPreferences via `AuthProvider` helpers, not directly from Supabase.
- Use `AuthProvider.getUserId()`, `AuthProvider.getUserFullName()`, `AuthProvider.getUserPhone()`, and `AuthProvider.isUserAuthenticated()`.
- Do not access SharedPreferences keys directly outside `AuthProvider`.
- Use Supabase only when fresh server data is required (e.g., profile/roles refresh).

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
- **Page-specific features**: Organize under parent page in `pages/` subdirectory (e.g., `home/pages/user_approval/`)
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

Example: `home/pages/user_approval/` with data/logic/ui structure

**Add standalone feature module**: Create `feature/` folder with `data/`, `logic/`, `ui/` subdirectories at lib root level. Use for major features like `auth/`, `library/`, etc

**Add new feature**: Create `feature/` folder with `data/`, `logic/`, `ui/` subdirectories. Add provider to [main.dart](lib/main.dart) MultiProvider. Add routes to [app_router.dart](lib/routing/app_router.dart).

**Add new page**: Create in `ui/`, add route constant + handler to `AppRouter`, use `Navigator.pushNamed()`.

**Fetch Supabase data**: Add method to existing service (e.g., `LibraryService`) or create new repository in `data/`. Call from Provider, update state, notify listeners.

**Implement role check**: Filter data using `user.canAccess(item.minRank)` in Provider BEFORE exposing to UI. See [auth/models/user_profile.dart](lib/auth/models/user_profile.dart).

**Style consistency**: Use `Theme.of(context)` and `AppColors` constants. Never hardcode color values.

## 🚨 CRITICAL: Responsive Design & Performance Rules

**THESE RULES PREVENT APP CRASHES AND PERFORMANCE ISSUES**

### 1. **Dropdown Overflow Prevention** ⚠️ CRASH RISK
Every `DropdownButtonFormField` MUST follow these rules:

```dart
DropdownButtonFormField<String?>(
  value: selectedValue,
  isExpanded: true,  // ✅ REQUIRED - prevents overflow crashes
  // For rich/multi-line items, always use selectedItemBuilder
  selectedItemBuilder: (context) {
    return items.map((e) => Align(
      alignment: Alignment.centerLeft,
      child: Text(e.name, style: TextStyle(fontWeight: FontWeight.bold)),
    )).toList();
  },
  itemHeight: 60, // ✅ REQUIRED if children are multi-line/rich
  decoration: InputDecoration(
    labelText: 'Label',
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  items: items.map((item) {
    return DropdownMenuItem<String>(
      value: item.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.name, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(item.subtitle, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }).toList(),
  onChanged: (value) => handleChange(value),
);
```

**Why**: Without `isExpanded: true` and `selectedItemBuilder` for rich content, dropdowns will crash with `RenderFlex overflowed` errors. `itemHeight` must be sufficiently large to contain the custom item UI.

### 2. **Responsive Layout Requirements**
Use `LayoutBuilder` or `MediaQuery` for responsive layouts:

```dart
// Good: Adaptive layout based on screen width
LayoutBuilder(
  builder: (context, constraints) {
    final useVerticalLayout = constraints.maxWidth < 500;
    
    if (useVerticalLayout) {
      return Column(children: widgets);
    } else {
      return Row(
        children: widgets.map((w) => Expanded(child: w)).toList(),
      );
    }
  },
)

// Good: Responsive padding/sizing
final screenWidth = MediaQuery.of(context).size.width;
final isNarrow = screenWidth < 600;
final padding = isNarrow ? 8.0 : 16.0;
```

**Never** assume a fixed screen size. Support:
- Small phones (360px width)
- Large phones (400-500px)
- Tablets (600-1000px)
- Desktops (1024px+)

### 2.1 **Dialog & Modal Stability**
To prevent overflows in Dialogs (especially with keyboards open):
- **Always** wrap Dialog content in `SingleChildScrollView`.
- Use `Dialog` widget with a constrained `BoxConstraints(maxWidth: ...)` instead of `AlertDialog` for more premium/custom control.
- Avoid hardcoded heights inside flex parents; use `mainAxisSize: MainAxisSize.min` for vertical columns.

### 2.2 **Modal Error Handling (Required)**
When a dialog/modal is open:
- **Never** show errors using `ScaffoldMessenger`/`SnackBar` (they can render behind the modal).
- Show validation and submit errors **inside the modal** using field validators (`errorText`) or an inline error container.
- Keep the modal open on errors so the user can correct fields immediately.

### 3. **Text Overflow Protection**
ALWAYS add overflow handling to text widgets in constrained spaces:

```dart
// In Cards, ListTiles, Rows, or any constrained layout:
Text(
  longText,
  style: textStyle,
  overflow: TextOverflow.ellipsis,  // ✅ Truncates with ...
  maxLines: 1,  // ✅ Prevents multi-line overflow
)

// In Expanded/Flexible widgets:
Expanded(
  child: Text(
    longText,
    overflow: TextOverflow.ellipsis,
  ),
)
```

### 4. **Performance: Debouncing User Input**
For frequently called operations (search, change detection):

```dart
Timer? _debounceTimer;

void _onFieldChanged() {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 150), () {
    _performExpensiveOperation();
  });
}

@override
void dispose() {
  _debounceTimer?.cancel();  // ✅ REQUIRED - prevent memory leaks
  super.dispose();
}
```

**Why**: Calling expensive operations on every keystroke causes:
- Severe performance degradation
- UI lag and jank
- Battery drain
- Poor user experience

**Rule**: Debounce any operation triggered by text field changes (search filters, validation, change detection).

### 5. **Performance: Filter Result Caching**
Cache expensive computations in providers:

```dart
class MyProvider with ChangeNotifier {
  List<Item> _items = [];
  List<Item>? _cachedFilteredItems;
  String? _lastSearchQuery;
  
  List<Item> get filteredItems {
    // Return cached result if filters unchanged
    if (_cachedFilteredItems != null && _lastSearchQuery == _searchQuery) {
      return _cachedFilteredItems!;
    }
    
    // Recalculate and cache
    final filtered = _items.where((item) => 
      item.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
    
    _cachedFilteredItems = filtered;
    _lastSearchQuery = _searchQuery;
    
    return filtered;
  }
  
  void _clearFilterCache() {
    _cachedFilteredItems = null;
  }
  
  void loadItems() {
    // Load items...
    _clearFilterCache();  // ✅ Clear cache when data changes
    notifyListeners();
  }
}
```

### 6. **Widget Lifecycle Management** ⚠️ CRITICAL
Proper cleanup prevents memory leaks and lifecycle errors:

```dart
@override
void dispose() {
  // Cancel timers
  _debounceTimer?.cancel();
  
  // Remove listeners BEFORE disposing
  _controller.removeListener(_onChanged);
  
  // Dispose controllers
  _controller.dispose();
  
  // Call super last
  super.dispose();
}
```

**🚨 NEVER use `context.read()`, `context.watch()`, or `Provider.of()` in dispose()** - causes "Looking up deactivated widget's ancestor" errors:

```dart
// ❌ WRONG - crashes with "Looking up deactivated widget's ancestor"
@override
void dispose() {
  context.read<MyProvider>().clearState();  // ❌ DON'T DO THIS!
  super.dispose();
}

// ❌ ALSO WRONG - still crashes
@override
void dispose() {
  Provider.of<MyProvider>(context, listen: false).clearState();  // ❌ DON'T DO THIS!
  super.dispose();
}

// ✅ RIGHT - store provider reference in initState or didChangeDependencies
late MyProvider _provider;

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _provider = context.read<MyProvider>();
}

@override
void dispose() {
  // Can use _provider reference safely (but usually not needed)
  // State cleanup should happen elsewhere, not in dispose
  super.dispose();
}

// ✅ BEST - Don't call provider methods in dispose at all
// Let providers manage their own state lifecycle
@override
void dispose() {
  _searchController.dispose();
  _debounceTimer?.cancel();
  super.dispose();
}
```

**Do NOT** use `addPostFrameCallback` in dispose - it can cause state updates on disposed widgets:

```dart
// ❌ WRONG - causes crashes
@override
void dispose() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    provider.cleanup();  // Called AFTER dispose!
  });
  super.dispose();
}
```

### 7. **ListView Optimization**
Add keys for efficient list updates:

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return MyCard(
      key: ValueKey(item.id),  // ✅ REQUIRED for filtered/sorted lists
      item: item,
    );
  },
)
```

### 8. **Component Extraction Guidelines**
Keep files under 500 lines. Extract components when:
- A widget is 100+ lines
- A widget is reused multiple times
- A file exceeds 500 lines total

**Reusable components** → `core/widgets/`  
**Feature-specific components** → `feature/ui/components/`

### 9. **didUpdateWidget Implementation**
Stateful widgets that accept initial values MUST implement `didUpdateWidget`:

```dart
@override
void didUpdateWidget(MyWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.initialValue != oldWidget.initialValue) {
    setState(() {
      _currentValue = widget.initialValue;
    });
  }
}
```

### 10. **Color Usage Enforcement**
Run color audit before committing:
1. Search for `Colors.` (except `Colors.transparent`)
2. Search for `Color(0x`
3. Search for `.shade` (Colors.grey.shade700, etc.)
4. Replace ALL with `AppColors.*` or `theme.colorScheme.*`

**Common Replacements**:
- `Colors.grey.shade700` → `theme.colorScheme.outline`
- `Colors.grey.shade300` → `theme.colorScheme.outlineVariant`
- `Colors.grey` → `theme.colorScheme.onSurfaceVariant`
- `Colors.white` → `colorScheme.surface`
- `Colors.transparent` → OK to keep

### 11. **Form Validation Best Practices**
```dart
// Email validation (RFC 5322 compliant)
final emailRegex = RegExp(
  r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
);

// Null-safe substring operations
final initial = name.trim().isNotEmpty 
    ? name.trim().substring(0, 1).toUpperCase()
    : '?';
```

### 12. **Unsaved Changes Protection**
Implement for forms with multiple fields:

```dart
PopScope(
  canPop: !_hasUnsavedChanges || _isSaving,
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop) return;
    final shouldDiscard = await _showUnsavedChangesDialog();
    if (shouldDiscard && mounted) {
      Navigator.of(context).pop();
    }
  },
  child: YourFormWidget(),
)
```

## Known Issues & Gotchas
- `go_router` in pubspec but **NOT USED** - manual routing only
- `flutter_riverpod` in pubspec but **Provider** is actual state management
- `.env` file required but not in repo - must create locally
- OTP verification not fully configured (requires Twilio/MessageBird setup in Supabase)
- Android emulator may need `-gpu swiftshader_indirect` flag (see [start_instructions.txt](lib/start_instructions.txt))

## Code Quality Checklist

Before marking any feature as complete, verify:

### **Responsiveness** ✅
- [ ] All dropdowns have `isExpanded: true`
- [ ] All text in constrained layouts has `overflow: TextOverflow.ellipsis`
- [ ] Layouts use `LayoutBuilder` or `MediaQuery` for screen size adaptation
- [ ] Tested on screen widths: 360px, 500px, 600px, 1024px
- [ ] No hardcoded widths/heights that break on different screens

### **Performance** ⚡
- [ ] Text field listeners are debounced (150ms)
- [ ] Expensive computations are cached in providers
- [ ] ListViews have proper keys (`ValueKey(item.id)`)
- [ ] No unnecessary rebuilds (check with DevTools)

### **Memory Management** 🧹
- [ ] All controllers disposed in `dispose()`
- [ ] All listeners removed before disposal
- [ ] All timers cancelled in `dispose()`
- [ ] No `addPostFrameCallback` in `dispose()`
- [ ] `didUpdateWidget` implemented for stateful widgets with initial values

### **Theme Consistency** 🎨
- [ ] Zero hardcoded colors (`Colors.*`, `Color(0x...)`, `.shade`)
- [ ] All colors use `AppColors.*` or `theme.colorScheme.*`
- [ ] Dark mode properly supported
- [ ] Tested in both light and dark themes

### **Code Organization** 📁
- [ ] Files under 500 lines (extract components if larger)
- [ ] Reusable widgets in `core/widgets/`
- [ ] Feature-specific components in `feature/ui/components/`
- [ ] Proper documentation comments on public APIs
- [ ] README.md in feature folder

### **Error Handling** 🚨
- [ ] Form validation with helpful error messages
- [ ] Loading states for async operations
- [ ] Error states with retry options
- [ ] Empty states with context-aware messages and CTAs
- [ ] Unsaved changes warnings for forms

### **Null Safety** 🛡️
- [ ] Safe string operations (`.trim()` before `.substring()`)
- [ ] Null checks before using optional values
- [ ] No unsafe null assertions (`!`) without validation
- [ ] Email/phone validation uses proper regex

### **Accessibility** ♿
- [ ] Semantic labels for screen readers
- [ ] Sufficient color contrast ratios
- [ ] Tap targets at least 44x44 pixels
- [ ] Keyboard navigation support where applicable

## Example: User Management Feature

The [user management feature](lib/home/pages/user_management/) demonstrates best practices:

**Component Structure**:
- ✅ Main page reduced from 1255 lines to ~200 lines via component extraction
- ✅ Extracted components: `UserCard`, `UserEditDialog`, `RoleAssignmentSection`
- ✅ Reusable `GenderSelector` in `core/widgets/`

**Responsive Design**:
- ✅ Vertical/horizontal filter layouts based on screen width
- ✅ All dropdowns with `isExpanded: true` and `TextOverflow.ellipsis`
- ✅ Adaptive padding and icons sizes

**Performance**:
- ✅ Debounced search (300ms delay)
- ✅ Debounced change detection in edit dialog (150ms)
- ✅ Cached filter results with automatic invalidation

**Features**:
- ✅ Search & filter functionality
- ✅ Unsaved changes protection with PopScope
- ✅ Context-aware empty states
- ✅ Comprehensive README.md documentation

**Code Quality**:
- ✅ Zero hardcoded colors
- ✅ All text overflow protected
- ✅ Proper disposal of controllers/timers/listeners
- ✅ ListView keys for efficient updates

Reference this feature when implementing similar functionality.

## Reference Files
- Architecture: [ARCHITECTURE.md](ARCHITECTURE.md)
- Auth setup: [lib/auth/AUTH_SETUP.md](lib/auth/AUTH_SETUP.md)
- Main entry: [lib/main.dart](lib/main.dart)
- App root: [lib/app.dart](lib/app.dart)
- Current focus: Refining role-specific dashboard views (Troop Leader/Head) in HomePage.
