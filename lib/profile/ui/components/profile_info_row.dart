import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Premium row matching the clean section card style.
class ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isMultiline;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isMultiline = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentForLabel(label, isDark);

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          // Sleek rounded square icon container
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.36 : 0.24),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: accent.withValues(alpha: isDark ? 0.95 : 0.9),
            ),
          ),
          const SizedBox(width: 16),
          // Content typography
          Expanded(
            child: isMultiline
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: content);
    }

    return content;
  }

  Color _accentForLabel(String label, bool isDark) {
    final value = label.toLowerCase();
    final base = switch (value) {
      final v when v.contains('role') => AppColors.goldAccent,
      final v when v.contains('troop') || v.contains('patrol') =>
        AppColors.badgeTeal,
      final v when v.contains('phone') || v.contains('address') =>
        AppColors.badgeGreen,
      final v when v.contains('date') || v.contains('joined') =>
        AppColors.badgeOrange,
      _ => AppColors.rankBronze,
    };
    return base.withValues(alpha: isDark ? 0.9 : 0.82);
  }
}
