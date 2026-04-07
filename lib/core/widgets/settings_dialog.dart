import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../auth/logic/auth_provider.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/config/theme_provider.dart';
import '../../core/utils/external_launcher.dart';
import '../../routing/app_router.dart';
import '../../main.dart' show restartApp;

/// Reusable Settings Dialog Widget
///
/// Shows app settings including theme, account options, logout, and support
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  String? _version;
  final bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  _AnimatedSettingsIcon(colorScheme: colorScheme),
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
                        _AnimatedThemeToggle(themeProvider: themeProvider),
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
                              if (!ConnectivityService.instance.isOnline) {
                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Internet connection is required to change your password.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(context); // Close settings dialog
                              Navigator.pushNamed(
                                context,
                                AppRouter.forgotPassword,
                              );
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
                          icon: Icons.info_rounded,
                          title: 'About App',
                          subtitle: 'Learn more about this app',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, AppRouter.about);
                          },
                        ),
                        _SettingItem(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          subtitle: 'View our privacy policy',
                          onTap: () async {
                            Navigator.pop(context);
                            await ExternalLauncher.openExternalUrl(
                              context,
                              'https://sites.google.com/view/masdigitalteam/app/privacy-policy?authuser=0',
                            );
                          },
                        ),
                        _SettingItem(
                          icon: Icons.refresh,
                          title: 'Reload App',
                          subtitle: 'Restart the app (cold start)',
                          onTap: () => restartApp(),
                        ),
                        _SettingItem(
                          icon: Icons.update_outlined,
                          title: 'App Version',
                          subtitle: _version ?? '...',
                          onTap: null,
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
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );

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
    final emailAddress =
        dotenv.env['ISSUE_EMAIL_ADDRESS'] ?? 'support.masdigitalteam@gmail.com';
    await ExternalLauncher.composeEmail(
      context,
      email: emailAddress,
      subject: 'MAS App Issue Report',
      body: 'Please describe the issue you encountered:',
    );
  }
}

/// Animated Theme Toggle Widget (iOS-style)
class _AnimatedThemeToggle extends StatelessWidget {
  final ThemeProvider themeProvider;

  const _AnimatedThemeToggle({required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return InkWell(
      onTap: () {
        if (isDark) {
          themeProvider.setLightMode();
        } else {
          themeProvider.setDarkMode();
        }
      },
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
                isDark ? Icons.dark_mode : Icons.light_mode,
                size: 20,
                color: isDark ? colorScheme.tertiary : Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dark Mode',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    isDark ? 'On' : 'Off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _IOSSwitch(
              isOn: isDark,
              onChanged: (value) {
                if (value) {
                  themeProvider.setDarkMode();
                } else {
                  themeProvider.setLightMode();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated Settings Icon with rotation
class _AnimatedSettingsIcon extends StatefulWidget {
  final ColorScheme colorScheme;

  const _AnimatedSettingsIcon({required this.colorScheme});

  @override
  State<_AnimatedSettingsIcon> createState() => _AnimatedSettingsIconState();
}

class _AnimatedSettingsIconState extends State<_AnimatedSettingsIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RotationTransition(
        turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
        child: Icon(
          Icons.settings,
          color: widget.colorScheme.onPrimaryContainer,
          size: 24,
        ),
      ),
    );
  }
}

/// iOS-style Animated Switch
class _IOSSwitch extends StatelessWidget {
  final bool isOn;
  final ValueChanged<bool> onChanged;

  const _IOSSwitch({required this.isOn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onChanged(!isOn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 51,
        height: 31,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isOn
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isOn ? Icons.dark_mode : Icons.light_mode,
                  key: ValueKey(isOn),
                  size: 14,
                  color: isOn ? colorScheme.primary : Colors.orange,
                ),
              ),
            ),
          ),
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
              Icon(icon, size: 18, color: colorScheme.primary),
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
          child: Column(children: children),
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
              child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
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
