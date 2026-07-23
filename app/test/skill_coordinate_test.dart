/*
 * [INPUT]: Depends on the public SkillsGateway domain barrel and representative Repository member identity values.
 * [OUTPUT]: Specifies stable App equality and internal key semantics for Repository ID plus Skill Name coordinates.
 * [POS]: Serves as domain-contract coverage for identity shared by discovery, installation, Library, and update journeys.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';

void main() {
  test('SkillCoordinate owns equality and collision-safe internal key', () {
    const first = SkillCoordinate(
      repositoryId: 'github.com/acme/skills',
      name: 'review',
    );
    const same = SkillCoordinate(
      repositoryId: 'github.com/acme/skills',
      name: 'review',
    );
    const other = SkillCoordinate(
      repositoryId: 'github.com/acme',
      name: 'skills:review',
    );

    expect(first, same);
    expect(first.key, 'github.com/acme/skills\u0000review');
    expect(first.key, isNot(other.key));
  });
}
