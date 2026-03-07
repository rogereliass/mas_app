import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

import '../../data/models/patrol_points_summary.dart';

class PatrolScoreLeaderboard extends StatelessWidget {
  final PointsSummaryAggregate summary;
  final Meeting? selectedMeeting;

  const PatrolScoreLeaderboard({
    super.key,
    required this.summary,
    required this.selectedMeeting,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkElevated : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.overlay.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _LeaderboardHeader(
              selectedMeeting: selectedMeeting,
              totalEntries: summary.totalEntries,
              totalNetScore: summary.totalNetScore,
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 460;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 8 : 12,
                    8,
                    isCompact ? 8 : 12,
                    8,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < summary.patrols.length; i++) ...[
                        _PatrolScoreRow(
                          rank: i + 1,
                          summary: summary.patrols[i],
                          allPatrols: summary.patrols,
                          isCompact: isCompact,
                        ),
                        if (i != summary.patrols.length - 1)
                          const SizedBox(height: 6),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  final Meeting? selectedMeeting;
  final int totalEntries;
  final int totalNetScore;

  const _LeaderboardHeader({
    required this.selectedMeeting,
    required this.totalEntries,
    required this.totalNetScore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleColor = Colors.white;
    final subtitleColor = Colors.white.withValues(alpha: 0.86);

    final headerSubtitle = selectedMeeting == null
        ? 'Selected meeting patrol scores'
        : '${selectedMeeting!.title}  |  ${selectedMeeting!.formattedDate}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.leaderboardHeaderStart.withValues(alpha: 0.8),
                  AppColors.leaderboardHeaderEnd.withValues(alpha: 0.9),
                ]
              : [
                  AppColors.leaderboardHeaderStart,
                  AppColors.leaderboardHeaderEnd,
                ], // Rich deep violet/indigo instead of blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.rankGold,
                  AppColors.rankGold.withValues(alpha: 0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.rankGold.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patrol Leaderboard',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  headerSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${totalNetScore > 0 ? '+' : ''}$totalNetScore pts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalEntries entries',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: subtitleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatrolScoreRow extends StatelessWidget {
  final int rank;
  final PatrolPointsSummary summary;
  final List<PatrolPointsSummary> allPatrols;
  final bool isCompact;

  const _PatrolScoreRow({
    required this.rank,
    required this.summary,
    required this.allPatrols,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rowBg = isDark
        ? AppColors.backgroundDark.withValues(alpha: 0.42)
        : AppColors.backgroundLight.withValues(alpha: 0.75);

    final scoreIsPositive = summary.netScore >= 0;
    final scoreColor = scoreIsPositive ? AppColors.success : AppColors.error;
    final scoreText = '${summary.netScore > 0 ? '+' : ''}${summary.netScore}';

    final fillRatio = _calculateFillRatio(
      current: summary.netScore,
      allPatrols: allPatrols,
    );

    return Semantics(
      label:
          '${summary.patrolName}, rank $rank, net score ${summary.netScore}, ${summary.pointCount} entries.',
      child: Container(
        padding: EdgeInsets.fromLTRB(isCompact ? 8 : 10, 8, 10, 8),
        decoration: BoxDecoration(
          color: rowBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.patrolName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ScoreBadge(scoreText: scoreText, scoreColor: scoreColor),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _ScoreBar(
                    fillRatio: fillRatio,
                    scoreIsPositive: scoreIsPositive,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${summary.positivePoints}  /  -${summary.penaltyPoints}  |  ${summary.pointCount} entries',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateFillRatio({
    required int current,
    required List<PatrolPointsSummary> allPatrols,
  }) {
    if (allPatrols.isEmpty) {
      return 0.0;
    }

    var maxPositive = 0;
    var maxNegativeAbs = 0;
    for (final item in allPatrols) {
      if (item.netScore > maxPositive) {
        maxPositive = item.netScore;
      }
      if (item.netScore < 0) {
        final abs = item.netScore.abs();
        if (abs > maxNegativeAbs) {
          maxNegativeAbs = abs;
        }
      }
    }

    if (current >= 0) {
      if (maxPositive <= 0) {
        return current == 0 ? 0.1 : 1.0;
      }
      final ratio = current / maxPositive;
      return ratio.clamp(0.1, 1.0);
    }

    if (maxNegativeAbs <= 0) {
      return 0.1;
    }
    final ratio = current.abs() / maxNegativeAbs;
    return ratio.clamp(0.1, 1.0);
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color borderColor;
    Color backgroundColor;
    Color textColor;

    if (rank == 1) {
      borderColor = AppColors.rankGold.withValues(alpha: 0.6);
      backgroundColor = AppColors.rankGold.withValues(
        alpha: isDark ? 0.15 : 0.2,
      );
      textColor = AppColors.rankGold;
    } else if (rank == 2) {
      borderColor = AppColors.rankSilver.withValues(alpha: 0.8);
      backgroundColor = AppColors.rankSilver.withValues(
        alpha: isDark ? 0.3 : 0.6,
      );
      textColor = isDark ? Colors.white : const Color(0xFF475569); // Slate 600
    } else if (rank == 3) {
      borderColor = AppColors.rankBronze.withValues(alpha: 0.6);
      backgroundColor = AppColors.rankBronze.withValues(
        alpha: isDark ? 0.15 : 0.2,
      );
      textColor = AppColors.rankBronze;
    } else {
      borderColor = theme.colorScheme.outline.withValues(alpha: 0.35);
      backgroundColor = theme.colorScheme.outlineVariant.withValues(
        alpha: 0.35,
      );
      textColor = theme.colorScheme.onSurface;
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        color: backgroundColor,
        boxShadow: rank <= 3
            ? [
                BoxShadow(
                  color: textColor.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String scoreText;
  final Color scoreColor;

  const _ScoreBadge({required this.scoreText, required this.scoreColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        scoreText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scoreColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double fillRatio;
  final bool scoreIsPositive;

  const _ScoreBar({required this.fillRatio, required this.scoreIsPositive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fillColors = scoreIsPositive
        ? const [
            AppColors.accentBlue,
            AppColors.primaryBlue,
          ] // Brighter blue gradient
        : const [
            Color(0xFFF87171),
            Color(0xFFEF4444),
          ]; // Brighter red gradient (Tailwind red-400 to red-500)

    return SizedBox(
      height: 12, // Slightly thicker
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardDark.withValues(alpha: 0.85)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.22),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: math.max(0.0, math.min(1.0, fillRatio)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: fillColors,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: fillColors.last.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
