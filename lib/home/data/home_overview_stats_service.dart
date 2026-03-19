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
