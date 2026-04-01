class TroopMember {
  final String id;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? phone;
  final String? address;
  final String? scoutCode;
  final String? addressMaps;
  final bool approved;
  final String troopId;
  final String? patrolId;

  const TroopMember({
    required this.id,
    this.firstName,
    this.middleName,
    this.lastName,
    this.phone,
    this.address,
    this.scoutCode,
    this.addressMaps,
    this.approved = false,
    required this.troopId,
    this.patrolId,
  });

  String get fullName {
    final parts = [firstName, middleName, lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList();

    if (parts.isEmpty) return 'Unnamed Member';
    return parts.join(' ');
  }

  String get displayPhone {
    final trimmed = phone?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'No phone number';
    }
    return trimmed;
  }

  bool get isAssigned => patrolId != null;

  factory TroopMember.fromJson(Map<String, dynamic> json) {
    return TroopMember(
      id: json['id'] as String,
      firstName: json['first_name'] as String?,
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      scoutCode: json['scout_code'] as String?,
      addressMaps: json['address_maps'] as String?,
      approved: json['approved'] as bool? ?? false,
      troopId: json['signup_troop'] as String? ?? '',
      patrolId: json['patrol_id'] as String?,
    );
  }

  TroopMember copyWith({
    String? patrolId,
    bool clearPatrolId = false,
    String? addressMaps,
    bool clearAddressMaps = false,
  }) {
    return TroopMember(
      id: id,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      phone: phone,
      address: address,
      scoutCode: scoutCode,
      addressMaps: clearAddressMaps ? null : (addressMaps ?? this.addressMaps),
      approved: approved,
      troopId: troopId,
      patrolId: clearPatrolId ? null : (patrolId ?? this.patrolId),
    );
  }
}
