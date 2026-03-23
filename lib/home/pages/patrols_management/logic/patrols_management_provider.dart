import 'package:flutter/foundation.dart';
import '../../../../core/utils/review_mode.dart';

import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/models/user_profile.dart';
import '../data/models/patrol.dart';
import '../data/models/patrol_with_members.dart';
import '../data/models/troop_member.dart';
import '../data/patrols_management_service.dart';

class PatrolsManagementProvider with ChangeNotifier {
  final PatrolsManagementService _service;
  final AuthProvider _authProvider;

  String? _selectedRoleName;
  String? _selectedTroopId;

  List<Map<String, dynamic>> _troops = [];
  List<Patrol> _patrols = [];
  List<TroopMember> _troopMembers = [];

  bool _isLoading = false;
  bool _isLoadingTroops = false;
  bool _isProcessing = false;
  String? _error;

  PatrolsManagementProvider({
    PatrolsManagementService? service,
    required AuthProvider authProvider,
  }) : _service = service ?? PatrolsManagementService.instance(),
       _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    _troops = [];
    _patrols = [];
    _troopMembers = [];
    _selectedTroopId = null;
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
      _patrols = [];
      _troopMembers = [];
    }
  }

  void setRoleContext(String roleName) {
    _selectedRoleName = roleName;
    notifyListeners();
  }

  void clearRoleContext() {
    _selectedRoleName = null;
    notifyListeners();
  }

  UserProfile? get _effectiveUserProfile {
    final baseProfile = _authProvider.currentUserProfile;
    if (baseProfile == null) return null;

    if (_selectedRoleName == null) return baseProfile;

    final selectedRole = _authProvider.getRoleByName(_selectedRoleName!);
    if (selectedRole == null) return baseProfile;

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

  List<Map<String, dynamic>> get troops => _troops;
  List<Patrol> get patrols => _patrols;
  List<TroopMember> get troopMembers => _troopMembers;
  String? get selectedTroopId => _selectedTroopId;
  bool get isLoading => _isLoading;
  bool get isLoadingTroops => _isLoadingTroops;
  bool get isProcessing => _isProcessing;
  bool get hasError => _error != null;
  String? get error => _error;
  bool get _isReviewDemoAccount => isReviewDemoEmail(_authProvider.userEmail);

  bool get isSystemScoped {
    final user = _effectiveUserProfile;
    if (user == null) return false;
    return user.roleRank >= 90;
  }

  List<TroopMember> get unassignedMembers {
    final items = _troopMembers
        .where((member) => member.patrolId == null)
        .toList();
    items.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return items;
  }

  List<PatrolWithMembers> get patrolsWithMembers {
    final membersById = {for (final member in _troopMembers) member.id: member};

    final result = _patrols.map((patrol) {
      final assigned =
          _troopMembers.where((member) => member.patrolId == patrol.id).toList()
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );

      final leader = patrol.patrolLeaderProfileId != null
          ? membersById[patrol.patrolLeaderProfileId!]
          : null;

      final assistant1 = patrol.assistant1ProfileId != null
          ? membersById[patrol.assistant1ProfileId!]
          : null;

      final assistant2 = patrol.assistant2ProfileId != null
          ? membersById[patrol.assistant2ProfileId!]
          : null;

      return PatrolWithMembers(
        patrol: patrol,
        patrolLeader: leader,
        assistant1: assistant1,
        assistant2: assistant2,
        members: assigned,
      );
    }).toList();

    result.sort(
      (a, b) =>
          a.patrol.name.toLowerCase().compareTo(b.patrol.name.toLowerCase()),
    );
    return result;
  }

  String patrolNameById(String patrolId) {
    for (final patrol in _patrols) {
      if (patrol.id == patrolId) {
        return patrol.name;
      }
    }
    return 'Unknown Patrol';
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

    if (!isSystemScoped) {
      final managedTroop = currentUser.managedTroopId;
      if (managedTroop != null && managedTroop.isNotEmpty) {
        _selectedTroopId = managedTroop;
        await loadPatrolsAndMembers();
      }
      return;
    }

    if (_selectedTroopId != null) {
      await loadPatrolsAndMembers();
    }
  }

  Future<void> loadTroops({bool forceRefresh = false}) async {
    _isLoadingTroops = true;
    notifyListeners();

    try {
      final fetchedTroops = await _authProvider.getTroops(
        forceRefresh: forceRefresh,
      );
      _setTroops(fetchedTroops);
    } catch (e) {
      _error = 'Unable to load troops';
      debugPrint('❌ loadTroops failed: $e');
    } finally {
      _isLoadingTroops = false;
      notifyListeners();
    }
  }

  Future<void> setSelectedTroop(String troopId) async {
    if (!_troops.any((troop) => troop['id'] == troopId)) {
      debugPrint('⚠️ setSelectedTroop ignored unknown troopId=$troopId');
      return;
    }
    if (_selectedTroopId == troopId) return;
    _selectedTroopId = troopId;
    notifyListeners();
    await loadPatrolsAndMembers();
  }

  Future<void> loadPatrolsAndMembers({bool forceRefresh = false}) async {
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

      final patrolsData = await _service.fetchPatrols(
        currentUser: currentUser,
        troopId: scopedTroopId,
      );
      final membersData = await _service.fetchTroopMembers(
        currentUser: currentUser,
        troopId: scopedTroopId,
      );

      _patrols = patrolsData;
      _troopMembers = membersData;
    } catch (e) {
      _error = 'Unable to load patrols. Please try again.';
      debugPrint('❌ loadPatrolsAndMembers failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPatrol({
    required String name,
    String? description,
    String? patrolLeaderProfileId,
    String? assistant1ProfileId,
    String? assistant2ProfileId,
  }) async {
    if (_isReviewDemoAccount) {
      _error = null;
      notifyListeners();
      return true;
    }

    return _processMutation(() async {
      final context = _mutationContext();

      await _service.createPatrol(
        currentUser: context.user,
        troopId: context.troopId,
        name: name,
        description: description,
        patrolLeaderProfileId: patrolLeaderProfileId,
        assistant1ProfileId: assistant1ProfileId,
        assistant2ProfileId: assistant2ProfileId,
      );

      await loadPatrolsAndMembers(forceRefresh: true);
      return true;
    });
  }

  Future<bool> updatePatrol({
    required String patrolId,
    required String name,
    String? description,
    String? patrolLeaderProfileId,
    String? assistant1ProfileId,
    String? assistant2ProfileId,
  }) async {
    if (_isReviewDemoAccount) {
      _error = null;
      notifyListeners();
      return true;
    }

    return _processMutation(() async {
      final context = _mutationContext();

      await _service.updatePatrol(
        currentUser: context.user,
        troopId: context.troopId,
        patrolId: patrolId,
        name: name,
        description: description,
        patrolLeaderProfileId: patrolLeaderProfileId,
        assistant1ProfileId: assistant1ProfileId,
        assistant2ProfileId: assistant2ProfileId,
      );

      await loadPatrolsAndMembers(forceRefresh: true);
      return true;
    });
  }

  Future<bool> deletePatrol(String patrolId) async {
    if (_isReviewDemoAccount) {
      _error = null;
      notifyListeners();
      return true;
    }

    return _processMutation(() async {
      final context = _mutationContext();

      await _service.deletePatrol(
        currentUser: context.user,
        troopId: context.troopId,
        patrolId: patrolId,
      );

      await loadPatrolsAndMembers(forceRefresh: true);
      return true;
    });
  }

  Future<bool> assignMemberToPatrol({
    required String memberProfileId,
    required String patrolId,
  }) async {
    if (_isReviewDemoAccount) {
      _error = null;
      notifyListeners();
      return true;
    }

    return _processMutation(() async {
      final context = _mutationContext();

      // Local update for immediate feedback
      _troopMembers = _troopMembers.map((m) {
        if (m.id == memberProfileId) {
          return m.copyWith(patrolId: patrolId);
        }
        return m;
      }).toList();
      notifyListeners();

      await _service.assignMemberToPatrol(
        currentUser: context.user,
        troopId: context.troopId,
        memberProfileId: memberProfileId,
        patrolId: patrolId,
      );

      await loadPatrolsAndMembers(forceRefresh: true);
      return true;
    });
  }

  Future<bool> updatePatrolMembers({
    required String patrolId,
    required List<String> memberIds,
  }) async {
    if (_isReviewDemoAccount) {
      _error = null;
      notifyListeners();
      return true;
    }

    return _processMutation(() async {
      final context = _mutationContext();

      // Local update for immediate feedback
      _troopMembers = _troopMembers.map((m) {
        if (m.patrolId == patrolId) {
          if (!memberIds.contains(m.id)) {
            return m.copyWith(clearPatrolId: true);
          }
        } else if (memberIds.contains(m.id)) {
          return m.copyWith(patrolId: patrolId);
        }
        return m;
      }).toList();
      notifyListeners();

      await _service.updatePatrolMembers(
        currentUser: context.user,
        troopId: context.troopId,
        patrolId: patrolId,
        memberIds: memberIds,
      );

      await loadPatrolsAndMembers(forceRefresh: true);
      return true;
    });
  }

  Future<bool> _processMutation(Future<bool> Function() action) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      return await action();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('❌ Patrols mutation failed: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  _MutationContext _mutationContext() {
    final currentUser = _effectiveUserProfile;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final troopId = _service.resolveScopedTroopId(
      currentUser: currentUser,
      selectedTroopId: _selectedTroopId,
    );

    return _MutationContext(user: currentUser, troopId: troopId);
  }
}

class _MutationContext {
  final UserProfile user;
  final String troopId;

  const _MutationContext({required this.user, required this.troopId});
}
