import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/models/user_profile.dart';

/// Mixin providing automatic troop-scoping for admin service queries
/// 
/// Apply to any service that needs role-based data filtering:
/// - System admins (rank 90+) see ALL data
/// - Troop leaders/heads (rank 60, 70) see ONLY their troop's data
/// 
/// Usage:
/// ```dart
/// class MyAdminService with ScopedServiceMixin {
///   Future<List<Data>> fetchData(UserProfile currentUser) async {
///     var query = supabase.from('table').select();
///     query = applyScopeFilter(query, currentUser, 'troop_id');
///     return query;
///   }
/// }
/// ```
mixin ScopedServiceMixin {
  /// Adds troop filter to query builder based on user's role and scope
  /// 
  /// [query] - The Supabase query builder to modify
  /// [currentUser] - The currently authenticated user with role info
  /// [troopColumnName] - Name of the troop foreign key column (e.g., 'signup_troop', 'troop_id')
  /// 
  /// Returns modified query with appropriate filtering applied
  /// 
  /// Type is dynamic to support both PostgrestFilterBuilder and PostgrestTransformBuilder
  dynamic applyScopeFilter(
    dynamic query,
    UserProfile currentUser,
    String troopColumnName,
  ) {
    // System-wide access (admins/moderators rank 90+) → No filter needed
    if (currentUser.hasSystemWideAccess) {
      debugPrint('🌐 System-wide access granted (rank ${currentUser.roleRank})');
      return query; // Return all records
    }
    
    // Troop-scoped access (troop leaders/heads rank 60, 70) → Filter to their troop only
    if (currentUser.isTroopScoped && currentUser.managedTroopId != null) {
      debugPrint('🎯 Troop-scoped access: filtering by $troopColumnName = ${currentUser.managedTroopId}');
      return query.eq(troopColumnName, currentUser.managedTroopId!);
    }
    
    // Fallback: User has no valid scope → Return empty results
    // This handles edge cases like troop leader without assigned troop
    debugPrint('⚠️ WARNING: User rank ${currentUser.roleRank} has no valid access scope. Managed troop: ${currentUser.managedTroopId}');
    return query.eq('id', '00000000-0000-0000-0000-000000000000'); // Guaranteed non-existent UUID
  }
  
  /// Check if current user can access a specific troop's data
  /// 
  /// Use for single-record operations (view, edit, delete)
  bool canAccessTroop(UserProfile currentUser, String? troopId) {
    if (currentUser.hasSystemWideAccess) return true;
    if (troopId == null) return false;
    return currentUser.managedTroopId == troopId;
  }
}
