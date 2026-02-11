# MAS App Architecture Documentation

## Overview
The MAS app follows a **clean architecture** pattern with clear separation of concerns, making it maintainable, testable, and extensible.

## Architecture Principles

### 1. **Feature-Based Folder Structure**
The codebase is organized by features, not by file types:
```
lib/
├── core/           # Shared functionality
├── auth/           # Authentication feature
├── library/        # Library feature
├── offline/        # Offline functionality
├── startup/        # Startup/landing pages
└── routing/        # Navigation configuration
```

### 2. **Separation of Concerns**
Each feature follows a layered architecture:
- **UI Layer** (`ui/`): Presentation components, pages, widgets
- **Logic Layer** (`logic/`): State management (Providers)
- **Data Layer** (`data/`): Models and data structures

Example from library feature:
```
library/
├── data/
│   └── library_models.dart      # Data models (FolderModel, FileModel)
├── logic/
│   └── library_provider.dart    # Business logic & state
└── ui/
    ├── components/               # Reusable UI components
    ├── folder_page.dart          # Feature pages
    └── folder_detail_page.dart
```

### 3. **Centralized Configuration**
All configuration lives in dedicated locations:

#### **Theme System** (`core/config/`)
- `app_colors.dart`: Single source of truth for all colors
- `theme_config.dart`: Material 3 theme configurations
- `theme_provider.dart`: Theme state management with persistence

**Benefits:**
- Easy theme switching (light/dark)
- Consistent colors across the app
- No hardcoded color values in components

#### **Routing** (`routing/`)
- `app_router.dart`: Centralized navigation logic
- Route constants prevent typos
- Navigation helpers for common patterns
- Handles breadcrumb navigation

**Benefits:**
- Type-safe navigation
- Easy to modify routes
- Clear navigation flow

### 4. **Reusable Components**
UI components are extracted and reusable:

#### **Library Components** (`library/ui/components/`)
- `custom_search_bar.dart`: Search input with theme support
- `folder_card.dart`: Folder display card
- `file_tile.dart`: File list item with type icons
- `filter_chip_row.dart`: Category filter chips
- `bottom_nav_bar.dart`: Bottom navigation

#### **Core Widgets** (`core/widgets/`)
- `loading_view.dart`: Loading indicators
- `error_view.dart`: Error states with retry
- `empty_view.dart`: Empty state displays

**Benefits:**
- DRY (Don't Repeat Yourself)
- Consistent UI across screens
- Easy to maintain and update
- Theme-aware by default

### 5. **State Management**
Using **Provider** pattern for predictable state:

#### **ThemeProvider** (`core/config/`)
Manages app-wide theme state with persistence:
```dart
// Usage
final themeProvider = Provider.of<ThemeProvider>(context);
themeProvider.toggleTheme();
```

#### **LibraryProvider** (`library/logic/`)
Manages library data and business logic:
```dart
// Provides:
- folders: List<FolderModel>
- recentFiles: List<FileModel>
- filteredFolders: Filtered by category
- searchFolders(query): Search functionality
- fetchFolders(): Data fetching
```

**Benefits:**
- Reactive UI updates
- Separates business logic from UI
- Easy to test
- Single source of truth

### 6. **Immutable Data Models**
All data models are immutable with proper factories:

#### **FolderModel** (`library/data/library_models.dart`)
```dart
class FolderModel {
  final String id;
  final String name;
  final int itemCount;
  
  // Factory constructors
  factory FolderModel.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  
  // Copy with pattern
  FolderModel copyWith({...});
}
```

**Benefits:**
- Predictable data flow
- Easy serialization/deserialization
- Type safety
- Prevents accidental mutations

### 7. **Role-Based Access Control**
Centralized permission system (`core/utils/role_utils.dart`):

```dart
enum UserRole {
  admin,    // Full access
  editor,   // Can edit content
  viewer,   // Read-only
  guest     // Limited access
}

// Check permissions
if (role.canEdit) {
  // Show edit button
}
```

**Benefits:**
- Centralized permission logic
- Easy to extend
- Type-safe role checking

## Design System

### Material 3 Implementation
The app uses Material 3 design system with:
- Dynamic color schemes (light/dark)
- Consistent spacing and typography
- Elevation and shadow system
- Component theming

### Theme-Aware Components
All components automatically adapt to theme:
- Colors from `app_colors.dart`
- Use `Theme.of(context)` for dynamic values
- Respect user's theme preference

### Accessibility
- Semantic labels on interactive elements
- Sufficient color contrast
- Touch target sizes (48x48dp minimum)
- Screen reader support

## Data Flow

### 1. **Reading Data**
```
Supabase → Provider → UI
```
- Provider fetches from Supabase
- Transforms to models
- Notifies listeners
- UI rebuilds with new data

### 2. **User Actions**
```
UI → Provider → Supabase → Update UI
```
- User interacts with UI
- Calls provider method
- Provider updates backend
- Notifies listeners on success/error

### 3. **Offline Support** (Planned)
```
Supabase → Hive (cache) → UI
```
- Data cached in Hive
- Offline-first approach
- Sync when online

## Navigation Flow

### Route Structure
```
/startup          → Landing page
/login            → Authentication
/library          → Main library (folder_page.dart)
/library/folder   → Folder detail with breadcrumbs
/library/all      → All folders grid
/library/about    → About page
```

### Navigation Patterns

#### **Simple Navigation**
```dart
Navigator.pushNamed(context, AppRouter.library);
```

#### **With Arguments**
```dart
Navigator.pushNamed(
  context,
  AppRouter.folderDetail,
  arguments: {
    'folderId': '123',
    'folderName': 'Documents',
  },
);
```

#### **Breadcrumb Navigation**
```dart
AppRouter.goToFolder(
  context,
  folderId: '456',
  folderName: 'Subfolder',
  breadcrumbs: ['Parent', 'Child'],
);
```

## Extensibility

### Adding New Features

#### 1. **Create Feature Folder**
```
lib/new_feature/
├── data/
│   └── models.dart
├── logic/
│   └── provider.dart
└── ui/
    ├── components/
    └── pages/
```

#### 2. **Add Routes**
Update `routing/app_router.dart`:
```dart
static const String newFeature = '/new_feature';

static final routes = {
  // ...existing routes
  newFeature: (context) => const NewFeaturePage(),
};
```

#### 3. **Add Provider** (if needed)
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => NewFeatureProvider()),
  ],
  child: const MyApp(),
);
```

### Adding New Colors
Update `core/constants/app_colors.dart`:
```dart
static const Color newColor = Color(0xFF123456);
```

### Adding New Components
Create in appropriate location:
- Feature-specific: `feature/ui/components/`
- Shared: `core/widgets/`

Follow naming convention:
- Widgets: `my_widget.dart` with `MyWidget` class
- Pages: `my_page.dart` with `MyPage` class

## Testing Strategy

### Unit Tests
- Test providers in isolation
- Test model serialization
- Test utility functions

### Widget Tests
- Test individual components
- Mock dependencies
- Verify UI behavior

### Integration Tests
- Test complete user flows
- Test navigation
- Test data persistence

## Backend Integration

### Supabase Setup
Configuration in `core/config/supabase_config.dart`:
```dart
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_ANON_KEY';
}
```

### Database Schema (Expected)
```sql
-- Folders table
CREATE TABLE folders (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  parent_id UUID REFERENCES folders(id),
  item_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  modified_at TIMESTAMP DEFAULT NOW()
);

-- Files table
CREATE TABLE files (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  folder_id UUID REFERENCES folders(id),
  url TEXT,
  thumbnail_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  modified_at TIMESTAMP DEFAULT NOW()
);
```

### API Patterns
```dart
// Fetch data
final response = await supabase
    .from('folders')
    .select()
    .order('name');

// Insert data
await supabase
    .from('folders')
    .insert({'name': 'New Folder'});

// Update data
await supabase
    .from('folders')
    .update({'name': 'Updated'})
    .eq('id', folderId);

// Delete data
await supabase
    .from('folders')
    .delete()
    .eq('id', folderId);
```

## Code Quality Standards

### Formatting
- Use `dart format` for consistent formatting
- 2-space indentation
- Max line length: 80 characters (where practical)

### Documentation
- Class-level documentation for all public classes
- Method documentation for complex logic
- Inline comments for non-obvious code

### Error Handling
```dart
try {
  await fetchData();
} catch (e) {
  _errorMessage = 'User-friendly error message: $e';
  notifyListeners();
}
```

### Constants
- Use `const` constructors where possible
- Extract magic numbers to named constants
- Use enums for fixed sets of values

## Performance Considerations

### Optimization Patterns
1. **Lazy Loading**: Load data on-demand
2. **Pagination**: Fetch data in chunks
3. **Caching**: Use Hive for offline access
4. **Image Optimization**: Use cached_network_image
5. **List Performance**: Use ListView.builder for long lists

### Memory Management
- Dispose controllers and subscriptions
- Use weak references where appropriate
- Profile with DevTools

## Security Best Practices

### API Keys
- Store in environment variables
- Never commit to version control
- Use Supabase RLS (Row Level Security)

### Authentication
- Use Supabase Auth
- Store tokens securely
- Handle session expiration

### Data Validation
- Validate user input
- Sanitize before sending to backend
- Use proper typing

## Scoped Admin Features Pattern

Admin features (user management, meeting manager, etc.) use a **single-file architecture** with automatic role-based data scoping. The same code serves both system-wide admins and troop-scoped leaders.

### Access Levels
- **System Admin (rank 100)**: Full access to all troops
- **Moderator (rank 90)**: Full access to all troops  
- **Troop Head (rank 70)**: Access limited to their assigned troop
- **Troop Leader (rank 60)**: Access limited to their assigned troop

### Implementation Pattern

Admin features follow this architecture to enable automatic troop-scoping without code duplication:

#### 1. **Service Layer** (data/)
Mix in `ScopedServiceMixin` and require `UserProfile` parameter:
```dart
class AdminService with ScopedServiceMixin {
  Future<List<Data>> fetchData({required UserProfile currentUser}) async {
    var query = supabase.from('table').select();
    query = applyScopeFilter(query, currentUser, 'signup_troop');
    return await query;
  }
}
```

#### 2. **Provider Layer** (logic/)
Inject `AuthProvider` and pass current user to service:
```dart
class AdminProvider extends ChangeNotifier {
  final AdminService _service;
  final AuthProvider _authProvider;
  
  AdminProvider({required AuthProvider authProvider})
    : _authProvider = authProvider;
    
  Future<void> loadData() async {
    final currentUser = _authProvider.currentUserProfile!;
    _data = await _service.fetchData(currentUser: currentUser);
    notifyListeners();
  }
}
```

#### 3. **UI Layer** (ui/)
Gate access at rank 60+ and display scope banner:
```dart
class AdminPage extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    // Allow all admin tiers (60, 70, 90, 100)
    if (authProvider.currentUserRoleRank < 60) {
      Navigator.pop(context);
      return;
    }
    provider.loadData();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AdminScopeBanner(),  // Shows scope automatically
          Expanded(child: DataList()),
        ],
      ),
    );
  }
}
```

### Database Schema

Troop context is stored in the `profile_roles` junction table:
```sql
ALTER TABLE profile_roles 
  ADD COLUMN troop_context uuid REFERENCES troops(id);
```

- **System-wide roles** (rank 90+): `troop_context = NULL`
- **Troop-scoped roles** (rank 60, 70): `troop_context = <troop_id>`

### Benefits

1. **No Code Duplication**: Single codebase for all admin tiers - DRY principle maintained
2. **Automatic Filtering**: Data layer handles scoping transparently based on current user
3. **Type-Safe**: Compile-time enforcement via required parameters prevents forgetting user context
4. **Secure**: Multi-layer security (app-level filtering + RLS policies provide defense-in-depth)
5. **Transparent**: AdminScopeBanner clearly shows users their operational scope
6. **Maintainable**: Adding new roles (e.g., District Leader) requires minimal changes
7. **Testable**: Easy to test different roles by swapping `currentUser` parameter
8. **Performant**: Database-level filtering via indexed columns

### Feature Template

When creating new scoped admin features:

**Checklist:**
- ✅ Service: `with ScopedServiceMixin`
- ✅ Service methods: Add `required UserProfile currentUser` parameter
- ✅ Service queries: Call `applyScopeFilter(query, currentUser, 'troop_column')`
- ✅ Provider: Inject `AuthProvider`, pass `currentUser` to service methods
- ✅ Provider registration: Use `ChangeNotifierProxyProvider<AuthProvider, YourProvider>`
- ✅ Page authorization: Gate at `rank >= 60` (not `rank >= 100`)
- ✅ Page UI: Add `AdminScopeBanner()` widget for transparency
- ✅ Test: Verify with both system admin (100/90) AND troop leader (60/70) accounts

**Example Structure:**
```
home/pages/user_management/
├── data/
│   ├── user_management_service.dart  ← with ScopedServiceMixin
│   └── models/
├── logic/
│   └── user_management_provider.dart ← passes currentUser from AuthProvider
└── ui/
    ├── user_management_page.dart     ← rank >= 60 check + AdminScopeBanner
    └── components/
```

Same pattern applies to: User Acceptance (implemented), User Management, Meeting Manager, Patrol CRUD, Troop Operations, Points Management, and all future admin features.

## Future Enhancements

### Planned Features
- [ ] Offline file downloads
- [ ] File viewer implementation
- [ ] Advanced search with filters
- [ ] User profile management
- [ ] Push notifications
- [ ] File sharing capabilities
- [ ] Activity tracking

### Technical Debt
- Replace mock data with Supabase queries
- Implement proper error handling
- Add comprehensive tests
- Add loading states
- Implement retry logic

## Conclusion

This architecture provides:
- **Maintainability**: Clear structure and separation
- **Scalability**: Easy to add features
- **Testability**: Isolated components
- **Consistency**: Centralized theming and routing
- **Quality**: Type-safe, documented code

The codebase follows Flutter best practices and is ready for production deployment with proper backend integration.
