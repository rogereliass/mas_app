import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/core/widgets/loading_view.dart';
import 'package:masapp/core/widgets/error_view.dart';
import 'package:masapp/meetings/pages/attendance/logic/attendance_provider.dart';
import 'package:masapp/meetings/pages/attendance/data/models/attendance_record.dart';
import 'package:masapp/meetings/pages/attendance/ui/components/attendance_row.dart';

/// The "Attendance" tab inside MeetingsPage's TabBarView.
/// Allows editors to mark and save attendance for a selected meeting.
// Note: unsaved changes banner is managed by parent MeetingsPage.
class AttendanceTab extends StatefulWidget {
  final String? troopId;
  final String? seasonId;

  const AttendanceTab({
    super.key,
    required this.troopId,
    required this.seasonId,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final troopId = widget.troopId;
      final seasonId = widget.seasonId;
      if (troopId != null && seasonId != null) {
        Provider.of<AttendanceProvider>(context, listen: false)
            .loadMeetings(troopId: troopId, seasonId: seasonId);
      }
    });
  }

  @override
  void didUpdateWidget(AttendanceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when the effective troop or season changes (e.g. admin picks a troop)
    if (widget.troopId != oldWidget.troopId ||
        widget.seasonId != oldWidget.seasonId) {
      final troopId = widget.troopId;
      final seasonId = widget.seasonId;
      if (troopId != null && seasonId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Provider.of<AttendanceProvider>(context, listen: false)
              .loadMeetings(troopId: troopId, seasonId: seasonId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard: no troop/season means we can't load attendance yet.
    // This covers: admin hasn't picked a troop, or member has no troop assigned.
    if (widget.troopId == null || widget.seasonId == null) {
      return const _WaitingForTroopView();
    }

    return Consumer<AttendanceProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const LoadingView(message: 'Loading attendance...');
        }

        if (provider.error != null) {
          return ErrorView(
            message: provider.error!,
            onRetry: () {
              provider.clearError();
              final troopId = widget.troopId;
              final seasonId = widget.seasonId;
              if (troopId != null && seasonId != null) {
                provider.loadMeetings(troopId: troopId, seasonId: seasonId);
              }
            },
          );
        }

        if (provider.noMeetings) {
          return const _NoMeetingsView();
        }

        return Column(
          children: [
            // Meeting selector dropdown.
            // ValueKey forces a fresh FormField state whenever the provider
            // itself changes the selection (e.g. auto-select on load/reload).
            _MeetingDropdown(
              key: ValueKey(provider.selectedMeetingId),
              provider: provider,
            ),
            // Member list
            Expanded(
              child: _buildMemberList(context, provider),
            ),
            // Save button (editors only, when there are unsaved changes)
            if (provider.isEditor && provider.hasUnsavedChanges)
              _SaveButton(provider: provider),
          ],
        );
      },
    );
  }

  Widget _buildMemberList(BuildContext context, AttendanceProvider provider) {
    if (provider.isLoading) {
      return const LoadingView(message: 'Loading members...');
    }

    final patrolGroups = provider.patrolGroups;
    final unassigned = provider.unassignedMembers;

    if (patrolGroups.isEmpty && unassigned.isEmpty) {
      return _NoMembersView(selectedMeeting: provider.selectedMeeting?.title);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Patrol sections
        for (final entry in patrolGroups.entries)
          _PatrolSection(
            patrolName: entry.key,
            members: entry.value,
            provider: provider,
          ),
        // Unassigned members section
        if (unassigned.isNotEmpty)
          _PatrolSection(
            patrolName: 'Unassigned',
            members: unassigned,
            provider: provider,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// No meetings empty state
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// No members empty state
// ---------------------------------------------------------------------------

class _NoMembersView extends StatelessWidget {
  final String? selectedMeeting;
  const _NoMembersView({this.selectedMeeting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          selectedMeeting != null
              ? 'No members found for "$selectedMeeting".'
              : 'Select a meeting to view attendance.',
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

// ---------------------------------------------------------------------------
// Waiting for troop selection (null troopId/seasonId)
// ---------------------------------------------------------------------------

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
              'Select a troop in the Management tab to view attendance.',
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
// Meeting dropdown selector
// ---------------------------------------------------------------------------

class _MeetingDropdown extends StatelessWidget {
  final AttendanceProvider provider;

  const _MeetingDropdown({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor =
        isDark ? AppColors.cardDarkElevated : AppColors.cardLight;

    return Container(
      color: cardColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: DropdownButtonFormField<String>(
        initialValue: provider.selectedMeetingId,
        isExpanded: true,
        itemHeight: 56,
        decoration: InputDecoration(
          labelText: 'Meeting',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
        selectedItemBuilder: (context) {
          return provider.meetings.map((m) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                provider.selectedMeeting?.title ?? m.title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList();
        },
        items: provider.meetings.map((m) {
          return DropdownMenuItem<String>(
            value: m.id,
            child: Text(
              '${m.title} • ${m.formattedDate}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.bodyMedium,
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          if (provider.hasUnsavedChanges) {
            _confirmDiscardAndSwitch(context, provider, value);
          } else {
            provider.selectMeeting(value);
          }
        },
      ),
    );
  }

  Future<void> _confirmDiscardAndSwitch(
    BuildContext context,
    AttendanceProvider provider,
    String meetingId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved attendance changes. Switching meetings will discard them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard & Switch'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      provider.selectMeeting(meetingId);
    }
  }
}

// ---------------------------------------------------------------------------
// Patrol section (header + list of AttendanceRow)
// ---------------------------------------------------------------------------

class _PatrolSection extends StatelessWidget {
  final String patrolName;
  final List<MemberWithAttendance> members;
  final AttendanceProvider provider;

  const _PatrolSection({
    required this.patrolName,
    required this.members,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            patrolName,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? AppColors.dividerDark : AppColors.divider,
        ),
        const SizedBox(height: 6),
        // Members
        ...members.map(
          (member) => AttendanceRow(
            key: ValueKey(member.profileId),
            member: member,
            currentStatus: provider.statusFor(member.profileId),
            isEditor: provider.isEditor,
            onStatusChanged: provider.isEditor
                ? (status) => provider.updateStatus(member.profileId, status)
                : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Save button
// ---------------------------------------------------------------------------

class _SaveButton extends StatelessWidget {
  final AttendanceProvider provider;

  const _SaveButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final modifiedCount = provider.modifiedCount;

    return Container(
      width: double.infinity,
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: ElevatedButton.icon(
        onPressed: provider.isSaving ? null : () => provider.saveChanges(),
        icon: provider.isSaving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimaryLight,
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          provider.isSaving
              ? 'Saving...'
              : 'Save Changes ($modifiedCount unsaved)',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.goldAccent : AppColors.primaryBlue,
          foregroundColor:
              isDark ? AppColors.textPrimaryLight : theme.colorScheme.onPrimary,
          disabledBackgroundColor: (isDark ? AppColors.goldAccent : AppColors.primaryBlue)
              .withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: theme.textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
