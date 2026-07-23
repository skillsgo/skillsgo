/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Installed-detail provenance, Hub enrichment resilience, and local install-more behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  testWidgets('installed detail presents provenance-specific actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));

    Future<void> open(InstalledSkill entry, {UpdateState? updateState}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            installed: false,
            libraryEntries: [entry],
            updateState: updateState ?? UpdateState.available,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.name).first);
      await tester.pumpAndSettle();
    }

    const target = SkillInstallationTarget(
      agent: 'codex',
      scope: InstallationScope.user,
      path: '/Users/test/.codex/skills/action-demo',
      version: 'v1',
    );
    const hub = InstalledSkill(
      inventoryKey: 'hub:github.com/test/skills:action-demo',
      name: 'action-demo',
      path: '/Users/test/.codex/skills/action-demo',
      agents: ['codex'],
      targetCount: 1,
      repositoryId: 'github.com/test/skills',
      versions: ['v1'],
      targets: [target],
    );
    await open(hub);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Install in more locations'), findsOneWidget);
    await tester.tap(find.byTooltip('Show target details'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'remove-installation-target-/Users/test/.codex/skills/action-demo',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'remove-installation-target-/Users/test/.codex/skills/action-demo',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm remove'), findsOneWidget);
    expect(find.text('Manage installation targets'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await open(hub, updateState: UpdateState.upToDate);
    expect(find.text('UP TO DATE'), findsNothing);
    expect(find.text('Update'), findsNothing);

    await open(
      const InstalledSkill(
        inventoryKey: 'external:action-demo',
        name: 'external-action-demo',
        path: '/Users/test/.codex/skills/external-action-demo',
        agents: ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/Users/test/.codex/skills/external-action-demo',
            version: '',
          ),
        ],
      ),
    );
    expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('installed Hub detail stays local-first through Hub failure', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    final gateway = FakeSkillsGateway(
      detailErrors: const [
        SkillsException(
          'Hub is offline',
          kind: SkillsFailureKind.offline,
          isOffline: true,
        ),
      ],
      localDetail: const SkillDetail(
        name: 'local-skill',
        source: 'Local cache',
        markdown: '# Available offline',
        immutableVersion: 'v1',
        files: [SkillFile(path: 'SKILL.md', contents: '# Available offline')],
        installationTargets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/tmp/local-skill',
            version: 'v1',
          ),
        ],
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('local-skill').first);
    await tester.pumpAndSettle();

    expect(find.text('Available offline'), findsOneWidget);
    expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
    expect(find.text('Service temporarily unavailable'), findsNothing);
    expect(find.text('Can’t connect to SkillsGo'), findsNothing);
    expect(find.text('CHECK FAILED'), findsNothing);
  });

  testWidgets('Hub enrichment preserves installed-detail geometry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    final remote = Completer<SkillDetail>();
    final gateway = FakeSkillsGateway(detailCompleter: remote);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('local-skill').first);
    await tester.pump();
    await tester.pump();

    expect(find.text('Local'), findsOneWidget);
    expect(find.byKey(const Key('installation-scope-panel')), findsOneWidget);
    final scopeBefore = tester
        .getTopLeft(find.byKey(const Key('installation-scope-panel')))
        .dy;

    remote.complete(defaultRemoteDetail);
    await tester.pumpAndSettle();

    expect(find.text('Build reliable Flutter products.'), findsOneWidget);
    final scopeAfter = tester
        .getTopLeft(find.byKey(const Key('installation-scope-panel')))
        .dy;
    expect(scopeAfter, scopeBefore);
  });
}
