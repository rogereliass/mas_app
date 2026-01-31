/// User profile with role information
///
/// Links user authentication with their role rank
class UserProfile {
  final String userId;
  final String? fullName;
  final String? avatarUrl;
  final int roleRank;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.userId,
    this.fullName,
    this.avatarUrl,
    required this.roleRank,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create UserProfile from Supabase JSON
  /// 
  /// Expects joined data from profiles, profiles_roles, and roles tables:
  /// ```sql
  /// SELECT 
  ///   profiles.user_id,
  ///   profiles.full_name,
  ///   profiles.avatar_url,
  ///   profiles.created_at,
  ///   profiles.updated_at,
  ///   roles.rank as role_rank
  /// FROM profiles
  /// LEFT JOIN profiles_roles ON profiles.user_id = profiles_roles.user_id
  /// LEFT JOIN roles ON profiles_roles.role_id = roles.id
  /// ```
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      roleRank: json['role_rank'] as int? ?? 0, // Default to 0 (public) if no role
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert UserProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'role_rank': roleRank,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Check if user can access content with given minimum rank
  bool canAccess(int minRank) => roleRank >= minRank;

  /// Check if user is public (unauthenticated)
  bool get isPublic => roleRank == 0;

  /// Check if user is admin (rank >= 80)
  bool get isAdmin => roleRank >= 80;

  /// Check if user is system admin (rank == 100)
  bool get isSystemAdmin => roleRank == 100;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          roleRank == other.roleRank;

  @override
  int get hashCode => userId.hashCode ^ roleRank.hashCode;

  @override
  String toString() =>
      'UserProfile{userId: $userId, fullName: $fullName, roleRank: $roleRank}';
}
