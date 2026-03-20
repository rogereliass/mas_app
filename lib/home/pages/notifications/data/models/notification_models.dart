import 'package:flutter/foundation.dart';

enum NotificationType {
  system,
  announcement,
  meeting,
  attendance,
  points,
}

extension NotificationTypeX on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.system:
        return 'system';
      case NotificationType.announcement:
        return 'announcement';
      case NotificationType.meeting:
        return 'meeting';
      case NotificationType.attendance:
        return 'attendance';
      case NotificationType.points:
        return 'points';
    }
  }

  static NotificationType fromValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'announcement':
        return NotificationType.announcement;
      case 'meeting':
        return NotificationType.meeting;
      case 'attendance':
        return NotificationType.attendance;
      case 'points':
        return NotificationType.points;
      case 'system':
      default:
        return NotificationType.system;
    }
  }
}

enum NotificationTargetType {
  all,
  troop,
  patrol,
  individual,
}

extension NotificationTargetTypeX on NotificationTargetType {
  String get value {
    switch (this) {
      case NotificationTargetType.all:
        return 'all';
      case NotificationTargetType.troop:
        return 'troop';
      case NotificationTargetType.patrol:
        return 'patrol';
      case NotificationTargetType.individual:
        return 'individual';
    }
  }

  static NotificationTargetType fromValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'troop':
        return NotificationTargetType.troop;
      case 'patrol':
        return NotificationTargetType.patrol;
      case 'individual':
        return NotificationTargetType.individual;
      case 'all':
      default:
        return NotificationTargetType.all;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? createdByProfileId;
  final DateTime createdAt;
  final String? seasonId;
  final NotificationTargetType targetType;
  final String? targetId;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdByProfileId,
    required this.createdAt,
    required this.seasonId,
    required this.targetType,
    required this.targetId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: NotificationTypeX.fromValue(json['type'] as String?),
      title: (json['title'] as String? ?? '').trim(),
      body: (json['body'] as String? ?? '').trim(),
      data: data is Map<String, dynamic>
          ? data
          : data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{},
      createdByProfileId: json['created_by_profile_id'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      seasonId: json['season_id'] as String?,
      targetType: NotificationTargetTypeX.fromValue(
        json['target_type'] as String?,
      ),
      targetId: json['target_id'] as String?,
    );
  }
}

class NotificationRecipientEntry {
  final String id;
  final String profileId;
  final String notificationId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final bool delivered;
  final DateTime? deliveredAt;
  final AppNotification notification;

  const NotificationRecipientEntry({
    required this.id,
    required this.profileId,
    required this.notificationId,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
    required this.delivered,
    required this.deliveredAt,
    required this.notification,
  });

  NotificationRecipientEntry copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationRecipientEntry(
      id: id,
      profileId: profileId,
      notificationId: notificationId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      delivered: delivered,
      deliveredAt: deliveredAt,
      notification: notification,
    );
  }

  factory NotificationRecipientEntry.fromJoinedJson(Map<String, dynamic> json) {
    final nestedNotification = json['notifications'];
    if (nestedNotification is! Map<String, dynamic>) {
      throw ArgumentError(
        'NotificationRecipientEntry.fromJoinedJson requires notifications join data.',
      );
    }

    return NotificationRecipientEntry(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      notificationId: json['notification_id'] as String? ?? '',
      isRead: json['read'] as bool? ?? false,
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      delivered: json['delivered'] as bool? ?? false,
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
      notification: AppNotification.fromJson(nestedNotification),
    );
  }
}

class NotificationTargetOption {
  final String id;
  final String label;
  final String? subtitle;

  const NotificationTargetOption({
    required this.id,
    required this.label,
    this.subtitle,
  });
}

class NotificationCreateResult {
  final String notificationId;
  final int recipientCount;

  const NotificationCreateResult({
    required this.notificationId,
    required this.recipientCount,
  });
}

@immutable
class NotificationCreateRequest {
  final String title;
  final String body;
  final NotificationType type;
  final NotificationTargetType targetType;
  final String? targetId;
  final Map<String, dynamic> data;

  const NotificationCreateRequest({
    required this.title,
    required this.body,
    required this.type,
    required this.targetType,
    required this.targetId,
    required this.data,
  });
}
