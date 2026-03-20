/// Typed metrics used by the home overview row for troop-scoped roles.
class TroopOverviewStats {
  final int totalMembers;
  final int pendingMembers;
  final int seasonMeetings;
  final int assignedLeaders;

  const TroopOverviewStats({
    required this.totalMembers,
    required this.pendingMembers,
    required this.seasonMeetings,
    required this.assignedLeaders,
  });

  TroopOverviewStats copyWith({
    int? totalMembers,
    int? pendingMembers,
    int? seasonMeetings,
    int? assignedLeaders,
  }) {
    return TroopOverviewStats(
      totalMembers: totalMembers ?? this.totalMembers,
      pendingMembers: pendingMembers ?? this.pendingMembers,
      seasonMeetings: seasonMeetings ?? this.seasonMeetings,
      assignedLeaders: assignedLeaders ?? this.assignedLeaders,
    );
  }

  @override
  String toString() {
    return 'TroopOverviewStats(totalMembers: $totalMembers, pendingMembers: $pendingMembers, seasonMeetings: $seasonMeetings, assignedLeaders: $assignedLeaders)';
  }
}

/// Typed metrics used by the Troop Overview smart stack card.
class TroopInsightStats {
  final int patrolCount;
  final double averageScoutsPresentPerMeeting;
  final DateTime? lastMeetingDate;
  final int lastMeetingPresentCount;

  const TroopInsightStats({
    required this.patrolCount,
    required this.averageScoutsPresentPerMeeting,
    required this.lastMeetingDate,
    required this.lastMeetingPresentCount,
  });

  const TroopInsightStats.empty()
    : patrolCount = 0,
      averageScoutsPresentPerMeeting = 0,
      lastMeetingDate = null,
      lastMeetingPresentCount = 0;

  TroopInsightStats copyWith({
    int? patrolCount,
    double? averageScoutsPresentPerMeeting,
    DateTime? lastMeetingDate,
    bool clearLastMeetingDate = false,
    int? lastMeetingPresentCount,
  }) {
    return TroopInsightStats(
      patrolCount: patrolCount ?? this.patrolCount,
      averageScoutsPresentPerMeeting:
          averageScoutsPresentPerMeeting ?? this.averageScoutsPresentPerMeeting,
      lastMeetingDate: clearLastMeetingDate
          ? null
          : (lastMeetingDate ?? this.lastMeetingDate),
      lastMeetingPresentCount:
          lastMeetingPresentCount ?? this.lastMeetingPresentCount,
    );
  }

  @override
  String toString() {
    return 'TroopInsightStats(patrolCount: $patrolCount, averageScoutsPresentPerMeeting: $averageScoutsPresentPerMeeting, lastMeetingDate: $lastMeetingDate, lastMeetingPresentCount: $lastMeetingPresentCount)';
  }
}

/// Typed metrics used by the home overview row for system-wide roles.
class AdminOverviewStats {
  final int totalAppUsers;
  final int totalPendingUsers;
  final int seasonMeetingsAllTroops;
  final String currentSeasonCode;

  const AdminOverviewStats({
    required this.totalAppUsers,
    required this.totalPendingUsers,
    required this.seasonMeetingsAllTroops,
    required this.currentSeasonCode,
  });

  AdminOverviewStats copyWith({
    int? totalAppUsers,
    int? totalPendingUsers,
    int? seasonMeetingsAllTroops,
    String? currentSeasonCode,
  }) {
    return AdminOverviewStats(
      totalAppUsers: totalAppUsers ?? this.totalAppUsers,
      totalPendingUsers: totalPendingUsers ?? this.totalPendingUsers,
      seasonMeetingsAllTroops:
          seasonMeetingsAllTroops ?? this.seasonMeetingsAllTroops,
      currentSeasonCode: currentSeasonCode ?? this.currentSeasonCode,
    );
  }

  @override
  String toString() {
    return 'AdminOverviewStats(totalAppUsers: $totalAppUsers, totalPendingUsers: $totalPendingUsers, seasonMeetingsAllTroops: $seasonMeetingsAllTroops, currentSeasonCode: $currentSeasonCode)';
  }
}
