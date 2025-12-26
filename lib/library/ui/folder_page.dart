import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routing/app_router.dart';
import '../../core/config/theme_provider.dart';
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

  // TODO: Fetch folders from Supabase
  // Replace with actual API call: supabase.from('folders').select()
  final List<Map<String, dynamic>> _mockFolders = [
    {'id': '1', 'name': 'المناهج الكشفية', 'name_en': 'Scout Programs', 'itemCount': 12},
    {'id': '2', 'name': 'الصور والوسائط', 'name_en': 'Photos & Media', 'itemCount': 45},
    {'id': '3', 'name': 'الشارات والأوسمة', 'name_en': 'Badges & Awards', 'itemCount': 8},
    {'id': '4', 'name': 'التقارير السنوية', 'name_en': 'Annual Reports', 'itemCount': 3},
  ];

  // TODO: Fetch recent files from Supabase
  // Replace with actual API call: supabase.from('files').select().order('created_at', desc: true).limit(10)
  final List<Map<String, dynamic>> _mockRecentFiles = [
    {
      'id': '1',
      'name': 'دليل القائد للكشافة.pdf',
      'type': 'PDF',
      'size': '2.4 MB',
      'date': '2 days ago',
    },
    {
      'id': '2',
      'name': 'فيديو تدريبي - رحلات الجبال.mp4',
      'type': 'MP4',
      'size': '15.8 MB',
      'date': 'Nov 24',
    },
    {
      'id': '3',
      'name': 'شعار المعسكر الصيفي.png',
      'type': 'PNG',
      'size': '450 KB',
      'date': 'Nov 20',
    },
    {
      'id': '4',
      'name': 'تقرير الفعاليات.docx',
      'type': 'DOCX',
      'size': '1.2 MB',
      'date': 'Nov 18',
    },
  ];

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
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _mockFolders.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final folder = _mockFolders[index];
              return SizedBox(
                width: 180,
                child: FolderCard(
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _mockRecentFiles.length,
          itemBuilder: (context, index) {
            final file = _mockRecentFiles[index];
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

  /// Build about content
  Widget _buildAboutContent() {
    return const AboutContent();
  }
}

