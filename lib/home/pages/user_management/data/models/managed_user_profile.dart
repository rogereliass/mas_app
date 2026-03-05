import '../../../../../auth/models/role.dart';

/// Represents a role assignment with troop context
class RoleAssignment {
  final Role role;
  final String? troopContextId;
  final String? troopContextName;

  const RoleAssignment({
    required this.role,
    this.troopContextId,
    this.troopContextName,
  });
}

/// Model representing a managed user profile
///
/// Includes profile fields plus assigned roles for admin editing
class ManagedUserProfile {
  final String id;
  final String userId;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? nameAr;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime? birthdate;
  final String? gender;
  final String? generation;
  final String? scoutOrgId;
  final String? scoutCode;
  final String? medicalNotes;
  final String? allergies;
  final String? signupTroopId;
  final String? signupTroopName;
  final List<Role> roles;
  final List<RoleAssignment> roleAssignments;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ManagedUserProfile({
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
    this.generation,
    this.scoutOrgId,
    this.scoutCode,
    this.medicalNotes,
    this.allergies,
    this.signupTroopId,
    this.signupTroopName,
    this.roles = const [],
    this.roleAssignments = const [],
    required this.createdAt,
    this.updatedAt,
  });

  String get fullName {
    final parts = [
      firstName,
      middleName,
      lastName,
    ].where((part) => part != null && part.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : 'Unnamed User';
  }

  Role? get primaryRole {
    if (roles.isEmpty) return null;
    final sorted = [...roles]..sort((a, b) => b.rank.compareTo(a.rank));
    return sorted.first;
  }

  factory ManagedUserProfile.fromJson(Map<String, dynamic> json) {
    String? asString(dynamic value) => value is String ? value : null;
    DateTime? asDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final rolesJson = json['profile_roles'] as List<dynamic>? ?? [];

    // Parse role assignments with troop context
    final List<RoleAssignment> assignments = [];
    final List<Role> parsedRoles = [];

    for (var entry in rolesJson) {
      try {
        final roleData = entry['roles'] as Map<String, dynamic>?;
        if (roleData != null && roleData.isNotEmpty) {
          // Validate required role fields before parsing
          if (roleData['id'] != null &&
              roleData['name'] != null &&
              roleData['created_at'] != null) {
            final role = Role.fromJson(roleData);
            parsedRoles.add(role);

            // Get troop context from profile_roles junction table
            final troopContextId = asString(entry['troop_context']);
            String? troopContextName;

            // Check if troop context data is available
            if (troopContextId != null && entry['troops'] != null) {
              final troopData = entry['troops'] as Map<String, dynamic>?;
              troopContextName = asString(troopData?['name']);
            }

            assignments.add(
              RoleAssignment(
                role: role,
                troopContextId: troopContextId,
                troopContextName: troopContextName,
              ),
            );
          }
        }
      } catch (e) {
        // Skip invalid role entries but log the error
        print('⚠️ Skipping invalid role entry: $e');
        continue;
      }
    }

    // Validate required profile fields
    final id = asString(json['id']);
    final userId = asString(json['user_id']);
    final createdAt = asDateTime(json['created_at']);

    if (id == null || id.isEmpty) {
      throw ArgumentError('Profile id is required but was null or invalid');
    }
    if (userId == null || userId.isEmpty) {
      throw ArgumentError(
        'Profile user_id is required but was null or invalid',
      );
    }
    if (createdAt == null) {
      throw ArgumentError(
        'Profile created_at is required but was null or invalid',
      );
    }

    return ManagedUserProfile(
      id: id,
      userId: userId,
      firstName: asString(json['first_name']),
      middleName: asString(json['middle_name']),
      lastName: asString(json['last_name']),
      nameAr: asString(json['name_ar']),
      email: asString(json['email']),
      phone: asString(json['phone']),
      address: asString(json['address']),
      birthdate: asDateTime(json['birthdate']),
      gender: asString(json['gender']),
      generation: asString(json['generation']),
      scoutOrgId: asString(json['scout_org_id']),
      scoutCode: asString(json['scout_code']),
      medicalNotes: asString(json['medical_notes']),
      allergies: asString(json['allergies']),
      signupTroopId: asString(json['signup_troop']),
      signupTroopName: json['troops'] != null && json['troops'] is Map
          ? asString(json['troops']['name'])
          : null,
      roles: parsedRoles,
      roleAssignments: assignments,
      createdAt: createdAt,
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  ManagedUserProfile copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? nameAr,
    String? email,
    String? address,
    DateTime? birthdate,
    String? gender,
    String? generation,
    String? medicalNotes,
    String? allergies,
    List<Role>? roles,
    List<RoleAssignment>? roleAssignments,
    DateTime? updatedAt,
  }) {
    return ManagedUserProfile(
      id: id,
      userId: userId,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      nameAr: nameAr ?? this.nameAr,
      email: email ?? this.email,
      phone: phone,
      address: address ?? this.address,
      birthdate: birthdate ?? this.birthdate,
      gender: gender ?? this.gender,
      generation: generation ?? this.generation,
      scoutOrgId: scoutOrgId,
      scoutCode: scoutCode,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      allergies: allergies ?? this.allergies,
      signupTroopId: signupTroopId,
      signupTroopName: signupTroopName,
      roles: roles ?? this.roles,
      roleAssignments: roleAssignments ?? this.roleAssignments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
