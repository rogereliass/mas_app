import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:masapp/core/constants/cache_ttl.dart';
import 'package:masapp/core/constants/offline_policy.dart';
import 'package:masapp/core/utils/ttl_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:masapp/meetings/pages/attendance/data/models/attendance_record.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

/// Service responsible for all Supabase operations related to attendance.
class AttendanceService {
  final SupabaseClient _supabase;

  static final TtlCache<String, List<MemberWithAttendance>> _membersCache =
      TtlCache();
  static final TtlCache<String, List<AttendanceRecord>> _attendanceCache =
      TtlCache();
    static final Map<String, DateTime> _attendanceLastUpdated =
      <String, DateTime>{};

    final Map<String, Future<List<MemberWithAttendance>>> _membersRefreshInFlight =
      <String, Future<List<MemberWithAttendance>>>{};
    final Map<String, Future<List<AttendanceRecord>>> _attendanceRefreshInFlight =
      <String, Future<List<AttendanceRecord>>>{};

  AttendanceService(this._supabase);

  factory AttendanceService.instance() {
    return AttendanceService(Supabase.instance.client);
  }

  /// Clears in-memory attendance caches.
  void clearCache() {
    _membersCache.clear();
    _attendanceCache.clear();
    _attendanceLastUpdated.clear();
  }

  DateTime? getAttendanceLastUpdated(String meetingId) {
    return _attendanceLastUpdated[meetingId.trim()];
  }

  // -------------------------------------------------------------------------
  // Members
  // -------------------------------------------------------------------------

  /// Fetches approved troop members with their patrol information.
  ///
  /// Mirrors the PatrolsManagementService approach:
  ///   1. Query `profiles` WHERE signup_troop = troopId AND approved = true
  ///   2. Query `patrols`  WHERE troop_id    = troopId
  ///   3. Map patrol names back onto each member via patrol_id
  ///
  /// The returned [MemberWithAttendance] list has `record = null`; callers are
  /// responsible for merging in existing [AttendanceRecord]s.
  ///
  /// If [memberProfileIdFilter] is provided, only that one member is returned.
  Future<List<MemberWithAttendance>> fetchTroopMembers({
    required String troopId,
    String? memberProfileIdFilter,
  }) async {
    final cacheKey = _membersCacheKey(
      troopId: troopId,
      memberProfileIdFilter: memberProfileIdFilter,
    );
    final cached = _membersCache.get(cacheKey);
    if (cached != null) {
      _logDataSource(
        operation: 'fetchTroopMembers',
        source: 'LOCAL_CACHE_HIT',
        scope: cacheKey,
      );
      unawaited(() async {
        try {
          await _refreshTroopMembersCache(
            troopId: troopId,
            memberProfileIdFilter: memberProfileIdFilter,
          );
        } catch (_) {
          // Keep cached member list if background refresh fails.
        }
      }());
      return cached;
    }

    final stale = _membersCache.get(cacheKey, ignoreExpiry: true);

    try {
      return await _refreshTroopMembersCache(
        troopId: troopId,
        memberProfileIdFilter: memberProfileIdFilter,
      );
    } catch (e) {
      if (stale != null) {
        _logDataSource(
          operation: 'fetchTroopMembers',
          source: 'OFFLINE_STALE_CACHE',
          scope: cacheKey,
        );
        return stale;
      }
      throw Exception('AttendanceService.fetchTroopMembers: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Attendance Records
  // -------------------------------------------------------------------------

  /// Fetches all existing attendance rows for the given [meetingId].
  Future<List<AttendanceRecord>> fetchAttendanceForMeeting(
      String meetingId) async {
    final cached = _attendanceCache.get(meetingId);
    if (cached != null) {
      _logDataSource(
        operation: 'fetchAttendanceForMeeting',
        source: 'LOCAL_CACHE_HIT',
        scope: meetingId.trim(),
      );
      unawaited(() async {
        try {
          await _refreshAttendanceForMeetingCache(meetingId);
        } catch (_) {
          // Keep cached attendance if background refresh fails.
        }
      }());
      return cached;
    }

    final stale = _attendanceCache.get(meetingId, ignoreExpiry: true);

    try {
      return await _refreshAttendanceForMeetingCache(meetingId);
    } catch (e) {
      if (stale != null) {
        _logDataSource(
          operation: 'fetchAttendanceForMeeting',
          source: 'OFFLINE_STALE_CACHE',
          scope: meetingId.trim(),
        );
        return stale;
      }
      throw Exception('AttendanceService.fetchAttendanceForMeeting: $e');
    }
  }

  Future<List<AttendanceRecord>> refreshAttendanceForMeeting(
    String meetingId,
  ) {
    return _refreshAttendanceForMeetingCache(meetingId);
  }

  /// Inserts absent rows for all [memberProfileIds] who do not yet have an
  /// attendance record for [meetingId].
  ///
  /// Uses a single `upsert` call with `ignoreDuplicates: true` so it is safe
  /// to call repeatedly. A UNIQUE(meeting_id, profile_id) constraint on the
  /// `attendance` table is strongly recommended for correctness.
  Future<void> lazyAutoFillAbsent({
    required String meetingId,
    required List<String> memberProfileIds,
    required String markedByProfileId,
  }) async {
    if (memberProfileIds.isEmpty) return;

    try {
      final rows = memberProfileIds.map((profileId) {
        return <String, dynamic>{
          'meeting_id': meetingId,
          'profile_id': profileId,
          'status': AttendanceStatus.absent.dbValue,
          'marked_by_profile_id': markedByProfileId,
          'marked_at': DateTime.now().toIso8601String(),
        };
      }).toList();

        await _withTimeout(_supabase
          .from('attendance')
          .upsert(rows, onConflict: 'meeting_id,profile_id', ignoreDuplicates: true));

      _attendanceCache.invalidate(meetingId);
    } catch (e) {
      throw Exception('AttendanceService.lazyAutoFillAbsent: $e');
    }
  }

  /// Updates only the [notes] field for a single attendance record.
  /// Pass `null` or an empty string to clear the note.
  Future<void> updateAttendanceNotes({
    required String recordId,
    String? meetingId,
    required String? notes,
  }) async {
    try {
        await _withTimeout(_supabase
          .from('attendance')
          .update({'notes': (notes?.trim().isEmpty ?? true) ? null : notes!.trim()})
          .eq('id', recordId));

      if (meetingId != null && meetingId.trim().isNotEmpty) {
        _attendanceCache.invalidate(meetingId.trim());
      } else {
        // Fallback when caller cannot provide meeting scope.
        _attendanceCache.clear();
      }
    } catch (e) {
      throw Exception('AttendanceService.updateAttendanceNotes: $e');
    }
  }

  /// Batch-updates only the [changedRecords] in the `attendance` table.
  ///
  /// Each record is updated individually in parallel via [Future.wait].
  /// Returns immediately if [changedRecords] is empty.
  Future<void> batchUpdateAttendance(
      List<AttendanceRecord> changedRecords) async {
    if (changedRecords.isEmpty) return;

    try {
      await Future.wait(
        changedRecords.map(
          (r) => _withTimeout(_supabase.from('attendance').update({
            'status': r.status.dbValue,
            'marked_by_profile_id': r.markedByProfileId,
            'marked_at': DateTime.now().toIso8601String(),
          }).eq('id', r.id)),
        ),
      );

      final touchedMeetingIds = changedRecords
          .map((record) => record.meetingId)
          .where((id) => id.trim().isNotEmpty)
          .toSet();
      for (final meetingId in touchedMeetingIds) {
        _attendanceCache.invalidate(meetingId);
      }
    } catch (e) {
      throw Exception('AttendanceService.batchUpdateAttendance: $e');
    }
  }

  Future<List<MemberWithAttendance>> _refreshTroopMembersCache({
    required String troopId,
    String? memberProfileIdFilter,
  }) {
    final cacheKey = _membersCacheKey(
      troopId: troopId,
      memberProfileIdFilter: memberProfileIdFilter,
    );
    final inFlight = _membersRefreshInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshTroopMembersCacheInternal(
      troopId: troopId,
      memberProfileIdFilter: memberProfileIdFilter,
    );
    _membersRefreshInFlight[cacheKey] = future;
    return future.whenComplete(() => _membersRefreshInFlight.remove(cacheKey));
  }

  Future<List<MemberWithAttendance>> _refreshTroopMembersCacheInternal({
    required String troopId,
    String? memberProfileIdFilter,
  }) async {
    _logDataSource(
      operation: 'fetchTroopMembers',
      source: 'SUPABASE',
      scope: _membersCacheKey(
        troopId: troopId,
        memberProfileIdFilter: memberProfileIdFilter,
      ),
    );

    // Step 1 – fetch approved profiles that belong to this troop.
    // Intentionally uses signup_troop (same as PatrolsManagementService)
    // to avoid ambiguous embedding with profile_roles.
    var profileQuery = _supabase
        .from('profiles')
        .select('id, first_name, middle_name, last_name, patrol_id')
        .eq('signup_troop', troopId)
        .eq('approved', true)
        .order('last_name', ascending: true)
        .order('first_name', ascending: true);

    final profileResults = await _withTimeout(profileQuery);
    var profiles = (profileResults as List).cast<Map<String, dynamic>>();

    // Optionally narrow to a single member (e.g. regular-member self-view).
    if (memberProfileIdFilter != null) {
      profiles = profiles.where((p) => p['id'] == memberProfileIdFilter).toList();
      if (profiles.isEmpty) {
        _membersCache.set(
          _membersCacheKey(
            troopId: troopId,
            memberProfileIdFilter: memberProfileIdFilter,
          ),
          <MemberWithAttendance>[],
          CacheTtl.attendanceMembers,
        );
        return <MemberWithAttendance>[];
      }
    }

    // Step 2 – fetch all patrols for this troop so we can resolve names.
    final patrolResults = await _withTimeout(_supabase
        .from('patrols')
        .select('id, name')
      .eq('troop_id', troopId));

    final patrolMap = <String, String>{
      for (final row in (patrolResults as List).cast<Map<String, dynamic>>())
        row['id'] as String: (row['name'] as String? ?? ''),
    };

    // Step 3 – build MemberWithAttendance list.
    final members = profiles.map((json) {
      final firstName = (json['first_name'] as String? ?? '').trim();
      final lastName = (json['last_name'] as String? ?? '').trim();
      final displayName =
          [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

      final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
      final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';

      final patrolId = json['patrol_id'] as String?;

      return MemberWithAttendance(
        profileId: json['id'] as String,
        displayName: displayName.isNotEmpty ? displayName : 'Unnamed Member',
        initialsName: '$firstInitial$lastInitial',
        patrolId: patrolId,
        patrolName: patrolId != null ? patrolMap[patrolId] : null,
        record: null,
      );
    }).toList();

    _membersCache.set(
      _membersCacheKey(
        troopId: troopId,
        memberProfileIdFilter: memberProfileIdFilter,
      ),
      members,
      CacheTtl.attendanceMembers,
    );

    return members;
  }

  Future<List<AttendanceRecord>> _refreshAttendanceForMeetingCache(
    String meetingId,
  ) {
    final cacheKey = meetingId.trim();
    final inFlight = _attendanceRefreshInFlight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshAttendanceForMeetingCacheInternal(meetingId);
    _attendanceRefreshInFlight[cacheKey] = future;
    return future.whenComplete(
      () => _attendanceRefreshInFlight.remove(cacheKey),
    );
  }

  Future<List<AttendanceRecord>> _refreshAttendanceForMeetingCacheInternal(
    String meetingId,
  ) async {
    _logDataSource(
      operation: 'fetchAttendanceForMeeting',
      source: 'SUPABASE',
      scope: meetingId.trim(),
    );

    final results = await _withTimeout(_supabase
        .from('attendance')
        .select()
      .eq('meeting_id', meetingId));

    final records = (results as List)
        .map((row) => AttendanceRecord.fromJson(row as Map<String, dynamic>))
        .toList();

    _attendanceCache.set(meetingId, records, CacheTtl.attendanceRecords);
    _attendanceLastUpdated[meetingId.trim()] = DateTime.now();
    return records;
  }

  String _membersCacheKey({
    required String troopId,
    String? memberProfileIdFilter,
  }) {
    final normalizedFilter = memberProfileIdFilter?.trim() ?? '';
    return '${troopId.trim()}::$normalizedFilter';
  }

  void _logDataSource({
    required String operation,
    required String source,
    required String scope,
  }) {
    if (!kDebugMode) return;
    final sourceTag = _sourceTag(source);
    debugPrint('[ATT][$sourceTag] $operation ($scope)');
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

  // -------------------------------------------------------------------------
  // Scout Dashboard
  // -------------------------------------------------------------------------

  /// Fetches an optimized list of a specific user's attendance for a season.
  /// Combines meetings data and attendance records.
  Future<List<MyAttendanceLog>> fetchMyAttendanceForSeason({
    required String profileId,
    required String troopId,
    required String seasonId,
  }) async {
    try {
      // 1) Fetch all meetings for the troop and season in descending order
        final meetingsResponse = await _withTimeout(_supabase
          .from('meetings')
          .select()
          .eq('troop_id', troopId)
          .eq('season_id', seasonId)
          .order('meeting_date', ascending: false));

      final List<Meeting> meetings = (meetingsResponse as List)
          .map((row) => Meeting.fromJson(row))
          .toList();

      if (meetings.isEmpty) return [];

      final List<String> meetingIds = meetings.map((m) => m.id).toList();

      // 2) Fetch attendance records for this profile ID within these meetings
        final attendanceResponse = await _withTimeout(_supabase
          .from('attendance')
          .select()
          .eq('profile_id', profileId)
          .inFilter('meeting_id', meetingIds));

      final List<AttendanceRecord> records = (attendanceResponse as List)
          .map((row) => AttendanceRecord.fromJson(row))
          .toList();

      // Map for O(1) lookups
      final recordMap = {for (var r in records) r.meetingId: r};

      // 3) Merge into logs
      return meetings.map((meeting) {
        return MyAttendanceLog(
          meeting: meeting,
          record: recordMap[meeting.id],
        );
      }).toList();
      
    } catch (e) {
      throw Exception('AttendanceService.fetchMyAttendanceForSeason: $e');
    }
  }

  Future<T> _withTimeout<T>(Future<T> future) {
    return future.timeout(
      OfflinePolicy.networkTimeout,
      onTimeout: () => throw Exception('Network timeout.'),
    );
  }
}
