import 'package:flutter/material.dart';

class SmartStackCardBase extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? customSubtitle;
  final List<Color> colors;
  final Color onColor;
  final bool hideHeaderIcon;
  final FontWeight titleWeight;
  final double backgroundIconSize;
  final double? backgroundIconTop;
  final double? backgroundIconRight;
  final double? backgroundIconBottom;
  final double? backgroundIconLeft;

  const SmartStackCardBase({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.customSubtitle,
    required this.colors,
    required this.onColor,
    this.hideHeaderIcon = false,
    this.titleWeight = FontWeight.bold,
    this.backgroundIconSize = 120,
    this.backgroundIconTop = -20,
    this.backgroundIconRight = -20,
    this.backgroundIconBottom,
    this.backgroundIconLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: backgroundIconTop,
            right: backgroundIconRight,
            bottom: backgroundIconBottom,
            left: backgroundIconLeft,
            child: Icon(
              icon,
              size: backgroundIconSize,
              color: onColor.withValues(alpha: 0.12),
            ),
          ),
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(), // Prevent erratic scrolling 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hideHeaderIcon) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: onColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: onColor),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: titleWeight,
                    color: onColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (customSubtitle != null)
                  customSubtitle!
                else if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onColor.withValues(alpha: 0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
