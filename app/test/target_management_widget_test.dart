/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Library selection, exact External removal, and modified-target safety behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/native_components.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  testWidgets('Library select-all follows the current filtered results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    InstalledSkill entry(String name) => InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills/-/$name',
      name: name,
      skillId: 'github.com/example/skills/-/$name',
      path: '/Users/test/.codex/skills/$name',
      agents: const ['codex'],
      targetCount: 1,
      versions: const ['v1'],
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.user,
          path: '/Users/test/.codex/skills/$name',
          version: 'v1',
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          libraryEntries: [entry('alpha'), entry('demo')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    const selectAllKey = Key('library-select-visible');
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).value,
      isFalse,
    );
    expect(
      tester.getCenter(find.byKey(selectAllKey)).dy,
      closeTo(
        tester.getCenter(find.byKey(const Key('search-visual-icon'))).dy + 2,
        1,
      ),
    );
    expect(
      tester.getCenter(find.byKey(selectAllKey)).dx,
      closeTo(
        tester
            .getCenter(
              find.byKey(
                const ValueKey(
                  'library-select-hub:github.com/example/skills/-/demo',
                ),
              ),
            )
            .dx,
        1,
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).indeterminate,
      isTrue,
    );

    await tester.tap(find.byKey(selectAllKey));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).value,
      isTrue,
    );
    expect(find.text('2 selected'), findsOneWidget);

    final search = find.descendant(
      of: find.byKey(const Key('library-search')),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'demo');
    await tester.pumpAndSettle();
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).value,
      isTrue,
    );

    await tester.tap(find.byKey(selectAllKey));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SkillsCheckbox>(find.byKey(selectAllKey)).value,
      isFalse,
    );
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('Target Management removes only the selected healthy target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'external:/Users/test/.codex/skills/demo',
          name: 'demo',
          skillId: 'github.com/example/skills/-/demo',
          path: '/Users/test/.codex/skills/demo',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          versions: [],
          provenance: LibraryProvenance.external,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/Users/test/.codex/skills/demo',
              version: '',
            ),
            SkillInstallationTarget(
              agent: 'claude-code',
              scope: InstallationScope.project,
              projectRoot: '/work/demo',
              path: '/work/demo/.claude/skills/demo',
              version: '',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-select-external:/Users/test/.codex/skills/demo',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-manage-selected')));
    await tester.pumpAndSettle();
    expect(find.byType(SkillsDialog), findsOneWidget);
    expect(find.text('0 of 2 targets selected'), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(SkillsDialog),
            matching: find.byType(SkillsCheckbox),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 targets selected'), findsOneWidget);
    await tester.tap(find.text('Apply selected actions'));
    await tester.pumpAndSettle();
    expect(find.text('1 succeeded, 0 failed'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(gateway.managementTargetHistory, hasLength(1));
    expect(gateway.managementTargetHistory.single, hasLength(1));
    expect(
      gateway.managementTargetHistory.single.values.single,
      TargetManagementAction.remove,
    );
    expect(gateway.libraryEntries!.single.targets.single.agent, 'claude-code');
  });

  testWidgets('unhealthy targets offer no automatic mutation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/example/skills/-/demo',
          name: 'demo',
          skillId: 'github.com/example/skills/-/demo',
          path: '/Users/test/.codex/skills/demo',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          versions: ['v1'],
          health: InstallationHealth.localModification,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/Users/test/.codex/skills/demo',
              version: 'v1',
            ),
            SkillInstallationTarget(
              agent: 'claude-code',
              scope: InstallationScope.project,
              projectRoot: '/work/demo',
              path: '/work/demo/.claude/skills/demo',
              version: 'v1',
              health: InstallationHealth.localModification,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-manage-selected')));
    await tester.pumpAndSettle();

    expect(find.text('Repair'), findsNothing);
    expect(find.byType(SkillsDialog), findsNothing);
  });

  testWidgets('modified managed targets are never overwritten automatically', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/example/skills/-/demo',
          name: 'demo',
          skillId: 'github.com/example/skills/-/demo',
          path: '/Users/test/.codex/skills/demo',
          agents: ['codex'],
          targetCount: 1,
          versions: ['v1'],
          health: InstallationHealth.localModification,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/Users/test/.codex/skills/demo',
              version: 'v1',
              health: InstallationHealth.localModification,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('library-select-hub:github.com/example/skills/-/demo'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-manage-selected')));
    await tester.pumpAndSettle();
    expect(find.text('Repair'), findsNothing);
    expect(gateway.managementTargetHistory, isEmpty);
    expect(
      gateway.libraryEntries!.single.targets.single.health,
      InstallationHealth.localModification,
    );
  });
}
