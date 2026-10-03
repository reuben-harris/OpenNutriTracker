import 'dart:convert';
import 'dart:io';

import 'package:opennutritracker/core/l10n/shipped_locales.dart';

const _androidLocales = 'android/app/src/main/res/xml/locales_config.xml';

void main() {
  final result = checkLocales();
  stdout.write(result.report);
  exitCode = result.ok ? 0 : 1;
}

class LocaleCheck {
  LocaleCheck(this.ok, this.report);
  final bool ok;
  final String report;
}

/// Validates English source strings and Android's declared UI locale.
LocaleCheck checkLocales({String root = '.'}) {
  final problems = <String>[];
  if (shippedLocales.length != 1 || !shippedLocales.containsKey('en')) {
    problems.add('The only shipped UI locale must be en.');
  }
  try {
    final arbs = Directory('$root/lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList();
    if (arbs.length != 1 || !arbs.single.path.endsWith('/intl_en.arb')) {
      problems.add('lib/l10n must contain only intl_en.arb.');
    }
    final strings =
        jsonDecode(File('$root/lib/l10n/intl_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    for (final entry in strings.entries) {
      if (!entry.key.startsWith('@') &&
          (entry.value is! String || (entry.value as String).trim().isEmpty)) {
        problems.add('English string ${entry.key} must not be blank.');
      }
    }
    final xml = File(
      '$root/$_androidLocales',
    ).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final locales = RegExp(
      r'<locale\s+android:name="([^"]+)"',
    ).allMatches(xml).map((match) => match.group(1)).toList();
    if (locales.length != 1 || locales.single != 'en') {
      problems.add('$_androidLocales must declare only en.');
    }
  } on Object catch (error) {
    problems.add('Cannot validate localization: $error');
  }
  return LocaleCheck(
    problems.isEmpty,
    problems.isEmpty
        ? 'OK: English ARB and Android locales agree.\n'
        : '${problems.join('\n')}\n',
  );
}
