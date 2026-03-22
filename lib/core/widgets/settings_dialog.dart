import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../auth/logic/auth_provider.dart';
import '../../core/config/theme_provider.dart';
import '../../routing/app_router.dart';

/// Reusable Settings Dialog Widget
/// 
/// Shows app settings including theme, account options, logout, and support
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Scrollable Settings Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Appearance Section
                    _SettingsSection(
                      title: 'Appearance',
                      icon: Icons.palette_outlined,
                      children: [
                        _SettingItem(
                          icon: Icons.brightness_6_outlined,
                          title: 'Theme',
                          subtitle: _getThemeModeLabel(themeProvider.themeMode),
                          onTap: () => _showThemeSelector(context, themeProvider),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Account Section
                    if (authProvider.isAuthenticated) ...[
                      _SettingsSection(
                        title: 'Account',
                        icon: Icons.person_outline,
                        children: [
                          _SettingItem(
                            icon: Icons.edit_outlined,
                            title: 'Edit Profile',
                            subtitle: 'Update your personal information',
                            onTap: () {
                              // TODO: Navigate to profile edit
                              Navigator.pop(context);
                            },
                          ),
                          _SettingItem(
                            icon: Icons.lock_outline,
                            title: 'Change Password',
                            subtitle: 'Update your account password',
                            onTap: () {
                              Navigator.pop(context); // Close settings dialog
                              Navigator.pushNamed(context, AppRouter.forgotPassword);
                            },
                          ),
                          _SettingItem(
                            icon: Icons.logout,
                            title: 'Log Out',
                            subtitle: 'Log out of your account',
                            onTap: () => _showLogoutConfirmation(context),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                    
                    // Storage Section
                    _SettingsSection(
                      title: 'Storage',
                      icon: Icons.storage_outlined,
                      children: [
                        _SettingItem(
                          icon: Icons.download_outlined,
                          title: 'Offline Files',
                          subtitle: 'Manage downloaded content',
                          onTap: () {
                            // TODO: Navigate to offline files management
                            Navigator.pop(context);
                          },
                        ),
                        _SettingItem(
                          icon: Icons.delete_outline,
                          title: 'Clear Cache',
                          subtitle: 'Free up storage space',
                          onTap: () {
                            // TODO: Show cache clearing dialog
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Support Section
                    _SettingsSection(
                      title: 'Support',
                      icon: Icons.help_outline,
                      children: [
                        _SettingItem(
                          icon: Icons.bug_report_outlined,
                          title: 'Report an Issue',
                          subtitle: 'Send us feedback or report a problem',
                          onTap: () => _reportIssue(),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // About Section
                    _SettingsSection(
                      title: 'About',
                      icon: Icons.info_outline,
                      children: [
                        _SettingItem(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          subtitle: 'View our privacy policy',
                          onTap: () {
                            // TODO: Show privacy policy
                            Navigator.pop(context);
                          },
                        ),
                        _SettingItem(
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          subtitle: 'View terms and conditions',
                          onTap: () {
                            // TODO: Show terms
                            Navigator.pop(context);
                          },
                        ),
                        _SettingItem(
                          icon: Icons.update_outlined,
                          title: 'App Version',
                          subtitle: '1.0.0',
                          onTap: null, // Non-interactive
                        ),
                        _SettingItem(
                          icon: Icons.info_rounded,
                          title: 'About App',
                          subtitle: 'Learn more about this app',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, AppRouter.about);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // Get the navigator and auth provider before closing dialogs
              final navigator = Navigator.of(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              
              // Close both dialogs
              Navigator.pop(dialogContext); // Close confirmation dialog
              Navigator.pop(context); // Close settings dialog
              
              // CRITICAL: Navigate BEFORE signing out to prevent flashing no-role widget
              // The auth state listener will handle clearing user data when sign out completes
              navigator.pushNamedAndRemoveUntil(
                AppRouter.startup,
                (route) => false,
              );
              
              // Sign out after navigation
              await authProvider.signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  /// Report issue via email
  Future<void> _reportIssue() async {
    final emailAddress = dotenv.env['ISSUE_EMAIL_ADDRESS'] ?? 'support.masdigitalteam@gmail.com';
    final uri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      query: 'subject=MAS App Issue Report&body=Please describe the issue you encountered:',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch email client');
    }
  }

  void _showThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Choose Theme',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ThemeModeOption(
              icon: Icons.light_mode,
              title: 'Light Mode',
              subtitle: 'Clean and bright interface',
              isSelected: themeProvider.themeMode == ThemeMode.light,
              onTap: () async {
                await themeProvider.setLightMode();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            _ThemeModeOption(
              icon: Icons.dark_mode,
              title: 'Dark Mode',
              subtitle: 'Easy on the eyes',
              isSelected: themeProvider.themeMode == ThemeMode.dark,
              onTap: () async {
                await themeProvider.setDarkMode();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            _ThemeModeOption(
              icon: Icons.brightness_auto,
              title: 'System Default',
              subtitle: 'Follow device settings',
              isSelected: themeProvider.themeMode == ThemeMode.system,
              onTap: () async {
                await themeProvider.setSystemMode();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Settings Section Widget
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Settings Item Widget
class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInteractive = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isInteractive)
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Theme Mode Option Tile
class _ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected 
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
