class EftekadMember {
  const EftekadMember({
    required this.id,
    required this.troopId,
    this.firstName,
    this.middleName,
    this.lastName,
    this.phone,
    this.address,
    this.patrolId,
    this.patrolName,
    required this.approved,
    required this.patrolOrderPriority,
  });

  final String id;
  final String troopId;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? phone;
  final String? address;
  final String? patrolId;
  final String? patrolName;
  final bool approved;
  final int patrolOrderPriority;

  String get fullName {
    final parts = [firstName, middleName, lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'Unnamed Member';
    }
    return parts.join(' ');
  }

  String get normalizedPhone => (phone ?? '').replaceAll(' ', '').trim();
}
