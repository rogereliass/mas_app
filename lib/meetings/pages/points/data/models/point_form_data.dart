/// Form payload for creating or editing a meeting point entry.
class PointFormData {
  final String patrolId;
  final String categoryId;
  final int value;
  final String? reason;

  const PointFormData({
    required this.patrolId,
    required this.categoryId,
    required this.value,
    this.reason,
  });

  PointFormData copyWith({
    String? patrolId,
    String? categoryId,
    int? value,
    String? reason,
  }) {
    return PointFormData(
      patrolId: patrolId ?? this.patrolId,
      categoryId: categoryId ?? this.categoryId,
      value: value ?? this.value,
      reason: reason ?? this.reason,
    );
  }
}
