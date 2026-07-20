/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies External installation removal plus exact location counts and plan-bound Batch Takeover behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/brand.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('External Installation stays visible and exposes exact removal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    const path = '/Users/test/.codex/skills/external-demo';
    const entry = InstalledSkill(
      inventoryKey: 'external:abc',
      name: 'external-demo',
      path: path,
      agents: ['codex'],
      targetCount: 1,
      provenance: LibraryProvenance.external,
      versions: [],
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.user,
          path: path,
          version: '',
          mode: InstallationMode.external,
        ),
      ],
    );
    const detail = SkillDetail(
      name: 'external-demo',
      source: 'External',
      markdown: '# External instructions',
      riskAssessment: SkillRiskAssessment.unknown,
      files: [
        SkillFile(path: 'SKILL.md', contents: '# External instructions'),
        SkillFile(
          path: 'scripts/run.sh',
          contents: '#!/bin/sh',
          executable: true,
        ),
      ],
    );
    await tester.pumpWidget(
      SkillsGoApp(
        gateway: FakeSkillsGateway(
          installed: false,
          libraryEntries: const [entry],
          localDetail: detail,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();

    expect(find.text('External installation'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('library-select-external:abc')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-selection-bar')), findsOneWidget);
    final removeButtonFinder = find.byKey(const Key('library-manage-selected'));
    final removeButton = tester.widget<TextButton>(removeButtonFinder);
    final removeButtonContext = tester.element(removeButtonFinder);
    expect(
      removeButton.style?.foregroundColor?.resolve(const {}),
      removeButtonContext.skillsComponents.statusDangerOnInverse,
    );
    await tester.tap(find.text('external-demo').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('installed-detail-back')), findsOneWidget);
    expect(
      find.byKey(const Key('installed-detail-skill-avatar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('installed-detail-scroll-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('installed-detail-instructions')),
      findsOneWidget,
    );
    expect(find.text(path), findsNothing);
    await tester.tap(find.byTooltip('Show target details'));
    await tester.pumpAndSettle();
    expect(find.text(path), findsOneWidget);
    expect(find.text('scripts/run.sh'), findsNothing);
    expect(find.text('Risk unknown'), findsNothing);
    expect(find.textContaining('scripts or executable content'), findsNothing);

    await tester.tap(find.byTooltip('Back to Library'));
    await tester.pumpAndSettle();
    expect(find.text('external-demo'), findsWidgets);
    expect(find.text('External installation'), findsWidgets);
  });

  testWidgets(
    'Library Batch Takeover follows All, Global, and Project locations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      const path = '/Users/test/.codex/skills/external-demo';
      const alpha = AddedProject(
        id: 'alpha',
        name: 'Alpha',
        description: '',
        path: '/work/alpha',
        accessState: ProjectAccessState.accessible,
      );
      const beta = AddedProject(
        id: 'beta',
        name: 'Beta',
        description: '',
        path: '/work/beta',
        accessState: ProjectAccessState.accessible,
      );
      final gateway = FakeSkillsGateway(
        installed: false,
        addedProjects: const [alpha, beta],
        libraryEntries: const [
          InstalledSkill(
            inventoryKey: 'external:abc',
            name: 'external-demo',
            path: path,
            agents: ['codex'],
            targetCount: 1,
            provenance: LibraryProvenance.external,
            targets: [
              SkillInstallationTarget(
                agent: 'codex',
                scope: InstallationScope.user,
                path: path,
                version: '',
                mode: InstallationMode.external,
              ),
            ],
          ),
        ],
        takeoverPlan: const BatchTakeoverPlan(
          id: 'scope-plan',
          allEligibleCount: 6,
          userEligibleCount: 2,
          eligibleCountByProjectRoot: {'/work/alpha': 3, '/work/beta': 1},
        ),
        takeoverResult: const BatchTakeoverResult(takenOver: 2, skipped: 1),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      final rail = find.byKey(const Key('library-location-rail'));
      expect(
        find.descendant(of: rail, matching: find.text('6')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rail, matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rail, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rail, matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.text('Manage (6)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();
      expect(gateway.takeoverRequests, isEmpty);
      expect(
        find.text('Manage existing skills with SkillsGo?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(gateway.takeoverRequests, isEmpty);

      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to management'));
      await tester.pumpAndSettle();

      expect(gateway.takeoverRequests, hasLength(1));
      expect(gateway.takeoverRequests.single.plan.id, 'scope-plan');
      expect(
        gateway.takeoverRequests.single.scope.kind,
        BatchTakeoverScopeKind.all,
      );
      expect(
        find.text('2 skills added to management, 1 skipped.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(libraryLocation('Global'));
      await tester.pumpAndSettle();
      expect(find.text('Manage (2)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to management'));
      await tester.pumpAndSettle();
      expect(
        gateway.takeoverRequests.last.scope.kind,
        BatchTakeoverScopeKind.user,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(libraryLocation('Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('Manage (3)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to management'));
      await tester.pumpAndSettle();
      expect(
        gateway.takeoverRequests.last.scope.kind,
        BatchTakeoverScopeKind.project,
      );
      expect(gateway.takeoverRequests.last.scope.projectRoot, '/work/alpha');
    },
  );

  testWidgets('Library Batch Takeover publishes next-frame progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final takeover = Completer<BatchTakeoverResult>();
    final gateway = FakeSkillsGateway(
      installed: false,
      takeoverCompleter: takeover,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-batch-takeover')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to management'));
    await tester.pump();

    expect(find.text('Adding skills to management…'), findsOneWidget);
    final pendingButton = tester.widget<SecondaryCapsuleButton>(
      find.byKey(const Key('library-batch-takeover')),
    );
    expect(pendingButton.onPressed, isNull);
    expect(
      find.byKey(const Key('primary-destination-settings')),
      findsOneWidget,
    );

    takeover.complete(const BatchTakeoverResult(takenOver: 1, skipped: 0));
    await tester.pumpAndSettle();
    expect(
      find.text('1 skills added to management, 0 skipped.'),
      findsOneWidget,
    );
  });
}
