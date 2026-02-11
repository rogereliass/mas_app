import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/logic/auth_provider.dart';

/// No Role Message Component
/// 
/// Displayed when user has no assigned roles
/// Provides guidance to refresh profile or contact support
class NoRoleMessage extends StatelessWidget {
  const NoRoleMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.error.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      color: colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: colorScheme.onErrorContainer,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              'No Role Assigned',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Description
            Text(
              'Your account does not have any roles assigned yet. This means you may have limited access to app features.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Column(
              children: [
                // Refresh Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      
                      // Show loading indicator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing profile...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // Refresh profile
                      await authProvider.refreshProfile();
                      
                      // Check if roles loaded
                      if (context.mounted) {
                        if (authProvider.userRoles.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No roles found. Please contact support.',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Roles loaded: ${authProvider.userRoles.length}',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Contact Support Text
                TextButton.icon(
                  onPressed: () {
                    // TODO: Add contact support functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please contact your troop administrator or system admin for role assignment.',
                        ),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  },
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Contact Support'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Additional Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you just registered, your account may be pending approval.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
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
