import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/patrol.dart';
import '../../data/models/troop_member.dart';

class ManageMembersResult {
  final List<String> selectedMemberIds;

  const ManageMembersResult({required this.selectedMemberIds});
}

class ManageMembersDialog extends StatefulWidget {
  final Patrol patrol;
  final List<TroopMember> troopMembers;
  final Map<String, String> patrolNamesById;

  const ManageMembersDialog({
    super.key,
    required this.patrol,
    required this.troopMembers,
    required this.patrolNamesById,
  });

  @override
  State<ManageMembersDialog> createState() => _ManageMembersDialogState();
}

class _ManageMembersDialogState extends State<ManageMembersDialog> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  late Set<String> _originalMemberIds;
  late Set<String> _selectedMemberIds;
  String _searchQuery = '';

  /// Whether the "All Troop Members" section is expanded.
  bool _allMembersExpanded = false;

  bool get _hasUnsavedChanges {
    return !_setEquals(_selectedMemberIds, _originalMemberIds);
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  @override
  void initState() {
    super.initState();
    _originalMemberIds = widget.troopMembers
        .where((member) => member.patrolId == widget.patrol.id)
        .map((member) => member.id)
        .toSet();
    _selectedMemberIds = Set.from(_originalMemberIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to close?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredMembers = _filteredMembers;
    final assignedFiltered = filteredMembers
        .where((m) => _selectedMemberIds.contains(m.id))
        .toList();
    final unassignedTroopMembers = widget.troopMembers
        .where((m) => m.patrolId == null && !_selectedMemberIds.contains(m.id))
        .toList();
    final unassignedFiltered = _searchQuery.isEmpty
        ? unassignedTroopMembers
        : unassignedTroopMembers.where((m) {
            final q = _searchQuery.trim().toLowerCase();
            return m.fullName.toLowerCase().contains(q) ||
                (m.phone?.toLowerCase().contains(q) ?? false);
          }).toList();
    final allAvailableFiltered =
        filteredMembers.where((m) => !_selectedMemberIds.contains(m.id)).toList();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldClose = await _onWillPop();
        if (shouldClose && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Members • ${widget.patrol.name}',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search members by name or phone',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Assigned Members ──────────────────────────────
                      _SectionHeader(
                          title: 'Assigned Members',
                          count: assignedFiltered.length),
                      const SizedBox(height: 8),
                      if (assignedFiltered.isEmpty)
                        _EmptySection(
                            message: 'No assigned members in current filter')
                      else
                        ...assignedFiltered.map(_buildMemberTile),

                      const SizedBox(height: 16),

                      // ── Unassigned Members (no patrol yet) ────────────
                      _SectionHeader(
                          title: 'Unassigned Members',
                          count: unassignedFiltered.length),
                      const SizedBox(height: 8),
                      if (unassignedFiltered.isEmpty)
                        _EmptySection(
                            message: _searchQuery.isEmpty
                                ? 'All troop members are in a patrol'
                                : 'No unassigned members match your search')
                      else
                        ...unassignedFiltered.map(_buildMemberTile),

                      const SizedBox(height: 16),

                      // ── All Troop Members (collapsible) ───────────────
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(
                            () => _allMembersExpanded = !_allMembersExpanded),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SectionHeader(
                                  title: 'All Troop Members',
                                  count: allAvailableFiltered.length,
                                ),
                              ),
                              Icon(
                                _allMembersExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_allMembersExpanded) ...[
                        const SizedBox(height: 8),
                        if (allAvailableFiltered.isEmpty)
                          _EmptySection(
                              message: 'No available members in current filter')
                        else
                          ...allAvailableFiltered.map(_buildMemberTile),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer actions
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        if (await _onWillPop()) nav.pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _hasUnsavedChanges ? _submit : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Changes'),
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

  List<TroopMember> get _filteredMembers {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.troopMembers;

    return widget.troopMembers.where((member) {
      final fullName = member.fullName.toLowerCase();
      final phone = member.phone?.toLowerCase() ?? '';
      return fullName.contains(query) || phone.contains(query);
    }).toList();
  }

  Widget _buildMemberTile(TroopMember member) {
    final theme = Theme.of(context);
    final selected = _selectedMemberIds.contains(member.id);
    final currentPatrolId = member.patrolId;
    final isInAnotherPatrol =
        currentPatrolId != null && currentPatrolId != widget.patrol.id;

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: selected,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        member.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.displayPhone,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isInAnotherPatrol)
            Text(
              'In: ${widget.patrolNamesById[currentPatrolId] ?? 'another patrol'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      onChanged: (checked) async {
        if (checked == null) return;

        if (checked && isInAnotherPatrol) {
          final fromPatrolName =
              widget.patrolNamesById[currentPatrolId] ?? 'another patrol';
          final shouldMove =
              await _showMoveConfirmation(member.fullName, fromPatrolName);
          if (!mounted || !shouldMove) return;
        }

        setState(() {
          if (checked) {
            _selectedMemberIds.add(member.id);
          } else {
            _selectedMemberIds.remove(member.id);
          }
        });
      },
    );
  }

  Future<bool> _showMoveConfirmation(
      String memberName, String fromPatrolName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Move Member?'),
          content: Text(
            '$memberName currently belongs to $fromPatrolName. Move them to ${widget.patrol.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Move'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
      });
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      ManageMembersResult(selectedMemberIds: _selectedMemberIds.toList()),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
