import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/pending_profile.dart';
import 'models/profile_approval.dart';
import '../../../../auth/models/role.dart';
import '../../../../auth/data/role_repository.dart';

/// Admin Service for User Acceptance Operations
/// 
/// Handles all Supabase operations related to profile approvals
/// including fetching pending profiles, approving/rejecting, and updating generations
class AdminService {
  static const String _profilesTable = 'profiles';
  static const String _profilesApprovalsTable = 'profiles_approvals';
  static const String _profileRolesTable = 'profile_roles';
  static const String _troopsTable = 'troops';

  final SupabaseClient _supabase;
  final RoleRepository _roleRepository = RoleRepository();

  AdminService(this._supabase);

  /// Factory constructor using singleton Supabase instance
  factory AdminService.instance() {
    return AdminService(Supabase.instance.client);
  }

  // ==================== FETCH OPERATIONS ====================

  /// Fetch all profiles pending approval (approved = false)
  /// Returns profiles sorted by creation date (oldest first)
  Future<List<PendingProfile>> fetchPendingProfiles() async {
    try {
      final response = await _supabase
          .from(_profilesTable)
          .select('''
            *,
            troops:signup_troop(name)
          ''')
          .eq('approved', false)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => PendingProfile.fromJson(json))
          .toList();
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

  /// Accept a user profile
  /// 
  /// Creates approval record with status=true and updates profile.approved=true
  /// Also assigns roles to user by creating multiple profile_roles records
  /// [profileId] - The profile to accept
  /// [approvedBy] - The admin profile ID performing the action
  /// [roleIds] - List of role IDs to assign to the user (can be multiple)
  /// [generation] - Required generation to assign to the user
  /// [comments] - Optional comments about the approval
  Future<void> acceptProfile({
    required String profileId,
    required String approvedBy,
    required List<String> roleIds,
    required String generation,
    String? comments,
  }) async {
    try {
      // 1. Create approval record
      await _supabase.from(_profilesApprovalsTable).insert({
        'profile_id': profileId,
        'approved_by': approvedBy,
        'status': true,
        'comments': comments,
      });

      // 2. Update profile with generation
      await _supabase
          .from(_profilesTable)
          .update({
            'approved': true,
            'generation': generation,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profileId);

      // 3. Assign multiple roles to user
      final roleRecords = roleIds.map((roleId) => {
        'profile_id': profileId,
        'role_id': roleId,
        'assigned_by': approvedBy,
      }).toList();
      
      await _supabase.from(_profileRolesTable).insert(roleRecords);
    } catch (e) {
      _logError('acceptProfile', e);
      rethrow;
    }
  }

  // ==================== COMMENT OPERATIONS ====================

  /// Add comment to a profile without changing approval status
  /// 
  /// Profile stays in pending state for future review
  /// [profileId] - The profile to add comment to
  /// [approvedBy] - The admin profile ID adding the comment
  /// [comments] - REQUIRED comment text
  Future<void> addProfileComment({
    required String profileId,
    required String approvedBy,
    required String comments,
  }) async {
    try {
      debugPrint('📝 Adding comment: profileId=$profileId, approvedBy=$approvedBy');
      
      // Create comment record with false status (keeps profile pending)
      // TODO: Change to null once database allows nullable status
      await _supabase.from(_profilesApprovalsTable).insert({
        'profile_id': profileId,
        'approved_by': approvedBy,
        'status': false,  // Using false for "comment/pending" state
        'comments': comments,
      });
      
      debugPrint('✅ Comment record created successfully');
    } catch (e) {
      debugPrint('❌ Failed to insert comment: $e');
      _logError('addProfileComment', e);
      rethrow;
    }
  }

  /// Reject a user profile
  /// 
  /// Creates approval record with status=false (DOES NOT update profile.approved)
  /// Comments are REQUIRED for rejection
  /// [profileId] - The profile to reject
  /// [approvedBy] - The admin profile ID performing the action
  /// [comments] - REQUIRED comments explaining rejection
  Future<void> rejectProfile({
    required String profileId,
    required String approvedBy,
    required String comments,
  }) async {
    if (comments.trim().isEmpty) {
      throw ArgumentError('Comments are required when rejecting a profile');
    }

    try {
      await _supabase.from(_profilesApprovalsTable).insert({
        'profile_id': profileId,
        'approved_by': approvedBy,
        'status': false,
        'comments': comments,
      });
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
