/*
 * [INPUT]: Depends on the product-supported UI languages and a system language code.
 * [OUTPUT]: Provides the single App language registry for UI locale selection, native labels, and canonical Hub content tags.
 * [POS]: Serves as the App-owned translation contract shared by composition, Settings, persistence, and CLI forwarding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

enum AppLanguage {
  system,
  english,
  simplifiedChinese,
  traditionalChineseTaiwan,
  traditionalChineseHongKong,
  japanese,
  korean,
  french,
  german,
  italian,
  spanish,
  portugueseBrazil,
  russian,
  arabic,
  hindi,
  indonesian,
  turkish,
  dutch,
  polish,
  thai,
  vietnamese,
  malay,
  swedish,
  ukrainian,
}

extension AppLanguageContract on AppLanguage {
  ({String languageCode, String? scriptCode, String? countryCode})?
  get explicitUiLocale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.english => (
      languageCode: 'en',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.simplifiedChinese => (
      languageCode: 'zh',
      scriptCode: 'Hans',
      countryCode: 'CN',
    ),
    AppLanguage.traditionalChineseTaiwan => (
      languageCode: 'zh',
      scriptCode: 'Hant',
      countryCode: 'TW',
    ),
    AppLanguage.traditionalChineseHongKong => (
      languageCode: 'zh',
      scriptCode: 'Hant',
      countryCode: 'HK',
    ),
    AppLanguage.japanese => (
      languageCode: 'ja',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.korean => (
      languageCode: 'ko',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.french => (
      languageCode: 'fr',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.german => (
      languageCode: 'de',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.italian => (
      languageCode: 'it',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.spanish => (
      languageCode: 'es',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.portugueseBrazil => (
      languageCode: 'pt',
      scriptCode: null,
      countryCode: 'BR',
    ),
    AppLanguage.russian => (
      languageCode: 'ru',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.arabic => (
      languageCode: 'ar',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.hindi => (
      languageCode: 'hi',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.indonesian => (
      languageCode: 'id',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.turkish => (
      languageCode: 'tr',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.dutch => (
      languageCode: 'nl',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.polish => (
      languageCode: 'pl',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.thai => (
      languageCode: 'th',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.vietnamese => (
      languageCode: 'vi',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.malay => (
      languageCode: 'ms',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.swedish => (
      languageCode: 'sv',
      scriptCode: null,
      countryCode: null,
    ),
    AppLanguage.ukrainian => (
      languageCode: 'uk',
      scriptCode: null,
      countryCode: null,
    ),
  };

  String? get nativeName => switch (this) {
    AppLanguage.system => null,
    AppLanguage.english => 'English',
    AppLanguage.simplifiedChinese => '简体中文',
    AppLanguage.traditionalChineseTaiwan => '繁體中文（台灣）',
    AppLanguage.traditionalChineseHongKong => '繁體中文（香港）',
    AppLanguage.japanese => '日本語',
    AppLanguage.korean => '한국어',
    AppLanguage.french => 'Français',
    AppLanguage.german => 'Deutsch',
    AppLanguage.italian => 'Italiano',
    AppLanguage.spanish => 'Español',
    AppLanguage.portugueseBrazil => 'Português (Brasil)',
    AppLanguage.russian => 'Русский',
    AppLanguage.arabic => 'العربية',
    AppLanguage.hindi => 'हिन्दी',
    AppLanguage.indonesian => 'Bahasa Indonesia',
    AppLanguage.turkish => 'Türkçe',
    AppLanguage.dutch => 'Nederlands',
    AppLanguage.polish => 'Polski',
    AppLanguage.thai => 'ไทย',
    AppLanguage.vietnamese => 'Tiếng Việt',
    AppLanguage.malay => 'Bahasa Melayu',
    AppLanguage.swedish => 'Svenska',
    AppLanguage.ukrainian => 'Українська',
  };

  String contentTag(String systemLocaleTag) => switch (this) {
    AppLanguage.system => _systemContentTag(systemLocaleTag),
    AppLanguage.english => 'en',
    AppLanguage.simplifiedChinese => 'zh-Hans',
    AppLanguage.traditionalChineseTaiwan ||
    AppLanguage.traditionalChineseHongKong => 'zh-Hant',
    AppLanguage.japanese ||
    AppLanguage.korean ||
    AppLanguage.french ||
    AppLanguage.german ||
    AppLanguage.italian ||
    AppLanguage.spanish ||
    AppLanguage.portugueseBrazil ||
    AppLanguage.russian ||
    AppLanguage.arabic ||
    AppLanguage.hindi ||
    AppLanguage.indonesian ||
    AppLanguage.turkish ||
    AppLanguage.dutch ||
    AppLanguage.polish ||
    AppLanguage.thai ||
    AppLanguage.vietnamese ||
    AppLanguage.malay ||
    AppLanguage.swedish ||
    AppLanguage.ukrainian => 'en',
  };
}

String _systemContentTag(String localeTag) {
  final normalized = localeTag.replaceAll('_', '-').toLowerCase();
  if (!normalized.startsWith('zh')) return 'en';
  if (normalized.contains('hant') ||
      normalized.endsWith('-tw') ||
      normalized.endsWith('-hk') ||
      normalized.endsWith('-mo')) {
    return 'zh-Hant';
  }
  return 'zh-Hans';
}
