import '../../../../core/constants/cache_ttl.dart';
import '../../../../core/data/persistent_query_cache.dart';
import '../../../../core/utils/ttl_cache.dart';
import '../data/models/notification_models.dart';
import '../data/notification_repository.dart';

class NotificationCacheLookup {
  final NotificationPanelData? data;
  final bool isExpired;

  const NotificationCacheLookup({
    required this.data,
    required this.isExpired,
  });

  bool get hasData => data != null;
}

class NotificationCacheManager {
  static const String _persistedPrefix = 'notifications:panel:';

  NotificationCacheManager({Duration? ttl}) : _ttl = ttl ?? CacheTtl.notificationsList;

  final Duration _ttl;
  final TtlCache<String, NotificationPanelData> _cache =
      TtlCache<String, NotificationPanelData>();

  NotificationCacheLookup lookup(String key) {
    if (!_cache.hasKey(key)) {
      return const NotificationCacheLookup(data: null, isExpired: false);
    }

    final isExpired = _cache.isExpired(key);
    final data = isExpired ? _cache.get(key, ignoreExpiry: true) : _cache.get(key);

    return NotificationCacheLookup(data: data, isExpired: isExpired);
  }

  Future<NotificationCacheLookup> lookupPersisted(String key) async {
    final persisted = await PersistentQueryCache.read<NotificationPanelData>(
      key: _persistedKey(key),
      parser: _parsePanelData,
    );

    if (persisted == null) {
      return const NotificationCacheLookup(data: null, isExpired: false);
    }

    return NotificationCacheLookup(
      data: persisted.data,
      isExpired: persisted.isExpired,
    );
  }

  void set(String key, NotificationPanelData data) {
    _cache.set(key, data, _ttl);
    // Persist in the background so notification snapshots survive app restarts.
    Future<void>.microtask(() async {
      await PersistentQueryCache.write(
        key: _persistedKey(key),
        payload: _panelDataToJson(data),
        ttl: _ttl,
      );
    });
  }

  void invalidate(String key) {
    _cache.invalidate(key);
    Future<void>.microtask(() async {
      await PersistentQueryCache.invalidate(_persistedKey(key));
    });
  }

  void clear() {
    _cache.clear();
  }

  String _persistedKey(String key) => '$_persistedPrefix$key';

  NotificationPanelData? _parsePanelData(Object? payload) {
    if (payload is! Map) return null;
    final map = payload.map((rawKey, value) => MapEntry(rawKey.toString(), value));
    final notificationsRaw = map['notifications'];
    if (notificationsRaw is! List) return null;

    final notifications = notificationsRaw
        .whereType<Map>()
        .map(
          (row) => row.map((rawKey, value) => MapEntry(rawKey.toString(), value)),
        )
        .map(NotificationRecipientEntry.fromJoinedJson)
        .toList(growable: false);

    final unreadRaw = map['unread_count'];
    final unreadCount = unreadRaw is num
        ? unreadRaw.toInt()
        : int.tryParse(unreadRaw?.toString() ?? '') ?? 0;

    return NotificationPanelData(
      notifications: notifications,
      unreadCount: unreadCount,
    );
  }

  Map<String, dynamic> _panelDataToJson(NotificationPanelData data) {
    return <String, dynamic>{
      'unread_count': data.unreadCount,
      'notifications': data.notifications
          .map(
            (entry) => <String, dynamic>{
              'id': entry.id,
              'profile_id': entry.profileId,
              'notification_id': entry.notificationId,
              'read': entry.isRead,
              'read_at': entry.readAt?.toIso8601String(),
              'created_at': entry.createdAt.toIso8601String(),
              'delivered': entry.delivered,
              'delivered_at': entry.deliveredAt?.toIso8601String(),
              'notifications': <String, dynamic>{
                'id': entry.notification.id,
                'type': entry.notification.type.value,
                'title': entry.notification.title,
                'body': entry.notification.body,
                'data': entry.notification.data,
                'created_by_profile_id': entry.notification.createdByProfileId,
                'created_at': entry.notification.createdAt.toIso8601String(),
                'season_id': entry.notification.seasonId,
                'target_type': entry.notification.targetType.value,
                'target_id': entry.notification.targetId,
              },
            },
          )
          .toList(growable: false),
    };
  }
}
