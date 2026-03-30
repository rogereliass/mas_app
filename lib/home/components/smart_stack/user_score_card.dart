/// USER SCORE CARD
/// Shows the Scout's current score, rank progression, or points.
/// TO BE IMPLEMENTED: Fetch the scout's points/attendance score from the database.
library;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../meetings/pages/attendance/logic/attendance_provider.dart';
import '../../../meetings/pages/attendance/data/models/attendance_record.dart';
import '../../../meetings/pages/meeting_creation/data/meetings_service.dart';
import '../../../core/constants/app_colors.dart';
import 'smart_stack_card_base.dart';

class UserScoreCard extends StatefulWidget {
  const UserScoreCard({super.key});

  @override
  State<UserScoreCard> createState() => _UserScoreCardState();
}

class _UserScoreCardState extends State<UserScoreCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      try {
        final auth = context.read<AuthProvider>();
        
        // Hide card logic if user is a leader/editor (rank >= 60).
        // Only scouts, patrol leaders, and assistants (rank < 60) should see this.
        if (auth.selectedRoleRank >= 60) {
          return;
        }

        final attendanceProvider = context.read<AttendanceProvider>();
        
        final profile = auth.currentUserProfile;
        final troopId = (profile?.managedTroopId ?? profile?.signupTroopId)?.trim();
        
        if (troopId == null) {
          debugPrint('UserScoreCard: No troop ID found for user');
          return;
        }

        // We need an active season to fetch attendance for a scout
        // Using service directly to ensure we get the latest data without relying on provider initialization order
        final season = await MeetingsService.instance().fetchActiveSeason();
        final seasonId = season?['id'] as String?;

        if (seasonId != null && mounted) {
          // Check if we already have the logs for the same troop and season
          // to prevent unnecessary overriding
          if (attendanceProvider.myLogs.isEmpty) {
            await attendanceProvider.loadMeetings(
              troopId: troopId,
              seasonId: seasonId,
            );
          }
        } else {
          debugPrint('UserScoreCard: No active season found');
        }
      } catch (e) {
        debugPrint('UserScoreCard error: $e');
        // Gracefully handle error - provider state will reflect if data didn't load
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthProvider>();
    
    // The card is only for scouts and patrol leaders/assistants (rank < 60)
    if (auth.selectedRoleRank >= 60) {
      return const SizedBox.shrink();
    }

    final attendanceProvider = context.watch<AttendanceProvider>();
    final theme = Theme.of(context);

    if (attendanceProvider.isLoading) {
      return _buildLoadingState();
    }

    if (attendanceProvider.myLogs.isEmpty) {
      return _buildEmptyState();
    }

    final pastTotal = attendanceProvider.scoutTotalPastMeetings;
    final present = attendanceProvider.scoutPresentCount;
    final lateCount = attendanceProvider.scoutLateCount;
    final excused = attendanceProvider.scoutExcusedCount;
    final absent = attendanceProvider.scoutAbsentCount;
    final unrecorded = attendanceProvider.scoutUnrecordedCount;

    // Keep homepage score consistent with Attendance Insights rows:
    // Present percentage is calculated from total past meetings.
    final double attendanceRate = pastTotal == 0 ? 0 : present / pastTotal;
    final int percentage = (attendanceRate * 100).round();

    // Keep history aligned with the same "before today" cutoff used by stats.
    final history = attendanceProvider.includedLogs.take(6).toList();

    return SmartStackCardBase(
      icon: Icons.auto_graph_rounded,
      title: 'Attendance Score',
      colors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
      onColor: Colors.white,
      hideHeaderIcon: true,
      customSubtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 6),
              _buildModernProgress(percentage),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getInsightText(percentage, history),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _buildHistoryTrend(history),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatGrid(present, lateCount, excused, absent, unrecorded),
        ],
      ),
    );
  }

  Widget _buildModernProgress(int percentage) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.goldAccent.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            strokeWidth: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldAccent),
            strokeCap: StrokeCap.round,
          ),
        ),
        Text(
          '$percentage%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTrend(List<MyAttendanceLog> history) {
    if (history.isEmpty) {
      return Text(
        'Waiting for your first meeting!',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 9,
        ),
      );
    }

    return Row(
      children: history.reversed.map((log) {
        final status = log.record?.status;
        Color color = Colors.white.withValues(alpha: 0.1);
        double size = 8;

        if (log.isRecorded) {
          switch (status) {
            case AttendanceStatus.present:
              color = AppColors.success;
              break;
            case AttendanceStatus.late:
              color = AppColors.warning;
              break;
            case AttendanceStatus.excused:
              color = Colors.blueAccent;
              break;
            case AttendanceStatus.absent:
              color = AppColors.error;
              break;
            default:
              break;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: log.isRecorded ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                )
              ] : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatGrid(int present, int lateCount, int excused, int absent, int unrecorded) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildMiniStat('Pres.', present, AppColors.success),
          const SizedBox(width: 8),
          _buildMiniStat('Late', lateCount, AppColors.warning),
          const SizedBox(width: 8),
          _buildMiniStat('Exc.', excused, Colors.blueAccent),
          const SizedBox(width: 8),
          _buildMiniStat('Abs.', absent, AppColors.error),
          if (unrecorded > 0) ...[
            const SizedBox(width: 8),
            _buildMiniStat('Unrec.', unrecorded, Colors.white.withValues(alpha: 0.6)),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: AppColors.goldAccent,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SmartStackCardBase(
      icon: Icons.auto_graph_rounded,
      title: 'Performance',
      subtitle: 'Attend meetings to unlock stats!',
      colors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
      onColor: Colors.white,
    );
  }

  String _getInsightText(int percentage, List<MyAttendanceLog> history) {
    if (history.length >= 2) {
      final last = history.first.record?.status;
      final secondLast = history[1].record?.status;
      
      if (last == AttendanceStatus.present && secondLast == AttendanceStatus.present) {
        return 'Unstoppable Momentum! 🔥';
      }
      if (last == AttendanceStatus.absent) {
        return 'Missed you last time 😔';
      }
    }

    if (percentage >= 95) return 'Elite Commitment! 🏆';
    if (percentage >= 85) return 'Exceptional Record ✨';
    if (percentage >= 70) return 'Strong Performance 💪';
    if (percentage >= 50) return 'Gaining Momentum 📈';
    if (percentage > 0) return 'Keep Growing 🌱';
    return 'Ready to Start 🚀';
  }
}
