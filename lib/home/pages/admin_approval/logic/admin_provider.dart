import 'package:flutter/foundation.dart';
import '../data/admin_service.dart';
import '../data/models/pending_profile.dart';
import '../data/models/profile_approval.dart';
import '../../../../auth/models/role.dart';
import '../../../../auth/data/role_repository.dart';

/// Admin Provider
/// 
/// Manages state for admin operations, specifically user acceptance workflow
/// Handles loading states, errors, and profile approval actions
class AdminProvider with ChangeNotifier {
  final AdminService _service;
  final RoleRepository _roleRepository = RoleRepository();

  AdminProvider({AdminService? service})
      : _service = service ?? AdminService.instance();

  // ==================== STATE ====================

  // Pending profiles list
  List<PendingProfile> _pendingProfiles = [];

  // Available roles
  List<Role> _roles = [];

  // Selected profile for review
  PendingProfile? _selectedProfile;
  List<ProfileApproval> _selectedProfileApprovals = [];
  List<Role> _selectedProfileRoles = [];

  // Loading states
  bool _isLoadingPending = false;
  bool _isLoadingProfile = false;
  bool _isLoadingRoles = false;
  bool _isProcessing = false;

  // Error states
  String? _error;

  // ==================== GETTERS ====================

  List<PendingProfile> get pendingProfiles => _pendingProfiles;
  List<Role> get roles => _roles;
  PendingProfile? get selectedProfile => _selectedProfile;
  List<ProfileApproval> get selectedProfileApprovals => _selectedProfileApprovals;
  List<Role> get selectedProfileRoles => _selectedProfileRoles;

  bool get isLoadingPending => _isLoadingPending;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isLoadingRoles => _isLoadingRoles;
  bool get isProcessing => _isProcessing;
  bool get hasError => _error != null;
  String? get error => _error;

  int get pendingCount => _pendingProfiles.length;

  // ==================== PUBLIC METHODS ====================

  /// Load all available roles
  Future<void> loadRoles() async {
    _isLoadingRoles = true;
    _error = null;
    notifyListeners();

    try {
      _roles = await _service.fetchRoles();
      debugPrint('✅ Loaded ${_roles.length} roles');
    } catch (e) {
      _error = 'Unable to load roles. Please check your connection and try again.';
      debugPrint('❌ Error loading roles: $e');
    } finally {
      _isLoadingRoles = false;
      notifyListeners();
    }
  }

  /// Load all pending profiles (approved = false)
  Future<void> loadPendingProfiles() async {
    _isLoadingPending = true;
    _error = null;
    notifyListeners();

    try {
      _pendingProfiles = await _service.fetchPendingProfiles();
      debugPrint('✅ Loaded ${_pendingProfiles.length} pending profiles');
    } catch (e) {
      _error = 'Unable to load pending profiles. Please check your connection and try again.';
      debugPrint('❌ Error loading pending profiles: $e');
    } finally {
      _isLoadingPending = false;
      notifyListeners();
    }
  }

  /// Select a profile for detailed review
  /// Loads profile details, approval history, and current roles
  Future<void> selectProfile(String profileId) async {
    _isLoadingProfile = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _service.getProfileById(profileId);
      if (profile == null) {
        throw Exception('Profile not found');
      }

      _selectedProfile = profile;
      _selectedProfileApprovals = await _service.fetchProfileApprovals(profileId);
      _selectedProfileRoles = await _roleRepository.getProfileRoles(profileId);

      debugPrint('✅ Loaded profile: ${profile.fullName}');
      debugPrint('📋 Approval history: ${_selectedProfileApprovals.length} records');
      debugPrint('🎭 Current roles: ${_selectedProfileRoles.length} roles assigned');
    } catch (e) {
      _error = 'Unable to load profile details. Please try again.';
      debugPrint('❌ Error loading profile: $e');
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  /// Clear selected profile
  void clearSelection() {
    _selectedProfile = null;
    _selectedProfileApprovals = [];
    _selectedProfileRoles = [];
    _error = null;
    notifyListeners();
  }

  /// Accept a user profile
  /// 
  /// Creates approval record, updates profile status, and assigns multiple roles
  /// [profileId] - Profile to accept
  /// [approvedBy] - Admin profile ID performing action
  /// [roleIds] - List of role IDs to assign to the user
  /// [generation] - Required generation to assign
  /// [comments] - Optional approval comments
  Future<bool> acceptProfile({
    required String profileId,
    required String approvedBy,
    required List<String> roleIds,
    required String generation,
    String? comments,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      await _service.acceptProfile(
        profileId: profileId,
        approvedBy: approvedBy,
        roleIds: roleIds,
        generation: generation,
        comments: comments,
      );

      // Remove from pending list
      _pendingProfiles.removeWhere((p) => p.id == profileId);

      // Clear selection if it was the accepted profile
      if (_selectedProfile?.id == profileId) {
        _selectedProfile = null;
        _selectedProfileApprovals = [];
      }

      debugPrint('✅ Profile accepted: $profileId with ${roleIds.length} roles');
      return true;
    } catch (e) {
      _error = 'Unable to accept profile. Please try again.';
      debugPrint('❌ Error accepting profile: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Add comment to a profile without rejecting
  /// 
  /// Profile stays in pending state for future review
  /// [profileId] - Profile to add comment to
  /// [approvedBy] - Admin profile ID adding comment
  /// [comments] - REQUIRED comment text
  Future<bool> addComment({
    required String profileId,
    required String approvedBy,
    required String comments,
  }) async {
    if (comments.trim().isEmpty) {
      _error = 'Comments cannot be empty';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      await _service.addProfileComment(
        profileId: profileId,
        approvedBy: approvedBy,
        comments: comments,
      );

      // Reload profile approvals if viewing this profile
      if (_selectedProfile?.id == profileId) {
        _selectedProfileApprovals = await _service.fetchProfileApprovals(profileId);
      }

      debugPrint('✅ Comment added to profile: $profileId');
      return true;
    } catch (e) {
      _error = 'Unable to add comment: ${e.toString()}';
      debugPrint('❌ Error adding comment: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Reject a user profile
  /// 
  /// Creates rejection record (comments required)
  /// [profileId] - Profile to reject
  /// [approvedBy] - Admin profile ID performing action
  /// [comments] - REQUIRED rejection reason
  Future<bool> rejectProfile({
    required String profileId,
    required String approvedBy,
    required String comments,
  }) async {
    if (comments.trim().isEmpty) {
      _error = 'Comments are required when rejecting a profile';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      await _service.rejectProfile(
        profileId: profileId,
        approvedBy: approvedBy,
        comments: comments,
      );

      // Reload profile approvals if viewing this profile
      if (_selectedProfile?.id == profileId) {
        _selectedProfileApprovals = await _service.fetchProfileApprovals(profileId);
      }

      debugPrint('✅ Profile rejected: $profileId');
      return true;
    } catch (e) {
      _error = 'Unable to reject profile. Please try again.';
      debugPrint('❌ Error rejecting profile: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Update profile generation
  /// 
  /// Updates generation field only
  /// [profileId] - Profile to update
  /// [generation] - Generation value
  Future<bool> updateGeneration({
    required String profileId,
    required String generation,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      await _service.updateProfileGeneration(
        profileId: profileId,
        generation: generation,
      );

      // Update local state if viewing this profile
      if (_selectedProfile?.id == profileId) {
        _selectedProfile = _selectedProfile!.copyWith(generation: generation);
      }

      // Update in pending list
      final index = _pendingProfiles.indexWhere((p) => p.id == profileId);
      if (index != -1) {
        _pendingProfiles[index] = _pendingProfiles[index].copyWith(generation: generation);
      }

      debugPrint('✅ Generation updated: $generation');
      return true;
    } catch (e) {
      _error = 'Failed to update generation: $e';
      debugPrint('❌ Error updating generation: $e');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh pending profiles list
  Future<void> refresh() async {
    await loadPendingProfiles();
  }
}
