import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_locales.dart';

/// Android locale declarations agree with the English ARB source.
void main() {
  test('every locale list matches shipped_locales.dart', () {
    final result = checkLocales();
    expect(result.ok, isTrue, reason: result.report);
  });
}
