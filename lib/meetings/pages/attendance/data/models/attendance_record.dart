import 'package:flutter/material.dart';
import 'package:masapp/meetings/pages/meeting_creation/data/models/meeting.dart';

// ---------------------------------------------------------------------------
// AttendanceStatus enum
// ---------------------------------------------------------------------------

enum AttendanceStatus { present, absent, late, excused }

extension AttendanceStatusX on AttendanceStatus {
  /// The lowercase string value stored in the database.
  String get dbValue {
    switch (this) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.late:
        return 'late';
      case AttendanceStatus.excused:
        return 'excused';
    }
  }

  /// Parses a database string into [AttendanceStatus]. Defaults to [AttendanceStatus.absent].
  static AttendanceStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'late':
        return AttendanceStatus.late;
      case 'excused':
        return AttendanceStatus.excused;
      case 'absent':
      default:
        return AttendanceStatus.absent;
    }
  }

  /// Human-readable label for display in the UI.
  String get displayLabel {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.excused:
        return 'Excused';
    }
  }

  /// Icon associated with this attendance status.
  IconData get icon {
    switch (this) {
      case AttendanceStatus.present:
        return Icons.check_circle;
      case AttendanceStatus.absent:
        return Icons.cancel;
      case AttendanceStatus.late:
        return Icons.access_time;
      case AttendanceStatus.excused:
        return Icons.info_outline;
    }
  }
}

// ---------------------------------------------------------------------------
// AttendanceRecord
// ---------------------------------------------------------------------------

/// Immutable model representing a row in the `attendance` table.
class AttendanceRecord {
  final String id;
  final String meetingId;
  final String profileId;
  final AttendanceStatus status;
  final String? markedByProfileId;
  final DateTime? markedAt;
  final String? notes;

  const AttendanceRecord({
    required this.id,
    required this.meetingId,
    required this.profileId,
    required this.status,
    this.markedByProfileId,
    this.markedAt,
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String,
      meetingId: json['meeting_id'] as String,
      profileId: json['profile_id'] as String,
      status: AttendanceStatusX.fromString(json['status'] as String? ?? 'absent'),
      markedByProfileId: json['marked_by_profile_id'] as String?,
      markedAt: DateTime.tryParse(json['marked_at'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }

  AttendanceRecord copyWith({
    String? id,
    String? meetingId,
    String? profileId,
    AttendanceStatus? status,
    String? markedByProfileId,
    DateTime? markedAt,
    String? notes,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      profileId: profileId ?? this.profileId,
      status: status ?? this.status,
      markedByProfileId: markedByProfileId ?? this.markedByProfileId,
      markedAt: markedAt ?? this.markedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() =>
      'AttendanceRecord(id: $id, profileId: $profileId, status: ${status.dbValue})';
}

// ---------------------------------------------------------------------------
// MemberWithAttendance
// ---------------------------------------------------------------------------

/// In-memory helper that combines a troop member's profile data with their
/// current [AttendanceRecord] for a specific meeting. Not persisted directly.
class MemberWithAttendance {
  final String profileId;
  final String displayName;

  /// First letter of first name + first letter of last name, e.g. `'JD'`.
  final String initialsName;

  final String? patrolId;
  final String? patrolName;

  /// The attendance record for this member, or `null` if not yet recorded.
  final AttendanceRecord? record;

  const MemberWithAttendance({
    required this.profileId,
    required this.displayName,
    required this.initialsName,
    this.patrolId,
    this.patrolName,
    this.record,
  });

  MemberWithAttendance copyWith({
    String? profileId,
    String? displayName,
    String? initialsName,
    String? patrolId,
    String? patrolName,
    AttendanceRecord? record,
  }) {
    return MemberWithAttendance(
      profileId: profileId ?? this.profileId,
      displayName: displayName ?? this.displayName,
      initialsName: initialsName ?? this.initialsName,
      patrolId: patrolId ?? this.patrolId,
      patrolName: patrolName ?? this.patrolName,
      record: record ?? this.record,
    );
  }

  @override
  String toString() =>
      'MemberWithAttendance(profileId: $profileId, displayName: $displayName)';
}

// ---------------------------------------------------------------------------
// MyAttendanceLog (For Scout Dashboard)
// ---------------------------------------------------------------------------

class MyAttendanceLog {
  final Meeting meeting;
  final AttendanceRecord? record;

  const MyAttendanceLog({
    required this.meeting,
    this.record,
  });

  bool get isRecorded => record != null;
}
