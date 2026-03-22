import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../auth/logic/auth_provider.dart';
import '../../../../../auth/models/role.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/gender_selector.dart';
import '../../data/models/managed_user_profile.dart';
import '../../logic/user_management_provider.dart';
import 'role_assignment_section.dart';

/// User Edit Dialog Component
///
/// A comprehensive dialog for editing user profiles with role management.
/// Supports form validation, role assignment with troop context, and profile updates.
///
/// Features:
/// - All profile field editing (name, email, birthdate, gender, etc.)
/// - Role assignment with troop context for troop-scoped roles
/// - Form validation with required field checks
/// - Responsive layout for different screen sizes
/// - Theme-aware styling using AppColors and Material theme
///
/// Usage:
/// ```dart
/// await showDialog(
///   context: context,
///   builder: (context) => UserEditDialog(profile: userProfile),
/// );
/// ```
class UserEditDialog extends StatefulWidget {
  /// The user profile to edit
  final ManagedUserProfile profile;

  const UserEditDialog({
    super.key,
    required this.profile,
  });

  @override
  State<UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<UserEditDialog> {
  // Form management
  final _formKey = GlobalKey<FormState>();

  // Text field controllers
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

  // Role management
  final List<Role> _selectedRoles = [];
  final Map<String, String?> _roleTroopContext = {}; // roleId -> troopId
  final bool _rolesInitialized = false;

  // Other fields
  DateTime? _selectedBirthdate;
  String? _selectedGender;
  List<Map<String, dynamic>> _troops = [];
  bool _isLoadingTroops = false;

  // Change tracking for unsaved changes warning
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  Timer? _changeCheckTimer;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;

    // Initialize text controllers with current profile data
    _firstNameController = TextEditingController(text: profile.firstName ?? '');
    _middleNameController = TextEditingController(text: profile.middleName ?? '');
    _lastNameController = TextEditingController(text: profile.lastName ?? '');
    _nameArController = TextEditingController(text: profile.nameAr ?? '');
    _emailController = TextEditingController(text: profile.email ?? '');
    _addressController = TextEditingController(text: profile.address ?? '');
    _generationController = TextEditingController(text: profile.generation ?? '');
    _medicalNotesController = TextEditingController(text: profile.medicalNotes ?? '');
    _allergiesController = TextEditingController(text: profile.allergies ?? '');

    // Initialize birthdate
    _selectedBirthdate = profile.birthdate;
    _birthdateController = TextEditingController(
      text: profile.birthdate != null
          ? DateFormat('yyyy-MM-dd').format(profile.birthdate!)
          : '',
    );

    // Initialize gender (capitalize first letter safely)
    final normalizedGender = profile.gender?.trim();
    _selectedGender = (normalizedGender != null && normalizedGender.isNotEmpty)
      ? normalizedGender.substring(0, 1).toUpperCase() +
        normalizedGender.substring(1).toLowerCase()
      : null;

    // Initialize roles
    _selectedRoles
      ..clear()
      ..addAll(profile.roles);
    
    // Initialize troop context from existing role assignments
    for (var assignment in profile.roleAssignments) {
      if (assignment.troopContextId != null) {
        _roleTroopContext[assignment.role.id] = assignment.troopContextId;
      }
    }
    
    // Debug logging
    debugPrint('🔍 Initializing edit dialog for ${profile.fullName}');
    debugPrint('   Roles: ${profile.roles.map((r) => r.name).join(", ")}');
    debugPrint('   Role assignments with troop context: ${profile.roleAssignments.where((a) => a.troopContextId != null).map((a) => '${a.role.name} -> ${a.troopContextName}').join(", ")}');
    debugPrint('   Initialized troop contexts: $_roleTroopContext');
    
    // Add listeners to all text controllers to detect changes (debounced)
    _firstNameController.addListener(_onFieldChanged);
    _middleNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _nameArController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _birthdateController.addListener(_onFieldChanged);
    _generationController.addListener(_onFieldChanged);
    _medicalNotesController.addListener(_onFieldChanged);
    _allergiesController.addListener(_onFieldChanged);
    
    _loadTroops();
  }

  /// Load available troops from the auth provider
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

  /// Debounced field change handler to avoid excessive change checks
  void _onFieldChanged() {
    _changeCheckTimer?.cancel();
    _changeCheckTimer = Timer(const Duration(milliseconds: 150), () {
      _checkForChanges();
    });
  }

  /// Check if there are any unsaved changes by comparing current values with original
  void _checkForChanges() {
    final profile = widget.profile;
    
    // Helper to normalize strings for comparison
    String normalize(String? value) => (value ?? '').trim();
    
    bool hasChanges = false;
    
    // Check text fields
    if (normalize(_firstNameController.text) != normalize(profile.firstName)) hasChanges = true;
    if (normalize(_middleNameController.text) != normalize(profile.middleName)) hasChanges = true;
    if (normalize(_lastNameController.text) != normalize(profile.lastName)) hasChanges = true;
    if (normalize(_nameArController.text) != normalize(profile.nameAr)) hasChanges = true;
    if (normalize(_emailController.text) != normalize(profile.email)) hasChanges = true;
    if (normalize(_addressController.text) != normalize(profile.address)) hasChanges = true;
    if (normalize(_generationController.text) != normalize(profile.generation)) hasChanges = true;
    if (normalize(_medicalNotesController.text) != normalize(profile.medicalNotes)) hasChanges = true;
    if (normalize(_allergiesController.text) != normalize(profile.allergies)) hasChanges = true;
    
    // Check birthdate
    if (_selectedBirthdate != profile.birthdate) hasChanges = true;
    
    // Check gender (normalize both to lowercase for comparison)
    final normalizedGender = _selectedGender?.toLowerCase();
    final originalGender = profile.gender?.toLowerCase();
    if (normalizedGender != originalGender) hasChanges = true;
    
    // Check roles (compare role IDs as sets)
    final currentRoleIds = _selectedRoles.map((r) => r.id).toSet();
    final originalRoleIds = profile.roles.map((r) => r.id).toSet();
    if (!currentRoleIds.containsAll(originalRoleIds) || !originalRoleIds.containsAll(currentRoleIds)) {
      hasChanges = true;
    }
    
    // Check troop context changes
    for (var assignment in profile.roleAssignments) {
      final currentTroopId = _roleTroopContext[assignment.role.id];
      if (currentTroopId != assignment.troopContextId) {
        hasChanges = true;
        break;
      }
    }
    
    // Update state only if changed to avoid unnecessary rebuilds
    if (_hasUnsavedChanges != hasChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  /// Show confirmation dialog when there are unsaved changes
  Future<bool> _showUnsavedChangesDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Unsaved Changes'),
            ],
          ),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Keep Editing',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text(
                'Discard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
    
    return result ?? false; // Default to keeping changes if dialog is dismissed
  }

  /// Handle cancel button - check for unsaved changes before closing
  Future<void> _handleCancel() async {
    if (_hasUnsavedChanges && !_isSaving) {
      final shouldDiscard = await _showUnsavedChangesDialog();
      if (shouldDiscard && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // Cancel debounce timer
    _changeCheckTimer?.cancel();
    
    // Remove listeners before disposing
    _firstNameController.removeListener(_onFieldChanged);
    _middleNameController.removeListener(_onFieldChanged);
    _lastNameController.removeListener(_onFieldChanged);
    _nameArController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _addressController.removeListener(_onFieldChanged);
    _birthdateController.removeListener(_onFieldChanged);
    _generationController.removeListener(_onFieldChanged);
    _medicalNotesController.removeListener(_onFieldChanged);
    _allergiesController.removeListener(_onFieldChanged);
    
    // Dispose all text controllers
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

    return PopScope(
      canPop: !_hasUnsavedChanges || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // If there are unsaved changes, show confirmation
        final shouldDiscard = await _showUnsavedChangesDialog();
        if (shouldDiscard && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minWidth: screenWidth < 600 ? screenWidth - 48 : 380,
        ),
        child: Padding(
          padding: EdgeInsets.all(dialogPadding),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with unsaved changes indicator
                  Row(
                    children: [
                      Text('Edit User', style: theme.textTheme.titleLarge),
                      if (_hasUnsavedChanges) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.warning.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Edited',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  _buildSectionHeader(context, title: 'Personal Information', icon: Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildTextField('First Name', _firstNameController, required: true, validator: _validateRequired, prefixIcon: Icons.badge_outlined),
                  _buildTextField('Middle Name', _middleNameController, prefixIcon: Icons.badge_outlined),
                  _buildTextField('Last Name', _lastNameController, required: true, validator: _validateRequired, prefixIcon: Icons.badge_outlined),
                  _buildTextField('Arabic Name', _nameArController, prefixIcon: Icons.translate_outlined),
                  _buildDateField(context),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GenderSelector(
                      initialValue: _selectedGender,
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                        _checkForChanges();
                      },
                      isRequired: true,
                    ),
                  ),
                  _buildTextField('Generation', _generationController, prefixIcon: Icons.tag_outlined),
                  
                  const SizedBox(height: 12),
                  _buildSectionHeader(context, title: 'Contact Information', icon: Icons.contact_mail_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('Email', _emailController, keyboardType: TextInputType.emailAddress, validator: _validateEmail, prefixIcon: Icons.email_outlined),
                  _buildTextField('Address', _addressController, validator: _validateAddress, prefixIcon: Icons.home_work_outlined),
                  _buildReadOnlyField('Phone Number', widget.profile.phone ?? 'Not provided', prefixIcon: Icons.phone_outlined),
                  
                  const SizedBox(height: 12),
                  _buildSectionHeader(context, title: 'Assigned Roles & Troop Contexts', icon: Icons.admin_panel_settings_outlined),
                  const SizedBox(height: 12),
                  if (widget.profile.roleAssignments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, left: 4),
                      child: Text(
                        'No roles assigned',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...widget.profile.roleAssignments.map((assignment) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    assignment.role.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Rank ${assignment.role.rank}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (assignment.troopContextName != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.groups_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Troop Context: ${assignment.troopContextName}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 12),
                  _buildSectionHeader(context, title: 'Scout Information', icon: Icons.explore_outlined),
                  const SizedBox(height: 16),
                  _buildReadOnlyField('Scout Code', widget.profile.scoutCode ?? 'Not provided', prefixIcon: Icons.numbers_outlined),

                  const SizedBox(height: 12),
                  _buildSectionHeader(context, title: 'Medical Information', icon: Icons.medical_information_outlined),
                  const SizedBox(height: 16),
                  _buildTextField('Medical Notes', _medicalNotesController, maxLines: 3),
                  _buildTextField('Allergies', _allergiesController, maxLines: 3),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: provider.isProcessing ? null : _handleCancel,
                        style: _hasUnsavedChanges
                            ? TextButton.styleFrom(
                                foregroundColor: AppColors.warning,
                              )
                            : null,
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
      ),
    );
  }

  /// Build a text field with consistent styling
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
    String? Function(String?)? validator,
    IconData? prefixIcon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: colorScheme.primary.withOpacity(0.7)) : null,
          filled: true,
          fillColor: theme.brightness == Brightness.light
              ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : const Color(0xFF1E1E1E).withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
        ),
      ),
    );
  }

  /// Validator for required fields
  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  /// Validator for email field (optional but must be valid if provided)
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Email is optional in edit
    }
    // RFC 5322 compliant email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validator for address field
  String? _validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Address is required';
    }
    return null;
  }

  /// Build a read-only field for non-editable data
  Widget _buildReadOnlyField(String label, String value, {IconData? prefixIcon}) {
    final isNotProvided = value == 'Not provided';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        style: isNotProvided ? theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ) : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: colorScheme.onSurfaceVariant.withOpacity(0.7)) : null,
          filled: true,
          fillColor: theme.brightness == Brightness.light
              ? colorScheme.surfaceContainerHighest.withOpacity(0.1)
              : const Color(0xFF1E1E1E).withOpacity(0.2),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// Build the birthdate picker field
  Widget _buildDateField(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _birthdateController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Birthdate',
          prefixIcon: Icon(Icons.cake_outlined, color: colorScheme.primary.withOpacity(0.7)),
          suffixIcon: Icon(Icons.calendar_today, color: colorScheme.primary),
          filled: true,
          fillColor: theme.brightness == Brightness.light
              ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : const Color(0xFF1E1E1E).withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
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
            _checkForChanges();
          }
        },
      ),
    );
  }

  /// Save changes to the user profile
  Future<void> _saveChanges(BuildContext context) async {
    // Set saving flag to prevent unsaved changes warning during save
    setState(() {
      _isSaving = true;
    });
    
    // Validate form
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Validate gender selection
    if (_selectedGender == null) {
      setState(() {
        _isSaving = false;
      });
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

    // Build updates map
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
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one role')),
      );
      return;
    }

    // Validate troop context for troop-scoped roles (ranks 60, 70)
    if (canEditRoles) {
      // Get the Role objects for selected assignable roles
      final rolesToAssign = _selectedRoles
          .where((role) => selectedRoleIds.contains(role.id))
          .toList();

      for (final role in rolesToAssign) {
        if ((role.rank == 60 || role.rank == 70) && 
            (_roleTroopContext[role.id] == null || _roleTroopContext[role.id]!.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select a troop for ${role.name}')),
          );
          setState(() {
            _isSaving = false;
          });
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
      // Reset flags before closing to prevent warning
      _hasUnsavedChanges = false;
      _isSaving = false;
      
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
    } else {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Unable to update user')),
      );
    }
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    // Use dark navy blue for better readability in light mode
    final headerColor = isDark ? colorScheme.onSurface : const Color(0xFF001F3F);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: headerColor),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: headerColor,
            ),
          ),
        ],
      ),
    );
  }
}
