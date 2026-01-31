/// Role model representing user role in the system
///
/// Roles determine access levels throughout the app
class Role {
  final String id;
  final String name;
  final String? description;
  final int rank;
  final DateTime createdAt;

  const Role({
    required this.id,
    required this.name,
    this.description,
    required this.rank,
    required this.createdAt,
  });

  /// Create Role from Supabase JSON
  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      rank: json['rank'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert Role to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'rank': rank,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rank == other.rank;

  @override
  int get hashCode => id.hashCode ^ rank.hashCode;

  @override
  String toString() => 'Role{id: $id, name: $name, rank: $rank}';
}
