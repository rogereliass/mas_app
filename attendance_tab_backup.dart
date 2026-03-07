import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/core/widgets/loading_view.dart';
import 'package:masapp/core/widgets/error_view.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';
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
        Provider.of<AttendanceProvider>(
          context,
          listen: false,
        ).loadMeetings(troopId: troopId, seasonId: seasonId);
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
          Provider.of<AttendanceProvider>(
            context,
            listen: false,
          ).loadMeetings(troopId: troopId, seasonId: seasonId);
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

        if (!provider.isEditor) {
          return _ScoutAttendanceView(provider: provider);
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
            if (provider.isEditor) _AttendanceActions(provider: provider),
            // Member list
            Expanded(child: _buildMemberList(context, provider)),
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
// Attendance actions below dropdown (scan + manual save)
// ---------------------------------------------------------------------------

class _AttendanceActions extends StatelessWidget {
  final AttendanceProvider provider;

  const _AttendanceActions({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          final scanButton = _ScanQrCodesButton(provider: provider);
          final saveButton = _SaveAttendanceButton(provider: provider);

          if (isNarrow) {
            return Column(
              children: [
                SizedBox(width: double.infinity, child: scanButton),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: saveButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: scanButton),
              const SizedBox(width: 12),
              Expanded(child: saveButton),
            ],
          );
        },
      ),
    );
  }
}

class _ScanQrCodesButton extends StatelessWidget {
  final AttendanceProvider provider;

  const _ScanQrCodesButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR scanning will be added soon.')),
        );
      },
      icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
      label: const Text('Scan QR Codes'),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        side: BorderSide(
          color: isDark ? AppColors.dividerDark : AppColors.divider,
        ),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SaveAttendanceButton extends StatelessWidget {
  final AttendanceProvider provider;

  const _SaveAttendanceButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ElevatedButton.icon(
      onPressed: (provider.isSaving || !provider.hasUnsavedChanges)
          ? null
          : () => provider.saveChanges(),
      icon: provider.isSaving
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark
                    ? AppColors.textPrimaryLight
                    : theme.colorScheme.onPrimary,
              ),
            )
          : const Icon(Icons.save_outlined, size: 18),
      label: Text(
        provider.isSaving
            ? 'Saving...'
            : provider.hasUnsavedChanges
            ? 'Save Attendance (${provider.modifiedCount})'
            : 'Save Attendance',
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
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
                          : '${selectedMeeting.title} • ${selectedMeeting.formattedDate}',
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
        // Section header — card with left accent border + member count badge
        Container(
          margin: const EdgeInsets.only(top: 20, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(
              alpha: isDark ? 0.18 : 0.28,
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.group_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  patrolName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Member count chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${members.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Members
        ...members.map(
          (member) => AttendanceRow(
            key: ValueKey(member.profileId),
            member: member,
            currentStatus: provider.statusFor(member.profileId),
            isEditor: provider.isEditor,
            currentNote: provider.notesFor(member.profileId),
            onStatusChanged: provider.isEditor
                ? (status) => provider.updateStatus(member.profileId, status)
                : null,
            onNotesTap: provider.isEditor
                ? () => _showNoteDialog(context, member, provider)
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _showNoteDialog(
    BuildContext context,
    MemberWithAttendance member,
    AttendanceProvider provider,
  ) async {
    final controller = TextEditingController(
      text: provider.notesFor(member.profileId) ?? '',
    );
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        member.initialsName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            member.displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Attendance Note',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Note text field
                TextField(
                  controller: controller,
                  maxLines: 3,
                  minLines: 2,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Add a note for this attendance record...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save Note'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Capture text now (dialog has been popped) and perform save if requested.
    final noteText = controller.text;
    if (result == true && context.mounted) {
      try {
        await provider.updateNotes(member.profileId, noteText);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save note. Please try again.'),
            ),
          );
        }
      }
    }

    // Dispose the controller after the next frame to ensure the TextField
    // has been fully removed from the widget tree and cleared its listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller.dispose();
      } catch (_) {
        // Swallow: defensive - controller may already be disposed by framework.
      }
    });
  }
}
// ---------------------------------------------------------------------------
// Scout Attendance View (Non-editor)
// ---------------------------------------------------------------------------

class _ScoutAttendanceView extends StatelessWidget {
  final AttendanceProvider provider;
  const _ScoutAttendanceView({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const LoadingView(message: 'Loading your attendance...');
    }

    if (provider.myLogs.isEmpty) {
      return const _NoMeetingsView();
    }

    return Column(
      children: [
        _ScoutStatsCard(provider: provider),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: provider.myLogs.length,
            itemBuilder: (context, index) {
              final log = provider.myLogs[index];
              return _LogCard(
                key: ValueKey(log.meeting.id),
                log: log,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScoutStatsCard extends StatelessWidget {
  final AttendanceProvider provider;
  const _ScoutStatsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total = provider.myLogs.length;
    final present = provider.scoutPresentCount;
    final lateCount = provider.scoutLateCount;
    final absent = provider.scoutAbsentCount;
    final excused = provider.scoutExcusedCount;
    final unrecorded = provider.scoutUnrecordedCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFFE0E0E0)) // AppColors.divider fallback
                .withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Overview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                ' Meetings',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Horizontal Segmentation Bar
          Container(
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDark ? AppColors.dividerDark : AppColors.divider,
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                if (present > 0)
                  Expanded(
                    flex: present,
                    child: Container(color: AppColors.success),
                  ),
                if (lateCount > 0)
                  Expanded(
                    flex: lateCount,
                    child: Container(color: AppColors.warning),
                  ),
                if (absent > 0)
                  Expanded(
                    flex: absent,
                    child: Container(color: AppColors.error),
                  ),
                if (excused > 0)
                  Expanded(
                    flex: excused,
                    child: Container(color: AppColors.info),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (present > 0) _StatBadge(label: 'Present ()', color: AppColors.success),
                  if (lateCount > 0) _StatBadge(label: 'Late ()', color: AppColors.warning),
                  if (absent > 0) _StatBadge(label: 'Absent ()', color: AppColors.error),
                  if (excused > 0) _StatBadge(label: 'Excused ()', color: AppColors.info),
                  if (unrecorded > 0)
                    _StatBadge(
                      label: 'Unrecorded ()',
                      color: isDark ? AppColors.textSecondaryDark : AppColors.divider,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final MyAttendanceLog log;
  const _LogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isRecorded = log.isRecorded;
    final status = log.record?.status;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (!isRecorded) {
      statusColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      statusLabel = 'Not Recorded';
      statusIcon = Icons.help_outline;
    } else {
      switch (status!) {
        case AttendanceStatus.present:
          statusColor = AppColors.success;
          statusLabel = 'Present';
          statusIcon = Icons.check_circle_outline;
          break;
        case AttendanceStatus.absent:
          statusColor = AppColors.error;
          statusLabel = 'Absent';
          statusIcon = Icons.cancel_outlined;
          break;
        case AttendanceStatus.late:
          statusColor = AppColors.warning;
          statusLabel = 'Late';
          statusIcon = Icons.watch_later_outlined;
          break;
        case AttendanceStatus.excused:
          statusColor = AppColors.info;
          statusLabel = 'Excused';
          statusIcon = Icons.info_outline;
          break;
      }
    }

    final hasNotes = log.record?.notes != null && log.record!.notes!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.meeting.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.meeting.formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasNotes) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote,
                    size: 16,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.record!.notes!.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
