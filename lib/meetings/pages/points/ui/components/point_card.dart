import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:masapp/core/constants/app_colors.dart';

import '../../data/models/point_entry.dart';

class PointCard extends StatelessWidget {
  final PointEntry point;
  final VoidCallback? onEdit;
  final bool isUpdating;

  const PointCard({
    super.key,
    required this.point,
    this.onEdit,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final valueIsPositive = point.value >= 0;

    final cardColor = isDark ? AppColors.cardDarkElevated : AppColors.cardLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final valueColor = valueIsPositive ? AppColors.success : AppColors.error;
    final iconColor = isDark ? AppColors.goldAccent : AppColors.primaryBlue;

    final timestamp = point.createdAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.overlay.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        point.patrolName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: valueColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${point.value > 0 ? '+' : ''}${point.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: valueColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _MetaLine(
                  icon: Icons.category_outlined,
                  text: point.categoryName,
                  textColor: secondaryTextColor,
                ),
                if (point.reason != null) ...[
                  const SizedBox(height: 4),
                  _MetaLine(
                    icon: Icons.notes_outlined,
                    text: point.reason!,
                    textColor: secondaryTextColor,
                  ),
                ],
                const SizedBox(height: 4),
                _MetaLine(
                  icon: Icons.person_outline,
                  text: 'Awarded by ${point.awardedByName}',
                  textColor: secondaryTextColor,
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  _MetaLine(
                    icon: Icons.schedule_outlined,
                    text: DateFormat('MMM d, yyyy  h:mm a').format(timestamp),
                    textColor: secondaryTextColor,
                  ),
                ],
              ],
            ),
          ),
          if (isUpdating)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (onEdit != null)
            IconButton(
              tooltip: 'Edit point',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: secondaryTextColor,
              ),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;

  const _MetaLine({
    required this.icon,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: textColor),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}
