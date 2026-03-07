import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/core/widgets/error_view.dart';
import 'package:masapp/core/widgets/loading_view.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

import '../data/models/point_entry.dart';
import '../logic/points_provider.dart';
import 'components/category_manager_sheet.dart';
import 'components/patrol_score_leaderboard.dart';
import 'components/point_card.dart';
import 'components/point_entry_dialog.dart';

class PointsTab extends StatefulWidget {
  final String? troopId;
  final String? seasonId;

  const PointsTab({super.key, required this.troopId, required this.seasonId});

  @override
  State<PointsTab> createState() => _PointsTabState();
}

class _PointsTabState extends State<PointsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reloadIfScopeReady();
    });
  }

  @override
  void didUpdateWidget(PointsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.troopId != widget.troopId ||
        oldWidget.seasonId != widget.seasonId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _reloadIfScopeReady();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.troopId == null || widget.seasonId == null) {
      return const _WaitingForTroopView();
    }

    return Consumer<PointsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingMeetings) {
          return const LoadingView(message: 'Loading points...');
        }

        if (provider.error != null && provider.meetings.isEmpty) {
          return ErrorView(
            message: provider.error!,
            onRetry: () {
              provider.clearError();
              _reloadIfScopeReady();
            },
          );
        }

        if (provider.noMeetings) {
          return const _NoMeetingsView();
        }

        return Column(
          children: [
            _MeetingDropdown(
              key: ValueKey(provider.selectedMeetingId),
              provider: provider,
            ),
            // TODO(points/custom-categories): surface category management here when leaders can create troop categories.
            if (provider.error != null)
              _InlineErrorBanner(
                message: provider.error!,
                onDismiss: provider.clearError,
              ),
            // TODO(points/approval): add approval controls for troop heads when approval flow is enabled.
            if (provider.canManagePoints)
              _PointsActions(
                provider: provider,
                onAddPoint: () => _showPointSheet(provider),
                onManageCategories: provider.canManageCategories
                    ? () => _showCategoryManagerSheet(provider)
                    : null,
                onTogglePointsVisibility: provider.canTogglePointsVisibility
                    ? () => provider.togglePointsVisibility()
                    : null,
              ),
            Expanded(child: _buildPointsContent(context, provider)),
          ],
        );
      },
    );
  }

  Widget _buildPointsContent(BuildContext context, PointsProvider provider) {
    if (provider.isLoadingPoints) {
      return const LoadingView(message: 'Loading meeting points...');
    }

    if (provider.troopPointsHidden && provider.isReadOnlyMember) {
      return const _PointsHiddenView();
    }

    if (provider.points.isEmpty) {
      return _NoPointsView(
        selectedMeetingName: provider.selectedMeeting?.title,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: provider.points.length + 1,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PatrolScoreLeaderboard(
              summary: provider.selectedMeetingPatrolSummary,
              selectedMeeting: provider.selectedMeeting,
            ),
          );
        }
        
        final entry = provider.points[index - 1];
        return PointCard(
          key: ValueKey(entry.id),
          point: entry,
          isUpdating: provider.isUpdatingPoint(entry.id),
          onEdit: provider.canManagePoints
              ? () => _showPointSheet(provider, entryId: entry.id)
              : null,
        );
      },
    );
  }

  Future<void> _showPointSheet(
    PointsProvider provider, {
    String? entryId,
  }) async {
    final troopId = widget.troopId;
    if (troopId == null) return;

    await provider.ensureLookupDataLoaded(troopId);
    if (!mounted) return;

    final patrolOptions = provider.patrolOptionsForTroop(troopId);
    final categoryOptions = provider.categoryOptionsForTroop(troopId);

    PointEntry? selectedEntry;
    if (entryId != null) {
      for (final entry in provider.points) {
        if (entry.id == entryId) {
          selectedEntry = entry;
          break;
        }
      }
      if (selectedEntry == null) {
        return;
      }
    }

    if (!mounted) return;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return PointEntryDialog(
          patrolOptions: patrolOptions,
          categoryOptions: categoryOptions,
          initialData: selectedEntry?.toFormData(),
          canManageCategories: provider.canManageCategories,
          onManageCategories: provider.canManageCategories
              ? () => _showCategoryManagerSheet(provider)
              : null,
          categoryOptionsResolver: () =>
              provider.categoryOptionsForTroop(troopId),
          onSubmit: (formData) async {
            if (entryId == null) {
              await provider.createPoint(formData);
            } else {
              await provider.updatePoint(entryId, formData);
            }
          },
        );
      },
    );
  }

  Future<String?> _showCategoryManagerSheet(PointsProvider provider) async {
    final troopId = widget.troopId;
    if (troopId == null) return null;

    await provider.ensureLookupDataLoaded(troopId);
    if (!mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CategoryManagerSheet(
          categories: provider.categoryOptionsForTroop(troopId),
          canManageCategories: provider.canManageCategories,
          onCreateCategory: ({required String name, String? description}) {
            return provider.createCategory(
              name: name,
              description: description,
            );
          },
          onUpdateCategory:
              ({
                required String categoryId,
                required String name,
                String? description,
              }) {
                return provider.updateCategory(
                  categoryId: categoryId,
                  name: name,
                  description: description,
                );
              },
        );
      },
    );
  }

  void _reloadIfScopeReady() {
    final troopId = widget.troopId;
    final seasonId = widget.seasonId;
    if (troopId == null || seasonId == null) return;

    Provider.of<PointsProvider>(
      context,
      listen: false,
    ).loadMeetings(troopId: troopId, seasonId: seasonId);
  }
}

class _PointsActions extends StatelessWidget {
  final PointsProvider provider;
  final VoidCallback onAddPoint;
  final VoidCallback? onManageCategories;
  final Future<void> Function()? onTogglePointsVisibility;

  const _PointsActions({
    required this.provider,
    required this.onAddPoint,
    this.onManageCategories,
    this.onTogglePointsVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showManage = onManageCategories != null;
    final showToggle = onTogglePointsVisibility != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          if (showManage || showToggle)
            _buildManageAndVisibilityRow(
              context,
              showManage: showManage,
              showToggle: showToggle,
            ),
          if (showManage || showToggle) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _buildAddButton(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(ThemeData theme, bool isDark) {
    return ElevatedButton.icon(
      onPressed: provider.isSubmitting ? null : onAddPoint,
      icon: provider.isCreatingPoint
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : const Icon(Icons.add_circle_outline, size: 18),
      label: Text(provider.isCreatingPoint ? 'Adding Point...' : 'Add Point'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.goldAccent : AppColors.primaryBlue,
        foregroundColor: isDark
            ? AppColors.textPrimaryLight
            : theme.colorScheme.onPrimary,
        disabledBackgroundColor:
            (isDark ? AppColors.goldAccent : AppColors.primaryBlue).withValues(
              alpha: 0.45,
            ),
        disabledForegroundColor:
            (isDark ? AppColors.textPrimaryLight : theme.colorScheme.onPrimary)
                .withValues(alpha: 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildManageAndVisibilityRow(
    BuildContext context, {
    required bool showManage,
    required bool showToggle,
  }) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
      letterSpacing: -0.2, // slightly tighter to fit more text
    );

    final manageButton = _buildTopActionCard(
      context,
      enabled: !provider.isSubmitting,
      onTap: provider.isSubmitting ? null : onManageCategories,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (provider.isCreatingCategory)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          else
            Icon(
              Icons.tune_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              provider.isCreatingCategory ? 'Saving...' : 'Categories',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );

    final toggleEnabled =
        onTogglePointsVisibility != null && !provider.isSubmitting;

    final toggleVisibilityCard = _buildTopActionCard(
      context,
      enabled: toggleEnabled,
      onTap: !toggleEnabled
          ? null
          : () {
              onTogglePointsVisibility!.call();
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            provider.troopPointsHidden
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              provider.troopPointsHidden ? 'Hidden' : 'Visible',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: 2),
          if (provider.isTogglingPointsVisibility)
            Container(
              margin: const EdgeInsets.only(left: 6, right: 6),
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          else
            Transform.scale(
              scale: 0.75, // Scale down the switch heavily so it fits nice
              child: Switch.adaptive(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: !provider.troopPointsHidden,
                onChanged:
                    onTogglePointsVisibility == null || provider.isSubmitting
                    ? null
                    : (_) async {
                        await onTogglePointsVisibility!.call();
                      },
              ),
            ),
        ],
      ),
    );

    if (showManage && showToggle) {
      return Row(
        children: [
          Expanded(child: manageButton),
          const SizedBox(width: 10),
          Expanded(child: toggleVisibilityCard),
        ],
      );
    }

    if (showManage) {
      return SizedBox(width: double.infinity, child: manageButton);
    }

    return SizedBox(width: double.infinity, child: toggleVisibilityCard);
  }

  Widget _buildTopActionCard(
    BuildContext context, {
    required Widget child,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    final card = Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48, // Fixed exact height for both cards
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35),
            ),
          ),
          child: child,
        ),
      ),
    );

    if (enabled) return card;
    return Opacity(opacity: 0.68, child: card);
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _InlineErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingForTroopView extends StatelessWidget {
  const _WaitingForTroopView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 56,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a troop in the Management tab to view points.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMeetingsView extends StatelessWidget {
  const _NoMeetingsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No meetings found for this season.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPointsView extends StatelessWidget {
  final String? selectedMeetingName;

  const _NoPointsView({required this.selectedMeetingName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          selectedMeetingName == null
              ? 'Select a meeting to view points.'
              : 'No points recorded for "$selectedMeetingName" yet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

class _PointsHiddenView extends StatelessWidget {
  const _PointsHiddenView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF4C1D95).withValues(alpha: 0.3)
                  : const Color(0xFF4C1D95).withValues(alpha: 0.1),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4C1D95).withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            AppColors.leaderboardHeaderStart.withValues(alpha: 0.8),
                            AppColors.leaderboardHeaderEnd.withValues(alpha: 0.9),
                          ]
                        : [
                            AppColors.leaderboardHeaderStart.withValues(alpha: 0.9),
                            const Color(0xFF2E1065),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.leaderboardHeaderStart.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Shh! It\'s a secret for now! 🤫',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'سرٌ مغلق! لم يحن وقت كشف النقاط',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark 
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) 
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'The troop leadership has hidden the points to build up the suspense. Stay tuned!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'النقاط مخفية حالياً من قبل قيادة الفرقة لزيادة الحماس. ترقبوا!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.4,
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

class _MeetingDropdown extends StatelessWidget {
  final PointsProvider provider;

  const _MeetingDropdown({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? AppColors.cardDarkElevated : AppColors.cardLight;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final meetingsById = <String, Meeting>{
      for (final meeting in provider.meetings) meeting.id: meeting,
    };
    final meetings = meetingsById.values.toList();
    final selectedMeetingId = provider.selectedMeetingId;
    final validSelectedMeetingId =
        selectedMeetingId != null && meetingsById.containsKey(selectedMeetingId)
        ? selectedMeetingId
        : null;
    final selectedMeeting = validSelectedMeetingId == null
        ? null
        : meetingsById[validSelectedMeetingId];

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: meetings.isEmpty
            ? null
            : () => _openMeetingSheet(
                context,
                meetings: meetings,
                selectedMeetingId: validSelectedMeetingId,
                onPicked: provider.selectMeeting,
              ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(Icons.event_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Meeting',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: secondaryTextColor,
                      ),
                    ),
                    Text(
                      selectedMeeting == null
                          ? 'Select meeting'
                          : '${selectedMeeting.title} | ${selectedMeeting.formattedDate}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMeetingSheet(
    BuildContext context, {
    required List<Meeting> meetings,
    required String? selectedMeetingId,
    required Future<void> Function(String meetingId) onPicked,
  }) async {
    final theme = Theme.of(context);

    final pickedMeetingId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Meeting',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: meetings.length,
                    itemBuilder: (context, index) {
                      final meeting = meetings[index];
                      final isSelected = meeting.id == selectedMeetingId;

                      return ListTile(
                        leading: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              )
                            : const Icon(Icons.circle_outlined),
                        title: Text(
                          meeting.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          meeting.formattedDate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(meeting.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (pickedMeetingId == null || pickedMeetingId == selectedMeetingId) {
      return;
    }
    await onPicked(pickedMeetingId);
  }
}

// TODO(points/leaderboard): add a summary/leaderboard section once ranking aggregation is implemented.
