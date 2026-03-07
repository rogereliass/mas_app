import 'point_form_data.dart';

/// Immutable model representing one row in the `points` table.
class PointEntry {
  final String id;
  final String meetingId;
  final String patrolId;
  final String categoryId;
  final int value;
  final String? reason;
  final String? awardedByProfileId;
  final DateTime? createdAt;
  final bool approved;

  final String patrolName;
  final String categoryName;
  final String awardedByName;

  const PointEntry({
    required this.id,
    required this.meetingId,
    required this.patrolId,
    required this.categoryId,
    required this.value,
    this.reason,
    this.awardedByProfileId,
    this.createdAt,
    required this.approved,
    required this.patrolName,
    required this.categoryName,
    required this.awardedByName,
  });

  factory PointEntry.fromJson(Map<String, dynamic> json) {
    final patrol = _asMap(json['patrol']);
    final category = _asMap(json['category']);
    final awardedBy = _asMap(json['awarded_by']);

    return PointEntry(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      patrolId:
          (json['patrol_id'] as String?) ?? (patrol?['id'] as String? ?? ''),
      categoryId:
          (json['category_id'] as String?) ??
          (category?['id'] as String? ?? ''),
      value: _parseInt(json['value']),
      reason: _normalizeReason(json['reason'] as String?),
      awardedByProfileId:
          (json['awarded_by_profile_id'] as String?) ??
          (awardedBy?['id'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      approved: json['approved'] as bool? ?? false,
      patrolName: (patrol?['name'] as String?)?.trim().isNotEmpty == true
          ? (patrol!['name'] as String).trim()
          : ((json['patrol_name'] as String?)?.trim().isNotEmpty == true
                ? (json['patrol_name'] as String).trim()
                : 'Unknown Patrol'),
      categoryName: (category?['name'] as String?)?.trim().isNotEmpty == true
          ? (category!['name'] as String).trim()
          : ((json['category_name'] as String?)?.trim().isNotEmpty == true
                ? (json['category_name'] as String).trim()
                : 'Uncategorized'),
      awardedByName:
          _buildFullName(
            firstName: awardedBy?['first_name'] as String?,
            middleName: awardedBy?['middle_name'] as String?,
            lastName: awardedBy?['last_name'] as String?,
          ) ??
          ((json['awarded_by_name'] as String?)?.trim().isNotEmpty == true
              ? (json['awarded_by_name'] as String).trim()
              : 'Unknown'),
    );
  }

  PointFormData toFormData() {
    return PointFormData(
      patrolId: patrolId,
      categoryId: categoryId,
      value: value,
      reason: reason,
    );
  }

  DateTime get sortTimestamp => createdAt ?? DateTime(1970);

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _normalizeReason(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String? _buildFullName({
    required String? firstName,
    required String? middleName,
    required String? lastName,
  }) {
    final parts = [firstName, middleName, lastName]
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }
}
