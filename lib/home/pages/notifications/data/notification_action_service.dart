import '../../../../auth/data/role_repository.dart';
import '../../../../auth/models/user_profile.dart';
import 'models/notification_models.dart';
import 'notification_repository.dart';

typedef NotificationSendCallback = Future<NotificationCreateResult> Function({
  required UserProfile senderProfile,
  required int senderRoleRank,
  required NotificationCreateRequest request,
});

/// Public API for sending notifications from anywhere in the app.
///
/// This service wraps existing notification creation logic in NotificationRepository
/// so you can send by audience without duplicating data-layer behavior.
class NotificationActionService {
  NotificationActionService({
    NotificationRepository? notificationRepository,
    RoleRepository? roleRepository,
    Future<UserProfile?> Function()? currentUserProfileLoader,
    NotificationSendCallback? sendNotification,
  })  : _notificationRepository = notificationRepository,
        _roleRepository = roleRepository,
        _currentUserProfileLoader = currentUserProfileLoader,
        _sendNotification = sendNotification;

  static NotificationActionService? _instance;

  /// Returns a singleton instance for app-wide reuse.
  factory NotificationActionService.instance() {
    return _instance ??= NotificationActionService();
  }

  final NotificationRepository? _notificationRepository;
  final RoleRepository? _roleRepository;
  final Future<UserProfile?> Function()? _currentUserProfileLoader;
  final NotificationSendCallback? _sendNotification;

  /// Sends a notification to all users in the system.
  ///
  /// Use this for global announcements that should reach every approved user.
  ///
  /// Parameters:
  /// - title: notification title shown to users.
  /// - body: main message content.
  /// - type: notification category (for example: system, announcement, meeting).
  /// - data: optional deep-link metadata payload used when notification is tapped.
  ///
  /// Example:
  /// ```dart
  /// await NotificationActionService.instance().sendToAll(
  ///   title: 'System Maintenance',
  ///   body: 'The app will be read-only tonight from 11 PM.',
  ///   type: 'announcement',
  ///   data: {'type': 'announcement'},
  /// );
  /// ```
  Future<NotificationCreateResult> sendToAll({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    return _send(
      title: title,
      body: body,
      type: type,
      targetType: NotificationTargetType.all,
      targetId: null,
      data: data,
    );
  }

  /// Sends a notification to all members of a specific troop.
  ///
  /// Use this when the message should reach everyone inside one troop.
  ///
  /// Parameters:
  /// - troopId: target troop identifier.
  /// - title: notification title shown to users.
  /// - body: main message content.
  /// - type: notification category (for example: meeting, attendance).
  /// - data: optional deep-link metadata payload.
  ///
  /// Example:
  /// ```dart
  /// await NotificationActionService.instance().sendToTroop(
  ///   troopId: selectedTroopId,
  ///   title: 'Troop Meeting',
  ///   body: 'Meeting starts at 7 PM in the main hall.',
  ///   type: 'meeting',
  ///   data: {'type': 'meeting', 'meeting_id': meetingId},
  /// );
  /// ```
  Future<NotificationCreateResult> sendToTroop({
    required String troopId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    _validateId(troopId, fieldName: 'troopId');

    return _send(
      title: title,
      body: body,
      type: type,
      targetType: NotificationTargetType.troop,
      targetId: troopId.trim(),
      data: data,
    );
  }

  /// Sends a notification to a specific patrol.
  ///
  /// Use this for patrol-scoped updates like attendance reminders.
  ///
  /// Parameters:
  /// - patrolId: target patrol identifier.
  /// - title: notification title shown to users.
  /// - body: main message content.
  /// - type: notification category (for example: attendance, points).
  /// - data: optional deep-link metadata payload.
  ///
  /// Example:
  /// ```dart
  /// await NotificationActionService.instance().sendToPatrol(
  ///   patrolId: patrol.id,
  ///   title: 'Attendance Reminder',
  ///   body: 'Please confirm attendance before 6 PM.',
  ///   type: 'attendance',
  ///   data: {'type': 'attendance', 'meeting_id': meetingId},
  /// );
  /// ```
  Future<NotificationCreateResult> sendToPatrol({
    required String patrolId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    _validateId(patrolId, fieldName: 'patrolId');

    return _send(
      title: title,
      body: body,
      type: type,
      targetType: NotificationTargetType.patrol,
      targetId: patrolId.trim(),
      data: data,
    );
  }

  /// Sends a notification to a single user profile.
  ///
  /// Use this for direct communication to one member.
  ///
  /// Parameters:
  /// - profileId: target profile identifier.
  /// - title: notification title shown to the user.
  /// - body: main message content.
  /// - type: notification category.
  /// - data: optional deep-link metadata payload.
  ///
  /// Example:
  /// ```dart
  /// await NotificationActionService.instance().sendToUser(
  ///   profileId: member.profileId,
  ///   title: 'Profile Update',
  ///   body: 'Your role assignment was updated.',
  ///   type: 'system',
  ///   data: {'type': 'profile'},
  /// );
  /// ```
  Future<NotificationCreateResult> sendToUser({
    required String profileId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    _validateId(profileId, fieldName: 'profileId');

    return _send(
      title: title,
      body: body,
      type: type,
      targetType: NotificationTargetType.individual,
      targetId: profileId.trim(),
      data: data,
    );
  }

  /// Sends a notification to all users who have a specific role.
  ///
  /// If troopId is provided, only users with this role inside that troop
  /// will be targeted.
  ///
  /// Parameters:
  /// - roleName: role key/slug, for example system_admin or troop_leader.
  /// - troopId: optional troop identifier to scope recipients.
  /// - title: notification title shown to users.
  /// - body: main message content.
  /// - type: notification category.
  /// - data: optional deep-link metadata payload.
  ///
  /// Example:
  /// ```dart
  /// await NotificationActionService.instance().sendToRole(
  ///   roleName: 'troop_leader',
  ///   troopId: selectedTroopId,
  ///   title: 'New Meeting',
  ///   body: 'A new meeting has been scheduled',
  ///   type: 'meeting',
  ///   data: {'type': 'meeting', 'meeting_id': meetingId},
  /// );
  /// ```
  Future<NotificationCreateResult> sendToRole({
    required String roleName,
    String? troopId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final normalizedRoleName = _normalizeRoleName(roleName);
    final normalizedTroopId = troopId?.trim();
    if (normalizedTroopId != null && normalizedTroopId.isNotEmpty) {
      _validateId(normalizedTroopId, fieldName: 'troopId');
    }

    return _send(
      title: title,
      body: body,
      type: type,
      targetType: NotificationTargetType.role,
      targetId: normalizedRoleName,
      roleTroopId: normalizedTroopId,
      data: data,
    );
  }

  /// Internal shared sender that forwards validated payloads to NotificationRepository.
  ///
  /// This guarantees all wrapper methods use the same creation pipeline.
  Future<NotificationCreateResult> _send({
    required String title,
    required String body,
    required String type,
    required NotificationTargetType targetType,
    required String? targetId,
    String? roleTroopId,
    Map<String, dynamic>? data,
  }) async {
    final senderContext = await _resolveSenderContext();

    final request = NotificationCreateRequest(
      title: title.trim(),
      body: body.trim(),
      type: _parseType(type),
      targetType: targetType,
      targetId: targetId,
      roleTroopId: roleTroopId,
      data: Map<String, dynamic>.from(data ?? const <String, dynamic>{}),
    );

    final sender = _sendNotification ??
        _notificationRepository?.sendNotification ??
        NotificationRepository().sendNotification;

    return sender(
      senderProfile: senderContext.profile,
      senderRoleRank: senderContext.senderRoleRank,
      request: request,
    );
  }

  /// Resolves the active sender profile and effective sender rank.
  ///
  /// Throws when no authenticated profile is available.
  Future<_SenderContext> _resolveSenderContext() async {
    final profileLoader = _currentUserProfileLoader ??
        _roleRepository?.getCurrentUserProfile ??
        RoleRepository().getCurrentUserProfile;
    final profile = await profileLoader();
    if (profile == null) {
      throw Exception('You must be signed in to send notifications.');
    }

    return _SenderContext(
      profile: profile,
      senderRoleRank: profile.roleRank,
    );
  }

  /// Converts a raw type string to NotificationType with strict allow-list validation.
  NotificationType _parseType(String type) {
    final normalized = type.trim().toLowerCase();
    const supported = <String>{
      'system',
      'announcement',
      'meeting',
      'attendance',
      'points',
    };

    if (!supported.contains(normalized)) {
      throw ArgumentError.value(
        type,
        'type',
        'Unsupported notification type. Supported: ${supported.join(', ')}',
      );
    }

    return NotificationTypeX.fromValue(normalized);
  }

  /// Validates that a required identifier field is not blank.
  void _validateId(String value, {required String fieldName}) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required.');
    }
  }

  /// Normalizes role name input to canonical slug style.
  String _normalizeRoleName(String roleName) {
    final normalized = roleName.trim().toLowerCase().replaceAll(' ', '_');
    if (normalized.isEmpty) {
      throw ArgumentError.value(roleName, 'roleName', 'roleName is required.');
    }
    return normalized;
  }
}

class _SenderContext {
  const _SenderContext({
    required this.profile,
    required this.senderRoleRank,
  });

  final UserProfile profile;
  final int senderRoleRank;
}
