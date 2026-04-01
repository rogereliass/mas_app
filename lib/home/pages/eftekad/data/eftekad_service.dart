import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../auth/models/user_profile.dart';
import '../../../../core/data/scoped_service_mixin.dart';
import '../../patrols_management/data/models/patrol.dart';
import '../../patrols_management/data/models/troop_member.dart';
import '../../patrols_management/data/patrols_management_service.dart';
import 'models/eftekad_member.dart';
import 'models/eftekad_members_snapshot.dart';
import 'models/eftekad_record.dart';

class EftekadService with ScopedServiceMixin {
  EftekadService(this._supabase, this._patrolsService);

  static const String _recordsTable = 'eftekad_records';
  static const String _profilesTable = 'profiles';

  final SupabaseClient _supabase;
  final PatrolsManagementService _patrolsService;

  factory EftekadService.instance() {
    return EftekadService(
      Supabase.instance.client,
      PatrolsManagementService.instance(),
    );
  }

  String resolveScopedTroopId({
    required UserProfile currentUser,
    String? selectedTroopId,
  }) {
    return _patrolsService.resolveScopedTroopId(
      currentUser: currentUser,
      selectedTroopId: selectedTroopId,
    );
  }

  Future<EftekadMembersSnapshot> fetchMembersSnapshot({
    required UserProfile currentUser,
    required String troopId,
    bool includePending = true,
  }) async {
    final results = await Future.wait<dynamic>([
      _patrolsService.fetchPatrols(currentUser: currentUser, troopId: troopId),
      _patrolsService.fetchTroopMembers(
        currentUser: currentUser,
        troopId: troopId,
        includePending: includePending,
      ),
    ]);

    final patrols = (results[0] as List<Patrol>);
    final members = (results[1] as List<TroopMember>);

    final patrolById = {for (final patrol in patrols) patrol.id: patrol};

    final normalized =
        members
            .map((member) {
              final patrol = member.patrolId != null
                  ? patrolById[member.patrolId!]
                  : null;

              var priority = 3;
              if (patrol != null) {
                if (member.id == patrol.patrolLeaderProfileId) {
                  priority = 0;
                } else if (member.id == patrol.assistant1ProfileId) {
                  priority = 1;
                } else if (member.id == patrol.assistant2ProfileId) {
                  priority = 2;
                }
              }

              return EftekadMember(
                id: member.id,
                troopId: member.troopId,
                firstName: member.firstName,
                middleName: member.middleName,
                lastName: member.lastName,
                phone: member.phone,
                address: member.address,
                patrolId: member.patrolId,
                patrolName: patrol?.name,
                approved: member.approved,
                patrolOrderPriority: priority,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final aHasPatrol = a.patrolName != null && a.patrolName!.isNotEmpty;
            final bHasPatrol = b.patrolName != null && b.patrolName!.isNotEmpty;

            if (aHasPatrol != bHasPatrol) {
              return aHasPatrol ? -1 : 1;
            }

            final patrolCompare = (a.patrolName ?? '').toLowerCase().compareTo(
              (b.patrolName ?? '').toLowerCase(),
            );
            if (patrolCompare != 0) {
              return patrolCompare;
            }

            final priorityCompare = a.patrolOrderPriority.compareTo(
              b.patrolOrderPriority,
            );
            if (priorityCompare != 0) {
              return priorityCompare;
            }

            return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          });

    return EftekadMembersSnapshot(patrols: patrols, members: normalized);
  }

  Future<Map<String, DateTime>> fetchLastContactByProfileIds(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty) {
      return <String, DateTime>{};
    }

    final response = await _supabase
        .from(_recordsTable)
        .select('profile_id, created_at')
        .inFilter('profile_id', profileIds)
        .order('created_at', ascending: false);

    final lastContactByProfile = <String, DateTime>{};

    for (final row in response as List) {
      final map = row as Map<String, dynamic>;
      final profileId = map['profile_id'] as String?;
      final createdAtRaw = map['created_at'] as String?;
      if (profileId == null || createdAtRaw == null) {
        continue;
      }
      if (lastContactByProfile.containsKey(profileId)) {
        continue;
      }
      final createdAt = DateTime.tryParse(createdAtRaw);
      if (createdAt != null) {
        lastContactByProfile[profileId] = createdAt;
      }
    }

    return lastContactByProfile;
  }

  Future<List<EftekadRecord>> fetchRecordsForProfile({
    required String profileId,
    required int limit,
    required int offset,
  }) async {
    final response = await _supabase
        .from(_recordsTable)
        .select()
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((row) => EftekadRecord.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> upsertRecord({
    required UserProfile currentUser,
    required EftekadRecord record,
  }) async {
    await _assertTargetProfileAccess(
      currentUser: currentUser,
      targetProfileId: record.profileId,
    );

    await _supabase
        .from(_recordsTable)
        .upsert(
          record.toInsertJson(),
          onConflict: 'id',
          ignoreDuplicates: true,
        );
  }

  Future<void> _assertTargetProfileAccess({
    required UserProfile currentUser,
    required String targetProfileId,
  }) async {
    final target = await _supabase
        .from(_profilesTable)
        .select('id, signup_troop')
        .eq('id', targetProfileId)
        .maybeSingle();

    if (target == null) {
      throw Exception('Target profile not found.');
    }

    final troopId = target['signup_troop'] as String?;
    if (troopId == null || troopId.isEmpty) {
      throw Exception('Target profile is missing troop assignment.');
    }

    if (currentUser.hasSystemWideAccess) {
      return;
    }

    if (!canAccessTroop(currentUser, troopId)) {
      throw Exception('Access denied for target profile troop.');
    }
  }
}
