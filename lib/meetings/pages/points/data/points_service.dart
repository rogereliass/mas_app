import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:masapp/core/constants/cache_ttl.dart';
import 'package:masapp/core/constants/offline_policy.dart';
import 'package:masapp/core/data/persistent_query_cache.dart';
import 'package:masapp/core/utils/ttl_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:masapp/meetings/pages/meeting_creation/data/meetings_service.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

import 'models/patrol_option.dart';
import 'models/point_category.dart';
import 'models/point_entry.dart';

/// Service responsible for all Supabase operations related to meeting points.
class PointsService {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final SupabaseClient _supabase;
  final MeetingsService _meetingsService;

  static final TtlCache<String, List<PointEntry>> _pointsByMeetingCache =
      TtlCache();
  static final TtlCache<String, List<PatrolOption>> _patrolsCache = TtlCache();
  static final TtlCache<String, List<PointCategory>> _categoriesCache =
      TtlCache();
  static final TtlCache<String, bool> _pointsVisibilityCache = TtlCache();
  static final Map<String, DateTime> _pointsLastUpdated = <String, DateTime>{};

    final Map<String, Future<List<PatrolOption>>> _patrolRefreshInFlight =
      <String, Future<List<PatrolOption>>>{};
    final Map<String, Future<List<PointCategory>>> _categoryRefreshInFlight =
      <String, Future<List<PointCategory>>>{};
    final Map<String, Future<List<PointEntry>>> _pointsRefreshInFlight =
      <String, Future<List<PointEntry>>>{};

  PointsService(this._supabase, {MeetingsService? meetingsService})
    : _meetingsService = meetingsService ?? MeetingsService(_supabase);

  factory PointsService.instance() {
    return PointsService(Supabase.instance.client);
  }

  /// Clears in-memory points caches.
  void clearCache() {
    _pointsByMeetingCache.clear();
    _patrolsCache.clear();
    _categoriesCache.clear();
    _pointsVisibilityCache.clear();
    _pointsLastUpdated.clear();
  }

  DateTime? getPointsLastUpdated(String meetingId) {
    return _pointsLastUpdated[meetingId.trim()];
  }

  Future<List<Meeting>> fetchMeetings({
    required String seasonId,
    required String troopId,
  }) {
    return _meetingsService.fetchMeetings(seasonId: seasonId, troopId: troopId);
  }

  Future<List<PatrolOption>> fetchPatrols({required String troopId}) async {
    final cacheKey = troopId.trim();
    final cached = _patrolsCache.get(cacheKey);
    if (cached != null) {
      _logDataSource(
        operation: 'fetchPatrols',
        source: 'LOCAL_CACHE_HIT',
        scope: cacheKey,
      );
      unawaited(() async {
        try {
          await _refreshPatrolsCache(troopId: troopId);
        } catch (_) {
          // Keep cached patrols if background refresh fails.
        }
      }());
      return cached;
    }

    final persisted = await PersistentQueryCache.read<List<PatrolOption>>(
      key: _persistedPatrolsKey(cacheKey),
      parser: _parsePatrolOptionList,
    );
    if (persisted != null) {
      _logDataSource(
        operation: 'fetchPatrols',
        source: 'DISK_CACHE_HIT',
        scope: cacheKey,
      );
      _patrolsCache.set(cacheKey, persisted.data, CacheTtl.patrols);
      unawaited(() async {
        try {
          await _refreshPatrolsCache(troopId: troopId);
        } catch (_) {
          // Keep persisted patrol list if background refresh fails.
        }
      }());
      return persisted.data;
    }

    final stale = _patrolsCache.get(cacheKey, ignoreExpiry: true);
    try {
      return await _refreshPatrolsCache(troopId: troopId);
    } catch (e) {
      if (stale != null) {
        _logDataSource(
          operation: 'fetchPatrols',
          source: 'OFFLINE_STALE_CACHE',
          scope: cacheKey,
        );
        return stale;
      }
      throw Exception('PointsService.fetchPatrols: $e');
    }
  }

  Future<List<PointCategory>> fetchCategories({required String troopId}) async {
    final cacheKey = troopId.trim();
    final cached = _categoriesCache.get(cacheKey);
    if (cached != null) {
      _logDataSource(
        operation: 'fetchCategories',
        source: 'LOCAL_CACHE_HIT',
        scope: cacheKey,
      );
      unawaited(() async {
        try {
          await _refreshCategoriesCache(troopId: troopId);
        } catch (_) {
          // Keep cached categories if background refresh fails.
        }
      }());
      return cached;
    }

    final persisted = await PersistentQueryCache.read<List<PointCategory>>(
      key: _persistedCategoriesKey(cacheKey),
      parser: _parsePointCategoryList,
    );
    if (persisted != null) {
      _logDataSource(
        operation: 'fetchCategories',
        source: 'DISK_CACHE_HIT',
        scope: cacheKey,
      );
      _categoriesCache.set(cacheKey, persisted.data, CacheTtl.pointCategories);
      unawaited(() async {
        try {
          await _refreshCategoriesCache(troopId: troopId);
        } catch (_) {
          // Keep persisted category list if background refresh fails.
        }
      }());
      return persisted.data;
    }

    final stale = _categoriesCache.get(cacheKey, ignoreExpiry: true);
    try {
      return await _refreshCategoriesCache(troopId: troopId);
    } catch (e) {
      if (stale != null) {
        _logDataSource(
          operation: 'fetchCategories',
          source: 'OFFLINE_STALE_CACHE',
          scope: cacheKey,
        );
        return stale;
      }
      throw Exception('PointsService.fetchCategories: $e');
    }
  }

  Future<bool> fetchTroopPointsHidden({required String troopId}) async {
    final cacheKey = troopId.trim();
    final cached = _pointsVisibilityCache.get(cacheKey);
    if (cached != null) {
      _logDataSource(
        operation: 'fetchTroopPointsHidden',
        source: 'LOCAL_CACHE_HIT',
        scope: cacheKey,
      );
      unawaited(() async {
        try {
          await _refreshTroopPointsHiddenCache(troopId: troopId);
        } catch (_) {
          // Keep cached visibility state if background refresh fails.
        }
      }());
      return cached;
    }

    final persisted = await PersistentQueryCache.read<bool>(
      key: _persistedVisibilityKey(cacheKey),
      parser: (payload) => payload is bool ? payload : null,
    );
    if (persisted != null) {
      _logDataSource(
        operation: 'fetchTroopPointsHidden',
        source: 'DISK_CACHE_HIT',
        scope: cacheKey,
      );
      _pointsVisibilityCache.set(
        cacheKey,
        persisted.data,
        CacheTtl.troopPointsVisibility,
      );
      unawaited(() async {
        try {
          await _refreshTroopPointsHiddenCache(troopId: troopId);
        } catch (_) {
          // Keep persisted visibility state if background refresh fails.
        }
      }());
      return persisted.data;
    }

    final stale = _pointsVisibilityCache.get(cacheKey, ignoreExpiry: true);
    try {
      return await _refreshTroopPointsHiddenCache(troopId: troopId);
    } catch (e) {
      if (stale != null) {
        _logDataSource(
          operation: 'fetchTroopPointsHidden',
          source: 'OFFLINE_STALE_CACHE',
          scope: cacheKey,
        );
        return stale;
      }
      throw Exception('PointsService.fetchTroopPointsHidden: $e');
    }
  }

  Future<void> updateTroopPointsVisibility({
    required int actorRoleRank,
    required String troopId,
    required bool pointsHidden,
  }) async {
    try {
      _assertCanManage(actorRoleRank);
      _assertTroopContextAvailable(troopId);

        await _withTimeout(_supabase
          .from('troops')
          .update({'points_hidden': pointsHidden})
          .eq('id', troopId));

      _pointsVisibilityCache.set(
        troopId.trim(),
        pointsHidden,
        CacheTtl.troopPointsVisibility,
      );
      await PersistentQueryCache.write(
        key: _persistedVisibilityKey(troopId.trim()),
        payload: pointsHidden,
        ttl: CacheTtl.troopPointsVisibility,
      );
    } catch (e) {
      throw Exception('PointsService.updateTroopPointsVisibility: $e');
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

      final row = await _withTimeout(_supabase
          .from('point_categories')
          .insert({
            'name': normalizedName,
            'description': normalizedDescription,
            'troop_id': troopId,
          })
          .select('id, slug, name, description, troop_id')
          .single());

      _categoriesCache.invalidate(troopId.trim());
      await PersistentQueryCache.invalidate(_persistedCategoriesKey(troopId.trim()));

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

        final existing = await _withTimeout(_supabase
          .from('point_categories')
          .select('id, troop_id')
          .eq('id', categoryId)
          .maybeSingle());

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

      final row = await _withTimeout(_supabase
          .from('point_categories')
          .update({
            'name': normalizedName,
            'description': normalizedDescription,
          })
          .eq('id', categoryId)
          .eq('troop_id', troopId)
          .select('id, slug, name, description, troop_id')
          .maybeSingle());

      if (row == null) {
        throw Exception('Category could not be updated.');
      }

      _categoriesCache.invalidate(troopId.trim());
      _pointsByMeetingCache.clear();
      await PersistentQueryCache.invalidate(_persistedCategoriesKey(troopId.trim()));

      return PointCategory.fromJson(row);
    } catch (e) {
      throw Exception('PointsService.updateTroopCategory: $e');
    }
  }

  Future<List<PointEntry>> fetchPointsForSeason(
    String troopId,
    String seasonId,
  ) async {
    final cacheKey = _persistedSeasonPointsKey(troopId.trim(), seasonId.trim());
    final persisted = await PersistentQueryCache.read<List<PointEntry>>(
      key: cacheKey,
      parser: _parsePointEntryList,
    );

    try {
      final meetings = await fetchMeetings(seasonId: seasonId, troopId: troopId);
      if (meetings.isEmpty) return [];

      final meetingIds = meetings.map((m) => m.id).toList();

      List<Map<String, dynamic>> rawPoints;
      try {
        final result = await _withTimeout(_supabase
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
            .inFilter('meeting_id', meetingIds)
            .order('created_at', ascending: false));
            
        rawPoints = (result as List).cast<Map<String, dynamic>>();
      } catch (_) {
        final result = await _withTimeout(_supabase
            .from('points')
            .select(
              'id, meeting_id, patrol_id, category_id, value, reason, awarded_by_profile_id, approved, approved_by_profile_id, approved_at, created_at',
            )
            .inFilter('meeting_id', meetingIds)
            .order('created_at', ascending: false));

        final rows = (result as List).cast<Map<String, dynamic>>();
        if (rows.isEmpty) return [];

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

        rawPoints = rows.map((row) {
          return {
            ...row,
            'patrol': patrolMap[row['patrol_id']],
            'category': categoryMap[row['category_id']],
            'awarded_by': profileMap[row['awarded_by_profile_id']],
          };
        }).toList();
      }

      final entries = _toPointEntries(rawPoints);
      await PersistentQueryCache.write(
        key: cacheKey,
        payload: entries.map(_pointEntryToJson).toList(growable: false),
        ttl: CacheTtl.meetingsList,
      );
      return entries;
    } catch (e) {
      if (persisted != null) {
        _logDataSource(
          operation: 'fetchPointsForSeason',
          source: 'DISK_CACHE_HIT',
          scope: cacheKey,
        );
        return persisted.data;
      }
      throw Exception('PointsService.fetchPointsForSeason: $e');
    }
  }

  Future<List<PointEntry>> fetchPointsForMeeting({
    required String meetingId,
  }) async {
    final cacheKey = meetingId.trim();
    final cached = _pointsByMeetingCache.get(cacheKey);
    if (cached != null) {
      _logDataSource(
        operation: 'fetchPointsForMeeting',
        source: 'LOCAL_CACHE_HIT',
        scope: cacheKey,
      );
      unawaited(() async {
        try {
          await _refreshPointsForMeetingCache(meetingId: meetingId);
        } catch (_) {
          // Keep cached points if background refresh fails.
        }
      }());
      return cached;
    }

    final persisted = await PersistentQueryCache.read<List<PointEntry>>(
      key: _persistedPointsByMeetingKey(cacheKey),
      parser: _parsePointEntryList,
    );
    if (persisted != null) {
      _logDataSource(
        operation: 'fetchPointsForMeeting',
        source: 'DISK_CACHE_HIT',
        scope: cacheKey,
      );
      _pointsByMeetingCache.set(cacheKey, persisted.data, CacheTtl.meetingPoints);
      _pointsLastUpdated[cacheKey] = persisted.savedAt ?? DateTime.now();
      unawaited(() async {
        try {
          await _refreshPointsForMeetingCache(meetingId: meetingId);
        } catch (_) {
          // Keep persisted points list if background refresh fails.
        }
      }());
      return persisted.data;
    }

    final stale = _pointsByMeetingCache.get(cacheKey, ignoreExpiry: true);
    try {
      return await _refreshPointsForMeetingCache(meetingId: meetingId);
    } catch (e) {
      if (stale != null) {
        _logDataSource(
          operation: 'fetchPointsForMeeting',
          source: 'OFFLINE_STALE_CACHE',
          scope: cacheKey,
        );
        return stale;
      }
      throw Exception(
        'PointsService.fetchPointsForMeeting: $e',
      );
    }
  }

  Future<List<PointEntry>> refreshPointsForMeeting({
    required String meetingId,
  }) {
    return _refreshPointsForMeetingCache(meetingId: meetingId);
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

      final row = await _withTimeout(_supabase
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
          .single());

      final pointId = row['id'] as String?;
      if (pointId == null || pointId.isEmpty) {
        throw Exception('Point created but id was not returned.');
      }

      _pointsByMeetingCache.invalidate(meetingId.trim());
      await PersistentQueryCache.invalidate(
        _persistedPointsByMeetingKey(meetingId.trim()),
      );

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

      await _withTimeout(_supabase
          .from('points')
          .update({
            'patrol_id': patrolId,
            'category_id': categoryId,
            'value': value,
            'reason': _normalizeReason(reason),
          })
          .eq('id', pointId)
          .eq('meeting_id', meetingId));

      _pointsByMeetingCache.invalidate(meetingId.trim());
      await PersistentQueryCache.invalidate(
        _persistedPointsByMeetingKey(meetingId.trim()),
      );

      return _fetchPointById(pointId);
    } catch (e) {
      throw Exception('PointsService.updatePoint: $e');
    }
  }

  Future<List<PatrolOption>> _refreshPatrolsCache({
    required String troopId,
  }) {
    final cacheKey = troopId.trim();
    final inFlight = _patrolRefreshInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshPatrolsCacheInternal(troopId: troopId);
    _patrolRefreshInFlight[cacheKey] = future;
    return future.whenComplete(() => _patrolRefreshInFlight.remove(cacheKey));
  }

  Future<List<PatrolOption>> _refreshPatrolsCacheInternal({
    required String troopId,
  }) async {
    final normalizedTroopId = _normalizeTroopId(troopId);
    _logDataSource(
      operation: 'fetchPatrols',
      source: 'SUPABASE',
      scope: normalizedTroopId,
    );

    final result = await _withTimeout(_supabase
        .from('patrols')
        .select('id, troop_id, name')
        .eq('troop_id', normalizedTroopId)
      .order('name', ascending: true));

    final patrols = (result as List)
        .map((row) => PatrolOption.fromJson(row as Map<String, dynamic>))
        .toList();

    _patrolsCache.set(normalizedTroopId, patrols, CacheTtl.patrols);
    await PersistentQueryCache.write(
      key: _persistedPatrolsKey(normalizedTroopId),
      payload: patrols.map(_patrolToJson).toList(growable: false),
      ttl: CacheTtl.patrols,
    );
    return patrols;
  }

  Future<List<PointCategory>> _refreshCategoriesCache({
    required String troopId,
  }) {
    final cacheKey = troopId.trim();
    final inFlight = _categoryRefreshInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshCategoriesCacheInternal(troopId: troopId);
    _categoryRefreshInFlight[cacheKey] = future;
    return future.whenComplete(() => _categoryRefreshInFlight.remove(cacheKey));
  }

  Future<List<PointCategory>> _refreshCategoriesCacheInternal({
    required String troopId,
  }) async {
    final normalizedTroopId = _normalizeTroopId(troopId);
    _logDataSource(
      operation: 'fetchCategories',
      source: 'SUPABASE',
      scope: normalizedTroopId,
    );

    final result = await _withTimeout(_supabase
        .from('point_categories')
        .select('id, slug, name, description, troop_id')
        .or('troop_id.is.null,troop_id.eq.$normalizedTroopId')
      .order('name', ascending: true));

    final categories = (result as List)
        .map((row) => PointCategory.fromJson(row as Map<String, dynamic>))
        .toList();

    _categoriesCache.set(
      normalizedTroopId,
      categories,
      CacheTtl.pointCategories,
    );
    await PersistentQueryCache.write(
      key: _persistedCategoriesKey(normalizedTroopId),
      payload: categories.map(_categoryToJson).toList(growable: false),
      ttl: CacheTtl.pointCategories,
    );
    return categories;
  }

  Future<bool> _refreshTroopPointsHiddenCache({required String troopId}) async {
    final normalizedTroopId = _normalizeTroopId(troopId);
    _logDataSource(
      operation: 'fetchTroopPointsHidden',
      source: 'SUPABASE',
      scope: normalizedTroopId,
    );

    _assertTroopContextAvailable(normalizedTroopId);

    final row = await _withTimeout(_supabase
        .from('troops')
        .select('id, points_hidden')
        .eq('id', normalizedTroopId)
      .maybeSingle());

    if (row == null) {
      throw Exception('Troop not found for visibility settings.');
    }

    final hidden = row['points_hidden'] as bool? ?? false;
    _pointsVisibilityCache.set(
      normalizedTroopId,
      hidden,
      CacheTtl.troopPointsVisibility,
    );
    await PersistentQueryCache.write(
      key: _persistedVisibilityKey(normalizedTroopId),
      payload: hidden,
      ttl: CacheTtl.troopPointsVisibility,
    );
    return hidden;
  }

  Future<List<PointEntry>> _refreshPointsForMeetingCache({
    required String meetingId,
  }) {
    final cacheKey = meetingId.trim();
    final inFlight = _pointsRefreshInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshPointsForMeetingCacheInternal(meetingId: meetingId);
    _pointsRefreshInFlight[cacheKey] = future;
    return future.whenComplete(() => _pointsRefreshInFlight.remove(cacheKey));
  }

  Future<List<PointEntry>> _refreshPointsForMeetingCacheInternal({
    required String meetingId,
  }) async {
    final cacheKey = meetingId.trim();
    _logDataSource(
      operation: 'fetchPointsForMeeting',
      source: 'SUPABASE',
      scope: cacheKey,
    );

    try {
      final joinedRows = await _fetchPointsWithJoins(meetingId: meetingId);
      final entries = _toPointEntries(joinedRows);
      _pointsByMeetingCache.set(cacheKey, entries, CacheTtl.meetingPoints);
      await PersistentQueryCache.write(
        key: _persistedPointsByMeetingKey(cacheKey),
        payload: entries.map(_pointEntryToJson).toList(growable: false),
        ttl: CacheTtl.meetingPoints,
      );
      _pointsLastUpdated[cacheKey] = DateTime.now();
      return entries;
    } catch (_) {
      final fallbackRows = await _fetchPointsWithLookupFallback(
        meetingId: meetingId,
      );
      final entries = _toPointEntries(fallbackRows);
      _pointsByMeetingCache.set(cacheKey, entries, CacheTtl.meetingPoints);
      await PersistentQueryCache.write(
        key: _persistedPointsByMeetingKey(cacheKey),
        payload: entries.map(_pointEntryToJson).toList(growable: false),
        ttl: CacheTtl.meetingPoints,
      );
      _pointsLastUpdated[cacheKey] = DateTime.now();
      return entries;
    }
  }

  void _logDataSource({
    required String operation,
    required String source,
    required String scope,
  }) {
    if (!kDebugMode) return;
    final sourceTag = _sourceTag(source);
    debugPrint('[PTS][$sourceTag] $operation ($scope)');
  }

  String _sourceTag(String source) {
    switch (source) {
      case 'SUPABASE':
        return 'API';
      case 'LOCAL_CACHE_HIT':
        return 'CACHE';
      case 'OFFLINE_STALE_CACHE':
        return 'STALE';
      case 'DISK_CACHE_HIT':
        return 'DISK';
      default:
        return source;
    }
  }

  String _persistedPatrolsKey(String troopId) => 'points:patrols:$troopId';

  String _persistedCategoriesKey(String troopId) =>
      'points:categories:$troopId';

  String _persistedVisibilityKey(String troopId) =>
      'points:visibility:$troopId';

  String _persistedPointsByMeetingKey(String meetingId) =>
      'points:meeting:$meetingId';

  String _persistedSeasonPointsKey(String troopId, String seasonId) =>
      'points:season:$troopId::$seasonId';

  List<Map<String, dynamic>>? _parseJsonMapList(Object? payload) {
    if (payload is! List) return null;
    return payload
        .whereType<Map>()
        .map(
          (row) => row.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
  }

  List<PatrolOption>? _parsePatrolOptionList(Object? payload) {
    final rows = _parseJsonMapList(payload);
    if (rows == null) return null;
    return rows.map(PatrolOption.fromJson).toList(growable: false);
  }

  List<PointCategory>? _parsePointCategoryList(Object? payload) {
    final rows = _parseJsonMapList(payload);
    if (rows == null) return null;
    return rows.map(PointCategory.fromJson).toList(growable: false);
  }

  List<PointEntry>? _parsePointEntryList(Object? payload) {
    final rows = _parseJsonMapList(payload);
    if (rows == null) return null;
    return rows.map(PointEntry.fromJson).toList(growable: false);
  }

  Map<String, dynamic> _patrolToJson(PatrolOption patrol) {
    return <String, dynamic>{
      'id': patrol.id,
      'troop_id': patrol.troopId,
      'name': patrol.name,
    };
  }

  Map<String, dynamic> _categoryToJson(PointCategory category) {
    return <String, dynamic>{
      'id': category.id,
      'slug': category.slug,
      'name': category.name,
      'description': category.description,
      'troop_id': category.troopId,
    };
  }

  Map<String, dynamic> _pointEntryToJson(PointEntry point) {
    return <String, dynamic>{
      'id': point.id,
      'meeting_id': point.meetingId,
      'patrol_id': point.patrolId,
      'category_id': point.categoryId,
      'value': point.value,
      'reason': point.reason,
      'awarded_by_profile_id': point.awardedByProfileId,
      'created_at': point.createdAt?.toIso8601String(),
      'approved': point.approved,
      'patrol_name': point.patrolName,
      'category_name': point.categoryName,
      'awarded_by_name': point.awardedByName,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchPointsWithJoins({
    required String meetingId,
  }) async {
    final result = await _withTimeout(_supabase
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
        .order('created_at', ascending: false));

    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchPointsWithLookupFallback({
    required String meetingId,
  }) async {
    final result = await _withTimeout(_supabase
        .from('points')
        .select(
          'id, meeting_id, patrol_id, category_id, value, reason, awarded_by_profile_id, approved, approved_by_profile_id, approved_at, created_at',
        )
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: false));

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

    final result = await _withTimeout(_supabase
        .from(table)
        .select(select)
      .inFilter('id', ids));

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
        final result = await _withTimeout(_supabase
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
          .maybeSingle());

      if (result == null) {
        throw Exception('Point not found after write.');
      }

      return PointEntry.fromJson(result);
    } catch (_) {
      final baseRow = await _withTimeout(_supabase
          .from('points')
          .select(
            'id, meeting_id, patrol_id, category_id, value, reason, awarded_by_profile_id, approved, approved_by_profile_id, approved_at, created_at',
          )
          .eq('id', pointId)
          .maybeSingle());

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
    final row = await _withTimeout(_supabase
        .from('meetings')
        .select('id, troop_id')
        .eq('id', meetingId)
      .maybeSingle());

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
    final row = await _withTimeout(_supabase
        .from('patrols')
        .select('id, troop_id')
        .eq('id', patrolId)
      .maybeSingle());

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
    final row = await _withTimeout(_supabase
        .from('point_categories')
        .select('id, troop_id')
        .eq('id', categoryId)
      .maybeSingle());

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
    final row = await _withTimeout(_supabase
        .from('points')
        .select('id, meeting_id')
        .eq('id', pointId)
      .maybeSingle());

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

  String _normalizeTroopId(String troopId) {
    final normalized = troopId.trim();
    if (!_uuidPattern.hasMatch(normalized)) {
      throw Exception('Invalid troop id provided for points operation.');
    }
    return normalized;
  }

  Future<void> _assertNoCategoryConflicts({
    required String troopId,
    required String name,
    String? excludeCategoryId,
  }) async {
    final rows = await _withTimeout(_supabase
        .from('point_categories')
        .select('id, name, slug')
      .eq('troop_id', troopId));

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

  Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(
      OfflinePolicy.networkTimeout,
      onTimeout: () => throw Exception('Network timeout.'),
    );
  }
}
