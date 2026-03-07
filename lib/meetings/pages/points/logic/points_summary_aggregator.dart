import '../data/models/patrol_points_summary.dart';
import '../data/models/point_entry.dart';

class PointsSummaryAggregator {
  const PointsSummaryAggregator._();

  /// Converts raw points into a ranked patrol summary.
  ///
  /// This utility is intentionally scope-agnostic: callers can pass selected
  /// meeting entries today and season-scoped entries later for homepage stats.
  static PointsSummaryAggregate aggregatePatrolScores(List<PointEntry> points) {
    if (points.isEmpty) {
      return const PointsSummaryAggregate(
        patrols: [],
        totalNetScore: 0,
        totalEntries: 0,
        maxNetScore: 0,
      );
    }

    final pointsByPatrol = <String, List<PointEntry>>{};
    for (final entry in points) {
      pointsByPatrol.putIfAbsent(entry.patrolId, () => []).add(entry);
    }

    final summaries = <PatrolPointsSummary>[];
    for (final group in pointsByPatrol.entries) {
      final patrolEntries = [...group.value]
        ..sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));

      var netScore = 0;
      var positivePoints = 0;
      var penaltyPoints = 0;
      final categoryTotals = <String, int>{};

      for (final entry in patrolEntries) {
        netScore += entry.value;
        if (entry.value >= 0) {
          positivePoints += entry.value;
        } else {
          penaltyPoints += entry.value.abs();
        }

        categoryTotals[entry.categoryName] =
            (categoryTotals[entry.categoryName] ?? 0) + entry.value;
      }

      summaries.add(
        PatrolPointsSummary(
          patrolId: group.key,
          patrolName: patrolEntries.first.patrolName,
          netScore: netScore,
          positivePoints: positivePoints,
          penaltyPoints: penaltyPoints,
          pointCount: patrolEntries.length,
          lastAwardedAt: patrolEntries.first.createdAt,
          categoryTotals: Map.unmodifiable(categoryTotals),
          entries: List.unmodifiable(patrolEntries),
        ),
      );
    }

    summaries.sort((a, b) {
      final byNet = b.netScore.compareTo(a.netScore);
      if (byNet != 0) return byNet;

      final byPositive = b.positivePoints.compareTo(a.positivePoints);
      if (byPositive != 0) return byPositive;

      return a.patrolName.toLowerCase().compareTo(b.patrolName.toLowerCase());
    });

    var maxNetScore = summaries.first.netScore;
    for (var i = 1; i < summaries.length; i++) {
      if (summaries[i].netScore > maxNetScore) {
        maxNetScore = summaries[i].netScore;
      }
    }
    if (maxNetScore < 0) {
      maxNetScore = 0;
    }

    return PointsSummaryAggregate(
      patrols: List.unmodifiable(summaries),
      totalNetScore: summaries.fold<int>(0, (sum, item) => sum + item.netScore),
      totalEntries: summaries.fold<int>(
        0,
        (sum, item) => sum + item.pointCount,
      ),
      maxNetScore: maxNetScore,
    );
  }
}
