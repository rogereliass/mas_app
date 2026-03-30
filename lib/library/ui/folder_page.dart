import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routing/app_router.dart';
import '../../core/constants/app_colors.dart';
import '../../auth/logic/auth_provider.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/services/connectivity_service.dart';
import '../logic/library_provider.dart';
import 'components/folder_card.dart';
import 'components/file_tile.dart';
import 'components/library_report_dialog.dart';

/// Library home page - main entry point for browsing content
///
/// Features:
/// - Scout Elite branded header
/// - Search functionality
/// - Recent Assets section with card layout
/// - Resource Library section with folder navigation
/// - Bottom navigation
class LibraryHomePage extends StatefulWidget {
  const LibraryHomePage({super.key});

  @override
  State<LibraryHomePage> createState() => _LibraryHomePageState();
}

class _LibraryHomePageState extends State<LibraryHomePage> {
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // Load root contents on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LibraryProvider>(context, listen: false);
      provider.refreshOfflineFiles(notify: false);
      provider.loadRootContents();
    });

    _connectivitySubscription = ConnectivityService.instance.statusStream
        .listen((isOnline) {
          if (!mounted || !isOnline) {
            return;
          }

          final provider = Provider.of<LibraryProvider>(context, listen: false);
          if (!provider.isLoadingRoot &&
              (provider.hasError || provider.rootFolders.isEmpty)) {
            provider.loadRootContents(forceRefresh: true);
          }
        });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SizedBox.expand(
        child: Stack(
          children: [
            _buildLibraryContent(),
            // Floating Navbar at Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppBottomNavBar(
                currentPage: 'library',
                isAuthenticated: authProvider.isAuthenticated,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Scout Elite branded app bar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isDark = theme.brightness == Brightness.dark;
    final isAuthenticated = authProvider.isAuthenticated;

    return AppBar(
      backgroundColor: isDark ? AppColors.scoutEliteNavy : null,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.goldAccent,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isAuthenticated ? Icons.explore : Icons.arrow_back,
              color: Colors.white,
            ),
            iconSize: 20,
            padding: EdgeInsets.zero,
            onPressed: () {
              if (isAuthenticated) {
                // If user is logged in, use compass as Home button
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.home,
                  (route) => false,
                );
              } else {
                // If not authenticated, go back to startup
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.startup,
                  (route) => false,
                );
              }
            },
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.goldAccent,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            'Library',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // TODO: Navigate to search screen
          },
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.flag_outlined),
          onPressed: () {
            LibraryReportDialog.show(
              context,
              contentType: ReportContentType.general,
            );
          },
          tooltip: 'Report an Issue',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Build library content view
  Widget _buildLibraryContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Recent Assets section
          _buildRecentFilesSection(),

          const SizedBox(height: 32),

          // Resource Library section
          _buildFoldersSection(),

          const SizedBox(height: 170),
        ],
      ),
    );
  }

  /// Build Resource Library section with vertical list
  Widget _buildFoldersSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<LibraryProvider>(context);
    final folders = provider.rootFolders;
    final isOnline = ConnectivityService.instance.isOnline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESOURCE LIBRARY',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark
                      ? AppColors.sectionHeaderGray
                      : Colors.grey[600],
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (!provider.isLoadingRoot && folders.isNotEmpty)
                Text(
                  '${folders.length} Folders',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.sectionHeaderGray
                        : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Content
        if (provider.isLoadingRoot)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (provider.hasError && !isOnline && folders.isEmpty)
          _buildOfflineLibraryContent(theme, isDark, provider)
        else if (provider.hasError && folders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Text(
                    provider.error ?? 'An error occurred',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => provider.refreshRootContents(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (folders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No folders found',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.sectionHeaderGray
                      : Colors.grey[600],
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: folders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final folder = folders[index];
              return FolderCard(
                folderId: folder.id,
                folderName: folder.name,
                description: folder.description,
                itemCount: folder.itemCount,
                onTap: () {
                  AppRouter.goToFolder(
                    context,
                    folderId: folder.id,
                    folderName: folder.name,
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildOfflineLibraryContent(
    ThemeData theme,
    bool isDark,
    LibraryProvider provider,
  ) {
    final offlineFiles = provider.offlineFiles;

    if (offlineFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'You are offline',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No downloaded library files are available on this device yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.sectionHeaderGray
                      : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'OFFLINE DOWNLOADS',
            style: theme.textTheme.labelLarge?.copyWith(
              color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '${offlineFiles.length} downloaded files available offline',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: offlineFiles.length,
          itemBuilder: (context, index) {
            final file = offlineFiles[index];
            return FileTile(
              fileId: file.fileId,
              fileName: file.fileName,
              fileType: _inferFileType(file.fileName),
              fileSize: _formatFileSize(file.sizeBytes),
              lastModified:
                  'Downloaded ${_formatDownloadedDate(file.downloadedAt)}',
              onTap: () {
                AppRouter.goToFileViewer(
                  context,
                  fileId: file.fileId,
                  fileName: file.fileName,
                  fileType: _inferFileType(file.fileName),
                  fileSizeBytes: file.sizeBytes,
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _inferFileType(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) {
      return 'file';
    }
    return parts.last.toLowerCase();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDownloadedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    }
    if (difference.inDays == 1) {
      return 'yesterday';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Build Recent Assets section with horizontal card scroll
  Widget _buildRecentFilesSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<LibraryProvider>(context);
    final files = provider.recentFiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT ASSETS',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark
                      ? AppColors.sectionHeaderGray
                      : Colors.grey[600],
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              // "New" Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.goldAccent.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'New',
                  style: TextStyle(
                    color: AppColors.goldAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Content
        if (provider.isLoadingRoot)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (files.isEmpty && !provider.hasError)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No recent files',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.sectionHeaderGray
                      : Colors.grey[600],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 180, // Reduced height for more square aspect ratio
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ), // Added vertical padding for shadows
              itemCount: files.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: 20), // Increased spacing between cards
              itemBuilder: (context, index) {
                final file = files[index];
                return FileTile(
                  fileId: file.id,
                  fileName: file.title,
                  fileType: file.fileType?.toUpperCase() ?? '',
                  fileSize: file.formattedSize,
                  lastModified: _formatDate(file.createdAt),
                  displayMode: FileDisplayMode.recentCard,
                  onTap: () async {
                    // Record view and navigate to file viewer
                    await provider.recordFileView(file.id);

                    if (!context.mounted) return;
                    AppRouter.goToFileViewer(
                      context,
                      fileId: file.id,
                      fileName: file.title,
                      fileType: file.fileType ?? '',
                      fileSizeBytes: file.sizeBytes,
                      description: file.description,
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
