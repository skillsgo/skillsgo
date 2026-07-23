/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies External installation removal, exact location counts, modal input isolation and scrim dismissal, the physical back-to-front console reveal, source-backed inline Tetris takeover identities, complete scrollable NEXT queues, localized/reduced-motion storytelling, and plan-bound Batch Takeover behavior.
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

Future<void> _showTakeoverDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('library-batch-takeover')));
  await tester.pump();
  await tester.pumpAndSettle();
}

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
      expect(find.descendant(of: rail, matching: find.text('6')), findsNothing);
      expect(find.descendant(of: rail, matching: find.text('2')), findsNothing);
      expect(
        find.descendant(of: rail, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rail, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rail, matching: find.byType(Badge)),
        findsNothing,
      );
      expect(find.text('Manage (6)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pump();
      expect(
        find.byKey(const Key('batch-takeover-console-back')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('batch-takeover-console-back-logo')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('batch-takeover-dialog')), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byKey(const Key('batch-takeover-console-back')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('batch-takeover-dialog')), findsNothing);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('batch-takeover-console-back')),
        findsNothing,
      );
      expect(find.byKey(const Key('batch-takeover-dialog')), findsOneWidget);
      expect(gateway.takeoverRequests, isEmpty);
      expect(
        find.byKey(const Key('batch-takeover-tetris-story')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('library-location-rail')), findsOneWidget);
      expect(find.text('Scattered across Agents'), findsNothing);
      expect(find.text('BEFORE'), findsNothing);
      expect(find.text('Drag to feel the disorder'), findsNothing);
      expect(
        find.byKey(const Key('batch-takeover-tetris-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('batch-takeover-status-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('batch-takeover-pending-queue')),
        findsOneWidget,
      );
      expect(find.text('external-demo'), findsWidgets);
      expect(
        find.byKey(const Key('batch-takeover-preservation-note')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('batch-takeover-modal-barrier')),
        findsOneWidget,
      );

      // Clicking a destination behind the console dismisses the modal without
      // allowing the underlying navigation target to receive the same click.
      await tester.tap(find.byKey(const Key('primary-destination-discover')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('batch-takeover-dialog')), findsNothing);
      expect(find.byKey(const Key('library-location-rail')), findsOneWidget);
      expect(gateway.takeoverRequests, isEmpty);

      await _showTakeoverDialog(tester);
      await tester.tap(find.text('Not now'));
      await tester.pump();
      expect(find.byKey(const Key('batch-takeover-dialog')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 650));
      expect(
        find.byKey(const Key('batch-takeover-console-back')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('batch-takeover-dialog')), findsNothing);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('batch-takeover-console-back')),
        findsNothing,
      );
      expect(gateway.takeoverRequests, isEmpty);

      await _showTakeoverDialog(tester);
      await tester.tap(find.text('Add to management'));
      await tester.pumpAndSettle();

      expect(gateway.takeoverRequests, hasLength(1));
      expect(gateway.takeoverRequests.single.plan.id, 'scope-plan');
      expect(
        gateway.takeoverRequests.single.scope.kind,
        BatchTakeoverScopeKind.all,
      );
      expect(
        find.byKey(const Key('batch-takeover-board-complete')),
        findsOneWidget,
      );
      final statLeft = tester
          .getTopLeft(find.byKey(const Key('batch-takeover-stat-value')).first)
          .dx;
      final checkLeft = tester
          .getTopLeft(
            find.byKey(const Key('batch-takeover-benefit-check')).first,
          )
          .dx;
      expect(statLeft, checkLeft);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(libraryLocation('Global'));
      await tester.pumpAndSettle();
      expect(find.text('Manage (2)'), findsOneWidget);
      await _showTakeoverDialog(tester);
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
      await _showTakeoverDialog(tester);
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
    await _showTakeoverDialog(tester);
    expect(
      find.byKey(const Key('batch-takeover-tetris-story')),
      findsOneWidget,
    );
    await tester.tap(find.text('Add to management'));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('batch-takeover-confirm')),
        matching: find.text('Adding skills to management…'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('batch-takeover-status-panel')),
      findsOneWidget,
    );
    final pendingButton = tester.widget<SecondaryCapsuleButton>(
      find.byKey(const Key('library-batch-takeover')),
    );
    expect(pendingButton.onPressed, isNull);
    expect(
      find.byKey(const Key('primary-destination-settings')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pump();
    expect(find.byKey(const Key('batch-takeover-dialog')), findsOneWidget);
    expect(find.byKey(const Key('library-location-rail')), findsOneWidget);

    takeover.complete(const BatchTakeoverResult(takenOver: 1, skipped: 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('batch-takeover-board-complete')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Manage zero remains available and opens the completed state without mutation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final gateway = FakeSkillsGateway(
        installed: false,
        takeoverPlan: const BatchTakeoverPlan(
          id: 'complete-plan',
          allEligibleCount: 0,
          userEligibleCount: 0,
        ),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      expect(find.text('Manage (0)'), findsOneWidget);
      final action = tester.widget<SecondaryCapsuleButton>(
        find.byKey(const Key('library-batch-takeover')),
      );
      expect(action.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('library-batch-takeover')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('batch-takeover-board-complete')),
        findsOneWidget,
      );
      expect(find.text('ALL CLEAR'), findsOneWidget);
      expect(find.byKey(const Key('batch-takeover-confirm')), findsNothing);
      expect(find.byKey(const Key('batch-takeover-close')), findsOneWidget);
      expect(gateway.takeoverRequests, isEmpty);
    },
  );

  testWidgets(
    'Batch Takeover moves only real successes and leaves skipped skills pending',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final gateway = FakeSkillsGateway(
        installed: false,
        takeoverPlan: const BatchTakeoverPlan(
          id: 'result-plan',
          allEligibleCount: 3,
          userEligibleCount: 3,
          previews: [
            BatchTakeoverPreview(
              name: 'alpha-skill',
              skillId: 'github.com/acme/skills/-/alpha',
              scope: InstallationScope.user,
            ),
            BatchTakeoverPreview(
              name: 'beta-skill',
              skillId: 'github.com/acme/skills/-/beta',
              scope: InstallationScope.user,
            ),
            BatchTakeoverPreview(
              name: 'changed-skill',
              skillId: 'github.com/acme/skills/-/changed',
              scope: InstallationScope.user,
            ),
          ],
        ),
        takeoverResult: const BatchTakeoverResult(
          takenOver: 2,
          skipped: 1,
          items: [
            BatchTakeoverItemResult(
              name: 'alpha-skill',
              skillId: 'github.com/acme/skills/-/alpha',
              status: BatchTakeoverItemStatus.takenOver,
            ),
            BatchTakeoverItemResult(
              name: 'beta-skill',
              skillId: 'github.com/acme/skills/-/beta',
              status: BatchTakeoverItemStatus.takenOver,
            ),
            BatchTakeoverItemResult(
              name: 'changed-skill',
              skillId: 'github.com/acme/skills/-/changed',
              status: BatchTakeoverItemStatus.skipped,
              reason: 'target-changed',
            ),
          ],
        ),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await _showTakeoverDialog(tester);

      expect(find.text('alpha skill'), findsOneWidget);
      expect(find.text('beta skill'), findsOneWidget);
      expect(find.text('changed skill'), findsOneWidget);
      await tester.tap(find.byKey(const Key('batch-takeover-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('batch-takeover-board-complete')),
        findsOneWidget,
      );
      expect(find.text('alpha skill'), findsNothing);
      expect(find.text('beta skill'), findsNothing);
      expect(find.text('changed skill'), findsNothing);
      expect(find.text('COMPLETE'), findsOneWidget);
      expect(find.text('Clear locations'), findsOneWidget);
      expect(find.text('Updates visible'), findsOneWidget);
      expect(find.text('Easy recovery'), findsOneWidget);
      expect(find.text('Versions clear'), findsOneWidget);
      expect(
        find.byKey(const Key('batch-takeover-pending-queue')),
        findsOneWidget,
      );
      expect(find.text('No skills are waiting'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '2',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '1',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == '3',
        ),
        findsOneWidget,
      );
      expect(
        find.text('3 SkillsGo organizer blocks complete the final rows'),
        findsNothing,
      );
      expect(find.text('Close'), findsOneWidget);
      expect(find.byKey(const Key('batch-takeover-close')), findsOneWidget);
    },
  );

  testWidgets('Batch Takeover failure stays in the dialog and offers retry', (
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
    await _showTakeoverDialog(tester);
    await tester.tap(find.byKey(const Key('batch-takeover-confirm')));
    await tester.pump();
    takeover.completeError(
      const SkillsException(
        'interrupted',
        kind: SkillsFailureKind.invalidLocalData,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('batch-takeover-dialog')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text(
        'Some local installation information is damaged or incompatible. Update or reinstall SkillsGo, then try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Managed by SkillsGo'), findsNothing);
    final plansBeforeRetry = gateway.takeoverPlanRequests.length;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(gateway.takeoverPlanRequests, hasLength(plansBeforeRetry + 1));
    expect(find.byKey(const Key('batch-takeover-dialog')), findsOneWidget);
  });

  testWidgets(
    'Chinese takeover story remains stable when animations are disabled',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      const path = '/Users/test/.codex/skills/my-review';
      await tester.pumpWidget(
        SkillsGoApp(
          gateway: FakeSkillsGateway(
            installed: false,
            language: AppLanguage.simplifiedChinese,
            libraryEntries: const [
              InstalledSkill(
                inventoryKey: 'external:my-review',
                name: 'my-review',
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
                  ),
                ],
              ),
            ],
            takeoverPlan: BatchTakeoverPlan(
              id: 'reduced-motion-plan',
              allEligibleCount: 15,
              userEligibleCount: 15,
              previews: [
                BatchTakeoverPreview(
                  name: 'acme-first',
                  skillId: 'github.com/acme/skills/-/first',
                  scope: InstallationScope.user,
                ),
                BatchTakeoverPreview(
                  name: 'acme-second',
                  skillId: 'github.com/acme/skills/-/second',
                  scope: InstallationScope.user,
                ),
                BatchTakeoverPreview(
                  name: 'other-first',
                  skillId: 'github.com/other/toolbox/-/first',
                  scope: InstallationScope.user,
                ),
                for (var index = 3; index <= 14; index++)
                  BatchTakeoverPreview(
                    name: 'acme-$index',
                    skillId: 'github.com/acme/skills/-/$index',
                    scope: InstallationScope.user,
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      await _showTakeoverDialog(tester);

      expect(
        find.byKey(const Key('batch-takeover-tetris-story')),
        findsOneWidget,
      );
      expect(find.text('散落在不同智能体中'), findsNothing);
      expect(find.text('纳入前'), findsNothing);
      expect(find.text('拖动一下，感受混乱'), findsNothing);
      expect(
        find.byKey(const Key('batch-takeover-status-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('batch-takeover-tetris-board')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('batch-takeover-pending-queue')),
        findsOneWidget,
      );
      final pendingList = tester.widget<ListView>(
        find.byKey(const Key('batch-takeover-pending-list')),
      );
      // NEXT contains every eligible Skill followed by the four localized
      // pain-point pieces, and remains independently scrollable.
      expect(pendingList.childrenDelegate.estimatedChildCount, 37);
      await tester.scrollUntilVisible(
        find.text('acme 14'),
        180,
        scrollable: find.descendant(
          of: find.byKey(const Key('batch-takeover-pending-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('acme 14'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('多个项目版本不一致'),
        180,
        scrollable: find.descendant(
          of: find.byKey(const Key('batch-takeover-pending-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('多个项目版本不一致'), findsOneWidget);
      expect(find.text('待纳入'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const Key('batch-takeover-status-panel')),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == '15',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('batch-takeover-pending-queue')),
          matching: find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == '19',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('暂时跳过'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('batch-takeover-status-panel')),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('batch-takeover-tetris-story')),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('batch-takeover-tetris-story')))
            .label,
        contains('纳入管理前，现有技能装在哪里、是不是最新、损坏后如何恢复，以及不同项目间的版本是否一致，都缺少清晰状态。'),
      );
    },
  );

  testWidgets(
    'takeover introduction opens only after entering Library and never repeats after skip',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final gateway = FakeSkillsGateway(
        installed: false,
        batchTakeoverPromptSeen: false,
        takeoverPlan: const BatchTakeoverPlan(
          id: 'automatic-plan',
          allEligibleCount: 2,
          userEligibleCount: 2,
        ),
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('batch-takeover-tetris-story')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('batch-takeover-tetris-story')),
        findsOneWidget,
      );
      expect(gateway.takeoverRequests, isEmpty);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(gateway.batchTakeoverPromptSeen, isTrue);
      expect(gateway.batchTakeoverPromptCompletions, 1);

      await tester.tap(find.byKey(const Key('primary-destination-discover')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-library')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('batch-takeover-tetris-story')),
        findsNothing,
      );
      expect(find.text('Manage (2)'), findsOneWidget);

      await _showTakeoverDialog(tester);
      expect(
        find.byKey(const Key('batch-takeover-tetris-story')),
        findsOneWidget,
      );
    },
  );
}
