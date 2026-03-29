import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:masapp/auth/logic/auth_provider.dart';
import 'package:masapp/core/services/connectivity_service.dart';
import 'package:masapp/core/utils/review_mode.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';
import 'package:masapp/offline/offline_action_queue.dart';
import 'package:masapp/routing/navigation_service.dart';
import '../data/models/attendance_record.dart';
import '../data/attendance_service.dart';
import '../../meeting_creation/data/meetings_service.dart';

enum AttendanceScanMarkResultType {
  markedPresent,
  alreadyPresent,
  invalidContext,
  unauthorized,
  error,
}

class AttendanceScanMarkResult {
  const AttendanceScanMarkResult({
    required this.type,
    this.memberName,
    this.errorMessage,
  });

  final AttendanceScanMarkResultType type;
  final String? memberName;
  final String? errorMessage;
}

/// Provider for the Attendance feature.
///
/// Loads meetings for a given troop+season, lets the user navigate between
/// them, and manages local attendance edits with batch-save semantics.
class AttendanceProvider with ChangeNotifier {
  final AttendanceService _attendanceService;
  final MeetingsService _meetingsService;
  final AuthProvider _authProvider;
  final OfflineActionQueue _offlineQueue = OfflineActionQueue.instance;

  // ── State ──────────────────────────────────────────────────────────────────

  List<Meeting> _meetings = [];
  String? _selectedMeetingId;

  List<MemberWithAttendance> _members = [];

  /// Current (locally editable) attendance status keyed by profileId.
  Map<String, AttendanceStatus> _localAttendance = {};

  /// Snapshot taken at load time — used for change detection.
  Map<String, AttendanceStatus> _originalAttendance = {};

  /// ProfileIds whose status has been modified since the last save.
  final Set<String> _modifiedProfileIds = {};

  /// Attendance record IDs keyed by profileId — required for batch updates.
  Map<String, String> _recordIdByProfileId = {};

  /// In-memory notes cache updated after a successful note save.
  /// Keyed by profileId; overrides the value from member.record?.notes.
  Map<String, String?> _localNotes = {};

  /// Patrol name → sorted member list (members assigned to a patrol).
  Map<String, List<MemberWithAttendance>> _patrolGroups = {};

  /// Members not assigned to any patrol.
  List<MemberWithAttendance> _unassignedMembers = [];

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  bool _noMeetings = false;
  DateTime? _attendanceLastUpdated;
  String? _currentTroopId;
  String? _currentSeasonId;

  // -- Scout Personal Logs --
  List<MyAttendanceLog> _myLogs = [];
  List<MyAttendanceLog> get myLogs => _myLogs;

  DateTime get _todayLocalStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isBeforeToday(DateTime meetingDate) {
    final localDate = meetingDate.toLocal();
    final meetingDay = DateTime(localDate.year, localDate.month, localDate.day);
    return meetingDay.isBefore(_todayLocalStart);
  }

  Iterable<MyAttendanceLog> get _pastLogs =>
      _myLogs.where((log) => _isBeforeToday(log.meeting.meetingDate));

  List<MyAttendanceLog> get pastMyLogs => List.unmodifiable(_pastLogs.toList());

  AttendanceStatus _statusForScoutLog(MyAttendanceLog log) {
    return log.record?.status ?? AttendanceStatus.absent;
  }

  int _countRecordedStatus(AttendanceStatus status) {
    return _pastLogs.where((log) => _statusForScoutLog(log) == status).length;
  }

  int get scoutTotalPastMeetings => _pastLogs.length;
  int get scoutPresentCount => _countRecordedStatus(AttendanceStatus.present);
  int get scoutAbsentCount => _countRecordedStatus(AttendanceStatus.absent);
  int get scoutLateCount => _countRecordedStatus(AttendanceStatus.late);
  int get scoutExcusedCount => _countRecordedStatus(AttendanceStatus.excused);
  int get scoutRecordedCount =>
      scoutPresentCount + scoutAbsentCount + scoutLateCount + scoutExcusedCount;
  int get scoutUnrecordedCount {
    final unrecorded = scoutTotalPastMeetings - scoutRecordedCount;
    return unrecorded > 0 ? unrecorded : 0;
  }

  // ── Constructor / lifecycle ────────────────────────────────────────────────

  AttendanceProvider({
    AttendanceService? attendanceService,
    MeetingsService? meetingsService,
    required AuthProvider authProvider,
  }) : _attendanceService = attendanceService ?? AttendanceService.instance(),
       _meetingsService = meetingsService ?? MeetingsService.instance(),
       _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
    _registerOfflineHandlers();
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _attendanceService.clearCache();
    _meetingsService.clearCache();
    _meetings = [];
    _myLogs = [];
    _selectedMeetingId = null;
    _noMeetings = false;
    _attendanceLastUpdated = null;
    _error = null;
    _clearMemberState();
    notifyListeners();
  }

  /// Called by [ProxyProvider] on every ancestor rebuild — no-op to preserve state.
  void update(AuthProvider auth) {
    // no-op
  }

  // ── Computed properties ────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get noMeetings => _noMeetings;
  List<Meeting> get meetings => List.unmodifiable(_meetings);
  String? get selectedMeetingId => _selectedMeetingId;
  DateTime? get attendanceLastUpdated => _attendanceLastUpdated;

  /// The currently selected [Meeting].
  ///
  /// Falls back to the first meeting when the stored ID no longer matches
  /// (e.g. after a reload). Returns null when [_meetings] is empty.
  Meeting? get selectedMeeting {
    if (_meetings.isEmpty) return null;
    return _meetings.firstWhere(
      (m) => m.id == _selectedMeetingId,
      orElse: () => _meetings.first,
    );
  }

  Map<String, List<MemberWithAttendance>> get patrolGroups =>
      Map.unmodifiable(_patrolGroups);
  List<MemberWithAttendance> get unassignedMembers =>
      List.unmodifiable(_unassignedMembers);

  /// True when any local attendance status differs from the saved snapshot.
  bool get hasUnsavedChanges => _modifiedProfileIds.isNotEmpty;

  /// Number of attendance records modified since the last save.
  int get modifiedCount => _modifiedProfileIds.length;

  /// Rank >= 60 can edit attendance.
  /// Uses globally selected role context from AuthProvider.
  bool get isEditor => _authProvider.selectedRoleRank >= 60;

  /// Rank < 60 — regular member view (only sees own record).
  /// Uses globally selected role context from AuthProvider.
  bool get isRegularMember => _authProvider.selectedRoleRank < 60;
  bool get _isReviewDemoAccount => isReviewDemoEmail(_authProvider.userEmail);

  /// Returns the current local [AttendanceStatus] for [profileId].
  /// Defaults to [AttendanceStatus.absent] when no record exists.
  AttendanceStatus statusFor(String profileId) =>
      _localAttendance[profileId] ?? AttendanceStatus.absent;

  /// Returns the current note for [profileId] — prefers the in-memory cache
  /// over the attached record so freshly saved notes are reflected instantly.
  String? notesFor(String profileId) {
    if (_localNotes.containsKey(profileId)) return _localNotes[profileId];
    try {
      return _members.firstWhere((m) => m.profileId == profileId).record?.notes;
    } catch (_) {
      return null;
    }
  }

  // ── Public methods ─────────────────────────────────────────────────────────

  /// Loads the list of meetings for [troopId] + [seasonId] and auto-selects
  /// the most relevant one (today → next upcoming → last past).
  Future<void> loadMeetings({
    required String troopId,
    required String seasonId,
  }) async {
    _currentTroopId = troopId;
    _currentSeasonId = seasonId;
    _isLoading = true;
    _noMeetings = false;
    _attendanceLastUpdated = null;
    _error = null;
    notifyListeners();

    try {
      // If user is not an editor (e.g., Scout/Rover rank), fetch their personal logs
      if (!isEditor) {
        final profileId = _authProvider.currentUserProfile?.id;
        if (profileId != null) {
          _myLogs = await _attendanceService.fetchMyAttendanceForSeason(
            profileId: profileId,
            troopId: troopId,
            seasonId: seasonId,
          );
          _meetings = _myLogs.map((log) => log.meeting).toList();
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      final fetched = await _meetingsService.fetchMeetings(
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
        _meetings = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      _meetings = normalizedMeetings;
      _selectedMeetingId = _pickBestMeeting(normalizedMeetings);
      _isLoading = false;
      notifyListeners();

      if (_selectedMeetingId != null) {
        await _loadAttendance();
      }
    } catch (e, st) {
      debugPrint('AttendanceProvider.loadMeetings error: $e\n$st');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switches to [meetingId] and loads its attendance records.
  ///
  /// If there are unsaved changes the UI should guard against navigation
  /// using [hasUnsavedChanges] before calling this.
  Future<void> selectMeeting(String meetingId) async {
    if (!_meetings.any((meeting) => meeting.id == meetingId)) {
      debugPrint(
        'AttendanceProvider.selectMeeting: ignoring unknown meetingId=$meetingId',
      );
      return;
    }
    if (_selectedMeetingId == meetingId) return;
    _selectedMeetingId = meetingId;
    _clearMemberState();
    notifyListeners();
    await _loadAttendance();
  }

  /// Applies a local status change for [profileId] — does NOT persist.
  void updateStatus(String profileId, AttendanceStatus newStatus) {
    _localAttendance[profileId] = newStatus;

    if (newStatus == _originalAttendance[profileId]) {
      _modifiedProfileIds.remove(profileId);
    } else {
      _modifiedProfileIds.add(profileId);
    }

    notifyListeners();
  }

  /// Immediately persists a note for [profileId]'s current attendance record.
  /// Updates the in-memory cache and notifies listeners on success.
  Future<void> updateNotes(String profileId, String? notes) async {
    if (_isReviewDemoAccount) {
      _localNotes[profileId] = (notes?.trim().isEmpty ?? true)
          ? null
          : notes!.trim();
      NavigationService.showMessage(kReviewModeSuccessMessage);
      notifyListeners();
      return;
    }

    final recordId = _recordIdByProfileId[profileId];
    if (recordId == null) {
      debugPrint(
        'AttendanceProvider.updateNotes: no recordId for $profileId — skipped',
      );
      return;
    }

    if (!ConnectivityService.instance.isOnline) {
      await _offlineQueue.enqueue(
        type: 'attendance',
        payload: <String, dynamic>{
          'operation': 'update_notes',
          'recordId': recordId,
          'meetingId': _selectedMeetingId,
          'notes': notes,
        },
      );
      _localNotes[profileId] = (notes?.trim().isEmpty ?? true)
          ? null
          : notes!.trim();
      NavigationService.showMessage(
        'Action saved offline and will sync automatically',
      );
      notifyListeners();
      return;
    }

    await _attendanceService.updateAttendanceNotes(
      recordId: recordId,
      meetingId: _selectedMeetingId,
      notes: notes,
    );
    _localNotes[profileId] = (notes?.trim().isEmpty ?? true)
        ? null
        : notes!.trim();
    notifyListeners();
  }

  /// Persists all locally modified records via a single batch update.
  Future<void> saveChanges() async {
    if (_modifiedProfileIds.isEmpty || _isSaving) return;

    if (_isReviewDemoAccount) {
      for (final profileId in _modifiedProfileIds) {
        final current = _localAttendance[profileId];
        if (current != null) {
          _originalAttendance[profileId] = current;
        }
      }
      _modifiedProfileIds.clear();
      _error = null;
      NavigationService.showMessage(kReviewModeSuccessMessage);
      notifyListeners();
      return;
    }

    _isSaving = true;
    notifyListeners();

    try {
      final currentUserProfileId = _authProvider.currentUserProfile?.id;
      final changedRecords = <AttendanceRecord>[];

      final orderedProfileIds = _modifiedProfileIds.toList()..sort();

      for (final profileId in orderedProfileIds) {
        final recordId = _recordIdByProfileId[profileId];
        if (recordId == null) {
          // Shouldn't happen after lazy-fill, but skip gracefully.
          debugPrint(
            'AttendanceProvider.saveChanges: no recordId for $profileId — skipping',
          );
          continue;
        }

        final status = _localAttendance[profileId];
        if (status == null) continue;

        changedRecords.add(
          AttendanceRecord(
            id: recordId,
            meetingId: _selectedMeetingId!,
            profileId: profileId,
            status: status,
            markedByProfileId: currentUserProfileId,
            markedAt: DateTime.now(),
            notes: null,
          ),
        );
      }

      if (!ConnectivityService.instance.isOnline) {
        await _offlineQueue.enqueue(
          type: 'attendance',
          payload: <String, dynamic>{
            'operation': 'batch_update',
            'records': changedRecords
                .map(
                  (record) => <String, dynamic>{
                    'id': record.id,
                    'meetingId': record.meetingId,
                    'profileId': record.profileId,
                    'status': record.status.dbValue,
                    'markedByProfileId': record.markedByProfileId,
                  },
                )
                .toList(growable: false),
          },
        );

        for (final profileId in _modifiedProfileIds) {
          final current = _localAttendance[profileId];
          if (current != null) _originalAttendance[profileId] = current;
        }
        _modifiedProfileIds.clear();
        NavigationService.showMessage(
          'Action saved offline and will sync automatically',
        );
        return;
      }

      await _attendanceService.batchUpdateAttendance(changedRecords);

      // Sync snapshot so hasUnsavedChanges resets.
      for (final profileId in _modifiedProfileIds) {
        final current = _localAttendance[profileId];
        if (current != null) _originalAttendance[profileId] = current;
      }
      _modifiedProfileIds.clear();
    } catch (e, st) {
      debugPrint('AttendanceProvider.saveChanges error: $e\n$st');
      _error = e.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Handles a single scanned profile by marking it Present and persisting immediately.
  /// Reuses existing status update + save flow, including offline queue behavior.
  Future<AttendanceScanMarkResult> markPresentFromScan(String profileId) async {
    if (!isEditor) {
      return const AttendanceScanMarkResult(
        type: AttendanceScanMarkResultType.unauthorized,
      );
    }

    if (_selectedMeetingId == null) {
      return const AttendanceScanMarkResult(
        type: AttendanceScanMarkResultType.invalidContext,
      );
    }

    MemberWithAttendance? member;
    for (final currentMember in _members) {
      if (currentMember.profileId == profileId) {
        member = currentMember;
        break;
      }
    }

    if (member == null) {
      return const AttendanceScanMarkResult(
        type: AttendanceScanMarkResultType.invalidContext,
      );
    }

    if (statusFor(profileId) == AttendanceStatus.present) {
      return AttendanceScanMarkResult(
        type: AttendanceScanMarkResultType.alreadyPresent,
        memberName: member.displayName,
      );
    }

    final previousStatus = statusFor(profileId);
    updateStatus(profileId, AttendanceStatus.present);

    _error = null;
    await saveChanges();

    if (_error != null) {
      // Preserve data integrity for unexpected online failures by restoring local state.
      updateStatus(profileId, previousStatus);

      return AttendanceScanMarkResult(
        type: AttendanceScanMarkResultType.error,
        memberName: member.displayName,
        errorMessage: 'Failed to mark attendance. Please try again.',
      );
    }

    return AttendanceScanMarkResult(
      type: AttendanceScanMarkResultType.markedPresent,
      memberName: member.displayName,
    );
  }

  /// Clears the current error and notifies listeners.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> retryLoadCurrentScope() async {
    final troopId = _currentTroopId;
    final seasonId = _currentSeasonId;
    if (troopId == null || seasonId == null) return;
    await loadMeetings(troopId: troopId, seasonId: seasonId);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Loads attendance for [_selectedMeetingId]:
  /// fetches members + existing records, optionally lazy-fills absent rows
  /// for editors, then builds patrol groups.
  Future<void> _loadAttendance() async {
    if (_selectedMeetingId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Determine the troop for the selected meeting.
      final meeting = _meetings.firstWhere((m) => m.id == _selectedMeetingId);
      // Always use troop_context (managedTroopId) as the source of truth.
      // For editors/admins the troop comes from the meeting row itself;
      // for regular members it comes from their own profile_roles troop_context.
      final String? troopId = isRegularMember
          ? _authProvider.currentUserProfile?.managedTroopId
          : meeting.troopId;

      // Cannot proceed without a valid troop ID
      if (troopId == null) {
        _error = 'Could not determine troop for this meeting.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final currentUserProfileId = _authProvider.currentUserProfile?.id;

      // Fetch troop members; regular members only see themselves.
      final memberProfileIdFilter = isRegularMember
          ? currentUserProfileId
          : null;

      final fetchedMembers = await _attendanceService.fetchTroopMembers(
        troopId: troopId,
        memberProfileIdFilter: memberProfileIdFilter,
      );

      // Fetch existing attendance records for this meeting.
      List<AttendanceRecord> records = await _attendanceService
          .fetchAttendanceForMeeting(_selectedMeetingId!);
      _attendanceLastUpdated = _attendanceService.getAttendanceLastUpdated(
        _selectedMeetingId!,
      );
      unawaited(_refreshAttendanceInBackground(_selectedMeetingId!));

      // Build lookup maps from existing records.
      _recordIdByProfileId = {for (final r in records) r.profileId: r.id};
      _localAttendance = {for (final r in records) r.profileId: r.status};
      _originalAttendance = Map.from(_localAttendance);
      _modifiedProfileIds.clear();

      // Editors: lazily create absent records for members with no row yet.
      if (isEditor) {
        final missingProfileIds = fetchedMembers
            .map((m) => m.profileId)
            .where((id) => !_recordIdByProfileId.containsKey(id))
            .toList();

        if (missingProfileIds.isNotEmpty) {
          final shouldAttemptAutoFill =
              !_isReviewDemoAccount && currentUserProfileId != null;

          if (shouldAttemptAutoFill) {
            try {
              await _attendanceService.lazyAutoFillAbsent(
                meetingId: _selectedMeetingId!,
                memberProfileIds: missingProfileIds,
                markedByProfileId: currentUserProfileId,
              );

              // Re-fetch so we have the newly created record IDs.
              records = await _attendanceService.fetchAttendanceForMeeting(
                _selectedMeetingId!,
              );
              _attendanceLastUpdated =
                  _attendanceService.getAttendanceLastUpdated(
                    _selectedMeetingId!,
                  );

              _recordIdByProfileId = {
                for (final r in records) r.profileId: r.id,
              };
            } catch (e, st) {
              // Read-only users should still be able to view attendance.
              debugPrint(
                'AttendanceProvider._loadAttendance lazyAutoFillAbsent skipped: $e\n$st',
              );
            }
          }

          // Ensure members without DB rows still render in local read state.
          for (final id in missingProfileIds) {
            _localAttendance.putIfAbsent(id, () => AttendanceStatus.absent);
            _originalAttendance.putIfAbsent(id, () => AttendanceStatus.absent);
          }
        }
      }

      // Attach latest AttendanceRecord to each MemberWithAttendance.
      final recordByProfileId = {for (final r in records) r.profileId: r};
      _members = fetchedMembers
          .map((m) => m.copyWith(record: recordByProfileId[m.profileId]))
          .toList();

      _buildPatrolGroups(_members);
    } catch (e, st) {
      debugPrint('AttendanceProvider._loadAttendance error: $e\n$st');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshAttendanceInBackground(String meetingId) async {
    try {
      final refreshed = await _attendanceService.refreshAttendanceForMeeting(
        meetingId,
      );
      if (_selectedMeetingId != meetingId) return;

      final existingIds = _recordIdByProfileId.values.toSet();
      final refreshedIds = refreshed.map((record) => record.id).toSet();
      if (setEquals(existingIds, refreshedIds)) {
        _attendanceLastUpdated = _attendanceService.getAttendanceLastUpdated(
          meetingId,
        );
        return;
      }

      _attendanceLastUpdated = _attendanceService.getAttendanceLastUpdated(
        meetingId,
      );
      await _loadAttendance();
    } catch (_) {
      // Keep current in-memory state if background refresh fails.
    }
  }

  /// Groups [members] into [_patrolGroups] and [_unassignedMembers].
  /// Each group is sorted alphabetically by [MemberWithAttendance.displayName].
  void _buildPatrolGroups(List<MemberWithAttendance> members) {
    final Map<String, List<MemberWithAttendance>> groups = {};
    final List<MemberWithAttendance> unassigned = [];

    for (final member in members) {
      final patrol = member.patrolName;
      if (patrol != null && patrol.isNotEmpty) {
        groups.putIfAbsent(patrol, () => []).add(member);
      } else {
        unassigned.add(member);
      }
    }

    // Sort each patrol group alphabetically.
    for (final list in groups.values) {
      list.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    }
    unassigned.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    _patrolGroups = groups;
    _unassignedMembers = unassigned;
  }

  /// Clears all member/attendance state without touching the meetings list.
  void _clearMemberState() {
    _members = [];
    _localAttendance = {};
    _originalAttendance = {};
    _modifiedProfileIds.clear();
    _recordIdByProfileId = {};
    _localNotes = {};
    _patrolGroups = {};
    _unassignedMembers = [];
  }

  /// Picks the most relevant meeting to show first:
  /// 1. A meeting whose [meetingDate] is today.
  /// 2. The nearest future meeting.
  /// 3. The most recent past meeting.
  String? _pickBestMeeting(List<Meeting> meetings) {
    if (meetings.isEmpty) return null;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Prefer today's meeting.
    for (final m in meetings) {
      final d = DateTime(
        m.meetingDate.year,
        m.meetingDate.month,
        m.meetingDate.day,
      );
      if (d == todayDate) return m.id;
    }

    // Next upcoming meeting (closest future date).
    final upcoming = meetings.where((m) {
      final d = DateTime(
        m.meetingDate.year,
        m.meetingDate.month,
        m.meetingDate.day,
      );
      return d.isAfter(todayDate);
    }).toList()..sort((a, b) => a.meetingDate.compareTo(b.meetingDate));

    if (upcoming.isNotEmpty) return upcoming.first.id;

    // Fall back to the most recent past meeting.
    final past = meetings.toList()
      ..sort((a, b) => b.meetingDate.compareTo(a.meetingDate));
    return past.first.id;
  }

  void _registerOfflineHandlers() {
    _offlineQueue.registerValidator('attendance', (payload) {
      final operation = payload['operation'];
      if (operation is! String || operation.isEmpty) {
        return false;
      }

      switch (operation) {
        case 'update_notes':
          return payload['recordId'] is String;
        case 'batch_update':
          return payload['records'] is List;
        default:
          return false;
      }
    });

    _offlineQueue.registerHandler('attendance', (payload) async {
      final operation = payload['operation'] as String?;
      if (operation == null) return;

      switch (operation) {
        case 'update_notes':
          await _attendanceService.updateAttendanceNotes(
            recordId: payload['recordId'] as String,
            meetingId: payload['meetingId'] as String?,
            notes: payload['notes'] as String?,
          );
          break;
        case 'batch_update':
          final rows =
              (payload['records'] as List<dynamic>? ?? const <dynamic>[])
                  .whereType<Map>()
                  .map(
                    (row) => AttendanceRecord(
                      id: row['id'] as String,
                      meetingId: row['meetingId'] as String,
                      profileId: row['profileId'] as String,
                      status: AttendanceStatusX.fromString(
                        (row['status'] as String?) ?? 'absent',
                      ),
                      markedByProfileId: row['markedByProfileId'] as String?,
                      markedAt: DateTime.now(),
                      notes: null,
                    ),
                  )
                  .toList(growable: false);

          await _attendanceService.batchUpdateAttendance(rows);
          break;
      }
    });
  }
}
