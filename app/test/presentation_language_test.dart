/*
 * [INPUT]: Uses the App-owned language registry with representative system language codes.
 * [OUTPUT]: Specifies stable UI locale metadata, native labels, and canonical Hub content tags.
 * [POS]: Serves as contract coverage for the App translation boundary shared by Settings and CLI forwarding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/presentation_language.dart';

void main() {
  test('language registry owns UI and Hub locale mappings', () {
    expect(AppLanguage.system.contentTag('zh'), 'zh-Hans');
    expect(AppLanguage.system.contentTag('de'), 'en');
    expect(AppLanguage.english.contentTag('zh'), 'en');
    expect(AppLanguage.simplifiedChinese.contentTag('en'), 'zh-Hans');
    expect(AppLanguage.simplifiedChinese.nativeName, '简体中文');
    expect(AppLanguage.simplifiedChinese.explicitUiLocale, (
      languageCode: 'zh',
      scriptCode: 'Hans',
    ));
  });
}
