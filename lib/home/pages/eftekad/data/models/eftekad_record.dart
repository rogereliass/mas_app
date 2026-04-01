enum EftekadRecordType { call, inPerson, message, other }

extension EftekadRecordTypeX on EftekadRecordType {
  String get dbValue {
    switch (this) {
      case EftekadRecordType.call:
        return 'call';
      case EftekadRecordType.inPerson:
        return 'in_person';
      case EftekadRecordType.message:
        return 'message';
      case EftekadRecordType.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case EftekadRecordType.call:
        return 'Call';
      case EftekadRecordType.inPerson:
        return 'In person';
      case EftekadRecordType.message:
        return 'Message';
      case EftekadRecordType.other:
        return 'Other';
    }
  }

  static EftekadRecordType fromDbValue(String raw) {
    switch (raw) {
      case 'call':
        return EftekadRecordType.call;
      case 'in_person':
        return EftekadRecordType.inPerson;
      case 'message':
        return EftekadRecordType.message;
      case 'other':
      default:
        return EftekadRecordType.other;
    }
  }
}

class EftekadRecord {
  const EftekadRecord({
    required this.id,
    required this.profileId,
    required this.createdByProfileId,
    required this.createdAt,
    required this.type,
    required this.reason,
    required this.notes,
    this.updatedAt,
    this.outcome,
    this.nextFollowUpDate,
  });

  final String id;
  final String profileId;
  final String createdByProfileId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final EftekadRecordType type;
  final String reason;
  final String notes;
  final String? outcome;
  final DateTime? nextFollowUpDate;

  factory EftekadRecord.fromJson(Map<String, dynamic> json) {
    return EftekadRecord(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      createdByProfileId: json['created_by_profile_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      type: EftekadRecordTypeX.fromDbValue(
        (json['type'] as String?) ?? 'other',
      ),
      reason: (json['reason'] as String?)?.trim() ?? '',
      notes: (json['notes'] as String?)?.trim() ?? '',
      outcome: (json['outcome'] as String?)?.trim(),
      nextFollowUpDate: json['next_follow_up_date'] != null
          ? DateTime.tryParse(json['next_follow_up_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'id': id,
      'profile_id': profileId,
      'created_by_profile_id': createdByProfileId,
      'created_at': createdAt.toIso8601String(),
      'type': type.dbValue,
      'reason': reason,
      'notes': notes,
      'outcome': outcome,
      'next_follow_up_date': nextFollowUpDate?.toIso8601String(),
    };
  }

  Map<String, dynamic> toQueuePayload() {
    return <String, dynamic>{
      'id': id,
      'profileId': profileId,
      'createdByProfileId': createdByProfileId,
      'createdAt': createdAt.toIso8601String(),
      'type': type.dbValue,
      'reason': reason,
      'notes': notes,
      'outcome': outcome,
      'nextFollowUpDate': nextFollowUpDate?.toIso8601String(),
    };
  }

  factory EftekadRecord.fromQueuePayload(Map<String, dynamic> payload) {
    return EftekadRecord(
      id: payload['id'] as String,
      profileId: payload['profileId'] as String,
      createdByProfileId: payload['createdByProfileId'] as String,
      createdAt: DateTime.parse(payload['createdAt'] as String),
      type: EftekadRecordTypeX.fromDbValue(payload['type'] as String),
      reason: (payload['reason'] as String?)?.trim() ?? '',
      notes: (payload['notes'] as String?)?.trim() ?? '',
      outcome: (payload['outcome'] as String?)?.trim(),
      nextFollowUpDate: payload['nextFollowUpDate'] != null
          ? DateTime.tryParse(payload['nextFollowUpDate'] as String)
          : null,
    );
  }
}
