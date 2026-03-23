import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../logic/season_management_provider.dart';
import '../data/models/season.dart';
import 'components/create_season_dialog.dart';

class SeasonManagementPage extends StatefulWidget {
  const SeasonManagementPage({super.key});

  @override
  State<SeasonManagementPage> createState() => _SeasonManagementPageState();
}

class _SeasonManagementPageState extends State<SeasonManagementPage> {
  bool _hasLoadedSeasons = false;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _authProvider?.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedSeasons) return;
    _attemptLoad();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (_hasLoadedSeasons) return;
    _attemptLoad();
  }

  void _attemptLoad() {
    final authProvider = _authProvider;
    if (authProvider == null) return;
    if (authProvider.profileLoading || authProvider.currentUserProfile == null) {
      return;
    }

    _hasLoadedSeasons = true;

    // Access guard: System-wide admins (rank >= 90) can access
    final userRank = authProvider.currentUserRoleRank;
    final colorScheme = Theme.of(context).colorScheme;

    if (userRank < 90) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access Denied: System Admin privileges required'),
            backgroundColor: colorScheme.error,
          ),
        );
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SeasonManagementProvider>().loadSeasons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<SeasonManagementProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, provider),
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: provider.isLoading
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                : provider.hasError
                    ? SliverToBoxAdapter(child: _buildErrorView(provider.error!))
                    : provider.seasons.isEmpty
                        ? SliverFillRemaining(child: _buildEmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _SeasonCard(season: provider.seasons[index]),
                              childCount: provider.seasons.length,
                            ),
                          ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // FAB space
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        label: const Text('Add Season', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    SeasonManagementProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: colorScheme.surfaceContainerLow,
      centerTitle: false,
      title: const Text('Season Management', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          tooltip: 'Cleanup season notifications',
          icon: const Icon(Icons.delete_sweep_rounded),
          onPressed: provider.isProcessing
              ? null
              : () => _showSeasonCleanupDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: provider.isProcessing
              ? null
              : () => context.read<SeasonManagementProvider>().refresh(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Activity Cycles',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'System Wide',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Establish activity seasons to track training schedules and operations across the system.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.error.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<SeasonManagementProvider>().loadSeasons(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_month_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            'No seasons established',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Get started by creating the first activity season for the system.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateSeasonDialog(),
    );
  }

  Future<void> _showSeasonCleanupDialog(BuildContext context) async {
    final provider = context.read<SeasonManagementProvider>();
    if (provider.seasons.isEmpty) {
      await provider.loadSeasons();
      if (!context.mounted) {
        return;
      }
    }

    if (provider.seasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No seasons available for cleanup.')),
      );
      return;
    }

    String? selectedSeasonId = provider.seasons.first.id;
    String? inlineError;
    String? codeInputError;
    String? nameInputError;
    bool isSubmitting = false;
    final codeController = TextEditingController();
    final nameController = TextEditingController();

    Season? resolveSelectedSeason() {
      for (final season in provider.seasons) {
        if (season.id == selectedSeasonId) {
          return season;
        }
      }
      return null;
    }

    final result = await showDialog<int?>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedSeason = resolveSelectedSeason();
            final expectedCode = selectedSeason?.seasonCode.trim() ?? '';
            final expectedName =
                ((selectedSeason?.name ?? '').trim().isNotEmpty)
                    ? selectedSeason!.name!.trim()
                    : expectedCode;
            final canSubmit =
                !isSubmitting &&
                expectedCode.isNotEmpty &&
                codeController.text.trim().isNotEmpty &&
                nameController.text.trim().isNotEmpty;

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cleanup Notifications',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Delete all notifications and recipients for a selected season.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSeasonId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Season',
                        ),
                        items: provider.seasons.map((season) {
                          final name = (season.name?.trim().isNotEmpty ?? false)
                              ? season.name!.trim()
                              : season.seasonCode;
                          return DropdownMenuItem<String>(
                            value: season.id,
                            child: Text(
                              '$name (${season.seasonCode})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedSeasonId = value;
                                  inlineError = null;
                                  codeInputError = null;
                                  nameInputError = null;
                                  codeController.clear();
                                  nameController.clear();
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Type the following exactly to confirm deletion:\n'
                          'Code: $expectedCode\n'
                          'Name: $expectedName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Type season code to confirm',
                          errorText: codeInputError,
                        ),
                        onChanged: (_) {
                          setDialogState(() {
                            codeInputError = null;
                            inlineError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Type season name to confirm',
                          errorText: nameInputError,
                        ),
                        onChanged: (_) {
                          setDialogState(() {
                            nameInputError = null;
                            inlineError = null;
                          });
                        },
                      ),
                      if (inlineError != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            inlineError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: canSubmit
                                ? () async {
                                    if (selectedSeason == null) {
                                      setDialogState(() {
                                        inlineError = 'Season is required.';
                                      });
                                      return;
                                    }

                                    final enteredCode = codeController.text.trim();
                                    final enteredName = nameController.text.trim();

                                    final codeMatches = enteredCode == expectedCode;
                                    final nameMatches = enteredName == expectedName;

                                    if (!codeMatches || !nameMatches) {
                                      setDialogState(() {
                                        if (!codeMatches) {
                                          codeInputError =
                                              'Code does not match the selected season.';
                                        }
                                        if (!nameMatches) {
                                          nameInputError =
                                              'Name does not match the selected season.';
                                        }
                                        inlineError =
                                            'Confirmation text mismatch. Deletion blocked.';
                                      });
                                      return;
                                    }

                                    setDialogState(() {
                                      isSubmitting = true;
                                      inlineError = null;
                                      codeInputError = null;
                                      nameInputError = null;
                                    });

                                    final deletedCount =
                                        await provider.cleanupNotificationsForSeason(
                                      selectedSeason.id,
                                    );

                                    if (!context.mounted) {
                                      return;
                                    }

                                    if (deletedCount == null) {
                                      setDialogState(() {
                                        isSubmitting = false;
                                        inlineError = provider.error ??
                                            'Cleanup failed. Please try again.';
                                      });
                                      return;
                                    }

                                    Navigator.of(dialogContext).pop(deletedCount);
                                  }
                                : null,
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_forever_rounded),
                            label: Text(
                              isSubmitting ? 'Cleaning...' : 'Delete Season Notifications',
                            ),
                          ),
                        ],
                      ),
                      // TODO(notifications/automation): trigger this cleanup automatically when a season ends.
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    codeController.dispose();
    nameController.dispose();

    if (!context.mounted || result == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted $result notification(s) for the selected season.'),
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  final Season season;

  const _SeasonCard({required this.season});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    
    // Determine status
    String status = 'Upcoming';
    Color statusColor = Colors.orange;
    
    if (season.startDate != null && season.endDate != null) {
      if (now.isAfter(season.startDate!) && now.isBefore(season.endDate!)) {
        status = 'Active';
        statusColor = Colors.green;
      } else if (now.isAfter(season.endDate!)) {
        status = 'Finished';
        statusColor = Colors.grey;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Future: Edit season or view details
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        season.seasonCode,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(status, statusColor, colorScheme),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  season.name ?? 'Standard Season',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateInfo(
                        context,
                        Icons.login_rounded,
                        'Start Date',
                        season.startDate?.toString().split(' ')[0] ?? 'N/A',
                      ),
                    ),
                    Container(
                      height: 30,
                      width: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    Expanded(
                      child: _buildDateInfo(
                        context,
                        Icons.logout_rounded,
                        'End Date',
                        season.endDate?.toString().split(' ')[0] ?? 'N/A',
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

  Widget _buildStatusChip(String label, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
