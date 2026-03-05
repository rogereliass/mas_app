import 'package:flutter/material.dart';

import '../../../../../auth/models/role.dart';
import '../../data/models/managed_user_profile.dart';

/// Role Assignment Section Component
///
/// A feature-specific component for managing role assignments in user profiles.
/// Handles role selection with checkboxes and troop context assignment for
/// troop-scoped roles (ranks 60 and 70).
///
/// Features:
/// - Checkbox list for role selection
/// - Troop context dropdown for troop-scoped roles
/// - Visual indicators for current assignments
/// - Form validation for required troop context
/// - Permission-based editing
/// - Responsive layout for different screen sizes
///
/// Usage:
/// ```dart
/// RoleAssignmentSection(
///   selectedRoles: _selectedRoles,
///   availableRoles: assignableRoles,
///   profile: userProfile,
///   troops: _troops,
///   roleTroopContext: _roleTroopContext,
///   canEditRole: true,
///   isLoadingTroops: false,
///   onRoleToggled: (role, isSelected) { /* ... */ },
///   onTroopContextChanged: (roleId, troopId) { /* ... */ },
/// )
/// ```
class RoleAssignmentSection extends StatelessWidget {
  /// Currently selected roles
  final List<Role> selectedRoles;

  /// Available roles that can be assigned
  final List<Role> availableRoles;

  /// The user profile being edited
  final ManagedUserProfile profile;

  /// Available troops for troop-scoped roles
  final List<Map<String, dynamic>> troops;

  /// Map of role ID to selected troop ID
  final Map<String, String?> roleTroopContext;

  /// Whether the current user can edit roles
  final bool canEditRole;

  /// Whether troops are currently loading
  final bool isLoadingTroops;

  /// Whether roles are still being loaded
  final bool isRolesReady;

  /// Callback when a role is toggled
  final void Function(Role role, bool isSelected) onRoleToggled;

  /// Callback when troop context is changed for a role
  final void Function(String roleId, String? troopId) onTroopContextChanged;

  const RoleAssignmentSection({
    super.key,
    required this.selectedRoles,
    required this.availableRoles,
    required this.profile,
    required this.troops,
    required this.roleTroopContext,
    required this.canEditRole,
    required this.isLoadingTroops,
    required this.isRolesReady,
    required this.onRoleToggled,
    required this.onTroopContextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Build a map of current role assignments for quick lookup
    final assignmentMap = <String, RoleAssignment>{};
    for (var assignment in profile.roleAssignments) {
      assignmentMap[assignment.role.id] = assignment;
    }

    final currentRoleNames = profile.roles.map((role) => role.name).join(', ');

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
            color: currentRoleNames.isEmpty
                ? colorScheme.error
                : colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        if (!isRolesReady)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (availableRoles.isEmpty)
          Text(
            'No roles available for assignment',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: availableRoles.map((role) {
                final isSelected = selectedRoles.contains(role);
                final wasAlreadyAssigned = profile.roles.contains(role);
                final assignment = assignmentMap[role.id];
                final isTroopScoped = role.rank == 60 || role.rank == 70;
                final selectedTroopId = roleTroopContext[role.id];

                return Column(
                  children: [
                    CheckboxListTile(
                      value: isSelected,
                      onChanged: canEditRole
                          ? (value) {
                              onRoleToggled(role, value ?? false);
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
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          // Show troop context info for non-selected roles
                          if (!isSelected &&
                              assignment?.troopContextName != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer
                                    .withValues(alpha: 0.5),
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
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
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
                    // Troop context dropdown for troop-scoped roles
                    if (isSelected && isTroopScoped)
                      Padding(
                        padding: EdgeInsets.only(
                          left: screenWidth < 600 ? 8 : 16,
                          right: screenWidth < 600 ? 8 : 16,
                          top: 8,
                          bottom: 12,
                        ),
                        child: _buildTroopContextDropdown(
                          context,
                          role,
                          selectedTroopId,
                          theme,
                          colorScheme,
                          screenWidth,
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

  /// Build troop context dropdown for troop-scoped roles
  Widget _buildTroopContextDropdown(
    BuildContext context,
    Role role,
    String? selectedTroopId,
    ThemeData theme,
    ColorScheme colorScheme,
    double screenWidth,
  ) {
    final troopsById = <String, Map<String, dynamic>>{};
    for (final troop in troops) {
      final troopId = troop['id']?.toString();
      if (troopId == null || troopId.isEmpty) continue;
      troopsById.putIfAbsent(troopId, () => troop);
    }
    final dropdownTroops = troopsById.values.toList();
    final dropdownSelectedTroopId =
        selectedTroopId != null && troopsById.containsKey(selectedTroopId)
        ? selectedTroopId
        : null;

    if (selectedTroopId != null && dropdownSelectedTroopId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onTroopContextChanged(role.id, null);
      });
    }

    if (isLoadingTroops) {
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

    if (dropdownTroops.isEmpty) {
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

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.all(screenWidth < 600 ? 8 : 12),
      child: Column(
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
            initialValue: dropdownSelectedTroopId,
            isExpanded: true, // Allow text to expand and truncate properly
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: screenWidth < 600 ? 12 : 16,
                vertical: screenWidth < 600 ? 10 : 12,
              ),
              filled: true,
              fillColor: colorScheme.surface,
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
                size: 20,
              ),
            ),
            hint: Text(
              'Choose a troop...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            items: dropdownTroops.map((troop) {
              return DropdownMenuItem<String>(
                value: troop['id'] as String,
                child: Text(
                  troop['name'] as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              onTroopContextChanged(role.id, newValue);
              if (newValue == null) {
                debugPrint('🔄 Troop context cleared: ${role.name}');
                return;
              }
              final troopName = troops
                  .firstWhere(
                    (troop) => troop['id'] == newValue,
                    orElse: () => {'name': 'Unknown troop'},
                  )['name']
                  .toString();
              debugPrint(
                '🔄 Troop context updated: ${role.name} -> $troopName',
              );
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
                  Icon(Icons.error_outline, size: 14, color: colorScheme.error),
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
      ),
    );
  }
}
