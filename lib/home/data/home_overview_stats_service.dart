import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/user_profile.dart';
import '../../core/constants/cache_ttl.dart';
import '../../core/data/persistent_query_cache.dart';
import '../../meetings/pages/meeting_creation/data/meetings_service.dart';
import 'models/home_overview_stats.dart';

/// Service for loading typed overview metrics shown on the home page.
class HomeOverviewStatsService {
  static const String _profilesTable = 'profiles';
  static const String _profileRolesTable = 'profile_roles';
  static const String _rolesTable = 'roles';
  static const String _meetingsTable = 'meetings';
  static const String _patrolsTable = 'patrols';
  static const String _attendanceTable = 'attendance';
  static const String _attendancePresentStatus = 'present';

  final SupabaseClient _supabase;
  final MeetingsService _meetingsService;

  HomeOverviewStatsService(this._supabase, {MeetingsService? meetingsService})
    : _meetingsService = meetingsService ?? MeetingsService.instance();

  factory HomeOverviewStatsService.instance() {
    return HomeOverviewStatsService(Supabase.instance.client);
  }

  /// Fetches troop-scoped overview metrics for ranks 60 and 70.
  Future<TroopOverviewStats> fetchTroopOverviewStats({
    required UserProfile currentUser,
  }) async {
    final troopId = _resolveTroopScope(currentUser);

    if (troopId == null) {
      throw Exception(
        'HomeOverviewStatsService.fetchTroopOverviewStats: troop-scoped user has no troop context.',
      );
    }

    _logDebug(
      'fetchTroopOverviewStats start: roleRank=${currentUser.roleRank}, troopId=$troopId',
    );

    final cacheKey = 'home:overview:troop:${troopId.trim()}';
    final persisted = await PersistentQueryCache.read<TroopOverviewStats>(
      key: cacheKey,
      parser: _parseTroopOverviewStats,
    );

    try {
      final totalMembers = await _countProfiles(
        approved: true,
        troopId: troopId,
      );
      final pendingMembers = await _countProfiles(
        approved: false,
        troopId: troopId,
      );

      final activeSeason = await _meetingsService.fetchActiveSeason();
      final seasonId = activeSeason?['id'] as String?;
      final seasonMeetings = seasonId == null || seasonId.isEmpty
          ? 0
          : await _countMeetings(seasonId: seasonId, troopId: troopId);

      final assignedLeaders = await _countAssignedLeaders(troopId: troopId);

      final stats = TroopOverviewStats(
        totalMembers: totalMembers,
        pendingMembers: pendingMembers,
        seasonMeetings: seasonMeetings,
        assignedLeaders: assignedLeaders,
      );

      await PersistentQueryCache.write(
        key: cacheKey,
        payload: _troopOverviewStatsToJson(stats),
        ttl: CacheTtl.meetingsList,
      );

      _logDebug('fetchTroopOverviewStats success: $stats');
      return stats;
    } catch (e) {
      if (persisted != null) {
        _logDebug('fetchTroopOverviewStats fallback: disk cache hit');
        return persisted.data;
      }
      final message =
          'HomeOverviewStatsService.fetchTroopOverviewStats failed: $e';
      _logError(message);
      throw Exception(message);
    }
  }

  /// Fetches live troop insight metrics for the Troop Overview smart card.
  Future<TroopInsightStats> fetchTroopInsightStats({
    required UserProfile currentUser,
  }) async {
    final troopId = _resolveTroopScope(currentUser);

    if (troopId == null || troopId.isEmpty) {
      _logDebug(
        'fetchTroopInsightStats fallback: troop-scoped user has no troop context; returning empty stats.',
      );
      return const TroopInsightStats.empty();
    }

    _logDebug(
      'fetchTroopInsightStats start: roleRank=${currentUser.roleRank}, troopId=$troopId',
    );

    final cacheKey = 'home:insights:troop:${troopId.trim()}';
    final persisted = await PersistentQueryCache.read<TroopInsightStats>(
      key: cacheKey,
      parser: _parseTroopInsightStats,
    );

    try {
      final patrolCount = await _countPatrols(troopId: troopId);

      final activeSeason = await _meetingsService.fetchActiveSeason();
      final seasonId = (activeSeason?['id'] as String?)?.trim();

      final seasonMeetingIds = seasonId == null || seasonId.isEmpty
          ? const <String>[]
          : await _fetchTroopMeetingIdsForSeason(
              troopId: troopId,
              seasonId: seasonId,
            );

      final averageScoutsPresentPerMeeting =
          await _computeAveragePresentAttendance(meetingIds: seasonMeetingIds);

      final lastMeeting = await _fetchLastTroopMeeting(troopId: troopId);
      final lastMeetingId = (lastMeeting?['id'] as String?)?.trim();
      final lastMeetingDate = _parseMeetingDate(lastMeeting?['meeting_date']);

      final lastMeetingPresentCount =
          (lastMeetingId == null || lastMeetingId.isEmpty)
          ? 0
          : await _countPresentAttendanceForMeeting(meetingId: lastMeetingId);

      final stats = TroopInsightStats(
        patrolCount: patrolCount,
        averageScoutsPresentPerMeeting: averageScoutsPresentPerMeeting,
        lastMeetingDate: lastMeetingDate,
        lastMeetingPresentCount: lastMeetingPresentCount,
      );

      await PersistentQueryCache.write(
        key: cacheKey,
        payload: _troopInsightStatsToJson(stats),
        ttl: CacheTtl.meetingsList,
      );

      _logDebug('fetchTroopInsightStats success: $stats');
      return stats;
    } catch (e) {
      if (persisted != null) {
        _logDebug('fetchTroopInsightStats fallback: disk cache hit');
        return persisted.data;
      }
      final message = 'HomeOverviewStatsService.fetchTroopInsightStats failed: $e';
      _logError(message);
      throw Exception(message);
    }
  }

  /// Fetches system-wide overview metrics for ranks 90 and above.
  Future<AdminOverviewStats> fetchAdminOverviewStats({
    required UserProfile currentUser,
  }) async {
    if (!currentUser.hasSystemWideAccess) {
      throw Exception(
        'HomeOverviewStatsService.fetchAdminOverviewStats: rank ${currentUser.roleRank} cannot access admin overview metrics.',
      );
    }

    _logDebug(
      'fetchAdminOverviewStats start: roleRank=${currentUser.roleRank}, profileId=${currentUser.id}',
    );

    const cacheKey = 'home:overview:admin';
    final persisted = await PersistentQueryCache.read<AdminOverviewStats>(
      key: cacheKey,
      parser: _parseAdminOverviewStats,
    );

    try {
      final totalAppUsers = await _countProfiles(approved: true);
      final totalPendingUsers = await _countProfiles(approved: false);

      final activeSeason = await _meetingsService.fetchActiveSeason();
      final seasonId = activeSeason?['id'] as String?;
      final seasonCode = (activeSeason?['season_code'] as String?)?.trim();
      final currentSeasonCode = (seasonCode == null || seasonCode.isEmpty)
          ? 'N/A'
          : seasonCode;

      final seasonMeetingsAllTroops = seasonId == null || seasonId.isEmpty
          ? 0
          : await _countMeetings(seasonId: seasonId);

      final stats = AdminOverviewStats(
        totalAppUsers: totalAppUsers,
        totalPendingUsers: totalPendingUsers,
        seasonMeetingsAllTroops: seasonMeetingsAllTroops,
        currentSeasonCode: currentSeasonCode,
      );

      await PersistentQueryCache.write(
        key: cacheKey,
        payload: _adminOverviewStatsToJson(stats),
        ttl: CacheTtl.meetingsList,
      );

      _logDebug('fetchAdminOverviewStats success: $stats');
      return stats;
    } catch (e) {
      if (persisted != null) {
        _logDebug('fetchAdminOverviewStats fallback: disk cache hit');
        return persisted.data;
      }
      final message =
          'HomeOverviewStatsService.fetchAdminOverviewStats failed: $e';
      _logError(message);
      throw Exception(message);
    }
  }

  String? _resolveTroopScope(UserProfile currentUser) {
    if (!currentUser.isTroopScoped) {
      throw Exception(
        'HomeOverviewStatsService.fetchTroopOverviewStats: rank ${currentUser.roleRank} is not troop-scoped (expected 60/70).',
      );
    }

    final managedTroopId = currentUser.managedTroopId?.trim();
    if (managedTroopId != null && managedTroopId.isNotEmpty) {
      return managedTroopId;
    }

    final signupTroopId = currentUser.signupTroopId?.trim();
    if (signupTroopId != null && signupTroopId.isNotEmpty) {
      _logDebug(
        'fetchTroopOverviewStats fallback: managedTroopId missing, using signupTroopId=$signupTroopId',
      );
      return signupTroopId;
    }

    return null;
  }

  Future<int> _countProfiles({required bool approved, String? troopId}) async {
    dynamic query = _supabase
        .from(_profilesTable)
        .select('id')
        .eq('approved', approved);

    if (troopId != null && troopId.isNotEmpty) {
      query = query.eq('signup_troop', troopId);
    }

    final rows = await query as List<dynamic>;
    return rows.length;
  }

  Future<int> _countMeetings({
    required String seasonId,
    String? troopId,
  }) async {
    dynamic query = _supabase
        .from(_meetingsTable)
        .select('id')
        .eq('season_id', seasonId);

    if (troopId != null && troopId.isNotEmpty) {
      query = query.eq('troop_id', troopId);
    }

    final rows = await query as List<dynamic>;
    return rows.length;
  }

  Future<int> _countPatrols({required String troopId}) async {
    final rows = await _supabase
        .from(_patrolsTable)
        .select('id')
        .eq('troop_id', troopId) as List<dynamic>;

    return rows.length;
  }

  Future<List<String>> _fetchTroopMeetingIdsForSeason({
    required String troopId,
    required String seasonId,
  }) async {
    final rows = List<Map<String, dynamic>>.from(
      await _supabase
              .from(_meetingsTable)
              .select('id')
              .eq('troop_id', troopId)
              .eq('season_id', seasonId)
              .eq('is_template', false)
          as List,
    );

    return rows
        .map((row) => (row['id'] as String?)?.trim())
        .whereType<String>()
        .where((meetingId) => meetingId.isNotEmpty)
        .toList();
  }

  Future<double> _computeAveragePresentAttendance({
    required List<String> meetingIds,
  }) async {
    if (meetingIds.isEmpty) {
      return 0;
    }

    final presentCounts = await _countPresentAttendanceByMeeting(
      meetingIds: meetingIds,
    );

    final totalPresent = presentCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

    return totalPresent / meetingIds.length;
  }

  Future<Map<String, int>> _countPresentAttendanceByMeeting({
    required List<String> meetingIds,
  }) async {
    if (meetingIds.isEmpty) {
      return const <String, int>{};
    }

    final rows = List<Map<String, dynamic>>.from(
      await _supabase
              .from(_attendanceTable)
              .select('meeting_id, status')
              .inFilter('meeting_id', meetingIds)
          as List,
    );

    final counts = <String, int>{
      for (final meetingId in meetingIds) meetingId: 0,
    };

    for (final row in rows) {
      final meetingId = (row['meeting_id'] as String?)?.trim();
      final status = (row['status'] as String?)?.trim().toLowerCase();

      if (meetingId == null || meetingId.isEmpty) {
        continue;
      }

      if (status != _attendancePresentStatus) {
        continue;
      }

      if (!counts.containsKey(meetingId)) {
        continue;
      }

      counts[meetingId] = (counts[meetingId] ?? 0) + 1;
    }

    return counts;
  }

  Future<Map<String, dynamic>?> _fetchLastTroopMeeting({
    required String troopId,
  }) async {
    final row = await _supabase
        .from(_meetingsTable)
        .select('id, meeting_date')
        .eq('troop_id', troopId)
        .eq('is_template', false)
        .order('meeting_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return Map<String, dynamic>.from(row as Map);
  }

  Future<int> _countPresentAttendanceForMeeting({required String meetingId}) async {
    final presentCounts = await _countPresentAttendanceByMeeting(
      meetingIds: [meetingId],
    );

    return presentCounts[meetingId] ?? 0;
  }

  DateTime? _parseMeetingDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return DateTime.tryParse(trimmed);
    }

    return null;
  }

  Future<int> _countAssignedLeaders({required String troopId}) async {
    final leaderRoleIds = await _fetchRoleIdsByRank(const [60, 70]);

    if (leaderRoleIds.isEmpty) {
      _logDebug(
        'countAssignedLeaders: no roles found for ranks 60/70; returning 0.',
      );
      return 0;
    }

    final rows = List<Map<String, dynamic>>.from(
      await _supabase
              .from(_profileRolesTable)
              .select('profile_id, role_id')
              .eq('troop_context', troopId)
              .inFilter('role_id', leaderRoleIds)
          as List,
    );

    final uniqueProfileIds = rows
        .map((row) => row['profile_id'])
        .whereType<String>()
        .where((profileId) => profileId.isNotEmpty)
        .toSet();

    return uniqueProfileIds.length;
  }

  Future<List<String>> _fetchRoleIdsByRank(List<int> ranks) async {
    final rows = List<Map<String, dynamic>>.from(
      await _supabase
              .from(_rolesTable)
              .select('id')
              .inFilter('role_rank', ranks)
          as List,
    );

    return rows.map((row) => row['id']).whereType<String>().toList();
  }

  void _logDebug(String message) {
    if (!kDebugMode) return;
    debugPrint('[HomeOverviewStatsService] $message');
  }

  void _logError(String message) {
    debugPrint('[HomeOverviewStatsService] ERROR: $message');
  }

  TroopOverviewStats? _parseTroopOverviewStats(Object? payload) {
    if (payload is! Map) return null;
    final map = payload.map((key, value) => MapEntry(key.toString(), value));
    return TroopOverviewStats(
      totalMembers: _asInt(map['total_members']),
      pendingMembers: _asInt(map['pending_members']),
      seasonMeetings: _asInt(map['season_meetings']),
      assignedLeaders: _asInt(map['assigned_leaders']),
    );
  }

  TroopInsightStats? _parseTroopInsightStats(Object? payload) {
    if (payload is! Map) return null;
    final map = payload.map((key, value) => MapEntry(key.toString(), value));
    return TroopInsightStats(
      patrolCount: _asInt(map['patrol_count']),
      averageScoutsPresentPerMeeting: _asDouble(
        map['average_scouts_present_per_meeting'],
      ),
      lastMeetingDate: DateTime.tryParse(
        map['last_meeting_date']?.toString() ?? '',
      ),
      lastMeetingPresentCount: _asInt(map['last_meeting_present_count']),
    );
  }

  AdminOverviewStats? _parseAdminOverviewStats(Object? payload) {
    if (payload is! Map) return null;
    final map = payload.map((key, value) => MapEntry(key.toString(), value));
    return AdminOverviewStats(
      totalAppUsers: _asInt(map['total_app_users']),
      totalPendingUsers: _asInt(map['total_pending_users']),
      seasonMeetingsAllTroops: _asInt(map['season_meetings_all_troops']),
      currentSeasonCode: (map['current_season_code'] as String? ?? 'N/A').trim(),
    );
  }

  Map<String, dynamic> _troopOverviewStatsToJson(TroopOverviewStats stats) {
    return <String, dynamic>{
      'total_members': stats.totalMembers,
      'pending_members': stats.pendingMembers,
      'season_meetings': stats.seasonMeetings,
      'assigned_leaders': stats.assignedLeaders,
    };
  }

  Map<String, dynamic> _troopInsightStatsToJson(TroopInsightStats stats) {
    return <String, dynamic>{
      'patrol_count': stats.patrolCount,
      'average_scouts_present_per_meeting': stats.averageScoutsPresentPerMeeting,
      'last_meeting_date': stats.lastMeetingDate?.toIso8601String(),
      'last_meeting_present_count': stats.lastMeetingPresentCount,
    };
  }

  Map<String, dynamic> _adminOverviewStatsToJson(AdminOverviewStats stats) {
    return <String, dynamic>{
      'total_app_users': stats.totalAppUsers,
      'total_pending_users': stats.totalPendingUsers,
      'season_meetings_all_troops': stats.seasonMeetingsAllTroops,
      'current_season_code': stats.currentSeasonCode,
    };
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
