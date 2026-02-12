import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/admin_service.dart';
import '../data/models/pending_profile.dart';
import '../data/models/profile_approval.dart';
import '../../../../auth/models/role.dart';
import '../../../../auth/models/user_profile.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../../../../auth/data/role_repository.dart';

/// Admin Provider
/// 
/// Manages state for admin operations, specifically user acceptance workflow
/// Handles loading states, errors, and profile approval actions
/// 
/// Automatically applies troop-scoping based on current user's role or selected role context
class AdminProvider with ChangeNotifier {
  final AdminService _service;
  final AuthProvider _authProvider;
  final RoleRepository _roleRepository = RoleRepository();
  
  // Role context override for multi-role users
  String? _selectedRoleName;

  AdminProvider({
    AdminService? service,
    required AuthProvider authProvider,
  })  : _service = service ?? AdminService.instance(),
        _authProvider = authProvider {
    // Listen to auth provider changes (e.g., when user profile loads)
    _authProvider.addListener(_onAuthChanged);
  }
  
  // ==================== CLEANUP ====================
  
  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
  
  /// Handle auth provider changes (e.g., user profile loaded)
  void _onAuthChanged() {
    // Notify listeners when auth state changes
    // This ensures UI rebuilds when user profile becomes available
    notifyListeners();
  }
  
  // ==================== ROLE CONTEXT ====================
  
  /// Set the selected role context for filtering (used when user has multiple roles)
  void setRoleContext(String roleName) {
    debugPrint('🎯 Setting role context to: $roleName');
    _selectedRoleName = roleName;
    notifyListeners();
  }
  
  /// Clear role context (revert to highest rank)
  void clearRoleContext() {
    _selectedRoleName = null;
    notifyListeners();
  }
  
  /// Get effective user profile for current role context
  /// 
  /// If a role is selected, creates a modified profile with that role's rank and troop context
  /// Otherwise returns the user's default profile (highest rank)
  UserProfile? get _effectiveUserProfile {
    final baseProfile = _authProvider.currentUserProfile;
    if (baseProfile == null) return null;
    
    // No role override - use default profile
    if (_selectedRoleName == null) return baseProfile;
    
    // Get selected role's rank
    final selectedRole = _authProvider.getRoleByName(_selectedRoleName!);
    if (selectedRole == null) {
      debugPrint('⚠️ Selected role "${_selectedRoleName}" not found in user roles');
      return baseProfile;
    }
    
    // Create modified profile with selected role's rank
    // Note: managedTroopId stays the same as it's user-specific, not role-specific
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
      roleRank: selectedRole.rank,  // Use selected role's rank
      managedTroopId: baseProfile.managedTroopId,
      createdAt: baseProfile.createdAt,
      updatedAt: baseProfile.updatedAt,
    );
  }

  // ==================== STATE ====================

  // Pending profiles list
  List<PendingProfile> _pendingProfiles = [];

  // Available roles
  List<Role> _roles = [];

  // Selected profile for review
  PendingProfile? _selectedProfile;
  List<ProfileApproval> _selectedProfileApprovals = [];
  List<Role> _selectedProfileRoles = [];
  String? _selectedProfileTroopContext;

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
  
  /// Get roles that current user can assign
  /// 
  /// Universal rule: Users cannot assign roles with rank >= their own rank
  /// Additional restriction for troop-scoped users (rank 60-70): Only ranks 1-40
  /// 
  /// Examples:
  /// - System Admin (100): Can assign ranks < 100 (everything except System Admin)
  /// - Moderator (90): Can assign ranks < 90 (cannot assign Moderator or System Admin)
  /// - Troop Head (70): Can assign ranks < 70 AND 1-40 (effectively 1-40)
  /// - Troop Leader (60): Can assign ranks < 60 AND 1-40 (effectively 1-40)
  List<Role> get assignableRoles {
    final effectiveUser = _effectiveUserProfile;
    if (effectiveUser == null) return [];
    
    final effectiveRank = effectiveUser.roleRank;
    
    // Universal rule: Cannot assign roles with rank >= own rank
    var filteredRoles = _roles.where((role) => role.rank < effectiveRank).toList();
    
    // Additional restriction for troop-scoped users (rank 60-70)
    // Can only assign roles with rank 1-40 (Scout, Patrol Leader, L1, L2, L3)
    if (effectiveRank >= 60 && effectiveRank < 90) {
      filteredRoles = filteredRoles.where((role) => role.rank > 0 && role.rank <= 40).toList();
    }
    
    return filteredRoles;
  }
  
  PendingProfile? get selectedProfile => _selectedProfile;
  List<ProfileApproval> get selectedProfileApprovals => _selectedProfileApprovals;
  List<Role> get selectedProfileRoles => _selectedProfileRoles;
  String? get selectedProfileTroopContext => _selectedProfileTroopContext;

  bool get isLoadingPending => _isLoadingPending;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isLoadingRoles => _isLoadingRoles;
  bool get isProcessing => _isProcessing;
  
  /// Returns true when roles are ready to display
  /// All conditions must be met:
  /// 1. Roles have finished loading
  /// 2. User profile is available (not null)
  /// 3. Auth provider has finished loading profile
  bool get isRolesReady => 
    !_isLoadingRoles && 
    !_authProvider.profileLoading &&
    _effectiveUserProfile != null;
  bool get hasError => _error != null;
  String? get error => _error;

  int get pendingCount => _pendingProfiles.length;
  
  /// Get current user's troop scope for UI display (computed from profile_roles)
  String? get userTroopScope => _authProvider.currentUserProfile?.getTroopContextForScope();
  
  /// Check if current user has system-wide access
  bool get isSystemWideAccess => _authProvider.currentUserProfile?.hasSystemWideAccess ?? false;

  /// Check if effective role context has system-wide access
  bool get isEffectiveSystemWideAccess => _effectiveUserProfile?.hasSystemWideAccess ?? false;

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
  /// Automatically filtered by user's role and troop context
  Future<void> loadPendingProfiles() async {
    _isLoadingPending = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = _effectiveUserProfile;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }
      
      debugPrint('🔍 Loading pending profiles with role context: $_selectedRoleName (rank ${currentUser.roleRank})');
      
      // Pass effective user profile to service for automatic scoping
      _pendingProfiles = await _service.fetchPendingProfiles(
        currentUser: currentUser,
      );
      debugPrint('✅ Loaded ${_pendingProfiles.length} pending profiles (scoped)');
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
      _selectedProfileTroopContext = await _roleRepository.getTroopContextForProfile(profileId);

      debugPrint('✅ Loaded profile: ${profile.fullName}');
      debugPrint('📋 Approval history: ${_selectedProfileApprovals.length} records');
      debugPrint('🎭 Current roles: ${_selectedProfileRoles.length} roles assigned');
      if (_selectedProfileTroopContext != null) {
        debugPrint('🏕️ Troop context loaded: $_selectedProfileTroopContext');
      }
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
    _selectedProfileTroopContext = null;
    _error = null;
    notifyListeners();
  }

  /// Accept a user profile
  /// 
  /// Creates approval record, updates profile status, and assigns multiple roles
  /// [profileId] - Profile to accept
  /// [approvedBy] - Admin profile ID performing action
  /// [roleIds] - List of role IDs to assign to the user (must not be empty)
  /// [generation] - Required generation to assign
  /// [comments] - Optional approval comments
  Future<bool> acceptProfile({
    required String profileId,
    required String approvedBy,
    required List<String> roleIds,
    required String generation,
    String? comments,
    String? troopContextId,
  }) async {
    // Validation
    if (roleIds.isEmpty) {
      _error = 'At least one role must be selected';
      notifyListeners();
      return false;
    }
    
    if (generation.trim().isEmpty) {
      _error = 'Generation is required';
      notifyListeners();
      return false;
    }
    
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = _effectiveUserProfile;
      
      await _service.acceptProfile(
        profileId: profileId,
        approvedBy: approvedBy,
        roleIds: roleIds,
        generation: generation,
        comments: comments,
        troopContextId: troopContextId,
        currentUser: currentUser, // Pass for security validation
      );

      // Remove from pending list
      _pendingProfiles.removeWhere((p) => p.id == profileId);

      // Clear selection if it was the accepted profile
      if (_selectedProfile?.id == profileId) {
        _selectedProfile = null;
        _selectedProfileApprovals = [];
        _selectedProfileRoles = [];
      }

      debugPrint('✅ Profile accepted: $profileId with ${roleIds.length} roles');
      return true;
    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message}';
      debugPrint('❌ PostgrestException accepting profile: ${e.message}');
      return false;
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
      final currentUser = _effectiveUserProfile;
      
      await _service.addProfileComment(
        profileId: profileId,
        approvedBy: approvedBy,
        comments: comments,
        currentUser: currentUser, // Pass for security validation
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
    // Validation
    if (comments.trim().isEmpty) {
      _error = 'Comments are required when rejecting a profile';
      notifyListeners();
      return false;
    }
    
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final currentUser = _effectiveUserProfile;
      
      await _service.rejectProfile(
        profileId: profileId,
        approvedBy: approvedBy,
        comments: comments,
        currentUser: currentUser, // Pass for security validation
      );

      // Remove from pending list
      _pendingProfiles.removeWhere((p) => p.id == profileId);

      // Clear selection if it was the rejected profile
      if (_selectedProfile?.id == profileId) {
        _selectedProfile = null;
        _selectedProfileApprovals = [];
        _selectedProfileRoles = [];
      }

      debugPrint('✅ Profile rejected: $profileId');
      return true;
    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message}';
      debugPrint('❌ PostgrestException rejecting profile: ${e.message}');
      return false;
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
