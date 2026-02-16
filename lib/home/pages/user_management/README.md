# User Management Module

## Feature Overview

The User Management module provides administrative capabilities for managing user profiles, roles, and permissions within the MAS App. This feature enables authorized personnel to view, edit, and assign roles to users based on their administrative level and troop context.

### Who Can Use This Feature

- **Troop Leaders** (Rank ≥ 60, < 90): Manage users within their assigned troop only
- **System Administrators** (Rank ≥ 90): Manage all users across all troops

### Key Capabilities

- **User Discovery**: Search and filter users by name, role, or troop
- **Profile Management**: Edit comprehensive user profile information
- **Role Assignment**: Assign multiple roles with troop context when applicable
- **Access Control**: Automatic scoping based on administrator permissions
- **Real-time Updates**: Changes sync immediately with Supabase backend
- **Unsaved Changes Protection**: Warns users before discarding edits

---

## Architecture

This feature follows the **3-layer clean architecture** pattern:

```
user_management/
├── data/              # Data Layer
│   ├── models/
│   │   └── managed_user_profile.dart    # Domain model
│   └── user_management_service.dart     # Supabase integration
├── logic/             # Business Logic Layer
│   └── user_management_provider.dart    # State management
├── ui/                # Presentation Layer
│   ├── components/
│   │   ├── user_card.dart               # User list item
│   │   ├── user_edit_dialog.dart        # Edit form dialog
│   │   └── role_assignment_section.dart # Role management UI
│   └── user_management_page.dart        # Main page
└── user_management.dart                  # Module exports
```

### Layer Responsibilities

#### Data Layer (`data/`)

**[user_management_service.dart](data/user_management_service.dart)**
- Handles all Supabase database operations
- Implements `ScopedServiceMixin` for automatic troop filtering
- Methods:
  - `fetchUsers()` - Load users with roles and troop context
  - `getProfileById()` - Fetch single user profile
  - `updateProfile()` - Update user profile fields
  - `assignRoles()` - Update role assignments with troop context
  - `fetchTroops()` - Load available troops for role assignment

**[models/managed_user_profile.dart](data/models/managed_user_profile.dart)**
- Immutable domain model for user profiles
- Includes `RoleAssignment` class for role-troop relationships
- Computed properties: `fullName`, `primaryRole`
- JSON serialization/deserialization

#### Logic Layer (`logic/`)

**[user_management_provider.dart](logic/user_management_provider.dart)**
- `ChangeNotifier`-based state management
- Integrates with `AuthProvider` for permission checks
- Features:
  - User list state management
  - Search and filter logic
  - Role context selection (for multi-role admins)
  - CRUD operations with error handling
- Key Methods:
  - `loadUsers()` - Fetch and filter users
  - `loadRoles()` - Load available roles
  - `updateUser()` - Update profile with validation
  - `setRoleContext()` / `clearRoleContext()` - Multi-role support

#### UI Layer (`ui/`)

**[user_management_page.dart](ui/user_management_page.dart)**
- Main page scaffold with AppBar, search, and filters
- Permission validation on page load
- Empty states and error handling
- Search debouncing (300ms)
- Role context banner for multi-role admins

**Components** (see [Components](#components) section below)

---

## Features

### 1. User Listing with Search and Filters

- **Real-time Search**: Debounced search across names (Arabic and English)
- **Role Filter**: Filter users by assigned role
- **Troop Filter**: Filter users by signup troop
- **Automatic Scoping**: 
  - Troop leaders see only their troop's users
  - System admins see all users
- **Responsive Grid**: Adapts layout for different screen sizes

### 2. User Profile Editing

- **Comprehensive Form**: Edit all profile fields
  - Personal info: First/middle/last name, Arabic name
  - Contact: Email, phone, address
  - Demographics: Birthdate, gender, generation
  - Scout info: Organization ID, scout code
  - Medical: Medical notes, allergies
- **Form Validation**: Required fields marked, validation on submit
- **Responsive Dialog**: Adapts to screen size (mobile scrollable, tablet/desktop in-dialog scroll)

### 3. Role Assignment with Troop Context

- **Multi-Role Support**: Assign multiple roles simultaneously
- **Troop Context**: Required dropdown for troop-scoped roles (ranks 60, 70)
- **Visual Indicators**: Shows current vs. new assignments
- **Permission-Based**: Only shows assignable roles based on admin rank
- **Validation**: Ensures troop context provided when required

### 4. Empty States

- **No Users Found**: Guides user to adjust filters or add users
- **Loading States**: Shows loading indicators during data fetch
- **Error States**: Displays user-friendly error messages

### 5. Unsaved Changes Protection

- **Change Detection**: Tracks form modifications
- **Confirmation Dialog**: Warns before discarding changes
- **Save/Cancel Actions**: Clear save paths with feedback

---

## Components

### UserCard

**File**: [ui/components/user_card.dart](ui/components/user_card.dart)

Displays a user profile card in the user list.

**Features**:
- Avatar with initials
- Full name and primary role badge
- Contact info (email, phone)
- Signup troop display
- Edit button

**Usage**:
```dart
UserCard(
  profile: userProfile,
  onEdit: () => _showEditDialog(userProfile),
)
```

**When to Use**: In list views to display user summaries with quick edit access.

---

### UserEditDialog

**File**: [ui/components/user_edit_dialog.dart](ui/components/user_edit_dialog.dart)

Comprehensive dialog for editing user profiles with role management.

**Features**:
- All profile field editing
- Integrated role assignment section
- Form validation
- Unsaved changes protection
- Responsive layout (full-screen on mobile, dialog on tablet+)
- Theme-aware styling

**Usage**:
```dart
await showDialog(
  context: context,
  builder: (context) => UserEditDialog(profile: userProfile),
);
```

**When to Use**: When users need to edit any aspect of a user profile, including roles.

---

### RoleAssignmentSection

**File**: [ui/components/role_assignment_section.dart](ui/components/role_assignment_section.dart)

Feature-specific component for managing role assignments.

**Features**:
- Checkbox list for role selection
- Troop context dropdown for troop-scoped roles (ranks 60, 70)
- Visual indicators for current assignments
- Permission-based editing
- Form validation for required troop context
- Responsive layout

**Usage**:
```dart
RoleAssignmentSection(
  selectedRoles: _selectedRoles,
  availableRoles: assignableRoles,
  profile: userProfile,
  troops: _troops,
  roleTroopContext: _roleTroopContext,
  canEditRole: true,
  isLoadingTroops: false,
  isRolesReady: true,
  onRoleToggled: (role, isSelected) { /* ... */ },
  onTroopContextChanged: (roleId, troopId) { /* ... */ },
)
```

**When to Use**: Embedded within forms where role assignment is needed, typically in user edit dialogs.

---

### GenderSelector

**File**: [core/widgets/gender_selector.dart](../../core/widgets/gender_selector.dart) (shared component)

Reusable gender selection widget with segmented button UI.

**Features**:
- Material 3 styled segmented buttons
- Male/Female options
- Theme-aware styling
- Callback on selection change

**Usage**:
```dart
GenderSelector(
  selectedGender: _selectedGender,
  onGenderChanged: (gender) {
    setState(() => _selectedGender = gender);
  },
)
```

**When to Use**: In any form requiring gender input. Located in `core/widgets` as it's reusable across features.

---

## Role-Based Access Control

### How RBAC Works in User Management

The User Management feature implements **hierarchical role-based access control** with troop scoping:

1. **Rank-Based Permissions**:
   - Rank < 60: No access (redirected)
   - Rank 60-89 (Troop Leaders): Access users in their assigned troop only
   - Rank ≥ 90 (System Admins): Access all users across all troops

2. **Multi-Role Support**:
   - Admins with multiple roles can select which role context to use
   - Role context determines effective rank and troop scope
   - Banner displays current role context

3. **Automatic Filtering**:
   - `ScopedServiceMixin` in service layer applies troop filters
   - Troop leaders automatically filtered to `managedTroopId`
   - System admins see unfiltered user list

4. **Role Assignment Restrictions**:
   - Admins can only assign roles up to their own rank
  - Troop leaders can only assign roles with rank 1-40 within their troop
  - Troop leaders cannot assign troop-scoped roles (rank 60/70)
   - System admins can assign any role with any troop context

### Permission Requirements

| Feature | Troop Leader (≥60, <90) | System Admin (≥90) |
|---------|-------------------------|---------------------|
| View users | Own troop only | All troops |
| Edit profiles | Own troop only | All users |
| Assign roles | Ranks 1-40 only (same troop) | Any role, any context |
| Change troop context | None | Yes |
| Manage system roles | None | Yes |

### Role Context Filtering

When an admin has multiple roles and selects a specific role context:

```dart
// Example: Admin selects "Troop Leader" role
userProvider.setRoleContext('Troop Leader');

// Effective rank and troop scope change accordingly
final effectiveRank = authProvider.getRankForRole('Troop Leader');
// Users filtered to that role's troop scope
```

### Troop Scoping

**Troop-Scoped Roles** (ranks 60, 70):
- Require a troop context (which troop the role applies to)
- Dropdown automatically appears when these roles are selected
- Validation ensures troop context is provided before saving
- Assignment is limited to system admins (rank ≥ 90)

**System Roles** (ranks <60 or ≥80):
- No troop context required
- Apply globally across all troops

---

## Usage Examples

### Navigating to User Management

```dart
// From anywhere in the app with route constants
Navigator.pushNamed(
  context,
  AppRouter.userManagement,
);

// With specific role context (for multi-role admins)
Navigator.pushNamed(
  context,
  AppRouter.userManagement,
  arguments: {'selectedRole': 'District Commissioner'},
);
```

### Using with Provider

```dart
// In a widget
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserManagementProvider>(context);
    
    if (userProvider.isLoadingUsers) {
      return LoadingView();
    }
    
    if (userProvider.hasError) {
      return ErrorView(message: userProvider.error);
    }
    
    final filteredUsers = userProvider.filteredUsers;
    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        return UserCard(
          profile: filteredUsers[index],
          onEdit: () => _editUser(filteredUsers[index]),
        );
      },
    );
  }
}
```

### Updating a User Profile

```dart
// In your widget
Future<void> _updateUser(ManagedUserProfile profile) async {
  final provider = context.read<UserManagementProvider>();
  
  await provider.updateUser(
    profileId: profile.id,
    updates: {
      'first_name': 'John',
      'last_name': 'Doe',
      'email': 'john.doe@example.com',
    },
    roleIds: ['role-id-1', 'role-id-2'],
    roleTroopContext: {
      'role-id-1': 'troop-id-1', // For troop-scoped roles
    },
  );
  
  if (provider.hasError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.error!)),
    );
  } else {
    // Success - users list automatically refreshed
  }
}
```

### Implementing Search

```dart
class UserManagementPage extends StatefulWidget {
  // ...
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  
  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Debounce search for 300ms
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final provider = context.read<UserManagementProvider>();
      provider.setSearchQuery(query);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search users...',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}
```

---

## Development Guidelines

### Adding New Features

1. **Data Layer First**: Add methods to `UserManagementService`
   ```dart
   Future<Result> fetchSomeData() async {
     try {
       final response = await _supabase.from('table').select();
       return Result.success(response);
     } catch (e) {
       return Result.error('User-friendly message: $e');
     }
   }
   ```

2. **Logic Layer**: Add provider methods and state
   ```dart
   Future<void> loadSomeData() async {
     _isLoading = true;
     notifyListeners();
     
     try {
       final data = await _service.fetchSomeData();
       _data = data;
       _error = null;
     } catch (e) {
       _error = e.toString();
     } finally {
       _isLoading = false;
       notifyListeners();
     }
   }
   ```

3. **UI Layer**: Create components/pages consuming provider state
   - Use `Provider.of` or `Consumer` for reactive updates
   - Extract reusable widgets to `components/`
   - Place feature-specific components in this feature's `ui/components/`
   - Place reusable widgets in `core/widgets/`

### Testing Considerations

- **Permission Testing**: Test with users of different ranks (59, 60, 89, 90)
- **Troop Scoping**: Verify filtering works correctly for troop leaders
- **Role Context**: Test multi-role admins switching contexts
- **Validation**: Test required fields and troop context validation
- **Error Handling**: Test offline scenarios and permission failures

### Styling Conventions

**CRITICAL RULES**:
- ❌ **NEVER** hardcode colors: `Colors.blue`, `Color(0xFF...)`
- ✅ **ALWAYS** use `AppColors.*` constants or `Theme.of(context).colorScheme.*`

**Examples**:
```dart
// ❌ WRONG
Container(
  color: Colors.grey[100],
  child: Text('Hello', style: TextStyle(color: Colors.black)),
)

// ✅ RIGHT
Container(
  color: Theme.of(context).colorScheme.surface,
  child: Text(
    'Hello',
    style: Theme.of(context).textTheme.bodyMedium,
  ),
)

// ✅ RIGHT (with AppColors)
Container(
  decoration: BoxDecoration(
    color: AppColors.backgroundLight,
    border: Border.all(color: AppColors.dividerLight),
  ),
)
```

**Typography**:
- Use `Theme.of(context).textTheme.*` for text styles
- Options: `displayLarge`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`

**Spacing**:
- Use consistent spacing: 4, 8, 12, 16, 24, 32
- Padding/margin in multiples of 4

**Border Radius**:
- Cards: 16px (standard), 24px (media)
- Buttons: 12px (small), 16px (medium), 20px (large)

### Common Patterns to Follow

1. **Provider Pattern**:
   ```dart
   // Read once (e.g., in callbacks)
   final provider = context.read<UserManagementProvider>();
   
   // Listen to changes
   final provider = Provider.of<UserManagementProvider>(context);
   
   // Consumer for partial rebuilds
   Consumer<UserManagementProvider>(
     builder: (context, provider, child) => Widget(),
   )
   ```

2. **Error Handling**:
   ```dart
   if (provider.hasError) {
     return ErrorView(
       message: provider.error,
       onRetry: () => provider.loadUsers(),
     );
   }
   ```

3. **Loading States**:
   ```dart
   if (provider.isLoadingUsers) {
     return LoadingView();
   }
   ```

4. **Empty States**:
   ```dart
   if (users.isEmpty) {
     return EmptyStateView(
       icon: Icons.people_outline,
       title: 'No users found',
       description: 'Try adjusting your filters',
     );
   }
   ```

5. **Dialogs**:
   ```dart
   await showDialog<bool>(
     context: context,
     builder: (context) => AlertDialog(
       title: Text('Confirm Action'),
       content: Text('Are you sure?'),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context, false),
           child: Text('Cancel'),
         ),
         FilledButton(
           onPressed: () => Navigator.pop(context, true),
           child: Text('Confirm'),
         ),
       ],
     ),
   );
   ```

---

## Known Limitations / Future Enhancements

### Current Limitations

1. **Pagination**
   - Currently loads all users at once
   - May cause performance issues with large user bases (>1000 users)
   - **Future**: Implement pagination with lazy loading

2. **Audit Trail**
   - No tracking of who made what changes when
   - **Future**: Add audit log table and UI to view change history

3. **Bulk Operations**
   - Can only edit one user at a time
   - **Future**: Add bulk role assignment, bulk profile updates

4. **Advanced Filters**
   - Limited to basic search and single role/troop filters
   - **Future**: Add date range filters, custom field filters, saved filter presets

5. **Export Functionality**
   - No way to export user list
   - **Future**: Add CSV/Excel export with filtered results

6. **Photo Upload**
   - Profile editing doesn't include avatar upload
   - **Future**: Add image upload with cropping and compression

7. **Real-time Collaboration**
   - No indication if another admin is editing same user
   - **Future**: Add real-time presence indicators using Supabase Realtime

### Enhancement Ideas

- **User Deactivation**: Soft-delete users instead of permanent deletion
- **Role Templates**: Predefined role sets for common user types
- **Activity Dashboard**: Show recently edited users, pending approvals
- **Advanced Search**: Full-text search across all profile fields
- **Mobile Optimization**: Native mobile app with offline editing support
- **Notifications**: Alert users when their profile/role is changed
- **Role Hierarchy Visualization**: Tree view of role relationships
- **Batch Import**: CSV import for bulk user creation

---

## Related Documentation

- [Project Architecture](../../../ARCHITECTURE.md)
- [Auth Setup](../../../../auth/AUTH_SETUP.md)
- [Role Repository](../../../../auth/data/role_repository.dart)
- [Admin Scope Banner](../../../../core/widgets/admin_scope_banner.dart)
- [Scoped Service Mixin](../../../../core/data/scoped_service_mixin.dart)

---

## Troubleshooting

### Users Not Loading
- Check user's rank: Must be ≥60
- Verify troop assignment for troop leaders (rank 60-89)
- Check Supabase RLS policies on `profiles` table
- Verify network connection and Supabase credentials

### Role Assignment Failing
- Ensure troop context provided for troop-scoped roles (ranks 60, 70)
- Verify admin has permission to assign that role (can't assign higher rank)
- Check `profile_roles` table RLS policies
- Verify role IDs are valid

### Search Not Working
- Search debounces for 300ms - wait briefly after typing
- Search is case-insensitive and searches Arabic/English names
- Clear filters if results seem missing

### Changes Not Saving
- Check for validation errors in form
- Verify required fields filled out
- Check browser console for error messages
- Ensure Supabase connection is active

---

**Last Updated**: February 15, 2026  
**Version**: 1.0.0  
**Maintainer**: Scout Digital Team
