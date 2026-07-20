/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies Mandatory Onboarding and reusable native interaction behavior.
 * [POS]: Serves as one focused rendered desktop behavior suite within the App test workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skillsgo/app.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/ui/brand.dart';
import 'package:skillsgo/ui/subscription_segmented_switch.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  testWidgets(
    'clean installation completes two-step Mandatory Onboarding before Library',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = FakeSkillsGateway(
        onboardingState: const OnboardingState(
          completed: false,
          step: OnboardingStep.welcome,
        ),
        agentNames: const ['codex', 'claude-code'],
        projectsToAdd: const [
          AddedProject(
            id: 'project-a',
            name: 'Project A',
            path: '/work/project-a',
            accessState: ProjectAccessState.accessible,
          ),
          AddedProject(
            id: 'project-b',
            name: 'Project B',
            path: '/work/project-b',
            accessState: ProjectAccessState.accessible,
          ),
        ],
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to SkillsGo'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-skillsgo-logo')), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Discover'), findsNothing);
      expect(gateway.projectLoads, 0);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Add your projects'), findsOneWidget);
      expect(find.text('Add now'), findsOneWidget);
      expect(find.textContaining('skills.sh'), findsNothing);
      expect(find.text('Start Using SkillsGo'), findsOneWidget);

      await tester.tap(find.text('Add now'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('onboarding-project-project-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('onboarding-project-project-b')),
        findsOneWidget,
      );
      expect(find.text('Start Using SkillsGo'), findsOneWidget);

      await tester.tap(find.text('Start Using SkillsGo'));
      await tester.pumpAndSettle();

      expect(gateway.onboardingCompletions, 1);
      expect(find.text('local-skill'), findsOneWidget);
    },
  );

  testWidgets('Onboarding startup errors remain retryable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      onboardingState: const OnboardingState(
        completed: false,
        step: OnboardingStep.welcome,
      ),
      onboardingLoadErrors: [StateError('preferences unavailable')],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('SkillsGo could not load setup.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SkillsGo'), findsOneWidget);
  });

  testWidgets(
    'Onboarding project strip exposes hover removal without deleting files',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = FakeSkillsGateway(
        onboardingState: const OnboardingState(
          completed: false,
          step: OnboardingStep.projects,
        ),
        addedProjects: const [
          AddedProject(
            id: 'project-a',
            name: 'Project A',
            path: '/work/project-a',
            accessState: ProjectAccessState.accessible,
          ),
        ],
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();

      final project = find.byKey(
        const ValueKey('onboarding-project-project-a'),
      );
      final remove = find.byKey(
        const ValueKey('onboarding-remove-project-project-a'),
      );
      expect(project, findsOneWidget);
      expect(find.text('1 project added'), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(project));
      await tester.pump(const Duration(milliseconds: 120));
      expect(remove, findsOneWidget);

      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(project, findsNothing);
      expect(gateway.projects, isEmpty);
    },
  );

  testWidgets('Mandatory Onboarding primary actions support the keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      onboardingState: const OnboardingState(
        completed: false,
        step: OnboardingStep.welcome,
      ),
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Add your projects'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to SkillsGo'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(gateway.onboardingCompletions, 1);
    expect(find.text('Discover'), findsOneWidget);
  });

  testWidgets(
    'Onboarding persists the next step before exposing its final action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saved = Completer<void>();
      final gateway = FakeSkillsGateway(
        onboardingState: const OnboardingState(
          completed: false,
          step: OnboardingStep.welcome,
        ),
        onboardingStepSaveCompleter: saved,
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pump();

      expect(find.text('Welcome to SkillsGo'), findsOneWidget);
      expect(find.text('Start Using SkillsGo'), findsNothing);
      saved.complete();
      await tester.pumpAndSettle();
      expect(find.text('Start Using SkillsGo'), findsOneWidget);
    },
  );

  testWidgets(
    'Onboarding waits for projects before enabling its final action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final projects = Completer<List<AddedProject>>();
      final gateway = FakeSkillsGateway(
        onboardingState: const OnboardingState(
          completed: false,
          step: OnboardingStep.projects,
        ),
        projectLoadCompleter: projects,
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pump();

      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
      await tester.tap(find.text('Start Using SkillsGo'));
      await tester.pump();
      expect(gateway.onboardingCompletions, 0);

      projects.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('Add now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('subscription switch preserves its sliding selection motion', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SubscriptionSegmentedSwitch(
            options: const [
              SubscriptionSwitchOption(
                label: 'All',
                icon: HugeIcons.strokeRoundedLayers01,
              ),
              SubscriptionSwitchOption(
                label: 'Updates',
                icon: HugeIcons.strokeRoundedArrowReloadVertical,
              ),
            ],
            selectedIndex: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    final thumb = find.byKey(const Key('subscription-switch-thumb'));
    final thumbSize = tester.getSize(thumb);
    final switchSize = tester.getSize(find.byType(SubscriptionSegmentedSwitch));
    expect(thumbSize.height, 28);
    expect(thumbSize.width * 2 + 8, switchSize.width);
    final start = tester.getTopLeft(thumb).dx;
    await tester.tap(find.text('Updates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getTopLeft(thumb).dx;
    var furthest = midway;
    var passedTarget = false;
    var rebounded = false;
    final target = start + thumbSize.width;
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final position = tester.getTopLeft(thumb).dx;
      furthest = math.max(furthest, position);
      if (position > target + .1) passedTarget = true;
      if (passedTarget && position < target - .1) rebounded = true;
    }

    expect(selected, 1);
    expect(midway, greaterThan(start));
    expect(midway, lessThan(target));
    expect(furthest, greaterThan(target));
    expect(furthest, lessThanOrEqualTo(target + 2.51));
    expect(rebounded, isTrue);
  });

  testWidgets('subscription switch adapts its width to localized labels', (
    tester,
  ) async {
    Future<double> pumpSwitch(List<String> labels) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SubscriptionSegmentedSwitch(
              options: [
                SubscriptionSwitchOption(
                  label: labels[0],
                  icon: HugeIcons.strokeRoundedLayers01,
                ),
                SubscriptionSwitchOption(
                  label: labels[1],
                  icon: HugeIcons.strokeRoundedArrowReloadVertical,
                ),
              ],
              selectedIndex: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(SubscriptionSegmentedSwitch)).width;
    }

    final compactWidth = await pumpSwitch(['All', 'Updates']);
    final localizedWidth = await pumpSwitch(['全部已安装项目', '存在可用更新的项目']);

    expect(localizedWidth, greaterThan(compactWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull-progress ink drop keeps its animation ticker enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SkillsLoadingShape(progress: .45)),
    );

    final tickerMode = tester.widget<TickerMode>(
      find
          .ancestor(
            of: find.byKey(const Key('skills-loading-ink-drop')),
            matching: find.byType(TickerMode),
          )
          .first,
    );
    expect(tickerMode.enabled, isTrue);
  });
}
