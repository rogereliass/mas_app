import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/notification_models.dart';

class NotificationItem extends StatelessWidget {
  const NotificationItem({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final NotificationRecipientEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconMeta = _metaForType(entry.notification.type, colorScheme);

    final bodyPreview = entry.notification.body.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: entry.isRead
            ? colorScheme.surface
            : colorScheme.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: entry.isRead
              ? colorScheme.outline.withValues(alpha: 0.12)
              : colorScheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: entry.isRead
            ? null
            : [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          iconMeta.color.withValues(alpha: 0.15),
                          iconMeta.color.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: iconMeta.color.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      iconMeta.icon,
                      size: 22,
                      color: iconMeta.color,
                    ),
                  ),
                  if (!entry.isRead)
                    Transform.translate(
                      offset: const Offset(4, -4),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.error.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
                            entry.notification.title.isEmpty
                                ? 'Untitled Notification'
                                : entry.notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: entry.isRead ? FontWeight.w600 : FontWeight.w800,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(entry.notification.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bodyPreview.isEmpty ? 'No additional message.' : bodyPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM').format(createdAt);
  }

  _NotificationTypeMeta _metaForType(
    NotificationType type,
    ColorScheme colorScheme,
  ) {
    switch (type) {
      case NotificationType.system:
        return _NotificationTypeMeta(
          icon: Icons.settings_suggest_rounded,
          color: colorScheme.primary,
        );
      case NotificationType.announcement:
        return _NotificationTypeMeta(
          icon: Icons.campaign_rounded,
          color: colorScheme.tertiary,
        );
      case NotificationType.meeting:
        return _NotificationTypeMeta(
          icon: Icons.event_rounded,
          color: colorScheme.secondary,
        );
      case NotificationType.attendance:
        return _NotificationTypeMeta(
          icon: Icons.how_to_reg_rounded,
          color: colorScheme.primary,
        );
      case NotificationType.points:
        return _NotificationTypeMeta(
          icon: Icons.stars_rounded,
          color: colorScheme.inversePrimary,
        );
    }
  }
}

class _NotificationTypeMeta {
  const _NotificationTypeMeta({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}
