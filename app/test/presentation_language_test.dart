/*
 * [INPUT]: Uses the App-owned language registry with representative system language codes.
 * [OUTPUT]: Specifies stable UI locale metadata, native labels, and canonical Hub content tags.
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
}
