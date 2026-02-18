class Patrol {
  final String id;
  final String troopId;
  final String name;
  final String? description;
  final String? patrolLeaderProfileId;
  final DateTime createdAt;

  const Patrol({
    required this.id,
    required this.troopId,
    required this.name,
    this.description,
    this.patrolLeaderProfileId,
    required this.createdAt,
  });

  factory Patrol.fromJson(Map<String, dynamic> json) {
    return Patrol(
      id: json['id'] as String,
      troopId: json['troop_id'] as String,
      name: (json['name'] as String?)?.trim() ?? '',
      description: json['description'] as String?,
      patrolLeaderProfileId: json['patrol_leader_profile_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Patrol copyWith({
    String? name,
    String? description,
    String? patrolLeaderProfileId,
  }) {
    return Patrol(
      id: id,
      troopId: troopId,
      name: name ?? this.name,
      description: description ?? this.description,
      patrolLeaderProfileId: patrolLeaderProfileId ?? this.patrolLeaderProfileId,
      createdAt: createdAt,
    );
  }
}
