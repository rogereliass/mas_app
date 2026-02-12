import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Display mode for file tile
enum FileDisplayMode {
  /// Horizontal list tile layout
  list,
  /// Vertical card layout for recent assets
  recentCard,
}

/// Reusable file tile component
/// 
/// Displays a file with appropriate icon, name, metadata
/// Supports two display modes: list (horizontal) and recentCard (vertical)
/// Uses Scout Elite design with themed colors
class FileTile extends StatelessWidget {
  final String fileId;
  final String fileName;
  final String fileType;
  final String fileSize;
  final String lastModified;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;
  final FileDisplayMode displayMode;

  const FileTile({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.lastModified,
    this.onTap,
    this.onMorePressed,
    this.displayMode = FileDisplayMode.list,
  });

  /// Get icon and color based on file type
  /// Uses centralized AppColors for consistency
  ({IconData icon, Color color}) _getFileIcon(BuildContext context) {
    final theme = Theme.of(context);
    
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return (icon: Icons.picture_as_pdf, color: AppColors.fileTypePdf);
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return (icon: Icons.image, color: AppColors.fileTypeImage);
      case 'video':
      case 'mp4':
      case 'mov':
        return (icon: Icons.play_circle_fill, color: AppColors.fileTypeVideo);
      case 'doc':
      case 'docx':
      case 'txt':
        return (icon: Icons.description, color: AppColors.fileTypeDocument);
      case 'kml':
      case 'map':
        return (icon: Icons.map, color: AppColors.fileTypeMap);
      default:
        return (icon: Icons.insert_drive_file, color: theme.iconTheme.color ?? Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return displayMode == FileDisplayMode.list 
        ? _buildListTile(context)
        : _buildRecentCard(context);
  }

  /// Build horizontal list tile layout
  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);
    final fileIcon = _getFileIcon(context);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: fileIcon.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          fileIcon.icon,
          color: fileIcon.color,
          size: 24,
        ),
      ),
      title: Text(
        fileName,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${fileType.toUpperCase()}  •  $fileSize  •  $lastModified',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
        ),
      ),
      trailing: onMorePressed != null 
          ? IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: onMorePressed,
            )
          : null,
      onTap: onTap,
    );
  }

  /// Build vertical card layout for recent assets
  Widget _buildRecentCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fileIcon = _getFileIcon(context); // This returns color
    
    // Use card color from theme or custom if needed
    final cardColor = isDark ? AppColors.cardDarkElevated : theme.cardTheme.color;
    
    return Container(
      width: 170, // Slightly reduced width for better proportion
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24), // Match image rounded look
        border: isDark 
            ? Border.all(color: Colors.white.withOpacity(0.05))
            : Border.all(color: Colors.black.withOpacity(0.03)), // Subtle border in light mode
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05), // Lighter shadow in light mode
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // File Type Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: fileIcon.color.withOpacity(0.2), // Semi-transparent bg
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    fileIcon.icon,
                    color: fileIcon.color, // Colored icon
                    size: 24,
                  ),
                ),
                
                // Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$fileSize • ${fileType.toUpperCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark 
                            ? AppColors.sectionHeaderGray 
                            : theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
