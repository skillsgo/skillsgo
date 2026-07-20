/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Update discovery, planning, retry, refreshed versions, and end-to-end target mutation behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/native_components.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('Library exposes update state after an explicit check', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('local-skill'), findsOneWidget);
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-select-hub:github.com/test/skills/-/local-skill',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('library-update-selected')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Update Plan changes only explicitly selected targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/user/local-skill',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          skillId: 'github.com/test/skills/-/local-skill',
          versions: ['v1'],
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/tmp/user/local-skill',
              version: 'v1',
            ),
            SkillInstallationTarget(
              agent: 'claude-code',
              scope: InstallationScope.project,
              projectRoot: '/tmp/project',
              path: '/tmp/project/.claude/skills/local-skill',
              version: 'v1',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-select-hub:github.com/test/skills/-/local-skill',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-update-selected')));
    await tester.pumpAndSettle();

    expect(find.text('Select targets to update'), findsOneWidget);
    expect(find.text('2 of 2 updateable targets selected'), findsOneWidget);
    expect(find.textContaining('/tmp/project/skillsgo.mod'), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(SkillsDialog),
            matching: find.byType(SkillsCheckbox),
          )
          .at(1),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 updateable targets selected'), findsOneWidget);
    expect(find.textContaining('/tmp/project/skillsgo.mod'), findsNothing);
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();

    expect(gateway.updateTargetHistory, hasLength(1));
    expect(gateway.updateTargetHistory.single, hasLength(1));
    expect(gateway.updateTargetHistory.single.single, contains('codex'));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('Update Plan retries only failed targets and retains success', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      updateFailures: const [
        {'claude-code'},
        <String>{},
      ],
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/user/local-skill',
          agents: ['codex', 'claude-code'],
          targetCount: 2,
          skillId: 'github.com/test/skills/-/local-skill',
          versions: ['v1'],
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/tmp/user/local-skill',
              version: 'v1',
            ),
            SkillInstallationTarget(
              agent: 'claude-code',
              scope: InstallationScope.project,
              projectRoot: '/tmp/project',
              path: '/tmp/project/.claude/skills/local-skill',
              version: 'v1',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey(
          'library-select-hub:github.com/test/skills/-/local-skill',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-update-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();

    expect(find.text('Retry 1 Failed Update'), findsOneWidget);
    expect(
      find.text(
        'This location could not be updated. Other locations were not affected, so you can retry only this one.',
      ),
      findsOneWidget,
    );
    expect(find.text('Target is not writable.'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(find.text('Target is not writable.'), findsOneWidget);
    expect(gateway.updateTargetHistory.first, hasLength(2));
    await tester.tap(find.text('Retry 1 Failed Update'));
    await tester.pumpAndSettle();

    expect(gateway.updateTargetHistory, hasLength(2));
    expect(gateway.updateTargetHistory.last, hasLength(1));
    expect(gateway.updateTargetHistory.last.single, contains('claude-code'));
    expect(find.text('Retry 1 Failed Update'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Version divergence'), findsNothing);
  });

  testWidgets('installed detail refreshes target versions after update', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(
      libraryEntries: const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/test/skills/-/local-skill',
          name: 'local-skill',
          path: '/tmp/local-skill',
          agents: ['codex'],
          targetCount: 1,
          skillId: 'github.com/test/skills/-/local-skill',
          versions: ['v1'],
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: '/tmp/local-skill',
              version: 'v1',
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('local-skill'));
    await tester.pumpAndSettle();
    final scope = find.byKey(const Key('installation-scope-panel'));
    expect(
      find.descendant(of: scope, matching: find.text('Global')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: scope, matching: find.text('v1')),
      findsOneWidget,
    );

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update selected targets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: scope, matching: find.text('Global')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: scope, matching: find.text('v2')),
      findsOneWidget,
    );
  });

  testWidgets(
    'core flow searches, installs, checks updates and removes a target',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway(installed: false);
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.enterText(searchInput(), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      expect(find.text('Install Flutter Pro to'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pumpAndSettle();
      expect(gateway.installCalls, 1);
      await tester.tap(
        find.byKey(const ValueKey('primary-destination-library')),
      );
      await tester.pumpAndSettle();
      expect(find.text('local-skill'), findsOneWidget);

      await tester.tap(find.text('Updates'));
      await tester.pumpAndSettle();
      expect(find.text('UPDATE'), findsNothing);
      await tester.tap(find.text('local-skill').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show target details'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('remove-installation-target-/tmp/local-skill'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('confirm-remove-installation-target-/tmp/local-skill'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No skills installed yet'), findsOneWidget);
    },
  );
}
