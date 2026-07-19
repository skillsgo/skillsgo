/*
 * [INPUT]: Depends on the product-supported UI languages and a system language code.
 * [OUTPUT]: Provides the single App language registry for UI locale selection, native labels, and canonical Hub content tags.
 * [POS]: Serves as the App-owned translation contract shared by composition, Settings, persistence, and CLI forwarding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

enum AppLanguage { system, english, simplifiedChinese }

extension AppLanguageContract on AppLanguage {
  ({String languageCode, String? scriptCode})? get explicitUiLocale =>
      switch (this) {
        AppLanguage.system => null,
        AppLanguage.english => (languageCode: 'en', scriptCode: null),
        AppLanguage.simplifiedChinese => (
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
      };

  String? get nativeName => switch (this) {
    AppLanguage.system => null,
    AppLanguage.english => 'English',
    AppLanguage.simplifiedChinese => '简体中文',
  };

  String contentTag(String systemLanguageCode) => switch (this) {
    AppLanguage.system =>
      systemLanguageCode.toLowerCase() == 'zh' ? 'zh-Hans' : 'en',
    AppLanguage.english => 'en',
    AppLanguage.simplifiedChinese => 'zh-Hans',
  };
}
