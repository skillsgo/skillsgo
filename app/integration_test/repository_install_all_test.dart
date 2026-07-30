/*
 * [INPUT]: Depends on Flutter integration_test, the real SkillsGo App entry point, JourneyRuntime isolation, onboarding preferences, a disposable Hub/schema, the bundled CLI, and the SkillsGo-owned public versioned fixture Repository.
 * [OUTPUT]: Verifies Package search, the stable Package-wide installation action, bundled-CLI dry-run-to-apply execution, global YAML/Lock state, global Scope Package Store, and member-symlink Package Projections.
 * [POS]: Serves as the first black-box cross-platform App-plus-CLI-plus-Hub journey orchestrated by e2e/app.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsgo/main.dart' as skillsgo;
import 'package:skillsgo/ui/native_components.dart';
import 'package:window_manager/window_manager.dart';

import 'support/journey_runtime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  registerRepositoryInstallAllJourney();
}

void registerRepositoryInstallAllJourney() {
  testWidgets(
    'repository search opens install-all location selection',
    (tester) async {
      final runtime = await JourneyRuntime.start('repository_install_all');
      addTearDown(runtime.close);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('onboarding_completed_v1', true);
      await skillsgo.runSkillsGoApp(
        initializeBinding: false,
        gateway: runtime.gateway,
      );
      await windowManager.setSize(const Size(1400, 960));
      await windowManager.center();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final search = find.byKey(const Key('skill-search-input'));
      await _pumpUntil(tester, search, timeout: const Duration(seconds: 30));
      await tester.enterText(
        search,
        'https://github.com/skillsgo/e2e-versioned-skills@v1.2.0',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);

      await _pumpUntil(
        tester,
        find.byKey(const Key('package-install-all')),
        timeout: const Duration(minutes: 2),
      );
      expect(find.text('skillsgo / e2e-versioned-skills'), findsOneWidget);

      await tester.tap(find.byKey(const Key('package-install-all')));
      await _pumpUntil(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Install all skills to' ||
                  widget.data == '安装所有技能到'),
        ),
        timeout: const Duration(seconds: 30),
      );

      final installButtonFinder = find.byKey(
        const ValueKey('install-location-submit'),
      );
      await _pumpUntilEnabledButton(tester, installButtonFinder);
      final installButton = tester.widget<PrimaryCapsuleButton>(
        installButtonFinder,
      );
      expect(installButton.onPressed, isNotNull);
      installButton.onPressed!();
      await tester.pump();
      await _pumpUntilInstalled(tester, runtime.sandbox.path);
      await _pumpUntilGone(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Install all skills to' ||
                  widget.data == '安装所有技能到'),
        ),
      );

      final sandbox = runtime.sandbox.path;
      final home = runtime.home;
      const coordinate = 'github.com/skillsgo/e2e-versioned-skills@v1.2.0';
      final manifest = File('${home.path}/.agents/skills.yaml');
      expect(manifest.existsSync(), isTrue);
      expect(
        File('${home.path}/.agents/skills-lock.yaml').existsSync(),
        isTrue,
      );
      expect(
        manifest.readAsStringSync(),
        allOf(
          contains('github.com/skillsgo/e2e-versioned-skills:'),
          contains('- skills/alpha'),
          contains('- skills/resourceful'),
        ),
      );
      expect(
        File(
          '${home.path}/.skillsgo/packages/$coordinate/skills/resourceful/references/guide.md',
        ).existsSync(),
        isTrue,
      );
      expect(
        File('$sandbox/test-agent/skills/alpha/SKILL.md').existsSync(),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _pumpUntilEnabledButton(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final buttons = tester.widgetList<PrimaryCapsuleButton>(finder);
    if (buttons.isNotEmpty && buttons.first.onPressed != null) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(tester.widget<PrimaryCapsuleButton>(finder).onPressed, isNotNull);
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsNothing);
}

Future<void> _pumpUntilInstalled(WidgetTester tester, String sandbox) async {
  final installed = File('$sandbox/test-agent/skills/alpha/SKILL.md');
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (!installed.existsSync() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(installed.existsSync(), isTrue);
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    finder,
    findsWidgets,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .join(' | '),
  );
}
