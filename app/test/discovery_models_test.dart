/*
 * [INPUT]: Depends on immutable discovery Skill summaries and Package-member identity rules.
 * [OUTPUT]: Specifies concise version actions and version-aware detail identity.
 * [POS]: Serves as the focused domain regression suite for discovery installation state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';

void main() {
  test('versioned identity separates versions of the same Package member', () {
    const first = SkillSummary(
      packagePath: 'github.com/acme/skills',
      installName: 'demo',
      name: 'demo',
      path: 'skills/demo',
      latestVersion: 'v1.0.0',
    );
    const second = SkillSummary(
      packagePath: 'github.com/acme/skills',
      installName: 'demo',
      name: 'demo',
      path: 'skills/demo',
      latestVersion: 'v2.0.0',
    );

    expect(first.coordinateKey, second.coordinateKey);
    expect(first.versionedCoordinateKey, isNot(second.versionedCoordinateKey));
    expect(first.versionedCoordinateKey, contains('v1.0.0'));
    expect(first.versionedCoordinateKey, contains('skills/demo'));
  });
}
