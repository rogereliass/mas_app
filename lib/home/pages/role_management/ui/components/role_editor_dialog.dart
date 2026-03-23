import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../auth/logic/auth_provider.dart';
import '../../../../../auth/models/role.dart';
import '../../../user_management/data/models/managed_user_profile.dart';
import '../../../user_management/ui/components/role_assignment_section.dart';
import '../../logic/role_management_provider.dart';

class RoleEditorDialog extends StatefulWidget {
  final ManagedUserProfile profile;

  const RoleEditorDialog({super.key, required this.profile});

  @override
  State<RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends State<RoleEditorDialog> {
  final List<Role> _selectedEditableRoles = [];
  final Map<String, String?> _roleTroopContext = {};
  final Set<String> _editableAssignedContextRoleIds = <String>{};

  late final Set<String> _initialSelectedRoleIds;
  late final Map<String, String?> _initialRoleTroopContext;

  List<Map<String, dynamic>> _troops = [];
  bool _isLoadingTroops = false;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();

    _selectedEditableRoles.addAll(widget.profile.roles);
    for (final assignment in widget.profile.roleAssignments) {
      _roleTroopContext[assignment.role.id] = assignment.troopContextId;
    }

    _initialSelectedRoleIds = _selectedEditableRoles.map((r) => r.id).toSet();
    _initialRoleTroopContext = Map<String, String?>.from(_roleTroopContext);

    _loadTroops();
  }

  void _updateUnsavedChanges() {
    final currentRoleIds = _selectedEditableRoles.map((r) => r.id).toSet();
    final roleIdsChanged =
        currentRoleIds.length != _initialSelectedRoleIds.length ||
        !currentRoleIds.containsAll(_initialSelectedRoleIds);

    bool contextChanged = false;
    final allContextRoleIds = {
      ..._initialRoleTroopContext.keys,
      ..._roleTroopContext.keys,
    };

    for (final roleId in allContextRoleIds) {
      if ((_initialRoleTroopContext[roleId] ?? '') !=
          (_roleTroopContext[roleId] ?? '')) {
        contextChanged = true;
        break;
      }
    }

    _hasUnsavedChanges = roleIdsChanged || contextChanged;
  }

  Future<void> _attemptClose() async {
    if (_isSaving) {
      return;
    }

    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }

    final action = await _showUnsavedChangesPrompt();
    if (!mounted) return;

    if (action == _DialogCloseAction.save) {
      await _save();
      return;
    }

    if (action == _DialogCloseAction.discard) {
      Navigator.of(context).pop();
    }
  }

  Future<_DialogCloseAction?> _showUnsavedChangesPrompt() {
    return showDialog<_DialogCloseAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('Save changes before closing?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_DialogCloseAction.discard);
              },
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_DialogCloseAction.cancel);
              },
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(_DialogCloseAction.save);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadTroops() async {
    setState(() {
      _isLoadingTroops = true;
    });

    try {
      final troops = await context.read<AuthProvider>().getTroops();
      if (!mounted) return;
      setState(() {
        _troops = troops;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inlineError = 'Unable to load troops for context selection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTroops = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _inlineError = null;
    });

    if (_selectedEditableRoles.isEmpty) {
      setState(() {
        _inlineError = 'At least one editable role should remain assigned.';
      });
      return;
    }

    final provider = context.read<RoleManagementProvider>();

    for (final role in _selectedEditableRoles) {
      if ((role.rank == 60 || role.rank == 70) &&
          (_roleTroopContext[role.id] == null ||
              _roleTroopContext[role.id]!.isEmpty)) {
        setState(() {
          _inlineError = 'Troop context is required for troop-scoped roles.';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    final success = await provider.updateRolesForUser(
      profile: widget.profile,
      selectedEditableRoles: _selectedEditableRoles,
      roleTroopContextMap: _roleTroopContext,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      if (!success) {
        _inlineError = provider.error ?? 'Failed to save role changes.';
      }
    });

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<RoleManagementProvider>();

    final assignableRoles = provider.assignableRoles;
    final assignableRoleIds = provider.assignableRoleIds;

    final selectedVisibleRoles = _selectedEditableRoles
        .where((role) => assignableRoleIds.contains(role.id))
        .toList();

    return PopScope(
      canPop: !_hasUnsavedChanges || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _attemptClose();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.manage_accounts,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Roles',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.profile.fullName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving ? null : _attemptClose,
                      icon: const Icon(Icons.close, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        title: 'Assigned Roles',
                        icon: Icons.verified_user_outlined,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            widget.profile.roleAssignments.map((assignment) {
                          final contextText =
                              assignment.troopContextName ?? 'Global';

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${assignment.role.name} ($contextText)',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        context,
                        title: 'Edit Assignments',
                        icon: Icons.edit_note_outlined,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigned troop-scoped roles are read-only. Use the edit icon to change context.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      RoleAssignmentSection(
                        selectedRoles: selectedVisibleRoles,
                        availableRoles: assignableRoles,
                        profile: widget.profile,
                        troops: _troops,
                        roleTroopContext: _roleTroopContext,
                        canEditRole: true,
                        isLoadingTroops: _isLoadingTroops,
                        isRolesReady: !provider.isLoadingRoles,
                        lockTroopContextForExistingAssignments: true,
                        editableExistingTroopContextRoleIds:
                            _editableAssignedContextRoleIds,
                        onRequestEditTroopContext: (roleId) {
                          setState(() {
                            _editableAssignedContextRoleIds.add(roleId);
                          });
                        },
                        onRoleToggled: (role, isSelected) {
                          setState(() {
                            if (isSelected) {
                              if (!_selectedEditableRoles.any(
                                (r) => r.id == role.id,
                              )) {
                                _selectedEditableRoles.add(role);
                              }
                              _updateUnsavedChanges();
                              return;
                            }

                            _selectedEditableRoles.removeWhere(
                              (r) => r.id == role.id,
                            );
                            _roleTroopContext.remove(role.id);
                            _editableAssignedContextRoleIds.remove(role.id);
                            _updateUnsavedChanges();
                          });
                        },
                        onTroopContextChanged: (roleId, troopId) {
                          setState(() {
                            _roleTroopContext[roleId] = troopId;
                            _updateUnsavedChanges();
                          });
                        },
                      ),
                      if (_inlineError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _inlineError!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isSaving ? null : _attemptClose,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox.shrink()
                            : const Icon(Icons.save_outlined, size: 20),
                        label: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

enum _DialogCloseAction { save, discard, cancel }
