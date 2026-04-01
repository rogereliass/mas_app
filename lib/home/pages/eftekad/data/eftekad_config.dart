class EftekadConfig {
  EftekadConfig._();

  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration notContactedThreshold = Duration(days: 10);
  static const int recordsPageSize = 15;
}
