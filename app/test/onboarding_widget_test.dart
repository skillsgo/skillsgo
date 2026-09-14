/*
 * [INPUT]: Uses SkillsGoApp, rendered Flutter widgets, and the controllable SkillsGateway test double.
 * [OUTPUT]: Specifies the first-Library-entry Local Scan Notice including loading, failure, pre-scan guarantees, persisted deferral into a non-repeating restricted Library, Mandatory Onboarding, and reusable native interaction behavior.
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
import 'package:skillsgo/ui/native_components.dart';
import 'package:skillsgo/ui/subscription_segmented_switch.dart';

import 'support/fake_skills_gateway.dart';

void main() {
  testWidgets(
    'local scan notice explains privacy before project and usage access',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = FakeSkillsGateway(
        localScanNoticeAcknowledged: false,
        onboardingState: const OnboardingState(
          completed: true,
          step: OnboardingStep.projects,
        ),
      );

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Read these folders'), findsNothing);
      expect(gateway.projectLoads, 0);
      expect(gateway.usageLoads, 0);

      await tester.tap(find.text('Skills'));
      await tester.pump();

      expect(find.text('Read these folders'), findsOneWidget);
      final scanDialog = find.ancestor(
        of: find.text('Read these folders'),
        matching: find.byType(SkillsDialog),
      );
      expect(
        find.descendant(
          of: scanDialog,
          matching: find.byKey(const Key('local-scan-project-tags')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: scanDialog, matching: find.byType(HugeIcon)),
        findsNothing,
      );
      expect(
        find.text('Used to identify installed Skills and usage.'),
        findsOneWidget,
      );
      expect(find.text('project'), findsOneWidget);
      expect(find.text('/Users/test/Documents/project'), findsNothing);
      expect(
        find.text(
          'Processed only on this device. Files and conversations are never uploaded.',
        ),
        findsOneWidget,
      );
      expect(gateway.projectLoads, 0);
      expect(gateway.usageLoads, 0);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(gateway.localScanNoticeAcknowledged, isTrue);
      expect(find.text('Read these folders'), findsNothing);
      expect(gateway.projectLoads, greaterThan(0));
      expect(gateway.usageLoads, greaterThan(0));
    },
  );

  testWidgets('local scan notice defers into Library without scanning', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(localScanNoticeAcknowledged: false);

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pump();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Projects not read yet'), findsOneWidget);
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Read these folders'), findsNothing);
    expect(gateway.localScanNoticeAcknowledged, isFalse);
    expect(gateway.localScanNoticeDeferred, isTrue);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    await tester.tap(find.text('Discover'));
    await tester.pump();
    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();

    expect(find.text('Read these folders'), findsNothing);
    expect(find.text('Projects not read yet'), findsOneWidget);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    await tester.tap(find.text('Continue reading'));
    await tester.pumpAndSettle();

    expect(gateway.localScanNoticeAcknowledged, isTrue);
    expect(gateway.localScanNoticeDeferred, isFalse);
    expect(find.text('Projects not read yet'), findsNothing);
    expect(gateway.projectLoads, greaterThan(0));
    expect(gateway.usageLoads, greaterThan(0));
  });

  testWidgets('local scan deferral gives next-frame feedback before saving', (
    tester,
  ) async {
    final saving = Completer<void>();
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticeAcknowledgeCompleter: saving,
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pump();
    await tester.tap(find.text('Not now'));
    await tester.pump();

    final deferButton = find.ancestor(
      of: find.text('Not now'),
      matching: find.byType(SkillsButton),
    );
    expect(tester.widget<SkillsButton>(deferButton).enabled, isFalse);
    expect(find.text('Read these folders'), findsOneWidget);
    expect(gateway.localScanNoticeDeferred, isFalse);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    saving.complete();
    await tester.pumpAndSettle();
    expect(find.text('Projects not read yet'), findsOneWidget);
    expect(gateway.localScanNoticeDeferred, isTrue);
  });

  testWidgets('local scan deferral failure stays gated and retryable', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticeAcknowledgeErrors: [StateError('preferences unavailable')],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pump();
    await tester.tap(find.text('Not now'));
    await tester.pump();

    expect(
      find.text('SkillsGo could not save your setup progress. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Read these folders'), findsOneWidget);
    expect(gateway.localScanNoticeDeferred, isFalse);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Projects not read yet'), findsOneWidget);
    expect(gateway.localScanNoticeDeferred, isTrue);
  });

  testWidgets('deferred local scan remains inline after restart', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticeDeferred: true,
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();

    expect(find.text('Read these folders'), findsNothing);
    expect(find.text('Projects not read yet'), findsOneWidget);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);
  });

  testWidgets('deferred local scan stays usable in compact RTL layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      language: AppLanguage.arabic,
      localScanNoticeAcknowledged: false,
      localScanNoticeDeferred: true,
      localScanNoticePaths: const [
        '/Users/test/Documents/a-very-long-project-directory-name-one',
        '/Users/test/Documents/a-very-long-project-directory-name-two',
        '/Users/test/Documents/a-very-long-project-directory-name-three',
        '/Users/test/Documents/a-very-long-project-directory-name-four',
      ],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skill'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('local-scan-deferred-view')), findsOneWidget);
    expect(find.byKey(const Key('local-scan-project-tags')), findsOneWidget);
    expect(find.text('متابعة القراءة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local scan project tags use compact measured geometry', (
    tester,
  ) async {
    const firstPath = '/Users/test/Documents/MagicTutor';
    const secondPath = '/Users/test/Documents/MinerU';
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticePaths: const [
        firstPath,
        secondPath,
        '/Users/test/Documents/hyperframes',
      ],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pump();

    final firstTag = find.byKey(
      const ValueKey('local-scan-project-tag-$firstPath'),
    );
    final secondTag = find.byKey(
      const ValueKey('local-scan-project-tag-$secondPath'),
    );
    final privacy = find.byKey(const Key('local-scan-privacy-summary'));
    final firstRect = tester.getRect(firstTag);
    final secondRect = tester.getRect(secondTag);
    final decoration =
        tester.widget<Container>(firstTag).decoration! as BoxDecoration;

    expect(firstRect.height, closeTo(24, 1));
    expect(secondRect.left - firstRect.right, closeTo(6, .01));
    expect(tester.getTopLeft(privacy).dy - firstRect.bottom, closeTo(14, .01));
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('local scan paths stay readable and scrollable in RTL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const paths = [
      '/Users/test/Documents/a-very-long-project-directory-name-one',
      '/Users/test/Documents/a-very-long-project-directory-name-two',
      '/Users/test/Documents/a-very-long-project-directory-name-three',
      '/Users/test/Documents/a-very-long-project-directory-name-four',
    ];
    final gateway = FakeSkillsGateway(
      language: AppLanguage.arabic,
      localScanNoticeAcknowledged: false,
      localScanNoticePaths: paths,
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skill'));
    await tester.pump();

    final lastProject = find.text('a-very-long-project-directory-name-four');
    expect(find.text('قراءة هذه المجلدات'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(lastProject);
    await tester.pump();
    expect(lastProject, findsOneWidget);
    expect(find.text(paths.last), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local scan notice does not interrupt unfinished onboarding', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      onboardingState: const OnboardingState(
        completed: false,
        step: OnboardingStep.welcome,
      ),
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SkillsGo'), findsOneWidget);
    expect(find.text('Read these folders'), findsNothing);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);
  });

  testWidgets('Library skips the notice when macOS access is not expected', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticePaths: const [],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();

    expect(find.text('Read these folders'), findsNothing);
    expect(gateway.localScanNoticeAcknowledged, isFalse);
    expect(gateway.projectLoads, greaterThan(0));
    expect(gateway.usageLoads, greaterThan(0));
  });

  testWidgets(
    'acknowledged users still defer local scans until Library entry',
    (tester) async {
      final gateway = FakeSkillsGateway(localScanNoticeAcknowledged: true);

      await tester.pumpWidget(SkillsGoApp(gateway: gateway));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(gateway.projectLoads, 0);
      expect(gateway.usageLoads, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(gateway.projectLoads, 0);
      expect(gateway.usageLoads, 0);

      await tester.tap(find.text('Skills'));
      await tester.pumpAndSettle();
      expect(gateway.projectLoads, greaterThan(0));
      expect(gateway.usageLoads, greaterThan(0));
    },
  );

  testWidgets('Library access preflight failure stays gated and retryable', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticeRequirementErrors: [StateError('CLI unavailable')],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pump();

    expect(
      find.text('SkillsGo could not refresh the local Library.'),
      findsOneWidget,
    );
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Read these folders'), findsOneWidget);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);
  });

  testWidgets('Library access preflight is visible on the next frame', (
    tester,
  ) async {
    final preflight = Completer<List<String>>();
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticePathsCompleter: preflight,
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pump();

    final loading = find.byKey(const Key('local-scan-preflight-loading'));
    expect(loading, findsOneWidget);
    expect(tester.getSize(loading), const Size(220, 18));
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    preflight.complete(const ['/Users/test/Documents/project']);
    await tester.pump();
    expect(loading, findsNothing);
    expect(find.text('Read these folders'), findsOneWidget);
  });

  testWidgets('local scan notice startup renders localized loading semantics', (
    tester,
  ) async {
    final load = Completer<OnboardingState>();
    final gateway = FakeSkillsGateway(onboardingLoadCompleter: load);

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pump();

    expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
    final skeleton = find.byKey(
      const Key('local-scan-notice-loading-skeleton'),
    );
    expect(skeleton, findsOneWidget);
    expect(tester.getSize(skeleton), const Size(220, 18));
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    load.complete(
      const OnboardingState(completed: true, step: OnboardingStep.projects),
    );
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsOneWidget);
    expect(skeleton, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local scan acknowledgment gives next-frame feedback', (
    tester,
  ) async {
    final acknowledgment = Completer<void>();
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticeAcknowledgeCompleter: acknowledgment,
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    final nextButton = find.ancestor(
      of: find.text('Continue'),
      matching: find.byType(SkillsButton),
    );
    expect(tester.widget<SkillsButton>(nextButton).enabled, isFalse);
    expect(find.text('Read these folders'), findsOneWidget);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    acknowledgment.complete();
    await tester.pumpAndSettle();
    expect(find.text('Read these folders'), findsNothing);
    expect(gateway.projectLoads, greaterThan(0));
  });

  testWidgets('local scan notice acknowledgment failure stays retryable', (
    tester,
  ) async {
    final gateway = FakeSkillsGateway(
      localScanNoticeAcknowledged: false,
      localScanNoticeAcknowledgeErrors: [StateError('preferences unavailable')],
    );

    await tester.pumpWidget(SkillsGoApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skills'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(
      find.text('SkillsGo could not save your setup progress. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Read these folders'), findsOneWidget);
    expect(gateway.projectLoads, 0);
    expect(gateway.usageLoads, 0);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Read these folders'), findsNothing);
    expect(gateway.projectLoads, greaterThan(0));
  });

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
