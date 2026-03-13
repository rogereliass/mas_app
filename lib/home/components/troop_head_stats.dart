import 'package:flutter/material.dart';
import '../../routing/app_router.dart';
import 'premium_dashboard_widgets.dart';

/// Troop Head Dashboard Component
/// 
/// Premium UI using shared dashboard components for quick troop management
/// and a compact statistics section below it.
class TroopHeadStats extends StatelessWidget {
  const TroopHeadStats({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumDashboardSection(
      title: 'Troop Management',
      headerIcon: Icons.admin_panel_settings_rounded,
      actionCards: [
        PremiumActionCard(
          title: 'User Acceptance',
          subtitle: 'Review & approve pending registrations',
          icon: Icons.how_to_reg_rounded,
          color: const Color(0xFF6366F1), // Indigo
          onTap: () => Navigator.pushNamed(context, AppRouter.userAcceptance),
        ),
        PremiumActionCard(
          title: 'User Management',
          subtitle: 'Edit member profiles & roles',
          icon: Icons.manage_accounts_rounded,
          color: const Color(0xFF14B8A6), // Teal
          onTap: () => Navigator.pushNamed(context, AppRouter.userManagement),
        ),
        PremiumActionCard(
          title: 'Patrols',
          subtitle: 'Organize troop structure',
          icon: Icons.groups_rounded,
          color: const Color(0xFFF59E0B), // Amber
          onTap: () => Navigator.pushNamed(context, AppRouter.patrolsManagement),
        ),
      ],
      stats: const [
        PremiumStat(
          icon: Icons.people_rounded,
          label: 'Members',
          value: '--',
          color: Color(0xFF3B82F6), // Blue
        ),
        PremiumStat(
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
          value: '--',
          color: Color(0xFFF43F5E), // Rose
        ),
        PremiumStat(
          icon: Icons.folder_shared_rounded,
          label: 'Files',
          value: '--',
          color: Color(0xFF8B5CF6), // Violet
        ),
        PremiumStat(
          icon: Icons.event_rounded,
          label: 'Activities',
          value: '--',
          color: Color(0xFF10B981), // Emerald
        ),
      ],
    );
  }
}
