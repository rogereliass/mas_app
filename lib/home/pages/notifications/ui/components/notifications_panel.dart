import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:masapp/core/utils/review_mode.dart';
import 'package:masapp/routing/deep_link/deep_link_service.dart';

import '../../../../../auth/logic/auth_provider.dart';
import '../../data/models/notification_models.dart';
import '../../logic/notifications_provider.dart';
import '../admin_notifications_audit_screen.dart';
import 'notification_compose_modal.dart';
import 'notification_detail_modal.dart';
import 'notification_item.dart';

class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key});

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final userRank = authProvider.selectedRoleRank;
    final canSend = userRank >= 60;
    final canAudit = userRank >= 90;

    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Consumer<NotificationsProvider>(
          builder: (context, provider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Notifications',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _UnreadBadge(count: provider.unreadCount),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (provider.canSendNotifications && canSend)
                      _HeaderIconButton(
                        tooltip: 'Send notification',
                        onPressed: provider.isSending
                            ? null
                            : () => _openComposeModal(context),
                        icon: Icons.add_alert_rounded,
                        color: colorScheme.primary,
                      ),
                    if (canAudit) ...[
                      if (provider.canSendNotifications && canSend)
                        const SizedBox(width: 8),
                      _HeaderIconButton(
                        tooltip: 'Sent notifications audit',
                        onPressed: () => _openAuditScreen(context),
                        icon: Icons.history_edu_rounded,
                        color: colorScheme.tertiary,
                      ),
                    ],
                    if (provider.unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: TextButton(
                          onPressed: () => provider.markAllAsRead(),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: colorScheme.primary,
                            textStyle: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Mark all read'),
                        ),
                      ),
                  ],
                ),
                if (provider.isRefreshing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Refreshing...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (provider.error != null && provider.items.isEmpty)
                  _PanelInfoMessage(
                    text: provider.error!,
                    isError: true,
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildBody(provider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(NotificationsProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 64,
                  color: colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'All caught up!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'No notifications yet. We\'ll let you know when something important happens.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.builder(
        itemCount: provider.items.length,
        itemBuilder: (context, index) {
          final entry = provider.items[index];
          return NotificationItem(
            key: ValueKey(entry.id),
            entry: entry,
            onTap: () => _openDetails(entry),
          );
        },
      ),
    );
  }

  Future<void> _openDetails(NotificationRecipientEntry entry) async {
    final provider = context.read<NotificationsProvider>();

    if (!entry.isRead) {
      await provider.markAsRead(entry.id);
    }

    if (!context.mounted) {
      return;
    }

    final deepLinkResult = await DeepLinkService.handle(entry.notification.data);
    if (!mounted) {
      return;
    }

    if (deepLinkResult.handled) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (deepLinkResult.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deepLinkResult.message!)),
      );
    }

    final latestEntry = provider.items.firstWhere(
      (item) => item.id == entry.id,
      orElse: () => entry.copyWith(isRead: true, readAt: DateTime.now()),
    );

    await showDialog<void>(
      context: context,
      builder: (_) => NotificationDetailModal(
        entry: latestEntry,
        onMarkRead: () => provider.markAsRead(entry.id),
      ),
    );
  }

  Future<void> _openComposeModal(BuildContext context) async {
    final result = await showDialog<NotificationCreateResult>(
      context: context,
      builder: (_) => const NotificationComposeModal(),
    );

    if (!context.mounted || result == null) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final isReviewAccount = isReviewDemoEmail(authProvider.userEmail);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isReviewAccount
              ? kReviewModeSuccessMessage
              : 'Notification sent to ${result.recipientCount} recipient(s).',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAuditScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminNotificationsAuditScreen(),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.color,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: onPressed == null
                ? colorScheme.surfaceContainerHighest
                : color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onPressed == null
                  ? colorScheme.outline.withValues(alpha: 0.18)
                  : color.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? colorScheme.onSurfaceVariant
                : color,
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final display = count > 99 ? '99+' : '$count';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: count > 0
            ? LinearGradient(
                colors: [
                  colorScheme.error,
                  colorScheme.error.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: count > 0
            ? null
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        boxShadow: count > 0
            ? [
                BoxShadow(
                  color: colorScheme.error.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        display,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: count > 0
              ? colorScheme.onError
              : colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PanelInfoMessage extends StatelessWidget {
  const _PanelInfoMessage({
    required this.text,
    this.isError = false,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isError
              ? colorScheme.errorContainer.withValues(alpha: 0.5)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isError
                ? colorScheme.error.withValues(alpha: 0.35)
                : colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isError
                ? colorScheme.onErrorContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
