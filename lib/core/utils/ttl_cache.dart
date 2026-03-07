class TtlCache<K, V> {
  final Map<K, _TtlEntry<V>> _store = {};

  /// Returns the cached value for [key].
  ///
  /// By default, expired entries are removed and `null` is returned.
  /// Set [ignoreExpiry] to true to read stale values for graceful offline
  /// fallback or background-refresh flows.
  V? get(K key, {bool ignoreExpiry = false}) {
    final entry = _store[key];
    if (entry == null) return null;
    if (!ignoreExpiry && entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Returns true when a key exists in the cache, even if the entry is stale.
  bool hasKey(K key) => _store.containsKey(key);

  /// Returns true when [key] exists and its TTL has already elapsed.
  bool isExpired(K key) {
    final entry = _store[key];
    if (entry == null) return false;
    return entry.isExpired;
  }

  void set(K key, V value, Duration ttl) {
    _store[key] = _TtlEntry(value, DateTime.now().add(ttl));
  }

  void invalidate(K key) {
    _store.remove(key);
  }

  void clear() {
    _store.clear();
  }
}

class _TtlEntry<V> {
  final V value;
  final DateTime expiresAt;

  _TtlEntry(this.value, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
