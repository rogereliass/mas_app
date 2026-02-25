import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/core/widgets/loading_view.dart';
import 'package:masapp/core/widgets/error_view.dart';
import 'package:masapp/meetings/components/troop_selector_banner.dart';
import 'package:masapp/meetings/pages/meeting_creation/logic/meetings_provider.dart';
import 'package:masapp/meetings/pages/meeting_creation/ui/components/meeting_card.dart';
import 'package:masapp/meetings/pages/meeting_creation/ui/components/create_meeting_dialog.dart';

/// The "Management" tab shown inside MeetingsPage's TabBarView.
/// Allows editors to view and schedule meetings for the active season.
class ManagementTab extends StatelessWidget {
  const ManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const LoadingView(message: 'Loading meetings...');
        }

        if (provider.error != null) {
          return ErrorView(
            message: provider.error!,
            onRetry: () => provider.init(),
          );
        }

        if (provider.noActiveSeason) {
          return const _NoActiveSeasonView();
        }

        if (provider.needsTroopSelection) {
          return Column(
            children: [
              TroopSelectorBanner(
                troops: provider.troops,
                selectedTroopId: provider.selectedTroopId,
              ),
              const Expanded(
                child: LoadingView(message: 'Select a troop above to continue...'),
              ),
            ],
          );
        }

        return _MeetingsList(provider: provider);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// No active season empty state
// ---------------------------------------------------------------------------

class _NoActiveSeasonView extends StatelessWidget {
  const _NoActiveSeasonView();

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
              Icons.event_busy_outlined,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Season',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No active season found. Meetings cannot be loaded or created.',
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

// ---------------------------------------------------------------------------
// Meetings list body
// ---------------------------------------------------------------------------

class _MeetingsList extends StatelessWidget {
  final MeetingsProvider provider;

  const _MeetingsList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final meetings = provider.meetings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (provider.canEdit) ...[
          _CreateMeetingButton(isCreating: provider.isCreating),
          const SizedBox(height: 20),
        ],
        if (meetings.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Meetings',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: meetings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final meeting = meetings[index];
              return MeetingCard(
                key: ValueKey(meeting.id),
                meeting: meeting,
              );
            },
          ),
        ] else ...[
          const SizedBox(height: 40),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 56,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(height: 12),
                Text(
                  'No meetings scheduled',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                if (provider.canEdit) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tap "Schedule Meeting" to create the first one.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Create meeting button
// ---------------------------------------------------------------------------

class _CreateMeetingButton extends StatelessWidget {
  final bool isCreating;

  const _CreateMeetingButton({required this.isCreating});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.goldAccent : AppColors.primaryBlue;
    final fgColor =
        isDark ? AppColors.textPrimaryLight : theme.colorScheme.onPrimary;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isCreating
            ? null
            : () {
                showDialog(
                  context: context,
                  builder: (_) => const CreateMeetingDialog(),
                );
              },
        icon: const Icon(Icons.add),
        label: const Text('Schedule Meeting'),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          disabledForegroundColor: fgColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle:
              theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
