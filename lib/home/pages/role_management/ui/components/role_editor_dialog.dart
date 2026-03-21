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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage User Roles',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.profile.fullName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving ? null : _attemptClose,
                      icon: const Icon(Icons.close),
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Roles and Context',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...widget.profile.roleAssignments.map((assignment) {
                        final contextText = assignment.troopContextName == null
                            ? 'No troop context'
                            : 'Troop: ${assignment.troopContextName}';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${assignment.role.name} ($contextText)',
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      Text(
                        'Editable Roles',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigned troop-scoped roles are read-only by default. Use Change context when needed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                        Text(
                          _inlineError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _attemptClose,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
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
}

enum _DialogCloseAction { save, discard, cancel }
