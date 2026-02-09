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
    final parts = [firstName, middleName, lastName]
        .where((part) => part != null && part.isNotEmpty);
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
    return PendingProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      middleName: json['middle_name'] as String?,
      nameAr: json['name_ar'] as String?,
      scoutOrgId: json['scout_org_id'] as String?,
      scoutCode: json['scout_code'] as String?,
      birthdate: json['birthdate'] != null
          ? DateTime.parse(json['birthdate'] as String)
          : null,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photo_url'] as String?,
      gender: json['gender'] as String?,
      generation: json['generation'] as String?,
      address: json['address'] as String?,
      medicalNotes: json['medical_notes'] as String?,
      allergies: json['allergies'] as String?,
      signupTroopId: json['signup_troop'] as String?,
      signupTroopName: json['troops'] != null && json['troops'] is Map
          ? json['troops']['name'] as String?
          : null,
      signupCompleted: json['signup_completed'] as bool? ?? false,
      approved: json['approved'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
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
