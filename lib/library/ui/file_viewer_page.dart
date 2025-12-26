import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'components/bottom_nav_bar.dart';
import 'file_viewer/pdf_viewer_widget.dart';
import 'file_viewer/image_viewer_widget.dart';
import 'file_viewer/video_viewer_widget.dart';
import 'file_viewer/txt_viewer_widget.dart';

/// File Viewer Page
/// 
/// Displays files in view-only mode with streaming support
/// Supports: PDF, Images, Videos, Text files
/// Files are NOT saved locally unless user taps download button
class FileViewerPage extends StatefulWidget {
  final String fileId;
  final String fileName;
  final String fileType;
  final int fileSizeBytes;
  final String? fileUrl; // Supabase storage URL
  final String? description;
  final String? publisher;
  final String? language;
  final int? pageCount;

  const FileViewerPage({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.fileType,
    required this.fileSizeBytes,
    this.fileUrl,
    this.description,
    this.publisher,
    this.language,
    this.pageCount,
  });

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isAvailableOffline = false;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkOfflineAvailability();
  }

  /// Check if file is already downloaded locally
  Future<void> _checkOfflineAvailability() async {
    // TODO: Check Hive or local storage for downloaded file
    // final exists = await LocalStorageService.fileExists(widget.fileId);
    // setState(() {
    //   _isAvailableOffline = exists;
    // });
  }

  /// Download file to local storage
  Future<void> _downloadFile() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // TODO: Implement Supabase file download with progress
      // final supabase = Supabase.instance.client;
      // final bytes = await supabase.storage
      //     .from('files')
      //     .download(widget.fileUrl ?? '');
      // 
      // // Save to local storage
      // await LocalStorageService.saveFile(
      //   fileId: widget.fileId,
      //   fileName: widget.fileName,
      //   bytes: bytes,
      //   onProgress: (progress) {
      //     setState(() {
      //       _downloadProgress = progress;
      //     });
      //   },
      // );

      // Simulate download progress
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() {
          _downloadProgress = i / 100;
        });
      }

      setState(() {
        _isDownloading = false;
        _isAvailableOffline = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File downloaded successfully')),
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  /// Get formatted file size
  String get _formattedFileSize {
    if (widget.fileSizeBytes < 1024) return '${widget.fileSizeBytes}B';
    if (widget.fileSizeBytes < 1024 * 1024) {
      return '${(widget.fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(widget.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: _currentNavIndex == 0 
          ? _buildFileViewerContent()
          : _buildAboutContent(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
    );
  }

  /// Build app bar with back button and download action
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Image.asset(
        'assets/images/mas_logo.png',
        height: 40,
        errorBuilder: (context, error, stackTrace) {
          return const Text(
            'SCOUT LOGO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          );
        },
      ),
      centerTitle: true,
      actions: [
        if (_isDownloading)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: _downloadProgress,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryBlue,
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(
              _isAvailableOffline ? Icons.download_done : Icons.download,
              color: _isAvailableOffline ? AppColors.success : null,
            ),
            onPressed: _isAvailableOffline ? null : _downloadFile,
            tooltip: _isAvailableOffline ? 'Available Offline' : 'Download',
          ),
      ],
    );
  }

  /// Build main file viewer content
  Widget _buildFileViewerContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // File preview with type badge and progress
          _buildFilePreview(),

          const SizedBox(height: 24),

          // File title and metadata
          _buildFileInfo(),

          const SizedBox(height: 24),

          // Description section
          if (widget.description != null) ...[
            _buildDescription(),
            const SizedBox(height: 24),
          ],

          // Publisher and Language info
          _buildMetadata(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Build file preview with type badge
  Widget _buildFilePreview() {
    final theme = Theme.of(context);
    final fileType = widget.fileType.toLowerCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 500,
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.cardDark
              : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // File viewer based on type
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildFileViewer(fileType),
            ),

            // Type badge
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.fileType.toUpperCase()} DOCUMENT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // Download progress bar at bottom
            if (_isDownloading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.publicAccessBadge,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build appropriate file viewer based on file type
  Widget _buildFileViewer(String fileType) {
    // TODO: Replace with actual Supabase streaming URL
    final streamUrl = widget.fileUrl ?? '';

    switch (fileType) {
      case 'pdf':
        return PDFViewerWidget(url: streamUrl);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'image':
        return ImageViewerWidget(url: streamUrl);
      case 'mp4':
      case 'mov':
      case 'video':
        return VideoViewerWidget(url: streamUrl);
      case 'txt':
      case 'text':
        return TxtViewerWidget(url: streamUrl);
      default:
        return _buildUnsupportedFileType();
    }
  }

  /// Build unsupported file type placeholder
  Widget _buildUnsupportedFileType() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Unsupported file type',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Build file info section
  Widget _buildFileInfo() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.fileName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                widget.pageCount != null
                    ? '${widget.pageCount} Pages • $_formattedFileSize'
                    : _formattedFileSize,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(width: 16),
              if (_isAvailableOffline)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.publicAccessBadge.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.publicAccessBadge,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.publicAccessBadge,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Available Offline',
                        style: TextStyle(
                          color: AppColors.publicAccessBadge,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build description section
  Widget _buildDescription() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESCRIPTION',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: theme.brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.description ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: theme.brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  /// Build metadata section (Publisher & Language)
  Widget _buildMetadata() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PUBLISHER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: theme.brightness == Brightness.dark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.publisher ?? 'Unknown',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppColors.surfaceDark
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LANGUAGE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: theme.brightness == Brightness.dark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.language ?? 'English',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build about content placeholder
  Widget _buildAboutContent() {
    return const Center(
      child: Text('About section'),
    );
  }
}
