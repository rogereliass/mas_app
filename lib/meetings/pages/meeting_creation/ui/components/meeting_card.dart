import 'package:flutter/material.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

/// A card displaying summary information for a single [Meeting].
class MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isDeleting;

  const MeetingCard({
    super.key,
    required this.meeting,
    this.onEdit,
    this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? AppColors.cardDarkElevated : AppColors.cardLight;
    final accentColor = isDark ? AppColors.goldAccent : AppColors.primaryBlue;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final hasPositivePrice = (meeting.price ?? 0) > 0;

    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading icon
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.event, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          // Content column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  meeting.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                // Date row
                _MetaRow(
                  icon: Icons.calendar_today,
                  label: meeting.formattedDate,
                  secondaryColor: secondaryTextColor,
                  theme: theme,
                ),
                // Time range row (conditional)
                if (meeting.formattedTimeRange.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _MetaRow(
                    icon: Icons.schedule,
                    label: meeting.formattedTimeRange,
                    secondaryColor: secondaryTextColor,
                    theme: theme,
                  ),
                ],
                // Price row (optional) - show only when strictly positive
                if (hasPositivePrice) ...[
                  const SizedBox(height: 3),
                  _MetaRow(
                    icon: Icons.attach_money,
                    label: NumberFormat.currency(
                      symbol: 'EGP ',
                    ).format(meeting.price!),
                    secondaryColor: secondaryTextColor,
                    theme: theme,
                    maxLines: 1,
                  ),
                ],
                // Location row (conditional)
                if (meeting.location != null &&
                    meeting.location!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _MetaRow(
                    icon: Icons.location_on_outlined,
                    label: meeting.location!,
                    secondaryColor: secondaryTextColor,
                    theme: theme,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          if (isDeleting)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit meeting',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: secondaryTextColor,
                      ),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete meeting',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget for icon + label rows
// ---------------------------------------------------------------------------

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color secondaryColor;
  final ThemeData theme;
  final int maxLines;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.secondaryColor,
    required this.theme,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: secondaryColor),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: secondaryColor),
          ),
        ),
      ],
    );
  }
}
