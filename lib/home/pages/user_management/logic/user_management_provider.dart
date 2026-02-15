import 'package:flutter/foundation.dart';
import '../../../../auth/data/role_repository.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/models/role.dart';
import '../../../../auth/models/user_profile.dart';
import '../data/models/managed_user_profile.dart';
import '../data/user_management_service.dart';

/// Provider for user management operations
class UserManagementProvider with ChangeNotifier {
  final UserManagementService _service;
  final AuthProvider _authProvider;
  final RoleRepository _roleRepository = RoleRepository();

  String? _selectedRoleName;

  UserManagementProvider({
    UserManagementService? service,
    required AuthProvider authProvider,
  })  : _service = service ?? UserManagementService.instance(),
        _authProvider = authProvider {
    _authProvider.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    notifyListeners();
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

  List<ManagedUserProfile> _users = [];
  List<Role> _roles = [];
  bool _isLoadingUsers = false;
  bool _isLoadingRoles = false;
  bool _isProcessing = false;
  String? _error;

  List<ManagedUserProfile> get users => _users;
  List<Role> get roles => _roles;
  bool get isLoadingUsers => _isLoadingUsers;
  bool get isLoadingRoles => _isLoadingRoles;
  bool get isProcessing => _isProcessing;
  bool get hasError => _error != null;
  String? get error => _error;

  bool get isRolesReady =>
      !_isLoadingRoles && !_authProvider.profileLoading && _effectiveUserProfile != null;

  List<Role> get assignableRoles {
    final effectiveUser = _effectiveUserProfile;
    if (effectiveUser == null) return [];

    final effectiveRank = effectiveUser.roleRank;
    var filteredRoles = _roles.where((role) => role.rank < effectiveRank).toList();

    if (effectiveRank >= 60 && effectiveRank < 90) {
      filteredRoles = filteredRoles.where((role) => role.rank > 0 && role.rank <= 40).toList();
    }

    return filteredRoles;
  }

  bool canEditRolesForProfile(ManagedUserProfile profile) {
    final effectiveUser = _effectiveUserProfile;
    if (effectiveUser == null) return false;

    if (profile.roles.isEmpty) {
      return true;
    }

    final highestTargetRank = profile.roles
        .map((role) => role.rank)
        .reduce((a, b) => a > b ? a : b);

    if (effectiveUser.roleRank <= highestTargetRank) {
      return false;
    }

    return true;
  }

  Future<void> loadUsers() async {
    _isLoadingUsers = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = _effectiveUserProfile;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      _users = await _service.fetchUsers(currentUser: currentUser);
    } catch (e) {
      _error = 'Unable to load users. Please check your connection and try again.';
      debugPrint('❌ Error loading users: $e');
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  Future<void> loadRoles() async {
    _isLoadingRoles = true;
    _error = null;
    notifyListeners();

    try {
      _roles = await _service.fetchRoles();
    } catch (e) {
      _error = 'Unable to load roles. Please try again.';
      debugPrint('❌ Error loading roles: $e');
    } finally {
      _isLoadingRoles = false;
      notifyListeners();
    }
  }

  Future<bool> updateUser({
    required ManagedUserProfile profile,
    required Map<String, dynamic> updates,
    List<String>? roleIds,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = _effectiveUserProfile;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      await _service.updateProfile(
        profileId: profile.id,
        updates: updates,
        currentUser: currentUser,
      );

      List<Role>? updatedRoles;
      final canEditRoles = canEditRolesForProfile(profile);
      final currentRoleIds = profile.roles.map((role) => role.id).toSet();
        final requestedRoleIds = roleIds?.toSet();
      final shouldUpdateRoles =
          requestedRoleIds != null && !setEquals(currentRoleIds, requestedRoleIds);

      if (shouldUpdateRoles) {
        if (!canEditRoles) {
          throw Exception('You do not have permission to change this user\'s roles');
        }

        final assignableRoleIds = assignableRoles.map((role) => role.id).toSet();
        if (!requestedRoleIds.every(assignableRoleIds.contains)) {
          throw Exception('One or more selected roles are not assignable');
        }

        final troopContextId = profile.signupTroopId ?? currentUser.managedTroopId;

        await _service.updateProfileRoles(
          profileId: profile.id,
          roleIds: requestedRoleIds.toList(),
          assignedBy: currentUser.id,
          currentUser: currentUser,
          troopContextId: troopContextId,
        );

        if (_roles.isNotEmpty) {
          updatedRoles = _roles
              .where((role) => requestedRoleIds.contains(role.id))
              .toList();
        }
      }

      final updatedProfile = profile.copyWith(
        firstName: updates['first_name'] as String?,
        middleName: updates['middle_name'] as String?,
        lastName: updates['last_name'] as String?,
        nameAr: updates['name_ar'] as String?,
        email: updates['email'] as String?,
        address: updates['address'] as String?,
        birthdate: updates['birthdate'] != null
            ? DateTime.parse(updates['birthdate'] as String)
            : profile.birthdate,
        gender: updates['gender'] as String?,
        generation: updates['generation'] as String?,
        medicalNotes: updates['medical_notes'] as String?,
        allergies: updates['allergies'] as String?,
        roles: updatedRoles,
        updatedAt: DateTime.now(),
      );

      final index = _users.indexWhere((user) => user.id == profile.id);
      if (index != -1) {
        _users[index] = updatedProfile;
      }

      return true;
    } catch (e) {
      _error = 'Unable to update user. Please try again.';
      debugPrint('❌ Error updating user: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<List<Role>> getProfileRoles(String profileId) async {
    try {
      return await _roleRepository.getProfileRoles(profileId);
    } catch (e) {
      debugPrint('❌ Error loading profile roles: $e');
      return [];
    }
  }

  Future<void> refresh() async {
    await loadUsers();
  }
}
