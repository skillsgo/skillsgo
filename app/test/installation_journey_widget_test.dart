/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Remote-detail restoration and installation planning, risk, recovery, and target behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/native_components.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets(
    'remote detail stays inside Discover and restores the originating list',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
      await tester.pumpAndSettle();

      await tester.enterText(searchInput(), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('primary-folder-shell')), findsOneWidget);
      expect(find.byKey(const Key('detail-instructions')), findsOneWidget);
      expect(searchInput(), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('discover-detail-motion'))),
        tester.getTopLeft(find.byKey(const Key('discover-body-stack'))),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('discover-detail-motion'))),
        tester.getSize(find.byKey(const Key('discover-body-stack'))),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail-instructions')), findsNothing);
      expect(find.text('Flutter Pro'), findsOneWidget);
      expect(
        tester.widget<EditableText>(searchInput()).controller.text,
        'flutter',
      );
    },
  );

  testWidgets('installation selector keeps explicit project and Agent targets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    const projectA = AddedProject(
      id: 'project-a',
      name: 'Project A',
      path: '/work/project-a',
      accessState: ProjectAccessState.accessible,
    );
    const projectB = AddedProject(
      id: 'project-b',
      name: 'Project B',
      path: '/work/project-b',
      accessState: ProjectAccessState.accessible,
    );
    const projectC = AddedProject(
      id: 'project-c',
      name: 'Project C',
      path: '/work/project-c',
      accessState: ProjectAccessState.accessible,
    );
    final gateway = FakeSkillsGateway(
      installed: false,
      agentNames: const ['codex', 'claude-code'],
      addedProjects: const [projectA],
      projectsToAdd: const [projectB, projectC],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pump();
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text('Selected projects'));
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('0 projects · 2 Agents'), findsOneWidget);

    await tester.tap(find.text('Add Project'));
    await tester.pump();
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Project B'), findsOneWidget);
    expect(find.text('Project C'), findsOneWidget);

    await tester.tap(
      find.ancestor(of: find.text('Project A'), matching: find.byType(InkWell)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('3 projects · 2 Agents'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      gateway.lastPlanSelections
          .map(
            (selection) =>
                '${selection.scope.name}:${selection.projectRoot}:${selection.agent}',
          )
          .toList(),
      [
        'project:/work/project-a:codex',
        'project:/work/project-a:claude-code',
        'project:/work/project-b:codex',
        'project:/work/project-b:claude-code',
        'project:/work/project-c:codex',
        'project:/work/project-c:claude-code',
      ],
    );
    expect(gateway.installCalls, 1);
  });

  testWidgets('installation selector does not expose installed target status', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final gateway = FakeSkillsGateway(installed: true);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'installed-target-status');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final card = find.byType(SkillCard).first;
    final cardTopBeforeInstall = tester.getTopLeft(card).dy;
    await tester.tap(find.text('Install').first);
    await tester.pumpAndSettle();
    final discoveryRequestsBeforeInstall = gateway.collections.length;

    expect(find.text('Installed'), findsNothing);
    final confirm = find.widgetWithText(
      PrimaryCapsuleButton,
      'Confirm Installation',
    );
    expect(tester.widget<PrimaryCapsuleButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(gateway.lastPlanSelections, hasLength(1));
    expect(gateway.lastPlanSelections.single.agent, 'codex');
    expect(gateway.lastPlanSelections.single.scope, InstallationScope.user);
    expect(gateway.installCalls, 1);
    expect(gateway.collections, hasLength(discoveryRequestsBeforeInstall));
    expect(tester.getTopLeft(card).dy, cardTopBeforeInstall);
    expect(find.text('Installation complete'), findsOneWidget);
    expect(
      find.text('The Skill is now available in the selected locations.'),
      findsOneWidget,
    );
    final successTextContext = tester.element(
      find.text('Installation complete'),
    );
    expect(
      tester.widget<Text>(find.text('Installation complete')).style?.fontWeight,
      FontWeight.w500,
    );
    expect(
      tester
          .widget<Text>(
            find.text('The Skill is now available in the selected locations.'),
          )
          .style
          ?.fontWeight,
      FontWeight.w400,
    );
    expect(
      DefaultTextStyle.of(successTextContext).style.decoration,
      isNot(TextDecoration.underline),
    );
  });

  testWidgets(
    'confirmed installation overwrites a Local Modification directly',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      final gateway = FakeSkillsGateway(
        installed: false,
        planConflictReason: 'local-modification',
      );
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.enterText(searchInput(), 'modified');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter Pro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
      );
      await tester.pumpAndSettle();

      expect(gateway.installCalls, 1);
      expect(find.text('Installation results'), findsOneWidget);
      expect(find.text('Review Installation Plan'), findsNothing);
      expect(find.byKey(const ValueKey('installation-matrix')), findsNothing);
    },
  );

  testWidgets('the install confirmation also confirms High risk', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    final gateway = FakeSkillsGateway(
      installed: false,
      remoteDetail: withoutInstallationTargets(
        defaultRemoteDetail,
        riskAssessment: SkillRiskAssessment.high,
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'risky');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pumpAndSettle();

    expect(gateway.installCalls, 1);
    expect(find.text('Installation results'), findsOneWidget);
    expect(find.textContaining('risk blocked'), findsNothing);
  });

  testWidgets('Critical risk still follows the Settings policy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 850));
    final gateway = FakeSkillsGateway(
      installed: false,
      remoteDetail: withoutInstallationTargets(
        defaultRemoteDetail,
        riskAssessment: SkillRiskAssessment.critical,
      ),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'critical');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PrimaryCapsuleButton, 'Confirm Installation'),
    );
    await tester.pumpAndSettle();

    expect(gateway.installCalls, 0);
    expect(find.text('Review Installation Plan'), findsNothing);
    expect(find.byKey(const ValueKey('installation-matrix')), findsNothing);
  });

  testWidgets('artifact detail failure is localized and retryable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      detailErrors: const [
        SkillsException(
          'raw artifact diagnostic',
          kind: SkillsFailureKind.artifactUnavailable,
        ),
      ],
      updateCheckErrors: const [
        SkillsException(
          'Update check is offline',
          kind: SkillsFailureKind.offline,
          isOffline: true,
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Artifact unavailable'), findsOneWidget);
    expect(find.text('raw artifact diagnostic'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Real instructions'), findsOneWidget);
    expect(gateway.detailLoads, 2);
  });

  testWidgets('artifact detail failure can return to the originating results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      detailErrors: const [
        SkillsException('raw server failure', kind: SkillsFailureKind.server),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'recoverable query');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    expect(find.text('Service temporarily unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-back')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(searchInput()).controller.text,
      'recoverable query',
    );
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'skill-card-${const SkillCoordinate(repositoryId: 'example/skills/flutter-pro', name: 'Flutter Pro').key}',
    );
  });

  testWidgets('detail exposes a localized loading state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final detail = Completer<SkillDetail>();
    final gateway = FakeSkillsGateway(
      installed: false,
      detailCompleter: detail,
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('detail-skeleton')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Loading auditable Skill detail')),
      findsOneWidget,
    );
    expect(find.text('Flutter Pro'), findsOneWidget);
    detail.complete(defaultRemoteDetail);
    await tester.pumpAndSettle();
    expect(find.text('Real instructions'), findsOneWidget);
  });

  testWidgets('installation selector only shows detected Agents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      installed: false,
      agentStatuses: const [
        AgentStatus(
          id: 'codex',
          displayName: 'Codex',
          installed: true,
          supportedScopes: [InstallationScope.user],
          userTarget: AgentUserTarget(
            path: '/Users/test/.codex/skills',
            exists: true,
          ),
          discoveryRoots: [
            '/Users/test/.codex/skills',
            '/Users/test/.agents/skills',
          ],
        ),
        AgentStatus(
          id: 'cursor',
          displayName: 'Cursor',
          installed: false,
          supportedScopes: [InstallationScope.user],
          userTarget: AgentUserTarget(
            path: '/Users/test/.cursor/skills',
            exists: false,
          ),
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.enterText(searchInput(), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Cursor'), findsNothing);
  });
}
