/// Model representing a user profile pending approval
///
/// Contains all profile information needed for admin review
class PendingProfile {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? nameAr;
  final String? scoutOrgId;
  final String? scoutCode;
  final DateTime? birthdate;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String? gender;
  final String? generation;
  final String? address;
  final String? medicalNotes;
  final String? allergies;
  final String? signupTroopId;
  final String? signupTroopName;
  final bool signupCompleted;
  final bool approved;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PendingProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.nameAr,
    this.scoutOrgId,
    this.scoutCode,
    this.birthdate,
    this.phone,
    this.email,
    this.photoUrl,
    this.gender,
    this.generation,
    this.address,
    this.medicalNotes,
    this.allergies,
    this.signupTroopId,
    this.signupTroopName,
    required this.signupCompleted,
    required this.approved,
    required this.createdAt,
    this.updatedAt,
  });

  /// Get full name
  String get fullName {
    final parts = [
      firstName,
      middleName,
      lastName,
    ].where((part) => part != null && part.isNotEmpty);
    return parts.join(' ');
  }

  /// Calculate age from birthdate
  int? get age {
    if (birthdate == null) return null;
    final today = DateTime.now();
    int age = today.year - birthdate!.year;
    if (today.month < birthdate!.month ||
        (today.month == birthdate!.month && today.day < birthdate!.day)) {
      age--;
    }
    return age;
  }

  /// Create PendingProfile from Supabase JSON
  /// Expects joined data with troops table
  factory PendingProfile.fromJson(Map<String, dynamic> json) {
    String? asString(dynamic value) => value is String ? value : null;
    DateTime? asDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final id = asString(json['id']);
    final createdAt = asDateTime(json['created_at']);
    if (id == null || id.isEmpty) {
      throw ArgumentError(
        'PendingProfile id is required but was null or invalid',
      );
    }
    if (createdAt == null) {
      throw ArgumentError(
        'PendingProfile created_at is required but was null or invalid',
      );
    }

    return PendingProfile(
      id: id,
      userId: asString(json['user_id']) ?? '',
      firstName: asString(json['first_name']) ?? 'Unknown',
      lastName: asString(json['last_name']) ?? '',
      middleName: asString(json['middle_name']),
      nameAr: asString(json['name_ar']),
      scoutOrgId: asString(json['scout_org_id']),
      scoutCode: asString(json['scout_code']),
      birthdate: asDateTime(json['birthdate']),
      phone: asString(json['phone']),
      email: asString(json['email']),
      photoUrl: asString(json['photo_url']),
      gender: asString(json['gender']),
      generation: asString(json['generation']),
      address: asString(json['address']),
      medicalNotes: asString(json['medical_notes']),
      allergies: asString(json['allergies']),
      signupTroopId: asString(json['signup_troop']),
      signupTroopName: json['troops'] != null && json['troops'] is Map
          ? asString(json['troops']['name'])
          : null,
      signupCompleted: json['signup_completed'] as bool? ?? false,
      approved: json['approved'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'name_ar': nameAr,
      'scout_org_id': scoutOrgId,
      'scout_code': scoutCode,
      'birthdate': birthdate?.toIso8601String().split('T')[0],
      'phone': phone,
      'email': email,
      'photo_url': photoUrl,
      'gender': gender,
      'generation': generation,
      'address': address,
      'medical_notes': medicalNotes,
      'allergies': allergies,
      'signup_troop': signupTroopId,
      'signup_completed': signupCompleted,
      'approved': approved,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create copy with updated fields
  PendingProfile copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? middleName,
    String? nameAr,
    String? scoutOrgId,
    String? scoutCode,
    DateTime? birthdate,
    String? phone,
    String? email,
    String? photoUrl,
    String? gender,
    String? generation,
    String? address,
    String? medicalNotes,
    String? allergies,
    String? signupTroopId,
    String? signupTroopName,
    bool? signupCompleted,
    bool? approved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PendingProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      nameAr: nameAr ?? this.nameAr,
      scoutOrgId: scoutOrgId ?? this.scoutOrgId,
      scoutCode: scoutCode ?? this.scoutCode,
      birthdate: birthdate ?? this.birthdate,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      generation: generation ?? this.generation,
      address: address ?? this.address,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      allergies: allergies ?? this.allergies,
      signupTroopId: signupTroopId ?? this.signupTroopId,
      signupTroopName: signupTroopName ?? this.signupTroopName,
      signupCompleted: signupCompleted ?? this.signupCompleted,
      approved: approved ?? this.approved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'PendingProfile{id: $id, fullName: $fullName, approved: $approved}';
}
