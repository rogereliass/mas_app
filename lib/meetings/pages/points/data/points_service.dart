import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:masapp/meetings/pages/meeting_creation/data/meetings_service.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

import 'models/patrol_option.dart';
import 'models/point_category.dart';
import 'models/point_entry.dart';

/// Service responsible for all Supabase operations related to meeting points.
class PointsService {
  final SupabaseClient _supabase;
  final MeetingsService _meetingsService;

  PointsService(this._supabase, {MeetingsService? meetingsService})
    : _meetingsService = meetingsService ?? MeetingsService(_supabase);

  factory PointsService.instance() {
    return PointsService(Supabase.instance.client);
  }

  Future<List<Meeting>> fetchMeetings({
    required String seasonId,
    required String troopId,
  }) {
    return _meetingsService.fetchMeetings(seasonId: seasonId, troopId: troopId);
  }

  Future<List<PatrolOption>> fetchPatrols({required String troopId}) async {
    try {
      final result = await _supabase
          .from('patrols')
          .select('id, troop_id, name')
          .eq('troop_id', troopId)
          .order('name', ascending: true);

      return (result as List)
          .map((row) => PatrolOption.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('PointsService.fetchPatrols: $e');
    }
  }

  Future<List<PointCategory>> fetchCategories({required String troopId}) async {
    try {
      final result = await _supabase
          .from('point_categories')
          .select('id, slug, name, description, troop_id')
          .or('troop_id.is.null,troop_id.eq.$troopId')
          .order('name', ascending: true);

      return (result as List)
          .map((row) => PointCategory.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('PointsService.fetchCategories: $e');
    }
  }

  Future<PointCategory> createTroopCategory({
    required int actorRoleRank,
    required String troopId,
    required String name,
    String? description,
  }) async {
    try {
      _assertCanManageCategories(actorRoleRank);
      _assertTroopContextAvailable(troopId);

      final normalizedName = _normalizeCategoryName(name);
      final normalizedDescription = _normalizeDescription(description);

      await _assertNoCategoryConflicts(troopId: troopId, name: normalizedName);

      final row = await _supabase
          .from('point_categories')
          .insert({
            'name': normalizedName,
            'description': normalizedDescription,
            'troop_id': troopId,
          })
          .select('id, slug, name, description, troop_id')
          .single();

      return PointCategory.fromJson(row);
    } catch (e) {
      throw Exception('PointsService.createTroopCategory: $e');
    }
  }

  Future<PointCategory> updateTroopCategory({
    required int actorRoleRank,
    required String troopId,
    required String categoryId,
    required String name,
    String? description,
  }) async {
    try {
      _assertCanManageCategories(actorRoleRank);
      _assertTroopContextAvailable(troopId);

      final existing = await _supabase
          .from('point_categories')
          .select('id, troop_id')
          .eq('id', categoryId)
          .maybeSingle();

      if (existing == null) {
        throw Exception('Selected category does not exist.');
      }

      final existingTroopId = existing['troop_id'] as String?;
      if (existingTroopId == null) {
        throw Exception('Global categories are read-only in this flow.');
      }
      if (existingTroopId != troopId) {
        throw Exception('Selected category is outside your troop scope.');
      }

      final normalizedName = _normalizeCategoryName(name);
      final normalizedDescription = _normalizeDescription(description);

      await _assertNoCategoryConflicts(
        troopId: troopId,
        name: normalizedName,
        excludeCategoryId: categoryId,
      );

      final row = await _supabase
          .from('point_categories')
          .update({
            'name': normalizedName,
            'description': normalizedDescription,
          })
          .eq('id', categoryId)
          .eq('troop_id', troopId)
          .select('id, slug, name, description, troop_id')
          .maybeSingle();

      if (row == null) {
        throw Exception('Category could not be updated.');
      }

      return PointCategory.fromJson(row);
    } catch (e) {
      throw Exception('PointsService.updateTroopCategory: $e');
    }
  }

  Future<List<PointEntry>> fetchPointsForMeeting({
    required String meetingId,
  }) async {
    try {
      final joinedRows = await _fetchPointsWithJoins(meetingId: meetingId);
      return _toPointEntries(joinedRows);
    } catch (_) {
      try {
        final fallbackRows = await _fetchPointsWithLookupFallback(
          meetingId: meetingId,
        );
        return _toPointEntries(fallbackRows);
      } catch (e) {
        throw Exception('PointsService.fetchPointsForMeeting: $e');
      }
    }
  }

  Future<PointEntry> createPoint({
    required int actorRoleRank,
    required String troopId,
    required String meetingId,
    required String patrolId,
    required String categoryId,
    required int value,
    String? reason,
    required String awardedByProfileId,
  }) async {
    try {
      _assertCanManage(actorRoleRank);
      await _validateWriteScope(
        troopId: troopId,
        meetingId: meetingId,
        patrolId: patrolId,
        categoryId: categoryId,
      );

      final row = await _supabase
          .from('points')
          .insert({
            'meeting_id': meetingId,
            'patrol_id': patrolId,
            'category_id': categoryId,
            'value': value,
            'reason': _normalizeReason(reason),
            'awarded_by_profile_id': awardedByProfileId,
            'approved': false,
          })
          .select('id')
          .single();

      final pointId = row['id'] as String?;
      if (pointId == null || pointId.isEmpty) {
        throw Exception('Point created but id was not returned.');
      }

      return _fetchPointById(pointId);
    } catch (e) {
      throw Exception('PointsService.createPoint: $e');
    }
  }

  Future<PointEntry> updatePoint({
    required int actorRoleRank,
    required String troopId,
    required String pointId,
    required String meetingId,
    required String patrolId,
    required String categoryId,
    required int value,
    String? reason,
  }) async {
    try {
      _assertCanManage(actorRoleRank);
      await _assertPointBelongsToMeeting(
        pointId: pointId,
        meetingId: meetingId,
      );
      await _validateWriteScope(
        troopId: troopId,
        meetingId: meetingId,
        patrolId: patrolId,
        categoryId: categoryId,
      );

      await _supabase
          .from('points')
          .update({
            'patrol_id': patrolId,
            'category_id': categoryId,
            'value': value,
            'reason': _normalizeReason(reason),
          })
          .eq('id', pointId)
          .eq('meeting_id', meetingId);

      return _fetchPointById(pointId);
    } catch (e) {
      throw Exception('PointsService.updatePoint: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPointsWithJoins({
    required String meetingId,
  }) async {
    final result = await _supabase
        .from('points')
        .select('''
          id,
          meeting_id,
          patrol_id,
          category_id,
          value,
          reason,
          awarded_by_profile_id,
          approved,
          approved_by_profile_id,
          approved_at,
          created_at,
          patrol:patrols!points_patrol_id_fkey(id, name, troop_id),
          category:point_categories!points_category_id_fkey(
            id,
            slug,
            name,
            description,
            troop_id
          ),
          awarded_by:profiles!points_awarded_by_profile_id_fkey(
            id,
            first_name,
            middle_name,
            last_name
          )
        ''')
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: false);

    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchPointsWithLookupFallback({
    required String meetingId,
  }) async {
    final result = await _supabase
        .from('points')
        .select(
          'id, meeting_id, patrol_id, category_id, value, reason, awarded_by_profile_id, approved, approved_by_profile_id, approved_at, created_at',
        )
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: false);

    final rows = (result as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return rows;

    final patrolIds = rows
        .map((row) => row['patrol_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final categoryIds = rows
        .map((row) => row['category_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final profileIds = rows
        .map((row) => row['awarded_by_profile_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final patrolMap = await _fetchMapById(
      table: 'patrols',
      ids: patrolIds,
      select: 'id, name, troop_id',
    );
    final categoryMap = await _fetchMapById(
      table: 'point_categories',
      ids: categoryIds,
      select: 'id, slug, name, description, troop_id',
    );
    final profileMap = await _fetchMapById(
      table: 'profiles',
      ids: profileIds,
      select: 'id, first_name, middle_name, last_name',
    );

    return rows.map((row) {
      return {
        ...row,
        'patrol': patrolMap[row['patrol_id']],
        'category': categoryMap[row['category_id']],
        'awarded_by': profileMap[row['awarded_by_profile_id']],
      };
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _fetchMapById({
    required String table,
    required List<String> ids,
    required String select,
  }) async {
    if (ids.isEmpty) return {};

    final result = await _supabase
        .from(table)
        .select(select)
        .inFilter('id', ids);

    final rows = (result as List).cast<Map<String, dynamic>>();
    final map = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null || id.isEmpty) continue;
      map[id] = row;
    }
    return map;
  }

  Future<PointEntry> _fetchPointById(String pointId) async {
    try {
      final result = await _supabase
          .from('points')
          .select('''
            id,
            meeting_id,
            patrol_id,
            category_id,
            value,
            reason,
            awarded_by_profile_id,
            approved,
            approved_by_profile_id,
            approved_at,
            created_at,
            patrol:patrols!points_patrol_id_fkey(id, name, troop_id),
            category:point_categories!points_category_id_fkey(
              id,
              slug,
              name,
              description,
              troop_id
            ),
            awarded_by:profiles!points_awarded_by_profile_id_fkey(
              id,
              first_name,
              middle_name,
              last_name
            )
          ''')
          .eq('id', pointId)
          .maybeSingle();

      if (result == null) {
        throw Exception('Point not found after write.');
      }

      return PointEntry.fromJson(result);
    } catch (_) {
      final baseRow = await _supabase
          .from('points')
          .select(
            'id, meeting_id, patrol_id, category_id, value, reason, awarded_by_profile_id, approved, approved_by_profile_id, approved_at, created_at',
          )
          .eq('id', pointId)
          .maybeSingle();

      if (baseRow == null) {
        throw Exception('Point not found after write.');
      }

      final rows = await _fetchPointsWithLookupFallback(
        meetingId: baseRow['meeting_id'] as String,
      );
      final row = rows.firstWhere(
        (item) => item['id'] == pointId,
        orElse: () => baseRow,
      );
      return PointEntry.fromJson(row);
    }
  }

  List<PointEntry> _toPointEntries(List<Map<String, dynamic>> rows) {
    final dedupedById = <String, PointEntry>{
      for (final row in rows)
        if ((row['id'] as String?) != null)
          row['id'] as String: PointEntry.fromJson(row),
    };

    final entries = dedupedById.values.toList()
      ..sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));

    return entries;
  }

  Future<void> _validateWriteScope({
    required String troopId,
    required String meetingId,
    required String patrolId,
    required String categoryId,
  }) async {
    await _assertMeetingBelongsToTroop(meetingId: meetingId, troopId: troopId);
    await _assertPatrolBelongsToTroop(patrolId: patrolId, troopId: troopId);
    await _assertCategoryInScope(categoryId: categoryId, troopId: troopId);
  }

  Future<void> _assertMeetingBelongsToTroop({
    required String meetingId,
    required String troopId,
  }) async {
    final row = await _supabase
        .from('meetings')
        .select('id, troop_id')
        .eq('id', meetingId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Meeting does not exist.');
    }

    if (row['troop_id'] != troopId) {
      throw Exception('Meeting is outside your troop scope.');
    }
  }

  Future<void> _assertPatrolBelongsToTroop({
    required String patrolId,
    required String troopId,
  }) async {
    final row = await _supabase
        .from('patrols')
        .select('id, troop_id')
        .eq('id', patrolId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Selected patrol does not exist.');
    }

    if (row['troop_id'] != troopId) {
      throw Exception('Selected patrol is outside your troop scope.');
    }
  }

  Future<void> _assertCategoryInScope({
    required String categoryId,
    required String troopId,
  }) async {
    final row = await _supabase
        .from('point_categories')
        .select('id, troop_id')
        .eq('id', categoryId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Selected category does not exist.');
    }

    final categoryTroopId = row['troop_id'] as String?;
    if (categoryTroopId != null && categoryTroopId != troopId) {
      throw Exception('Selected category is outside your troop scope.');
    }
  }

  Future<void> _assertPointBelongsToMeeting({
    required String pointId,
    required String meetingId,
  }) async {
    final row = await _supabase
        .from('points')
        .select('id, meeting_id')
        .eq('id', pointId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Point entry not found.');
    }

    if (row['meeting_id'] != meetingId) {
      throw Exception('Point entry does not belong to the selected meeting.');
    }
  }

  void _assertCanManage(int actorRoleRank) {
    if (actorRoleRank < 60) {
      throw Exception('You do not have permission to manage points.');
    }
  }

  void _assertCanManageCategories(int actorRoleRank) {
    if (actorRoleRank < 60) {
      throw Exception('You do not have permission to manage categories.');
    }
  }

  void _assertTroopContextAvailable(String troopId) {
    if (troopId.trim().isEmpty) {
      throw Exception('Could not determine troop context for this action.');
    }
  }

  Future<void> _assertNoCategoryConflicts({
    required String troopId,
    required String name,
    String? excludeCategoryId,
  }) async {
    final rows = await _supabase
        .from('point_categories')
        .select('id, name, slug')
        .eq('troop_id', troopId);

    for (final rawRow in rows as List) {
      final row = rawRow as Map<String, dynamic>;
      final rowId = row['id'] as String?;
      if (rowId == null || rowId.isEmpty) continue;
      if (excludeCategoryId != null && rowId == excludeCategoryId) {
        continue;
      }

      final existingName = (row['name'] as String? ?? '').trim().toLowerCase();
      if (existingName == name.toLowerCase()) {
        throw Exception('A category with this name already exists.');
      }
    }
  }

  String _normalizeCategoryName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw Exception('Category name is required.');
    }
    return normalized;
  }

  String? _normalizeDescription(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  String? _normalizeReason(String? reason) {
    final trimmed = reason?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
