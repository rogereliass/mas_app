import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable folder card component
/// 
/// Displays a folder with icon badge, name, and contextual item count
/// Uses Scout Elite design with horizontal layout and icon badges
class FolderCard extends StatelessWidget {
  final String folderId;
  final String folderName;
  final String? description;
  final int itemCount;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;

  const FolderCard({
    super.key,
    required this.folderId,
    required this.folderName,
    this.description,
    required this.itemCount,
    this.onTap,
    this.onMorePressed,
  });

  /// Determine icon and color based on folder name
  IconData _getFolderIcon() {
    final lowerName = folderName.toLowerCase();
    
    // Arabic keyword matching
    if (lowerName.contains('خرائط') || lowerName.contains('maps')) {
      return Icons.map;
    } else if (lowerName.contains('نشاطات') || lowerName.contains('activities') || 
               lowerName.contains('projects')) {
      return Icons.folder_special;
    } else if (lowerName.contains('أوسمة') || lowerName.contains('badges') ||
               lowerName.contains('awards')) {
      return Icons.workspace_premium;
    } else if (lowerName.contains('صور') || lowerName.contains('images') ||
               lowerName.contains('photos')) {
      return Icons.photo_library;
    } else if (lowerName.contains('تقارير') || lowerName.contains('reports') ||
               lowerName.contains('documents')) {
      return Icons.description;
    } else if (lowerName.contains('مجموعة') || lowerName.contains('collection')) {
      return Icons.collections_bookmark;
    } else if (lowerName.contains('مسارات') || lowerName.contains('paths') ||
               lowerName.contains('tracks')) {
      return Icons.route;
    }
    
    // Default folder icon
    return Icons.folder;
  }

  /// Get background color for icon badge based on folder type
  Color _getBadgeColor() {
    final lowerName = folderName.toLowerCase();
    
    if (lowerName.contains('خرائط') || lowerName.contains('maps')) {
      return AppColors.badgeYellow;
    } else if (lowerName.contains('نشاطات') || lowerName.contains('activities') || 
               lowerName.contains('projects')) {
      return AppColors.badgeBlue;
    } else if (lowerName.contains('أوسمة') || lowerName.contains('badges') ||
               lowerName.contains('awards')) {
      return AppColors.goldAccent; // Only use Gold for awards/badges
    } else if (lowerName.contains('صور') || lowerName.contains('images') ||
               lowerName.contains('photos')) {
      return AppColors.badgeOrange;
    } else if (lowerName.contains('تقارير') || lowerName.contains('reports') ||
               lowerName.contains('documents')) {
      return AppColors.badgeTeal;
    } else if (lowerName.contains('مجموعة') || lowerName.contains('collection')) {
      return AppColors.badgePurple;
    } else if (lowerName.contains('مسارات') || lowerName.contains('paths')) {
      return AppColors.badgeGreen;
    }
    
    // Default to Blue for general folders instead of Gold (too much gold)
    return AppColors.primaryBlue; 
  }

  /// Get contextual label for item count (Acting as Description)
  String _getFolderDescription() {
    // Return actual description if available
    if (description != null && description!.isNotEmpty) {
      return description!.toUpperCase();
    }
    
    // Default fallback if no description
    return 'FOLDER';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: isDark ? 4 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Increased vertical padding
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getBadgeColor(),
                      _getBadgeColor().withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _getBadgeColor().withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _getFolderIcon(),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              // Folder Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folderName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getFolderDescription(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark 
                            ? AppColors.sectionHeaderGray 
                            : theme.textTheme.bodySmall?.color,
                        fontSize: 11,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron Icon
              Icon(
                Icons.chevron_right,
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.3) // Subtler chevron
                    : theme.textTheme.bodySmall?.color,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

