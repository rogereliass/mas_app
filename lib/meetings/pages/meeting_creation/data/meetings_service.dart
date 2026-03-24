import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:masapp/core/constants/cache_ttl.dart';
import 'package:masapp/core/constants/offline_policy.dart';
import 'package:masapp/core/utils/ttl_cache.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

/// Service responsible for all Supabase operations related to meetings.
class MeetingsService {
  final SupabaseClient _supabase;

  // Static cache keeps entries alive even though instance() creates a new
  // service object at call sites.
  static final TtlCache<String, List<Meeting>> _meetingsCache = TtlCache();
  static final Map<String, DateTime> _meetingsLastUpdated =
      <String, DateTime>{};

  MeetingsService(this._supabase);

  factory MeetingsService.instance() {
    return MeetingsService(Supabase.instance.client);
  }

  /// Clears in-memory meetings cache.
  void clearCache() {
    _meetingsCache.clear();
    _meetingsLastUpdated.clear();
  }

  DateTime? getMeetingsLastUpdated({
    required String seasonId,
    required String troopId,
  }) {
    return _meetingsLastUpdated[
      _meetingsCacheKey(seasonId: seasonId, troopId: troopId)
    ];
  }

  // -------------------------------------------------------------------------
  // Seasons
  // -------------------------------------------------------------------------

  /// Returns the currently active season (where today falls between
  /// `start_date` and `end_date`), or `null` if none is found.
  Future<Map<String, dynamic>?> fetchActiveSeason() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final result = await _withTimeout(_supabase
          .from('seasons')
          .select()
          .lte('start_date', today)
          .gte('end_date', today)
          .limit(1)
          .maybeSingle());

      return result;
    } catch (e) {
      throw Exception('MeetingsService.fetchActiveSeason: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Troops
  // -------------------------------------------------------------------------

  /// Returns a list of troops as `[{id, name}]`, ordered by name.
  Future<List<Map<String, dynamic>>> fetchTroops() async {
    try {
      final results = await _withTimeout(_supabase
          .from('troops')
          .select('id, name')
          .order('name', ascending: true));

      return List<Map<String, dynamic>>.from(results as List);
    } catch (e) {
      throw Exception('MeetingsService.fetchTroops: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Meetings
  // -------------------------------------------------------------------------

  /// Returns all meetings for the given [seasonId] and [troopId],
  /// ordered by `meeting_date ASC`.
  ///
  /// TODO: Implement clan-based meeting support
  Future<List<Meeting>> fetchMeetings({
    required String seasonId,
    required String troopId,
  }) async {
    final cacheKey = _meetingsCacheKey(seasonId: seasonId, troopId: troopId);
    final cached = _meetingsCache.get(cacheKey);
    if (cached != null) {
      _logDataSource(
        operation: 'fetchMeetings',
        source: 'LOCAL_CACHE_HIT',
        scope: cacheKey,
      );
      unawaited(() async {
        try {
          await _refreshMeetingsCache(seasonId: seasonId, troopId: troopId);
        } catch (_) {
          // Keep current cache result if background refresh fails.
        }
      }());
      return cached;
    }

    final stale = _meetingsCache.get(cacheKey, ignoreExpiry: true);

    try {
      return await _refreshMeetingsCache(seasonId: seasonId, troopId: troopId);
    } catch (e) {
      if (stale != null) {
        _logDataSource(
          operation: 'fetchMeetings',
          source: 'OFFLINE_STALE_CACHE',
          scope: cacheKey,
        );
        return stale;
      }
      throw Exception('MeetingsService.fetchMeetings: $e');
    }
  }

  Future<List<Meeting>> refreshMeetings({
    required String seasonId,
    required String troopId,
  }) {
    return _refreshMeetingsCache(seasonId: seasonId, troopId: troopId);
  }

  /// Inserts a new meeting row and returns the created [Meeting].
  ///
  /// TODO: Implement clan-based meeting support
  Future<Meeting> createMeeting({
    required String troopId,
    required String seasonId,
    required String createdByProfileId,
    required String title,
    required String location,
    required DateTime meetingDate,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    int? price,
  }) async {
    try {
      if (price != null && (price <= 0 || price > 32767)) {
        throw Exception('Meeting price must be between 1 and 32767.');
      }

      final payload = <String, dynamic>{
        // TODO: Implement clan-based meeting support
        'troop_id': troopId,
        'season_id': seasonId,
        'created_by_profile_id': createdByProfileId,
        'title': title,
        'location': location,
        'meeting_date': meetingDate.toIso8601String().substring(0, 10),
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        if (description != null) 'description': description,
        if (price != null) 'price': price,
      };

        final result = await _withTimeout(_supabase
          .from('meetings')
          .insert(payload)
          .select()
          .single());

      _meetingsCache.invalidate(
        _meetingsCacheKey(seasonId: seasonId, troopId: troopId),
      );

      return Meeting.fromJson(result);
    } catch (e) {
      throw Exception('MeetingsService.createMeeting: $e');
    }
  }

  /// Updates an existing meeting row and returns the updated [Meeting].
  Future<Meeting> updateMeeting({
    required String meetingId,
    required String title,
    required String location,
    required DateTime meetingDate,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    int? price,
  }) async {
    try {
      if (price != null && (price <= 0 || price > 32767)) {
        throw Exception('Meeting price must be between 1 and 32767.');
      }

      final payload = <String, dynamic>{
        'title': title,
        'location': location,
        'meeting_date': meetingDate.toIso8601String().substring(0, 10),
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'description': (description?.trim().isEmpty ?? true)
            ? null
            : description!.trim(),
        'price': price,
      };

        final result = await _withTimeout(_supabase
          .from('meetings')
          .update(payload)
          .eq('id', meetingId)
          .select()
          .single());

      // Meeting can move between troop/season; clear all list caches safely.
      _meetingsCache.clear();

      return Meeting.fromJson(result);
    } catch (e) {
      throw Exception('MeetingsService.updateMeeting: $e');
    }
  }

  /// Deletes a meeting row by [meetingId].
  Future<void> deleteMeeting(String meetingId) async {
    try {
      await _withTimeout(_supabase.from('meetings').delete().eq('id', meetingId));
      _meetingsCache.clear();
    } catch (e) {
      throw Exception('MeetingsService.deleteMeeting: $e');
    }
  }

  Future<List<Meeting>> _refreshMeetingsCache({
    required String seasonId,
    required String troopId,
  }) async {
    _logDataSource(
      operation: 'fetchMeetings',
      source: 'SUPABASE',
      scope: _meetingsCacheKey(seasonId: seasonId, troopId: troopId),
    );

    final results = await _withTimeout(_supabase
        .from('meetings')
        .select()
        // TODO: Implement clan-based meeting support
        .eq('season_id', seasonId)
        .eq('troop_id', troopId)
      .order('meeting_date', ascending: true));

    final meetings = (results as List)
        .map((row) => Meeting.fromJson(row as Map<String, dynamic>))
        .toList();

    _meetingsCache.set(
      _meetingsCacheKey(seasonId: seasonId, troopId: troopId),
      meetings,
      CacheTtl.meetingsList,
    );
    _meetingsLastUpdated[
      _meetingsCacheKey(seasonId: seasonId, troopId: troopId)
    ] = DateTime.now();
    return meetings;
  }

  String _meetingsCacheKey({required String seasonId, required String troopId}) {
    return '${seasonId.trim()}::${troopId.trim()}';
  }

  void _logDataSource({
    required String operation,
    required String source,
    required String scope,
  }) {
    if (!kDebugMode) return;
    final sourceTag = _sourceTag(source);
    debugPrint('[MTG][$sourceTag] $operation ($scope)');
  }

  String _sourceTag(String source) {
    switch (source) {
      case 'SUPABASE':
        return 'API';
      case 'LOCAL_CACHE_HIT':
        return 'CACHE';
      case 'OFFLINE_STALE_CACHE':
        return 'STALE';
      default:
        return source;
    }
  }

  Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(
      OfflinePolicy.networkTimeout,
      onTimeout: () => throw Exception('Network timeout.'),
    );
  }
}
