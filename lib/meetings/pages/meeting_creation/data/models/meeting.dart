import 'package:intl/intl.dart';

/// Immutable model representing a row in the `meetings` table.
class Meeting {
  final String id;
  final String? troopId;
  final String? seasonId;
  final String title;
  final String? description;
  final String? location;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? createdByProfileId;
  final bool isTemplate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Corresponds to the `meeting_date` (date) column — required.
  final DateTime meetingDate;

  const Meeting({
    required this.id,
    this.troopId,
    this.seasonId,
    required this.title,
    this.description,
    this.location,
    this.startsAt,
    this.endsAt,
    this.createdByProfileId,
    this.isTemplate = false,
    this.createdAt,
    this.updatedAt,
    required this.meetingDate,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] as String,
      troopId: json['troop_id'] as String?,
      seasonId: json['season_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? ''),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      createdByProfileId: json['created_by_profile_id'] as String?,
      isTemplate: json['is_template'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      meetingDate: DateTime.parse(json['meeting_date'] as String),
    );
  }

  Meeting copyWith({
    String? id,
    String? troopId,
    String? seasonId,
    String? title,
    String? description,
    String? location,
    DateTime? startsAt,
    DateTime? endsAt,
    String? createdByProfileId,
    bool? isTemplate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? meetingDate,
  }) {
    return Meeting(
      id: id ?? this.id,
      troopId: troopId ?? this.troopId,
      seasonId: seasonId ?? this.seasonId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      createdByProfileId: createdByProfileId ?? this.createdByProfileId,
      isTemplate: isTemplate ?? this.isTemplate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      meetingDate: meetingDate ?? this.meetingDate,
    );
  }

  /// Returns the meeting date formatted as e.g. `'Jan 5, 2025'`.
  String get formattedDate => DateFormat('MMM d, yyyy').format(meetingDate);

  /// Returns a time range string like `'18:00 – 20:00'`, or `''` if either
  /// [startsAt] or [endsAt] is null.
  String get formattedTimeRange {
    if (startsAt == null || endsAt == null) return '';
    final fmt = DateFormat('HH:mm');
    return '${fmt.format(startsAt!)} \u2013 ${fmt.format(endsAt!)}';
  }

  @override
  String toString() => 'Meeting(id: $id, title: $title, meetingDate: $meetingDate)';
}
