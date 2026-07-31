/*
 * [INPUT]: Reads the English template and locale-specific ARB catalogs from lib/l10n.
 * [OUTPUT]: Specifies that every supported App locale has exactly the complete English message-key set.
 * [POS]: Serves as the localization coverage regression contract for the App workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every locale covers the complete English message catalog', () {
    final l10nDirectory = Directory('lib/l10n');
    final template = _readCatalog(File('${l10nDirectory.path}/app_en.arb'));
    final templateKeys = _messageKeys(template);
    final catalogs =
        l10nDirectory
            .listSync()
            .whereType<File>()
            .where((file) => RegExp(r'app_.+\.arb$').hasMatch(file.path))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    for (final catalogFile in catalogs) {
      final localeKeys = _messageKeys(_readCatalog(catalogFile));
      expect(
        localeKeys,
        templateKeys,
        reason:
            '${catalogFile.path} must translate every English message '
            'without relying on generated fallback copy.',
      );
    }
  });
}

Map<String, Object?> _readCatalog(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
      .cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> catalog) {
  return catalog.keys.where((key) => !key.startsWith('@')).toSet();
}
