import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../auth/data/role_repository.dart';
import '../../../../auth/models/role.dart';
import '../../../../auth/models/user_profile.dart';
import '../../../../core/data/scoped_service_mixin.dart';
import 'models/patrol.dart';
import 'models/troop_member.dart';

class PatrolsManagementService with ScopedServiceMixin {
  static const String _patrolsTable = 'patrols';
  static const String _profilesTable = 'profiles';
  static const String _profileRolesTable = 'profile_roles';

  final SupabaseClient _supabase;

  PatrolsManagementService(this._supabase);

  factory PatrolsManagementService.instance() {
    return PatrolsManagementService(Supabase.instance.client);
  }

  String resolveScopedTroopId({
    required UserProfile currentUser,
    String? selectedTroopId,
  }) {
    if (currentUser.hasSystemWideAccess) {
      if (selectedTroopId == null || selectedTroopId.isEmpty) {
        throw Exception('Please select a troop first');
      }
      return selectedTroopId;
    }

    final managedTroopId = currentUser.managedTroopId;
    if (managedTroopId == null || managedTroopId.isEmpty) {
      throw Exception(
        'No troop is assigned to your role, please contact support for assistance',
      );
    }

    return managedTroopId;
  }

  Future<List<Patrol>> fetchPatrols({
    required UserProfile currentUser,
    required String troopId,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);

      final response = await _supabase
          .from(_patrolsTable)
          .select() // Select all available columns to be resilient to missing fields
          .eq('troop_id', troopId)
          .order('name', ascending: true);

      return (response as List)
          .map((row) => Patrol.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logError('fetchPatrols', e);
      rethrow;
    }
  }

  Future<List<TroopMember>> fetchTroopMembers({
    required UserProfile currentUser,
    required String troopId,
    bool includePending = false,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);

      var query = _supabase
          .from(_profilesTable)
          .select(
            'id, first_name, middle_name, last_name, phone, address, approved, signup_troop, patrol_id',
          )
          .eq('signup_troop', troopId);

      if (!includePending) {
        query = query.eq('approved', true);
      }

      final response = await query
          .order('first_name', ascending: true)
          .order('last_name', ascending: true);

      return (response as List)
          .map((row) => TroopMember.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logError('fetchTroopMembers', e);
      rethrow;
    }
  }

  Future<Patrol> createPatrol({
    required UserProfile currentUser,
    required String troopId,
    required String name,
    required String? description,
    String? patrolLeaderProfileId,
    String? assistant1ProfileId,
    String? assistant2ProfileId,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);
      await _assertPatrolNameAvailable(troopId: troopId, name: name);

      final payload = {
        'troop_id': troopId,
        'name': name.trim(),
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'patrol_leader_profile_id': patrolLeaderProfileId,
        'assistant_1_profile_id': assistant1ProfileId,
        'assistant_2_profile_id': assistant2ProfileId,
      };

      final response = await _supabase
          .from(_patrolsTable)
          .insert(payload)
          .select()
          .single();

      final patrol = Patrol.fromJson(response);

      // Sync leadership roles in database
      await _syncLeadershipRoles(
        currentUser: currentUser,
        troopId: troopId,
        patrolId: patrol.id,
        newLeader: patrolLeaderProfileId,
        newAssistant1: assistant1ProfileId,
        newAssistant2: assistant2ProfileId,
      );

      return patrol;
    } catch (e) {
      _logError('createPatrol', e);
      rethrow;
    }
  }

  Future<void> updatePatrol({
    required UserProfile currentUser,
    required String troopId,
    required String patrolId,
    required String name,
    required String? description,
    String? patrolLeaderProfileId,
    String? assistant1ProfileId,
    String? assistant2ProfileId,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);
      await _assertPatrolNameAvailable(
        troopId: troopId,
        name: name,
        excludePatrolId: patrolId,
      );

      // Fetch current patrol to identify old leadership roles for syncing
      final currentPatrolResponse = await _supabase
          .from(_patrolsTable)
          .select(
            'patrol_leader_profile_id, assistant_1_profile_id, assistant_2_profile_id',
          )
          .eq('id', patrolId)
          .single();

      await _supabase
          .from(_patrolsTable)
          .update({
            'name': name.trim(),
            'description': description?.trim().isEmpty == true
                ? null
                : description?.trim(),
            'patrol_leader_profile_id': patrolLeaderProfileId,
            'assistant_1_profile_id': assistant1ProfileId,
            'assistant_2_profile_id': assistant2ProfileId,
          })
          .eq('id', patrolId)
          .eq('troop_id', troopId);

      // Sync leadership roles in database
      await _syncLeadershipRoles(
        currentUser: currentUser,
        troopId: troopId,
        patrolId: patrolId,
        oldLeader: currentPatrolResponse['patrol_leader_profile_id'],
        oldAssistant1: currentPatrolResponse['assistant_1_profile_id'],
        oldAssistant2: currentPatrolResponse['assistant_2_profile_id'],
        newLeader: patrolLeaderProfileId,
        newAssistant1: assistant1ProfileId,
        newAssistant2: assistant2ProfileId,
      );
    } catch (e) {
      _logError('updatePatrol', e);
      rethrow;
    }
  }

  Future<void> _syncLeadershipRoles({
    required UserProfile currentUser,
    required String troopId,
    required String patrolId,
    String? oldLeader,
    String? oldAssistant1,
    String? oldAssistant2,
    String? newLeader,
    String? newAssistant1,
    String? newAssistant2,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Syncing leadership roles for patrol $patrolId...');
      }

      final roleRepo = RoleRepository();
      final roles = await roleRepo.getAllRoles();

      // Helper to find a role by its unique rank value
      Role? findRoleByRank(int rankValue) {
        try {
          return roles.firstWhere((r) => r.rank == rankValue);
        } catch (_) {
          return null;
        }
      }

      // Rank-based identification as per project definition:
      // - Patrol Leader: 30
      // - Patrol Assistant 1: 25
      // - Patrol Assistant 2: 20
      final leaderRole = findRoleByRank(30);
      final assistant1Role = findRoleByRank(25);
      final assistant2Role = findRoleByRank(20);

      if (kDebugMode) {
        debugPrint('🎭 Identified Roles by Rank:');
        debugPrint('   - Leader (Rank 30): ${leaderRole?.name ?? 'NOT FOUND'}');
        debugPrint(
          '   - Asst 1 (Rank 25): ${assistant1Role?.name ?? 'NOT FOUND'}',
        );
        debugPrint(
          '   - Asst 2 (Rank 20): ${assistant2Role?.name ?? 'NOT FOUND'}',
        );
      }

      final leadershipRoleIds = [
        if (leaderRole != null) leaderRole.id,
        if (assistant1Role != null) assistant1Role.id,
        if (assistant2Role != null) assistant2Role.id,
      ].whereType<String>().toList();

      if (leadershipRoleIds.isEmpty) {
        debugPrint('⚠️ No leadership roles found in DB to sync.');
        return;
      }

      // Map of profileId -> targetLeadershipRole (one of the 3, or null)
      final Map<String, String?> targetLeadershipRoles = {};

      final Set<String> involvedProfiles = {
        if (oldLeader != null) oldLeader,
        if (oldAssistant1 != null) oldAssistant1,
        if (oldAssistant2 != null) oldAssistant2,
        if (newLeader != null) newLeader,
        if (newAssistant1 != null) newAssistant1,
        if (newAssistant2 != null) newAssistant2,
      };

      for (final profileId in involvedProfiles) {
        if (profileId == newLeader && leaderRole != null) {
          targetLeadershipRoles[profileId] = leaderRole.id;
        } else if (profileId == newAssistant1 && assistant1Role != null) {
          targetLeadershipRoles[profileId] = assistant1Role.id;
        } else if (profileId == newAssistant2 && assistant2Role != null) {
          targetLeadershipRoles[profileId] = assistant2Role.id;
        } else {
          targetLeadershipRoles[profileId] = null;
        }
      }

      // Fetch current leadership state from DB for involved users
      final currentRolesResponse = await _supabase
          .from(_profileRolesTable)
          .select('profile_id, role_id')
          .inFilter('profile_id', involvedProfiles.toList())
          .inFilter('role_id', leadershipRoleIds);

      final Map<String, String> currentLeadershipRoles = {};
      for (final row in currentRolesResponse as List) {
        currentLeadershipRoles[row['profile_id'] as String] =
            row['role_id'] as String;
      }

      // Apply changes (Smart update/delete/insert)
      for (final profileId in involvedProfiles) {
        final current = currentLeadershipRoles[profileId];
        final target = targetLeadershipRoles[profileId];

        if (current == target) continue;

        if (current != null && target != null) {
          // UPDATE: User is still a leader but role changed (e.g. Leader -> Ast 1)
          await _supabase
              .from(_profileRolesTable)
              .update({'role_id': target, 'assigned_by': currentUser.id})
              .eq('profile_id', profileId)
              .eq('role_id', current);
          if (kDebugMode) {
            debugPrint(
              '🎭 Updated leadership role for $profileId: $current -> $target',
            );
          }
        } else if (current != null && target == null) {
          // DELETE: User is no longer a leader in any capacity
          await _supabase
              .from(_profileRolesTable)
              .delete()
              .eq('profile_id', profileId)
              .eq('role_id', current);
          if (kDebugMode) {
            debugPrint('🎭 Removed leadership role from $profileId: $current');
          }
        } else if (current == null && target != null) {
          // INSERT: User just became a leader
          await _supabase.from(_profileRolesTable).insert({
            'profile_id': profileId,
            'role_id': target,
            'assigned_by': currentUser.id,
          });
          if (kDebugMode) {
            debugPrint('🎭 Added new leadership role for $profileId: $target');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Leadership roles synced successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Leadership sync error: $e');
      }
      // Non-fatal for the main operation
    }
  }

  Future<void> deletePatrol({
    required UserProfile currentUser,
    required String troopId,
    required String patrolId,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);

      // Identify leadership roles to remove them
      final currentPatrolResponse = await _supabase
          .from(_patrolsTable)
          .select(
            'patrol_leader_profile_id, assistant_1_profile_id, assistant_2_profile_id',
          )
          .eq('id', patrolId)
          .single();

      final roleRepo = RoleRepository();
      final roles = await roleRepo.getAllRoles();

      // Identify leadership roles by their unique ranks (30, 25, 20)
      final leadershipRoleIds = roles
          .where((r) => r.rank == 30 || r.rank == 25 || r.rank == 20)
          .map((r) => r.id)
          .toList();

      if (leadershipRoleIds.isNotEmpty) {
        final leaderProfileIds = [
          currentPatrolResponse['patrol_leader_profile_id'],
          currentPatrolResponse['assistant_1_profile_id'],
          currentPatrolResponse['assistant_2_profile_id'],
        ].where((id) => id != null).cast<String>().toList();

        if (leaderProfileIds.isNotEmpty) {
          // Perform the delete and select the count of deleted rows
          final deletedRows = await _supabase
              .from(_profileRolesTable)
              .delete()
              .inFilter('profile_id', leaderProfileIds)
              .inFilter('role_id', leadershipRoleIds)
              .select('id');

          if (kDebugMode) {
            debugPrint(
              '🎭 Cleaned up ${deletedRows.length} leadership roles for profiles: $leaderProfileIds',
            );
          }
        }
      }

      await _supabase
          .from(_profilesTable)
          .update({'patrol_id': null})
          .eq('signup_troop', troopId)
          .eq('patrol_id', patrolId);

      await _supabase
          .from(_patrolsTable)
          .delete()
          .eq('id', patrolId)
          .eq('troop_id', troopId);
    } catch (e) {
      _logError('deletePatrol', e);
      rethrow;
    }
  }

  Future<void> assignMemberToPatrol({
    required UserProfile currentUser,
    required String troopId,
    required String memberProfileId,
    required String patrolId,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);

      // Check if the member was a leader in their current patrol before moving them
      final memberRows = await _supabase
          .from(_profilesTable)
          .select('patrol_id')
          .eq('id', memberProfileId)
          .maybeSingle();

      final oldPatrolId = memberRows?['patrol_id'] as String?;

      // If they had a patrol and it's different from the new one, clean up leadership
      if (oldPatrolId != null && oldPatrolId != patrolId) {
        await _cleanupLeadershipForRemovedMembers(
          currentUser: currentUser,
          patrolId: oldPatrolId,
          removedMemberIds: {memberProfileId},
        );
      }

      await _supabase
          .from(_profilesTable)
          .update({'patrol_id': patrolId})
          .eq('id', memberProfileId)
          .eq('signup_troop', troopId);
    } catch (e) {
      _logError('assignMemberToPatrol', e);
      rethrow;
    }
  }

  Future<void> unassignMemberFromPatrol({
    required UserProfile currentUser,
    required String troopId,
    required String memberProfileId,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);

      await _supabase
          .from(_profilesTable)
          .update({'patrol_id': null})
          .eq('id', memberProfileId)
          .eq('signup_troop', troopId);
    } catch (e) {
      _logError('unassignMemberFromPatrol', e);
      rethrow;
    }
  }

  Future<void> updatePatrolMembers({
    required UserProfile currentUser,
    required String troopId,
    required String patrolId,
    required List<String> memberIds,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);

      final normalizedIds = memberIds.toSet().toList();

      final currentMembersResponse = await _supabase
          .from(_profilesTable)
          .select('id')
          .eq('signup_troop', troopId)
          .eq('patrol_id', patrolId);

      final currentMemberIds = (currentMembersResponse as List)
          .map((row) => row['id'] as String)
          .toSet();
      final newMemberIds = normalizedIds.toSet();

      final removedMemberIds = currentMemberIds.difference(newMemberIds);

      // Before updating patrol_id, clean up any leadership roles held by
      // members who are being removed from this patrol.
      if (removedMemberIds.isNotEmpty) {
        await _cleanupLeadershipForRemovedMembers(
          currentUser: currentUser,
          patrolId: patrolId,
          removedMemberIds: removedMemberIds,
        );
      }

      if (removedMemberIds.isNotEmpty) {
        await _supabase
            .from(_profilesTable)
            .update({'patrol_id': null})
            .eq('signup_troop', troopId)
            .eq('patrol_id', patrolId)
            .inFilter('id', removedMemberIds.toList());
      }

      if (normalizedIds.isNotEmpty) {
        await _supabase
            .from(_profilesTable)
            .update({'patrol_id': patrolId})
            .eq('signup_troop', troopId)
            .inFilter('id', normalizedIds);
      }
    } catch (e) {
      _logError('updatePatrolMembers', e);
      rethrow;
    }
  }

  /// Cleans up leadership roles for members who are being removed from a patrol.
  ///
  /// For each removed member that held a PL / APL1 / APL2 slot in the patrol:
  /// 1. Clears their slot in the `patrols` table.
  /// 2. Removes their role record from `profile_roles`.
  Future<void> _cleanupLeadershipForRemovedMembers({
    required UserProfile currentUser,
    required String patrolId,
    required Set<String> removedMemberIds,
  }) async {
    try {
      if (removedMemberIds.isEmpty) return;

      // Fetch current leadership state for this patrol
      final patrolRow = await _supabase
          .from(_patrolsTable)
          .select(
            'patrol_leader_profile_id, assistant_1_profile_id, assistant_2_profile_id',
          )
          .eq('id', patrolId)
          .maybeSingle();

      if (patrolRow == null) return;

      final leaderId = patrolRow['patrol_leader_profile_id'] as String?;
      final asst1Id = patrolRow['assistant_1_profile_id'] as String?;
      final asst2Id = patrolRow['assistant_2_profile_id'] as String?;

      // Build a map of slot → profileId for any removed member holding a leadership slot
      final Map<String, String?> patchPayload = {};
      final Set<String> affectedProfileIds = {};

      if (leaderId != null && removedMemberIds.contains(leaderId)) {
        patchPayload['patrol_leader_profile_id'] = null;
        affectedProfileIds.add(leaderId);
      }
      if (asst1Id != null && removedMemberIds.contains(asst1Id)) {
        patchPayload['assistant_1_profile_id'] = null;
        affectedProfileIds.add(asst1Id);
      }
      if (asst2Id != null && removedMemberIds.contains(asst2Id)) {
        patchPayload['assistant_2_profile_id'] = null;
        affectedProfileIds.add(asst2Id);
      }

      if (patchPayload.isEmpty) return; // nobody removed was a leader

      // 1. Clear leadership slots in the patrols table
      await _supabase
          .from(_patrolsTable)
          .update(patchPayload)
          .eq('id', patrolId);

      if (kDebugMode) {
        debugPrint(
          '🧹 Cleared leadership slots for patrol $patrolId: $patchPayload',
        );
      }

      // 2. Remove their leadership role records from profile_roles
      final roleRepo = RoleRepository();
      final roles = await roleRepo.getAllRoles();
      final leadershipRoleIds = roles
          .where((r) => r.rank == 30 || r.rank == 25 || r.rank == 20)
          .map((r) => r.id)
          .whereType<String>()
          .toList();

      if (leadershipRoleIds.isNotEmpty) {
        final deleted = await _supabase
            .from(_profileRolesTable)
            .delete()
            .inFilter('profile_id', affectedProfileIds.toList())
            .inFilter('role_id', leadershipRoleIds)
            .select('id');

        if (kDebugMode) {
          debugPrint(
            '🧹 Removed ${deleted.length} leadership profile_roles for: $affectedProfileIds',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ _cleanupLeadershipForRemovedMembers error (non-fatal): $e',
        );
      }
      // Non-fatal: don't rethrow, the member move itself is the primary operation
    }
  }

  Future<void> _assertPatrolNameAvailable({
    required String troopId,
    required String name,
    String? excludePatrolId,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Patrol name is required');
    }

    final response = await _supabase
        .from(_patrolsTable)
        .select('id, name')
        .eq('troop_id', troopId);

    final rows = response as List;
    for (final row in rows) {
      final rowId = row['id'] as String;
      if (excludePatrolId != null && rowId == excludePatrolId) {
        continue;
      }

      final existingName = (row['name'] as String?)?.trim().toLowerCase();
      if (existingName == trimmedName.toLowerCase()) {
        throw Exception(
          'A patrol with this name already exists in the selected troop',
        );
      }
    }
  }

  void _validateTroopAccess({
    required UserProfile currentUser,
    required String troopId,
  }) {
    if (currentUser.hasSystemWideAccess) {
      return;
    }

    if (currentUser.managedTroopId == null) {
      throw Exception('No managed troop configured for your role');
    }

    if (currentUser.managedTroopId != troopId) {
      throw Exception('Access denied for the selected troop');
    }
  }

  void _logError(String operation, Object error) {
    if (kDebugMode) {
      debugPrint('❌ PatrolsManagementService.$operation error: $error');
    }
  }
}
