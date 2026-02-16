class TtlCache<K, V> {
  final Map<K, _TtlEntry<V>> _store = {};

  V? get(K key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value;
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
