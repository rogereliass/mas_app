import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/models/user_profile.dart';
import '../data/models/notification_models.dart';
import '../data/notification_repository.dart';
import 'notification_cache_manager.dart';

class NotificationsProvider with ChangeNotifier {
  NotificationsProvider({
    required AuthProvider authProvider,
    NotificationRepository? repository,
    NotificationCacheManager? cacheManager,
  })  : _authProvider = authProvider,
        _repository = repository ?? NotificationRepository(),
        _cacheManager = cacheManager ?? NotificationCacheManager() {
    _authProvider.addListener(_onAuthChanged);
    _authSignature = _buildAuthSignature();
  }

  final AuthProvider _authProvider;
  final NotificationRepository _repository;
  final NotificationCacheManager _cacheManager;
  final Map<String, Future<void>> _inFlightLoads = <String, Future<void>>{};

  List<NotificationRecipientEntry> _items = const <NotificationRecipientEntry>[];
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isSending = false;
  String? _error;
  int _unreadCount = 0;
  String? _authSignature;

  List<NotificationRecipientEntry> get items => _items;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isSending => _isSending;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  bool get canSendNotifications =>
      _repository.canUserSendNotifications(_authProvider.selectedRoleRank);

  List<NotificationTargetType> get availableTargetTypes {
    final rank = _authProvider.selectedRoleRank;
    if (rank >= 90) {
      return const <NotificationTargetType>[
        NotificationTargetType.all,
        NotificationTargetType.troop,
        NotificationTargetType.patrol,
        NotificationTargetType.individual,
      ];
    }

    if (rank == 60 || rank == 70) {
      return const <NotificationTargetType>[
        NotificationTargetType.troop,
        NotificationTargetType.patrol,
        NotificationTargetType.individual,
      ];
    }

    return const <NotificationTargetType>[];
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (_authProvider.profileLoading && _items.isEmpty) {
      _isLoading = true;
      notifyListeners();
      return;
    }

    final profile = _authProvider.currentUserProfile;
    if (profile == null) {
      _clearState();
      return;
    }

    final cacheKey = _cacheKey(profile.id);

    if (!forceRefresh) {
      final lookup = _cacheManager.lookup(cacheKey);
      if (lookup.hasData && lookup.data != null) {
        _applyPanelData(lookup.data!);
        _error = null;
        _isLoading = false;
        notifyListeners();

        if (lookup.isExpired) {
          unawaited(
            _fetchAndCache(
              cacheKey: cacheKey,
              profileId: profile.id,
              isBackground: true,
            ),
          );
        }
        return;
      }

      final inFlight = _inFlightLoads[cacheKey];
      if (inFlight != null) {
        await inFlight;
        return;
      }
    } else {
      _cacheManager.invalidate(cacheKey);
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    await _fetchAndCache(cacheKey: cacheKey, profileId: profile.id);
  }

  Future<void> refresh() async {
    await loadNotifications(forceRefresh: true);
  }

  Future<void> markAsRead(String recipientId) async {
    final index = _items.indexWhere((entry) => entry.id == recipientId);
    if (index < 0) {
      return;
    }

    final current = _items[index];
    if (current.isRead) {
      return;
    }

    final previousItems = _items;
    final previousUnreadCount = _unreadCount;

    final now = DateTime.now();
    final updated = current.copyWith(isRead: true, readAt: now);
    _items = List<NotificationRecipientEntry>.from(_items);
    _items[index] = updated;
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 20);
    _syncCurrentCacheSnapshot();
    notifyListeners();

    try {
      await _repository.markNotificationRead(recipientId: recipientId);
    } catch (_) {
      _items = previousItems;
      _unreadCount = previousUnreadCount;
      _syncCurrentCacheSnapshot();
      notifyListeners();
      await refresh();
    }
  }

  Future<void> markAllAsRead() async {
    final profile = _authProvider.currentUserProfile;
    if (profile == null || _unreadCount == 0) {
      return;
    }

    final previousItems = _items;
    final now = DateTime.now();
    _items = _items
        .map(
          (entry) => entry.isRead
              ? entry
              : entry.copyWith(
                  isRead: true,
                  readAt: now,
                ),
        )
        .toList();
    _unreadCount = 0;
    _syncCurrentCacheSnapshot();
    notifyListeners();

    try {
      await _repository.markAllRead(profileId: profile.id);
    } catch (_) {
      _items = previousItems;
      _unreadCount = previousItems.where((entry) => !entry.isRead).length;
      _syncCurrentCacheSnapshot();
      notifyListeners();
      await refresh();
    }
  }

  Future<NotificationCreateResult> sendNotification({
    required NotificationCreateRequest request,
  }) async {
    final profile = _authProvider.currentUserProfile;
    if (profile == null) {
      throw Exception('User profile is not loaded.');
    }

    final senderRank = _authProvider.selectedRoleRank;
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.sendNotification(
        senderProfile: profile,
        senderRoleRank: senderRank,
        request: request,
      );
      _isSending = false;
      notifyListeners();
      await refresh();
      return result;
    } catch (e) {
      _isSending = false;
      _error = _mapUserFacingError(
        e,
        fallback: 'Could not send notification. Please try again.',
      );
      debugPrint('NotificationsProvider.sendNotification error: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<List<NotificationTargetOption>> loadTroopTargets() {
    final profile = _authProvider.currentUserProfile;
    return _repository.fetchTroopTargets(
      senderRoleRank: _authProvider.selectedRoleRank,
      senderTroopId: (profile?.managedTroopId ?? profile?.signupTroopId)?.trim(),
    );
  }

  Future<List<NotificationTargetOption>> loadPatrolTargets({
    String? selectedTroopId,
  }) {
    final profile = _authProvider.currentUserProfile;
    return _repository.fetchPatrolTargets(
      senderRoleRank: _authProvider.selectedRoleRank,
      senderTroopId: (profile?.managedTroopId ?? profile?.signupTroopId)?.trim(),
      troopId: selectedTroopId,
    );
  }

  Future<List<NotificationTargetOption>> loadIndividualTargets({
    String? selectedTroopId,
  }) {
    final profile = _authProvider.currentUserProfile;
    return _repository.fetchIndividualTargets(
      senderRoleRank: _authProvider.selectedRoleRank,
      senderTroopId: (profile?.managedTroopId ?? profile?.signupTroopId)?.trim(),
      troopId: selectedTroopId,
    );
  }

  Future<int> cleanupSeasonNotifications(String seasonId) {
    return _repository.cleanupSeasonNotifications(seasonId);
  }

  Future<void> _fetchAndCache({
    required String cacheKey,
    required String profileId,
    bool isBackground = false,
  }) async {
    final existing = _inFlightLoads[cacheKey];
    if (existing != null) {
      await existing;
      return;
    }

    if (isBackground) {
      _isRefreshing = true;
      notifyListeners();
    }

    final future = _fetchAndCacheInternal(
      cacheKey: cacheKey,
      profileId: profileId,
      isBackground: isBackground,
    );
    _inFlightLoads[cacheKey] = future;

    try {
      await future;
    } finally {
      if (identical(_inFlightLoads[cacheKey], future)) {
        _inFlightLoads.remove(cacheKey);
      }
    }
  }

  Future<void> _fetchAndCacheInternal({
    required String cacheKey,
    required String profileId,
    required bool isBackground,
  }) async {
    try {
      final panelData = await _repository.fetchPanelData(profileId: profileId);
      _cacheManager.set(cacheKey, panelData);
      _applyPanelData(panelData);
      _error = null;
    } catch (e) {
      if (_items.isEmpty) {
        _error = 'Failed to load notifications. Please try again.';
      }
      debugPrint('NotificationsProvider._fetchAndCacheInternal error: $e');
    } finally {
      _isLoading = false;
      if (isBackground) {
        _isRefreshing = false;
      }
      notifyListeners();
    }
  }

  String _mapUserFacingError(
    Object error, {
    required String fallback,
  }) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return fallback;
    }

    final lower = raw.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('not allowed') ||
        lower.contains('row-level security') ||
        lower.contains('rls') ||
        lower.contains('denied')) {
      return 'You are not allowed to perform this action.';
    }

    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('connection')) {
      return 'Network issue. Please check your connection and try again.';
    }

    if (lower.contains('no active season')) {
      return 'No active season found. Please activate a season first.';
    }

    if (lower.contains('outside your troop scope')) {
      return 'Selected target is outside your allowed scope.';
    }

    return fallback;
  }

  void _onAuthChanged() {
    final nextSignature = _buildAuthSignature();
    if (_authSignature == nextSignature) {
      return;
    }

    _authSignature = nextSignature;

    if (_authProvider.currentUserProfile == null) {
      _inFlightLoads.clear();
      _cacheManager.clear();
      _clearState();
      return;
    }

    if (_authProvider.profileLoading) {
      return;
    }

    unawaited(loadNotifications());
  }

  void _applyPanelData(NotificationPanelData panelData) {
    _items = panelData.notifications;
    _unreadCount = panelData.unreadCount;
  }

  void _syncCurrentCacheSnapshot() {
    final profile = _authProvider.currentUserProfile;
    if (profile == null) {
      return;
    }

    final key = _cacheKey(profile.id);
    _cacheManager.set(
      key,
      NotificationPanelData(notifications: _items, unreadCount: _unreadCount),
    );
  }

  void _clearState() {
    _items = const <NotificationRecipientEntry>[];
    _isLoading = false;
    _isRefreshing = false;
    _isSending = false;
    _error = null;
    _unreadCount = 0;
    notifyListeners();
  }

  String _cacheKey(String profileId) {
    return 'profile:$profileId';
  }

  String _buildAuthSignature() {
    final profile = _authProvider.currentUserProfile;
    if (profile == null) {
      return 'anonymous';
    }

    return [
      profile.id,
      _authProvider.selectedRoleName ?? '',
      _authProvider.selectedRoleRank.toString(),
      profile.managedTroopId ?? '',
      profile.signupTroopId ?? '',
    ].join('|');
  }
}
