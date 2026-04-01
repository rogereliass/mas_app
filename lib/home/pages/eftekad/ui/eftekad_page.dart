import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../auth/logic/auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/admin_scope_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../data/eftekad_config.dart';
import '../data/models/eftekad_member.dart';
import '../data/models/eftekad_record.dart';
import '../logic/eftekad_provider.dart';

class EftekadPage extends StatefulWidget {
  const EftekadPage({super.key});

  @override
  State<EftekadPage> createState() => _EftekadPageState();
}

class _EftekadPageState extends State<EftekadPage> {
  final TextEditingController _searchController = TextEditingController();

  AuthProvider? _authProvider;
  bool _initialized = false;
  bool _isAuthListenerAttached = false;
  String? _lastResolvedRoleContext;
  bool _accessDeniedHandled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryInitialize();
  }

  void _tryInitialize() {
    _authProvider ??= context.read<AuthProvider>();
    final authProvider = _authProvider!;

    if (authProvider.profileLoading ||
        authProvider.currentUserProfile == null) {
      if (!_isAuthListenerAttached) {
        authProvider.addListener(_onAuthChanged);
        _isAuthListenerAttached = true;
      }
      return;
    }

    if (_isAuthListenerAttached) {
      authProvider.removeListener(_onAuthChanged);
      _isAuthListenerAttached = false;
    }

    final roleContext = authProvider.selectedRoleName;
    var effectiveRank = roleContext != null
        ? authProvider.getRankForRole(roleContext)
        : authProvider.currentUserRoleRank;

    if (effectiveRank <= 0) {
      effectiveRank = authProvider.currentUserRoleRank;
    }

    if (effectiveRank < 60) {
      if (_accessDeniedHandled) {
        return;
      }

      _accessDeniedHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Access Denied: Eftekad requires rank 60 or above.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      });
      return;
    }

    _accessDeniedHandled = false;

    if (_initialized && roleContext == _lastResolvedRoleContext) {
      return;
    }

    _lastResolvedRoleContext = roleContext;

    if (!_initialized) {
      setState(() {
        _initialized = true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<EftekadProvider>().initialize(selectedRoleName: roleContext);
    });
  }

  void _onAuthChanged() {
    if (!mounted) {
      return;
    }

    final authProvider = _authProvider;
    if (authProvider == null) {
      return;
    }

    if (!authProvider.profileLoading &&
        authProvider.currentUserProfile != null) {
      if (_isAuthListenerAttached) {
        authProvider.removeListener(_onAuthChanged);
        _isAuthListenerAttached = false;
      }
      _tryInitialize();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();

    if (_isAuthListenerAttached && _authProvider != null) {
      _authProvider!.removeListener(_onAuthChanged);
      _isAuthListenerAttached = false;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_initialized) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        appBar: AppBar(title: const Text('Eftekad')),
        body: const LoadingView(message: 'Loading Eftekad...'),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Eftekad'),
        actions: [
          Consumer<EftekadProvider>(
            builder: (context, provider, _) {
              return IconButton(
                onPressed: provider.isLoading ? null : provider.refresh,
                icon: const Icon(Icons.refresh_rounded),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const AdminScopeBanner(),
          _buildFilters(),
          Expanded(
            child: Consumer<EftekadProvider>(
              builder: (context, provider, _) {
                final requiresTroopSelection =
                    provider.isSystemScoped && provider.selectedTroopId == null;

                if (requiresTroopSelection) {
                  return const EmptyView(
                    icon: Icons.groups_rounded,
                    title: 'Select a troop',
                    message: 'Pick a troop first to load Eftekad members.',
                  );
                }

                if (provider.isLoading) {
                  return const LoadingView(message: 'Loading members...');
                }

                if (provider.hasError && provider.visibleMembers.isEmpty) {
                  return ErrorView(
                    message: provider.error ?? 'Unable to load EFTEKAD data.',
                    onRetry: provider.refresh,
                  );
                }

                final groups = provider.groupedMembers;
                if (groups.isEmpty) {
                  return const EmptyView(
                    icon: Icons.person_search_rounded,
                    title: 'No members found',
                    message: 'Try changing search or filters.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: groups.length,
                  separatorBuilder: (_, unused) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _PatrolMembersSection(
                      group: group,
                      onMemberTap: (member) => _openProfileModal(member),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Consumer<EftekadProvider>(
      builder: (context, provider, _) {
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            children: [
              if (provider.isSystemScoped) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: provider.selectedTroopId,
                  decoration: const InputDecoration(
                    labelText: 'Troop',
                    border: OutlineInputBorder(),
                  ),
                  items: provider.troops
                      .map(
                        (troop) => DropdownMenuItem<String>(
                          value: troop['id']?.toString(),
                          child: Text(
                            troop['name']?.toString() ?? 'Unknown troop',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null || value.isEmpty) {
                      return;
                    }
                    provider.setSelectedTroop(value);
                  },
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: provider.selectedPatrolFilter,
                      decoration: const InputDecoration(
                        labelText: 'Patrol',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All patrols'),
                        ),
                        ...provider.patrolFilterOptions.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item['id'],
                            child: Text(
                              item['name'] ?? 'Unknown patrol',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: provider.setPatrolFilter,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Not contacted ${EftekadConfig.notContactedThreshold.inDays}+ days',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Switch.adaptive(
                            value: provider.notContactedOnly,
                            onChanged: provider.setNotContactedOnly,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: provider.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openProfileModal(EftekadMember member) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EftekadProfileDialog(member: member),
    );
  }
}

class _PatrolMembersSection extends StatelessWidget {
  const _PatrolMembersSection({required this.group, required this.onMemberTap});

  final EftekadPatrolGroup group;
  final ValueChanged<EftekadMember> onMemberTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  group.isUnassigned
                      ? Icons.person_outline_rounded
                      : Icons.groups_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${group.members.length}',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...group.members.map(
              (member) => _EftekadMemberTile(
                member: member,
                onTap: () => onMemberTap(member),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EftekadMemberTile extends StatelessWidget {
  const _EftekadMemberTile({required this.member, required this.onTap});

  final EftekadMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<EftekadProvider>();
    final lastContact = provider.lastContactForProfile(member.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        member.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.phone?.trim().isNotEmpty == true
                ? member.phone!
                : 'No phone number',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            lastContact != null
                ? 'Last contact: ${_formatDateTime(lastContact)}'
                : 'Last contact: never',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'View profile',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!member.approved)
            Chip(
              label: const Text('Pending'),
              visualDensity: VisualDensity.compact,
              labelStyle: theme.textTheme.labelSmall,
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _EftekadProfileDialog extends StatefulWidget {
  const _EftekadProfileDialog({required this.member});

  final EftekadMember member;

  @override
  State<_EftekadProfileDialog> createState() => _EftekadProfileDialogState();
}

class _EftekadProfileDialogState extends State<_EftekadProfileDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<EftekadProvider>().loadProfileRecords(
        widget.member.id,
        reset: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer<EftekadProvider>(
            builder: (context, provider, _) {
              final records = provider.recordsForProfile(widget.member.id);
              final lastContact = provider.lastContactForProfile(
                widget.member.id,
              );
              final isLoading = provider.isLoadingRecordsForProfile(
                widget.member.id,
              );
              final hasMore = provider.hasMoreRecordsForProfile(
                widget.member.id,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.member.fullName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _InfoLine(label: 'Phone', value: widget.member.phone),
                  _InfoLine(label: 'Address', value: widget.member.address),
                  _InfoLine(label: 'Patrol', value: widget.member.patrolName),
                  _InfoLine(
                    label: 'Last contact',
                    value: lastContact != null
                        ? _formatDateTime(lastContact)
                        : 'Never',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Records',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: provider.isSavingRecord
                            ? null
                            : () async {
                                await showDialog<bool>(
                                  context: context,
                                  builder: (_) => _AddEftekadRecordDialog(
                                    profileId: widget.member.id,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add record'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (isLoading && records.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: CircularProgressIndicator(),
                            ),
                          if (!isLoading && records.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('No follow-up records yet.'),
                            ),
                          ...records.map(
                            (record) => _RecordTile(record: record),
                          ),
                          if (hasMore)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton(
                                onPressed: isLoading
                                    ? null
                                    : () => provider.loadProfileRecords(
                                        widget.member.id,
                                      ),
                                child: Text(
                                  isLoading ? 'Loading...' : 'Load more',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AddEftekadRecordDialog extends StatefulWidget {
  const _AddEftekadRecordDialog({required this.profileId});

  final String profileId;

  @override
  State<_AddEftekadRecordDialog> createState() =>
      _AddEftekadRecordDialogState();
}

class _AddEftekadRecordDialogState extends State<_AddEftekadRecordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _outcomeController = TextEditingController();

  EftekadRecordType _selectedType = EftekadRecordType.call;
  DateTime? _nextFollowUpDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saveError = context.watch<EftekadProvider>().error;

    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Follow-up Record',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<EftekadRecordType>(
                isExpanded: true,
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: EftekadRecordType.values
                    .map(
                      (type) => DropdownMenuItem<EftekadRecordType>(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Reason is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Notes are required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _outcomeController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Outcome (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _nextFollowUpDate == null
                          ? 'No next follow-up date'
                          : 'Next follow-up: ${_formatDateTime(_nextFollowUpDate!)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Pick date'),
                  ),
                  if (_nextFollowUpDate != null)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _nextFollowUpDate = null;
                        });
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (saveError != null && saveError.trim().isNotEmpty) ...[
                Text(
                  saveError,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(_isSubmitting ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _nextFollowUpDate ?? now,
    );
    if (selected == null) {
      return;
    }

    setState(() {
      _nextFollowUpDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        10,
      );
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final provider = context.read<EftekadProvider>();
    final success = await provider.addRecord(
      profileId: widget.profileId,
      type: _selectedType,
      reason: _reasonController.text,
      notes: _notesController.text,
      outcome: _outcomeController.text,
      nextFollowUpDate: _nextFollowUpDate,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
    });
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final EftekadRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  record.type.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(record.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Reason: ${record.reason}'),
            const SizedBox(height: 4),
            Text('Notes: ${record.notes}'),
            if (record.outcome != null &&
                record.outcome!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Outcome: ${record.outcome!}'),
            ],
            if (record.nextFollowUpDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Next follow-up: ${_formatDateTime(record.nextFollowUpDate!)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value?.trim().isNotEmpty == true ? value! : 'Not available',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
