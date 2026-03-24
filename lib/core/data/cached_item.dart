class CachedItem<T> {
  const CachedItem({
    required this.data,
    required this.lastUpdated,
    required this.isStale,
  });

  final T data;
  final DateTime lastUpdated;
  final bool isStale;
}
