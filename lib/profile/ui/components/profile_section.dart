import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Premium, Apple/Linear style section container.
/// Groups items cleanly into a rounded continuous card with subtle dividers.
class ProfileSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final Widget? trailing;

  const ProfileSection({
    super.key,
    this.title,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || trailing != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (title != null)
                  Text(
                    title!.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isDark
                          ? colorScheme.onSurfaceVariant
                          : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      colorScheme.surfaceContainerLow,
                      colorScheme.surfaceContainerHigh,
                    ]
                  : [
                      AppColors.cardLight,
                      AppColors.surfaceLight.withValues(alpha: 0.9),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? colorScheme.outlineVariant.withValues(alpha: 0.34)
                  : AppColors.goldAccent.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: AppColors.goldAccent.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: _buildChildrenWithDividers(colorScheme, isDark),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChildrenWithDividers(
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 64, // Aligns exactly after the icon container
            color: isDark
                ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                : AppColors.goldAccent.withValues(alpha: 0.16),
          ),
        );
      }
    }
    return result;
  }
}
