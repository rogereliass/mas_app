import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routing/app_router.dart';
import '../../core/config/theme_provider.dart';
import '../logic/library_provider.dart';
import 'components/custom_search_bar.dart';
import 'components/filter_chip_row.dart';
import 'components/folder_card.dart';
import 'components/file_tile.dart';
import 'components/bottom_nav_bar.dart';
import 'about_page.dart';

/// Library home page - main entry point for browsing content
/// 
/// Features:
/// - Search bar for resources
/// - Category filters (All, Scouts, Guides, Cubs)
/// - Folders section with grid view
/// - Recent files section with list view
/// - Bottom navigation
class LibraryHomePage extends StatefulWidget {
  const LibraryHomePage({super.key});

  @override
  State<LibraryHomePage> createState() => _LibraryHomePageState();
}

class _LibraryHomePageState extends State<LibraryHomePage> {
  String _selectedCategory = 'All';
  int _currentNavIndex = 0;

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
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _currentNavIndex == 0 
          ? _buildLibraryContent()
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

  /// Build custom app bar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.startup,
            (route) => false,
          );
        },
      ),
      title: const Text(
        'Digital Library',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
          ),
          onPressed: () {
            themeProvider.toggleTheme();
          },
          tooltip: isDark ? 'Light Mode' : 'Dark Mode',
        ),
      ],
    );
  }

  /// Build library content view
  Widget _buildLibraryContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomSearchBar(
              hintText: 'Search resources...',
              onTap: () {
                // TODO: Navigate to search screen or expand search
              },
              readOnly: true,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Filter chips
          FilterChipRow(
            categories: const ['All', 'Scouts', 'Guides', 'Cubs'],
            selectedCategory: _selectedCategory,
            onCategorySelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
              // TODO: Filter content based on selected category
            },
          ),
          
          const SizedBox(height: 24),
          
          // Folders section
          _buildFoldersSection(),
          
          const SizedBox(height: 24),
          
          // Recent files section
          _buildRecentFilesSection(),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build folders section with grid
  Widget _buildFoldersSection() {
    final theme = Theme.of(context);
    final provider = Provider.of<LibraryProvider>(context);
    final folders = provider.rootFolders;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folders',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (folders.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRouter.allFolders);
                  },
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (provider.isLoadingRoot)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (provider.hasError)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
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
        else if (folders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No folders found',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: folders.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final folder = folders[index];
                return SizedBox(
                  width: 180,
                  child: FolderCard(
                    folderId: folder.id,
                    folderName: folder.name,
                    itemCount: folder.itemCount,
                    onTap: () {
                      AppRouter.goToFolder(
                        context,
                        folderId: folder.id,
                        folderName: folder.name,
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Build recent files section with list
  Widget _buildRecentFilesSection() {
    final theme = Theme.of(context);
    final provider = Provider.of<LibraryProvider>(context);
    final files = provider.recentFiles;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Files',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  // TODO: Show filter options
                },
              ),
            ],
          ),
        ),
        if (provider.isLoadingRoot)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (files.isEmpty && !provider.hasError)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No recent files',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return FileTile(
                fileId: file.id,
                fileName: file.title,
                fileType: file.fileType.toUpperCase(),
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
                    fileType: file.fileType,
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

  /// Build about content
  Widget _buildAboutContent() {
    return const AboutContent();
  }
}

