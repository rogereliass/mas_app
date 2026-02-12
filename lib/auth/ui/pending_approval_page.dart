// ⚠️ ARCHIVED - NOT CURRENTLY IN USE ⚠️
// This page is preserved for potential future use but is not wired into the app.
// It is not imported, routed, or referenced anywhere in the active codebase.
// Date archived: February 10, 2026
// To reactivate: Add route to app_router.dart and update navigation flow

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/theme_provider.dart';
import '../../routing/app_router.dart';
import '../logic/auth_provider.dart';

/// Pending Approval Page (ARCHIVED)
/// 
/// Shown to users who have successfully registered but are awaiting admin approval
/// Provides clear messaging and logout option
/// 
/// NOTE: This page is currently not in use. See header comment for details.
class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Account Pending'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pending icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Account Pending Approval',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Message
              Text(
                'Your registration has been received and is currently under review by our administrators.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Info card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What happens next?',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        '1',
                        'Admin reviews your registration details',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context,
                        '2',
                        'You\'ll be assigned a generation and role',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context,
                        '3',
                        'You\'ll receive access to the platform',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // User info
              if (authProvider.currentUserProfile != null) ...[
                Text(
                  'Registered as:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authProvider.currentUserProfile!.fullName ?? 'No name',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (authProvider.currentUserProfile!.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    authProvider.currentUserProfile!.phone!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
              
              const SizedBox(height: 48),
              
              // Actions
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Navigate first, then sign out to prevent UI flash
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRouter.startup,
                      (route) => false,
                    );
                    await authProvider.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Refresh button
              TextButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await authProvider.refreshProfile();
                  
                  if (context.mounted) {
                  // TODO: wire in the pending user
                    // if (authProvider.currentUserProfile?.approved == true) {
                    //   // User is now approved, redirect to home
                    //   Navigator.of(context).pushReplacementNamed(AppRouter.home);
                    // } else {
                    //   messenger.showSnackBar(
                    //     const SnackBar(
                    //       content: Text('Still pending approval. Please check back later.'),
                    //       duration: Duration(seconds: 2),
                    //     ),
                    //   );
                    // }
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String number, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
