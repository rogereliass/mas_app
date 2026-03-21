/// LATEST UPDATE CARD
/// Shows the most recent notification or system update for the user.
/// TO BE IMPLEMENTED: Fetch the latest notification/announcement from the database.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:masapp/routing/deep_link/deep_link_service.dart';
import '../../pages/notifications/notifications.dart';
import 'smart_stack_card_base.dart';

class LatestUpdateCard extends StatefulWidget {
  const LatestUpdateCard({super.key});

  @override
  State<LatestUpdateCard> createState() => _LatestUpdateCardState();
}

class _LatestUpdateCardState extends State<LatestUpdateCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<NotificationsProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Error state
    if (provider.error != null && provider.items.isEmpty) {
      return GestureDetector(
        onTap: () => provider.refresh(),
        child: SmartStackCardBase(
          icon: Icons.error_outline_rounded,
          title: 'Latest Update',
          subtitle: provider.error!,
          colors: [colorScheme.error, colorScheme.error.withValues(alpha: 0.8)],
          onColor: colorScheme.onError,
        ),
      );
    }

    if (provider.isLoading && provider.items.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 160,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    // Empty state
    if (provider.items.isEmpty) {
      return GestureDetector(
        onTap: () => _showNotificationsPanel(context),
        child: SmartStackCardBase(
          icon: Icons.notifications_none_rounded,
          title: 'Latest Update',
          subtitle: 'You are all caught up!',
          colors: const [Color(0xFF0ea5e9), Color(0xFF2563eb)],
          onColor: Colors.white,
        ),
      );
    }

    // Display latest notification
    final latestEntry = provider.items.first;
    final notification = latestEntry.notification;
    final meta = _metaForType(notification.type);

    return GestureDetector(
      onTap: () => _handleTap(context, latestEntry),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SmartStackCardBase(
            icon: meta.icon,
            title: notification.title.isEmpty ? 'Latest Update' : notification.title,
            customSubtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 10,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            colors: meta.colors,
            onColor: Colors.white,
            titleWeight: FontWeight.w900,
            backgroundIconSize: 90,
            backgroundIconTop: null,
            backgroundIconRight: -10,
            backgroundIconBottom: -15,
          ),
          if (!latestEntry.isRead)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleTap(BuildContext context, NotificationRecipientEntry entry) async {
    final provider = context.read<NotificationsProvider>();
    
    // Mark as read if not already
    if (!entry.isRead) {
      await provider.markAsRead(entry.id);
    }

    // Try handling deep link
    final result = await DeepLinkService.handle(entry.notification.data);
    
    if (result.handled) {
      if (result.message != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message!)),
        );
      }
      return;
    }

    // If not handled, open the panel
    if (context.mounted) {
      _showNotificationsPanel(context);
    }
  }

  void _showNotificationsPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const NotificationsPanel(),
    );
  }

  String _formatTimestamp(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, h:mm a').format(createdAt);
  }

  _NotificationTypeMeta _metaForType(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return const _NotificationTypeMeta(
          icon: Icons.settings_suggest_rounded,
          colors: [Color(0xFF0ea5e9), Color(0xFF2563eb)], // Sky to Blue
        );
      case NotificationType.announcement:
        return const _NotificationTypeMeta(
          icon: Icons.campaign_rounded,
          colors: [Color(0xFFf59e0b), Color(0xFFd97706)], // Amber to Orange
        );
      case NotificationType.meeting:
        return const _NotificationTypeMeta(
          icon: Icons.event_rounded,
          colors: [Color(0xFF10b981), Color(0xFF059669)], // Emerald to Green
        );
      case NotificationType.attendance:
        return const _NotificationTypeMeta(
          icon: Icons.how_to_reg_rounded,
          colors: [Color(0xFF8b5cf6), Color(0xFF7c3aed)], // Violet to Purple
        );
      case NotificationType.points:
        return const _NotificationTypeMeta(
          icon: Icons.stars_rounded,
          colors: [Color(0xFFec4899), Color(0xFFdb2777)], // Pink to Rose
        );
    }
  }
}

class _NotificationTypeMeta {
  final IconData icon;
  final List<Color> colors;

  const _NotificationTypeMeta({
    required this.icon,
    required this.colors,
  });
}
