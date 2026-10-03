import 'dart:ui';

import 'package:opennutritracker/core/l10n/shipped_locales.dart';

/// Restricts generated localization delegates to shipped UI languages.
List<Locale> appLocales(Iterable<Locale> generated) => generated
    .where((locale) => shippedLocales.containsKey(locale.toString()))
    .toList(growable: false);
