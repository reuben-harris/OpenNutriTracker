import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_locales.dart';

void main() {
  late Directory root;
  const androidPath = 'android/app/src/main/res/xml/locales_config.xml';

  void write(String relative, String content) => File('${root.path}/$relative')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  setUp(() {
    root = Directory.systemTemp.createTempSync('check_locales_');
    write('lib/l10n/intl_en.arb', '{"appTitle": "OpenNutriTracker"}');
    write(
      androidPath,
      '<locale-config><locale android:name="en"/></locale-config>',
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('a consistent English fixture passes', () {
    final result = checkLocales(root: root.path);
    expect(result.ok, isTrue, reason: result.report);
  });

  test('a commented-out Android locale is not declared', () {
    write(
      androidPath,
      '<locale-config><!-- <locale android:name="en"/> --></locale-config>',
    );
    expect(checkLocales(root: root.path).ok, isFalse);
  });

  test('an extra Android language fails validation', () {
    write(
      androidPath,
      '<locale-config><locale android:name="en"/><locale android:name="de"/></locale-config>',
    );
    expect(checkLocales(root: root.path).ok, isFalse);
  });

  test('a missing English ARB is reported', () {
    File('${root.path}/lib/l10n/intl_en.arb').deleteSync();
    expect(checkLocales(root: root.path).ok, isFalse);
  });

  test('a blank English string fails validation', () {
    write('lib/l10n/intl_en.arb', '{"appTitle": "  "}');
    expect(checkLocales(root: root.path).ok, isFalse);
  });
}
