import 'dart:async';

import 'package:masapp/core/data/cached_item.dart';
import 'package:masapp/core/utils/ttl_cache.dart';

class CacheManager {
  CacheManager();

  final TtlCache<String, Object?> _cache = TtlCache<String, Object?>();
  final Map<String, DateTime> _lastUpdated = <String, DateTime>{};
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  T? get<T>(String key, {bool allowStale = true}) {
    final value = _cache.get(key, ignoreExpiry: allowStale);
    if (value == null) return null;
    if (value is! T) return null;
    return value as T;
  }

  void set<T>(String key, T data, Duration ttl) {
    _cache.set(key, data, ttl);
    _lastUpdated[key] = DateTime.now();
  }

  bool isExpired(String key) => _cache.isExpired(key);

  DateTime? getLastUpdated(String key) => _lastUpdated[key];

  CachedItem<T>? getCachedItem<T>(String key, {bool allowStale = true}) {
    final data = get<T>(key, allowStale: allowStale);
    if (data == null) return null;

    return CachedItem<T>(
      data: data,
      lastUpdated: _lastUpdated[key] ?? DateTime.now(),
      isStale: _cache.isExpired(key),
    );
  }

  Future<T?> getCacheFirst<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetcher,
    void Function(T data)? onBackgroundRefreshed,
  }) async {
    final cached = get<T>(key);
    if (cached != null) {
      unawaited(
        _refreshInBackground<T>(
          key: key,
          ttl: ttl,
          fetcher: fetcher,
          onBackgroundRefreshed: onBackgroundRefreshed,
        ),
      );
      return cached;
    }

    final fresh = await _fetchDeduped<T>(key, fetcher);
    set<T>(key, fresh, ttl);
    return fresh;
  }

  Future<void> refresh<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetcher,
    void Function(T data)? onBackgroundRefreshed,
  }) {
    return _refreshInBackground<T>(
      key: key,
      ttl: ttl,
      fetcher: fetcher,
      onBackgroundRefreshed: onBackgroundRefreshed,
    );
  }

  void invalidate(String key) {
    _cache.invalidate(key);
    _lastUpdated.remove(key);
    _inFlight.remove(key);
  }

  void clear() {
    _cache.clear();
    _lastUpdated.clear();
    _inFlight.clear();
  }

  Future<void> _refreshInBackground<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetcher,
    void Function(T data)? onBackgroundRefreshed,
  }) async {
    try {
      final fresh = await _fetchDeduped<T>(key, fetcher);
      set<T>(key, fresh, ttl);
      onBackgroundRefreshed?.call(fresh);
    } catch (_) {
      // Keep existing cached value on background refresh failures.
    }
  }

  Future<T> _fetchDeduped<T>(String key, Future<T> Function() fetcher) async {
    final existing = _inFlight[key];
    if (existing != null) {
      final reused = await existing;
      if (reused is T) {
        return reused;
      }
    }

    final future = fetcher();
    final wrapped = future.then<Object?>((value) => value);
    _inFlight[key] = wrapped;

    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }
}
