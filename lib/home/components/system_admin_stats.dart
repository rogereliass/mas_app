import 'package:flutter/material.dart';
import '../../routing/app_router.dart';
import 'premium_dashboard_widgets.dart';

/// System Admin Dashboard Statistics Component
/// 
/// Premium UI using shared dashboard components for top-level admin stats
/// and actions, alongside custom activity and health widgets.
class SystemAdminStats extends StatelessWidget {
  const SystemAdminStats({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Premium Dashboard Section (Replaces old Stats Grid and Action Buttons List)
        PremiumDashboardSection(
          title: 'System Overview',
          headerIcon: Icons.admin_panel_settings_rounded,
          actionCards: [
            PremiumActionCard(
              title: 'Season Management',
              subtitle: 'Manage activity seasons & codes',
              icon: Icons.calendar_today_rounded,
              color: const Color(0xFF6366F1), // Indigo
              onTap: () => Navigator.pushNamed(context, AppRouter.seasonManagement),
            ),
            PremiumActionCard(
              title: 'User Acceptance',
              subtitle: 'Review & approve registrations',
              icon: Icons.how_to_reg_rounded,
              color: const Color(0xFFF43F5E), // Rose
              onTap: () => Navigator.pushNamed(context, AppRouter.userAcceptance),
            ),
            PremiumActionCard(
              title: 'User Management',
              subtitle: 'Edit profiles & role assignments',
              icon: Icons.manage_accounts_rounded,
              color: const Color(0xFF14B8A6), // Teal
              onTap: () => Navigator.pushNamed(context, AppRouter.userManagement),
            ),
            PremiumActionCard(
              title: 'Patrols',
              subtitle: 'Manage system-wide patrols',
              icon: Icons.groups_rounded,
              color: const Color(0xFFF59E0B), // Amber
              onTap: () => Navigator.pushNamed(context, AppRouter.patrolsManagement),
            ),
          ],
          stats: const [
            PremiumStat(
              icon: Icons.people_rounded,
              label: 'Users',
              value: '--',
              color: Color(0xFF3B82F6), // Blue
            ),
            PremiumStat(
              icon: Icons.folder_rounded,
              label: 'Folders',
              value: '--',
              color: Color(0xFF14B8A6), // Teal
            ),
            PremiumStat(
              icon: Icons.description_rounded,
              label: 'Files',
              value: '--',
              color: Color(0xFF8B5CF6), // Violet
            ),
            PremiumStat(
              icon: Icons.storage_rounded,
              label: 'Storage',
              value: '-- GB',
              color: Color(0xFFF43F5E), // Rose
            ),
          ],
        ),

        const SizedBox(height: 32),

        // 2. Recent Activity Summary (Preserved)
        _ActivitySummaryCard(
          title: 'Recent Activity',
          items: const [
            _ActivityItem(
              icon: Icons.person_add_outlined,
              label: 'New users (7 days)',
              value: '--',
            ),
            _ActivityItem(
              icon: Icons.upload_file_outlined,
              label: 'Files uploaded (7 days)',
              value: '--',
            ),
            _ActivityItem(
              icon: Icons.download_outlined,
              label: 'Total downloads (7 days)',
              value: '--',
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 3. System Health Indicators (Preserved)
        _buildSystemHealth(context),
      ],
    );
  }

  Widget _buildSystemHealth(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Health',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HealthIndicator(
              label: 'Database',
              status: HealthStatus.healthy,
            ),
            const SizedBox(height: 8),
            _HealthIndicator(
              label: 'Storage',
              status: HealthStatus.healthy,
            ),
            const SizedBox(height: 8),
            _HealthIndicator(
              label: 'Authentication',
              status: HealthStatus.healthy,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color backgroundColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            // Label and Value
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Activity Summary Card Widget
class _ActivitySummaryCard extends StatelessWidget {
  final String title;
  final List<_ActivityItem> items;

  const _ActivitySummaryCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item.icon,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        item.value,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Activity Item Data Class
class _ActivityItem {
  final IconData icon;
  final String label;
  final String value;

  const _ActivityItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Health Status Enum
enum HealthStatus {
  healthy,
  warning,
  error,
}

/// Health Indicator Widget
class _HealthIndicator extends StatelessWidget {
  final String label;
  final HealthStatus status;

  const _HealthIndicator({
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case HealthStatus.healthy:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case HealthStatus.warning:
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case HealthStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Row(
      children: [
        Icon(
          statusIcon,
          size: 16,
          color: statusColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status == HealthStatus.healthy
                ? 'Operational'
                : status == HealthStatus.warning
                    ? 'Warning'
                    : 'Error',
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
