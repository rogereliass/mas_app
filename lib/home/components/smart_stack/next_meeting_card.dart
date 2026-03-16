/// NEXT MEETING CARD
/// Shows the user's next upcoming meeting and keeps the result cached for the
/// current app session to avoid repeated homepage fetches.
library;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masapp/auth/logic/auth_provider.dart';
import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/meetings_service.dart';
import 'package:provider/provider.dart';
import 'smart_stack_card_base.dart';

class NextMeetingCard extends StatefulWidget {
  const NextMeetingCard({super.key});

  @override
  State<NextMeetingCard> createState() => _NextMeetingCardState();
}

class _NextMeetingCardState extends State<NextMeetingCard> with AutomaticKeepAliveClientMixin {
  static final Map<String, _NextMeetingCardData> _sessionCache = {};
  static final Map<String, Future<_NextMeetingCardData>> _inFlightRequests = {};

  bool _isLoading = true;
  String _title = 'Next Meeting';
  String? _subtitle = 'Loading...';
  Meeting? _meeting;
  String? _meetingTitle;
  String? _lastCacheKey;

  static const _colors = [AppColors.primaryBlue, AppColors.accentBlue];

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authProvider = Provider.of<AuthProvider>(context);
    final isWaitingForProfile = authProvider.isAuthenticated &&
        authProvider.profileLoading &&
        authProvider.currentUserProfile == null;

    if (isWaitingForProfile) {
      if (!_isLoading) {
        setState(() {
          _isLoading = true;
          _title = 'Next Meeting';
          _subtitle = 'Loading your next meeting...';
          _meeting = null;
          _meetingTitle = null;
        });
      }
      return;
    }

    final cacheKey = _buildCacheKey(authProvider);
    if (_lastCacheKey == cacheKey) {
      return;
    }

    _lastCacheKey = cacheKey;
    _loadNextMeeting(authProvider: authProvider, cacheKey: cacheKey);
  }

  String _buildCacheKey(AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      return 'guest';
    }

    final profile = authProvider.currentUserProfile;
    if (profile == null) {
      return 'user:${authProvider.currentUser?.id ?? 'unknown'}:profile-unavailable';
    }

    final troopId = profile.managedTroopId ?? profile.signupTroopId;
    return 'user:${profile.id}:troop:${troopId ?? 'none'}';
  }

  Future<void> _loadNextMeeting({
    required AuthProvider authProvider,
    required String cacheKey,
  }) async {
    final cached = _sessionCache[cacheKey];
    if (cached != null) {
      _applyResult(cached, cacheKey);
      return;
    }

    if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
        _title = 'Next Meeting';
        _subtitle = 'Loading your next meeting...';
        _meeting = null;
        _meetingTitle = null;
      });
    }

    final future = _inFlightRequests.putIfAbsent(
      cacheKey,
      () => _resolveNextMeeting(authProvider),
    );

    try {
      final result = await future;
      _sessionCache[cacheKey] = result;
      _applyResult(result, cacheKey);
    } catch (_) {
      const fallback = _NextMeetingCardData(
        title: 'Next Meeting',
        subtitle: 'Unable to load meetings right now.',
      );
      _sessionCache[cacheKey] = fallback;
      _applyResult(fallback, cacheKey);
    } finally {
      if (identical(_inFlightRequests[cacheKey], future)) {
        _inFlightRequests.remove(cacheKey);
      }
    }
  }

  Future<_NextMeetingCardData> _resolveNextMeeting(AuthProvider authProvider) async {
    if (!authProvider.isAuthenticated) {
      return const _NextMeetingCardData(
        title: 'Next Meeting',
        subtitle: 'Sign in to see your upcoming meetings.',
      );
    }

    final profile = authProvider.currentUserProfile;
    if (profile == null) {
      return const _NextMeetingCardData(
        title: 'Next Meeting',
        subtitle: 'We could not load your profile yet.',
      );
    }

    final troopId = (profile.managedTroopId ?? profile.signupTroopId)?.trim();
    if (troopId == null || troopId.isEmpty) {
      return const _NextMeetingCardData(
        title: 'Next Meeting',
        subtitle: 'No troop is linked to your account yet.',
      );
    }

    try {
      final service = MeetingsService.instance();
      final season = await service.fetchActiveSeason();
      final seasonId = season?['id'] as String?;

      if (seasonId == null || seasonId.isEmpty) {
        return const _NextMeetingCardData(
          title: 'Next Meeting',
          subtitle: 'No active season is running right now.',
        );
      }

      final meetings = await service.fetchMeetings(
        seasonId: seasonId,
        troopId: troopId,
      );

      final nextMeeting = _findNextMeeting(meetings);
      if (nextMeeting == null) {
        return const _NextMeetingCardData(
          title: 'Next Meeting',
          subtitle: 'No upcoming meetings are scheduled yet.',
        );
      }

      final meetingTitle = nextMeeting.title.trim().isEmpty
          ? 'Upcoming troop meeting'
          : nextMeeting.title.trim();
      
      final details = _buildMeetingSubtitle(
        meetingTitle: meetingTitle,
        meeting: nextMeeting,
      );

      return _NextMeetingCardData(
        title: 'Next Meeting',
        subtitle: details,
        meeting: nextMeeting,
        meetingTitle: meetingTitle,
      );
    } catch (_) {
      return const _NextMeetingCardData(
        title: 'Next Meeting',
        subtitle: 'Unable to load meetings right now.',
      );
    }
  }

  Meeting? _findNextMeeting(List<Meeting> meetings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = meetings
        .where((meeting) => !meeting.isTemplate && !meeting.meetingDate.isBefore(today))
        .toList()
      ..sort((left, right) => left.meetingDate.compareTo(right.meetingDate));

    if (upcoming.isEmpty) {
      return null;
    }

    return upcoming.first;
  }

  String _buildMeetingSubtitle({
    required String meetingTitle,
    required Meeting meeting,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Your next meeting is: $meetingTitle');

    buffer.write('🗓️ ${_formatMeetingSchedule(meeting)}');

    final location = meeting.location?.trim();
    if (location != null && location.isNotEmpty) {
      buffer.write(' • 📍 $location');
    }

    return buffer.toString();
  }

  String _formatMeetingSchedule(Meeting meeting) {
    final dateLabel = DateFormat('EEE, d MMM').format(meeting.meetingDate);

    if (meeting.startsAt == null) {
      return dateLabel;
    }

    final timeLabel = DateFormat('h:mm a').format(meeting.startsAt!.toLocal());
    return '$dateLabel at $timeLabel';
  }

  void _applyResult(_NextMeetingCardData result, String cacheKey) {
    if (!mounted || _lastCacheKey != cacheKey) {
      return;
    }

    setState(() {
      _isLoading = false;
      _title = result.title;
      _subtitle = result.subtitle;
      _meeting = result.meeting;
      _meetingTitle = result.meetingTitle;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const _LoadingCardBase(colors: _colors);
    }

    Widget? customBody;
    if (_meeting != null && _meetingTitle != null) {
      final theme = Theme.of(context);
      final location = _meeting!.location?.trim();

      customBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your next meeting: ${_meetingTitle!}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.buttonSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.buttonSecondaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.buttonSecondaryLight),
                    const SizedBox(width: 6),
                    Text(
                      _formatMeetingSchedule(_meeting!),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.buttonSecondaryLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (location != null && location.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: AppColors.buttonSecondaryLight.withValues(alpha: 0.8)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          location,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.buttonSecondaryLight.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return SmartStackCardBase(
      icon: Icons.event_available_rounded,
      title: _title,
      subtitle: _subtitle,
      customSubtitle: customBody,
      colors: _colors,
      onColor: AppColors.buttonSecondaryLight,
    );
  }
}

class _NextMeetingCardData {
  final String title;
  final String? subtitle;
  final Meeting? meeting;
  final String? meetingTitle;

  const _NextMeetingCardData({
    required this.title,
    this.subtitle,
    this.meeting,
    this.meetingTitle,
  });
}

class _LoadingCardBase extends StatelessWidget {
  final List<Color> colors;
  const _LoadingCardBase({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.buttonSecondaryLight),
      ),
    );
  }
}
