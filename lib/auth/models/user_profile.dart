import 'package:flutter/foundation.dart';

/// User profile with role information
///
/// Links user authentication with their role rank and contains all user data
class UserProfile {
  final String id;  // Maps to profiles.id (primary key)
  final String userId;  // Maps to profiles.user_id (auth UID)
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? nameAr;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime? birthdate;
  final String? gender;
  final String? signupTroopId;
  final String? generation;
  final String? avatarUrl;
  final int roleRank;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.userId,
    this.firstName,
    this.middleName,
    this.lastName,
    this.nameAr,
    this.email,
    this.phone,
    this.address,
    this.birthdate,
    this.gender,
    this.signupTroopId,
    this.generation,
    this.avatarUrl,
    required this.roleRank,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get full name constructed from first, middle, and last names
  String? get fullName {
    final parts = [firstName, middleName, lastName]
        .where((part) => part != null && part.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : null;
  }

  /// Create UserProfile from Supabase JSON
  ///
  /// Expects data from profiles table with all columns
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Debug log to diagnose missing id issue
    if (json['id'] == null) {
      debugPrint('⚠️ UserProfile.fromJson called with null id! JSON keys: ${json.keys.toList()}');
      debugPrint('   JSON dump: $json');
    }
    
    return UserProfile(
      id: json['id'] as String? ?? '', // Provide empty string fallback to prevent crash
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String?,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String?,
      nameAr: json['name_ar'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      birthdate: json['birthdate'] != null
          ? DateTime.parse(json['birthdate'] as String)
          : null,
      gender: json['gender'] as String?,
      signupTroopId: json['signup_troop'] as String?,
      generation: json['generation'] as String?,
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
      'id': id,
      'user_id': userId,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'name_ar': nameAr,
      'email': email,
      'phone': phone,
      'address': address,
      'birthdate': birthdate?.toIso8601String(),
      'gender': gender,
      'signup_troop': signupTroopId,
      'generation': generation,
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

  /// Check if user is admin (rank >= 90)
  bool get isAdmin => roleRank >= 90;

  /// Check if user is system admin (rank == 100)
  bool get isSystemAdmin => roleRank == 100;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          roleRank == other.roleRank;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode ^ roleRank.hashCode;

  @override
  String toString() =>
      'UserProfile{id: $id, userId: $userId, fullName: $fullName, roleRank: $roleRank}';
}
