import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routing/app_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/theme_provider.dart';
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

  // TODO: Fetch all folders from Supabase
  // Replace with: supabase.from('folders').select().order('name')
  final List<Map<String, dynamic>> _mockAllFolders = [
    {'id': '1', 'name': 'Science & Tech', 'itemCount': 12},
    {'id': '2', 'name': 'History', 'itemCount': 8},
    {'id': '3', 'name': 'Arts & Crafts', 'itemCount': 24},
    {'id': '4', 'name': 'Field Guides', 'itemCount': 5},
    {'id': '5', 'name': 'Leadership', 'itemCount': 10},
    {'id': '6', 'name': 'Camping', 'itemCount': 15},
    {'id': '7', 'name': 'Knots', 'itemCount': 7},
    {'id': '8', 'name': 'First Aid', 'itemCount': 3},
    {'id': '9', 'name': 'Navigation', 'itemCount': 6},
    {'id': '10', 'name': 'Cooking', 'itemCount': 9},
    {'id': '11', 'name': 'Sports', 'itemCount': 11},
    {'id': '12', 'name': 'Music & Songs', 'itemCount': 14},
  ];

  List<Map<String, dynamic>> get _filteredFolders {
    if (_searchQuery.isEmpty) {
      return _mockAllFolders;
    }
    return _mockAllFolders.where((folder) {
      return folder['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
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
                  'Total ${_filteredFolders.length} folders',
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
            child: _isGridView ? _buildGridView() : _buildListView(),
          ),
        ],
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
          Navigator.pop(context);
        },
      ),
      title: const Text(
        'All Folders',
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

  /// Build grid view of folders
  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: _filteredFolders.length,
      itemBuilder: (context, index) {
        final folder = _filteredFolders[index];
        return FolderCard(
          folderId: folder['id'],
          folderName: folder['name'],
          itemCount: folder['itemCount'],
          onTap: () {
            AppRouter.goToFolder(
              context,
              folderId: folder['id'],
              folderName: folder['name'],
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
  Widget _buildListView() {
    final theme = Theme.of(context);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFolders.length,
      itemBuilder: (context, index) {
        final folder = _filteredFolders[index];
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
              folder['name'],
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${folder['itemCount']} ${folder['itemCount'] == 1 ? 'item' : 'items'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () {
                // TODO: Show folder options
              },
            ),
            onTap: () {
              AppRouter.goToFolder(
                context,
                folderId: folder['id'],
                folderName: folder['name'],
              );
            },
          ),
        );
      },
    );
  }
}
