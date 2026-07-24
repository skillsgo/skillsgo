/*
 * [INPUT]: Depends on the rendered App, bundled CLI, disposable Hub, isolated Agent state, and immutable v1.2.0/v1.3.0 releases of the SkillsGo-owned public versioned fixture Repository.
 * [OUTPUT]: Verifies that a user installs the older Repository release, sees Catalog-derived availability, confirms the exact update, persists v1.3.0 YAML/Lock and Vendor state, and observes no update on the next check.
 * [POS]: Serves as the black-box macOS App update lifecycle journey orchestrated by e2e/app.
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
    'shows Catalog updates for an older installed public fixture release',
    (tester) async {
      final sandbox = Platform.environment['SKILLSGO_E2E_SANDBOX'];
      final hubOrigin = Platform.environment['SKILLSGO_HUB_URL'];
      expect(sandbox, isNotNull);
      expect(hubOrigin, isNotNull);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('onboarding_completed_v1', true);

      await skillsgo.runSkillsGoApp(initializeBinding: false);
      await windowManager.setSize(const Size(1400, 960));
      await windowManager.center();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final search = find.byKey(const Key('skill-search-input'));
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
      await tester.tap(find.byKey(const Key('repository-install-all')));
      await _pumpUntil(
        tester,
        _textEither('Install all skills to', '安装所有技能到'),
        timeout: const Duration(seconds: 30),
      );
      final installLabels = _textEither('Install all skills', '安装所有技能');
      final installFinder = find
          .ancestor(of: installLabels.last, matching: find.byType(FilledButton))
          .first;
      await _pumpUntilEnabledButton(tester, installFinder);
      final install = tester.widget<FilledButton>(installFinder);
      expect(install.onPressed, isNotNull);
      install.onPressed!();
      await tester.pump();
      const repository = 'github.com/skillsgo/e2e-versioned-skills';
      const oldCoordinate = '$repository@v1.2.0';
      const newCoordinate = '$repository@v1.3.0';
      await _pumpUntilFile(
        tester,
        File('$sandbox/test-agent/skills/$oldCoordinate/skills/alpha/SKILL.md'),
      );
      await _pumpUntilGone(
        tester,
        _textEither('Install all skills to', '安装所有技能到'),
        timeout: const Duration(minutes: 2),
      );
      final installationComplete = _textEither('Installation complete', '安装完成');
      await _pumpUntil(
        tester,
        installationComplete,
        timeout: const Duration(minutes: 2),
      );
      await _pumpUntilGone(
        tester,
        installationComplete,
        timeout: const Duration(seconds: 30),
      );
      final manifest = File('$sandbox/home/.skillsgo/skillsgo.yaml');
      expect(manifest.readAsStringSync(), contains('v1.2.0'));

      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('$hubOrigin/$repository/@v/v1.3.0.info'),
        );
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, HttpStatus.ok);
      } finally {
        client.close(force: true);
      }

      await tester.tap(
        find.byKey(const ValueKey('primary-destination-library')),
      );
      await _pumpUntil(
        tester,
        find.byKey(const Key('library-update-filter')),
        timeout: const Duration(seconds: 45),
      );
      await tester.tap(_textEither('Updates', '有更新'));
      await _pumpUntil(
        tester,
        find.text('alpha'),
        timeout: const Duration(seconds: 45),
      );
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsNothing);

      await tester.tap(
        find.byKey(
          const ValueKey(
            'library-select-hub:github.com/skillsgo/e2e-versioned-skills:alpha',
          ),
        ),
      );
      final updateSelected = find.byKey(const Key('library-update-selected'));
      await _pumpUntilEnabledButton(tester, updateSelected);
      await tester.tap(updateSelected);
      await _pumpUntil(
        tester,
        _textEither('Select targets to update', '选择要更新的目标'),
        timeout: const Duration(seconds: 45),
      );
      await tester.tap(_textEither('Update selected targets', '更新所选目标'));
      await _pumpUntil(
        tester,
        _textEither('Update results', '更新结果'),
        timeout: const Duration(minutes: 2),
      );

      final technicalDetails = _textEither('Technical details', '技术详情');
      if (technicalDetails.evaluate().isNotEmpty) {
        await tester.ensureVisible(technicalDetails.first);
        await tester.tap(technicalDetails.first);
        await tester.pumpAndSettle();
      }
      final resultText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | ');

      final alpha = File(
        '$sandbox/test-agent/skills/$newCoordinate/skills/alpha/SKILL.md',
      );
      expect(
        alpha.readAsStringSync(),
        contains('Version 1.3.0 fixture content.'),
        reason: resultText,
      );
      expect(
        manifest.readAsStringSync(),
        contains('v1.3.0'),
        reason: resultText,
      );
      expect(
        File('$sandbox/home/.skillsgo/skillsgo-lock.yaml').existsSync(),
        isTrue,
      );
      expect(
        File(
          '$sandbox/home/.skillsgo/vendor/$newCoordinate/skills/alpha/SKILL.md',
        ).existsSync(),
        isTrue,
      );

      await tester.tap(_textEither('Close', '关闭'));
      await _pumpUntilGone(
        tester,
        _textEither('Close', '关闭'),
        timeout: const Duration(seconds: 30),
      );
      await _pumpUntilGone(
        tester,
        find.text('alpha'),
        timeout: const Duration(seconds: 45),
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Finder _textEither(String english, String chinese) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && (widget.data == english || widget.data == chinese),
);

Future<void> _pumpUntilFile(WidgetTester tester, File file) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (!file.existsSync() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'Expected ${file.path}. Visible UI: '
        '${tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data).whereType<String>().join(' | ')}',
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

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  final installationFailed = _textEither('Installation failed', '安装失败');
  while (finder.evaluate().isNotEmpty &&
      installationFailed.evaluate().isEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    finder,
    findsNothing,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .join(' | '),
  );
}
