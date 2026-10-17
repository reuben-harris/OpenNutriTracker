import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Keeps test registrations in their own scope and restores the caller's scope.
void useTestLocator() {
  setUp(() => GetIt.instance.pushNewScope());
  tearDown(() => GetIt.instance.popScope());
}
