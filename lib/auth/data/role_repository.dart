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
  /// Joins profiles, profiles_roles, and roles tables to get user's role rank
  /// Returns null if user is not authenticated or profile not found
  /// Throws [RoleException] on error
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('''
            user_id,
            full_name,
            avatar_url,
            created_at,
            updated_at,
            profiles_roles!inner(
              roles!inner(
                rank
              )
            )
          ''')
          .eq('user_id', userId)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while fetching user profile',
              statusCode: '408',
            ),
          );

      // Extract role rank from nested structure
      final roleRank = response['profiles_roles']?['roles']?['rank'] as int?;

      // Build flattened JSON for UserProfile
      final profileData = {
        'user_id': response['user_id'],
        'full_name': response['full_name'],
        'avatar_url': response['avatar_url'],
        'created_at': response['created_at'],
        'updated_at': response['updated_at'],
        'role_rank': roleRank ?? 0, // Default to public if no role
      };

      return UserProfile.fromJson(profileData);
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
          .order('rank', ascending: true)
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
  /// Returns list of roles the user has been assigned
  /// Returns empty list if user has no roles
  /// Throws [RoleException] on error
  Future<List<Role>> getUserRoles(String userId) async {
    try {
      // First get the profile ID for this user
      final profileResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        // User has no profile, return empty list
        return [];
      }

      final profileId = profileResponse['id'] as String;

      // Now get all roles for this profile
      final response = await _supabase
          .from('profiles_roles')
          .select('''
            roles!inner(
              id,
              name,
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

      return (response as List)
          .map((item) {
            final roleData = item['roles'] as Map<String, dynamic>;
            return Role.fromJson(roleData);
          })
          .toList();
    } on PostgrestException catch (e) {
      throw RoleException(
        'Database error: ${e.message}',
        statusCode: e.code,
      );
    } on RoleException {
      rethrow;
    } catch (e) {
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
