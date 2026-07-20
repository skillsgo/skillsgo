/*
 * [INPUT]: Depends on dart:io, flutter_svg's production loader, the shared AgentLogo identity mapping, and vendored Agent logo assets.
 * [OUTPUT]: Verifies supplied Agent mappings, fallback behavior, and production-parser validity for every vendored Agent SVG.
 * [POS]: Serves as the focused asset-mapping contract for Agent identity presentation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/agent_logo.dart';

void main() {
  test('WorkBuddy uses its brand logo asset', () {
    expect(
      AgentLogo.assetPathFor('workbuddy'),
      'assets/agent-logos/workbuddy.svg',
    );
  });

  test('Bob uses the safe text fallback when no valid SVG is supplied', () {
    expect(AgentLogo.assetPathFor('bob'), isNull);
  });

  test('every vendored Agent SVG parses with the production loader', () async {
    final files = Directory('assets/agent-logos')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.svg'))
        .toList(growable: false);

    expect(files, isNotEmpty);
    for (final file in files) {
      await expectLater(
        SvgBytesLoader(await file.readAsBytes()).loadBytes(null),
        completes,
        reason: file.path,
      );
    }
  });
}
