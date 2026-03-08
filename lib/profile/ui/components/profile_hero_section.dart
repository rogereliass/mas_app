import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Clean, minimal hero section that seamlessly blends into the app background.
class ProfileHeroSection extends StatelessWidget {
  final String fullName;
  final String? secondaryInfo;
  final String? email;
  final String? avatarUrl;
  final VoidCallback onQrTap;

  const ProfileHeroSection({
    super.key,
    required this.fullName,
    required this.onQrTap,
    this.secondaryInfo,
    this.email,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final nameColor = isDark ? AppColors.goldAccent : AppColors.rankBronze;

    return Column(
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: isDark ? 0.22 : 0.1,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  AppColors.goldAccent.withValues(alpha: isDark ? 0.65 : 0.45),
                  AppColors.badgeTeal.withValues(alpha: isDark ? 0.45 : 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: CircleAvatar(
                backgroundColor: isDark
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surfaceContainerLow,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Text(
                        _getInitials(fullName),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          fullName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: nameColor,
            letterSpacing: -0.5,
          ),
        ),
        if (email != null && email!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (secondaryInfo != null && secondaryInfo!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.goldAccent.withValues(alpha: isDark ? 0.22 : 0.14),
                  AppColors.badgeTeal.withValues(alpha: isDark ? 0.16 : 0.1),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border.all(
                color: AppColors.goldAccent.withValues(
                  alpha: isDark ? 0.38 : 0.24,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              secondaryInfo!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton.tonalIcon(
          onPressed: onQrTap,
          icon: const Icon(Icons.qr_code_2_rounded, size: 20),
          label: const Text('Show QR Code'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.goldAccent.withValues(
              alpha: isDark ? 0.28 : 0.16,
            ),
            foregroundColor: colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(
              color: AppColors.rankBronze.withValues(
                alpha: isDark ? 0.42 : 0.28,
              ),
            ),
            textStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return 'U';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
