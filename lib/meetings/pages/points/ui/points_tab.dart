import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/core/widgets/error_view.dart';
import 'package:masapp/core/widgets/loading_view.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

import '../data/models/point_entry.dart';
import '../logic/points_provider.dart';
import 'components/category_manager_sheet.dart';
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

    if (provider.points.isEmpty) {
      return _NoPointsView(
        selectedMeetingName: provider.selectedMeeting?.title,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: provider.points.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = provider.points[index];
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

  const _PointsActions({
    required this.provider,
    required this.onAddPoint,
    this.onManageCategories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final addButton = ElevatedButton.icon(
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
            label: Text(
              provider.isCreatingPoint ? 'Adding...' : 'Add Point',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppColors.goldAccent
                  : AppColors.primaryBlue,
              foregroundColor: isDark
                  ? AppColors.textPrimaryLight
                  : theme.colorScheme.onPrimary,
              disabledBackgroundColor:
                  (isDark ? AppColors.goldAccent : AppColors.primaryBlue)
                      .withValues(alpha: 0.45),
              disabledForegroundColor:
                  (isDark
                          ? AppColors.textPrimaryLight
                          : theme.colorScheme.onPrimary)
                      .withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          );

          final manageButton = OutlinedButton.icon(
            onPressed: provider.isSubmitting ? null : onManageCategories,
            icon: provider.isCreatingCategory
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.tune_outlined, size: 18),
            label: Text(
              provider.isCreatingCategory ? 'Saving...' : 'Manage Categories',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );

          final showManage = onManageCategories != null;

          if (constraints.maxWidth < 500) {
            if (!showManage) {
              return SizedBox(width: double.infinity, child: addButton);
            }

            return Column(
              children: [
                SizedBox(width: double.infinity, child: addButton),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: manageButton),
              ],
            );
          }

          if (!showManage) {
            return Row(children: [Expanded(child: addButton)]);
          }

          return Row(
            children: [
              Expanded(child: addButton),
              const SizedBox(width: 10),
              Expanded(child: manageButton),
            ],
          );
        },
      ),
    );
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
    final borderColor = isDark ? AppColors.dividerDark : AppColors.divider;

    final meetingsById = <String, Meeting>{
      for (final meeting in provider.meetings) meeting.id: meeting,
    };
    final dropdownMeetings = meetingsById.values.toList();
    final selectedMeetingId = provider.selectedMeetingId;
    final dropdownSelectedMeetingId =
        selectedMeetingId != null && meetingsById.containsKey(selectedMeetingId)
        ? selectedMeetingId
        : null;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: DropdownButtonFormField<String>(
          initialValue: dropdownSelectedMeetingId,
          isExpanded: true,
          itemHeight: 58,
          iconEnabledColor: theme.colorScheme.primary,
          dropdownColor: isDark ? AppColors.cardDark : AppColors.cardLight,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
          menuMaxHeight: 320,
          decoration: InputDecoration(
            hintText: 'Select meeting',
            prefixIcon: Icon(Icons.event, color: theme.colorScheme.primary),
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: secondaryTextColor,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          ),
          selectedItemBuilder: (context) {
            return dropdownMeetings.map((meeting) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${meeting.title} | ${meeting.formattedDate}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList();
          },
          items: dropdownMeetings.map((meeting) {
            return DropdownMenuItem<String>(
              value: meeting.id,
              child: Text(
                '${meeting.title} | ${meeting.formattedDate}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            provider.selectMeeting(value);
          },
        ),
      ),
    );
  }
}

// TODO(points/leaderboard): add a summary/leaderboard section once ranking aggregation is implemented.
