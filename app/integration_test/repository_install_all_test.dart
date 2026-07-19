/*
 * [INPUT]: Depends on Flutter integration_test, the real SkillsGo App entry point, a disposable Hub, the built CLI, and public GitHub repository resolution.
 * [OUTPUT]: Verifies repository search, the repository-wide installation surface, bundled-CLI execution, and isolated installed filesystem state.
 * [POS]: Serves as the first black-box macOS App-plus-CLI-plus-Hub journey orchestrated by e2e/app.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:skillsgo/main.dart' as skillsgo;
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'repository search opens install-all location selection',
    (tester) async {
      await skillsgo.runSkillsGoApp(initializeBinding: false);
      await windowManager.setSize(const Size(1400, 960));
      await windowManager.center();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final search = find.byKey(const Key('skill-search-input'));
      expect(search, findsOneWidget);
      await tester.enterText(
        search,
        'https://github.com/vercel-labs/agent-skills',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);

      await _pumpUntil(
        tester,
        find.byKey(const Key('repository-install-all')),
        timeout: const Duration(minutes: 2),
      );
      expect(find.text('vercel-labs / agent-skills'), findsOneWidget);

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
      final installButton = tester.widget<FilledButton>(
        find
            .ancestor(
              of: installAllLabels.last,
              matching: find.byType(FilledButton),
            )
            .first,
      );
      expect(installButton.onPressed, isNotNull);
      installButton.onPressed!();
      await tester.pump();
      await _pumpUntilInstalled(tester);

      final sandbox = Platform.environment['SKILLSGO_E2E_SANDBOX'];
      expect(sandbox, isNotNull);
      final home = Directory('$sandbox/home');
      expect(File('${home.path}/.skillsgo/skillsgo.mod').existsSync(), isTrue);
      expect(File('${home.path}/.skillsgo/skillsgo.sum').existsSync(), isTrue);
      expect(
        File(
          '${home.path}/.agents/skills/vercel-composition-patterns/SKILL.md',
        ).existsSync(),
        isTrue,
      );
      expect(
        Link(
          '$sandbox/test-agent/skills/vercel-composition-patterns',
        ).existsSync(),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _pumpUntilInstalled(WidgetTester tester) async {
  final sandbox = Platform.environment['SKILLSGO_E2E_SANDBOX']!;
  final installed = File(
    '$sandbox/home/.agents/skills/vercel-composition-patterns/SKILL.md',
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
