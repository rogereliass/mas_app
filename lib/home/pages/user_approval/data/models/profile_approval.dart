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
    String? approverName;
    if (json['approver'] != null && json['approver'] is Map) {
      final approver = json['approver'] as Map<String, dynamic>;
      final firstName = approver['first_name'] as String?;
      final lastName = approver['last_name'] as String?;
      if (firstName != null && lastName != null) {
        approverName = '$firstName $lastName';
      }
    }

    return ProfileApproval(
      id: json['id'] as int,
      profileId: json['profile_id'] as String,
      approvedBy: json['approved_by'] as String?,
      approvedByName: approverName,
      comments: json['comments'] as String?,
      status: json['status'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
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
