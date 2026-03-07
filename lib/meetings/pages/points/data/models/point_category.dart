/// Point category used to classify meeting points.
class PointCategory {
  final String id;
  final String name;
  final String? slug;
  final String? description;
  final String? troopId;

  const PointCategory({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.troopId,
  });

  bool get isGlobal => troopId == null;

  PointCategory copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? troopId,
  }) {
    return PointCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      troopId: troopId ?? this.troopId,
    );
  }

  factory PointCategory.fromJson(Map<String, dynamic> json) {
    return PointCategory(
      id: json['id'] as String,
      name: (json['name'] as String? ?? '').trim(),
      slug: (json['slug'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      troopId: json['troop_id'] as String?,
    );
  }
}
