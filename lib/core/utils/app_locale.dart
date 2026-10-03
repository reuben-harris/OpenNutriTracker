import 'package:flutter/foundation.dart';

/// Food requests use the same English locale as the app.
class AppLocale {
  AppLocale._();

  static String? _testLocale;
  static String get localeName => _testLocale ?? 'en';

  /// Allows generic food translation and cache tests to exercise other locales.
  @visibleForTesting
  static void select(String? localeName) => _testLocale = localeName;

  @visibleForTesting
  static void reset() => _testLocale = null;
}
