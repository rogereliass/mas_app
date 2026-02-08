import 'package:flutter/material.dart';
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
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
        icon: Icons.search_outlined,
        activeIcon: Icons.search,
        label: 'Search',
        page: 'search',
        onTap: () => _showComingSoon(context, 'Search'),
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
    final colorScheme = theme.colorScheme;
    final isActive = currentPage == page;
    final color = isActive 
        ? colorScheme.primary 
        : theme.textTheme.bodySmall?.color?.withOpacity(0.6);

    return Expanded(
      child: InkWell(
        onTap: isActive ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to a route
  void _navigateTo(BuildContext context, String route) {
    // Don't navigate if already on the page
    if (_isCurrentRoute(route)) return;
    
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (route) => false,
    );
  }

  /// Check if the route matches current page
  bool _isCurrentRoute(String route) {
    switch (route) {
      case AppRouter.home:
        return currentPage == 'home';
      case AppRouter.library:
        return currentPage == 'library';
      case AppRouter.about:
        return currentPage == 'about';
      case AppRouter.profile:
        return currentPage == 'profile';
      default:
        return false;
    }
  }

  /// Show coming soon message
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
