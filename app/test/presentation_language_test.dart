/*
 * [INPUT]: Uses the App-owned language registry, generated localizations, and representative system/source language codes.
 * [OUTPUT]: Specifies stable UI locale metadata, localized source-language names, native labels, and canonical Hub content tags.
 * [POS]: Serves as contract coverage for the App translation boundary shared by Settings and CLI forwarding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/presentation_language.dart';
import 'package:skillsgo/l10n/app_localizations.dart';

void main() {
  test('language registry owns UI and Hub locale mappings', () {
    expect(AppLanguage.system.contentTag('zh'), 'zh-Hans-CN');
    expect(AppLanguage.system.contentTag('zh-Hant-TW'), 'zh-Hant-TW');
    expect(AppLanguage.system.contentTag('zh_HK'), 'zh-Hant-HK');
    expect(AppLanguage.system.contentTag('de'), 'de');
    expect(AppLanguage.english.contentTag('zh'), 'en');
    expect(AppLanguage.simplifiedChinese.contentTag('en'), 'zh-Hans-CN');
    expect(AppLanguage.traditionalChineseTaiwan.contentTag('en'), 'zh-Hant-TW');
    expect(
      AppLanguage.traditionalChineseHongKong.contentTag('en'),
      'zh-Hant-HK',
    );
    expect(AppLanguage.japanese.contentTag('en'), 'ja');
    expect(AppLanguage.simplifiedChinese.nativeName, '简体中文');
    expect(AppLanguage.simplifiedChinese.explicitUiLocale, (
      languageCode: 'zh',
      scriptCode: 'Hans',
      countryCode: 'CN',
    ));
    expect(AppLanguage.portugueseBrazil.explicitUiLocale, (
      languageCode: 'pt',
      scriptCode: null,
      countryCode: 'BR',
    ));
    expect(AppLanguage.arabic.nativeName, 'العربية');
    expect(AppLanguage.values, hasLength(24));

    final registeredCodes = AppLanguage.values
        .where((language) => language != AppLanguage.system)
        .map((language) => language.explicitUiLocale!.languageCode)
        .toSet();
    final generatedCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    expect(generatedCodes, registeredCodes);
    expect(AppLocalizations.supportedLocales, hasLength(23));
  });

  test('every UI locale localizes every supported source language', () async {
    const sourceCodes = [
      'en',
      'zhHans',
      'zhHant',
      'ja',
      'ko',
      'fr',
      'de',
      'it',
      'es',
      'pt',
      'ru',
      'ar',
      'hi',
      'id',
      'tr',
      'nl',
      'pl',
      'th',
      'vi',
      'ms',
      'sv',
      'uk',
    ];
    const localizedEnglish = {
      'ar': 'الإنجليزية',
      'de': 'Englisch',
      'en': 'English',
      'es': 'inglés',
      'fr': 'anglais',
      'hi': 'अंग्रेज़ी',
      'id': 'Inggris',
      'it': 'inglese',
      'ja': '英語',
      'ko': '영어',
      'ms': 'Inggeris',
      'nl': 'Engels',
      'pl': 'angielski',
      'pt': 'inglês',
      'ru': 'английский',
      'sv': 'engelska',
      'th': 'อังกฤษ',
      'tr': 'İngilizce',
      'uk': 'англійська',
      'vi': 'Tiếng Anh',
      'zh': '英语',
      'zh-Hant-HK': '英文',
      'zh-Hant-TW': '英文',
    };

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final localeTag = locale.toLanguageTag();
      expect(
        l10n.sourceLanguageName('en'),
        localizedEnglish[localeTag],
        reason: localeTag,
      );
      for (final code in sourceCodes) {
        expect(
          l10n.sourceLanguageName(code),
          isNot(code),
          reason: '$localeTag must localize $code',
        );
      }
    }
  });
}
