import 'package:flutter_test/flutter_test.dart';

/// Pumps frame work and real I/O until an observable transition completes.
/// The deadline bounds failures without guessing how long storage will take.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  String reason = 'expected asynchronous transition',
}) async {
  final deadline = Stopwatch()..start();
  while (!done()) {
    if (deadline.elapsed > const Duration(seconds: 5)) {
      fail('Timed out waiting for $reason');
    }
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump();
}
