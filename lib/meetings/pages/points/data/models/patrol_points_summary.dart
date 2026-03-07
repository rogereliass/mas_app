import 'point_entry.dart';

/// Aggregated score metrics for one patrol in a given points scope.
class PatrolPointsSummary {
  final String patrolId;
  final String patrolName;
  final int netScore;
  final int positivePoints;
  final int penaltyPoints;
  final int pointCount;
  final DateTime? lastAwardedAt;
  final Map<String, int> categoryTotals;
  final List<PointEntry> entries;

  const PatrolPointsSummary({
    required this.patrolId,
    required this.patrolName,
    required this.netScore,
    required this.positivePoints,
    required this.penaltyPoints,
    required this.pointCount,
    required this.lastAwardedAt,
    required this.categoryTotals,
    required this.entries,
  });
}

/// Aggregate output that can represent meeting-level or season-level scopes.
class PointsSummaryAggregate {
  final List<PatrolPointsSummary> patrols;
  final int totalNetScore;
  final int totalEntries;
  final int maxNetScore;

  const PointsSummaryAggregate({
    required this.patrols,
    required this.totalNetScore,
    required this.totalEntries,
    required this.maxNetScore,
  });

  bool get isEmpty => patrols.isEmpty;
}
