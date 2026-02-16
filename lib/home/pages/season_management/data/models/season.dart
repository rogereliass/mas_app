/// Season model representing a training or activity season
///
/// Database schema: id, season_code, name, start_date, end_date, created_at
class Season {
  final String id;
  final String seasonCode; // Format: Year-Season (e.g., 2026-F)
  final String? name;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  const Season({
    required this.id,
    required this.seasonCode,
    this.name,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  /// Create Season from Supabase JSON
  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] as String,
      seasonCode: json['season_code'] as String,
      name: json['name'] as String?,
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date'] as String) 
          : null,
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert Season to JSON for database operations
  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'season_code': seasonCode,
      'name': name,
      'start_date': startDate?.toIso8601String().split('T')[0], // YYYY-MM-DD
      'end_date': endDate?.toIso8601String().split('T')[0],   // YYYY-MM-DD
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Season &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          seasonCode == other.seasonCode;

  @override
  int get hashCode => id.hashCode ^ seasonCode.hashCode;

  @override
  String toString() => 'Season{id: $id, code: $seasonCode, name: $name}';
}
