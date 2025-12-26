import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable file tile component
/// 
/// Displays a file with appropriate icon, name, metadata
/// Uses theme-aware colors and file type differentiation
class FileTile extends StatelessWidget {
  final String fileId;
  final String fileName;
  final String fileType;
  final String fileSize;
  final String lastModified;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;

  const FileTile({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.lastModified,
    this.onTap,
    this.onMorePressed,
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
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, size: 20),
        onPressed: onMorePressed,
      ),
      onTap: onTap,
    );
  }
}
