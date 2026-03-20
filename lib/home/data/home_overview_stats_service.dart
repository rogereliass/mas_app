import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/models/user_profile.dart';
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

      _logDebug('fetchTroopOverviewStats success: $stats');
      return stats;
    } catch (e) {
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

      _logDebug('fetchTroopInsightStats success: $stats');
      return stats;
    } catch (e) {
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

      _logDebug('fetchAdminOverviewStats success: $stats');
      return stats;
    } catch (e) {
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
}
