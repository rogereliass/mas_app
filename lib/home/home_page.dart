import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/logic/auth_provider.dart';
import '../core/widgets/app_bottom_nav_bar.dart';
import '../routing/app_router.dart';

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
    // Set initial role after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userRoles.isNotEmpty && _selectedRole == null) {
        setState(() {
          _selectedRole = authProvider.userRoles.first.name;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final userRoles = authProvider.userRoles;

    // Set default role if not set and roles are available
    if (_selectedRole == null && userRoles.isNotEmpty) {
      _selectedRole = userRoles.first.name;
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(role.name),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Rank ${role.rank}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
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
          // Settings Action
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              // TODO: Navigate to settings page
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      // 2. Main Content Area
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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

                // Recent Activity
                _buildRecentActivity(context),
                
                // Bottom padding to ensure content isn't hidden behind FAB or Nav bar if needed
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),

      // 3. Bottom Navigation Bar
      bottomNavigationBar: const AppBottomNavBar(
        currentIndex: 0,
        // TODO: Verify active tab index matches AppRouter logic
      ),
    );
  }

  /// Contextual Welcome Header
  /// Changes based on the current user state and role
  Widget _buildWelcomeHeader(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userName = authProvider.fullName ?? 'User';
    final currentRole = _selectedRole ?? 'No Role';
    final roleRank = authProvider.currentUserRoleRank;

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
        // Role and Rank Badge
        Row(
          children: [
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_outline,
                    size: 16,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rank $roleRank',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              onTap: () {
                // TODO: Navigate to profile
              },
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
                'You can access content up to rank $roleRank',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              // Progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: roleRank / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  minHeight: 8,
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

  /// Recent Activity Feed
  /// Shows latest updates or accessed content
  Widget _buildRecentActivity(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full activity log
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        // TODO: Connect to recent activity stream/provider
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3, // Placeholder count
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(
                  Icons.history,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 20,
                ),
              ),
              title: Text('Activity Item ${index + 1}'),
              subtitle: Text(
                'Description of action taken',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Text(
                '2h ago',
                style: theme.textTheme.bodySmall,
              ),
              onTap: () {
                // TODO: Handle activity item tap
              },
            );
          },
        ),
      ],
    );
  }

  /// Handles pull-to-refresh action
  Future<void> _refreshData() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshProfile();
    // TODO: Add other data refreshes here (Stats, Activities, etc.)
    await Future.delayed(const Duration(milliseconds: 500));
  }

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
