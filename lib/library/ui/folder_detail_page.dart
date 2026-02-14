import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routing/app_router.dart';
import '../../auth/logic/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/settings_dialog.dart';
import '../logic/library_provider.dart';
import 'components/folder_card.dart';
import 'components/file_tile.dart';

/// Folder detail page showing subfolders and files
/// 
/// Features:
/// - Back navigation
/// - Breadcrumb navigation
/// - Subfolders grid
/// - Files list with view toggle
/// - Bottom navigation
class FolderDetailPage extends StatefulWidget {
  final String folderId;
  final String folderName;
  final List<String>? breadcrumbs;

  const FolderDetailPage({
    super.key,
    required this.folderId,
    required this.folderName,
    this.breadcrumbs,
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> with WidgetsBindingObserver {
  bool _isGridView = false;
  bool _hasLoadedInitially = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load folder contents on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFolderContents();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload when app comes to foreground
    if (state == AppLifecycleState.resumed && _hasLoadedInitially) {
      _loadFolderContents();
    }
  }

  void _loadFolderContents() {
    final provider = Provider.of<LibraryProvider>(context, listen: false);
    provider.loadFolderContents(widget.folderId);
    _hasLoadedInitially = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SizedBox.expand(
        child: Stack(
          children: [
            _buildFolderContent(),
            // Floating Navbar at Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppBottomNavBar(
                currentPage: 'library',
                isAuthenticated: Provider.of<AuthProvider>(context, listen: false).isAuthenticated,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build custom app bar with back button
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
        widget.folderName,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
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
        const SizedBox(width: 4),
      ],
    );
  }

  /// Build folder content view
  Widget _buildFolderContent() {
    final provider = Provider.of<LibraryProvider>(context);
    final subfolders = provider.currentSubfolders;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Breadcrumb navigation
          _buildBreadcrumbs(),
          
          const SizedBox(height: 24),
          
          // Loading indicator
          if (provider.isLoadingFolder)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          // Error state
          else if (provider.hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      provider.error ?? 'An error occurred',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => provider.refreshFolderContents(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          // Content
          else ...[
            // Subfolders section
            if (subfolders.isNotEmpty) ...[
              _buildSubfoldersSection(),
              const SizedBox(height: 24),
            ],
            
            // Files section
            _buildFilesSection(),
            
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  /// Build breadcrumb navigation
  Widget _buildBreadcrumbs() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final breadcrumbs = widget.breadcrumbs ?? ['Library'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (int i = 0; i < breadcrumbs.length; i++) ...[
            _BreadcrumbChip(
              label: breadcrumbs[i],
              isActive: i == breadcrumbs.length - 1,
              isDark: isDark,
              onTap: () {
                // TODO: Navigate to breadcrumb level
              },
            ),
            if (i < breadcrumbs.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isDark ? AppColors.sectionHeaderGray : theme.textTheme.bodySmall?.color,
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: isDark ? AppColors.sectionHeaderGray : theme.textTheme.bodySmall?.color,
            ),
          ),
          _BreadcrumbChip(
            label: widget.folderName,
            isActive: true,
            isDark: isDark,
            onTap: null,
          ),
        ],
      ),
    );
  }

  /// Build subfolders section
  Widget _buildSubfoldersSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<LibraryProvider>(context);
    final subfolders = provider.currentSubfolders;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SUBFOLDERS',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '${subfolders.length} Folders',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: subfolders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final folder = subfolders[index];
            return FolderCard(
              folderId: folder.id,
              folderName: folder.name,              description: folder.description,              itemCount: folder.itemCount,
              onTap: () async {
                // Navigate to nested folder
                final newBreadcrumbs = [
                  ...(widget.breadcrumbs ?? ['Library']),
                  widget.folderName,
                ];
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FolderDetailPage(
                      folderId: folder.id,
                      folderName: folder.name,
                      breadcrumbs: newBreadcrumbs,
                    ),
                  ),
                );
                // Reload folder contents when returning from subfolder
                _loadFolderContents();
              },
            );
          },
        ),
      ],
    );
  }

  /// Build files section
  Widget _buildFilesSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<LibraryProvider>(context);
    final files = provider.currentFiles;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FILES',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {
                      // TODO: Show filter options
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isGridView ? Icons.view_list : Icons.grid_view,
                    ),
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (files.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No files in this folder',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return FileTile(
                    fileId: file.id,
                    fileName: file.title,
                    fileType: file.fileType?.toUpperCase() ?? 'UNKNOWN',
                    fileSize: file.formattedSize,
                    lastModified: _formatDate(file.createdAt),
                    onTap: () async {
                      // Record view and navigate to file viewer
                      await provider.recordFileView(file.id);
                      
                      if (!mounted) return;
                      AppRouter.goToFileViewer(
                        context,
                        fileId: file.id,
                        fileName: file.title,
                        fileType: file.fileType ?? 'unknown',
                        fileSizeBytes: file.sizeBytes,
                        description: file.description,
                      );
                    },
                    onMorePressed: () {
                      // TODO: Show file options
                    },
                  );
                },
              ),
              if (provider.hasMoreFiles)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TextButton(
                    onPressed: provider.isLoadingMoreFiles
                        ? null
                        : () => provider.loadMoreFiles(),
                    child: provider.isLoadingMoreFiles
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load more'),
                  ),
                ),
            ],
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

/// Breadcrumb chip component
class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback? onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.isActive,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppColors.goldAccent.withOpacity(0.2) : theme.colorScheme.primary.withOpacity(0.1))
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: AppColors.goldAccent, width: 1)
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isActive
                ? AppColors.goldAccent
                : (isDark ? AppColors.sectionHeaderGray : theme.textTheme.bodyMedium?.color),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
