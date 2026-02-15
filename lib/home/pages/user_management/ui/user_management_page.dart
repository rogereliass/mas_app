import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/models/role.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/admin_scope_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../data/models/managed_user_profile.dart';
import '../logic/user_management_provider.dart';

/// User Management Page
///
/// Allows system admins and troop-scoped leaders to update user profiles
class UserManagementPage extends StatefulWidget {
  final String? selectedRole;

  const UserManagementPage({super.key, this.selectedRole});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  UserManagementProvider? _userProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserManagementProvider>();
      _userProvider = userProvider;
      final colorScheme = Theme.of(context).colorScheme;

      String? roleContext = widget.selectedRole;
      if (roleContext == null) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        roleContext = args?['selectedRole'] as String?;
      }

      int effectiveRank;
      if (roleContext != null) {
        effectiveRank = authProvider.getRankForRole(roleContext);
        userProvider.setRoleContext(roleContext);
      } else {
        effectiveRank = authProvider.currentUserRoleRank;
        userProvider.clearRoleContext();
      }

      final user = authProvider.currentUserProfile;

      if (effectiveRank < 60) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access Denied: Admin privileges required'),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }

      if (effectiveRank >= 60 && effectiveRank < 90) {
        if (user?.managedTroopId == null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Access Error: No troop assigned. Please contact an administrator.'),
              backgroundColor: colorScheme.tertiary,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      userProvider.loadUsers();
      userProvider.loadRoles();
    });
  }

  @override
  void dispose() {
    // Clear role context after frame to avoid setState during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _userProvider?.clearRoleContext();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String? roleContext = widget.selectedRole;
    if (roleContext == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      roleContext = args?['selectedRole'] as String?;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          Consumer<UserManagementProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: provider.isLoadingUsers ? null : () => provider.refresh(),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          AdminScopeBanner(selectedRoleName: roleContext),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await context.read<UserManagementProvider>().refresh();
              },
              child: Consumer<UserManagementProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingUsers) {
                    return const LoadingView(message: 'Loading users...');
                  }

                  if (provider.hasError) {
                    return ErrorView(
                      message: provider.error ?? 'Unknown error occurred',
                      onRetry: () => provider.loadUsers(),
                    );
                  }

                  if (provider.users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 72,
                            color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text('No users found', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            'No users are available for management in this scope.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.users.length,
                    itemBuilder: (context, index) {
                      final user = provider.users[index];
                      return _UserCard(
                        profile: user,
                        onEdit: () => _showEditDialog(context, user),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, ManagedUserProfile profile) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _UserEditDialog(profile: profile),
    );
  }
}

class _UserCard extends StatelessWidget {
  final ManagedUserProfile profile;
  final VoidCallback onEdit;

  const _UserCard({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roleName = profile.primaryRole?.name ?? 'No Role';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    profile.fullName.isNotEmpty
                        ? profile.fullName.substring(0, 1).toUpperCase()
                        : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.fullName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        roleName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Edit User',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (profile.email != null && profile.email!.isNotEmpty)
              Text(profile.email!, style: theme.textTheme.bodySmall),
            if (profile.phone != null && profile.phone!.isNotEmpty)
              Text(profile.phone!, style: theme.textTheme.bodySmall),
            if (profile.signupTroopName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Troop: ${profile.signupTroopName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserEditDialog extends StatefulWidget {
  final ManagedUserProfile profile;

  const _UserEditDialog({required this.profile});

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _nameArController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _birthdateController;
  late final TextEditingController _generationController;
  late final TextEditingController _medicalNotesController;
  late final TextEditingController _allergiesController;
  final List<Role> _selectedRoles = [];
  final Map<String, String?> _roleTroopContext = {}; // roleId -> troopId
  bool _rolesInitialized = false;

  DateTime? _selectedBirthdate;
  String? _selectedGender;
  List<Map<String, dynamic>> _troops = [];
  bool _isLoadingTroops = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;

    _firstNameController = TextEditingController(text: profile.firstName ?? '');
    _middleNameController = TextEditingController(text: profile.middleName ?? '');
    _lastNameController = TextEditingController(text: profile.lastName ?? '');
    _nameArController = TextEditingController(text: profile.nameAr ?? '');
    _emailController = TextEditingController(text: profile.email ?? '');
    _addressController = TextEditingController(text: profile.address ?? '');
    _generationController = TextEditingController(text: profile.generation ?? '');
    _medicalNotesController = TextEditingController(text: profile.medicalNotes ?? '');
    _allergiesController = TextEditingController(text: profile.allergies ?? '');

    _selectedBirthdate = profile.birthdate;
    _selectedGender = profile.gender != null 
        ? profile.gender!.substring(0, 1).toUpperCase() + profile.gender!.substring(1).toLowerCase()
        : null;
    _birthdateController = TextEditingController(
      text: profile.birthdate != null
          ? DateFormat('yyyy-MM-dd').format(profile.birthdate!)
          : '',
    );

    _selectedRoles
      ..clear()
      ..addAll(profile.roles);
    
    // Initialize troop context from existing role assignments
    for (var assignment in profile.roleAssignments) {
      if (assignment.troopContextId != null) {
        _roleTroopContext[assignment.role.id] = assignment.troopContextId;
      }
    }
    
    // Debug: Print initialization info
    debugPrint('🔍 Initializing edit dialog for ${profile.fullName}');
    debugPrint('   Roles: ${profile.roles.map((r) => r.name).join(", ")}');
    debugPrint('   Role assignments with troop context: ${profile.roleAssignments.where((a) => a.troopContextId != null).map((a) => '${a.role.name} -> ${a.troopContextName}').join(", ")}');
    debugPrint('   Initialized troop contexts: $_roleTroopContext');
    
    _loadTroops();
  }
  
  Future<void> _loadTroops() async {
    setState(() {
      _isLoadingTroops = true;
    });
    
    try {
      final authProvider = context.read<AuthProvider>();
      final troops = await authProvider.getTroops();
      
      if (mounted) {
        setState(() {
          _troops = troops;
          _isLoadingTroops = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTroops = false;
        });
        debugPrint('Error loading troops: $e');
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _nameArController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _birthdateController.dispose();
    _generationController.dispose();
    _medicalNotesController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<UserManagementProvider>();
    final assignableRoles = provider.assignableRoles;
    final canEditRoles = provider.canEditRolesForProfile(widget.profile);
    final canEditRole = assignableRoles.isNotEmpty && canEditRoles;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogPadding = screenWidth < 600 ? 12.0 : 20.0;
    final dialogInset = screenWidth < 600 ? 8.0 : 16.0;

    if (!_rolesInitialized) {
      _rolesInitialized = true;
      _selectedRoles
        ..clear()
        ..addAll(widget.profile.roles);
    }

    return Dialog(
      insetPadding: EdgeInsets.all(dialogInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          minWidth: screenWidth < 600 ? screenWidth - (dialogInset * 2) : 300,
        ),
        child: Padding(
          padding: EdgeInsets.all(dialogPadding),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit User', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildTextField('First Name', _firstNameController, required: true, validator: _validateRequired),
                  _buildTextField('Middle Name', _middleNameController),
                  _buildTextField('Last Name', _lastNameController, required: true, validator: _validateRequired),
                  _buildTextField('Arabic Name', _nameArController),
                  _buildTextField('Email', _emailController, keyboardType: TextInputType.emailAddress, validator: _validateEmail),
                  _buildReadOnlyField('Phone Number', widget.profile.phone ?? 'Not provided'),
                  _buildReadOnlyField('Scout Code', widget.profile.scoutCode ?? 'Not provided'),
                  _buildDateField(context),
                  _buildGenderField(theme),
                  _buildTextField('Generation', _generationController),
                  _buildTextField('Address', _addressController, validator: _validateAddress),
                  _buildTextField('Medical Notes', _medicalNotesController, maxLines: 3),
                  _buildTextField('Allergies', _allergiesController, maxLines: 3),
                  const SizedBox(height: 8),
                  _buildRoleSelection(theme, provider, canEditRole, screenWidth),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: provider.isProcessing ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: provider.isProcessing ? null : () => _saveChanges(context),
                        child: provider.isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Email is optional in edit
    }
    final emailRegex = RegExp(r'^[\w\-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }
    return null;
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildGenderField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FormField<String>(
        initialValue: _selectedGender,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a gender';
          }
          return null;
        },
        builder: (FormFieldState<String> field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gender *',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedGender = 'Male';
                        });
                        field.didChange('Male');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedGender == 'Male'
                              ? AppColors.primaryBlue.withValues(alpha: 0.1)
                              : theme.brightness == Brightness.dark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                          border: Border.all(
                            color: _selectedGender == 'Male'
                                ? AppColors.primaryBlue
                                : theme.brightness == Brightness.dark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                            width: _selectedGender == 'Male' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedGender == 'Male'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _selectedGender == 'Male'
                                  ? AppColors.primaryBlue
                                  : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Male',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: _selectedGender == 'Male'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _selectedGender == 'Male'
                                    ? AppColors.primaryBlue
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedGender = 'Female';
                        });
                        field.didChange('Female');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedGender == 'Female'
                              ? AppColors.primaryBlue.withValues(alpha: 0.1)
                              : theme.brightness == Brightness.dark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                          border: Border.all(
                            color: _selectedGender == 'Female'
                                ? AppColors.primaryBlue
                                : theme.brightness == Brightness.dark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                            width: _selectedGender == 'Female' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedGender == 'Female'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _selectedGender == 'Female'
                                  ? AppColors.primaryBlue
                                  : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Female',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: _selectedGender == 'Female'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _selectedGender == 'Female'
                                    ? AppColors.primaryBlue
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleSelection(
    ThemeData theme,
    UserManagementProvider provider,
    bool canEditRole,
    double screenWidth,
  ) {
    final colorScheme = theme.colorScheme;
    final assignableRoles = provider.assignableRoles;
    
    // Build a map of current role assignments for quick lookup
    final assignmentMap = <String, RoleAssignment>{};
    for (var assignment in widget.profile.roleAssignments) {
      assignmentMap[assignment.role.id] = assignment;
    }
    
    final currentRoleNames = widget.profile.roles.map((role) => role.name).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Assign Roles',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '*',
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          currentRoleNames.isEmpty
              ? 'Required - Select one or more roles'
              : 'Current roles: $currentRoleNames',
          style: theme.textTheme.bodySmall?.copyWith(
            color: currentRoleNames.isEmpty ? colorScheme.error : colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        if (!provider.isRolesReady)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (assignableRoles.isEmpty)
          Text(
            'No roles available for assignment',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: assignableRoles.map((role) {
                final isSelected = _selectedRoles.contains(role);
                final wasAlreadyAssigned = widget.profile.roles.contains(role);
                final assignment = assignmentMap[role.id];
                final isTroopScoped = role.rank == 60 || role.rank == 70;
                final selectedTroopId = _roleTroopContext[role.id];
                
                return Column(
                  children: [
                    CheckboxListTile(
                      value: isSelected,
                      onChanged: canEditRole
                          ? (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedRoles.add(role);
                                  // Initialize with existing troop context or user's signup troop
                                  if (isTroopScoped && !_roleTroopContext.containsKey(role.id)) {
                                    _roleTroopContext[role.id] = widget.profile.signupTroopId;
                                  }
                                } else {
                                  _selectedRoles.remove(role);
                                  _roleTroopContext.remove(role.id);
                                }
                              });
                            }
                          : null,
                      title: Text(
                        role.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (role.description != null)
                            Text(
                              role.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          // Show troop context info for non-selected roles
                          if (!isSelected && assignment?.troopContextName != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.group,
                                    size: 14,
                                    color: colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Current Troop: ${assignment!.troopContextName}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.secondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Show indicator for troop-scoped roles when selected
                          if (isSelected && isTroopScoped) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: colorScheme.tertiary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Requires troop assignment (see below)',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.tertiary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (wasAlreadyAssigned) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Currently assigned',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      secondary: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${role.rank}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onError,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Troop context dropdown for troop-scoped roles - ALWAYS show when selected
                    if (isSelected && isTroopScoped)
                      Padding(
                        padding: EdgeInsets.only(
                          left: screenWidth < 600 ? 8 : 16, 
                          right: screenWidth < 600 ? 8 : 16, 
                          top: 8, 
                          bottom: 12
                        ),
                        child: Consumer<UserManagementProvider>(
                          builder: (context, _, __) {
                            final currentScreenWidth = MediaQuery.of(context).size.width;
                            return Container(
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.secondary.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              padding: EdgeInsets.all(currentScreenWidth < 600 ? 8 : 12),
                              child: _buildTroopContextDropdown(role, selectedTroopId, theme, colorScheme, currentScreenWidth),
                            );
                          },
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        if (!canEditRole)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'You do not have permission to change this user\'s roles.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTroopContextDropdown(
    Role role,
    String? selectedTroopId,
    ThemeData theme,
    ColorScheme colorScheme,
    double screenWidth,
  ) {
    if (_isLoadingTroops) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_troops.isEmpty) {
      return Container(
        padding: EdgeInsets.all(screenWidth < 600 ? 8 : 12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 16, color: colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No troops available. Cannot assign troop-scoped role.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth < 600 ? 5 : 6),
              decoration: BoxDecoration(
                color: colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group,
                size: screenWidth < 600 ? 12 : 14,
                color: colorScheme.onSecondary,
              ),
            ),
            SizedBox(width: screenWidth < 600 ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Troop Assignment for ${role.name}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.secondary,
                    ),
                  ),
                  Text(
                    'Select which troop this role applies to',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: selectedTroopId,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: screenWidth < 600 ? 12 : 16, 
              vertical: screenWidth < 600 ? 10 : 12
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark 
                ? colorScheme.surface 
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: selectedTroopId == null
                    ? colorScheme.error
                    : colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: selectedTroopId == null
                    ? colorScheme.error
                    : colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: selectedTroopId == null
                    ? colorScheme.error
                    : colorScheme.secondary,
                width: 2,
              ),
            ),
            prefixIcon: Icon(
              Icons.location_city,
              color: colorScheme.secondary,
            ),
          ),
          hint: Text(
            'Choose a troop...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          items: _troops.map((troop) {
            return DropdownMenuItem<String>(
              value: troop['id'] as String,
              child: Text(
                troop['name'] as String,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _roleTroopContext[role.id] = newValue;
            });
            debugPrint('🔄 Troop context updated: ${role.name} -> ${_troops.firstWhere((t) => t['id'] == newValue)['name']}');
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required: Select a troop for this role';
            }
            return null;
          },
        ),
        if (selectedTroopId == null)
          Padding(
            padding: EdgeInsets.only(top: 8, left: screenWidth < 600 ? 2 : 4),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 14,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This role cannot be assigned without selecting a troop',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _birthdateController,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Birthdate',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: _selectedBirthdate ?? DateTime(2005, 1, 1),
            firstDate: DateTime(1940),
            lastDate: DateTime.now(),
          );

          if (selected != null) {
            setState(() {
              _selectedBirthdate = selected;
              _birthdateController.text = DateFormat('yyyy-MM-dd').format(selected);
            });
          }
        },
      ),
    );
  }

  Future<void> _saveChanges(BuildContext context) async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate gender selection
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a gender')),
      );
      return;
    }

    final provider = context.read<UserManagementProvider>();

    String? cleanValue(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final updates = <String, dynamic>{
      'first_name': cleanValue(_firstNameController.text),
      'middle_name': cleanValue(_middleNameController.text),
      'last_name': cleanValue(_lastNameController.text),
      'name_ar': cleanValue(_nameArController.text),
      'email': cleanValue(_emailController.text),
      'address': cleanValue(_addressController.text),
      'birthdate': _selectedBirthdate?.toIso8601String(),
      'gender': _selectedGender?.toLowerCase(), // Convert to lowercase for database
      'generation': cleanValue(_generationController.text),
      'medical_notes': cleanValue(_medicalNotesController.text),
      'allergies': cleanValue(_allergiesController.text),
    };

    final canEditRoles = provider.canEditRolesForProfile(widget.profile);
    final assignableRoleIds = provider.assignableRoles.map((role) => role.id).toSet();
    final selectedRoleIds = _selectedRoles
        .map((role) => role.id)
        .where(assignableRoleIds.contains)
        .toList();

    if (canEditRoles && selectedRoleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one role')),
      );
      return;
    }

    // Validate troop context for troop-scoped roles (ranks 60, 70)
    if (canEditRoles) {
      for (final role in _selectedRoles) {
        if ((role.rank == 60 || role.rank == 70) && 
            (_roleTroopContext[role.id] == null || _roleTroopContext[role.id]!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select a troop for ${role.name}')),
          );
          return;
        }
      }
    }

    final roleIds = canEditRoles ? selectedRoleIds : null;
    final roleTroopContext = canEditRoles ? _roleTroopContext : null;

    final success = await provider.updateUser(
      profile: widget.profile,
      updates: updates,
      roleIds: roleIds,
      roleTroopContextMap: roleTroopContext,
    );

    if (!context.mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Unable to update user')),
      );
    }
  }
}
