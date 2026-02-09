import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/role.dart';
import '../models/user_profile.dart';

/// Exception thrown when role/profile operations fail
class RoleException implements Exception {
  final String message;
  final String? statusCode;

  const RoleException(this.message, {this.statusCode});

  @override
  String toString() => 'RoleException: $message';
}

/// Repository for role and profile-related operations
///
/// Handles fetching user profiles with role information from Supabase
class RoleRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch user profile with role rank
  ///
  /// Join path: auth.uid() → profiles.user_id → profiles.id → profile_roles.profile_id → profile_roles.role_id → roles.id
  /// Returns null if user is not authenticated or profile not found
  /// Throws [RoleException] on error
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      debugPrint('🔍 Fetching profile for user: $userId');

      // Step 1: auth.uid() → profiles.user_id to get all profile data
      final profileResponse = await _supabase
          .from('profiles')
          .select('''
            id,
            user_id,
            first_name,
            middle_name,
            last_name,
            name_ar,
            email,
            phone,
            address,
            birthdate,
            gender,
            signup_troop,
            generation,
            created_at,
            updated_at
          ''')
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while fetching user profile',
              statusCode: '408',
            ),
          );

      if (profileResponse == null) {
        debugPrint('⚠️ No profile found for user: $userId');
        return null;
      }

      final profileId = profileResponse['id'] as String;
      debugPrint('   Profile ID: $profileId');
      debugPrint('   Name: ${profileResponse['first_name']} ${profileResponse['middle_name'] ?? ''} ${profileResponse['last_name']}'.trim());

      // Step 2: profiles.id → profile_roles.profile_id to get role_id
      // Step 3: profile_roles.role_id → roles.id to get role_rank
      final rolesResponse = await _supabase
          .from('profile_roles')
          .select('roles!inner(role_rank)')
          .eq('profile_id', profileId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while fetching user roles',
              statusCode: '408',
            ),
          );

      // Get the highest role_rank (users can have multiple roles)
      int roleRank = 0;
      if (rolesResponse.isNotEmpty) {
        roleRank = rolesResponse
            .map((item) => (item['roles'] as Map<String, dynamic>)['role_rank'] as int? ?? 0)
            .reduce((a, b) => a > b ? a : b);
        debugPrint('   Highest role rank: $roleRank');
      } else {
        debugPrint('   No roles found, defaulting to rank 0');
      }

      // Add role_rank to profile data
      final profileData = {
        ...profileResponse,
        'role_rank': roleRank,
      };

      final profile = UserProfile.fromJson(profileData);
      debugPrint('✅ Profile loaded: ${profile.fullName} (rank $roleRank)');
      return profile;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows returned - user profile doesn't exist
        return null;
      }
      throw RoleException(
        'Database error: ${e.message}',
        statusCode: e.code,
      );
    } on RoleException {
      rethrow;
    } catch (e) {
      throw RoleException('Failed to fetch user profile: $e');
    }
  }

  /// Get current user's profile with role rank
  ///
  /// Returns null if no user is authenticated
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return getUserProfile(user.id);
  }

  /// Fetch all available roles from the system
  ///
  /// Returns list of roles ordered by rank
  /// Throws [RoleException] on error
  Future<List<Role>> getAllRoles() async {
    try {
      final response = await _supabase
          .from('roles')
          .select()
          .order('role_rank', ascending: true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while fetching roles',
              statusCode: '408',
            ),
          );

      return (response as List)
          .map((json) => Role.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw RoleException(
        'Database error: ${e.message}',
        statusCode: e.code,
      );
    } on RoleException {
      rethrow;
    } catch (e) {
      throw RoleException('Failed to fetch roles: $e');
    }
  }

  /// Get the role rank for a specific user
  ///
  /// Returns 0 (public) if user has no profile or role
  /// Throws [RoleException] on error
  Future<int> getUserRoleRank(String userId) async {
    final profile = await getUserProfile(userId);
    return profile?.roleRank ?? 0;
  }

  /// Get current authenticated user's role rank
  ///
  /// Returns 0 if no user is authenticated or user has no role
  Future<int> getCurrentUserRoleRank() async {
    final profile = await getCurrentUserProfile();
    return profile?.roleRank ?? 0;
  }

  /// Check if user can access content with given minimum rank
  ///
  /// Returns true if user's rank >= minRank
  /// Returns true if minRank is 0 (public content)
  Future<bool> canUserAccess(String userId, int minRank) async {
    if (minRank == 0) return true; // Public content
    
    final userRank = await getUserRoleRank(userId);
    return userRank >= minRank;
  }

  /// Check if current user can access content with given minimum rank
  Future<bool> canCurrentUserAccess(int minRank) async {
    if (minRank == 0) return true; // Public content
    
    final user = _supabase.auth.currentUser;
    if (user == null) return false; // Not authenticated
    
    return canUserAccess(user.id, minRank);
  }

  /// Get all roles assigned to a specific user
  ///
  /// Join path: auth.uid() → profiles.user_id → profiles.id → profile_roles.profile_id → profile_roles.role_id → roles.id
  /// Returns list of roles the user has been assigned
  /// Returns empty list if user has no roles
  /// Throws [RoleException] on error
  Future<List<Role>> getUserRoles(String userId) async {
    try {
      debugPrint('🔍 ========== FETCHING ROLES DEBUG ==========');
      debugPrint('   User ID (auth.uid): $userId');
      
      // Step 1: auth.uid() → profiles.user_id to get profiles.id
      final profileResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        debugPrint('❌ No profile found for user: $userId');
        return [];
      }

      final profileId = profileResponse['id'] as String;
      debugPrint('✅ Profile ID: $profileId');

      // Step 2: Check profile_roles junction table
      debugPrint('🔍 Checking profile_roles table for profile_id: $profileId');
      final profileRolesCheck = await _supabase
          .from('profile_roles')
          .select('id, profile_id, role_id')
          .eq('profile_id', profileId);
      
      debugPrint('   Rows: $profileRolesCheck');
      debugPrint('   Count: ${(profileRolesCheck as List).length}');
      
      if ((profileRolesCheck).isEmpty) {
        debugPrint('⚠️ No entries in profile_roles for this profile!');
        debugPrint('   ACTION NEEDED: Insert a row in profile_roles table:');
        debugPrint('   INSERT INTO profile_roles (profile_id, role_id) VALUES (\'$profileId\', <role-id>);');
        return [];
      }

      // Print each entry
      for (var entry in profileRolesCheck) {
        debugPrint('   Found: profile_roles.id=${entry['id']}, role_id=${entry['role_id']}');
      }

      // Step 3: Join with roles table to get full role details
      debugPrint('🔍 Attempting join query: profile_roles → roles');
      final response = await _supabase
          .from('profile_roles')
          .select('''
            id,
            profile_id,
            role_id,
            roles!inner(
              id,
              name,
              slug,
              description,
              role_rank,
              created_at
            )
          ''')
          .eq('profile_id', profileId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while fetching user roles',
              statusCode: '408',
            ),
          );

      debugPrint('   Join query raw response: $response');
      debugPrint('   Response type: ${response.runtimeType}');
      debugPrint('   Response length: ${(response as List).length}');
      
      if ((response as List).isEmpty) {
        debugPrint('⚠️ Join returned empty - possible RLS blocking or invalid role_id references');
        return [];
      }

      final roles = response
          .map((item) {
            debugPrint('   Processing item: $item');
            final roleData = item['roles'] as Map<String, dynamic>;
            debugPrint('   → Role: ${roleData['name']} (rank ${roleData['role_rank']})');
            return Role.fromJson(roleData);
          })
          .toList();
      
      debugPrint('✅ ========== FOUND ${roles.length} ROLES ==========');
      return roles;
      
    } on PostgrestException catch (e) {
      debugPrint('❌ PostgrestException: ${e.message}');
      debugPrint('   Code: ${e.code}, Details: ${e.details}');
      throw RoleException(
        'Database error: ${e.message}',
        statusCode: e.code,
      );
    } on RoleException {
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error: $e');
      debugPrint('   Stack: $stackTrace');
      throw RoleException('Failed to fetch user roles: $e');
    }
  }

  /// Get all roles assigned to current authenticated user
  ///
  /// Returns empty list if no user is authenticated or user has no roles
  Future<List<Role>> getCurrentUserRoles() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      return await getUserRoles(user.id);
    } catch (e) {
      // Return empty list on error (graceful degradation)
      return [];
    }
  }
}
