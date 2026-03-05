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

        return Stack(
          children: [
            Column(
              children: [
                // Meeting selector dropdown.
                // ValueKey forces a fresh FormField state whenever the provider
                // itself changes the selection (e.g. auto-select on load/reload).
                _MeetingDropdown(
                  key: ValueKey(provider.selectedMeetingId),
                  provider: provider,
                ),
                // Member list
                Expanded(child: _buildMemberList(context, provider)),
                // Keep the full-width save button for clarity on larger devices.
                if (provider.isEditor && provider.hasUnsavedChanges)
                  _SaveButton(provider: provider),
              ],
            ),

            // Small chic floating save button for quick manual saves.
            if (provider.isEditor && provider.hasUnsavedChanges)
              Positioned(
                right: 20,
                bottom: 28,
                child: _FloatingSaveFab(provider: provider),
              ),
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
// Small floating save FAB for quick manual saves
// ---------------------------------------------------------------------------

class _FloatingSaveFab extends StatelessWidget {
  final AttendanceProvider provider;

  const _FloatingSaveFab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final modified = provider.modifiedCount;

    return FloatingActionButton.small(
      onPressed: provider.isSaving ? null : () => provider.saveChanges(),
      backgroundColor: isDark ? AppColors.goldAccent : AppColors.primaryBlue,
      foregroundColor: isDark
          ? AppColors.textPrimaryLight
          : theme.colorScheme.onPrimary,
      tooltip: modified > 0 ? 'Save ($modified)' : 'Save',
      elevation: 6,
      child: provider.isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
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
      borderRadius: BorderRadius.circular(14),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: DropdownButtonFormField<String>(
          initialValue: dropdownSelectedMeetingId,
          isExpanded: true,
          itemHeight: 56,
          decoration: InputDecoration(
            hintText: 'Select meeting',
            prefixIcon: Icon(Icons.event, color: theme.colorScheme.primary),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: cardColor,
          ),
          selectedItemBuilder: (context) {
            return dropdownMeetings.map((m) {
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
          items: dropdownMeetings.map((m) {
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
          backgroundColor: isDark
              ? AppColors.goldAccent
              : AppColors.primaryBlue,
          foregroundColor: isDark
              ? AppColors.textPrimaryLight
              : theme.colorScheme.onPrimary,
          disabledBackgroundColor:
              (isDark ? AppColors.goldAccent : AppColors.primaryBlue)
                  .withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
