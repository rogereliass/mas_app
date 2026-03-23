import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../auth/logic/auth_provider.dart';
import '../../../../core/widgets/admin_scope_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../user_management/data/models/managed_user_profile.dart';
import '../logic/role_management_provider.dart';
import 'components/role_editor_dialog.dart';
import 'components/role_management_user_card.dart';

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  String _lastSubmittedQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final roleProvider = context.read<RoleManagementProvider>();
      final colorScheme = Theme.of(context).colorScheme;

      if (authProvider.currentUserRoleRank < 100) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Access denied: only system admins can manage roles.',
            ),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }

      roleProvider.loadRoles();
      roleProvider.loadUsers();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<RoleManagementProvider>().loadMoreUsers();
    }
  }

  void _onSearchChanged(String value, RoleManagementProvider provider) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      final normalized = value.trim();
      if (_lastSubmittedQuery == normalized) return;
      _lastSubmittedQuery = normalized;
      provider.setSearchQuery(normalized);
    });
  }

  Future<void> _openRoleDialog(ManagedUserProfile profile) async {
    final provider = context.read<RoleManagementProvider>();
    final latestProfile = await provider.getProfileDetails(profile.id);
    if (!mounted) return;

    final target = latestProfile ?? profile;
    await showDialog<bool>(
      context: context,
      builder: (_) => RoleEditorDialog(profile: target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
        centerTitle: false,
        actions: [
          Consumer<RoleManagementProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh users',
                onPressed: provider.isLoadingUsers
                    ? null
                    : () => provider.refresh(forceRefresh: true),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AdminScopeBanner(),
          ),
          _buildSearchAndFilter(theme),
          Expanded(
            child: Consumer<RoleManagementProvider>(
              builder: (context, provider, _) {
                if (provider.isLoadingUsers) {
                  return const LoadingView(message: 'Loading users...');
                }

                if (provider.hasError && provider.users.isEmpty) {
                  return ErrorView(
                    message: provider.error ?? 'Unable to load users.',
                    onRetry: () => provider.loadUsers(),
                  );
                }

                if (provider.users.isEmpty) {
                  return _buildEmptyState(
                    context,
                    title: 'No users found',
                    subtitle:
                        'Try changing filters or search by a different name/mobile.',
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount:
                      provider.users.length + (provider.hasMoreUsers ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.users.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final profile = provider.users[index];
                    return RoleManagementUserCard(
                      key: ValueKey(profile.id),
                      profile: profile,
                      onManageRoles: () => _openRoleDialog(profile),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Consumer<RoleManagementProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;

              final searchField = TextField(
                controller: _searchController,
                onChanged: (value) => _onSearchChanged(value, provider),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search name or mobile...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
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

              final roleFilter = DropdownButtonFormField<String?>(
                key: ValueKey(
                  'role-filter-${provider.selectedRoleFilter ?? 'all'}',
                ),
                value: provider.selectedRoleFilter,
                isExpanded: false,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  labelText: 'Filter by role',
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
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
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All roles'),
                  ),
                  ...provider.roles.map((role) {
                    return DropdownMenuItem<String?>(
                      value: role.id,
                      child: Text(role.name, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: provider.isLoadingRoles
                    ? null
                    : (value) => provider.setRoleFilter(value),
              );

              if (compact) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    roleFilter,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: searchField),
                  const SizedBox(width: 12),
                  Expanded(child: roleFilter),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_off_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
