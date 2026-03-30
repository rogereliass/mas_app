import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../routing/app_router.dart';

/// Unified bottom navigation bar component
///
/// Adapts based on authentication status:
/// - Authenticated users: Home, Library, Search, Profile
/// - Public users: Library, About
///
/// Handles navigation internally for consistency across the app
class AppBottomNavBar extends StatelessWidget {
  final String currentPage;
  final bool isAuthenticated;

  const AppBottomNavBar({
    super.key,
    required this.currentPage,
    this.isAuthenticated = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Return the navbar wrapped in SafeArea to prevent overlap with system navigation
    // This ensures the navbar is always positioned above the Android/iOS navigation buttons
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : theme.shadowColor.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.min,
            children: isAuthenticated
                ? _buildAuthenticatedNavItems(context)
                : _buildPublicNavItems(context),
          ),
        ),
      ),
    );
  }

  /// Build navigation items for authenticated users
  List<Widget> _buildAuthenticatedNavItems(BuildContext context) {
    return [
      _buildNavItem(
        context: context,
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
        page: 'home',
        onTap: () => _navigateTo(context, AppRouter.home),
      ),
      _buildNavItem(
        context: context,
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: 'Library',
        page: 'library',
        onTap: () => _navigateTo(context, AppRouter.library),
      ),
      _buildNavItem(
        context: context,
        icon: Icons.event_outlined,
        activeIcon: Icons.event,
        label: 'Meetings',
        page: 'meetings',
        onTap: () => _navigateTo(context, AppRouter.meetings),
      ),

      _buildNavItem(
        context: context,
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
        page: 'profile',
        onTap: () => _navigateTo(context, AppRouter.profile),
      ),
    ];
  }

  /// Build navigation items for public (non-authenticated) users
  List<Widget> _buildPublicNavItems(BuildContext context) {
    return [
      _buildNavItem(
        context: context,
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories,
        label: 'Library',
        page: 'library',
        onTap: () => _navigateTo(context, AppRouter.library),
      ),
      _buildNavItem(
        context: context,
        icon: Icons.info_outline,
        activeIcon: Icons.info,
        label: 'About',
        page: 'about',
        onTap: () => _navigateTo(context, AppRouter.about),
      ),
    ];
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String page,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = currentPage == page;

    final Color activeColor = isDark
        ? AppColors.goldAccent
        : theme.colorScheme.primary;
    final Color inactiveColor = isDark
        ? AppColors.sectionHeaderGray
        : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6) ??
              Colors.grey;

    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            // Active indicator line
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Navigate to a route
  void _navigateTo(BuildContext context, String route, {Object? arguments}) {
    // Don't navigate if already on the page
    if (_isCurrentRoute(route)) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Check if the route matches current page
  bool _isCurrentRoute(String route) {
    switch (route) {
      case AppRouter.home:
        return currentPage == 'home';
      case AppRouter.library:
        return currentPage == 'library';
      case AppRouter.meetings:
        return currentPage == 'meetings';
      case AppRouter.about:
        return currentPage == 'about';
      case AppRouter.profile:
        return currentPage == 'profile';
      default:
        return false;
    }
  }

  /// Show coming soon message
  // ignore: unused_element
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
