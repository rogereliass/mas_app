import 'package:flutter/foundation.dart';
import '../../auth/logic/auth_provider.dart';
import '../../meetings/pages/meeting_creation/data/meetings_service.dart';
import '../../meetings/pages/points/data/points_service.dart';
import '../../meetings/pages/points/data/models/patrol_points_summary.dart';
import '../../meetings/pages/points/logic/points_summary_aggregator.dart';

class SeasonStandingsProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  final PointsService _pointsService;
  final MeetingsService _meetingsService;

  bool _isLoading = false;
  String? _error;
  PointsSummaryAggregate? _aggregate;
  bool _isHiddenForUser = false;
  String? _activeSeasonName;

  bool get isLoading => _isLoading;
  String? get error => _error;
  PointsSummaryAggregate? get aggregate => _aggregate;
  bool get isHiddenForUser => _isHiddenForUser;
  String? get activeSeasonName => _activeSeasonName;

  bool get isReadOnlyMember => _authProvider.selectedRoleRank < 60;

  SeasonStandingsProvider({
    required AuthProvider authProvider,
    PointsService? pointsService,
    MeetingsService? meetingsService,
  })  : _authProvider = authProvider,
        _pointsService = pointsService ?? PointsService.instance(),
        _meetingsService = meetingsService ?? MeetingsService.instance();

  Future<void> fetchStandings() async {
    if (_isLoading) return;

    // Use cached data if it exists except when explicitly refreshing
    if (_aggregate != null || _isHiddenForUser) {
        return;
    }

    _isLoading = true;
    _error = null;
    _isHiddenForUser = false;
    notifyListeners();

    try {
      final profile = _authProvider.currentUserProfile;
      if (profile == null) {
        _error = 'User not authenticated.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final troopId = (profile.managedTroopId ?? profile.signupTroopId)?.trim();
      if (troopId == null || troopId.isEmpty) {
        _error = 'No troop linked.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Check visibility first
      final isHidden = await _pointsService.fetchTroopPointsHidden(troopId: troopId);
      if (isHidden && isReadOnlyMember) {
        _isHiddenForUser = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final season = await _meetingsService.fetchActiveSeason();
      final seasonId = season?['id'] as String?;
      _activeSeasonName = season?['name'] as String?;

      if (seasonId == null || seasonId.isEmpty) {
        _error = 'No active season is running right now.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final points = await _pointsService.fetchPointsForSeason(troopId, seasonId);
      _aggregate = PointsSummaryAggregator.aggregatePatrolScores(points);
    } catch (e) {
      _error = 'Failed to load standings: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refresh() {
      _aggregate = null;
      _isHiddenForUser = false;
      _error = null;
      fetchStandings();
  }
}
