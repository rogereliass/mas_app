import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/notification_audit_models.dart';
import '../../data/models/notification_models.dart';

class NotificationAuditItem extends StatelessWidget {
  const NotificationAuditItem({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final NotificationAuditEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = _iconForType(entry.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.primaryContainer.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title.isEmpty ? 'Untitled Notification' : entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('d MMM').format(entry.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_typeLabel(entry.type)} • ${_targetLabel(entry)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${entry.senderName ?? 'Unknown'} • ${entry.recipientCount} Recipients',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Center(
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return 'System';
      case NotificationType.announcement:
        return 'Announcement';
      case NotificationType.meeting:
        return 'Meeting';
      case NotificationType.attendance:
        return 'Attendance';
      case NotificationType.points:
        return 'Points';
    }
  }

  String _targetLabel(NotificationAuditEntry entry) {
    switch (entry.targetType) {
      case NotificationTargetType.all:
        return 'All users';
      case NotificationTargetType.troop:
        return 'Troop: ${entry.targetLabel ?? entry.targetId ?? 'Unknown'}';
      case NotificationTargetType.patrol:
        return 'Patrol: ${entry.targetLabel ?? entry.targetId ?? 'Unknown'}';
      case NotificationTargetType.individual:
        return 'Individual: ${entry.targetLabel ?? entry.targetId ?? 'Unknown'}';
    }
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return Icons.settings_suggest_rounded;
      case NotificationType.announcement:
        return Icons.campaign_rounded;
      case NotificationType.meeting:
        return Icons.event_rounded;
      case NotificationType.attendance:
        return Icons.how_to_reg_rounded;
      case NotificationType.points:
        return Icons.stars_rounded;
    }
  }
}
