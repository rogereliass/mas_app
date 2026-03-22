import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../auth/models/user_profile.dart';
import '../../../../auth/data/role_repository.dart';
import '../../../../auth/models/role.dart';
import '../../../../core/data/scoped_service_mixin.dart';
import 'models/managed_user_profile.dart';

/// User Management Service
///
/// Handles loading and updating user profiles and roles
class UserManagementService with ScopedServiceMixin {
  static const String _profilesTable = 'profiles';
  static const String _profileRolesTable = 'profile_roles';

  final SupabaseClient _supabase;
  final RoleRepository _roleRepository = RoleRepository();

  UserManagementService(this._supabase);

  factory UserManagementService.instance() {
    return UserManagementService(Supabase.instance.client);
  }

  Future<List<ManagedUserProfile>> fetchUsers({
    required UserProfile currentUser,
    int limit = 20,
    int offset = 0,
    String? searchQuery,
    String? roleFilter,
    String? troopFilter,
  }) async {
    try {
      final normalizedRoleFilter = roleFilter?.trim();

      if (normalizedRoleFilter != null && normalizedRoleFilter.isNotEmpty) {
        return _fetchUsersWithDeterministicRoleFilter(
          currentUser: currentUser,
          limit: limit,
          offset: offset,
          searchQuery: searchQuery,
          roleFilter: normalizedRoleFilter,
          troopFilter: troopFilter,
        );
      }

      return _fetchUsersPage(
        currentUser: currentUser,
        limit: limit,
        offset: offset,
        searchQuery: searchQuery,
        troopFilter: troopFilter,
      );
    } catch (e) {
      _logError('fetchUsers', e);
      rethrow;
    }
  }

  Future<List<ManagedUserProfile>> _fetchUsersPage({
    required UserProfile currentUser,
    required int limit,
    required int offset,
    String? searchQuery,
    String? troopFilter,
  }) async {
    var query = _supabase.from(_profilesTable).select('''
            id,
            user_id,
            first_name,
            middle_name,
            last_name,
            name_ar,
            email,
            phone,
            address,
            birthdate,
            gender,
            generation,
            scout_org_id,
            scout_code,
            medical_notes,
            allergies,
            signup_troop,
            approved,
            created_at,
            updated_at,
            troops:signup_troop(name),
            profile_roles!profile_roles_profile_id_fkey(
              role_id,
              troop_context,
              troops:troop_context(name),
              roles:roles(
                id,
                name,
                slug,
                description,
                role_rank,
                created_at
              )
            )
          ''').eq('approved', true);

    // Apply scope filter (system vs troop level)
    query = applyScopeFilter(query, currentUser, 'signup_troop');

    // Apply troop filter if provided (only for system admins who can see all)
    if (troopFilter != null) {
      query = query.eq('signup_troop', troopFilter);
    }

    // Apply search query
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      query = query.or(
        'first_name.ilike.$q,last_name.ilike.$q,name_ar.ilike.$q,phone.ilike.$q,scout_code.ilike.$q',
      );
    }

    // Sort by last name and apply range
    final response = await query.order('last_name', ascending: true).range(
      offset,
      offset + limit - 1,
    );

    return _parseUsers(response);
  }

  Future<List<ManagedUserProfile>> _fetchUsersWithDeterministicRoleFilter({
    required UserProfile currentUser,
    required int limit,
    required int offset,
    required String roleFilter,
    String? searchQuery,
    String? troopFilter,
  }) async {
    const int chunkSize = 80;

    final collected = <ManagedUserProfile>[];
    var rawOffset = 0;
    var matchedSeen = 0;
    var reachedEnd = false;

    while (!reachedEnd && collected.length < limit) {
      final pageUsers = await _fetchUsersPage(
        currentUser: currentUser,
        limit: chunkSize,
        offset: rawOffset,
        searchQuery: searchQuery,
        troopFilter: troopFilter,
      );

      if (pageUsers.isEmpty) {
        reachedEnd = true;
        break;
      }

      final pageProfileIds = pageUsers.map((u) => u.id).toList();
      final matchedRows = await _supabase
          .from(_profileRolesTable)
          .select('profile_id')
          .eq('role_id', roleFilter)
          .inFilter('profile_id', pageProfileIds);

      final matchedProfileIds = (matchedRows as List)
          .map((row) => (row as Map<String, dynamic>)['profile_id'] as String?)
          .whereType<String>()
          .toSet();

      for (final user in pageUsers) {
        if (!matchedProfileIds.contains(user.id)) continue;

        if (matchedSeen < offset) {
          matchedSeen++;
          continue;
        }

        collected.add(user);
        if (collected.length >= limit) break;
      }

      rawOffset += chunkSize;
      if (pageUsers.length < chunkSize) {
        reachedEnd = true;
      }
    }

    return collected;
  }

  List<ManagedUserProfile> _parseUsers(dynamic response) {
    final users = <ManagedUserProfile>[];
    for (final row in (response as List)) {
      try {
        users.add(ManagedUserProfile.fromJson(row as Map<String, dynamic>));
      } catch (error) {
        final profileId = row is Map<String, dynamic> ? row['id'] : null;
        debugPrint(
          '⚠️ Skipping invalid profile row in fetchUsers. id=$profileId error=$error',
        );
      }
    }
    return users;
  }

  Future<ManagedUserProfile?> getProfileById(String profileId) async {
    try {
      final response = await _supabase
          .from(_profilesTable)
          .select('''
            id,
            user_id,
            first_name,
            middle_name,
            last_name,
            name_ar,
            email,
            phone,
            address,
            birthdate,
            gender,
            generation,
            scout_org_id,
            scout_code,
            medical_notes,
            allergies,
            signup_troop,
            approved,
            created_at,
            updated_at,
            troops:signup_troop(name),
            profile_roles!profile_roles_profile_id_fkey(
              role_id,
              troop_context,
              troops:troop_context(name),
              roles:roles(
                id,
                name,
                slug,
                description,
                role_rank,
                created_at
              )
            )
          ''')
          .eq('id', profileId)
          .maybeSingle();

      if (response == null) return null;
      return ManagedUserProfile.fromJson(response);
    } catch (e) {
      _logError('getProfileById', e);
      rethrow;
    }
  }

  Future<List<Role>> fetchRoles() async {
    try {
      return await _roleRepository.getAllRoles();
    } catch (e) {
      _logError('fetchRoles', e);
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String profileId,
    required Map<String, dynamic> updates,
    UserProfile? currentUser,
  }) async {
    try {
      if (currentUser != null) {
        await _validateProfileAccess(profileId, currentUser);
      }

      await _supabase.from(_profilesTable).update(updates).eq('id', profileId);
    } catch (e) {
      _logError('updateProfile', e);
      rethrow;
    }
  }

  Future<void> updateProfileRoles({
    required String profileId,
    required List<String> roleIds,
    required String assignedBy,
    required UserProfile currentUser,
    String? troopContextId,
    Map<String, String?>? roleTroopContextMap,
  }) async {
    if (roleIds.isEmpty) {
      throw ArgumentError('At least one role must be selected');
    }

    await _validateProfileAccess(profileId, currentUser);

    try {
      final rolesResponse = await _supabase
          .from('roles')
          .select('id, role_rank');

      final roleRanks = Map<String, int>.fromEntries(
        (rolesResponse as List).map(
          (r) => MapEntry(r['id'] as String, r['role_rank'] as int? ?? 0),
        ),
      );

      for (final roleId in roleIds) {
        final rank = roleRanks[roleId] ?? 0;
        if (rank >= currentUser.roleRank) {
          throw Exception('Cannot assign a role at or above your rank');
        }
        if (currentUser.isTroopScoped && rank > 40) {
          throw Exception('Troop-scoped roles can only assign ranks 1-40');
        }

        // Check troop context requirement using per-role map or fallback
        if (rank == 60 || rank == 70) {
          final contextForRole = roleTroopContextMap?[roleId] ?? troopContextId;
          if (contextForRole == null) {
            throw Exception('Troop context is required for troop-scoped roles');
          }
        }
      }

      await _supabase
          .from(_profileRolesTable)
          .delete()
          .eq('profile_id', profileId);

      final roleRecords = roleIds.map((roleId) {
        final rank = roleRanks[roleId] ?? 0;
        final contextForRole = roleTroopContextMap?[roleId] ?? troopContextId;

        return {
          'profile_id': profileId,
          'role_id': roleId,
          'assigned_by': assignedBy,
          if ((rank == 60 || rank == 70) && contextForRole != null)
            'troop_context': contextForRole,
        };
      }).toList();

      await _supabase.from(_profileRolesTable).insert(roleRecords);
    } catch (e) {
      _logError('updateProfileRoles', e);
      rethrow;
    }
  }

  Future<void> _validateProfileAccess(
    String profileId,
    UserProfile currentUser,
  ) async {
    if (currentUser.hasSystemWideAccess) {
      return;
    }

    if (currentUser.managedTroopId == null) {
      throw Exception('Troop-scoped user has no managed troop assigned');
    }

    final profile = await getProfileById(profileId);
    if (profile == null) {
      throw Exception('Profile not found: $profileId');
    }

    if (profile.signupTroopId != currentUser.managedTroopId) {
      throw Exception('Access Denied: This profile is not in your troop');
    }
  }

  void _logError(String operation, Object error) {
    debugPrint('❌ UserManagementService.$operation error: $error');
  }
}
