import 'notification_models.dart';

class NotificationAuditEntry {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final String? createdByProfileId;
  final String? senderName;
  final NotificationTargetType targetType;
  final String? targetId;
  final String? targetLabel;
  final int recipientCount;
  final Map<String, dynamic> data;

  const NotificationAuditEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.createdByProfileId,
    required this.senderName,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.recipientCount,
    required this.data,
  });
}
