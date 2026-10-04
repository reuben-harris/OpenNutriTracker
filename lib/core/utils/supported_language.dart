enum SupportedLanguage {
  en,
  de,
  pl,
  zh,
  cs,
  it,
  sk,
  tr,
  uk,
  hu,
  es;

  factory SupportedLanguage.fromCode(String localeCode) {
    final languageCode = localeCode.split('_').first;
    switch (languageCode) {
      case 'en':
        return SupportedLanguage.en;
      case 'de':
        return SupportedLanguage.de;
      case 'pl':
        return SupportedLanguage.pl;
      case 'zh':
        return SupportedLanguage.zh;
      case 'cs':
        return SupportedLanguage.cs;
      case 'it':
        return SupportedLanguage.it;
      case 'sk':
        return SupportedLanguage.sk;
      case 'tr':
        return SupportedLanguage.tr;
      case 'uk':
        return SupportedLanguage.uk;
      case 'hu':
        return SupportedLanguage.hu;
      case 'es':
        return SupportedLanguage.es;
      default:
        return SupportedLanguage.en;
    }
  }
}
