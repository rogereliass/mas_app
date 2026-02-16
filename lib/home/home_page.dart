import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/logic/auth_provider.dart';
import '../core/widgets/app_bottom_nav_bar.dart';
import '../core/widgets/settings_dialog.dart';
import '../routing/app_router.dart';
import 'components/components.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    // Auth guard: redirect to startup if not authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      debugPrint('🏠 HomePage initState - Auth check...');
      debugPrint('   isAuthenticated: ${authProvider.isAuthenticated}');
      debugPrint('   User: ${authProvider.fullName}');
      
      if (!authProvider.isAuthenticated) {
        debugPrint('❌ User not authenticated, redirecting to startup...');
        // User not authenticated, redirect to startup page
        Navigator.of(context).pushReplacementNamed(AppRouter.startup);
        return;
      }
      
      debugPrint('🏠 HomePage initState - Roles count: ${authProvider.userRoles.length}');
      if (authProvider.userRoles.isNotEmpty) {
        debugPrint('🏠 Roles available: ${authProvider.userRoles.map((r) => r.name).join(', ')}');
        if (_selectedRole == null) {
          setState(() {
            _selectedRole = authProvider.userRoles.first.name;
          });
          debugPrint('🏠 Set initial role to: $_selectedRole');
        }
      } else {
        debugPrint('⚠️ No roles found for user');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final userRoles = authProvider.userRoles;

    // Detailed debug logging
    debugPrint('🏠 ============ HomePage Build ============');
    debugPrint('   Current User ID: ${authProvider.userId}');
    debugPrint('   Full Name: ${authProvider.fullName}');
    debugPrint('   Profile Loading: ${authProvider.profileLoading}');
    debugPrint('   Roles Count: ${userRoles.length}');
    debugPrint('   Selected Role: $_selectedRole');
    if (userRoles.isNotEmpty) {
      debugPrint('   Available Roles: ${userRoles.map((r) => r.name).join(', ')}');
    }
    debugPrint('🏠 ======================================');

    // Show loading state while profile is being fetched
    if (authProvider.profileLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading your profile...',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    // Set default role if not set and roles are available
    if (_selectedRole == null && userRoles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedRole = userRoles.first.name;
          });
          debugPrint('🏠 Auto-selected first role: ${userRoles.first.name}');
        }
      });
    }

    return Scaffold(
      // 1. Top App Bar (Header)
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        // Role Selector (Center)
        title: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: userRoles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'No Role',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRole,
                    icon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.arrow_drop_down, color: colorScheme.primary),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: theme.cardColor,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    items: userRoles.map((role) {
                      return DropdownMenuItem<String>(
                        value: role.name,
                        child: Text(role.name),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                        // Trigger refresh of content based on new role
                        _onRoleChanged(newValue);
                      }
                    },
                  ),
                ),
        ),
        actions: [
          // Debug: Manual reload button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Profile & Roles',
            onPressed: () async {
              debugPrint('🔄 Manual reload triggered from HomePage');
              final authProvider = Provider.of<AuthProvider>(context, listen: false);

              // Show loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reloading profile...'),
                  duration: Duration(seconds: 1),
                ),
              );

              await authProvider.refreshProfile();

              if (!context.mounted) return;

              debugPrint('✅ Manual reload complete');
              debugPrint('   Full Name after reload: ${authProvider.fullName}');
              debugPrint('   Profile: ${authProvider.currentUserProfile}');

              final name = authProvider.fullName ?? 'No name loaded';
              final roleCount = authProvider.userRoles.length;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Profile: $name\nRoles: $roleCount'),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
          // Settings Action
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _showSettingsDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),

      // 2. Main Content Area with Floating Navbar
      body: SizedBox.expand(
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    _buildWelcomeHeader(context, authProvider),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(context),
                    const SizedBox(height: 32),

                    // Summary / Stats
                    _buildSummaryStats(context),
                    const SizedBox(height: 32),

                    // // Recent Activity
                    // _buildRecentActivity(context),
                    
                    // Bottom padding to ensure content isn't hidden behind FAB or Nav bar if needed
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Floating Navbar at Bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const AppBottomNavBar(
                currentPage: 'home',
                isAuthenticated: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Contextual Welcome Header
  /// Changes based on the current user state and role
  Widget _buildWelcomeHeader(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Debug logging to trace the issue
    debugPrint('🔍 _buildWelcomeHeader DEBUG:');
    debugPrint('   currentUser: ${authProvider.currentUser?.id}');
    debugPrint('   currentUserProfile: ${authProvider.currentUserProfile}');
    debugPrint('   firstName: ${authProvider.currentUserProfile?.firstName}');
    debugPrint('   middleName: ${authProvider.currentUserProfile?.middleName}');
    debugPrint('   lastName: ${authProvider.currentUserProfile?.lastName}');
    debugPrint('   fullName getter: ${authProvider.fullName}');
    debugPrint('   userMetadata: ${authProvider.userMetadata}');

    final userName = authProvider.fullName ?? 'User';
    final currentRole = _selectedRole ?? 'No Role';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          userName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        // Role Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.badge_outlined,
                size: 16,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                currentRole,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Quick Actions / Shortcuts
  /// Grid or Row of frequently used actions
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TODO: Populate dynamically based on user permissions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickActionItem(
              icon: Icons.library_books_outlined,
              label: 'Library',
              onTap: () => Navigator.pushNamed(context, AppRouter.library),
            ),
            _QuickActionItem(
              icon: Icons.folder_open_outlined,
              label: 'Folders',
              onTap: () => Navigator.pushNamed(context, AppRouter.allFolders),
            ),
            _QuickActionItem(
              icon: Icons.download_done_outlined,
              label: 'Offline',
              onTap: () {
                // TODO: Navigate to offline files
              },
            ),
            _QuickActionItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () => Navigator.pushNamed(context, AppRouter.profile),
            ),
          ],
        ),
      ],
    );
  }

  /// Summary Cards or Statistics
  /// Displays key metrics relevant to the selected role
  Widget _buildSummaryStats(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roleRank = authProvider.currentUserRoleRank;
    
    // Show no role message if user has no roles assigned
    if (authProvider.userRoles.isEmpty || _selectedRole == null || _selectedRole == 'No Role') {
      return const NoRoleMessage();
    }
    
    // Show role-specific components based on role rank
    final selectedRoleRank = authProvider.getRankForRole(_selectedRole ?? '');
    
    // System Admins (rank 100) and Admins (rank 90-99) see the system dashboard
    if (selectedRoleRank >= 90) {
      return SystemAdminStats(selectedRole: _selectedRole ?? 'Admin');
    }
    
    // Troop Head (rank 70) and Troop Leader (rank 60) see troop dashboard
    if (selectedRoleRank >= 60 && selectedRoleRank < 90) {
      return TroopHeadStats(selectedRole: _selectedRole ?? 'Troop Head');
    }
    
    // Default stats for other roles
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Dynamic stats based on role rank
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Access Level: ${_getAccessLevelName(roleRank)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Your access level determines which content you can view and interact with in the app.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Dashboard Stats',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              // TODO: Connect to real data providers
              _buildStatRow(
                context,
                icon: Icons.folder_outlined,
                label: 'Accessible Folders',
                value: '...',
              ),
              const SizedBox(height: 8),
              _buildStatRow(
                context,
                icon: Icons.file_copy_outlined,
                label: 'Accessible Files',
                value: '...',
              ),
              const SizedBox(height: 8),
              _buildStatRow(
                context,
                icon: Icons.download_outlined,
                label: 'Downloaded',
                value: '...',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper to build stat row
  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Get human-readable access level name based on rank
  String _getAccessLevelName(int rank) {
    if (rank == 0) return 'Public';
    if (rank < 20) return 'Basic';
    if (rank < 40) return 'Member';
    if (rank < 60) return 'Advanced';
    if (rank < 80) return 'Senior';
    if (rank < 100) return 'Admin';
    return 'System Admin';
  }

  // /// Recent Activity Feed
  // /// Shows latest updates or accessed content
  // Widget _buildRecentActivity(BuildContext context) {
  //   final theme = Theme.of(context);

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Padding(
  //         padding: const EdgeInsets.only(bottom: 16),
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Text(
  //               'Recent Activity',
  //               style: theme.textTheme.titleLarge?.copyWith(
  //                 fontWeight: FontWeight.w600,
  //               ),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 // TODO: Navigate to full activity log
  //               },
  //               child: const Text('View All'),
  //             ),
  //           ],
  //         ),
  //       ),
  //       // TODO: Connect to recent activity stream/provider
  //       ListView.separated(
  //         shrinkWrap: true,
  //         physics: const NeverScrollableScrollPhysics(),
  //         itemCount: 3, // Placeholder count
  //         separatorBuilder: (context, index) => const Divider(height: 1),
  //         itemBuilder: (context, index) {
  //           return ListTile(
  //             contentPadding: EdgeInsets.zero,
  //             leading: CircleAvatar(
  //               backgroundColor: theme.colorScheme.secondaryContainer,
  //               child: Icon(
  //                 Icons.history,
  //                 color: theme.colorScheme.onSecondaryContainer,
  //                 size: 20,
  //               ),
  //             ),
  //             title: Text('Activity Item ${index + 1}'),
  //             subtitle: Text(
  //               'Description of action taken',
  //               style: theme.textTheme.bodySmall,
  //             ),
  //             trailing: Text(
  //               '2h ago',
  //               style: theme.textTheme.bodySmall,
  //             ),
  //             onTap: () {
  //               // TODO: Handle activity item tap
  //             },
  //           );
  //         },
  //       ),
  //     ],
  //   );
  // }

  /// Handle role change event
  void _onRoleChanged(String newRole) {
    // TODO: Implement role-specific data filtering/reloading
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to $newRole view'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show settings dialog
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
