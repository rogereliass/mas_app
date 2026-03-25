import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/error_translator.dart';
import '../logic/library_provider.dart';
import '../data/library_models.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/settings_dialog.dart';
import '../../offline/offline_storage.dart';
import '../../offline/download_service.dart';
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
  final _downloadService = DownloadService();
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadFileData();
  }

  /// Load file data from provider
  Future<void> _loadFileData() async {
    final provider = Provider.of<LibraryProvider>(context, listen: false);
    final fallbackFile = _buildFallbackFile();

    try {
      final fetchedFile = await provider.getFile(widget.fileId);
      final file = fetchedFile ?? fallbackFile;
      if (kDebugMode) {
        debugPrint('📂 Loaded file: ${file.title}, type: ${file.fileType}');
        debugPrint('📁 Storage path: ${file.storagePath}');
        debugPrint('🔗 Icon URL: ${file.iconUrl}');
      }

      _file = file;

      // Check if it's a video or audio file
      final isVideo = file.fileType?.toLowerCase() == 'video';
      final isAudio = file.fileType?.toLowerCase() == 'audio';

      // Check if file is available offline for all non-video files.
      // Text files are stored as bytes and decoded back when offline.
      final shouldCheckOffline = !isVideo;
      final offlinePath = shouldCheckOffline
          ? OfflineStorageService.getFilePath(widget.fileId)
          : null;
      final hasOffline = offlinePath != null;

      if (isVideo) {
        // For video files, use storagePath directly (YouTube URL)
        if (kDebugMode) {
          debugPrint('🎥 Video file - using storagePath: ${file.storagePath}');
        }

        if (mounted) {
          setState(() {
            _fileUrl = file.storagePath; // Use storagePath as YouTube URL
            _isLoadingFile = false;
          });
        }
      } else if (hasOffline && file.isTextFile) {
        // Use offline cached bytes for text files when network content is unavailable.
        final content = await _readOfflineText(offlinePath);

        if (mounted) {
          setState(() {
            _file = file.copyWith(textContent: content);
            _isLoadingFile = false;
            _isAvailableOffline = true;
          });
        }
      } else if (hasOffline) {
        // Use offline cached file for PDFs, images, and audio.
        if (kDebugMode) {
          debugPrint('💾 Using offline cached file: $offlinePath');
        }

        if (mounted) {
          setState(() {
            _fileUrl = offlinePath; // Use local file path directly
            _isLoadingFile = false;
            _isAvailableOffline = true; // Set offline status immediately
          });
        }
      } else if (isAudio) {
        // For audio files, get signed URL from Supabase storage
        if (kDebugMode) {
          debugPrint('🎵 Audio file - getting signed URL');
        }
        final url = await provider.getFileUrl(widget.fileId);
        if (kDebugMode) {
          debugPrint('🔗 Generated signed URL for audio: $url');
        }

        if (mounted) {
          setState(() {
            _fileUrl = url;
            _isLoadingFile = false;
          });
        }
      } else if (!file.isTextFile) {
        // Get signed URL for non-video, non-text files
        final url = await provider.getFileUrl(widget.fileId);
        if (kDebugMode) {
          debugPrint('🔗 Generated signed URL: $url');
        }

        if (mounted) {
          setState(() {
            _fileUrl = url;
            _isLoadingFile = false;
          });
        }
      } else {
        // For text files, load content from storage if text_content is empty
        final textContent = await provider.getTextFileContent(widget.fileId);
        if (kDebugMode) {
          debugPrint(
            '📝 Text file loaded - content length: ${textContent?.length ?? 0}',
          );
        }

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
                downloadsAllowed: file.downloadsAllowed,
                minRoleRank: file.minRoleRank, // Preserve role rank
                createdAt: file.createdAt,
              );
            }
            _isLoadingFile = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading file: $e');
      }
      if (mounted) {
        setState(() {
          _file ??= fallbackFile;
          _isLoadingFile = false;
        });
      }
    }

    _checkOfflineAvailability();
  }

  LibraryFile _buildFallbackFile() {
    return LibraryFile(
      id: widget.fileId,
      folderId: null,
      title: widget.fileName,
      description: widget.description,
      fileType: widget.fileType,
      storagePath: null,
      sizeBytes: widget.fileSizeBytes,
      iconUrl: null,
      visibilityRoleId: null,
      allowedRoles: null,
      textContent: null,
      serverVersion: 1,
      tags: null,
      downloadsAllowed: true,
      minRoleRank: 0,
      createdAt: DateTime.now(),
    );
  }

  Future<String?> _readOfflineText(String? offlinePath) async {
    if (offlinePath == null || offlinePath.isEmpty) {
      return null;
    }

    try {
      final file = File(offlinePath);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed reading offline text file: $e');
      }
      return null;
    }
  }

  /// Check if file is already downloaded locally
  Future<void> _checkOfflineAvailability() async {
    final isOffline = OfflineStorageService.isAvailableOffline(widget.fileId);

    if (mounted) {
      setState(() {
        _isAvailableOffline = isOffline;
      });
    }

    // If file is offline and we have internet, check for updates
    if (isOffline && _file != null) {
      await _checkAndUpdateIfNeeded();
    }
  }

  /// Check if server has newer version and auto-update
  Future<void> _checkAndUpdateIfNeeded() async {
    if (_isCheckingUpdate || _file == null) return;

    final serverVersion = _file!.serverVersion ?? 1;
    final needsUpdate = OfflineStorageService.needsUpdate(
      widget.fileId,
      serverVersion,
    );

    if (!needsUpdate) return;

    // Validate storage path before updating
    if (_file!.storagePath == null || _file!.storagePath!.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ Cannot auto-update: Storage path not available');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('🔄 New version available, auto-updating...');
    }

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final updated = await _downloadService.checkAndUpdate(
        fileId: widget.fileId,
        fileName: widget.fileName,
        storagePath: _file!.storagePath!,
        fileType: widget.fileType,
        serverVersion: serverVersion,
        fileSizeBytes: _file!.sizeBytes,
        iconUrl: _file!.iconUrl,
      );

      if (updated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.download_done, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Newer Version has been downloaded',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        // Reload the file with updated content
        await _loadFileData();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking for updates: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  /// Download file to local storage
  Future<void> _downloadFile() async {
    if (_isDownloading || _file == null) return;

    // Check if downloads are allowed for this file
    if (_file!.downloadsAllowed == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloads are not allowed for this file'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Don't allow download for videos (YouTube URLs)
    if (widget.fileType.toLowerCase() == 'video') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Videos cannot be downloaded offline'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validate storage path
    if (_file!.storagePath == null || _file!.storagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot download: File storage path not available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // Simulate progress updates
      _updateProgressPeriodically();

      final filePath = await _downloadService.downloadAndCache(
        fileId: widget.fileId,
        fileName: widget.fileName,
        storagePath: _file!.storagePath!,
        fileType: widget.fileType,
        serverVersion: _file!.serverVersion ?? 1,
        fileSizeBytes: _file!.sizeBytes,
        iconUrl: _file!.iconUrl,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      if (filePath != null) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0;
          _isAvailableOffline = true;
        });

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File downloaded successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // CRITICAL FIX: Reload file data to use the cached version
        await _loadFileData();
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });

      if (!mounted) return;
      final userMessage = ErrorTranslator.toUserMessage(e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage)));
    }
  }

  /// Simulate progress updates during download
  void _updateProgressPeriodically() {
    Future.doWhile(() async {
      if (!_isDownloading || !mounted) return false;

      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted && _downloadProgress < 0.9) {
        setState(() {
          _downloadProgress += 0.05;
        });
      }

      return _isDownloading && _downloadProgress < 0.9;
    });
  }

  /// Remove file from offline storage
  Future<void> _removeFromOffline() async {
    if (_file == null || !_isAvailableOffline) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Offline File'),
        content: const Text(
          'Are you sure you want to remove this file from offline storage? '
          'You will need an internet connection to view it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Delete file from offline storage
      await OfflineStorageService.deleteFile(widget.fileId);

      setState(() {
        _isAvailableOffline = false;
      });

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('File removed from offline storage'),
            ],
          ),
          backgroundColor: AppColors.primaryBlue,
          duration: Duration(seconds: 2),
        ),
      );

      // Reload file data to use online version
      await _loadFileData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove file: $e'),
          backgroundColor: Colors.red,
        ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark ? AppColors.scoutEliteNavy : null,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.goldAccent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.goldAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.goldAccent, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      title: Text(
        _file?.title ?? widget.fileName,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: true,
      actions: [
        // Hide download button for videos, audio, and when downloads are not allowed
        if (widget.fileType.toLowerCase() != 'video' &&
            widget.fileType.toLowerCase() != 'audio' &&
            _file?.downloadsAllowed != false) ...[
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
              onPressed: _isAvailableOffline
                  ? _removeFromOffline
                  : _downloadFile,
              tooltip: _isAvailableOffline
                  ? 'Remove from Offline Storage'
                  : 'Download for Offline Use',
            ),
        ],
        // Settings icon
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const SettingsDialog(),
            );
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }

  /// Build main file viewer content
  Widget _buildFileViewerContent() {
    if (_isLoadingFile) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_file == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: isVideo
            ? null
            : MediaQuery.of(context).size.height *
                  0.7, // Dynamic height for videos
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.cardDark
              : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                  color: Colors.black.withValues(alpha: 0.7),
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
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
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
    if (kDebugMode) {
      debugPrint('🎬 Building viewer for type: $fileType');
    }

    // For text files, pass the text content directly
    if (fileType == 'text' || fileType == 'txt') {
      if (kDebugMode) {
        debugPrint(
          '📝 Rendering text file with content: ${_file?.textContent?.substring(0, 50) ?? "empty"}...',
        );
      }
      return TxtViewerWidget(
        url: '',
        textContent: _file?.textContent,
        iconUrl: _file?.iconUrl,
      );
    }

    // For other files, use the signed URL
    final streamUrl = _fileUrl ?? widget.fileUrl ?? '';
    if (kDebugMode) {
      debugPrint('🔗 Using URL for viewer: $streamUrl');
    }

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
        return AudioViewerWidget(url: streamUrl, iconUrl: _file?.iconUrl);
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
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Unsupported file type',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Build file info section
  Widget _buildFileInfo() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fileSize = _file?.formattedSize ?? _formattedFileSize;
    final showFileSize = fileSize != 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (showFileSize) ...[
            Text(
              fileSize,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (_isAvailableOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.goldAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.goldAccent, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.goldAccent,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Available Offline',
                    style: TextStyle(
                      color: AppColors.goldAccent,
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
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESCRIPTION',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: isDark
                  ? AppColors.sectionHeaderGray
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _file?.description ?? widget.description ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: isDark
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
    final isDark = theme.brightness == Brightness.dark;
    final tags = _file?.tags ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAGS',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: isDark
                  ? AppColors.sectionHeaderGray
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
                  color: AppColors.goldAccent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.goldAccent.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  tag,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.goldAccent
                        : const Color(0xFF885A0A),
                    fontWeight: FontWeight.w600,
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
