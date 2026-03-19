import 'package:flutter/foundation.dart';

import '../../auth/logic/auth_provider.dart';
import '../../auth/models/role.dart';
import '../../auth/models/user_profile.dart';
import '../../core/utils/ttl_cache.dart';
import '../data/home_overview_stats_service.dart';
import '../data/models/home_overview_stats.dart';

/// Provider for role-aware home overview row statistics.
///
/// Caches results per scope (admin or troop) and deduplicates in-flight loads
/// so dashboard rebuilds do not trigger duplicate Supabase requests.
class HomeOverviewStatsProvider with ChangeNotifier {
  static const Duration _cacheTtl = Duration(minutes: 2);

  final HomeOverviewStatsService _service;
  final AuthProvider _authProvider;
  final TtlCache<String, Object> _overviewCache = TtlCache();
  final Map<String, Future<void>> _inFlightLoads = <String, Future<void>>{};

  bool _isLoading = false;
  String? _error;
  TroopOverviewStats? _troopStats;
  AdminOverviewStats? _adminStats;
  String? _authSignature;

  HomeOverviewStatsProvider({
    HomeOverviewStatsService? service,
    required AuthProvider authProvider,
  }) : _service = service ?? HomeOverviewStatsService.instance(),
       _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  TroopOverviewStats? get troopStats => _troopStats;
  AdminOverviewStats? get adminStats => _adminStats;

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> loadOverview({bool forceRefresh = false}) async {
    if (_authProvider.profileLoading) {
      _setLoading(true);
      return;
    }

    final effectiveUser = _effectiveUserProfile;
    if (effectiveUser == null) {
      _clearState();
      return;
    }

    final roleRank = effectiveUser.roleRank;
    if (!_isSupportedRank(roleRank)) {
      _clearState();
      return;
    }

    final scopeKey = _buildScopeKey(effectiveUser);

    if (!forceRefresh) {
      final cached = _overviewCache.get(scopeKey);
      if (cached != null) {
        _applyCached(cached);
        _setLoading(false);
        _error = null;
        notifyListeners();
        return;
      }

      final inFlight = _inFlightLoads[scopeKey];
      if (inFlight != null) {
        await inFlight;
        return;
      }
    } else {
      _overviewCache.invalidate(scopeKey);
    }

    _setLoading(true);
    _error = null;

    final loadFuture = _fetchAndStore(scopeKey: scopeKey, effectiveUser: effectiveUser);
    _inFlightLoads[scopeKey] = loadFuture;

    try {
      await loadFuture;
    } finally {
      _inFlightLoads.remove(scopeKey);
    }
  }

  Future<void> refresh() async {
    await loadOverview(forceRefresh: true);
  }

  Future<void> _fetchAndStore({
    required String scopeKey,
    required UserProfile effectiveUser,
  }) async {
    try {
      if (effectiveUser.roleRank >= 90) {
        final data = await _service.fetchAdminOverviewStats(currentUser: effectiveUser);
        _overviewCache.set(scopeKey, data, _cacheTtl);
        _adminStats = data;
        _troopStats = null;
      } else {
        final data = await _service.fetchTroopOverviewStats(currentUser: effectiveUser);
        _overviewCache.set(scopeKey, data, _cacheTtl);
        _troopStats = data;
        _adminStats = null;
      }
      _error = null;
    } catch (e) {
      _error = 'Failed to load overview stats. Please try again.';
      debugPrint('HomeOverviewStatsProvider.loadOverview error: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _onAuthChanged() {
    final nextSignature = _buildAuthSignature();
    if (nextSignature == _authSignature) {
      return;
    }

    _authSignature = nextSignature;

    if (_authProvider.currentUserProfile == null) {
      _overviewCache.clear();
      _inFlightLoads.clear();
      _clearState();
      return;
    }

    _error = null;
    if (_isSupportedRank(_authProvider.selectedRoleRank) &&
        !_authProvider.profileLoading) {
      loadOverview();
    } else {
      notifyListeners();
    }
  }

  bool _isSupportedRank(int rank) {
    return rank == 60 || rank == 70 || rank >= 90;
  }

  String _buildScopeKey(UserProfile profile) {
    if (profile.roleRank >= 90) {
      return 'admin';
    }

    final troopId = (profile.managedTroopId ?? profile.signupTroopId ?? '').trim();
    return 'troop:$troopId';
  }

  String _buildAuthSignature() {
    final profile = _authProvider.currentUserProfile;
    final selectedRole = _authProvider.selectedRoleName ?? '';
    final selectedRoleRank = _authProvider.selectedRoleRank;
    final profileId = profile?.id ?? '';
    final managedTroop = profile?.managedTroopId ?? '';
    final signupTroop = profile?.signupTroopId ?? '';
    return '$profileId|$selectedRole|$selectedRoleRank|$managedTroop|$signupTroop';
  }

  UserProfile? get _effectiveUserProfile {
    final baseProfile = _authProvider.currentUserProfile;
    if (baseProfile == null) {
      return null;
    }

    final selectedRoleName = _authProvider.selectedRoleName;
    if (selectedRoleName == null) {
      return baseProfile;
    }

    final selectedRole = _authProvider.getRoleByName(selectedRoleName);
    if (selectedRole == null) {
      return baseProfile;
    }

    return _copyWithRoleRank(baseProfile, selectedRole);
  }

  UserProfile _copyWithRoleRank(UserProfile baseProfile, Role selectedRole) {
    return UserProfile(
      id: baseProfile.id,
      userId: baseProfile.userId,
      firstName: baseProfile.firstName,
      middleName: baseProfile.middleName,
      lastName: baseProfile.lastName,
      nameAr: baseProfile.nameAr,
      email: baseProfile.email,
      phone: baseProfile.phone,
      address: baseProfile.address,
      birthdate: baseProfile.birthdate,
      gender: baseProfile.gender,
      signupTroopId: baseProfile.signupTroopId,
      generation: baseProfile.generation,
      avatarUrl: baseProfile.avatarUrl,
      roleRank: selectedRole.rank,
      managedTroopId: baseProfile.managedTroopId,
      createdAt: baseProfile.createdAt,
      updatedAt: baseProfile.updatedAt,
    );
  }

  void _applyCached(Object cached) {
    if (cached is AdminOverviewStats) {
      _adminStats = cached;
      _troopStats = null;
      return;
    }

    if (cached is TroopOverviewStats) {
      _troopStats = cached;
      _adminStats = null;
    }
  }

  void _clearState() {
    _isLoading = false;
    _error = null;
    _troopStats = null;
    _adminStats = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_isLoading == loading) {
      return;
    }
    _isLoading = loading;
    notifyListeners();
  }
}
