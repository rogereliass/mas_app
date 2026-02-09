# Admin Approval Feature

## Overview
Admin approval page for system administrators to review and approve/reject new user registrations. Located under home page features following the app's page-based architecture pattern.

## Location
`lib/home/pages/admin_approval/`

This feature is organized under the home page because it's an admin dashboard feature accessed from the system admin section of the home page.

## Feature Requirements
- **Role Restriction**: Only accessible to system administrators (roleRank == 100)
- **Pending Profiles**: Shows all profiles where `approved = false`
- **Review Details**: Full profile information display for admin review
- **Multiple Role Assignment**: Required - Admin must assign at least one role (can select multiple)
- **Generation Assignment**: Required - Admin must assign generation during approval
- **Accept Action**: Creates approval record (status=true), updates profile.approved=true with generation, assigns multiple roles by creating profile_roles records
- **Add Comment**: Admin can add notes without changing approval status, profile remains pending
- **Approval History**: Shows all comments and approval/rejection records for each profile

## Architecture

### Data Layer (`data/`)

#### Models
- **PendingProfile** (`models/pending_profile.dart`)
  - Represents user profiles pending approval
  - Includes all profile fields plus helper methods (fullName, age)
  - Handles JSON serialization from Supabase

- **ProfileApproval** (`models/profile_approval.dart`)
  - Represents approval/rejection records from `profiles_approvals` table
  - Tracks status, comments, approver, and timestamp

- **Role** (imported from `auth/models/role.dart`)
  - Represents roles from the roles table
  - Includes id, slug, name, description, and rank
  - Used for role assignment during profile approval
  - Reuses existing auth infrastructure (no duplication)

#### Service
- **AdminService** (`admin_service.dart`)
  - Singleton service for all admin-related Supabase operations
  - Uses `RoleRepository.getAllRoles()` for fetching available roles
  - Key methods:
    - `fetchPendingProfiles()` - Get all unapproved profiles
    - `fetchProfileApprovals(profileId)` - Get approval history
    - `fetchRoles()` - Delegates to RoleRepository.getAllRoles()
    - `acceptProfile()` - Approve profile with role assignment and optional generation
    - `rejectProfile()` - Reject profile (comments required)
    - `updateProfileGeneration()` - Update generation field

### Logic Layer (`logic/`)

#### Provider
- **AdminProvider** (`admin_provider.dart`)
  - State management for admin operations
  - Manages loading states, errors, and data caching
  - Provides reactive UI updates via ChangeNotifier
  - Key methods mirror service but add state management

### UI Layer (`ui/`)

#### Pages
- **UserAcceptancePage** (`user_acceptance_page.dart`)
  - Main page showing list of pending profiles
  - Empty state when no pending registrations
  - Profile cards with quick info
  - Detailed review dialog with accept and add comment actions

#### Components
- **ProfileCard** - Compact profile display in list
- **ProfileDetailsDialog** - Full profile review dialog with:
  - Personal information section
  - Scout information section
  - Medical information section (if present)
  - Multi-select role checkboxes with rank badges (REQUIRED)
  - Selected roles displayed as removable chips
  - Generation input field (REQUIRED)
  - Comments input field (optional)
  - Approval history (expandable)
  - Accept and Add Comment action buttons

## Database Schema

### profiles table
```sql
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY,
  user_id uuid,
  first_name text NOT NULL,
  last_name text NOT NULL,
  middle_name text,
  name_ar text,
  scout_org_id text,
  scout_code text UNIQUE,
  birthdate date,
  phone text UNIQUE,
  email text,
  photo_url text,
  gender USER-DEFINED,
  generation text,              -- Can be assigned during approval
  address text,
  medical_notes text,
  allergies text,
  signup_completed boolean DEFAULT false,
  approved boolean DEFAULT false,  -- Key field for pending status
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  signup_troop uuid
);
```

### profiles_approvals table
```sql
CREATE TABLE public.profiles_approvals (
  id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  profile_id uuid REFERENCES profiles(id),
  approved_by uuid REFERENCES profiles(id),
  comments text,
  status bool,                     -- true=accepted, false=rejected
  created_at timestamp with time zone DEFAULT now()
);
```

## Usage

### Accessing User Acceptance Page
1. Log in as system administrator (roleRank = 100)
2. Navigate to Home page
3. In "System Admin" section, find "Admin Actions" card
4. Click "User Acceptance" button
5. Review pending profiles

### Reviewing a Profile
1. Click on profile card to open details dialog
2. Review all information sections
3. Select one or more roles (REQUIRED) - displayed as checkboxes
4. Assign generation (REQUIRED) - enter cohort identifier
5. Add comments if needed (optional)
6. Click "Accept" to approve or "Add Comment" to save notes without approving

### Business Rules
- **Accept Action**:
  - At least one role selection is REQUIRED
  - Generation assignment is REQUIRED
  - Multiple roles can be assigned simultaneously
  - Creates approval record with status=true
  - Sets profile.approved=true and generation field
  - Creates multiple profile_roles records (one per selected role)
  - Profile removed from pending list
  
- **Add Comment Action**:
  - Comments are REQUIRED for this action
  - Creates comment record with status=null (pending review)
  - Profile STAYS in pending list
  - Allows admin to document review without making decision
  - Useful for flagging issues to review later or with team

## Navigation Flow
```
Home Page (System Admin Section)
  └── Admin Actions Card
      └── User Acceptance Button
          └── User Acceptance Page
              └── Profile Card Click
                  └── Profile Details Dialog
                      ├── Accept → Profile Approved
                      └── Reject → Approval Record Created
```

## Integration Points

### Providers
- **AuthProvider**: Used to get current admin user ID for approval records
- **AdminProvider**: Manages all admin-specific state

### Routes
- Route constant: `AppRouter.userAcceptance`
- Route path: `/user-acceptance`
- Defined in: `lib/routing/app_router.dart`

### Permissions
- Feature is only accessible via button visible to system admins
- No route-level protection currently (consider adding middleware)
- Database RLS policies should also protect the tables

## Future Enhancements
- [ ] Add route-level permission checks
- [ ] Email notifications to users on approval/rejection
- [ ] Batch approval functionality
- [ ] Search and filter pending profiles
- [ ] Export pending profiles list
- [ ] Add admin notes field separate from comments
- [ ] Profile comparison for duplicate detection
- [ ] Automatic role assignment rules

## Testing Checklist
- [ ] System admin can access User Acceptance page
- [ ] Non-admin users cannot see the button
- [ ] Roles load correctly in dropdown
- [ ] Pending profiles load correctly
- [ ] Profile details display all information
- [ ] Role selection is required for acceptance
- [ ] Accept action updates database correctly
- [ ] Profile_roles record created on acceptance
- [ ] Reject action requires comments
- [ ] Generation assignment works
- [ ] Approval history displays correctly
- [ ] Empty state shows when no pending profiles
- [ ] Error handling works for network issues
- [ ] Loading states display properly
- [ ] Confirmation dialogs show selected role and generation

## Troubleshooting

### Common Issues

**Issue**: Button not visible
- **Solution**: Verify user has roleRank = 100 (system admin)

**Issue**: Pending profiles not loading
- **Solution**: Check Supabase connection and RLS policies

**Issue**: Accept/Reject not working
- **Solution**: Verify admin has valid user ID in AuthProvider

**Issue**: Comments not saving
- **Solution**: Check profiles_approvals table exists and has correct schema

## Code Examples

### Navigating to User Acceptance
```dart
Navigator.pushNamed(context, AppRouter.userAcceptance);
```

### Using AdminProvider
```dart
// Get provider
final adminProvider = context.read<AdminProvider>();

// Load pending profiles
await adminProvider.loadPendingProfiles();

// Load available roles
await adminProvider.loadRoles();

// Accept profile with role assignment
final success = await adminProvider.acceptProfile(
  profileId: profile.id,
  approvedBy: adminId,
  roleId: selectedRole.id,     // Required
  generation: '2024',           // Optional
  comments: 'Approved by admin', // Optional
);
```

### Checking Admin Permission
```dart
final user = context.read<AuthProvider>().currentUserProfile;
if (user?.isSystemAdmin ?? false) {
  // Show admin features
}
```

## Related Files
- Architecture doc: `ARCHITECTURE.md`
- Auth setup: `lib/auth/AUTH_SETUP.md`
- Database schema: `database/schema_copy.txt`
- Main app: `lib/main.dart`
