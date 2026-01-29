import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routing/app_router.dart';
import '../../core/constants/app_colors.dart';
import '../logic/library_provider.dart';
import 'components/custom_search_bar.dart';
import 'components/folder_card.dart';

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
      if (provider.rootFolders.isEmpty && !provider.isLoadingRoot) {
        provider.loadRootContents();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<LibraryProvider>(context);
    
    // Get all folders from provider and filter by search query
    final allFolders = provider.rootFolders;
    final filteredFolders = _searchQuery.isEmpty
        ? allFolders
        : allFolders.where((folder) {
            return folder.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    
    return Scaffold(
      appBar: _buildAppBar(context),
      body: provider.isLoadingRoot
          ? const Center(child: CircularProgressIndicator())
          : provider.hasError
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total ${filteredFolders.length} folders',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.grid_view,
                                  color: _isGridView 
                                      ? theme.colorScheme.primary 
                                      : theme.iconTheme.color?.withOpacity(0.6),
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
                                      : theme.iconTheme.color?.withOpacity(0.6),
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
                      child: _isGridView 
                          ? _buildGridView(filteredFolders) 
                          : _buildListView(filteredFolders),
                    ),
                  ],
                ),
    );
  }

  /// Build custom app bar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'All Folders',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Build grid view of folders
  Widget _buildGridView(List folders) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
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

  /// Build list view of folders
  Widget _buildListView(List folders) {
    final theme = Theme.of(context);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppColors.folderBackgroundDark
                    : AppColors.folderBackgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder,
                color: AppColors.folderIconColor,
                size: 24,
              ),
            ),
            title: Text(
              folder.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () {
                // TODO-OPTIONAL: Show folder options, three dots action 
              },
            ),
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
    );
  }
}
