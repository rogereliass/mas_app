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
      // 1. Upsert approval record with status=true
      final hasRecord = await hasApprovalRecord(profileId);
      
      if (hasRecord) {
        // Update existing record
        debugPrint('🔄 Updating existing approval record for profile: $profileId');
        await _supabase
            .from(_profilesApprovalsTable)
            .update({
              'approved_by': approvedBy,
              'status': true,
              'comments': comments,
            })
            .eq('profile_id', profileId);
      } else {
        // Create new approval record
        debugPrint('➕ Creating new approval record for profile: $profileId');
        await _supabase.from(_profilesApprovalsTable).insert({
          'profile_id': profileId,
          'approved_by': approvedBy,
          'status': true,
          'comments': comments,
        });
      }

      // 2. Update profile with generation and approved status
      await _supabase
          .from(_profilesTable)
          .update({
            'approved': true,
            'generation': generation,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profileId);

      // 3. Smart role update: only add/remove changed roles
      // Get current roles
      final currentRolesResponse = await _supabase
          .from(_profileRolesTable)
          .select('role_id')
          .eq('profile_id', profileId);
      
      final currentRoleIds = (currentRolesResponse as List)
          .map((item) => item['role_id'] as String)
          .toSet();
      
      final newRoleIds = roleIds.toSet();
      
      // Find roles to remove (in current but not in new)
      final rolesToRemove = currentRoleIds.difference(newRoleIds);
      if (rolesToRemove.isNotEmpty) {
        debugPrint('🗑️ Removing ${rolesToRemove.length} unchecked roles');
        for (final roleId in rolesToRemove) {
          await _supabase
              .from(_profileRolesTable)
              .delete()
              .eq('profile_id', profileId)
              .eq('role_id', roleId);
        }
      }
      
      // Find roles to add (in new but not in current)
      final rolesToAdd = newRoleIds.difference(currentRoleIds);
      if (rolesToAdd.isNotEmpty) {
        debugPrint('➕ Adding ${rolesToAdd.length} new roles');
        final roleRecords = rolesToAdd.map((roleId) => {
          'profile_id': profileId,
          'role_id': roleId,
          'assigned_by': approvedBy,
        }).toList();
        
        await _supabase.from(_profileRolesTable).insert(roleRecords);
      }
      
      final unchangedCount = currentRoleIds.intersection(newRoleIds).length;
      debugPrint('✅ Profile accepted - $unchangedCount roles unchanged, ${rolesToAdd.length} added, ${rolesToRemove.length} removed');
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
  /// [profileId] - The profile to add/update comment for
  /// [approvedBy] - The admin profile ID adding the comment
  /// [comments] - REQUIRED comment text
  Future<void> addProfileComment({
    required String profileId,
    required String approvedBy,
    required String comments,
  }) async {
    try {
      debugPrint('📝 Adding/updating comment: profileId=$profileId, approvedBy=$approvedBy');
      
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
