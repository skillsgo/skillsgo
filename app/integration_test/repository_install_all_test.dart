/*
 * [INPUT]: Depends on Flutter integration_test, the real SkillsGo App entry point, isolated onboarding preferences, a disposable Hub, the built CLI, and the SkillsGo-owned public versioned fixture Repository.
 * [OUTPUT]: Verifies repository search, the repository-wide installation surface, bundled-CLI execution, YAML/Lock state, Scope Vendor, and ordinary-file Repository Projections.
 * [POS]: Serves as the first black-box macOS App-plus-CLI-plus-Hub journey orchestrated by e2e/app.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsgo/main.dart' as skillsgo;
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'repository search opens install-all location selection',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('onboarding_completed_v1', true);
      await skillsgo.runSkillsGoApp(initializeBinding: false);
      await windowManager.setSize(const Size(1400, 960));
      await windowManager.center();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final search = find.byKey(const Key('skill-search-input'));
      expect(search, findsOneWidget);
      await tester.enterText(
        search,
        'https://github.com/skillsgo/e2e-versioned-skills@v1.2.0',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);

      await _pumpUntil(
        tester,
        find.byKey(const Key('repository-install-all')),
        timeout: const Duration(minutes: 2),
      );
      expect(find.text('skillsgo / e2e-versioned-skills'), findsOneWidget);

      await tester.tap(find.byKey(const Key('repository-install-all')));
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

      final installAllLabels = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'Install all skills' || widget.data == '安装所有技能'),
      );
      expect(installAllLabels, findsWidgets);
      final installButtonFinder = find
          .ancestor(
            of: installAllLabels.last,
            matching: find.byType(FilledButton),
          )
          .first;
      await _pumpUntilEnabledButton(tester, installButtonFinder);
      final installButton = tester.widget<FilledButton>(installButtonFinder);
      expect(installButton.onPressed, isNotNull);
      installButton.onPressed!();
      await tester.pump();
      await _pumpUntilInstalled(tester);
      await _pumpUntilGone(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Install all skills to' ||
                  widget.data == '安装所有技能到'),
        ),
      );

      final sandbox = Platform.environment['SKILLSGO_E2E_SANDBOX'];
      expect(sandbox, isNotNull);
      final home = Directory('$sandbox/home');
      const coordinate = 'github.com/skillsgo/e2e-versioned-skills@v1.2.0';
      final manifest = File('${home.path}/.skillsgo/skillsgo.yaml');
      expect(manifest.existsSync(), isTrue);
      expect(File('${home.path}/.skillsgo/skillsgo-lock.yaml').existsSync(), isTrue);
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
          '${home.path}/.skillsgo/vendor/$coordinate/skills/resourceful/references/guide.md',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$sandbox/test-agent/skills/$coordinate/skills/alpha/SKILL.md',
        ).existsSync(),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _pumpUntilEnabledButton(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final buttons = tester.widgetList<FilledButton>(finder);
    if (buttons.isNotEmpty && buttons.first.onPressed != null) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(tester.widget<FilledButton>(finder).onPressed, isNotNull);
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsNothing);
}

Future<void> _pumpUntilInstalled(WidgetTester tester) async {
  final sandbox = Platform.environment['SKILLSGO_E2E_SANDBOX']!;
  final installed = File(
    '$sandbox/test-agent/skills/github.com/skillsgo/e2e-versioned-skills@v1.2.0/skills/alpha/SKILL.md',
  );
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
  expect(finder, findsWidgets);
}
