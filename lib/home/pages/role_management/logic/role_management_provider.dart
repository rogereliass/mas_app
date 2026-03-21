import 'package:flutter/foundation.dart';

import '../../../../auth/models/role.dart';
import '../../../../auth/models/user_profile.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../../../../core/utils/ttl_cache.dart';
import '../../user_management/data/models/managed_user_profile.dart';
import '../data/role_management_service.dart';

class RoleManagementProvider with ChangeNotifier {
  static const Duration _usersCacheTtl = Duration(minutes: 3);
  static const Duration _rolesCacheTtl = Duration(minutes: 60);
  static const int _pageSize = 20;

  final RoleManagementService _service;
  final AuthProvider _authProvider;
  final TtlCache<String, List<ManagedUserProfile>> _usersCache =
      TtlCache<String, List<ManagedUserProfile>>();
  final TtlCache<String, List<Role>> _rolesCache =
      TtlCache<String, List<Role>>();

  List<ManagedUserProfile> _users = [];
  List<Role> _roles = [];

  bool _isLoadingUsers = false;
  bool _isLoadingRoles = false;
  bool _isLoadingMore = false;
  bool _isProcessing = false;
  bool _hasMoreUsers = true;

  String _searchQuery = '';
  String? _selectedRoleFilter;
  String? _error;

  RoleManagementProvider({
    RoleManagementService? service,
    required AuthProvider authProvider,
  }) : _service = service ?? RoleManagementService.instance(),
       _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  List<ManagedUserProfile> get users => _users;
  List<Role> get roles => _roles;
  bool get isLoadingUsers => _isLoadingUsers;
  bool get isLoadingRoles => _isLoadingRoles;
  bool get isLoadingMore => _isLoadingMore;
  bool get isProcessing => _isProcessing;
  bool get hasMoreUsers => _hasMoreUsers;
  bool get hasError => _error != null;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedRoleFilter => _selectedRoleFilter;

  bool get canManageRoles {
    final user = _authProvider.currentUserProfile;
    return user != null && user.roleRank >= 100;
  }

  List<Role> get assignableRoles {
    final user = _authProvider.currentUserProfile;
    if (user == null) return [];
    return _roles.where((role) => role.rank < user.roleRank).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
  }

  Set<String> get assignableRoleIds => assignableRoles.map((r) => r.id).toSet();

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    loadUsers(forceRefresh: true);
  }

  void setRoleFilter(String? roleId) {
    if (_selectedRoleFilter == roleId) return;
    _selectedRoleFilter = roleId;
    loadUsers(forceRefresh: true);
  }

  void clearFilters() {
    if (_searchQuery.isEmpty && _selectedRoleFilter == null) return;
    _searchQuery = '';
    _selectedRoleFilter = null;
    loadUsers(forceRefresh: true);
  }

  Future<void> loadUsers({bool forceRefresh = false}) async {
    _isLoadingUsers = true;
    _hasMoreUsers = true;
    _error = null;
    notifyListeners();

    try {
      final user = _requireCurrentUser();
      final cacheKey =
          '${user.roleRank}:$_searchQuery:${_selectedRoleFilter ?? ''}';

      if (!forceRefresh) {
        final cached = _usersCache.get(cacheKey);
        if (cached != null) {
          _users = cached;
          _hasMoreUsers = _users.length >= _pageSize;
          _isLoadingUsers = false;
          notifyListeners();
          return;
        }
      }

      _users = await _service.fetchUsers(
        currentUser: user,
        limit: _pageSize,
        offset: 0,
        searchQuery: _searchQuery,
        roleFilter: _selectedRoleFilter,
      );

      _hasMoreUsers = _users.length >= _pageSize;
      _usersCache.set(cacheKey, _users, _usersCacheTtl);
    } catch (e) {
      _error = 'Unable to load users. Please try again.';
      debugPrint('RoleManagementProvider.loadUsers error: $e');
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreUsers() async {
    if (_isLoadingUsers || _isLoadingMore || !_hasMoreUsers) return;

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final user = _requireCurrentUser();
      final more = await _service.fetchUsers(
        currentUser: user,
        limit: _pageSize,
        offset: _users.length,
        searchQuery: _searchQuery,
        roleFilter: _selectedRoleFilter,
      );

      if (more.isEmpty) {
        _hasMoreUsers = false;
      } else {
        _users.addAll(more);
        _hasMoreUsers = more.length >= _pageSize;

        final cacheKey =
            '${user.roleRank}:$_searchQuery:${_selectedRoleFilter ?? ''}';
        _usersCache.set(cacheKey, _users, _usersCacheTtl);
      }
    } catch (e) {
      _error = 'Unable to load more users. Please try again.';
      debugPrint('RoleManagementProvider.loadMoreUsers error: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadRoles({bool forceRefresh = false}) async {
    _isLoadingRoles = true;
    _error = null;
    notifyListeners();

    try {
      if (!forceRefresh) {
        final cached = _rolesCache.get('all_roles');
        if (cached != null) {
          _roles = cached;
          _sanitizeSelectedRoleFilter();
          _isLoadingRoles = false;
          notifyListeners();
          return;
        }
      }

      final user = _requireCurrentUser();
      _roles = await _service.fetchRoles(currentUser: user);
      _rolesCache.set('all_roles', _roles, _rolesCacheTtl);
      _sanitizeSelectedRoleFilter();
    } catch (e) {
      _error = 'Unable to load roles. Please try again.';
      debugPrint('RoleManagementProvider.loadRoles error: $e');
    } finally {
      _isLoadingRoles = false;
      notifyListeners();
    }
  }

  Future<ManagedUserProfile?> getProfileDetails(String profileId) async {
    try {
      final user = _requireCurrentUser();
      return _service.getProfileById(currentUser: user, profileId: profileId);
    } catch (e) {
      _error = 'Unable to load user details. Please try again.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateRolesForUser({
    required ManagedUserProfile profile,
    required List<Role> selectedEditableRoles,
    required Map<String, String?> roleTroopContextMap,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final user = _requireCurrentUser();
      final editableRoleIds = assignableRoleIds;

      final selectedRoleIds = selectedEditableRoles
          .where((role) => editableRoleIds.contains(role.id))
          .map((role) => role.id)
          .toList();

      await _service.patchProfileRolesDelta(
        currentUser: user,
        profileId: profile.id,
        selectedRoleIds: selectedRoleIds,
        roleTroopContextMap: roleTroopContextMap,
      );

      final refreshed = await _service.getProfileById(
        currentUser: user,
        profileId: profile.id,
      );

      if (refreshed != null) {
        final index = _users.indexWhere((u) => u.id == profile.id);
        if (index != -1) {
          _users[index] = refreshed;
        }
      }

      _usersCache.clear();
      return true;
    } catch (e) {
      _error = 'Unable to update roles. Please verify data and try again.';
      debugPrint('RoleManagementProvider.updateRolesForUser error: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool forceRefresh = false}) async {
    await loadUsers(forceRefresh: forceRefresh);
  }

  UserProfile _requireCurrentUser() {
    final user = _authProvider.currentUserProfile;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    if (user.roleRank < 100) {
      throw Exception('Only system admins can access role management');
    }
    return user;
  }

  void _onAuthChanged() {
    _usersCache.clear();
    _rolesCache.clear();
    _error = null;
    notifyListeners();
  }

  void _sanitizeSelectedRoleFilter() {
    if (_selectedRoleFilter == null) return;
    final exists = _roles.any((role) => role.id == _selectedRoleFilter);
    if (exists) return;
    _selectedRoleFilter = null;
    _usersCache.clear();
  }
}
