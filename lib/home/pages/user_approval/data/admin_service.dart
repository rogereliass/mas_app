import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/pending_profile.dart';
import 'models/profile_approval.dart';
import '../../../../auth/models/role.dart';
import '../../../../auth/models/user_profile.dart';
import '../../../../auth/data/role_repository.dart';
import '../../../../core/data/scoped_service_mixin.dart';

/// Admin Service for User Acceptance Operations
/// 
/// Handles all Supabase operations related to profile approvals
/// including fetching pending profiles, approving/rejecting, and updating generations
/// 
/// Implements automatic troop-scoping via ScopedServiceMixin:
/// - System admins (rank 90+) see ALL profiles
/// - Troop leaders/heads (rank 60, 70) see ONLY their troop's profiles
class AdminService with ScopedServiceMixin {
  static const String _profilesTable = 'profiles';
  static const String _profilesApprovalsTable = 'profiles_approvals';
  // Note: profile_roles table operations now handled by accept_profile_transaction RPC

  final SupabaseClient _supabase;
  final RoleRepository _roleRepository = RoleRepository();

  AdminService(this._supabase);

  /// Factory constructor using singleton Supabase instance
  factory AdminService.instance() {
    return AdminService(Supabase.instance.client);
  }

  // ==================== FETCH OPERATIONS ====================

  /// Fetch all profiles pending approval (approved = false)
  /// 
  /// Automatically scoped based on user's role:
  /// - System admins (100) and moderators (90) see ALL pending profiles
  /// - Troop heads (70) and troop leaders (60) see ONLY their troop's pending profiles
  /// 
  /// Returns profiles sorted by creation date (oldest first)
  Future<List<PendingProfile>> fetchPendingProfiles({
    required UserProfile currentUser,
    int? limit,
    int? offset,
  }) async {
    try {
      debugPrint('🔍 Fetching pending profiles for user (rank ${currentUser.roleRank})');
      
      // Build query with basic filters first
      var query = _supabase
          .from(_profilesTable)
          .select('''
            *,
            troops:signup_troop(name)
          ''')
          .eq('approved', false);
      
      // Apply automatic scope filtering BEFORE order/transformations
      query = applyScopeFilter(query, currentUser, 'signup_troop');
      
      // Apply ordering
      var sortedQuery = query.order('created_at', ascending: true);

      // Apply pagination if provided
      if (limit != null) {
        final start = offset ?? 0;
        final end = start + limit - 1;
        sortedQuery = sortedQuery.range(start, end);
      }
      
      final response = await sortedQuery;

      final profiles = (response as List)
          .map((json) => PendingProfile.fromJson(json))
          .toList();
      
      debugPrint('✅ Fetched ${profiles.length} pending profiles');
      return profiles;
    } catch (e) {
      _logError('fetchPendingProfiles', e);
      rethrow;
    }
  }

  /// Fetch approval history for a specific profile
  /// Returns approvals sorted by creation date (newest first)
  Future<List<ProfileApproval>> fetchProfileApprovals(String profileId) async {
    try {
      final response = await _supabase
          .from(_profilesApprovalsTable)
          .select('''
            *,
            approver:approved_by(first_name, last_name)
          ''')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ProfileApproval.fromJson(json))
          .toList();
    } catch (e) {
      _logError('fetchProfileApprovals', e);
      rethrow;
    }
  }

  /// Get single profile by ID with troop info
  Future<PendingProfile?> getProfileById(String profileId) async {
    try {
      final response = await _supabase
          .from(_profilesTable)
          .select('''
            *,
            troops:signup_troop(name)
          ''')
          .eq('id', profileId)
          .maybeSingle();

      if (response == null) return null;
      return PendingProfile.fromJson(response);
    } catch (e) {
      _logError('getProfileById', e);
      rethrow;
    }
  }

  /// Fetch all available roles using existing RoleRepository
  /// Returns roles sorted by rank ascending
  Future<List<Role>> fetchRoles() async {
    try {
      return await _roleRepository.getAllRoles();
    } catch (e) {
      _logError('fetchRoles', e);
      rethrow;
    }
  }

  // ==================== APPROVAL OPERATIONS ====================

  /// Verify that the current user can act on this profile
  /// 
  /// SECURITY: Ensures troop-scoped users can only modify profiles from their troop
  /// Throws SecurityException if access is denied
  Future<void> _validateProfileAccess(
    String profileId,
    UserProfile currentUser,
  ) async {
    // System-wide users can access anything
    if (currentUser.hasSystemWideAccess) {
      return;
    }
    
    // Troop-scoped users must have a troop assigned
    if (currentUser.managedTroopId == null) {
      throw Exception('SECURITY: Troop-scoped user has no managed troop assigned');
    }
    
    // Fetch the profile to check its troop
    final profile = await getProfileById(profileId);
    if (profile == null) {
      throw Exception('Profile not found: $profileId');
    }
    
    // Verify the profile belongs to the user's managed troop
    if (profile.signupTroopId != currentUser.managedTroopId) {
      debugPrint('🚨 SECURITY VIOLATION: User (rank ${currentUser.roleRank}, troop ${currentUser.managedTroopId}) '
                 'attempted to modify profile from different troop (${profile.signupTroopId})');
      throw Exception('Access Denied: This profile is not in your troop');
    }
    
    debugPrint('✅ Access validated: User can modify profile $profileId');
  }

  /// Check if profile_approvals record exists for a profile
  /// Returns true if record exists, false otherwise
  Future<bool> hasApprovalRecord(String profileId) async {
    try {
      final response = await _supabase
          .from(_profilesApprovalsTable)
          .select('profile_id')
          .eq('profile_id', profileId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      _logError('hasApprovalRecord', e);
      return false;
    }
  }

  /// Accept a user profile
  /// 
  /// Updates existing approval record (or creates if not exists) with status=true
  /// Also updates profile.approved=true and assigns roles
  /// Each profile has only ONE profile_approvals record
  /// 
  /// SECURITY: Validates that troop-scoped users can only accept profiles from their troop
  /// 
  /// [profileId] - The profile to accept
  /// [approvedBy] - The admin profile ID performing the action
  /// [currentUser] - Current user for authorization check
  /// [roleIds] - List of role IDs to assign to the user (can be multiple)
  /// [generation] - Required generation to assign to the user
  /// [comments] - Optional comments about the approval
  /// 
  /// Uses transaction-safe RPC function to ensure atomicity of operations
  Future<void> acceptProfile({
    required String profileId,
    required String approvedBy,
    required List<String> roleIds,
    required String generation,
    String? comments,
    String? troopContextId,
    UserProfile? currentUser,
  }) async {
    // Input validation
    if (roleIds.isEmpty) {
      throw ArgumentError('At least one role must be selected');
    }
    if (generation.trim().isEmpty) {
      throw ArgumentError('Generation is required');
    }
    
    try {
      // SECURITY: Validate access if currentUser is provided
      if (currentUser != null) {
        await _validateProfileAccess(profileId, currentUser);
      }
      
      // Get profile details to extract signup_troop for troop_context
      final profile = await getProfileById(profileId);
      if (profile == null) {
        throw Exception('Profile not found: $profileId');
      }
      final signupTroopId = profile.signupTroopId;
      final effectiveTroopContext = troopContextId ?? signupTroopId;
      
      debugPrint('🏕️ Troop context resolution:');
      debugPrint('   troopContextId (from UI): $troopContextId');
      debugPrint('   signupTroopId (from profile): $signupTroopId');
      debugPrint('   effectiveTroopContext (final): $effectiveTroopContext');

      // SECURITY: Non-system users cannot assign a different troop context
      if (currentUser != null && !currentUser.hasSystemWideAccess) {
        if (troopContextId != null && troopContextId != signupTroopId) {
          throw Exception('Access Denied: Cannot assign a different troop context');
        }
      }
      
      debugPrint('🔍 Fetching role ranks for ${roleIds.length} roles');
      
      // Fetch all roles and filter client-side
      // (simpler than using .in_() which may have compatibility issues)
      final rolesResponse = await _supabase
          .from('roles')
          .select('id, role_rank');
      
      final allRoles = Map<String, int>.fromEntries(
        (rolesResponse as List).map((r) => MapEntry(
          r['id'] as String,
          r['role_rank'] as int? ?? 0,
        )),
      );
      
      // Filter to only the roles we need
      final roleRanks = Map<String, int>.fromEntries(
        roleIds.map((id) => MapEntry(id, allRoles[id] ?? 0)),
      );
      
      // Validate troop-scoped roles BEFORE calling transaction
      for (final roleId in roleIds) {
        final rank = roleRanks[roleId] ?? 0;
        final isTroopScoped = rank == 60 || rank == 70;
        
        if (isTroopScoped && effectiveTroopContext == null) {
          throw ArgumentError(
            'Cannot assign troop-scoped role (rank $rank) without a troop assignment. '
            'Please select a troop before accepting.'
          );
        }
      }
      
      // Build role records for transaction
      final roleRecords = roleIds.map((roleId) {
        final rank = roleRanks[roleId] ?? 0;
        final isTroopScoped = rank == 60 || rank == 70;
        
        // CRITICAL: Set troop_context for troop-scoped roles
        return {
          'role_id': roleId,
          'troop_context': (isTroopScoped && effectiveTroopContext != null) 
              ? effectiveTroopContext 
              : 'null', // Use string 'null' for JSONB handling
        };
      }).toList();
      
      debugPrint('📋 Role records prepared: ${roleRecords.map((r) => '${r['role_id']}: troop=${r['troop_context']}').join(', ')}');
      
      // Call transaction-safe RPC function
      debugPrint('🔐 Calling accept_profile_transaction RPC');
      final result = await _supabase.rpc(
        'accept_profile_transaction',
        params: {
          'p_profile_id': profileId,
          'p_approved_by': approvedBy,
          'p_role_records': roleRecords,
          'p_generation': generation.trim(),
          'p_comments': comments,
        },
      );
      
      // Parse result
      final resultData = result as Map<String, dynamic>?;
      final rolesAdded = resultData?['roles_added'] ?? 0;
      final rolesRemoved = resultData?['roles_removed'] ?? 0;
      final rolesUnchanged = resultData?['roles_unchanged'] ?? 0;
      
      debugPrint('✅ Profile accepted (transaction committed)');
      debugPrint('   - Roles added: $rolesAdded');
      debugPrint('   - Roles removed: $rolesRemoved');
      debugPrint('   - Roles unchanged: $rolesUnchanged');
      
    } catch (e) {
      _logError('acceptProfile', e);
      rethrow;
    }
  }

  // ==================== COMMENT OPERATIONS ====================

  /// Add or update comment for a profile without changing approval status
  /// 
  /// Updates the existing profile_approvals record or creates one if not exists.
  /// Status remains false (pending). Each profile has only ONE record.
  /// 
  /// SECURITY: Validates that troop-scoped users can only comment on profiles from their troop
  /// 
  /// [profileId] - The profile to add/update comment for
  /// [approvedBy] - The admin profile ID adding the comment
  /// [comments] - REQUIRED comment text
  /// [currentUser] - Current user for authorization check
  Future<void> addProfileComment({
    required String profileId,
    required String approvedBy,
    required String comments,
    UserProfile? currentUser,
  }) async {
    try {
      debugPrint('📝 Adding/updating comment: profileId=$profileId, approvedBy=$approvedBy');
      
      // SECURITY: Validate access if currentUser is provided
      if (currentUser != null) {
        await _validateProfileAccess(profileId, currentUser);
      }
      
      // Check if approval record already exists for this profile
      final hasRecord = await hasApprovalRecord(profileId);
      
      if (hasRecord) {
        // Update existing record (keep status as is, just update comment)
        debugPrint('🔄 Updating existing approval record with comment');
        await _supabase
            .from(_profilesApprovalsTable)
            .update({
              'approved_by': approvedBy,
              'comments': comments,
              // Note: status is NOT updated, stays as current value
            })
            .eq('profile_id', profileId);
        debugPrint('✅ Comment updated successfully');
      } else {
        // Create new approval record with status=false (pending)
        debugPrint('➕ Creating new approval record with comment');
        await _supabase.from(_profilesApprovalsTable).insert({
          'profile_id': profileId,
          'approved_by': approvedBy,
          'status': false,  // Pending state
          'comments': comments,
        });
        debugPrint('✅ Comment record created successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to add/update comment: $e');
      _logError('addProfileComment', e);
      rethrow;
    }
  }

  /// Reject a user profile
  /// 
  /// Updates existing approval record (or creates if not exists) with status=false
  /// Comments are REQUIRED for rejection. Does NOT update profile.approved field.
  /// Each profile has only ONE profile_approvals record
  /// 
  /// SECURITY: Validates that troop-scoped users can only reject profiles from their troop
  /// 
  /// [profileId] - The profile to reject
  /// [approvedBy] - The admin profile ID performing the action
  /// [comments] - REQUIRED comments explaining rejection
  /// [currentUser] - Current user for authorization check
  Future<void> rejectProfile({
    required String profileId,
    required String approvedBy,
    required String comments,
    UserProfile? currentUser,
  }) async {
    if (comments.trim().isEmpty) {
      throw ArgumentError('Comments are required when rejecting a profile');
    }

    try {
      // SECURITY: Validate access if currentUser is provided
      if (currentUser != null) {
        await _validateProfileAccess(profileId, currentUser);
      }
      
      // Upsert approval record with status=false
      final hasRecord = await hasApprovalRecord(profileId);
      
      if (hasRecord) {
        // Update existing record
        debugPrint('🔄 Updating existing approval record with rejection');
        await _supabase
            .from(_profilesApprovalsTable)
            .update({
              'approved_by': approvedBy,
              'status': false,
              'comments': comments,
            })
            .eq('profile_id', profileId);
      } else {
        // Create new approval record
        debugPrint('➕ Creating new rejection record');
        await _supabase.from(_profilesApprovalsTable).insert({
          'profile_id': profileId,
          'approved_by': approvedBy,
          'status': false,
          'comments': comments,
        });
      }
      
      debugPrint('✅ Profile rejection recorded successfully');
    } catch (e) {
      _logError('rejectProfile', e);
      rethrow;
    }
  }

  /// Update profile generation
  /// 
  /// Updates the generation field for a profile
  /// [profileId] - The profile to update
  /// [generation] - The generation value to set
  Future<void> updateProfileGeneration({
    required String profileId,
    required String generation,
  }) async {
    try {
      await _supabase.from(_profilesTable).update({
        'generation': generation,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', profileId);
    } catch (e) {
      _logError('updateProfileGeneration', e);
      rethrow;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Log errors with context
  void _logError(String operation, dynamic error) {
    debugPrint('AdminService.$operation error: $error');
  }
}
