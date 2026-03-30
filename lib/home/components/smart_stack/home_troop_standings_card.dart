import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/theme_provider.dart';
import '../../../../meetings/pages/points/data/models/patrol_points_summary.dart';
import '../../logic/season_standings_provider.dart';

class HomeTroopStandingsCard extends StatefulWidget {
  const HomeTroopStandingsCard({super.key});

  @override
  State<HomeTroopStandingsCard> createState() => _HomeTroopStandingsCardState();
}

class _HomeTroopStandingsCardState extends State<HomeTroopStandingsCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SeasonStandingsProvider>().fetchStandings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<SeasonStandingsProvider>();
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    if (provider.isLoading && provider.aggregate == null) {
      return const _LoadingShimmer();
    }

    if (provider.error != null) {
      if (provider.error!.contains("season")) {
        return const SizedBox();
      }
      return _buildErrorCard(provider.error!, isDark, theme);
    }

    if (provider.isHiddenForUser) {
      return _buildHiddenMessage(context, isDark, theme);
    }

    final aggregate = provider.aggregate;
    if (aggregate == null || aggregate.patrols.isEmpty) {
      return const SizedBox();
    }

    final allPatrols = aggregate.patrols;
    final top3 = allPatrols.take(3).toList();
    final remaining = allPatrols.length > 3
        ? allPatrols.skip(3).toList()
        : <PatrolPointsSummary>[];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isDark ? 12 : 6,
      shadowColor: isDark
          ? Colors.black87
          : AppColors.overlay.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      clipBehavior: Clip.antiAlias,
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.cardDark,
                    AppColors.cardDark.withValues(alpha: 0.8),
                  ]
                : [
                    AppColors.cardLight,
                    AppColors.backgroundLight.withValues(alpha: 0.5),
                  ],
          ),
        ),
        child: Column(
          children: [
            // Premium Header
            _buildHeader(provider.activeSeasonName ?? "Season", theme, isDark),


            // Visual Podium section
            if (top3.isNotEmpty)
              _PodiumSection(
                top3: top3,
                allPatrols: allPatrols,
                isDark: isDark,
              ),

            // Add extra spacing between podium and remaining rows
            if (top3.isNotEmpty && remaining.isNotEmpty)
              const SizedBox(height: 24),

            // Remaining list with creative indicators
            if (remaining.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: remaining.map((patrol) {
                    final rank = allPatrols.indexOf(patrol) + 1;
                    return _buildStandingsItem(
                      patrol,
                      rank,
                      allPatrols,
                      theme,
                      isDark,
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String seasonName, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEADERBOARD',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$seasonName Standings',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: AppColors.primaryBlue,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsItem(
    PatrolPointsSummary patrol,
    int rank,
    List<PatrolPointsSummary> allPatrols,
    ThemeData theme,
    bool isDark,
  ) {
    double ratio = _calculateRatio(patrol.netScore, allPatrols);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        patrol.patrolName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${patrol.netScore} pts',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: patrol.netScore > 0
                            ? AppColors.success
                            : patrol.netScore < 0
                            ? AppColors.error
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SegmentedProgressBar(ratio: ratio, netScore: patrol.netScore),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateRatio(int current, List<PatrolPointsSummary> all) {
    if (all.isEmpty) return 0.05;
    // Safety: division by zero protection
    final maxScore = all.map((e) => e.netScore.abs()).fold(0, math.max);
    if (maxScore == 0) return 0.05; // Base height for all if everyone has 0
    return (current.abs() / maxScore).clamp(0.05, 1.0);
  }

  Widget _buildErrorCard(String error, bool isDark, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: AppColors.error.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(error, overflow: TextOverflow.ellipsis, maxLines: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHiddenMessage(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.visibility_off_rounded,
            size: 48,
            color: AppColors.sectionHeaderGray,
          ),
          const SizedBox(height: 16),
          Text(
            'Standings Hidden',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          const Text(
            'Points are currently hidden by leadership.',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _PodiumSection extends StatelessWidget {
  final List<PatrolPointsSummary> top3;
  final List<PatrolPointsSummary> allPatrols;
  final bool isDark;

  const _PodiumSection({
    required this.top3,
    required this.allPatrols,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Safety: fold with initial value to handle potential empty lists correctly
    final maxScore = allPatrols.isEmpty
        ? 0
        : allPatrols.map((e) => e.netScore.abs()).fold(0, math.max);

    // Podium order for visual peak: 2, 1, 3
    final List<PatrolPointsSummary?> displayOrder = [
      top3.length > 1 ? top3[1] : null,
      top3.isNotEmpty ? top3[0] : null,
      top3.length > 2 ? top3[2] : null,
    ];

    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: displayOrder.asMap().entries.map((entry) {
          final patrol = entry.value;
          if (patrol == null) return const Expanded(child: SizedBox());

          final rank = allPatrols.indexOf(patrol) + 1;
          final isWinner = rank == 1;
          // Base ratio of 0.2 even if score is 0 so the pillar is visible
          final scoreRatio = maxScore == 0
              ? 0.2
              : (patrol.netScore.abs() / maxScore).clamp(0.2, 1.0);

          return Expanded(
            child: _PodiumPillar(
              patrol: patrol,
              rank: rank,
              ratio: scoreRatio,
              isWinner: isWinner,
              isDark: isDark,
              theme: theme,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PodiumPillar extends StatelessWidget {
  final PatrolPointsSummary patrol;
  final int rank;
  final double ratio;
  final bool isWinner;
  final bool isDark;
  final ThemeData theme;

  const _PodiumPillar({
    required this.patrol,
    required this.rank,
    required this.ratio,
    required this.isWinner,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final height = 120 * ratio;
    final color = _getRankColor(rank);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isWinner) ...[
          const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.rankGold,
            size: 28,
          ),
          const SizedBox(height: 4),
        ],
        Container(
          width: 60,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            patrol.patrolName,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: height),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.elasticOut,
          builder: (context, val, child) {
            return Container(
              width: isWinner ? 54 : 44,
              height: val.clamp(20.0, 160.0), // Min height safety
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.4)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          4,
                          (_) => Container(height: 1, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${patrol.netScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Container(
          width: double.infinity,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
          child: Text(
            '#$rank',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.rankGold;
      case 2:
        return AppColors.rankSilver;
      case 3:
        return AppColors.rankBronze;
      default:
        return AppColors.primaryBlue;
    }
  }
}

class _SegmentedProgressBar extends StatelessWidget {
  final double ratio;
  final int netScore;

  const _SegmentedProgressBar({required this.ratio, required this.netScore});

  @override
  Widget build(BuildContext context) {
    final segments = 10;
    // Even if ratio is low, shown at least 1 segment if it's the leaderboard
    // But if netScore is 0, we can use a neutral empty color
    final filledSegments = (ratio * segments).round().clamp(0, segments);
    final color = netScore > 0
        ? AppColors.success
        : netScore < 0
        ? AppColors.error
        : AppColors.sectionHeaderGray.withValues(alpha: 0.3);

    return Row(
      children: List.generate(segments, (index) {
        final isFilled = index < filledSegments;
        final isActive = isFilled && (netScore != 0);

        return Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: isActive ? color : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(
                  width: 140,
                  height: 28,
                  color: baseColor,
                  highlight: highlightColor,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _shimmerBox(
                      width: 44,
                      height: 80,
                      color: baseColor,
                      highlight: highlightColor,
                    ),
                    _shimmerBox(
                      width: 54,
                      height: 110,
                      color: baseColor,
                      highlight: highlightColor,
                    ),
                    _shimmerBox(
                      width: 44,
                      height: 60,
                      color: baseColor,
                      highlight: highlightColor,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ...List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        _shimmerBox(
                          width: 30,
                          height: 30,
                          isCircle: true,
                          color: baseColor,
                          highlight: highlightColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _shimmerBox(
                            width: double.infinity,
                            height: 40,
                            color: baseColor,
                            highlight: highlightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    bool isCircle = false,
    required Color color,
    required Color highlight,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isCircle ? height / 2 : 12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, highlight, color],
          stops: [
            _controller.value - 0.3,
            _controller.value,
            _controller.value + 0.3,
          ],
        ),
      ),
    );
  }
}
