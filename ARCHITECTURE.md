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
