import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/models/user_profile.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../routing/navigation_service.dart';
import '../../../../offline/offline_action_queue.dart';
import '../../patrols_management/data/models/patrol.dart';
import '../data/eftekad_config.dart';
import '../data/eftekad_service.dart';
import '../data/models/eftekad_member.dart';
import '../data/models/eftekad_record.dart';

class EftekadPatrolGroup {
  const EftekadPatrolGroup({
    required this.id,
    required this.name,
    required this.members,
    this.isUnassigned = false,
  });

  final String id;
  final String name;
  final List<EftekadMember> members;
  final bool isUnassigned;
}

class EftekadProvider with ChangeNotifier {
  EftekadProvider({
    required AuthProvider authProvider,
    EftekadService? service,
    OfflineActionQueue? offlineQueue,
  }) : _authProvider = authProvider,
       _service = service ?? EftekadService.instance(),
       _offlineQueue = offlineQueue ?? OfflineActionQueue.instance {
    _authProvider.addListener(_onAuthChanged);
    _registerOfflineHandlers();
  }

  static const String _unassignedPatrolFilterValue = '__unassigned__';

  final AuthProvider _authProvider;
  final EftekadService _service;
  final OfflineActionQueue _offlineQueue;
  final Uuid _uuid = const Uuid();

  String? _selectedRoleName;
  String? _selectedTroopId;

  List<Map<String, dynamic>> _troops = [];
  List<Patrol> _patrols = [];
  List<EftekadMember> _members = [];
  List<EftekadMember> _visibleMembers = [];
  Map<String, DateTime> _lastContactByProfileId = {};

  final Map<String, List<EftekadRecord>> _recordsByProfile =
      <String, List<EftekadRecord>>{};
  final Map<String, int> _recordsOffsetByProfile = <String, int>{};
  final Map<String, bool> _recordsHasMoreByProfile = <String, bool>{};
  final Set<String> _recordsLoadingProfiles = <String>{};

  bool _isLoading = false;
  bool _isLoadingTroops = false;
  bool _isSavingRecord = false;
  String? _error;

  String _searchQuery = '';
  String _committedSearchQuery = '';
  String? _selectedPatrolFilter;
  bool _notContactedOnly = false;
  final Duration _notContactedThreshold = EftekadConfig.notContactedThreshold;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  UserProfile? get _effectiveUserProfile {
    final baseProfile = _authProvider.currentUserProfile;
    if (baseProfile == null) {
      return null;
    }

    if (_selectedRoleName == null) {
      return baseProfile;
    }

    final selectedRole = _authProvider.getRoleByName(_selectedRoleName!);
    if (selectedRole == null) {
      return baseProfile;
    }

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

  bool get isSystemScoped {
    final user = _effectiveUserProfile;
    return user?.hasSystemWideAccess ?? false;
  }

  bool get isLoading => _isLoading;
  bool get isLoadingTroops => _isLoadingTroops;
  bool get isSavingRecord => _isSavingRecord;
  bool get hasError => _error != null;
  String? get error => _error;

  List<Map<String, dynamic>> get troops => _troops;
  List<Patrol> get patrols => _patrols;
  List<EftekadMember> get visibleMembers => _visibleMembers;

  String get searchQuery => _searchQuery;
  String? get selectedTroopId => _selectedTroopId;
  String? get selectedPatrolFilter => _selectedPatrolFilter;
  bool get notContactedOnly => _notContactedOnly;
  Duration get notContactedThreshold => _notContactedThreshold;

  DateTime? lastContactForProfile(String profileId) {
    return _lastContactByProfileId[profileId];
  }

  List<Map<String, String>> get patrolFilterOptions {
    final items =
        _patrols
            .map(
              (patrol) => <String, String>{
                'id': patrol.id,
                'name': patrol.name,
              },
            )
            .toList(growable: false)
          ..sort(
            (a, b) =>
                a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
          );

    return <Map<String, String>>[
      ...items,
      const <String, String>{
        'id': _unassignedPatrolFilterValue,
        'name': 'Unassigned',
      },
    ];
  }

  List<EftekadPatrolGroup> get groupedMembers {
    final grouped = <String, List<EftekadMember>>{};
    final unassigned = <EftekadMember>[];

    for (final member in _visibleMembers) {
      final patrolId = member.patrolId;
      if (patrolId == null || patrolId.isEmpty) {
        unassigned.add(member);
        continue;
      }
      grouped.putIfAbsent(patrolId, () => <EftekadMember>[]).add(member);
    }

    final groups = <EftekadPatrolGroup>[];

    for (final patrol in _patrols) {
      final members = grouped[patrol.id];
      if (members == null || members.isEmpty) {
        continue;
      }
      groups.add(
        EftekadPatrolGroup(id: patrol.id, name: patrol.name, members: members),
      );
    }

    if (unassigned.isNotEmpty) {
      groups.add(
        EftekadPatrolGroup(
          id: _unassignedPatrolFilterValue,
          name: 'Unassigned',
          members: unassigned,
          isUnassigned: true,
        ),
      );
    }

    return groups;
  }

  List<EftekadRecord> recordsForProfile(String profileId) {
    return _recordsByProfile[profileId] ?? const <EftekadRecord>[];
  }

  bool isLoadingRecordsForProfile(String profileId) {
    return _recordsLoadingProfiles.contains(profileId);
  }

  bool hasMoreRecordsForProfile(String profileId) {
    return _recordsHasMoreByProfile[profileId] ?? true;
  }

  void setRoleContext(String roleName) {
    _selectedRoleName = roleName;
    notifyListeners();
  }

  void clearRoleContext() {
    _selectedRoleName = null;
    notifyListeners();
  }

  Future<void> initialize({String? selectedRoleName}) async {
    if (selectedRoleName != null) {
      setRoleContext(selectedRoleName);
    }

    await loadTroops();

    final currentUser = _effectiveUserProfile;
    if (currentUser == null) {
      _error = 'No authenticated user';
      notifyListeners();
      return;
    }

    if (!currentUser.hasSystemWideAccess) {
      _selectedTroopId = currentUser.managedTroopId;
    }

    if (_selectedTroopId == null && currentUser.hasSystemWideAccess) {
      notifyListeners();
      return;
    }

    await loadMembers();
  }

  Future<void> loadTroops({bool forceRefresh = false}) async {
    _isLoadingTroops = true;
    notifyListeners();

    try {
      final fetchedTroops = await _authProvider.getTroops(
        forceRefresh: forceRefresh,
      );

      final deduped = <String, Map<String, dynamic>>{};
      for (final troop in fetchedTroops) {
        final troopId = troop['id']?.toString();
        if (troopId == null || troopId.isEmpty) {
          continue;
        }
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
      }
    } catch (e) {
      _error = 'Unable to load troops';
    } finally {
      _isLoadingTroops = false;
      notifyListeners();
    }
  }

  Future<void> setSelectedTroop(String troopId) async {
    if (_selectedTroopId == troopId) {
      return;
    }
    _selectedTroopId = troopId;
    notifyListeners();
    await loadMembers();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(EftekadConfig.searchDebounce, () {
      _committedSearchQuery = _searchQuery.trim();
      _applyFilters();
      notifyListeners();
    });
    notifyListeners();
  }

  void setPatrolFilter(String? value) {
    if (_selectedPatrolFilter == value) {
      return;
    }
    _selectedPatrolFilter = value;
    _applyFilters();
    notifyListeners();
  }

  void setNotContactedOnly(bool value) {
    if (_notContactedOnly == value) {
      return;
    }
    _notContactedOnly = value;
    _applyFilters();
    notifyListeners();
  }

  Future<void> loadMembers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = _effectiveUserProfile;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      final scopedTroopId = _service.resolveScopedTroopId(
        currentUser: currentUser,
        selectedTroopId: _selectedTroopId,
      );

      final snapshot = await _service.fetchMembersSnapshot(
        currentUser: currentUser,
        troopId: scopedTroopId,
        includePending: true,
      );

      _patrols = [...snapshot.patrols]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _members = snapshot.members;

      final ids = _members.map((member) => member.id).toList(growable: false);
      _lastContactByProfileId = await _service.fetchLastContactByProfileIds(
        ids,
      );

      _recordsByProfile.clear();
      _recordsOffsetByProfile.clear();
      _recordsHasMoreByProfile.clear();

      _applyFilters();
    } catch (e) {
      _error = 'Unable to load EFTEKAD members. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadMembers();
  }

  Future<void> loadProfileRecords(
    String profileId, {
    bool reset = false,
  }) async {
    if (_recordsLoadingProfiles.contains(profileId)) {
      return;
    }

    if (reset) {
      _recordsByProfile.remove(profileId);
      _recordsOffsetByProfile[profileId] = 0;
      _recordsHasMoreByProfile[profileId] = true;
    }

    if (!(_recordsHasMoreByProfile[profileId] ?? true)) {
      return;
    }

    _recordsLoadingProfiles.add(profileId);
    notifyListeners();

    try {
      final offset = _recordsOffsetByProfile[profileId] ?? 0;
      final fetched = await _service.fetchRecordsForProfile(
        profileId: profileId,
        limit: EftekadConfig.recordsPageSize,
        offset: offset,
      );

      final current = reset
          ? <EftekadRecord>[]
          : [...(_recordsByProfile[profileId] ?? const <EftekadRecord>[])];

      final seenIds = current.map((record) => record.id).toSet();
      for (final record in fetched) {
        if (!seenIds.contains(record.id)) {
          current.add(record);
        }
      }

      current.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _recordsByProfile[profileId] = current;
      _recordsOffsetByProfile[profileId] = offset + fetched.length;
      _recordsHasMoreByProfile[profileId] =
          fetched.length == EftekadConfig.recordsPageSize;
    } catch (_) {
      _error = 'Unable to load records.';
    } finally {
      _recordsLoadingProfiles.remove(profileId);
      notifyListeners();
    }
  }

  Future<bool> addRecord({
    required String profileId,
    required EftekadRecordType type,
    required String reason,
    required String notes,
    String? outcome,
    DateTime? nextFollowUpDate,
  }) async {
    final currentUser = _effectiveUserProfile;
    if (currentUser == null) {
      _error = 'No authenticated user';
      notifyListeners();
      return false;
    }

    final normalizedReason = reason.trim();
    final normalizedNotes = notes.trim();

    if (normalizedReason.isEmpty || normalizedNotes.isEmpty) {
      _error = 'Reason and notes are required.';
      notifyListeners();
      return false;
    }

    final newRecord = EftekadRecord(
      id: _uuid.v4(),
      profileId: profileId,
      createdByProfileId: currentUser.id,
      createdAt: DateTime.now(),
      type: type,
      reason: normalizedReason,
      notes: normalizedNotes,
      outcome: outcome?.trim().isEmpty ?? true ? null : outcome?.trim(),
      nextFollowUpDate: nextFollowUpDate,
    );

    final previousRecords = [
      ...(_recordsByProfile[profileId] ?? const <EftekadRecord>[]),
    ];
    final previousLastContact = _lastContactByProfileId[profileId];

    _recordsByProfile[profileId] = [newRecord, ...previousRecords]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _lastContactByProfileId[profileId] = newRecord.createdAt;
    _applyFilters();
    _isSavingRecord = true;
    _error = null;
    notifyListeners();

    try {
      if (!_authProvider.isAuthenticated) {
        throw Exception('No authenticated session');
      }

      if (_authProvider.currentUserProfile == null) {
        throw Exception('No authenticated profile context');
      }

      if (!_isOnline()) {
        await _offlineQueue.enqueue(
          id: newRecord.id,
          type: 'eftekad',
          payload: <String, dynamic>{
            'operation': 'create_record',
            'enqueuedByProfileId': currentUser.id,
            ...newRecord.toQueuePayload(),
          },
        );
        NavigationService.showMessage('Saved offline, will sync');
        return true;
      }

      await _service.upsertRecord(currentUser: currentUser, record: newRecord);
      NavigationService.showMessage('Record saved');
      return true;
    } catch (e) {
      _recordsByProfile[profileId] = previousRecords;
      if (previousLastContact != null) {
        _lastContactByProfileId[profileId] = previousLastContact;
      } else {
        _lastContactByProfileId.remove(profileId);
      }
      _applyFilters();
      _error = 'Failed to save record. Please try again.';
      notifyListeners();
      return false;
    } finally {
      _isSavingRecord = false;
      notifyListeners();
    }
  }

  bool _isOnline() {
    return ConnectivityService.instance.isOnline;
  }

  bool isNotContactedRecently(String profileId) {
    final lastContact = _lastContactByProfileId[profileId];
    if (lastContact == null) {
      return true;
    }
    final thresholdDate = DateTime.now().subtract(_notContactedThreshold);
    return lastContact.isBefore(thresholdDate);
  }

  void _applyFilters() {
    final normalizedSearch = _committedSearchQuery.toLowerCase();

    _visibleMembers = _members
        .where((member) {
          if (_selectedPatrolFilter != null) {
            if (_selectedPatrolFilter == _unassignedPatrolFilterValue) {
              final isUnassigned =
                  member.patrolId == null || member.patrolId!.isEmpty;
              if (!isUnassigned) {
                return false;
              }
            } else if (member.patrolId != _selectedPatrolFilter) {
              return false;
            }
          }

          if (_notContactedOnly && !isNotContactedRecently(member.id)) {
            return false;
          }

          if (normalizedSearch.isEmpty) {
            return true;
          }

          final fullName = member.fullName.toLowerCase();
          final phone = member.normalizedPhone.toLowerCase();
          final compactSearch = normalizedSearch.replaceAll(' ', '');
          return fullName.contains(normalizedSearch) ||
              phone.contains(compactSearch);
        })
        .toList(growable: false);
  }

  void _onAuthChanged() {
    _troops = [];
    _patrols = [];
    _members = [];
    _visibleMembers = [];
    _lastContactByProfileId = {};
    _recordsByProfile.clear();
    _recordsOffsetByProfile.clear();
    _recordsHasMoreByProfile.clear();
    _selectedTroopId = null;
    _selectedPatrolFilter = null;
    _error = null;
    notifyListeners();
  }

  void _registerOfflineHandlers() {
    _offlineQueue.registerValidator('eftekad', (payload) {
      final operation = payload['operation'];
      if (operation is! String || operation.isEmpty) {
        return false;
      }

      switch (operation) {
        case 'create_record':
          return payload['id'] is String &&
              payload['enqueuedByProfileId'] is String &&
              payload['profileId'] is String &&
              payload['createdByProfileId'] is String &&
              payload['createdAt'] is String &&
              payload['type'] is String &&
              payload['reason'] is String &&
              payload['notes'] is String;
        default:
          return false;
      }
    });

    _offlineQueue.registerHandler('eftekad', (payload) async {
      final operation = payload['operation'] as String?;
      if (operation == null) {
        return;
      }

      final currentUser = _effectiveUserProfile;
      if (currentUser == null) {
        throw Exception('No authenticated user for EFTEKAD sync.');
      }

      switch (operation) {
        case 'create_record':
          final enqueuedByProfileId = payload['enqueuedByProfileId'] as String;
          if (currentUser.id != enqueuedByProfileId) {
            throw Exception('EFTEKAD offline action owner mismatch.');
          }

          final record = EftekadRecord.fromQueuePayload(payload);
          if (record.createdByProfileId != currentUser.id) {
            throw Exception('EFTEKAD record creator mismatch during sync.');
          }
          await _service.upsertRecord(currentUser: currentUser, record: record);
          break;
      }
    });
  }
}
