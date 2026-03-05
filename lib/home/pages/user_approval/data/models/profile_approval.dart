/// Model representing a profile approval/rejection record
///
/// Corresponds to the profiles_approvals table
class ProfileApproval {
  final int id;
  final String profileId;
  final String? approvedBy;
  final String? approvedByName;
  final String? comments;
  final bool status;
  final DateTime createdAt;

  const ProfileApproval({
    required this.id,
    required this.profileId,
    this.approvedBy,
    this.approvedByName,
    this.comments,
    required this.status,
    required this.createdAt,
  });

  /// Status label for display
  String get statusLabel => status ? 'Accepted' : 'Rejected';

  /// Create ProfileApproval from Supabase JSON
  /// Expects joined data with approver profile
  factory ProfileApproval.fromJson(Map<String, dynamic> json) {
    String? asString(dynamic value) => value is String ? value : null;
    DateTime? asDateTime(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    String? approverName;
    if (json['approver'] != null && json['approver'] is Map) {
      final approver = json['approver'] as Map<String, dynamic>;
      final firstName = asString(approver['first_name']);
      final lastName = asString(approver['last_name']);
      if (firstName != null && lastName != null) {
        approverName = '$firstName $lastName';
      }
    }

    final idValue = json['id'];
    final parsedId = idValue is int
        ? idValue
        : int.tryParse('${idValue ?? ''}');
    final profileId = asString(json['profile_id']);
    final createdAt = asDateTime(json['created_at']);

    if (parsedId == null) {
      throw ArgumentError(
        'ProfileApproval id is required but was null or invalid',
      );
    }
    if (profileId == null || profileId.isEmpty) {
      throw ArgumentError(
        'ProfileApproval profile_id is required but was null or invalid',
      );
    }
    if (createdAt == null) {
      throw ArgumentError(
        'ProfileApproval created_at is required but was null or invalid',
      );
    }

    return ProfileApproval(
      id: parsedId,
      profileId: profileId,
      approvedBy: asString(json['approved_by']),
      approvedByName: approverName,
      comments: asString(json['comments']),
      status: json['status'] as bool,
      createdAt: createdAt,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'approved_by': approvedBy,
      'comments': comments,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'ProfileApproval{id: $id, profileId: $profileId, status: $statusLabel}';
}
