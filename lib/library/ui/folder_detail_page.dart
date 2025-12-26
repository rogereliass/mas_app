import 'package:flutter/material.dart';
import 'components/folder_card.dart';
import 'components/file_tile.dart';
import 'components/bottom_nav_bar.dart';

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

class _FolderDetailPageState extends State<FolderDetailPage> {
  bool _isGridView = false;
  int _currentNavIndex = 0;

  // TODO: Fetch subfolders from Supabase based on parent folderId
  // Replace with: supabase.from('folders').select().eq('parent_id', widget.folderId)
  final List<Map<String, dynamic>> _mockSubfolders = [
    {'id': 's1', 'name': 'Photos & Media', 'name_ar': 'الصور والوسائط', 'itemCount': 45},
    {'id': 's2', 'name': 'Daily Reports', 'name_ar': 'التقارير اليومية', 'itemCount': 12},
    {'id': 's3', 'name': 'Maps & Guides', 'name_ar': 'الخرائط والأدلة', 'itemCount': 8},
  ];

  // TODO: Fetch files from Supabase based on folderId
  // Replace with: supabase.from('files').select().eq('folder_id', widget.folderId)
  final List<Map<String, dynamic>> _mockFiles = [
    {
      'id': 'f1',
      'name': 'General Scout Rules',
      'type': 'PDF',
      'size': '2.4 MB',
      'date': 'Mar 12, 2023',
    },
    {
      'id': 'f2',
      'name': 'Opening Ceremony - Video',
      'type': 'MP4',
      'size': '145 MB',
      'date': 'Mar 10, 2023',
    },
    {
      'id': 'f3',
      'name': 'Team Group Photo',
      'type': 'JPG',
      'size': '4.2 MB',
      'date': 'Mar 09, 2023',
    },
    {
      'id': 'f4',
      'name': 'Camp Location Coords',
      'type': 'KML',
      'size': '18 KB',
      'date': 'Mar 08, 2023',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _currentNavIndex == 0
          ? _buildFolderContent()
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

  /// Build custom app bar with back button
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.folderName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/images/mas_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image,
                  color: theme.colorScheme.primary,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Build folder content view
  Widget _buildFolderContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Breadcrumb navigation
          _buildBreadcrumbs(),
          
          const SizedBox(height: 24),
          
          // Subfolders section
          if (_mockSubfolders.isNotEmpty) ...[
            _buildSubfoldersSection(),
            const SizedBox(height: 24),
          ],
          
          // Files section
          _buildFilesSection(),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Build breadcrumb navigation
  Widget _buildBreadcrumbs() {
    final theme = Theme.of(context);
    final breadcrumbs = widget.breadcrumbs ?? ['Library', 'Events'];
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < breadcrumbs.length; i++) ...[
            _BreadcrumbChip(
              label: breadcrumbs[i],
              isActive: i == breadcrumbs.length - 1,
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
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          _BreadcrumbChip(
            label: widget.folderName,
            isActive: true,
            onTap: null,
          ),
        ],
      ),
    );
  }

  /// Build subfolders section
  Widget _buildSubfoldersSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subfolders',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Show all subfolders
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _mockSubfolders.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final folder = _mockSubfolders[index];
              return SizedBox(
                width: 180,
                child: FolderCard(
                  folderId: folder['id'],
                  folderName: folder['name'],
                  itemCount: folder['itemCount'],
                  onTap: () {
                    // Navigate to nested folder
                    final newBreadcrumbs = [
                      ...(widget.breadcrumbs ?? ['Library', 'Events']),
                      widget.folderName,
                    ];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FolderDetailPage(
                          folderId: folder['id'],
                          folderName: folder['name'],
                          breadcrumbs: newBreadcrumbs,
                        ),
                      ),
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

  /// Build files section
  Widget _buildFilesSection() {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Files',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _mockFiles.length,
          itemBuilder: (context, index) {
            final file = _mockFiles[index];
            return FileTile(
              fileId: file['id'],
              fileName: file['name'],
              fileType: file['type'],
              fileSize: file['size'],
              lastModified: file['date'],
              onTap: () {
                // TODO: Open file viewer
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

  /// Build about content placeholder
  Widget _buildAboutContent() {
    return Center(
      child: Text('About screen'),
    );
  }
}

/// Breadcrumb chip component
class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.isActive,
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
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isActive
                ? Colors.white
                : theme.textTheme.bodyMedium?.color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
