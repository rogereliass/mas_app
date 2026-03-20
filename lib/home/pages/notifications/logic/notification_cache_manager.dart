import '../../../../core/constants/cache_ttl.dart';
import '../../../../core/utils/ttl_cache.dart';
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

  void set(String key, NotificationPanelData data) {
    _cache.set(key, data, _ttl);
  }

  void invalidate(String key) {
    _cache.invalidate(key);
  }

  void clear() {
    _cache.clear();
  }
}
