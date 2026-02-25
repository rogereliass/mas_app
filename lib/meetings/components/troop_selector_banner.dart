import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/meeting_creation/logic/meetings_provider.dart';

/// Card-style banner displayed when an admin has not yet selected a troop.
/// Shows a dropdown to choose a troop, or a loading indicator while troops load.
class TroopSelectorBanner extends StatelessWidget {
  final List<Map<String, dynamic>> troops;
  final String? selectedTroopId;

  const TroopSelectorBanner({
    super.key,
    required this.troops,
    required this.selectedTroopId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.cardDarkElevated : AppColors.cardLight;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.overlay.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_outlined,
                size: 18,
                color: isDark ? AppColors.goldAccent : AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'Select a troop to manage',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          troops.isEmpty
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: isDark
                          ? AppColors.goldAccent
                          : AppColors.primaryBlue,
                    ),
                  ),
                )
              : DropdownButtonFormField<String>(
                  initialValue: selectedTroopId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Troop',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  selectedItemBuilder: (context) {
                    return troops.map((troop) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          troop['name'] as String? ?? '',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  items: troops.map((troop) {
                    return DropdownMenuItem<String>(
                      value: troop['id'] as String?,
                      child: Text(
                        troop['name'] as String? ?? '',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      Provider.of<MeetingsProvider>(context, listen: false)
                          .selectTroop(value);
                    }
                  },
                ),
        ],
      ),
    );
  }
}
