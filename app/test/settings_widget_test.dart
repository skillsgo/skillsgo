/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Settings navigation, motion, CLI, reminder, Agent, Hub Origin, risk-policy, and local Library refresh behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/agent_logo.dart';
import 'package:skillsgo/ui/nested_navigation.dart';

import 'support/fake_skills_gateway.dart';
import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('leaderboard tabs change selection without moving layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    final indicator = find.byKey(const Key('discover-tab-indicator'));
    final hotIndicatorX = tester.getTopLeft(indicator).dx;
    final rankingX = tester
        .getTopLeft(find.byKey(const ValueKey('discover-tab-ranking')))
        .dx;
    await tester.tap(find.text('Ranking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final movingIndicatorX = tester.getTopLeft(indicator).dx;
    expect(movingIndicatorX, lessThan(hotIndicatorX));
    expect(movingIndicatorX, greaterThan(rankingX));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(indicator).dx, closeTo(rankingX, 0.01));
    expect(isSemanticallySelected(tester, 'Ranking'), isTrue);
    expect(find.text('It’s nice to know a little more.'), findsNothing);
    expect(find.byKey(const Key('discovery-options-mode')), findsOneWidget);
  });

  testWidgets('reduced motion keeps tab selection immediate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ranking'));
    await tester.pump();

    final rankingSemantics = find.bySemanticsLabel('Ranking');
    expect(
      List.generate(
        rankingSemantics.evaluate().length,
        (index) => tester.getSemantics(rankingSemantics.at(index)),
      ).any((node) => node.flagsCollection.isSelected == Tristate.isTrue),
      isTrue,
    );
  });

  testWidgets('keyboard focus can activate the first leaderboard tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(isSemanticallySelected(tester, 'Ranking'), isTrue);
  });

  testWidgets('Settings shows a missing CLI and accepts a custom path', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(cliReady: false);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(find.text('MISSING'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('cli-path')),
        matching: find.byType(EditableText),
      ),
      '/custom/skills',
    );
    await tester.ensureVisible(find.text('Save & detect'));
    await tester.tap(find.text('Save & detect'));
    await tester.pumpAndSettle();

    expect(gateway.savedPath, '/custom/skills');
  });

  testWidgets('Settings secondary body enters with a short depth motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders'));
    await tester.pump();

    final body = find.byKey(const Key('skills-destination-body'));
    final fade = tester.widget<FadeTransition>(body);
    final slide = fade.child! as SlideTransition;
    final scale = slide.child! as ScaleTransition;
    expect(find.byKey(const Key('update-reminder-label')), findsOneWidget);
    expect(fade.opacity.value, closeTo(.86, .001));
    expect(slide.position.value.dy, closeTo(.012, .001));
    expect(scale.scale.value, closeTo(.985, .001));

    await tester.pump(const Duration(milliseconds: 90));
    expect(fade.opacity.value, inExclusiveRange(.86, 1));
    expect(scale.scale.value, inExclusiveRange(.985, 1));

    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
    expect(slide.position.value, Offset.zero);
    expect(scale.scale.value, 1);
  });

  testWidgets('Settings secondary body skips motion when animations are off', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders'));
    await tester.pump();

    final body = find.byKey(const Key('skills-destination-body'));
    expect(body, findsOneWidget);
    expect(tester.widget(body), isA<KeyedSubtree>());
    expect(find.byKey(const Key('update-reminder-label')), findsOneWidget);
  });

  testWidgets('Settings keeps infrequent controls behind one advanced route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(SkillsGoApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    final settingsRail = find.byWidgetPredicate(
      (widget) => widget is SkillsSideRail,
      description: 'settings side rail',
    );
    expect(
      find.descendant(of: settingsRail, matching: find.byType(HugeIcon)),
      findsNWidgets(4),
    );
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    expect(find.text('Reminder settings'), findsNothing);
    expect(find.text('Choose which reminders to receive.'), findsNothing);
    final updateReminderLabel = tester.widget<Text>(
      find.byKey(const Key('update-reminder-label')),
    );
    final securityReminderLabel = tester.widget<Text>(
      find.byKey(const Key('security-reminder-label')),
    );
    expect(
      updateReminderLabel.textSpan!.toPlainText(),
      'Update reminders  Check for updates when Library opens.',
    );
    expect(
      securityReminderLabel.textSpan!.toPlainText(),
      'High-risk alerts  Notify you of new High or Critical risks in installed skills.',
    );
    expect(updateReminderLabel.maxLines, 1);
    expect(securityReminderLabel.maxLines, 1);
    expect(find.byKey(const Key('update-reminder')), findsOneWidget);
    expect(find.byKey(const Key('security-reminder')), findsOneWidget);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Hub Origin'), findsOneWidget);
    expect(find.text('Personal risk policy'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Storage'), findsNothing);
    expect(find.text('Color Scheme'), findsNothing);
    expect(find.text('About'), findsNothing);
  });

  testWidgets(
    'Advanced Settings can restart Onboarding without clearing data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway();
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('primary-destination-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('restart-onboarding')));
      await tester.tap(find.byKey(const Key('restart-onboarding')));
      await tester.pumpAndSettle();

      expect(gateway.onboardingResets, 1);
      expect(find.text('Welcome to SkillsGo'), findsOneWidget);
    },
  );

  testWidgets('Advanced Settings ends with the local Library refresh', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    final refresh = find.byKey(const Key('refresh-local-library'));
    final restart = find.byKey(const Key('restart-onboarding'));
    expect(refresh, findsOneWidget);
    expect(
      tester.getTopLeft(refresh).dy,
      greaterThan(tester.getTopLeft(restart).dy),
    );
    final projectLoads = gateway.projectLoads;
    final agentInspections = gateway.agentInspections;

    await tester.tap(refresh);
    await tester.pumpAndSettle();

    expect(gateway.projectLoads, projectLoads + 1);
    expect(gateway.agentInspections, agentInspections + 1);
    expect(find.text('Local Library refreshed.'), findsOneWidget);
  });

  testWidgets('reminder settings persist and drive the Library update prompt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      reminderSettings: const ReminderSettings(),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('primary-destination-library')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-update-reminder')), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-update-reminder')));
    await tester.pumpAndSettle();
    expect(find.text('Updates'), findsOneWidget);

    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-reminder')));
    await tester.pumpAndSettle();
    expect(gateway.reminderSettings.updateAvailable, isFalse);
  });

  testWidgets('Agents settings separates detected and supported Agents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    final gateway = FakeSkillsGateway(
      agentStatuses: const [
        AgentStatus(
          id: 'codex',
          displayName: 'Codex',
          installed: true,
          supportedScopes: [InstallationScope.project, InstallationScope.user],
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
          supportedScopes: [InstallationScope.project, InstallationScope.user],
          userTarget: AgentUserTarget(
            path: '/Users/test/.cursor/skills',
            exists: false,
          ),
        ),
      ],
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Cursor'), findsOneWidget);
    expect(find.text('Installed · 1'), findsOneWidget);
    expect(find.text('Not installed · 1'), findsOneWidget);
    expect(find.byKey(const Key('installed-agents-group')), findsOneWidget);
    expect(find.byKey(const Key('not-installed-agents-group')), findsOneWidget);
    expect(find.byType(AgentLogo), findsNWidgets(2));
    expect(find.textContaining('/Users/test/.codex/skills'), findsOneWidget);
    expect(find.textContaining('/Users/test/.agents/skills'), findsOneWidget);
  });

  testWidgets('Agent inspection failure keeps detection retry actionable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(
      agentInspectionError: const SkillsException('malformed agents'),
    );
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(
      find.text('Agent detection data is unavailable. Run detection again.'),
      findsOneWidget,
    );
    expect(find.text('Detect again'), findsOneWidget);
    final inspectionsBeforeRetry = gateway.agentInspections;
    await tester.tap(find.text('Detect again'));
    await tester.pumpAndSettle();
    expect(gateway.agentInspections, inspectionsBeforeRetry + 1);
  });

  testWidgets('Agents exposes CLI recovery when the runtime is missing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      SkillsGoApp(gateway: FakeSkillsGateway(cliReady: false)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agents'));
    await tester.pumpAndSettle();

    expect(find.text('MISSING'), findsOneWidget);
    expect(find.text('INCOMPATIBLE'), findsNothing);
    expect(
      find.textContaining('required SkillsGo component is missing'),
      findsWidgets,
    );
  });

  testWidgets('Hub Origin can be tested, saved, and reset immediately', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('hub-origin')),
        matching: find.byType(EditableText),
      ),
      'https://self-hosted.example',
    );
    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connection ready'), findsOneWidget);

    await tester.tap(find.text('Save Origin'));
    await tester.pumpAndSettle();
    expect(gateway.hubOrigin, 'https://self-hosted.example');

    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    expect(gateway.hubOrigin, 'https://hub.skillsgo.ai');
  });

  testWidgets('a Hub Origin is not saved when its protocol test fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(hubTestState: HealthState.invalid);
    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('primary-destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('hub-origin')),
        matching: find.byType(EditableText),
      ),
      'https://incompatible.example',
    );
    await tester.tap(find.text('Save Origin'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('did not return the SkillsGo Hub'),
      findsOneWidget,
    );
    expect(gateway.hubOrigin, 'https://hub.skillsgo.ai');
  });

  testWidgets(
    'Critical-risk override persists while High confirmation stays required',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final gateway = FakeSkillsGateway();
      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('primary-destination-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      expect(find.text('Require confirmation for High risk'), findsOneWidget);
      await tester.tap(find.byKey(const Key('critical-risk-override')));
      await tester.pumpAndSettle();

      expect(gateway.riskPolicy.confirmHighRisk, isTrue);
      expect(gateway.riskPolicy.allowCriticalOverride, isTrue);
    },
  );
}
