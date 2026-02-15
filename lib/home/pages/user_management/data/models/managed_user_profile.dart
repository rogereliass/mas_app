import '../../../../../auth/models/role.dart';

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
    required this.createdAt,
    this.updatedAt,
  });

  String get fullName {
    final parts = [firstName, middleName, lastName]
        .where((part) => part != null && part.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : 'Unnamed User';
  }

  Role? get primaryRole {
    if (roles.isEmpty) return null;
    final sorted = [...roles]..sort((a, b) => b.rank.compareTo(a.rank));
    return sorted.first;
  }

  factory ManagedUserProfile.fromJson(Map<String, dynamic> json) {
    final rolesJson = json['profile_roles'] as List<dynamic>? ?? [];
    final parsedRoles = rolesJson
        .map((entry) => entry['roles'] as Map<String, dynamic>?)
        .where((role) => role != null)
        .map((role) => Role.fromJson(role!))
        .toList();

    return ManagedUserProfile(
      id: json['id'] as String,
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
      generation: json['generation'] as String?,
      scoutOrgId: json['scout_org_id'] as String?,
      scoutCode: json['scout_code'] as String?,
      medicalNotes: json['medical_notes'] as String?,
      allergies: json['allergies'] as String?,
      signupTroopId: json['signup_troop'] as String?,
      signupTroopName: json['troops'] != null && json['troops'] is Map
          ? json['troops']['name'] as String?
          : null,
      roles: parsedRoles,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
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
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
