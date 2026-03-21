import '../../../../auth/models/user_profile.dart';
import 'models/notification_models.dart';
import 'notification_service.dart';

class NotificationPanelData {
  final List<NotificationRecipientEntry> notifications;
  final int unreadCount;

  const NotificationPanelData({
    required this.notifications,
    required this.unreadCount,
  });
}

class NotificationRepository {
  NotificationRepository({NotificationService? service})
      : _service = service ?? NotificationService.instance();

  final NotificationService _service;

  bool canUserSendNotifications(int roleRank) {
    return roleRank >= 90 || roleRank == 60 || roleRank == 70;
  }

  Future<NotificationPanelData> fetchPanelData({
    required String profileId,
    int limit = 50,
  }) async {
    final result = await Future.wait<dynamic>([
      _service.fetchNotificationsForProfile(profileId: profileId, limit: limit),
      _service.fetchUnreadCount(profileId: profileId),
    ]);

    return NotificationPanelData(
      notifications: result[0] as List<NotificationRecipientEntry>,
      unreadCount: result[1] as int,
    );
  }

  Future<void> markNotificationRead({required String recipientId}) {
    return _service.markRecipientRead(recipientId: recipientId);
  }

  Future<void> markAllRead({required String profileId}) {
    return _service.markAllRead(profileId: profileId);
  }

  Future<NotificationCreateResult> sendNotification({
    required UserProfile senderProfile,
    required int senderRoleRank,
    required NotificationCreateRequest request,
  }) async {
    if (!canUserSendNotifications(senderRoleRank)) {
      throw Exception('You do not have permission to send notifications.');
    }

    final title = request.title.trim();
    final body = request.body.trim();
    if (title.isEmpty || body.isEmpty) {
      throw Exception('Title and body are required.');
    }

    final activeSeason = await _service.fetchActiveSeason();
    final seasonId = activeSeason?['id'] as String?;
    if (seasonId == null || seasonId.trim().isEmpty) {
      throw Exception('No active season found. Please create or activate a season first.');
    }

    final senderTroopId =
        (senderProfile.managedTroopId ?? senderProfile.signupTroopId)?.trim();
    final normalizedTargetId = _normalizeTargetId(
      targetType: request.targetType,
      targetId: request.targetId,
      senderRoleRank: senderRoleRank,
      senderTroopId: senderTroopId,
    );

    final normalizedRoleTroopId = request.roleTroopId?.trim();
    final normalizedData = <String, dynamic>{...request.data};
    if (request.targetType == NotificationTargetType.role &&
        normalizedRoleTroopId != null &&
        normalizedRoleTroopId.isNotEmpty) {
      normalizedData['role_troop_id'] = normalizedRoleTroopId;
    }

    final normalizedRequest = NotificationCreateRequest(
      title: title,
      body: body,
      type: request.type,
      targetType: request.targetType,
      targetId: normalizedTargetId,
      roleTroopId: normalizedRoleTroopId,
      data: normalizedData,
    );

    if (normalizedRequest.targetType != NotificationTargetType.all &&
        (normalizedRequest.targetId == null ||
            normalizedRequest.targetId!.trim().isEmpty)) {
      throw Exception('Please select a valid target.');
    }

    if ((senderRoleRank == 60 || senderRoleRank == 70) &&
        normalizedRequest.targetType != NotificationTargetType.troop &&
        normalizedRequest.targetType != NotificationTargetType.all &&
        normalizedRequest.targetId != null &&
        senderTroopId != null) {
      final isInScope = await _service.validateScopedTarget(
        targetType: normalizedRequest.targetType,
        targetId: normalizedRequest.targetId!,
        senderTroopId: senderTroopId,
      );
      if (!isInScope) {
        throw Exception('Selected target is outside your troop scope.');
      }
    }

    final notificationId = await _service.createNotificationRow(
      createdByProfileId: senderProfile.id,
      seasonId: seasonId,
      request: normalizedRequest,
    );

    try {
      final recipients = await _service.resolveRecipientProfileIds(
        targetType: normalizedRequest.targetType,
        targetId: normalizedRequest.targetId,
        roleTroopId: normalizedRequest.roleTroopId,
        senderRoleRank: senderRoleRank,
        senderTroopId: senderTroopId,
      );

      final uniqueRecipients = recipients.toSet().toList();
      if (uniqueRecipients.isEmpty) {
        throw Exception('No recipients matched the selected target.');
      }

      await _service.insertRecipientRows(
        notificationId: notificationId,
        recipientProfileIds: uniqueRecipients,
      );

      // Push fan-out is triggered server-side via DB trigger on notification_recipients.
      return NotificationCreateResult(
        notificationId: notificationId,
        recipientCount: uniqueRecipients.length,
      );
    } catch (e) {
      await _service.deleteNotificationById(notificationId);
      rethrow;
    }
  }

  Future<List<NotificationTargetOption>> fetchTroopTargets({
    required int senderRoleRank,
    required String? senderTroopId,
  }) async {
    if (senderRoleRank >= 90) {
      return _service.fetchTroopTargetOptions();
    }

    if (senderRoleRank == 60 || senderRoleRank == 70) {
      if (senderTroopId == null || senderTroopId.isEmpty) {
        return const <NotificationTargetOption>[];
      }
      final option = await _service.fetchTroopTargetOptionById(
        troopId: senderTroopId,
      );
      if (option == null) {
        return const <NotificationTargetOption>[];
      }
      return <NotificationTargetOption>[option];
    }

    return const <NotificationTargetOption>[];
  }

  Future<List<NotificationTargetOption>> fetchPatrolTargets({
    required int senderRoleRank,
    required String? senderTroopId,
    String? troopId,
  }) async {
    final resolvedTroopId = _resolveComposeTroopId(
      senderRoleRank: senderRoleRank,
      senderTroopId: senderTroopId,
      requestedTroopId: troopId,
    );
    if (resolvedTroopId == null || resolvedTroopId.isEmpty) {
      return const <NotificationTargetOption>[];
    }

    return _service.fetchPatrolTargetOptions(troopId: resolvedTroopId);
  }

  Future<List<NotificationTargetOption>> fetchIndividualTargets({
    required int senderRoleRank,
    required String? senderTroopId,
    String? troopId,
  }) async {
    final resolvedTroopId = _resolveComposeTroopId(
      senderRoleRank: senderRoleRank,
      senderTroopId: senderTroopId,
      requestedTroopId: troopId,
    );
    if (resolvedTroopId == null || resolvedTroopId.isEmpty) {
      return const <NotificationTargetOption>[];
    }

    return _service.fetchIndividualTargetOptions(troopId: resolvedTroopId);
  }

  Future<List<NotificationTargetOption>> fetchRoleTargets({
    required int senderRoleRank,
  }) async {
    // Only system admins (rank >= 90) can send notifications by role
    if (senderRoleRank < 90) {
      return const <NotificationTargetOption>[];
    }

    return _service.fetchRoleTargetOptions();
  }

  Future<int> cleanupSeasonNotifications(String seasonId) {
    return _service.cleanupSeasonNotifications(seasonId: seasonId);
  }

  String? _normalizeTargetId({
    required NotificationTargetType targetType,
    required String? targetId,
    required int senderRoleRank,
    required String? senderTroopId,
  }) {
    if (targetType == NotificationTargetType.all) {
      return null;
    }

    final trimmed = targetId?.trim();
    if (targetType == NotificationTargetType.troop &&
        (senderRoleRank == 60 || senderRoleRank == 70)) {
      return senderTroopId;
    }

    return trimmed;
  }

  String? _resolveComposeTroopId({
    required int senderRoleRank,
    required String? senderTroopId,
    required String? requestedTroopId,
  }) {
    if (senderRoleRank >= 90) {
      return requestedTroopId?.trim();
    }

    if (senderRoleRank == 60 || senderRoleRank == 70) {
      return senderTroopId?.trim();
    }

    return null;
  }
}
