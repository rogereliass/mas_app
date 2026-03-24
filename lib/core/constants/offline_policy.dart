class OfflinePolicy {
  OfflinePolicy._();

  static const Duration connectivityDebounce = Duration(milliseconds: 600);
  static const Duration networkTimeout = Duration(seconds: 15);
  static const int maxQueueRetries = 3;
}
