import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../auth/data/role_repository.dart';
import '../../../../auth/models/role.dart';
import '../../../../auth/models/user_profile.dart';
import '../../../../core/data/scoped_service_mixin.dart';
import '../../user_management/data/models/managed_user_profile.dart';

class RoleManagementService with ScopedServiceMixin {
  static const String _profilesTable = 'profiles';
  static const String _profileRolesTable = 'profile_roles';

  final SupabaseClient _supabase;
  final RoleRepository _roleRepository = RoleRepository();

  RoleManagementService(this._supabase);

  factory RoleManagementService.instance() {
    return RoleManagementService(Supabase.instance.client);
  }

  Future<List<ManagedUserProfile>> fetchUsers({
    required UserProfile currentUser,
    int limit = 20,
    int offset = 0,
    String? searchQuery,
    String? roleFilter,
  }) async {
    _assertSystemAdmin(currentUser);

    try {
      final normalizedRoleFilter = roleFilter?.trim();

      if (normalizedRoleFilter != null && normalizedRoleFilter.isNotEmpty) {
        return _fetchUsersWithDeterministicRoleFilter(
          currentUser: currentUser,
          limit: limit,
          offset: offset,
          searchQuery: searchQuery,
          roleFilter: normalizedRoleFilter,
        );
      }

      return _fetchUsersPage(
        currentUser: currentUser,
        limit: limit,
        offset: offset,
        searchQuery: searchQuery,
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
  }) async {
    var query = _supabase
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
        .eq('approved', true);

    query = applyScopeFilter(query, currentUser, 'signup_troop');

    final normalizedSearch = searchQuery?.trim() ?? '';
    if (normalizedSearch.isNotEmpty) {
      final q = '%$normalizedSearch%';
      query = query.or(
        'first_name.ilike.$q,middle_name.ilike.$q,last_name.ilike.$q,name_ar.ilike.$q,phone.ilike.$q',
      );
    }

    final response = await query
        .order('last_name', ascending: true)
        .range(offset, offset + limit - 1);

    return _parseUsers(response);
  }

  Future<List<ManagedUserProfile>> _fetchUsersWithDeterministicRoleFilter({
    required UserProfile currentUser,
    required int limit,
    required int offset,
    required String roleFilter,
    String? searchQuery,
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
          'Skipping invalid profile row in fetchUsers. id=$profileId error=$error',
        );
      }
    }

    return users;
  }

  Future<ManagedUserProfile?> getProfileById({
    required UserProfile currentUser,
    required String profileId,
  }) async {
    _assertSystemAdmin(currentUser);

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

  Future<List<Role>> fetchRoles({required UserProfile currentUser}) async {
    _assertSystemAdmin(currentUser);

    try {
      final roles = await _roleRepository.getAllRoles();
      roles.sort((a, b) => a.rank.compareTo(b.rank));
      return roles;
    } catch (e) {
      _logError('fetchRoles', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> patchProfileRolesDelta({
    required UserProfile currentUser,
    required String profileId,
    required List<String> selectedRoleIds,
    required Map<String, String?> roleTroopContextMap,
  }) async {
    _assertSystemAdmin(currentUser);

    try {
      final existingResponse = await _supabase
          .from(_profileRolesTable)
          .select('role_id, troop_context, roles!inner(role_rank)')
          .eq('profile_id', profileId);

      final existingRoleIds = <String>{};
      final existingRoleRanks = <String, int>{};
      final existingRoleTroopContext = <String, String?>{};

      for (final row in existingResponse as List) {
        final map = row as Map<String, dynamic>;
        final roleId = map['role_id'] as String?;
        if (roleId == null || roleId.isEmpty) continue;

        final roleRank =
            (map['roles'] as Map<String, dynamic>)['role_rank'] as int? ?? 0;
        existingRoleIds.add(roleId);
        existingRoleRanks[roleId] = roleRank;
        existingRoleTroopContext[roleId] = map['troop_context'] as String?;
      }

      final selectedRoleIdSet = selectedRoleIds.toSet();
      final selectedRoleRanks = <String, int>{};

      if (selectedRoleIdSet.isNotEmpty) {
        final rolesResponse = await _supabase
            .from('roles')
            .select('id, role_rank')
            .inFilter('id', selectedRoleIdSet.toList());

        for (final row in rolesResponse as List) {
          final map = row as Map<String, dynamic>;
          final roleId = map['id'] as String?;
          if (roleId == null || roleId.isEmpty) continue;
          selectedRoleRanks[roleId] = map['role_rank'] as int? ?? 0;
        }
      }

      for (final roleId in selectedRoleIdSet) {
        final rank =
            selectedRoleRanks[roleId] ?? existingRoleRanks[roleId] ?? 0;
        if (rank >= currentUser.roleRank) {
          throw Exception('Cannot assign a role at or above your rank');
        }

        if ((rank == 60 || rank == 70) &&
            (roleTroopContextMap[roleId] == null ||
                roleTroopContextMap[roleId]!.isEmpty)) {
          throw Exception('Troop context is required for troop-scoped roles');
        }
      }

      final toAdd = <Map<String, dynamic>>[];
      for (final roleId in selectedRoleIdSet.difference(existingRoleIds)) {
        final rank = selectedRoleRanks[roleId] ?? 0;
        toAdd.add({
          'role_id': roleId,
          if (rank == 60 || rank == 70)
            'troop_context': roleTroopContextMap[roleId],
        });
      }

      final removableRoleIds = <String>{};
      for (final roleId in existingRoleIds) {
        final rank = existingRoleRanks[roleId] ?? 0;
        if (rank < currentUser.roleRank) {
          removableRoleIds.add(roleId);
        }
      }

      final toRemove = removableRoleIds.difference(selectedRoleIdSet).toList();

      final toUpdateContext = <Map<String, dynamic>>[];
      final sharedRoleIds = selectedRoleIdSet.intersection(existingRoleIds);
      for (final roleId in sharedRoleIds) {
        final rank =
            selectedRoleRanks[roleId] ?? existingRoleRanks[roleId] ?? 0;
        if (rank != 60 && rank != 70) continue;

        final previousContext = existingRoleTroopContext[roleId];
        final nextContext = roleTroopContextMap[roleId];
        if (nextContext == null || nextContext.isEmpty) {
          throw Exception('Troop context is required for troop-scoped roles');
        }

        if (nextContext != previousContext) {
          toUpdateContext.add({
            'role_id': roleId,
            'troop_context': nextContext,
          });
        }
      }

      final shouldCallRpc =
          toAdd.isNotEmpty || toRemove.isNotEmpty || toUpdateContext.isNotEmpty;
      if (!shouldCallRpc) {
        return {
          'success': true,
          'added': 0,
          'removed': 0,
          'context_updated': 0,
          'unchanged': selectedRoleIdSet.length,
        };
      }

      final rpcResponse = await _supabase.rpc(
        'patch_profile_roles_delta',
        params: {
          'p_profile_id': profileId,
          'p_add_roles': toAdd,
          'p_remove_role_ids': toRemove,
          'p_context_updates': toUpdateContext,
        },
      );

      if (rpcResponse is Map<String, dynamic>) {
        return rpcResponse;
      }

      return {'success': true};
    } catch (e) {
      _logError('patchProfileRolesDelta', e);
      rethrow;
    }
  }

  void _assertSystemAdmin(UserProfile currentUser) {
    if (currentUser.roleRank < 100) {
      throw Exception('Only system admins can access role management');
    }
  }

  void _logError(String operation, Object error) {
    debugPrint('RoleManagementService.$operation error: $error');
  }
}
