import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/connectivity_service.dart';
import '../../routing/app_router.dart';
import '../logic/home_overview_stats_provider.dart';
import 'premium_dashboard_widgets.dart';

/// Troop Head Dashboard Component
///
/// Premium UI using shared dashboard components for quick troop management
/// and a compact statistics section below it.
class TroopHeadStats extends StatefulWidget {
  const TroopHeadStats({super.key});

  @override
  State<TroopHeadStats> createState() => _TroopHeadStatsState();
}

class _TroopHeadStatsState extends State<TroopHeadStats> {
  bool _requestedInitialLoad = false;

  void _navigateOnlineOnly(String routeName, String featureLabel) {
    if (!ConnectivityService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$featureLabel requires internet connection.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.pushNamed(context, routeName);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialLoad) {
      return;
    }
    _requestedInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<HomeOverviewStatsProvider>().loadOverview();
    });
  }

  String _valueOrPlaceholder({
    required int? value,
    required bool isLoading,
  }) {
    if (value != null) {
      return value.toString();
    }
    return isLoading ? '...' : '--';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeOverviewStatsProvider>(
      builder: (context, overviewProvider, _) {
        final stats = overviewProvider.troopStats;

        return PremiumDashboardSection(
          title: 'Troop Management',
          headerIcon: Icons.admin_panel_settings_rounded,
          actionCards: [
            PremiumActionCard(
              title: 'User Acceptance',
              subtitle: 'Review & approve pending registrations',
              icon: Icons.how_to_reg_rounded,
              color: const Color(0xFF6366F1), // Indigo
              onTap: () => _navigateOnlineOnly(
                AppRouter.userAcceptance,
                'User Acceptance',
              ),
            ),
            PremiumActionCard(
              title: 'User Management',
              subtitle: 'Edit member profiles & roles',
              icon: Icons.manage_accounts_rounded,
              color: const Color(0xFF14B8A6), // Teal
              onTap: () => _navigateOnlineOnly(
                AppRouter.userManagement,
                'User Management',
              ),
            ),
            PremiumActionCard(
              title: 'Patrols',
              subtitle: 'Organize troop structure',
              icon: Icons.groups_rounded,
              color: const Color(0xFFF59E0B), // Amber
              onTap: () =>
                  _navigateOnlineOnly(AppRouter.patrolsManagement, 'Patrols'),
            ),
            PremiumActionCard(
              title: 'Eftekad',
              subtitle: 'Open Eftekad tools (coming soon)',
              icon: Icons.fact_check_rounded,
              color: AppColors.primaryBlue,
              onTap: () =>
                  _navigateOnlineOnly(AppRouter.eftekad, 'Eftekad'),
            ),
          ],
          stats: [
            PremiumStat(
              icon: Icons.people_rounded,
              label: 'Members',
              value: _valueOrPlaceholder(
                value: stats?.totalMembers,
                isLoading: overviewProvider.isLoading,
              ),
              color: const Color(0xFF3B82F6), // Blue
            ),
            PremiumStat(
              icon: Icons.hourglass_top_rounded,
              label: 'Pending Members',
              value: _valueOrPlaceholder(
                value: stats?.pendingMembers,
                isLoading: overviewProvider.isLoading,
              ),
              color: const Color(0xFFF43F5E), // Rose
            ),
            PremiumStat(
              icon: Icons.event_rounded,
              label: 'Season Meetings',
              value: _valueOrPlaceholder(
                value: stats?.seasonMeetings,
                isLoading: overviewProvider.isLoading,
              ),
              color: const Color(0xFF8B5CF6), // Violet
            ),
            PremiumStat(
              icon: Icons.manage_accounts_rounded,
              label: 'Assigned Leaders',
              value: _valueOrPlaceholder(
                value: stats?.assignedLeaders,
                isLoading: overviewProvider.isLoading,
              ),
              color: const Color(0xFF10B981), // Emerald
            ),
          ],
        );
      },
    );
  }
}
