/// Role model representing user role in the system
///
/// Roles determine access levels throughout the app
/// Database schema: id, name, slug, description, role_rank, created_at
class Role {
  final String id;
  final String name;
  final String? slug;
  final String? description;
  final int rank;
  final DateTime createdAt;

  const Role({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    required this.rank,
    required this.createdAt,
  });

  /// Create Role from Supabase JSON
  /// Maps role_rank from database to rank property
  factory Role.fromJson(Map<String, dynamic> json) {
    // Defensive null checks for required fields
    final id = json['id'];
    final name = json['name'];
    final createdAt = json['created_at'];

    if (id == null || id is! String || id.isEmpty) {
      throw ArgumentError('Role id is required but was null or invalid: $id');
    }
    if (name == null || name is! String || name.isEmpty) {
      throw ArgumentError('Role name is required but was null or invalid: $name');
    }
    if (createdAt == null || createdAt is! String || createdAt.isEmpty) {
      throw ArgumentError('Role created_at is required but was null or invalid: $createdAt');
    }

    return Role(
      id: id,
      name: name,
      slug: json['slug'] as String?,
      description: json['description'] as String?,
      rank: json['role_rank'] as int? ?? json['rank'] as int? ?? 0, // Support both field names
      createdAt: DateTime.parse(createdAt),
    );
  }

  /// Convert Role to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'role_rank': rank, // Use role_rank for database
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
  String toString() => 'Role{id: $id, name: $name, slug: $slug, rank: $rank}';
}
