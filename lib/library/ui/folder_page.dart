import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routing/app_router.dart';
import '../../core/config/theme_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../auth/logic/auth_provider.dart';
import '../../core/widgets/app_bottom_nav_bar.dart';
import '../../core/widgets/settings_dialog.dart';
import '../logic/library_provider.dart';
import 'components/custom_search_bar.dart';
import 'components/folder_card.dart';
import 'components/file_tile.dart';

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
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    // Load root contents on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LibraryProvider>(context, listen: false);
      provider.loadRootContents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildLibraryContent(),
      bottomNavigationBar: AppBottomNavBar(
        currentPage: 'library',
        isAuthenticated: authProvider.isAuthenticated,
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
              color: Colors.white
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
          
          const SizedBox(height: 24),
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
                  color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (!provider.isLoadingRoot && folders.isNotEmpty)
                Text(
                  '${folders.length} Folders',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
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
        else if (provider.hasError)
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
                  color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: folders.length > 5 ? 5 : folders.length,
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
              if (folders.length > 5)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRouter.allFolders);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: BorderSide(
                        color: isDark ? AppColors.goldAccent : theme.colorScheme.primary,
                      ),
                    ),
                    child: Text(
                      'View All Folders',
                      style: TextStyle(
                        color: isDark ? AppColors.goldAccent : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
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
                  color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              // "New" Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.goldAccent.withOpacity(0.5)),
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
                  color: isDark ? AppColors.sectionHeaderGray : Colors.grey[600],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 180, // Reduced height for more square aspect ratio
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Added vertical padding for shadows
              itemCount: files.length,
              separatorBuilder: (context, index) => const SizedBox(width: 20), // Increased spacing between cards
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
                    
                    if (!mounted) return;
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

