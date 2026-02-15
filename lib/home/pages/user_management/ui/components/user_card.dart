import 'package:flutter/material.dart';
import '../../data/models/managed_user_profile.dart';

/// User Card Component
///
/// Displays a user profile card with:
/// - User avatar with initials
/// - Full name and primary role
/// - Email and phone (if available)
/// - Signup troop information (if available)
/// - Edit button to trigger user profile editing
///
/// This is a feature-specific component for the user management feature.
class UserCard extends StatelessWidget {
  /// The user profile to display
  final ManagedUserProfile profile;

  /// Callback triggered when the edit button is pressed
  final VoidCallback onEdit;

  const UserCard({
    super.key,
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roleName = profile.primaryRole?.name ?? 'No Role';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    profile.fullName.trim().isNotEmpty
                        ? profile.fullName.trim().substring(0, 1).toUpperCase()
                        : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Edit User',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (profile.email != null && profile.email!.isNotEmpty)
              Text(
                profile.email!,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            if (profile.phone != null && profile.phone!.isNotEmpty)
              Text(
                profile.phone!,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            if (profile.signupTroopName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Troop: ${profile.signupTroopName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
