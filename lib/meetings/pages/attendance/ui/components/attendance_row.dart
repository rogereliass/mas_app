import 'package:flutter/material.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/attendance/data/models/attendance_record.dart';

/// A single row representing a member and their attendance status.
/// Editors can tap the status badge to change it via a popup menu.
/// Regular members see a read-only status badge.
class AttendanceRow extends StatelessWidget {
  final MemberWithAttendance member;
  final AttendanceStatus currentStatus;
  final bool isEditor;
  final ValueChanged<AttendanceStatus>? onStatusChanged;

  const AttendanceRow({
    super.key,
    required this.member,
    required this.currentStatus,
    required this.isEditor,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDarkElevated : AppColors.cardLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Avatar with initials
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              member.initialsName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + patrol
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (member.patrolName != null &&
                    member.patrolName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.patrolName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          const SizedBox(width: 8),
          // Status control
          isEditor
              ? _EditableStatusBadge(
                  currentStatus: currentStatus,
                  onStatusChanged: onStatusChanged,
                )
              : _StatusBadge(status: currentStatus),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editable status badge (for editors) — PopupMenuButton
// ---------------------------------------------------------------------------

class _EditableStatusBadge extends StatelessWidget {
  final AttendanceStatus currentStatus;
  final ValueChanged<AttendanceStatus>? onStatusChanged;

  const _EditableStatusBadge({
    required this.currentStatus,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AttendanceStatus>(
      onSelected: onStatusChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) {
        return AttendanceStatus.values.map((status) {
          return PopupMenuItem<AttendanceStatus>(
            value: status,
            child: Row(
              children: [
                Icon(
                  status.icon,
                  size: 16,
                  color: _statusColor(status),
                ),
                const SizedBox(width: 10),
                Text(
                  status.displayLabel,
                  style: TextStyle(color: _statusColor(status)),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: _StatusBadge(
        status: currentStatus,
        trailing: const Icon(Icons.arrow_drop_down, size: 16),
      ),
    );
  }

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.success;
      case AttendanceStatus.absent:
        return AppColors.error;
      case AttendanceStatus.late:
        return AppColors.warning;
      case AttendanceStatus.excused:
        return AppColors.info;
    }
  }
}

// ---------------------------------------------------------------------------
// Status badge widget
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus status;
  final Widget? trailing;

  const _StatusBadge({required this.status, this.trailing});

  Color get _color {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.success;
      case AttendanceStatus.absent:
        return AppColors.error;
      case AttendanceStatus.late:
        return AppColors.warning;
      case AttendanceStatus.excused:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullColor = _color;
    final bgColor = fullColor.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: fullColor),
          const SizedBox(width: 4),
          Text(
            status.displayLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fullColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 2),
            trailing!,
          ],
        ],
      ),
    );
  }
}
