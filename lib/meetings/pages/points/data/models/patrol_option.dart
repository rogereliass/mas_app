/// Patrol option used by point create/edit dropdowns.
class PatrolOption {
  final String id;
  final String troopId;
  final String name;

  const PatrolOption({
    required this.id,
    required this.troopId,
    required this.name,
  });

  factory PatrolOption.fromJson(Map<String, dynamic> json) {
    return PatrolOption(
      id: json['id'] as String,
      troopId: json['troop_id'] as String,
      name: (json['name'] as String? ?? '').trim(),
    );
  }
}
