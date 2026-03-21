/// TROOP OVERVIEW CARD
/// Shows live troop-level patrol and attendance insights for troop leaders.
library;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:masapp/auth/logic/auth_provider.dart';
import 'package:masapp/auth/models/user_profile.dart';
import 'package:masapp/core/constants/app_colors.dart';
import 'package:masapp/home/data/home_overview_stats_service.dart';
import 'package:masapp/home/data/models/home_overview_stats.dart';
import 'package:provider/provider.dart';

import 'smart_stack_card_base.dart';

class TroopOverviewCard extends StatefulWidget {
  const TroopOverviewCard({super.key});

  @override
  State<TroopOverviewCard> createState() => _TroopOverviewCardState();
}

class _TroopOverviewCardState extends State<TroopOverviewCard>
    with AutomaticKeepAliveClientMixin {
  static final Map<String, _TroopOverviewCardData> _sessionCache = {};
  static final Map<String, Future<_TroopOverviewCardData>> _inFlightRequests =
      {};

  static const _colors = [Color(0xFF059669), Color(0xFF047857)];

  bool _isLoading = true;
  String _subtitle = 'Loading troop overview...';
  TroopInsightStats? _insights;
  String? _lastCacheKey;

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
          _subtitle = 'Loading troop overview...';
        });
      }
      return;
    }

    final cacheKey = _buildCacheKey(authProvider);
    if (_lastCacheKey == cacheKey) {
      return;
    }

    _lastCacheKey = cacheKey;
    _loadCardData(authProvider: authProvider, cacheKey: cacheKey);
  }

  String _buildCacheKey(AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      return 'guest';
    }

    final profile = authProvider.currentUserProfile;
    if (profile == null) {
      return 'user:${authProvider.currentUser?.id ?? 'unknown'}:profile-unavailable';
    }

    final troopId = (profile.managedTroopId ?? profile.signupTroopId)?.trim();
    return 'user:${profile.id}:selected-rank:${authProvider.selectedRoleRank}:troop:${troopId ?? 'none'}';
  }

  Future<void> _loadCardData({
    required AuthProvider authProvider,
    required String cacheKey,
  }) async {
    final cached = _sessionCache[cacheKey];
    if (cached != null && _canUseCached(cached)) {
      _applyResult(cached, cacheKey);
      return;
    }

    if (cached != null) {
      _sessionCache.remove(cacheKey);
    }

    if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
        _subtitle = 'Loading troop overview...';
        _insights = null;
      });
    }

    final future = _inFlightRequests.putIfAbsent(
      cacheKey,
      () => _resolveCardData(authProvider),
    );

    try {
      final result = await future;
      _sessionCache[cacheKey] = result;
      _applyResult(result, cacheKey);
    } catch (_) {
      const fallback = _TroopOverviewCardData(
        subtitle: 'Unable to load troop overview right now.',
      );
      _sessionCache[cacheKey] = fallback;
      _applyResult(fallback, cacheKey);
    } finally {
      if (identical(_inFlightRequests[cacheKey], future)) {
        _inFlightRequests.remove(cacheKey);
      }
    }
  }

  bool _canUseCached(_TroopOverviewCardData data) {
    if (data.stats != null) {
      return true;
    }

    return _isFallbackSubtitle(data.subtitle);
  }

  bool _isFallbackSubtitle(String subtitle) {
    return subtitle == 'Sign in to view your troop overview.' ||
        subtitle == 'We could not load your profile yet.' ||
        subtitle == 'Troop overview is available for troop leadership roles.' ||
        subtitle == 'No troop is linked to your account yet.' ||
        subtitle == 'Unable to load troop overview right now.';
  }

  Future<_TroopOverviewCardData> _resolveCardData(
    AuthProvider authProvider,
  ) async {
    if (!authProvider.isAuthenticated) {
      return const _TroopOverviewCardData(
        subtitle: 'Sign in to view your troop overview.',
      );
    }

    final profile = authProvider.currentUserProfile;
    if (profile == null) {
      return const _TroopOverviewCardData(
        subtitle: 'We could not load your profile yet.',
      );
    }

    final effectiveProfile = _effectiveUserProfile(authProvider, profile);

    if (!effectiveProfile.isTroopScoped) {
      return const _TroopOverviewCardData(
        subtitle: 'Troop overview is available for troop leadership roles.',
      );
    }

    final troopId =
        (effectiveProfile.managedTroopId ?? effectiveProfile.signupTroopId)
            ?.trim();
    if (troopId == null || troopId.isEmpty) {
      return const _TroopOverviewCardData(
        subtitle: 'No troop is linked to your account yet.',
      );
    }

    try {
      final service = HomeOverviewStatsService.instance();
      final stats = await service.fetchTroopInsightStats(
        currentUser: effectiveProfile,
      );

      return _TroopOverviewCardData(
        subtitle: 'Troop insights loaded.',
        stats: stats,
      );
    } catch (_) {
      return const _TroopOverviewCardData(
        subtitle: 'Unable to load troop overview right now.',
      );
    }
  }

  UserProfile _effectiveUserProfile(
    AuthProvider authProvider,
    UserProfile profile,
  ) {
    final selectedRoleRank = authProvider.selectedRoleRank;
    if (selectedRoleRank <= 0 || selectedRoleRank == profile.roleRank) {
      return profile;
    }

    return UserProfile(
      id: profile.id,
      userId: profile.userId,
      firstName: profile.firstName,
      middleName: profile.middleName,
      lastName: profile.lastName,
      nameAr: profile.nameAr,
      email: profile.email,
      phone: profile.phone,
      address: profile.address,
      birthdate: profile.birthdate,
      gender: profile.gender,
      signupTroopId: profile.signupTroopId,
      generation: profile.generation,
      avatarUrl: profile.avatarUrl,
      roleRank: selectedRoleRank,
      managedTroopId: profile.managedTroopId,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );
  }

  String _formatAverage(double value) {
    if (value == 0) {
      return '0';
    }

    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  void _applyResult(_TroopOverviewCardData result, String cacheKey) {
    if (!mounted || _lastCacheKey != cacheKey) {
      return;
    }

    setState(() {
      _isLoading = false;
      _subtitle = result.subtitle;
      _insights = result.stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _colors,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.buttonSecondaryLight),
        ),
      );
    }

    final insights = _insights;
    final customSubtitle = insights == null
        ? null
        : _TroopInsightsBody(
            stats: insights,
            averageText: _formatAverage(
              insights.averageScoutsPresentPerMeeting,
            ),
            onColor: Colors.white,
          );

    return SmartStackCardBase(
      icon: Icons.groups_outlined,
      title: 'Troop Overview',
      subtitle: _subtitle,
      customSubtitle: customSubtitle,
      colors: _colors,
      onColor: Colors.white,
      hideHeaderIcon: true,
      titleWeight: FontWeight.w900,
      backgroundIconSize: 90,
      backgroundIconTop: null,
      backgroundIconRight: -10,
      backgroundIconBottom: -15,
    );
  }
}

class _TroopOverviewCardData {
  final String subtitle;
  final TroopInsightStats? stats;

  const _TroopOverviewCardData({required this.subtitle, this.stats});
}

class _TroopInsightsBody extends StatelessWidget {
  final TroopInsightStats stats;
  final String averageText;
  final Color onColor;

  const _TroopInsightsBody({
    required this.stats,
    required this.averageText,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastMeetingDateText = stats.lastMeetingDate == null
        ? '--'
        : DateFormat('d MMM').format(stats.lastMeetingDate!);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'PATROLS',
                value: stats.patrolCount.toString(),
                icon: Icons.groups_2_rounded,
                onColor: onColor,
              ),
              _StatItem(
                label: 'AVG ATTEND',
                value: averageText,
                icon: Icons.how_to_reg_rounded,
                onColor: onColor,
              ),
              _StatItem(
                label: 'LAST SESSION',
                value: lastMeetingDateText,
                icon: Icons.event_rounded,
                onColor: onColor,
              ),
            ],
          ),
          if (stats.lastMeetingDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${stats.lastMeetingPresentCount} scouts attended last meeting',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onColor.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color onColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: onColor.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onColor,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: onColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w900,
            fontSize: 8,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
