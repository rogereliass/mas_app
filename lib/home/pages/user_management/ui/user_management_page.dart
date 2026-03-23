import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/models/role.dart';
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
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  UserManagementProvider? _userProvider;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  String? _roleContext;
  int? _effectiveRank;
  String _lastSubmittedQuery = '';
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final userProvider = context.read<UserManagementProvider>();
      _userProvider = userProvider;
      final colorScheme = Theme.of(context).colorScheme;

      // Extract and cache role context from global app state.
      _roleContext = authProvider.selectedRoleName;

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
              content: const Text(
                'Access Error: No troop assigned. Please contact an administrator.',
              ),
              backgroundColor: colorScheme.tertiary,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      userProvider.loadUsers();
      userProvider.loadRoles();

      // Error listener for paging/refresh errors
      userProvider.addListener(_errorHandler);
    });
  }

  void _errorHandler() {
    if (!mounted || _userProvider == null) return;

    if (_userProvider!.hasError && _userProvider!.users.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_userProvider!.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _userProvider!.loadMoreUsers(),
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<UserManagementProvider>().loadMoreUsers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    // Don't call clearRoleContext() here - it triggers notifyListeners() during dispose
    // The role context will be cleared when needed (e.g., when navigating to the page again)
    super.dispose();
  }

  /// Debounced search handler to avoid filtering on every keystroke
  void _onSearchChanged(String query, UserManagementProvider provider) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      final normalized = query.trim();
      if (_lastSubmittedQuery == normalized) return;
      _lastSubmittedQuery = normalized;
      provider.setSearchQuery(normalized);
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
                onPressed: provider.isLoadingUsers
                    ? null
                    : () => provider.refresh(forceRefresh: true),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const AdminScopeBanner(),
          _buildSearchAndFilters(context),
          Expanded(
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
                  return _buildEmptyState(
                    context,
                    provider,
                    isInitialState: true,
                  );
                }

                final filteredUsers = provider.filteredUsers;

                if (filteredUsers.isEmpty) {
                  return _buildEmptyState(
                    context,
                    provider,
                    isInitialState: false,
                  );
                }

                return Column(
                  children: [
                    _buildUserCountBadge(
                      provider.filteredUsers.length,
                      provider.users.length,
                      theme,
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            filteredUsers.length +
                            (provider.hasMoreUsers ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filteredUsers.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

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
        ],
      ),
    );
  }

  /// Build search bar and filter dropdowns
  Widget _buildSearchAndFilters(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final provider = context.watch<UserManagementProvider>();
    final effectiveRank = _effectiveRank ?? authProvider.currentUserRoleRank;
    final isSystemAdmin = effectiveRank >= 90;

    return Container(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;

          final searchField = TextField(
            controller: _searchController,
            onChanged: (value) => _onSearchChanged(value, provider),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Search by name or email...',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        _lastSubmittedQuery = '';
                        provider.setSearchQuery('');
                        setState(() {});
                      },
                    ),
            ),
          );

          final roleFilter = _buildRoleFilter(theme, provider, constraints.maxWidth);
          final troopFilter = _buildTroopFilter(theme, provider, constraints.maxWidth);

          if (compact) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 12),
                roleFilter,
                if (isSystemAdmin) ...[
                  const SizedBox(height: 12),
                  troopFilter,
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: searchField),
              const SizedBox(width: 12),
              Expanded(child: roleFilter),
              if (isSystemAdmin) ...[
                const SizedBox(width: 12),
                Expanded(child: troopFilter),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Build role filter dropdown
  Widget _buildRoleFilter(
    ThemeData theme,
    UserManagementProvider provider,
    double availableWidth,
  ) {
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
    final availableRoles = isTroopLeader
        ? provider.roles
              .where((role) => role.rank > 0 && role.rank <= 40)
              .toList()
        : provider.roles;

    final dedupedRoleMap = <String, Role>{};
    for (final role in availableRoles) {
      dedupedRoleMap.putIfAbsent(role.id, () => role);
    }
    final dedupedRoles = dedupedRoleMap.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    final selectedRoleFilter = provider.selectedRoleFilter;
    final selectedMatches = selectedRoleFilter == null
        ? 0
        : dedupedRoles.where((role) => role.id == selectedRoleFilter).length;
    final dropdownSelectedValue = selectedMatches == 1
        ? selectedRoleFilter
        : null;

    if (selectedRoleFilter != null && dropdownSelectedValue == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentProvider = context.read<UserManagementProvider>();
        if (currentProvider.selectedRoleFilter != null) {
          currentProvider.setRoleFilter(null);
        }
      });
    }

    return DropdownButtonFormField<String?>(
      key: ValueKey('role-filter-${provider.selectedRoleFilter ?? 'all'}'),
      initialValue: dropdownSelectedValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Filter by role',
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
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
                child: Text('All Roles', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        ...dedupedRoles.map((role) {
          return DropdownMenuItem<String>(
            value: role.id,
            child: Text(role.name, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (value) => provider.setRoleFilter(value),
    );
  }

  /// Build troop filter dropdown
  Widget _buildTroopFilter(
    ThemeData theme,
    UserManagementProvider provider,
    double availableWidth,
  ) {
    final troops = provider.availableTroops;
    final selectedTroopFilter = provider.selectedTroopFilter;
    final selectedTroopMatches = selectedTroopFilter == null
        ? 0
        : troops.where((troop) => troop['id'] == selectedTroopFilter).length;
    final dropdownSelectedTroop = selectedTroopMatches == 1
        ? selectedTroopFilter
        : null;

    if (selectedTroopFilter != null && dropdownSelectedTroop == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final currentProvider = context.read<UserManagementProvider>();
        if (currentProvider.selectedTroopFilter != null) {
          currentProvider.setTroopFilter(null);
        }
      });
    }

    // Adjust UI based on available width
    final isNarrow = availableWidth < 250;
    final contentPadding = isNarrow
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 14);

    return DropdownButtonFormField<String?>(
      key: ValueKey('troop-filter-${provider.selectedTroopFilter ?? 'all'}'),
      initialValue: dropdownSelectedTroop,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Filter by troop',
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
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
                child: Text('All Troops', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        ...troops.map((troop) {
          return DropdownMenuItem<String>(
            value: troop['id'],
            child: Text(troop['name']!, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (value) => provider.setTroopFilter(value),
    );
  }

  /// Build user count badge showing filtered/total users
  Widget _buildUserCountBadge(
    int filteredCount,
    int totalCount,
    ThemeData theme,
  ) {
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
                _debounceTimer?.cancel();
                _searchController.clear();
                _lastSubmittedQuery = '';
                context.read<UserManagementProvider>().clearFilters();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    ManagedUserProfile profile,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => UserEditDialog(profile: profile),
    );
  }

  /// Build context-aware empty state
  ///
  /// Shows different messages and CTAs based on whether the empty state is due to
  /// no users existing (initial state) or active filters returning no results
  Widget _buildEmptyState(
    BuildContext context,
    UserManagementProvider provider, {
    required bool isInitialState,
  }) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final hasAdminPermission = authProvider.currentUserRoleRank >= 60;

    // Check if any filters are active
    final hasActiveFilters =
        provider.searchQuery.isNotEmpty ||
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
              const Icon(Icons.groups_outlined, size: 100),
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
              const Icon(Icons.filter_alt_off, size: 100),
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
                  _debounceTimer?.cancel();
                  _searchController.clear();
                  _lastSubmittedQuery = '';
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
