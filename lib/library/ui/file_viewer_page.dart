import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/library_provider.dart';
import '../data/library_models.dart';
import '../../core/constants/app_colors.dart';
import 'file_viewer/pdf_viewer_widget.dart';
import 'file_viewer/image_viewer_widget.dart';
import 'file_viewer/video_viewer_widget.dart';
import 'file_viewer/txt_viewer_widget.dart';
import 'file_viewer/audio_viewer_widget.dart';

/// File Viewer Page
/// 
/// Displays files in view-only mode with streaming support
/// Supports: PDF, Images, Videos, Text files
/// Files are NOT saved locally unless user taps download button
class FileViewerPage extends StatefulWidget {
  final String fileId;
  final String fileName;
  final String fileType;
  final int? fileSizeBytes;
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
    this.fileSizeBytes,
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
  LibraryFile? _file;
  String? _fileUrl;
  bool _isLoadingFile = true;

  @override
  void initState() {
    super.initState();
    _loadFileData();
  }

  /// Load file data from provider
  Future<void> _loadFileData() async {
    final provider = Provider.of<LibraryProvider>(context, listen: false);
    
    try {
      final file = await provider.getFile(widget.fileId);
      print('📂 Loaded file: ${file?.title}, type: ${file?.fileType}');
      print('📁 Storage path: ${file?.storagePath}');
      print('🔗 Icon URL: ${file?.iconUrl}');
      
      if (file != null) {
        _file = file;
        
        // Check if it's a video or audio file
        final isVideo = file.fileType?.toLowerCase() == 'video';
        final isAudio = file.fileType?.toLowerCase() == 'audio';
        
        if (isVideo) {
          // For video files, use storagePath directly (YouTube URL)
          print('🎥 Video file - using storagePath: ${file.storagePath}');
          
          if (mounted) {
            setState(() {
              _fileUrl = file.storagePath; // Use storagePath as YouTube URL
              _isLoadingFile = false;
            });
          }
        } else if (isAudio) {
          // For audio files, get signed URL from Supabase storage
          print('🎵 Audio file - getting signed URL');
          final url = await provider.getFileUrl(widget.fileId);
          print('🔗 Generated signed URL for audio: $url');
          
          if (mounted) {
            setState(() {
              _fileUrl = url;
              _isLoadingFile = false;
            });
          }
        } else if (!file.isTextFile) {
          // Get signed URL for non-video, non-text files
          final url = await provider.getFileUrl(widget.fileId);
          print('🔗 Generated signed URL: $url');
          
          if (mounted) {
            setState(() {
              _fileUrl = url;
              _isLoadingFile = false;
            });
          }
        } else {
          // For text files, load content from storage if text_content is empty
          final textContent = await provider.getTextFileContent(widget.fileId);
          print('📝 Text file loaded - content length: ${textContent?.length ?? 0}');
          
          if (mounted) {
            setState(() {
              // Update the file object with loaded content
              if (textContent != null) {
                _file = LibraryFile(
                  id: file.id,
                  folderId: file.folderId,
                  title: file.title,
                  description: file.description,
                  fileType: file.fileType,
                  storagePath: file.storagePath,
                  sizeBytes: file.sizeBytes,
                  iconUrl: file.iconUrl,
                  visibilityRoleId: file.visibilityRoleId,
                  allowedRoles: file.allowedRoles,
                  textContent: textContent, // Use loaded content
                  serverVersion: file.serverVersion,
                  tags: file.tags,
                  createdAt: file.createdAt,
                );
              }
              _isLoadingFile = false;
            });
          }
        }
      } else {
        print('❌ File not found');
        if (mounted) {
          setState(() {
            _isLoadingFile = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading file: $e');
      if (mounted) {
        setState(() {
          _isLoadingFile = false;
        });
      }
    }
    
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
      final provider = Provider.of<LibraryProvider>(context, listen: false);
      
      // Download file bytes
      final bytes = await provider.downloadFile(widget.fileId);
      
      if (bytes == null) {
        throw Exception('Failed to download file');
      }

      // TODO: Save to local storage using path_provider
      // final directory = await getApplicationDocumentsDirectory();
      // final filePath = '${directory.path}/${widget.fileName}';
      // final file = File(filePath);
      // await file.writeAsBytes(bytes);
      
      // Simulate progress
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 100));
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
    final bytes = widget.fileSizeBytes;
    if (bytes == null) return 'Unknown';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: _buildFileViewerContent(),
    );
  }

  /// Build app bar with back button and download action
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _file?.title ?? widget.fileName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: true,
      actions: [
        // Hide download button for videos and audio
        if (widget.fileType.toLowerCase() != 'video' && widget.fileType.toLowerCase() != 'audio') ...[        
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
      ],
    );
  }

  /// Build main file viewer content
  Widget _buildFileViewerContent() {
    if (_isLoadingFile) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_file == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text('File not found'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

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
          if (_file?.description != null && 
              _file!.description!.trim().isNotEmpty) ...[
            _buildDescription(),
            const SizedBox(height: 24),
          ],

          // Tags section
          if (_file!.tags != null && _file!.tags!.isNotEmpty) ...[
            _buildTags(),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Build file preview with type badge
  Widget _buildFilePreview() {
    final theme = Theme.of(context);
    final fileType = widget.fileType.toLowerCase();
    final isVideo = fileType == 'video';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: isVideo ? null : MediaQuery.of(context).size.height * 0.7, // Dynamic height for videos
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
    print('🎬 Building viewer for type: $fileType');
    
    // For text files, pass the text content directly
    if (fileType == 'text' || fileType == 'txt') {
      print('📝 Rendering text file with content: ${_file?.textContent?.substring(0, 50) ?? "empty"}...');
      return TxtViewerWidget(
        url: '',
        textContent: _file?.textContent,
        iconUrl: _file?.iconUrl,
      );
    }

    // For other files, use the signed URL
    final streamUrl = _fileUrl ?? widget.fileUrl ?? '';
    print('🔗 Using URL for viewer: $streamUrl');

    switch (fileType.toLowerCase()) {
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
      case 'mp3':
      case 'wav':
      case 'audio':
        return AudioViewerWidget(
          url: streamUrl,
          iconUrl: _file?.iconUrl,
        );
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
    final fileSize = _file?.formattedSize ?? _formattedFileSize;
    final showFileSize = fileSize != 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showFileSize) ...[
            Text(
              fileSize,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 16),
          ],
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
            _file?.description ?? widget.description ?? '',
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

  /// Build tags section
  Widget _buildTags() {
    final theme = Theme.of(context);
    final tags = _file?.tags ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAGS',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: theme.brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  tag,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
