import 'package:flutter_test/flutter_test.dart';
import 'package:masapp/home/pages/eftekad/data/eftekad_config.dart';

void main() {
  test('uses 300ms debounce and 10-day not-contacted threshold', () {
    expect(EftekadConfig.searchDebounce, const Duration(milliseconds: 300));
    expect(EftekadConfig.notContactedThreshold, const Duration(days: 10));
    expect(EftekadConfig.recordsPageSize, 15);
  });
}
