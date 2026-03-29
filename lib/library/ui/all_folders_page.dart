import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routing/app_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/connectivity_service.dart';
import '../logic/library_provider.dart';
import 'components/custom_search_bar.dart';
import 'components/folder_card.dart';
import 'components/file_tile.dart';
import 'components/library_report_dialog.dart';

/// All folders page showing complete folder grid
///
/// Features:
/// - Search bar for filtering folders
/// - Grid/List view toggle
/// - Total folder count
/// - Notification bell
/// - Full folder grid
class AllFoldersPage extends StatefulWidget {
  const AllFoldersPage({super.key});

  @override
  State<AllFoldersPage> createState() => _AllFoldersPageState();
}

class _AllFoldersPageState extends State<AllFoldersPage> {
  bool _isGridView = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load root contents if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LibraryProvider>(context, listen: false);
      provider.refreshOfflineFiles(notify: false);
      if (provider.rootFolders.isEmpty && !provider.isLoadingRoot) {
        provider.loadRootContents();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<LibraryProvider>(context);
    final isOnline = ConnectivityService.instance.isOnline;

    // Get all folders from provider and filter by search query
    final allFolders = provider.rootFolders;
    final filteredFolders = _searchQuery.isEmpty
        ? allFolders
        : allFolders.where((folder) {
            return folder.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
          }).toList();

    return Scaffold(
      appBar: _buildAppBar(context),
        body: provider.isLoadingRoot
          ? const Center(child: CircularProgressIndicator())
          : provider.hasError && !isOnline && allFolders.isEmpty
          ? _buildOfflineDownloadsState(theme, provider)
          : provider.hasError && allFolders.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.error ?? 'An error occurred',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => provider.refreshRootContents(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 16),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CustomSearchBar(
                    hintText: 'Search topics...',
                    onChanged: (query) {
                      setState(() {
                        _searchQuery = query;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Folder count and view toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total ${filteredFolders.length} folders',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? AppColors.sectionHeaderGray
                              : theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.grid_view,
                              color: _isGridView
                                  ? theme.colorScheme.primary
                                  : theme.iconTheme.color?.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                            onPressed: () {
                              setState(() {
                                _isGridView = true;
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.view_list,
                              color: !_isGridView
                                  ? theme.colorScheme.primary
                                  : theme.iconTheme.color?.withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                            onPressed: () {
                              setState(() {
                                _isGridView = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Folders grid/list
                Expanded(
                  child: filteredFolders.isEmpty
                      ? _buildEmptyState(theme)
                      : _isGridView
                      ? _buildGridView(filteredFolders)
                      : _buildListView(filteredFolders),
                ),
              ],
            ),
    );
  }

  /// Build custom app bar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            iconSize: 20,
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: Text(
        'All Folders',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
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

  /// Build grid view of folders (2 columns)
  Widget _buildGridView(List folders) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: folders.length,
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
          onMorePressed: () {
            // TODO: Show folder options
          },
        );
      },
    );
  }

  /// Build list view of folders (1 column vertical FolderCard list)
  Widget _buildListView(List folders) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FolderCard(
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
            onMorePressed: () {
              // TODO: Show folder options
            },
          ),
        );
      },
    );
  }

  /// Build empty state
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: theme.brightness == Brightness.dark
                  ? AppColors.sectionHeaderGray
                  : theme.iconTheme.color?.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No folders found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? AppColors.sectionHeaderGray
                    : theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineDownloadsState(
    ThemeData theme,
    LibraryProvider provider,
  ) {
    final offlineFiles = provider.offlineFiles;
    final isDark = theme.brightness == Brightness.dark;

    if (offlineFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No downloaded content available offline.',
                style: theme.textTheme.titleMedium,
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '${offlineFiles.length} downloaded files on this device',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: offlineFiles.length,
            itemBuilder: (context, index) {
              final file = offlineFiles[index];
              final fileType = _inferFileType(file.fileName);
              return FileTile(
                fileId: file.fileId,
                fileName: file.fileName,
                fileType: fileType,
                fileSize: _formatFileSize(file.sizeBytes),
                lastModified: 'Downloaded ${_formatDownloadedDate(file.downloadedAt)}',
                onTap: () {
                  AppRouter.goToFileViewer(
                    context,
                    fileId: file.fileId,
                    fileName: file.fileName,
                    fileType: fileType,
                    fileSizeBytes: file.sizeBytes,
                  );
                },
              );
            },
          ),
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
}
