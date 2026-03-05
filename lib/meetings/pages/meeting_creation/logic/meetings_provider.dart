import 'package:flutter/foundation.dart';
import 'package:masapp/auth/logic/auth_provider.dart';
import '../data/models/meeting.dart';
import '../data/meetings_service.dart';

/// Provider for the Meetings feature.
///
/// Manages loading, filtering and creating meetings for a troop/season.
/// Supports both admin (multi-troop) and non-admin (single-troop) flows.
class MeetingsProvider with ChangeNotifier {
  final MeetingsService _service;
  final AuthProvider _authProvider;

  // ── State ──────────────────────────────────────────────────────────────────

  List<Meeting> _meetings = [];

  /// [{id, name}] — populated only for admin users
  List<Map<String, dynamic>> _troops = [];

  /// {id, name, start_date, end_date} — currently active season
  Map<String, dynamic>? _activeSeason;

  /// Troop explicitly chosen by an admin in the UI
  String? _selectedTroopId;

  bool _isLoading = false;
  bool _isCreating = false;
  String? _error;
  bool _noActiveSeason = false;

  // ── Constructor / lifecycle ────────────────────────────────────────────────

  MeetingsProvider({
    MeetingsService? service,
    required AuthProvider authProvider,
  }) : _service = service ?? MeetingsService.instance(),
       _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Reset transient state whenever the authenticated user changes.
  void _onAuthChanged() {
    _meetings = [];
    _troops = [];
    _activeSeason = null;
    _selectedTroopId = null;
    _noActiveSeason = false;
    _error = null;
    notifyListeners();
  }

  void _setTroops(List<Map<String, dynamic>> troops) {
    final deduped = <String, Map<String, dynamic>>{};
    for (final troop in troops) {
      final troopId = troop['id']?.toString();
      if (troopId == null || troopId.isEmpty) continue;
      deduped.putIfAbsent(troopId, () => troop);
    }

    _troops = deduped.values.toList()
      ..sort(
        (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
          (b['name']?.toString() ?? '').toLowerCase(),
        ),
      );

    if (_selectedTroopId != null &&
        !_troops.any((troop) => troop['id'] == _selectedTroopId)) {
      _selectedTroopId = null;
      _meetings = [];
    }
  }

  /// Called by [ProxyProvider] on every ancestor rebuild.
  /// We intentionally do nothing here to preserve loaded state.
  void update(AuthProvider auth) {
    // no-op — state is preserved across ancestor rebuilds
  }

  // ── Computed properties ────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get error => _error;
  bool get noActiveSeason => _noActiveSeason;
  List<Meeting> get meetings => List.unmodifiable(_meetings);
  List<Map<String, dynamic>> get troops => List.unmodifiable(_troops);
  Map<String, dynamic>? get activeSeason => _activeSeason;
  String? get selectedTroopId => _selectedTroopId;

  /// Users with rank >= 60 (Troop Leader, Troop Head, Admin) may create/edit.
  /// Uses globally selected role context from AuthProvider.
  bool get canEdit => _authProvider.selectedRoleRank >= 60;

  /// Users with rank >= 90 are system admins and can see all troops.
  /// Uses globally selected role context from AuthProvider.
  bool get isAdmin => _authProvider.selectedRoleRank >= 90;

  /// Admin who hasn't selected a troop yet — UI should show troop picker.
  bool get needsTroopSelection => isAdmin && _selectedTroopId == null;

  /// The troop this provider operates on:
  /// - Admin: explicitly selected [_selectedTroopId] (may be null until chosen)
  /// - All other roles: their [managedTroopId] (troop_context from profile_roles)
  String? get effectiveTroopId {
    if (isAdmin) return _selectedTroopId;
    return _authProvider.currentUserProfile?.managedTroopId;
  }

  String? get activeSeasonId => _activeSeason?['id'] as String?;

  // ── Public methods ─────────────────────────────────────────────────────────

  /// Entry point — call once from the UI's [initState] / [didChangeDependencies].
  ///
  /// 1. Fetches the active season.
  /// 2. For admins: loads the full troops list so they can pick a troop.
  /// 3. For non-admins: immediately loads meetings for their troop.
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    _noActiveSeason = false;
    notifyListeners();

    try {
      final season = await _service.fetchActiveSeason();

      if (season == null) {
        _noActiveSeason = true;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _activeSeason = season;

      if (isAdmin) {
        final fetchedTroops = await _service.fetchTroops();
        _setTroops(fetchedTroops);
        _isLoading = false;
        notifyListeners();
        // Admin still needs to selectTroop() before meetings load.
      } else {
        // Non-admin: troop is implicit — load immediately.
        // loadMeetings() sets _isLoading = false internally.
        await loadMeetings();
      }
    } catch (e, st) {
      debugPrint('MeetingsProvider.init error: $e\n$st');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches meetings for [effectiveTroopId] + [activeSeasonId].
  /// No-ops when either is unavailable.
  Future<void> loadMeetings() async {
    if (effectiveTroopId == null || activeSeasonId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _meetings = await _service.fetchMeetings(
        seasonId: activeSeasonId!,
        troopId: effectiveTroopId!,
      );
    } catch (e, st) {
      debugPrint('MeetingsProvider.loadMeetings error: $e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Admin-only: sets the active troop and reloads meetings.
  void selectTroop(String troopId) {
    if (!_troops.any((troop) => troop['id'] == troopId)) {
      debugPrint(
        'MeetingsProvider.selectTroop: ignoring unknown troopId=$troopId',
      );
      return;
    }
    if (_selectedTroopId == troopId) return;
    _selectedTroopId = troopId;
    _meetings = [];
    notifyListeners();
    loadMeetings();
  }

  /// Creates a new meeting and prepends it to [meetings].
  Future<void> createMeeting({
    required String title,
    required String location,
    required DateTime meetingDate,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    int? price,
  }) async {
    if (_isCreating || effectiveTroopId == null || activeSeasonId == null)
      return;

    final createdByProfileId = _authProvider.currentUserProfile?.id;
    if (createdByProfileId == null) {
      _error = 'Cannot create meeting: user profile not available.';
      notifyListeners();
      return;
    }

    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final newMeeting = await _service.createMeeting(
        troopId: effectiveTroopId!,
        seasonId: activeSeasonId!,
        title: title,
        location: location,
        meetingDate: meetingDate,
        startsAt: startsAt,
        endsAt: endsAt,
        description: description,
        price: price,
        createdByProfileId: createdByProfileId,
      );
      _meetings = [..._meetings, newMeeting]
        ..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));
    } catch (e, st) {
      debugPrint('MeetingsProvider.createMeeting error: $e\n$st');
      _error = e.toString();
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  /// Clears the current error and notifies listeners.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
