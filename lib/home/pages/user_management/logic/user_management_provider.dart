import 'package:flutter/foundation.dart';
import '../../../../core/utils/ttl_cache.dart';
import '../../../../auth/data/role_repository.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/models/role.dart';
import '../../../../auth/models/user_profile.dart';
import '../data/models/managed_user_profile.dart';
import '../data/user_management_service.dart';

/// Provider for user management operations
class UserManagementProvider with ChangeNotifier {
  static const Duration _usersCacheTtl = Duration(minutes: 3);
  static const Duration _rolesCacheTtl = Duration(minutes: 60);

  final UserManagementService _service;
  final AuthProvider _authProvider;
  final RoleRepository _roleRepository = RoleRepository();
  final TtlCache<String, List<ManagedUserProfile>> _usersCache =
      TtlCache<String, List<ManagedUserProfile>>();
  final TtlCache<String, List<Role>> _rolesCache =
      TtlCache<String, List<Role>>();

  String? _selectedRoleName;
  
  // Search and filter state
  String _searchQuery = '';
  String? _selectedRoleFilter;
  String? _selectedTroopFilter;

  UserManagementProvider({
    UserManagementService? service,
    required AuthProvider authProvider,
  })  : _service = service ?? UserManagementService.instance(),
        _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _usersCache.clear();
    _rolesCache.clear();
    notifyListeners();
  }

  void setRoleContext(String roleName) {
    _selectedRoleName = roleName;
    notifyListeners();
  }

  void clearRoleContext() {
    _selectedRoleName = null;
    notifyListeners();
  }

  UserProfile? get _effectiveUserProfile {
    final baseProfile = _authProvider.currentUserProfile;
    if (baseProfile == null) return null;

    if (_selectedRoleName == null) return baseProfile;

    final selectedRole = _authProvider.getRoleByName(_selectedRoleName!);
    if (selectedRole == null) return baseProfile;

    return UserProfile(
      id: baseProfile.id,
      userId: baseProfile.userId,
      firstName: baseProfile.firstName,
      middleName: baseProfile.middleName,
      lastName: baseProfile.lastName,
      nameAr: baseProfile.nameAr,
      email: baseProfile.email,
      phone: baseProfile.phone,
      address: baseProfile.address,
      birthdate: baseProfile.birthdate,
      gender: baseProfile.gender,
      signupTroopId: baseProfile.signupTroopId,
      generation: baseProfile.generation,
      avatarUrl: baseProfile.avatarUrl,
      roleRank: selectedRole.rank,
      managedTroopId: baseProfile.managedTroopId,
      createdAt: baseProfile.createdAt,
      updatedAt: baseProfile.updatedAt,
    );
  }

  List<ManagedUserProfile> _users = [];
  List<Role> _roles = [];
  bool _isLoadingUsers = false;
  bool _isLoadingRoles = false;
  bool _isProcessing = false;
  String? _error;

  // Filter cache for performance optimization
  List<ManagedUserProfile>? _cachedFilteredUsers;
  String? _cachedSearchQuery;
  String? _cachedRoleFilter;
  String? _cachedTroopFilter;

  List<ManagedUserProfile> get users => _users;
  List<Role> get roles => _roles;
  bool get isLoadingUsers => _isLoadingUsers;
  bool get isLoadingRoles => _isLoadingRoles;
  bool get isProcessing => _isProcessing;
  bool get hasError => _error != null;
  String? get error => _error;
  
  // Search and filter getters
  String get searchQuery => _searchQuery;
  String? get selectedRoleFilter => _selectedRoleFilter;
  String? get selectedTroopFilter => _selectedTroopFilter;

  bool get isRolesReady =>
      !_isLoadingRoles && !_authProvider.profileLoading && _effectiveUserProfile != null;

  /// Get filtered list of users based on search query and selected filters
  List<ManagedUserProfile> get filteredUsers {
    // Return cached result if filters haven't changed
    if (_cachedFilteredUsers != null &&
        _cachedSearchQuery == _searchQuery &&
        _cachedRoleFilter == _selectedRoleFilter &&
        _cachedTroopFilter == _selectedTroopFilter) {
      return _cachedFilteredUsers!;
    }

    var filtered = _users;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((user) {
        final name = user.fullName.toLowerCase();
         final phone = user.phone?.toLowerCase() ?? '';
        final scoutCode = user.scoutCode?.toLowerCase() ?? '';
        return name.contains(query) || 
           phone.contains(query) || 
               scoutCode.contains(query);
      }).toList();
    }
    
    // Apply role filter
    if (_selectedRoleFilter != null) {
      filtered = filtered.where((user) {
        return user.roles.any((role) => role.id == _selectedRoleFilter);
      }).toList();
    }
    
    // Apply troop filter
    if (_selectedTroopFilter != null) {
      filtered = filtered.where((user) {
        return user.signupTroopId == _selectedTroopFilter;
      }).toList();
    }
    
    // Cache the result
    _cachedFilteredUsers = filtered;
    _cachedSearchQuery = _searchQuery;
    _cachedRoleFilter = _selectedRoleFilter;
    _cachedTroopFilter = _selectedTroopFilter;
    
    return filtered;
  }
  
  /// Get list of available troops from loaded users
  List<Map<String, String>> get availableTroops {
    final troopMap = <String, String>{};
    for (var user in _users) {
      if (user.signupTroopId != null && user.signupTroopName != null) {
        troopMap[user.signupTroopId!] = user.signupTroopName!;
      }
    }
    return troopMap.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }
  
  /// Clear filter cache when data or filters change
  void _clearFilterCache() {
    _cachedFilteredUsers = null;
    _cachedSearchQuery = null;
    _cachedRoleFilter = null;
    _cachedTroopFilter = null;
  }

  /// Update search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    _clearFilterCache();
    notifyListeners();
  }
  
  /// Update role filter
  void setRoleFilter(String? roleId) {
    _selectedRoleFilter = roleId;
    _clearFilterCache();
    notifyListeners();
  }
  
  /// Update troop filter
  void setTroopFilter(String? troopId) {
    _selectedTroopFilter = troopId;
    _clearFilterCache();
    notifyListeners();
  }
  
  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedRoleFilter = null;
    _selectedTroopFilter = null;
    _clearFilterCache();
    notifyListeners();
  }

  List<Role> get assignableRoles {
    final effectiveUser = _effectiveUserProfile;
    if (effectiveUser == null) return [];

    final effectiveRank = effectiveUser.roleRank;
    var filteredRoles = _roles.where((role) => role.rank < effectiveRank).toList();

    if (effectiveRank >= 60 && effectiveRank < 90) {
      filteredRoles = filteredRoles.where((role) => role.rank > 0 && role.rank <= 40).toList();
    }

    return filteredRoles;
  }

  bool canEditRolesForProfile(ManagedUserProfile profile) {
    final effectiveUser = _effectiveUserProfile;
    if (effectiveUser == null) return false;

    if (profile.roles.isEmpty) {
      return true;
    }

    final highestTargetRank = profile.roles
        .map((role) => role.rank)
        .reduce((a, b) => a > b ? a : b);

    if (effectiveUser.roleRank <= highestTargetRank) {
      return false;
    }

    return true;
  }

  Future<void> loadUsers({bool forceRefresh = false}) async {
    _isLoadingUsers = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = _effectiveUserProfile;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      final cacheKey =
          '${currentUser.roleRank}:${currentUser.managedTroopId ?? 'none'}:${_selectedRoleName ?? 'default'}';
      if (!forceRefresh) {
        final cachedUsers = _usersCache.get(cacheKey);
        if (cachedUsers != null && cachedUsers.isNotEmpty) {
          _users = cachedUsers;
          _clearFilterCache();
          _isLoadingUsers = false;
          notifyListeners();
          return;
        }
      }

      _users = await _service.fetchUsers(currentUser: currentUser);
      _usersCache.set(cacheKey, _users, _usersCacheTtl);
      _clearFilterCache();
    } catch (e) {
      _error = 'Unable to load users. Please check your connection and try again.';
      debugPrint('❌ Error loading users: $e');
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  Future<void> loadRoles({bool forceRefresh = false}) async {
    _isLoadingRoles = true;
    _error = null;
    notifyListeners();

    try {
      if (!forceRefresh) {
        final cachedRoles = _rolesCache.get('all_roles');
        if (cachedRoles != null && cachedRoles.isNotEmpty) {
          _roles = cachedRoles;
          _isLoadingRoles = false;
          notifyListeners();
          return;
        }
      }

      _roles = await _service.fetchRoles();
      _rolesCache.set('all_roles', _roles, _rolesCacheTtl);
    } catch (e) {
      _error = 'Unable to load roles. Please try again.';
      debugPrint('❌ Error loading roles: $e');
    } finally {
      _isLoadingRoles = false;
      notifyListeners();
    }
  }

  Future<bool> updateUser({
    required ManagedUserProfile profile,
    required Map<String, dynamic> updates,
    List<String>? roleIds,
    Map<String, String?>? roleTroopContextMap,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      // Validate current user authentication and authorization
      final currentUser = _effectiveUserProfile;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Update basic profile fields (name, email, address, etc.)
      await _service.updateProfile(
        profileId: profile.id,
        updates: updates,
        currentUser: currentUser,
      );

      // Handle role updates if requested
      List<Role>? updatedRoles;
      final canEditRoles = canEditRolesForProfile(profile);
      final currentRoleIds = profile.roles.map((role) => role.id).toSet();
        final requestedRoleIds = roleIds?.toSet();
      final shouldUpdateRoles =
          requestedRoleIds != null && !setEquals(currentRoleIds, requestedRoleIds);

      if (shouldUpdateRoles) {
        // Permission check: Verify current user can modify target user's roles
        // (also enforced by server-side RLS policies)
        if (!canEditRoles) {
          throw Exception('You do not have permission to change this user\'s roles');
        }

        // Validate all requested roles are assignable by current user
        final assignableRoleIds = assignableRoles.map((role) => role.id).toSet();
        if (!requestedRoleIds.every(assignableRoleIds.contains)) {
          throw Exception('One or more selected roles are not assignable');
        }

        // Determine troop context for role assignment
        // Use profile's signup troop or current user's managed troop
        final troopContextId = profile.signupTroopId ?? currentUser.managedTroopId;

        // Update role assignments in database
        await _service.updateProfileRoles(
          profileId: profile.id,
          roleIds: requestedRoleIds.toList(),
          assignedBy: currentUser.id,
          currentUser: currentUser,
          troopContextId: troopContextId,
          roleTroopContextMap: roleTroopContextMap,
        );

        // Sync updated roles to local state
        if (_roles.isNotEmpty) {
          updatedRoles = _roles
              .where((role) => requestedRoleIds.contains(role.id))
              .toList();
        } else {
          // Keep existing roles if we don't have role definitions loaded
          updatedRoles = profile.roles
              .where((role) => requestedRoleIds.contains(role.id))
              .toList();
        }
      }

      // Create updated profile with new data
      final updatedProfile = profile.copyWith(
        firstName: updates['first_name'] as String?,
        middleName: updates['middle_name'] as String?,
        lastName: updates['last_name'] as String?,
        nameAr: updates['name_ar'] as String?,
        email: updates['email'] as String?,
        address: updates['address'] as String?,
        birthdate: updates['birthdate'] != null
            ? DateTime.parse(updates['birthdate'] as String)
            : profile.birthdate,
        gender: updates['gender'] as String?,
        generation: updates['generation'] as String?,
        medicalNotes: updates['medical_notes'] as String?,
        allergies: updates['allergies'] as String?,
        roles: updatedRoles,
        updatedAt: DateTime.now(),
      );

      // Update local users list with modified profile
      final index = _users.indexWhere((user) => user.id == profile.id);
      if (index != -1) {
        _users[index] = updatedProfile;
        // Clear filter cache to force recomputation with updated data
        _clearFilterCache();
      }

      return true;
    } catch (e) {
      _error = 'Unable to update user. Please try again.';
      debugPrint('❌ Error updating user: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Fetches roles for a specific profile (utility method for direct role queries)
  /// Note: This does not update provider state. Use loadRoles() for provider state updates.
  Future<List<Role>> getProfileRoles(String profileId) async {
    try {
      return await _roleRepository.getProfileRoles(profileId);
    } catch (e) {
      debugPrint('❌ Error loading profile roles: $e');
      return [];
    }
  }

  Future<void> refresh({bool forceRefresh = false}) async {
    await loadUsers(forceRefresh: forceRefresh);
  }
}
