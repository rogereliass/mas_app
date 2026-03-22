import 'package:flutter/material.dart';
import '../../data/models/managed_user_profile.dart';

/// User Card Component
///
/// Displays a user profile card with:
/// - User avatar with modern gradient
/// - Full name and primary role badge
/// - Email, phone, and troop details natively structured
/// - Edit button to trigger user profile editing
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
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                colorScheme.primaryContainer.withValues(alpha: 0.3),
                                colorScheme.secondaryContainer.withValues(alpha: 0.08),
                              ]
                            : [
                                colorScheme.primaryContainer.withValues(alpha: 0.5),
                                colorScheme.secondaryContainer.withValues(alpha: 0.25),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      profile.fullName.trim().isNotEmpty
                          ? profile.fullName.trim().substring(0, 1).toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: colorScheme.secondary,
                    ),
                    onPressed: onEdit,
                    tooltip: 'Edit User',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildInfoItem(
                    context,
                    icon: Icons.email_outlined,
                    label: profile.email?.isNotEmpty == true ? profile.email! : 'Not provided',
                  ),
                  _buildInfoItem(
                    context,
                    icon: Icons.phone_outlined,
                    label: profile.phone?.isNotEmpty == true ? profile.phone! : 'Not provided',
                  ),
                  if (profile.signupTroopName?.isNotEmpty == true)
                    _buildInfoItem(
                      context,
                      icon: Icons.groups_outlined,
                      label: profile.signupTroopName!,
                      isDimmed: false,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isDimmed = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isNotProvided = label == 'Not provided';
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant.withValues(alpha: isNotProvided ? 0.4 : 0.7),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isNotProvided 
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6) 
                : colorScheme.onSurfaceVariant,
            fontStyle: isNotProvided ? FontStyle.italic : FontStyle.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
