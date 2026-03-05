import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../auth/logic/auth_provider.dart';
import '../../../../core/widgets/admin_scope_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../data/models/patrol.dart';
import '../data/models/troop_member.dart';
import '../logic/patrols_management_provider.dart';
import 'components/manage_members_dialog.dart';
import 'components/patrol_card.dart';
import 'components/patrol_form_dialog.dart';

class PatrolsManagementPage extends StatefulWidget {
  const PatrolsManagementPage({super.key});

  @override
  State<PatrolsManagementPage> createState() => _PatrolsManagementPageState();
}

class _PatrolsManagementPageState extends State<PatrolsManagementPage> {
  String? _roleContext;
  int? _effectiveRank;
  // Guards against running initialization more than once per valid state
  bool _initialized = false;
  // Track last resolved role so didChangeDependencies can detect a change
  String? _lastResolvedRole;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryInitialize();
  }

  void _tryInitialize() {
    final authProvider = context.read<AuthProvider>();

    // Wait until profile is loaded
    if (authProvider.profileLoading ||
        authProvider.currentUserProfile == null) {
      // Re-listen so we retry when auth state changes
      authProvider.addListener(_onAuthChanged);
      return;
    }

    // Resolve role from global app state.
    final resolvedRole = authProvider.selectedRoleName;

    // Skip re-init if nothing has changed
    if (_initialized && resolvedRole == _lastResolvedRole) return;

    final patrolsProvider = Provider.of<PatrolsManagementProvider>(
      context,
      listen: false,
    );

    _roleContext = resolvedRole;
    _lastResolvedRole = resolvedRole;

    if (resolvedRole != null) {
      final selectedRank = authProvider.getRankForRole(resolvedRole);
      _effectiveRank = selectedRank > 0
          ? selectedRank
          : authProvider.currentUserRoleRank;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        patrolsProvider.setRoleContext(resolvedRole);
      });
    } else {
      _effectiveRank = authProvider.currentUserRoleRank;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        patrolsProvider.clearRoleContext();
      });
    }

    final rank = _effectiveRank ?? 0;

    if (rank < 60) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access Denied: Admin privileges required'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      });
      return;
    }

    final user = authProvider.currentUserProfile;
    if (rank >= 60 && rank < 90 && user?.managedTroopId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Access Error: No troop assigned. Please contact an administrator.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      });
      return;
    }

    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      patrolsProvider.initialize(selectedRoleName: _roleContext);
    });
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.profileLoading &&
        authProvider.currentUserProfile != null) {
      authProvider.removeListener(_onAuthChanged);
      _tryInitialize();
    }
  }

  @override
  void dispose() {
    // Safely remove the listener if it was ever added
    try {
      context.read<AuthProvider>().removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Show a loading screen while waiting for auth/profile
      return Scaffold(
        appBar: AppBar(title: const Text('Patrols Management')),
        body: const LoadingView(message: 'Loading...'),
      );
    }
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Patrols Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Patrols'),
              Tab(text: 'Unassigned Members'),
            ],
          ),
          actions: [
            Consumer<PatrolsManagementProvider>(
              builder: (context, provider, _) {
                return IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: provider.isLoading
                      ? null
                      : () =>
                            provider.loadPatrolsAndMembers(forceRefresh: true),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            const AdminScopeBanner(),
            _buildTroopSelector(),
            Expanded(
              child: Consumer<PatrolsManagementProvider>(
                builder: (context, provider, _) {
                  if (_shouldPromptTroopSelection(provider)) {
                    return const EmptyView(
                      icon: Icons.groups_3_outlined,
                      title: 'Select a troop',
                      message:
                          'Choose a troop first to view and manage patrols.',
                    );
                  }

                  if (provider.isLoading) {
                    return const LoadingView(message: 'Loading patrols...');
                  }

                  if (provider.hasError) {
                    return ErrorView(
                      message: provider.error ?? 'Unknown error occurred',
                      onRetry: () =>
                          provider.loadPatrolsAndMembers(forceRefresh: true),
                    );
                  }

                  return TabBarView(
                    children: [
                      _buildPatrolsTab(provider),
                      _buildUnassignedTab(provider),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: Consumer<PatrolsManagementProvider>(
          builder: (context, provider, _) {
            if (_shouldPromptTroopSelection(provider)) {
              return const SizedBox.shrink();
            }

            return FloatingActionButton.extended(
              onPressed: provider.isProcessing
                  ? null
                  : () => _showCreatePatrolDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Patrol'),
            );
          },
        ),
      ),
    );
  }

  bool _shouldPromptTroopSelection(PatrolsManagementProvider provider) {
    final isSystemScoped = (_effectiveRank ?? 0) >= 90;
    return isSystemScoped && provider.selectedTroopId == null;
  }

  Widget _buildTroopSelector() {
    return Consumer<PatrolsManagementProvider>(
      builder: (context, provider, _) {
        final isSystemScoped = (_effectiveRank ?? 0) >= 90;

        if (!isSystemScoped) {
          return const SizedBox.shrink();
        }

        final troops = provider.troops;
        final selectedTroopId = provider.selectedTroopId;
        final dropdownSelectedTroopId =
            selectedTroopId != null &&
                troops.any((troop) => troop['id'] == selectedTroopId)
            ? selectedTroopId
            : null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: DropdownButtonFormField<String>(
            key: ValueKey(dropdownSelectedTroopId ?? 'none'),
            initialValue: dropdownSelectedTroopId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Troop *',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: troops
                .map(
                  (troop) => DropdownMenuItem<String>(
                    value: troop['id'] as String,
                    child: Text(
                      (troop['name'] as String?) ?? 'Unnamed Troop',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: provider.isLoadingTroops || provider.isLoading
                ? null
                : (value) {
                    if (value == null) return;
                    provider.setSelectedTroop(value);
                  },
          ),
        );
      },
    );
  }

  Widget _buildPatrolsTab(PatrolsManagementProvider provider) {
    final patrolItems = provider.patrolsWithMembers;

    if (patrolItems.isEmpty) {
      return const EmptyView(
        icon: Icons.shield_outlined,
        title: 'No patrols yet',
        message: 'Create your first patrol to start assigning members.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: patrolItems.length,
      itemBuilder: (context, index) {
        final item = patrolItems[index];
        return PatrolCard(
          key: ValueKey(item.patrol.id),
          item: item,
          onManageMembers: () => _showManageMembersDialog(context, item.patrol),
          onEdit: () => _showEditPatrolDialog(context, item.patrol),
          onDelete: () => _confirmDeletePatrol(context, item.patrol),
        );
      },
    );
  }

  Widget _buildUnassignedTab(PatrolsManagementProvider provider) {
    final members = provider.unassignedMembers;

    if (members.isEmpty) {
      return const EmptyView(
        icon: Icons.check_circle_outline,
        title: 'All members are assigned',
        message: 'No unassigned members in this troop.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = members[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            title: Text(
              member.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              member.displayPhone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _AssignInlineButton(
              member: member,
              patrols: provider.patrols,
              onAssign: (patrolId) => _assignMember(context, member, patrolId),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreatePatrolDialog(BuildContext context) async {
    final provider = context.read<PatrolsManagementProvider>();

    final result = await showDialog<PatrolFormResult>(
      context: context,
      builder: (context) => PatrolFormDialog(),
    );

    if (!context.mounted || result == null) return;

    final success = await provider.createPatrol(
      name: result.name,
      description: result.description,
      patrolLeaderProfileId: result.patrolLeaderProfileId,
      assistant1ProfileId: result.assistant1ProfileId,
      assistant2ProfileId: result.assistant2ProfileId,
    );

    if (!context.mounted) return;
    _showResultSnackBar(
      context,
      success: success,
      successMessage: 'Patrol created successfully',
      errorMessage: provider.error ?? 'Unable to create patrol',
    );
  }

  Future<void> _showEditPatrolDialog(
    BuildContext context,
    Patrol patrol,
  ) async {
    final provider = context.read<PatrolsManagementProvider>();

    final result = await showDialog<PatrolFormResult>(
      context: context,
      builder: (context) => PatrolFormDialog(
        initialPatrol: patrol,
        leaderCandidates: provider.troopMembers
            .where((m) => m.patrolId == patrol.id)
            .toList(),
      ),
    );

    if (!context.mounted || result == null) return;

    final success = await provider.updatePatrol(
      patrolId: patrol.id,
      name: result.name,
      description: result.description,
      patrolLeaderProfileId: result.patrolLeaderProfileId,
      assistant1ProfileId: result.assistant1ProfileId,
      assistant2ProfileId: result.assistant2ProfileId,
    );

    if (!context.mounted) return;
    _showResultSnackBar(
      context,
      success: success,
      successMessage: 'Patrol updated successfully',
      errorMessage: provider.error ?? 'Unable to update patrol',
    );
  }

  Future<void> _showManageMembersDialog(
    BuildContext context,
    Patrol patrol,
  ) async {
    final provider = context.read<PatrolsManagementProvider>();
    final patrolNameById = {
      for (final item in provider.patrols) item.id: item.name,
    };

    final result = await showDialog<ManageMembersResult>(
      context: context,
      builder: (context) => ManageMembersDialog(
        patrol: patrol,
        troopMembers: provider.troopMembers,
        patrolNamesById: patrolNameById,
      ),
    );

    if (!context.mounted || result == null) return;

    final success = await provider.updatePatrolMembers(
      patrolId: patrol.id,
      memberIds: result.selectedMemberIds,
    );

    if (!context.mounted) return;
    _showResultSnackBar(
      context,
      success: success,
      successMessage: 'Patrol members updated',
      errorMessage: provider.error ?? 'Unable to update patrol members',
    );
  }

  Future<void> _assignMember(
    BuildContext context,
    TroopMember member,
    String patrolId,
  ) async {
    final provider = context.read<PatrolsManagementProvider>();

    final success = await provider.assignMemberToPatrol(
      memberProfileId: member.id,
      patrolId: patrolId,
    );

    if (!context.mounted) return;
    _showResultSnackBar(
      context,
      success: success,
      successMessage: 'Member assigned successfully',
      errorMessage: provider.error ?? 'Unable to assign member',
    );
  }

  Future<void> _confirmDeletePatrol(BuildContext context, Patrol patrol) async {
    final provider = context.read<PatrolsManagementProvider>();
    final theme = Theme.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final confirmController = TextEditingController();
        var canDelete = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Delete Patrol?',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently delete "${patrol.name}" and all its members will become unassigned.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type the patrol name to confirm:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: patrol.name,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      errorText:
                          confirmController.text.isNotEmpty &&
                              confirmController.text != patrol.name
                          ? 'Name does not match'
                          : null,
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        canDelete = value == patrol.name;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: canDelete
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    disabledBackgroundColor: theme.colorScheme.error.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!context.mounted || shouldDelete != true) return;

    final success = await provider.deletePatrol(patrol.id);

    if (!context.mounted) return;
    _showResultSnackBar(
      context,
      success: success,
      successMessage: 'Patrol deleted successfully',
      errorMessage: provider.error ?? 'Unable to delete patrol',
    );
  }

  void _showResultSnackBar(
    BuildContext context, {
    required bool success,
    required String successMessage,
    required String errorMessage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMessage : errorMessage),
        backgroundColor: success ? colorScheme.primary : colorScheme.error,
      ),
    );
  }
}

/// A small inline button that opens a PopupMenu of patrols directly — no dialog.
class _AssignInlineButton extends StatelessWidget {
  final TroopMember member;
  final List<Patrol> patrols;
  final void Function(String patrolId) onAssign;

  const _AssignInlineButton({
    required this.member,
    required this.patrols,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    if (patrols.isEmpty) {
      return TextButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Create a patrol first before assigning members'),
            ),
          );
        },
        icon: const Icon(Icons.add_link_outlined),
        label: const Text('Assign'),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Assign to patrol',
      onSelected: onAssign,
      itemBuilder: (context) => patrols
          .map(
            (patrol) => PopupMenuItem<String>(
              value: patrol.id,
              child: Text(
                patrol.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_link_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Assign',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
