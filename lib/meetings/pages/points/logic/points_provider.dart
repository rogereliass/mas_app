import 'package:flutter/foundation.dart';

import 'package:masapp/auth/logic/auth_provider.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

import '../data/models/patrol_option.dart';
import '../data/models/point_category.dart';
import '../data/models/point_entry.dart';
import '../data/models/point_form_data.dart';
import '../data/points_service.dart';

/// Provider for Meetings Points tab.
class PointsProvider with ChangeNotifier {
  final PointsService _service;
  final AuthProvider _authProvider;

  List<Meeting> _meetings = [];
  String? _selectedMeetingId;
  List<PointEntry> _points = [];

  final Map<String, List<PatrolOption>> _patrolsByTroop = {};
  final Map<String, List<PointCategory>> _categoriesByTroop = {};

  String? _activeTroopId;

  bool _isLoadingMeetings = false;
  bool _isLoadingPoints = false;
  bool _isLoadingLookups = false;
  bool _isTogglingPointsVisibility = false;
  bool _troopPointsHidden = false;
  bool _isCreatingPoint = false;
  final Set<String> _updatingPointIds = {};
  bool _isCreatingCategory = false;
  final Set<String> _updatingCategoryIds = {};

  bool _noMeetings = false;
  String? _error;

  PointsProvider({PointsService? service, required AuthProvider authProvider})
    : _service = service ?? PointsService.instance(),
      _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void update(AuthProvider auth) {
    // no-op to preserve state during ancestor rebuilds
  }

  bool get isLoadingMeetings => _isLoadingMeetings;
  bool get isLoadingPoints => _isLoadingPoints;
  bool get isLoadingLookups => _isLoadingLookups;
  bool get isTogglingPointsVisibility => _isTogglingPointsVisibility;
  bool get troopPointsHidden => _troopPointsHidden;
  bool get isSubmitting =>
      _isTogglingPointsVisibility ||
      _isCreatingPoint ||
      _updatingPointIds.isNotEmpty ||
      _isCreatingCategory ||
      _updatingCategoryIds.isNotEmpty;
  bool get isCreatingPoint => _isCreatingPoint;
  bool get isCreatingCategory => _isCreatingCategory;

  bool isUpdatingPoint(String pointId) => _updatingPointIds.contains(pointId);
  bool isUpdatingCategory(String categoryId) =>
      _updatingCategoryIds.contains(categoryId);

  bool get noMeetings => _noMeetings;
  String? get error => _error;

  List<Meeting> get meetings => List.unmodifiable(_meetings);
  List<PointEntry> get points => List.unmodifiable(_points);
  String? get selectedMeetingId => _selectedMeetingId;

  bool get canManagePoints => _authProvider.selectedRoleRank >= 60;
  bool get canManageCategories => _authProvider.selectedRoleRank >= 60;
  bool get canTogglePointsVisibility => _authProvider.selectedRoleRank >= 60;
  bool get isSystemAdmin => _authProvider.selectedRoleRank >= 90;
  bool get isReadOnlyMember => _authProvider.selectedRoleRank < 60;

  Meeting? get selectedMeeting {
    if (_meetings.isEmpty) return null;
    return _meetings.firstWhere(
      (meeting) => meeting.id == _selectedMeetingId,
      orElse: () => _meetings.first,
    );
  }

  List<PatrolOption> patrolOptionsForTroop(String troopId) {
    return List.unmodifiable(_patrolsByTroop[troopId] ?? const []);
  }

  List<PointCategory> categoryOptionsForTroop(String troopId) {
    return List.unmodifiable(_categoriesByTroop[troopId] ?? const []);
  }

  Future<void> loadMeetings({
    required String troopId,
    required String seasonId,
  }) async {
    _activeTroopId = troopId;
    _isLoadingMeetings = true;
    _error = null;
    _noMeetings = false;
    _meetings = [];
    _points = [];
    _selectedMeetingId = null;
    _troopPointsHidden = false;
    notifyListeners();

    try {
      final fetched = await _service.fetchMeetings(
        seasonId: seasonId,
        troopId: troopId,
      );

      final dedupedMeetingsById = <String, Meeting>{
        for (final meeting in fetched) meeting.id: meeting,
      };
      final normalizedMeetings = dedupedMeetingsById.values.toList()
        ..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

      if (normalizedMeetings.isEmpty) {
        _noMeetings = true;
        _isLoadingMeetings = false;
        notifyListeners();
        return;
      }

      _meetings = normalizedMeetings;
      _selectedMeetingId = _pickBestMeeting(normalizedMeetings);

      await _loadTroopVisibility(troopId);

      _isLoadingMeetings = false;
      notifyListeners();

      await ensureLookupDataLoaded(troopId);
      if (_selectedMeetingId != null) {
        await _loadPointsForMeeting(_selectedMeetingId!);
      }
    } catch (e, st) {
      debugPrint('PointsProvider.loadMeetings error: $e\n$st');
      _error = _formatErrorMessage(e);
      _isLoadingMeetings = false;
      notifyListeners();
    }
  }

  Future<void> selectMeeting(String meetingId) async {
    if (!_meetings.any((meeting) => meeting.id == meetingId)) {
      debugPrint(
        'PointsProvider.selectMeeting: ignoring unknown meetingId=$meetingId',
      );
      return;
    }

    if (_selectedMeetingId == meetingId) return;

    _selectedMeetingId = meetingId;
    _points = [];
    _error = null;
    notifyListeners();

    await _loadPointsForMeeting(meetingId);
  }

  Future<void> ensureLookupDataLoaded(String troopId) async {
    final hasPatrols = _patrolsByTroop.containsKey(troopId);
    final hasCategories = _categoriesByTroop.containsKey(troopId);

    if (hasPatrols && hasCategories) return;
    if (_isLoadingLookups) return;

    _isLoadingLookups = true;
    _error = null;
    notifyListeners();

    try {
      if (!hasPatrols) {
        _patrolsByTroop[troopId] = await _service.fetchPatrols(
          troopId: troopId,
        );
      }
      if (!hasCategories) {
        _categoriesByTroop[troopId] = await _service.fetchCategories(
          troopId: troopId,
        );
      }
    } catch (e, st) {
      debugPrint('PointsProvider.ensureLookupDataLoaded error: $e\n$st');
      _error = _formatErrorMessage(e);
    } finally {
      _isLoadingLookups = false;
      notifyListeners();
    }
  }

  Future<void> createPoint(PointFormData formData) async {
    if (!canManagePoints) {
      throw Exception('You do not have permission to create points.');
    }
    if (_isCreatingPoint) return;

    final troopId = _activeTroopId;
    final meetingId = _selectedMeetingId;
    final profileId = _authProvider.currentUserProfile?.id;

    if (troopId == null || troopId.isEmpty) {
      throw Exception('Could not determine troop context for this action.');
    }
    if (meetingId == null || meetingId.isEmpty) {
      throw Exception('Please select a meeting first.');
    }
    if (profileId == null || profileId.isEmpty) {
      throw Exception('Could not determine your profile for this action.');
    }

    _isCreatingPoint = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _service.createPoint(
        actorRoleRank: _authProvider.selectedRoleRank,
        troopId: troopId,
        meetingId: meetingId,
        patrolId: formData.patrolId,
        categoryId: formData.categoryId,
        value: formData.value,
        reason: formData.reason,
        awardedByProfileId: profileId,
      );

      if (_selectedMeetingId == meetingId) {
        _points = [created, ..._points]
          ..sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
      }
    } catch (e, st) {
      debugPrint('PointsProvider.createPoint error: $e\n$st');
      _error = _formatErrorMessage(e);
      rethrow;
    } finally {
      _isCreatingPoint = false;
      notifyListeners();
    }
  }

  Future<void> updatePoint(String pointId, PointFormData formData) async {
    if (!canManagePoints) {
      throw Exception('You do not have permission to edit points.');
    }
    if (_updatingPointIds.contains(pointId)) return;

    final troopId = _activeTroopId;
    final meetingId = _selectedMeetingId;

    if (troopId == null || troopId.isEmpty) {
      throw Exception('Could not determine troop context for this action.');
    }
    if (meetingId == null || meetingId.isEmpty) {
      throw Exception('Please select a meeting first.');
    }

    _updatingPointIds.add(pointId);
    _error = null;
    notifyListeners();

    try {
      final updated = await _service.updatePoint(
        actorRoleRank: _authProvider.selectedRoleRank,
        troopId: troopId,
        pointId: pointId,
        meetingId: meetingId,
        patrolId: formData.patrolId,
        categoryId: formData.categoryId,
        value: formData.value,
        reason: formData.reason,
      );

      final nextPoints = [..._points];
      final index = nextPoints.indexWhere((entry) => entry.id == pointId);
      if (index >= 0) {
        nextPoints[index] = updated;
      } else {
        nextPoints.insert(0, updated);
      }
      nextPoints.sort((a, b) => b.sortTimestamp.compareTo(a.sortTimestamp));
      _points = nextPoints;
    } catch (e, st) {
      debugPrint('PointsProvider.updatePoint error: $e\n$st');
      _error = _formatErrorMessage(e);
      rethrow;
    } finally {
      _updatingPointIds.remove(pointId);
      notifyListeners();
    }
  }

  Future<void> togglePointsVisibility() async {
    if (!canTogglePointsVisibility) {
      throw Exception(
        'You do not have permission to update points visibility.',
      );
    }
    if (_isTogglingPointsVisibility) return;

    final troopId = _activeTroopId;
    if (troopId == null || troopId.isEmpty) {
      throw Exception('Could not determine troop context for this action.');
    }

    final nextHiddenState = !_troopPointsHidden;

    _isTogglingPointsVisibility = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updateTroopPointsVisibility(
        actorRoleRank: _authProvider.selectedRoleRank,
        troopId: troopId,
        pointsHidden: nextHiddenState,
      );
      _troopPointsHidden = nextHiddenState;
    } catch (e, st) {
      debugPrint('PointsProvider.togglePointsVisibility error: $e\n$st');
      _error = _formatErrorMessage(e);
      rethrow;
    } finally {
      _isTogglingPointsVisibility = false;
      notifyListeners();
    }
  }

  Future<PointCategory> createCategory({
    required String name,
    String? description,
  }) async {
    if (!canManageCategories) {
      throw Exception('You do not have permission to create categories.');
    }
    if (_isCreatingCategory) {
      throw Exception('Category creation is already in progress.');
    }

    final troopId = _activeTroopId;
    if (troopId == null || troopId.isEmpty) {
      throw Exception('Could not determine troop context for this action.');
    }

    _isCreatingCategory = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _service.createTroopCategory(
        actorRoleRank: _authProvider.selectedRoleRank,
        troopId: troopId,
        name: name,
        description: description,
      );
      _upsertCategoryInCache(troopId: troopId, category: created);
      return created;
    } catch (e, st) {
      debugPrint('PointsProvider.createCategory error: $e\n$st');
      _error = _formatErrorMessage(e);
      rethrow;
    } finally {
      _isCreatingCategory = false;
      notifyListeners();
    }
  }

  Future<PointCategory> updateCategory({
    required String categoryId,
    required String name,
    String? description,
  }) async {
    if (!canManageCategories) {
      throw Exception('You do not have permission to edit categories.');
    }
    if (_updatingCategoryIds.contains(categoryId)) {
      throw Exception('Category update is already in progress.');
    }

    final troopId = _activeTroopId;
    if (troopId == null || troopId.isEmpty) {
      throw Exception('Could not determine troop context for this action.');
    }

    _updatingCategoryIds.add(categoryId);
    _error = null;
    notifyListeners();

    try {
      final updated = await _service.updateTroopCategory(
        actorRoleRank: _authProvider.selectedRoleRank,
        troopId: troopId,
        categoryId: categoryId,
        name: name,
        description: description,
      );
      _upsertCategoryInCache(troopId: troopId, category: updated);
      return updated;
    } catch (e, st) {
      debugPrint('PointsProvider.updateCategory error: $e\n$st');
      _error = _formatErrorMessage(e);
      rethrow;
    } finally {
      _updatingCategoryIds.remove(categoryId);
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> _loadPointsForMeeting(String meetingId) async {
    _isLoadingPoints = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _service.fetchPointsForMeeting(
        meetingId: meetingId,
      );
      if (_selectedMeetingId == meetingId) {
        _points = fetched;
      }
    } catch (e, st) {
      debugPrint('PointsProvider._loadPointsForMeeting error: $e\n$st');
      _error = _formatErrorMessage(e);
      _points = [];
    } finally {
      _isLoadingPoints = false;
      notifyListeners();
    }
  }

  Future<void> _loadTroopVisibility(String troopId) async {
    try {
      _troopPointsHidden = await _service.fetchTroopPointsHidden(
        troopId: troopId,
      );
    } catch (e, st) {
      debugPrint('PointsProvider._loadTroopVisibility error: $e\n$st');
      _troopPointsHidden = false;
    }
  }

  void _upsertCategoryInCache({
    required String troopId,
    required PointCategory category,
  }) {
    final existing = [
      ...(_categoriesByTroop[troopId] ?? const <PointCategory>[]),
    ];
    final index = existing.indexWhere((item) => item.id == category.id);
    if (index >= 0) {
      existing[index] = category;
    } else {
      existing.add(category);
    }

    existing.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    _categoriesByTroop[troopId] = existing;
  }

  void _onAuthChanged() {
    _meetings = [];
    _selectedMeetingId = null;
    _points = [];
    _patrolsByTroop.clear();
    _categoriesByTroop.clear();
    _activeTroopId = null;
    _isLoadingMeetings = false;
    _isLoadingPoints = false;
    _isLoadingLookups = false;
    _isTogglingPointsVisibility = false;
    _troopPointsHidden = false;
    _isCreatingPoint = false;
    _updatingPointIds.clear();
    _isCreatingCategory = false;
    _updatingCategoryIds.clear();
    _noMeetings = false;
    _error = null;
    notifyListeners();
  }

  String _formatErrorMessage(Object error) {
    final value = error.toString().trim();
    if (value.startsWith('Exception:')) {
      return value.replaceFirst('Exception:', '').trim();
    }
    return value;
  }

  String? _pickBestMeeting(List<Meeting> meetings) {
    if (meetings.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final meeting in meetings) {
      final date = DateTime(
        meeting.meetingDate.year,
        meeting.meetingDate.month,
        meeting.meetingDate.day,
      );
      if (date == today) return meeting.id;
    }

    final upcoming = meetings.where((meeting) {
      final date = DateTime(
        meeting.meetingDate.year,
        meeting.meetingDate.month,
        meeting.meetingDate.day,
      );
      return date.isAfter(today);
    }).toList()..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

    if (upcoming.isNotEmpty) return upcoming.first.id;

    final past = meetings.toList()
      ..sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
    return past.first.id;
  }
}
