import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/admin_scope_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../routing/app_router.dart';
import '../data/models/managed_user_profile.dart';
import '../logic/user_management_provider.dart';
import 'components/user_card.dart';
import 'components/user_edit_dialog.dart';

/// User Management Page
///
/// Allows system admins and troop-scoped leaders to update user profiles
class UserManagementPage extends StatefulWidget {
  final String? selectedRole;

  const UserManagementPage({super.key, this.selectedRole});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  UserManagementProvider? _userProvider;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String? _roleContext;
  int? _effectiveRank;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserManagementProvider>();
      _userProvider = userProvider;
      final colorScheme = Theme.of(context).colorScheme;

      // Extract and cache role context once
      _roleContext = widget.selectedRole;
      if (_roleContext == null) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        _roleContext = args?['selectedRole'] as String?;
      }

      if (_roleContext != null) {
        _effectiveRank = authProvider.getRankForRole(_roleContext!);
        userProvider.setRoleContext(_roleContext!);
      } else {
        _effectiveRank = authProvider.currentUserRoleRank;
        userProvider.clearRoleContext();
      }
      
      final effectiveRank = _effectiveRank!;

      final user = authProvider.currentUserProfile;

      if (effectiveRank < 60) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access Denied: Admin privileges required'),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }

      if (effectiveRank >= 60 && effectiveRank < 90) {
        if (user?.managedTroopId == null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Access Error: No troop assigned. Please contact an administrator.'),
              backgroundColor: colorScheme.tertiary,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      userProvider.loadUsers();
      userProvider.loadRoles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    // Don't call clearRoleContext() here - it triggers notifyListeners() during dispose
    // The role context will be cleared when needed (e.g., when navigating to the page again)
    super.dispose();
  }
  
  /// Debounced search handler to avoid filtering on every keystroke
  void _onSearchChanged(String query, UserManagementProvider provider) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      provider.setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          Consumer<UserManagementProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: provider.isLoadingUsers ? null : () => provider.refresh(),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          AdminScopeBanner(selectedRoleName: _roleContext),
          _buildSearchAndFilters(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await context.read<UserManagementProvider>().refresh();
              },
              child: Consumer<UserManagementProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingUsers) {
                    return const LoadingView(message: 'Loading users...');
                  }

                  if (provider.hasError) {
                    return ErrorView(
                      message: provider.error ?? 'Unknown error occurred',
                      onRetry: () => provider.loadUsers(),
                    );
                  }

                  if (provider.users.isEmpty) {
                    return _buildEmptyState(context, provider, isInitialState: true);
                  }
                  
                  final filteredUsers = provider.filteredUsers;
                  
                  if (filteredUsers.isEmpty) {
                    return _buildEmptyState(context, provider, isInitialState: false);
                  }

                  return Column(
                    children: [
                      _buildUserCountBadge(provider.filteredUsers.length, provider.users.length, theme),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return UserCard(
                              key: ValueKey(user.id),
                              profile: user,
                              onEdit: () => _showEditDialog(context, user),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build search bar and filter dropdowns
  Widget _buildSearchAndFilters(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final provider = context.watch<UserManagementProvider>();
    // Use effective rank (accounts for role context)
    final effectiveRank = _effectiveRank ?? authProvider.currentUserRoleRank;
    final isSystemAdmin = effectiveRank >= 90;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerLow,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (query) => _onSearchChanged(query, provider),
            decoration: InputDecoration(
              hintText: 'Search by name, phone number, or scout code...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 22,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.brightness == Brightness.light
                  ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : AppColors.cardDark.withOpacity(0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Filter dropdowns - responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              // Use vertical layout for narrow screens
              final useVerticalLayout = constraints.maxWidth < 500;
              
                if (useVerticalLayout) {
                return Column(
                  children: [
                    _buildRoleFilter(theme, provider, constraints.maxWidth),
                    if (isSystemAdmin) ...[
                      const SizedBox(height: 12),
                      _buildTroopFilter(theme, provider, constraints.maxWidth),
                    ],
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: _buildRoleFilter(theme, provider, constraints.maxWidth / 2),
                    ),
                    const SizedBox(width: 12),
                    if (isSystemAdmin)
                      Expanded(
                        child: _buildTroopFilter(theme, provider, constraints.maxWidth / 2),
                      ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
  
  /// Build role filter dropdown
  Widget _buildRoleFilter(ThemeData theme, UserManagementProvider provider, double availableWidth) {
    // Adjust UI based on available width
    final isNarrow = availableWidth < 250;
    final contentPadding = isNarrow 
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    
    // Get effective user rank (accounts for role context)
    final authProvider = context.read<AuthProvider>();
    final effectiveRank = _effectiveRank ?? authProvider.currentUserRoleRank;
    final isTroopLeader = effectiveRank >= 60 && effectiveRank < 90;
    
    // Filter roles based on effective user rank
    // Troop leaders (60-89) can only see/assign roles with rank 1-40
    // System admins (90+) can see all roles
    final availableRoles = isTroopLeader
        ? provider.roles.where((role) => role.rank > 0 && role.rank <= 40).toList()
        : provider.roles;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonFormField<String?>(
        value: provider.selectedRoleFilter,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: isNarrow ? null : 'Filter by Role',
          hintText: isNarrow ? 'Role' : null,
          labelStyle: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            Icons.admin_panel_settings_rounded,
            size: 20,
            color: theme.colorScheme.primary.withOpacity(0.8),
          ),
          filled: true,
          fillColor: theme.brightness == Brightness.light
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.4)
              : AppColors.cardDark.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          contentPadding: contentPadding,
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Row(
              children: [
                Icon(
                  Icons.all_inclusive,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'All Roles',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ...availableRoles.map((role) {
            return DropdownMenuItem<String>(
              value: role.id,
              child: Text(
                role.name,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (value) => provider.setRoleFilter(value),
      ),
    );
  }
  
  /// Build troop filter dropdown
  Widget _buildTroopFilter(ThemeData theme, UserManagementProvider provider, double availableWidth) {
    final troops = provider.availableTroops;
    
    // Adjust UI based on available width
    final isNarrow = availableWidth < 250;
    final contentPadding = isNarrow 
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonFormField<String?>(
        value: provider.selectedTroopFilter,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: isNarrow ? null : 'Filter by Troop',
          hintText: isNarrow ? 'Troop' : null,
          labelStyle: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(
            Icons.groups_rounded,
            size: 20,
            color: theme.colorScheme.primary.withOpacity(0.8),
          ),
          filled: true,
          fillColor: theme.brightness == Brightness.light
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.4)
              : AppColors.cardDark.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          contentPadding: contentPadding,
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Row(
              children: [
                Icon(
                  Icons.all_inclusive,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'All Troops',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ...troops.map((troop) {
            return DropdownMenuItem<String>(
              value: troop['id'],
              child: Text(
                troop['name']!,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (value) => provider.setTroopFilter(value),
      ),
    );
  }
  
  /// Build user count badge showing filtered/total users
  Widget _buildUserCountBadge(int filteredCount, int totalCount, ThemeData theme) {
    final isFiltered = filteredCount < totalCount;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isFiltered 
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFiltered ? Icons.filter_alt : Icons.group,
                  size: 16,
                  color: isFiltered 
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  isFiltered 
                      ? 'Showing $filteredCount of $totalCount users'
                      : '$totalCount users',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isFiltered 
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                context.read<UserManagementProvider>().clearFilters();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, ManagedUserProfile profile) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => UserEditDialog(profile: profile),
    );
  }

  /// Build context-aware empty state
  /// 
  /// Shows different messages and CTAs based on whether the empty state is due to
  /// no users existing (initial state) or active filters returning no results
  Widget _buildEmptyState(BuildContext context, UserManagementProvider provider, {required bool isInitialState}) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final hasAdminPermission = authProvider.currentUserRoleRank >= 60;
    
    // Check if any filters are active
    final hasActiveFilters = provider.searchQuery.isNotEmpty ||
        provider.selectedRoleFilter != null ||
        provider.selectedTroopFilter != null;

    if (isInitialState && !hasActiveFilters) {
      // A) No Users Exist (Initial State)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 100,
              ),
              const SizedBox(height: 24),
              Text(
                'No users in your troop yet',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'New user registrations will appear here once they\'ve been approved.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasAdminPermission) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRouter.userAcceptance);
                  },
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('View Pending Approvals'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      // B) Filters Active But No Results
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.filter_alt_off,
                size: 100,
              ),
              const SizedBox(height: 24),
              Text(
                'No users match your filters',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Try adjusting your search or filter criteria',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  _searchController.clear();
                  provider.clearFilters();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
