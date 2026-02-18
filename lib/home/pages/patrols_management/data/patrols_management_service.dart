import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../auth/models/user_profile.dart';
import '../../../../core/data/scoped_service_mixin.dart';
import 'models/patrol.dart';
import 'models/troop_member.dart';

class PatrolsManagementService with ScopedServiceMixin {
  static const String _patrolsTable = 'patrols';
  static const String _profilesTable = 'profiles';

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
      throw Exception('No troop is assigned to your role, please contact support for assistance');
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
          .select('id, troop_id, name, description, patrol_leader_profile_id, created_at')
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
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);

      final response = await _supabase
          .from(_profilesTable)
          .select('id, first_name, middle_name, last_name, phone, signup_troop, patrol_id')
          .eq('approved', true)
          .eq('signup_troop', troopId)
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
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);
      await _assertPatrolNameAvailable(
        troopId: troopId,
        name: name,
      );

      final payload = {
        'troop_id': troopId,
        'name': name.trim(),
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'patrol_leader_profile_id': patrolLeaderProfileId,
      };

      final response = await _supabase
          .from(_patrolsTable)
          .insert(payload)
          .select('id, troop_id, name, description, patrol_leader_profile_id, created_at')
          .single();

      return Patrol.fromJson(response);
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
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);
      await _assertPatrolNameAvailable(
        troopId: troopId,
        name: name,
        excludePatrolId: patrolId,
      );

      await _supabase
          .from(_patrolsTable)
          .update({
            'name': name.trim(),
            'description': description?.trim().isEmpty == true ? null : description?.trim(),
            'patrol_leader_profile_id': patrolLeaderProfileId,
          })
          .eq('id', patrolId)
          .eq('troop_id', troopId);
    } catch (e) {
      _logError('updatePatrol', e);
      rethrow;
    }
  }

  Future<void> deletePatrol({
    required UserProfile currentUser,
    required String troopId,
    required String patrolId,
  }) async {
    try {
      _validateTroopAccess(currentUser: currentUser, troopId: troopId);

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
        throw Exception('A patrol with this name already exists in the selected troop');
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
    debugPrint('❌ PatrolsManagementService.$operation error: $error');
  }
}
