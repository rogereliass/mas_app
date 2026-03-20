import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:masapp/auth/logic/auth_provider.dart';
import 'package:provider/provider.dart';

import '../../data/models/notification_models.dart';
import '../../logic/notifications_provider.dart';

class NotificationComposeModal extends StatefulWidget {
  const NotificationComposeModal({super.key});

  @override
  State<NotificationComposeModal> createState() =>
      _NotificationComposeModalState();
}

class _NotificationComposeModalState extends State<NotificationComposeModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  NotificationType _selectedType = NotificationType.announcement;
  NotificationTargetType? _selectedTargetType;
  String? _selectedTroopId;
  String? _selectedTargetId;

  List<NotificationTargetOption> _troopOptions = const <NotificationTargetOption>[];
  List<NotificationTargetOption> _targetOptions = const <NotificationTargetOption>[];
  List<NotificationTargetOption> _roleOptions = const <NotificationTargetOption>[];

  bool _isLoadingTargets = false;
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final provider = context.read<NotificationsProvider>();
    final availableTargets = provider.availableTargetTypes;
    if (availableTargets.isEmpty) {
      setState(() {
        _inlineError = 'Your current role cannot send notifications.';
      });
      return;
    }

    _selectedType = NotificationType.announcement;
    _selectedTargetType = availableTargets.first;

    // Auto-infer troop for leaders/heads (Rank 60/70)
    final profile = context.read<AuthProvider>().currentUserProfile;
    final rank = context.read<AuthProvider>().selectedRoleRank;
    if (rank >= 60 && rank <= 80) {
      _selectedTroopId = (profile?.managedTroopId ?? profile?.signupTroopId)?.trim();
    }

    await _loadTargetOptions();
  }

  Future<void> _loadTargetOptions() async {
    final provider = context.read<NotificationsProvider>();
    final targetType = _selectedTargetType;

    if (targetType == null) {
      return;
    }

    setState(() {
      _isLoadingTargets = true;
      _inlineError = null;
      _targetOptions = const <NotificationTargetOption>[];
      if (targetType == NotificationTargetType.all) {
        _selectedTargetId = null;
      }
    });

    try {
      if (targetType == NotificationTargetType.all) {
        setState(() {
          _isLoadingTargets = false;
          _targetOptions = const <NotificationTargetOption>[];
          _selectedTargetId = null;
        });
        return;
      }

      if (targetType == NotificationTargetType.role) {
        final options = await provider.loadRoleTargets();
        setState(() {
          _roleOptions = options;
          _targetOptions = options;
          _selectedTargetId = options.isNotEmpty ? options.first.id : null;
          _isLoadingTargets = false;
        });
        return;
      }

      if (targetType == NotificationTargetType.troop) {
        final options = await provider.loadTroopTargets();
        setState(() {
          _troopOptions = options;
          _targetOptions = options;

          // If user has inferred troop, find it in options or use first
          if (_selectedTroopId != null && options.any((o) => o.id == _selectedTroopId)) {
            _selectedTargetId = _selectedTroopId;
          } else {
            _selectedTargetId = options.isNotEmpty ? options.first.id : null;
          }
          
          _selectedTroopId = _selectedTargetId;
          _isLoadingTargets = false;
        });
        return;
      }

      final troopOptions = await provider.loadTroopTargets();
      String? troopId = _selectedTroopId;
      if (troopId == null || !troopOptions.any((item) => item.id == troopId)) {
        troopId = troopOptions.isNotEmpty ? troopOptions.first.id : null;
      }

      List<NotificationTargetOption> targetOptions;
      if (targetType == NotificationTargetType.patrol) {
        targetOptions = await provider.loadPatrolTargets(selectedTroopId: troopId);
      } else {
        targetOptions = await provider.loadIndividualTargets(selectedTroopId: troopId);
      }

      setState(() {
        _troopOptions = troopOptions;
        _selectedTroopId = troopId;
        _targetOptions = targetOptions;
        _selectedTargetId = targetOptions.isNotEmpty ? targetOptions.first.id : null;
        _isLoadingTargets = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTargets = false;
        _inlineError = _mapUserFacingError(
          e,
          fallback: 'Could not load available targets. Please try again.',
        );
      });
    }
  }

  Future<void> _onTroopChanged(String? troopId) async {
    setState(() {
      _selectedTroopId = troopId;
      _selectedTargetId = null;
    });

    final provider = context.read<NotificationsProvider>();
    try {
      setState(() {
        _isLoadingTargets = true;
      });

      final targetType = _selectedTargetType;
      List<NotificationTargetOption> options;
      if (targetType == NotificationTargetType.patrol) {
        options = await provider.loadPatrolTargets(selectedTroopId: troopId);
      } else {
        options = await provider.loadIndividualTargets(selectedTroopId: troopId);
      }

      setState(() {
        _targetOptions = options;
        _selectedTargetId = options.isNotEmpty ? options.first.id : null;
        _isLoadingTargets = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTargets = false;
        _inlineError = _mapUserFacingError(
          e,
          fallback: 'Could not refresh target options. Please try again.',
        );
      });
    }
  }

  Future<void> _submit() async {
    final provider = context.read<NotificationsProvider>();

    if (_isSubmitting || !provider.canSendNotifications) {
      return;
    }

    setState(() {
      _hasAttemptedSubmit = true;
      _inlineError = null;
    });

    final formIsValid = _formKey.currentState?.validate() ?? false;
    if (!formIsValid) {
      return;
    }

    if (_selectedTargetType != NotificationTargetType.all && _selectedTargetId == null) {
      setState(() {
        _inlineError = 'Please select a valid target.';
      });
      return;
    }

    const Map<String, dynamic> payload = <String, dynamic>{};

    final targetType = _selectedTargetType;
    if (targetType == null) {
      setState(() {
        _inlineError = 'Target type is required.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      final result = await provider.sendNotification(
        request: NotificationCreateRequest(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          type: _selectedType,
          targetType: targetType,
          targetId: _selectedTargetId,
          data: payload,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _inlineError = _mapUserFacingError(
          e,
          fallback: 'Could not send notification. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<NotificationsProvider>();

    final availableTargets = provider.availableTargetTypes;
    final canSend = provider.canSendNotifications;
    final isSystemSender = availableTargets.contains(NotificationTargetType.all);

    if (!canSend) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send Notification',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You are not allowed to send notifications with the currently selected role.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: _hasAttemptedSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send Notification',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Send targetted announcements to members.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                if (_inlineError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _inlineError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _FormSection(
                  title: 'Content',
                  icon: Icons.edit_note_rounded,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'e.g. Tomorrow\'s Meeting Reminder',
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Title is required.';
                        }
                        if (text.length < 3) {
                          return 'Title must be at least 3 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bodyController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 600,
                      decoration: const InputDecoration(
                        labelText: 'Message Body',
                        hintText: 'Enter your message here...',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return 'Body is required.';
                        }
                        if (text.length < 8) {
                          return 'Message must be at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _FormSection(
                  title: 'Recipients',
                  icon: Icons.group_add_rounded,
                  children: [
                    DropdownButtonFormField<NotificationTargetType>(
                      value: _selectedTargetType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Target Type'),
                      items: availableTargets.map((type) {
                        return DropdownMenuItem<NotificationTargetType>(
                          value: type,
                          child: Text(_targetTypeLabel(type)),
                        );
                      }).toList(),
                      onChanged: canSend
                          ? (next) async {
                              if (next == null) return;
                              setState(() {
                                _selectedTargetType = next;
                                _selectedTargetId = null;
                                _inlineError = null;
                              });
                              await _loadTargetOptions();
                            }
                          : null,
                      validator: (value) => value == null
                          ? 'Target type is required.'
                          : null,
                    ),
                    if ((_selectedTargetType == NotificationTargetType.patrol ||
                            _selectedTargetType == NotificationTargetType.individual) &&
                        isSystemSender) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTroopId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Filter by Troop'),
                        items: _troopOptions.map((troop) {
                          return DropdownMenuItem<String>(
                            value: troop.id,
                            child: Text(troop.label),
                          );
                        }).toList(),
                        onChanged: canSend
                            ? (value) {
                                setState(() {
                                  _inlineError = null;
                                });
                                _onTroopChanged(value);
                              }
                            : null,
                        validator: (value) {
                          if (!isSystemSender) {
                            return null;
                          }
                          if (_troopOptions.isEmpty) {
                            return 'No troop options are available.';
                          }
                          if (value == null || value.isEmpty) {
                            return 'Troop is required.';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_selectedTargetType != null &&
                        _selectedTargetType != NotificationTargetType.all) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTargetId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _targetSelectionLabel(_selectedTargetType!),
                        ),
                        items: _targetOptions.map((option) {
                          final label = option.subtitle == null
                              ? option.label
                              : '${option.label} • ${option.subtitle}';
                          return DropdownMenuItem<String>(
                            value: option.id,
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: canSend
                            ? (next) {
                                setState(() {
                                  _selectedTargetId = next;
                                  _inlineError = null;
                                });
                              }
                            : null,
                        validator: (value) {
                          if (_selectedTargetType == NotificationTargetType.all) {
                            return null;
                          }
                          if (_targetOptions.isEmpty) {
                            if (_selectedTargetType == NotificationTargetType.role) {
                              return 'No roles available for selection.';
                            }
                            return 'No selectable targets are available.';
                          }
                          if (value == null || value.isEmpty) {
                            return 'Target is required.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_isSubmitting ? 'Sending...' : 'Send Notification'),
                      ),
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

  String _notificationTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return 'System';
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.meeting:
        return 'Meeting';
      case NotificationType.attendance:
        return 'Attendance';
      case NotificationType.points:
        return 'Points';
    }
  }

  String _targetTypeLabel(NotificationTargetType type) {
    switch (type) {
      case NotificationTargetType.all:
        return 'All users';
      case NotificationTargetType.troop:
        return 'Troop';
      case NotificationTargetType.patrol:
        return 'Patrol';
      case NotificationTargetType.individual:
        return 'Individual';
      case NotificationTargetType.role:
        return 'By Role';
    }
  }

  String _targetSelectionLabel(NotificationTargetType type) {
    switch (type) {
      case NotificationTargetType.all:
        return 'Target';
      case NotificationTargetType.troop:
        return 'Troop';
      case NotificationTargetType.patrol:
        return 'Patrol';
      case NotificationTargetType.individual:
        return 'Member';
      case NotificationTargetType.role:
        return 'Role';
    }
  }

  String _mapUserFacingError(
    Object error, {
    required String fallback,
  }) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return fallback;
    }

    final lower = raw.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('not allowed') ||
        lower.contains('row-level security') ||
        lower.contains('rls') ||
        lower.contains('denied')) {
      return 'You are not allowed to perform this action.';
    }

    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('connection')) {
      return 'Network issue. Please check your connection and try again.';
    }

    if (lower.contains('outside your troop scope')) {
      return 'Selected target is outside your allowed scope.';
    }

    if (lower.contains('no active season')) {
      return 'No active season found. Please activate a season first.';
    }

    return fallback;
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 1.0,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}
