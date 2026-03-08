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

  void _logDebug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  /// Fetch user profile with role rank
  ///
  /// Join path: auth.uid() → profiles.user_id → profiles.id → profile_roles.profile_id → profile_roles.role_id → roles.id
  /// Returns null if user is not authenticated or profile not found
  /// Throws [RoleException] on error
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      _logDebug('🔍 Fetching profile for user: $userId');

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

      _logDebug(
        '📊 Profile query result: ${profileResponse != null ? "FOUND" : "NULL"}',
      );
      if (profileResponse != null) {
        _logDebug('   Raw response keys: ${profileResponse.keys.toList()}');
        _logDebug('   first_name: ${profileResponse['first_name']}');
        _logDebug('   middle_name: ${profileResponse['middle_name']}');
        _logDebug('   last_name: ${profileResponse['last_name']}');
        _logDebug('   email: ${profileResponse['email']}');
      }

      if (profileResponse == null) {
        _logDebug('❌ No profile found for user: $userId');
        return null;
      }

      final profileId = profileResponse['id'] as String;
      _logDebug('   Profile ID: $profileId');
      _logDebug(
        '   Name: ${profileResponse['first_name']} ${profileResponse['middle_name'] ?? ''} ${profileResponse['last_name']}'
            .trim(),
      );

      // Step 2: profiles.id → profile_roles.profile_id to get role_id and troop_context
      // Step 3: profile_roles.role_id → roles.id to get role_rank
      final rolesResponse = await _supabase
          .from('profile_roles')
          .select('role_id, troop_context, roles!inner(role_rank)')
          .eq('profile_id', profileId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while fetching user roles',
              statusCode: '408',
            ),
          );

      // Get the highest role_rank and extract troop_context for troop-scoped roles
      int roleRank = 0;
      String? managedTroopId;

      if (rolesResponse.isNotEmpty) {
        // Find role with highest rank for default access level
        var highestRole = rolesResponse.reduce((a, b) {
          final rankA =
              (a['roles'] as Map<String, dynamic>)['role_rank'] as int? ?? 0;
          final rankB =
              (b['roles'] as Map<String, dynamic>)['role_rank'] as int? ?? 0;
          return rankA > rankB ? a : b;
        });

        roleRank =
            (highestRole['roles'] as Map<String, dynamic>)['role_rank']
                as int? ??
            0;

        // Extract troop_context from ANY troop-scoped role (rank 60 or 70)
        // This is separate from highest rank - user might be System Admin (100) + Troop Head (70)
        for (var roleEntry in rolesResponse) {
          final entryRank =
              (roleEntry['roles'] as Map<String, dynamic>)['role_rank']
                  as int? ??
              0;
          if (entryRank == 60 || entryRank == 70) {
            final troopContext = roleEntry['troop_context'] as String?;
            if (troopContext != null) {
              managedTroopId = troopContext;
              _logDebug(
                '   Troop-scoped role (rank $entryRank) detected. Managed troop: $managedTroopId',
              );
              break; // Use first found troop context
            }
          }
        }

        _logDebug('   Highest role rank: $roleRank');
      } else {
        _logDebug('   No roles found, defaulting to rank 0');
      }

      // Add role_rank and managed_troop_id to profile data
      final profileData = {
        ...profileResponse,
        'role_rank': roleRank,
        'managed_troop_id': managedTroopId,
      };

      final profile = UserProfile.fromJson(profileData);
      _logDebug('✅ Profile loaded: ${profile.fullName} (rank $roleRank)');
      return profile;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows returned - user profile doesn't exist
        return null;
      }
      throw RoleException('Database error: ${e.message}', statusCode: e.code);
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
      throw RoleException('Database error: ${e.message}', statusCode: e.code);
    } on RoleException {
      rethrow;
    } catch (e) {
      throw RoleException('Failed to fetch roles: $e');
    }
  }

  /// Fetch roles assigned to a specific profile
  ///
  /// Returns list of Role objects currently assigned to the profile
  /// Returns empty list if profile has no roles
  /// Throws [RoleException] on error
  Future<List<Role>> getProfileRoles(String profileId) async {
    try {
      final response = await _supabase
          .from('profile_roles')
          .select('roles!inner(*)')
          .eq('profile_id', profileId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while fetching profile roles',
              statusCode: '408',
            ),
          );

      return (response as List)
          .map((item) => Role.fromJson(item['roles'] as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw RoleException('Database error: ${e.message}', statusCode: e.code);
    } on RoleException {
      rethrow;
    } catch (e) {
      throw RoleException('Failed to fetch profile roles: $e');
    }
  }

  /// Get troop context for a profile's troop-scoped roles (rank 60 or 70)
  ///
  /// Returns the first non-null troop_context found, or null if none
  Future<String?> getTroopContextForProfile(String profileId) async {
    try {
      final response = await _supabase
          .from('profile_roles')
          .select('troop_context, roles!inner(role_rank)')
          .eq('profile_id', profileId)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while fetching troop context',
              statusCode: '408',
            ),
          );

      for (final entry in response as List) {
        final rank =
            (entry['roles'] as Map<String, dynamic>)['role_rank'] as int? ?? 0;
        if (rank == 60 || rank == 70) {
          final troopContext = entry['troop_context'] as String?;
          if (troopContext != null) {
            return troopContext;
          }
        }
      }

      return null;
    } on PostgrestException catch (e) {
      throw RoleException('Database error: ${e.message}', statusCode: e.code);
    } on RoleException {
      rethrow;
    } catch (e) {
      throw RoleException('Failed to fetch troop context: $e');
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
      _logDebug('🔍 ========== FETCHING ROLES DEBUG ==========');
      _logDebug('   User ID (auth.uid): $userId');

      // Step 1: auth.uid() → profiles.user_id to get profiles.id
      final profileResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        _logDebug('❌ No profile found for user: $userId');
        return [];
      }

      final profileId = profileResponse['id'] as String;
      _logDebug('✅ Profile ID: $profileId');

      // Step 2: Check profile_roles junction table
      _logDebug('🔍 Checking profile_roles table for profile_id: $profileId');
      final profileRolesCheck = await _supabase
          .from('profile_roles')
          .select('id, profile_id, role_id')
          .eq('profile_id', profileId);

      _logDebug('   Rows: $profileRolesCheck');
      _logDebug('   Count: ${(profileRolesCheck as List).length}');

      if ((profileRolesCheck).isEmpty) {
        _logDebug('⚠️ No entries in profile_roles for this profile!');
        _logDebug('   ACTION NEEDED: Insert a row in profile_roles table:');
        _logDebug(
          '   INSERT INTO profile_roles (profile_id, role_id) VALUES (\'$profileId\', <role-id>);',
        );
        return [];
      }

      // Print each entry
      for (var entry in profileRolesCheck) {
        _logDebug(
          '   Found: profile_roles.id=${entry['id']}, role_id=${entry['role_id']}',
        );
      }

      // Step 3: Join with roles table to get full role details
      _logDebug('🔍 Attempting join query: profile_roles → roles');
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

      _logDebug('   Join query raw response: $response');
      _logDebug('   Response type: ${response.runtimeType}');
      _logDebug('   Response length: ${(response as List).length}');

      if ((response as List).isEmpty) {
        _logDebug(
          '⚠️ Join returned empty - possible RLS blocking or invalid role_id references',
        );
        return [];
      }

      final roles = response.map((item) {
        _logDebug('   Processing item: $item');
        final roleData = item['roles'] as Map<String, dynamic>;
        _logDebug(
          '   → Role: ${roleData['name']} (rank ${roleData['role_rank']})',
        );
        return Role.fromJson(roleData);
      }).toList();

      _logDebug('✅ ========== FOUND ${roles.length} ROLES ==========');
      return roles;
    } on PostgrestException catch (e) {
      _logDebug('❌ PostgrestException: ${e.message}');
      _logDebug('   Code: ${e.code}, Details: ${e.details}');
      throw RoleException('Database error: ${e.message}', statusCode: e.code);
    } on RoleException {
      rethrow;
    } catch (e, stackTrace) {
      _logDebug('❌ Unexpected error: $e');
      _logDebug('   Stack: $stackTrace');
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

  /// Get managed troop ID for a user (for troop-scoped roles)
  ///
  /// Returns troop_context for users with rank 60 (Troop Leader) or 70 (Troop Head)
  /// Returns null for system-wide roles or users without troop-scoped roles
  /// Throws [RoleException] on error
  Future<String?> getUserManagedTroopId(String userId) async {
    try {
      // Get profile for this user
      final profile = await getUserProfile(userId);
      return profile?.managedTroopId;
    } on RoleException {
      rethrow;
    } catch (e) {
      throw RoleException('Failed to fetch managed troop: $e');
    }
  }

  /// Assign role with optional troop context
  ///
  /// For troop-scoped roles (rank 60, 70), troopId should be provided
  /// For system-wide roles (rank 90+), troopId should be null
  /// [profileId] - The profile to assign role to
  /// [roleId] - The role ID to assign
  /// [troopId] - Optional troop context (required for rank 60, 70)
  /// [assignedBy] - Profile ID of the admin assigning the role
  /// Throws [RoleException] on error
  Future<void> assignRoleWithTroopContext({
    required String profileId,
    required String roleId,
    String? troopId,
    required String assignedBy,
  }) async {
    try {
      _logDebug(
        '🔧 Assigning role $roleId to profile $profileId with troop context: $troopId',
      );

      final data = {
        'profile_id': profileId,
        'role_id': roleId,
        'assigned_by': assignedBy,
        if (troopId != null) 'troop_context': troopId,
      };

      await _supabase
          .from('profile_roles')
          .insert(data)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const RoleException(
              'Request timed out while assigning role',
              statusCode: '408',
            ),
          );

      _logDebug('✅ Role assigned successfully');
    } on PostgrestException catch (e) {
      throw RoleException('Database error: ${e.message}', statusCode: e.code);
    } on RoleException {
      rethrow;
    } catch (e) {
      throw RoleException('Failed to assign role: $e');
    }
  }
}
