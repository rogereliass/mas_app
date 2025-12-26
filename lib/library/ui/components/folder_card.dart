import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable folder card component
/// 
/// Displays a folder with icon, name, and item count
/// Uses theme-aware colors for consistency across light/dark modes
class FolderCard extends StatelessWidget {
  final String folderId;
  final String folderName;
  final int itemCount;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;

  const FolderCard({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.itemCount,
    this.onTap,
    this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Folder icon with theme-aware background
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? AppColors.folderBackgroundDark
                          : AppColors.folderBackgroundLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder,
                      color: AppColors.folderIconColor,
                      size: 28,
                    ),
                  ),
                  // More options button
                  if (onMorePressed != null)
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: onMorePressed,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Folder name
              Text(
                folderName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Item count
              Text(
                '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
