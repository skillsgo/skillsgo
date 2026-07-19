/*
 * [INPUT]: Depends on the shared AgentLogo identity mapping and vendored Agent logo asset paths.
 * [OUTPUT]: Verifies that WorkBuddy resolves to its supplied brand SVG instead of the initial fallback.
 * [POS]: Serves as the focused asset-mapping contract for Agent identity presentation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/ui/agent_logo.dart';

void main() {
  test('WorkBuddy uses its brand logo asset', () {
    expect(
      AgentLogo.assetPathFor('workbuddy'),
      'assets/agent-logos/workbuddy.svg',
    );
  });
}
