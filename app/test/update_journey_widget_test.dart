/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Needs Attention Package-card update discovery, alert-colored Library update badges, five-item update previews with overflow counts, readable resident-budget tooltips, one-card direct Package update delegation, failure retention, and refreshed installed versions.
 * [POS]: Serves as the rendered Package-update journey suite without App-owned Update Plan UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';

import 'support/fake_skills_gateway.dart';

const updateSkill = InstalledSkill(
  inventoryKey: 'hub:github.com/test/skills:local-skill',
  name: 'local-skill',
  path: '/tmp/user/local-skill',
  agents: ['codex', 'claude-code'],
  targetCount: 2,
  packagePath: 'github.com/test/skills',
  versions: ['v1'],
  targets: [
    SkillInstallationTarget(
      agent: 'codex',
      scope: InstallationScope.global,
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
);

const secondPackageMember = InstalledSkill(
  inventoryKey: 'hub:github.com/test/skills:second-skill',
  name: 'second-skill',
  path: '/tmp/user/second-skill',
  agents: ['codex'],
  targetCount: 1,
  packagePath: 'github.com/test/skills',
  versions: ['v1'],
  targets: [
    SkillInstallationTarget(
      agent: 'codex',
      scope: InstallationScope.global,
      path: '/tmp/user/second-skill',
      version: 'v1',
    ),
  ],
);

InstalledSkill updatePreviewSkill(String packagePath, String name) =>
    InstalledSkill(
      inventoryKey: 'hub:$packagePath:$name',
      name: name,
      path: '/tmp/user/$name',
      agents: const ['codex'],
      targetCount: 1,
      packagePath: packagePath,
      versions: const ['v1'],
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.global,
          path: '/tmp/user/$name',
          version: 'v1',
        ),
      ],
    );

Future<void> openUpdates(WidgetTester tester, FakeSkillsGateway gateway) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(SkillsGoApp(gateway: gateway));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('primary-destination-library')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('library-content-needs-attention')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('library-attention-updates')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Library exposes update state after an explicit check', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(libraryEntries: const [updateSkill]);
    await openUpdates(tester, gateway);

    expect(
      find.byKey(
        const ValueKey('library-package-update-github.com/test/skills'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('library-content-needs-attention')),
      findsOneWidget,
    );
    expect(find.textContaining('Retired Skill'), findsOneWidget);
    expect(find.textContaining('skills/retired/SKILL.md'), findsNothing);
    expect(find.text('local-skill'), findsNothing);
    expect(find.byKey(const Key('library-select-visible')), findsNothing);
  });

  testWidgets('available updates mark both Library update badges as alerts', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      libraryEntries: [
        updateSkill,
        updatePreviewSkill('github.com/acme/first', 'first'),
        updatePreviewSkill('github.com/acme/second', 'second'),
        updatePreviewSkill('github.com/acme/third', 'third'),
        updatePreviewSkill('github.com/acme/fourth', 'fourth'),
        updatePreviewSkill('github.com/acme/fifth', 'fifth'),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-content-needs-attention')));
    await tester.pumpAndSettle();

    Color badgeTextColor(Finder badge) {
      final text = find.descendant(of: badge, matching: find.byType(Text));
      return tester.widget<Text>(text).style!.color!;
    }

    final attentionBadge = find.byKey(
      const Key('library-content-count-needs-attention'),
    );
    final updatesBadge = find.byKey(
      const Key('library-attention-updates-count'),
    );
    final colors = Theme.of(tester.element(attentionBadge)).colorScheme;
    final budgetTooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('library-unused-budget-45-days')),
        matching: find.byType(Tooltip),
      ),
    );

    expect(badgeTextColor(attentionBadge), colors.onError);
    expect(badgeTextColor(updatesBadge), colors.onError);
    expect(
      find.byKey(const Key('library-update-skill-preview-row')),
      findsOneWidget,
    );
    for (final name in ['first', 'second', 'third', 'fourth', 'fifth']) {
      expect(
        find.byKey(
          ValueKey(
            'library-update-skill-avatar-hub:github.com/acme/$name:$name',
          ),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('library-update-skill-preview-more')),
      findsOneWidget,
    );
    expect(find.text('+1'), findsOneWidget);
    expect(budgetTooltip.constraints!.maxWidth, 380);
    expect(
      tester
          .widget<Container>(
            find.descendant(of: updatesBadge, matching: find.byType(Container)),
          )
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        colors.error,
      ),
    );
  });

  testWidgets('failed update checks never report that Packages are current', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      libraryEntries: const [updateSkill],
      updateCheckErrors: const [
        SkillsException(
          'network unavailable',
          kind: SkillsFailureKind.offline,
          isOffline: true,
        ),
        SkillsException(
          'network unavailable',
          kind: SkillsFailureKind.offline,
          isOffline: true,
        ),
      ],
    );
    await openUpdates(tester, gateway);

    expect(find.text('Can’t connect to SkillsGo'), findsWidgets);
    expect(find.text('UP TO DATE'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'Library delegates direct Package update and refreshes inventory',
    (tester) async {
      final gateway = FakeSkillsGateway(libraryEntries: const [updateSkill]);
      await openUpdates(tester, gateway);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'library-package-update-action-github.com/test/skills',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(gateway.updateCalls, 1);
      expect(
        gateway.updatePackageHistory.single.packagePath,
        'github.com/test/skills',
      );
      expect(gateway.updatePackageHistory.single.version, 'v2');
      expect(find.text('Select targets to update'), findsNothing);
    },
  );

  testWidgets('members of one Package render one Package update card', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      libraryEntries: const [updateSkill, secondPackageMember],
    );
    await openUpdates(tester, gateway);
    expect(
      find.byKey(
        const ValueKey('library-package-update-github.com/test/skills'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('library-package-update-action-github.com/test/skills'),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.updateCalls, 1);
    expect(
      gateway.updatePackageHistory.single.packagePath,
      'github.com/test/skills',
    );
  });

  testWidgets(
    'failed direct Package update leaves installed version unchanged',
    (tester) async {
      final gateway = FakeSkillsGateway(
        libraryEntries: const [updateSkill],
        updateError: const SkillsException(
          'Package Projection Local Modification',
          kind: SkillsFailureKind.invalidLocalData,
        ),
      );
      await openUpdates(tester, gateway);
      await tester.tap(
        find.byKey(
          const ValueKey(
            'library-package-update-action-github.com/test/skills',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(gateway.updateCalls, 1);
      expect(gateway.libraryEntries!.single.targets.first.version, 'v1');
    },
  );

  testWidgets('installed detail refreshes target versions after update', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      libraryEntries: const [updateSkill],
      updateCheckCache: UpdateCheckCache(
        checkedAt: DateTime.now().toUtc(),
        results: {
          for (final target in updateSkill.targets)
            packageScopeUpdateKey(
              updateSkill.packagePath,
              target.scope,
              target.projectRoot,
            ): const UpdateAvailability(
              state: UpdateState.available,
              toVersion: 'v2',
            ),
        },
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('local-skill'));
    await tester.pumpAndSettle();
    expect(find.text('v1'), findsWidgets);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(gateway.updateCalls, 1);
    expect(find.text('v2'), findsWidgets);
    expect(find.text('Select targets to update'), findsNothing);
  });
}
