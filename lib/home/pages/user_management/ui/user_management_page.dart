import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/models/role.dart';
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
    _userProvider?.clearRoleContext();
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
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _nameArController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _birthdateController;
  late final TextEditingController _genderController;
  late final TextEditingController _generationController;
  late final TextEditingController _medicalNotesController;
  late final TextEditingController _allergiesController;
  final List<Role> _selectedRoles = [];
  bool _rolesInitialized = false;

  DateTime? _selectedBirthdate;

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
    _genderController = TextEditingController(text: profile.gender ?? '');
    _generationController = TextEditingController(text: profile.generation ?? '');
    _medicalNotesController = TextEditingController(text: profile.medicalNotes ?? '');
    _allergiesController = TextEditingController(text: profile.allergies ?? '');

    _selectedBirthdate = profile.birthdate;
    _birthdateController = TextEditingController(
      text: profile.birthdate != null
          ? DateFormat('yyyy-MM-dd').format(profile.birthdate!)
          : '',
    );

    _selectedRoles
      ..clear()
      ..addAll(profile.roles);
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
    _genderController.dispose();
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

    if (!_rolesInitialized) {
      _rolesInitialized = true;
      _selectedRoles
        ..clear()
        ..addAll(widget.profile.roles);
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit User', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                _buildTextField('First Name', _firstNameController),
                _buildTextField('Middle Name', _middleNameController),
                _buildTextField('Last Name', _lastNameController),
                _buildTextField('Arabic Name', _nameArController),
                _buildTextField('Email', _emailController, keyboardType: TextInputType.emailAddress),
                _buildReadOnlyField('Phone Number', widget.profile.phone ?? 'Not provided'),
                _buildReadOnlyField('Scout Code', widget.profile.scoutCode ?? 'Not provided'),
                _buildDateField(context),
                _buildTextField('Gender', _genderController),
                _buildTextField('Generation', _generationController),
                _buildTextField('Address', _addressController),
                _buildTextField('Medical Notes', _medicalNotesController, maxLines: 3),
                _buildTextField('Allergies', _allergiesController, maxLines: 3),
                const SizedBox(height: 8),
                _buildRoleSelection(theme, provider, canEditRole),
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
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
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

  Widget _buildRoleSelection(
    ThemeData theme,
    UserManagementProvider provider,
    bool canEditRole,
  ) {
    final colorScheme = theme.colorScheme;
    final assignableRoles = provider.assignableRoles;
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
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: canEditRole
                      ? (value) {
                          setState(() {
                            if (value == true) {
                              _selectedRoles.add(role);
                            } else {
                              _selectedRoles.remove(role);
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
                            Text(
                              'Currently assigned',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w500,
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
      'gender': cleanValue(_genderController.text),
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

    final roleIds = canEditRoles ? selectedRoleIds : null;

    final success = await provider.updateUser(
      profile: widget.profile,
      updates: updates,
      roleIds: roleIds,
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
