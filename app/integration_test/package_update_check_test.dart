/*
 * [INPUT]: Depends on the rendered App, bundled CLI, JourneyRuntime filesystem/Hub/schema isolation, and immutable v1.2.0/v1.3.0 releases of the SkillsGo-owned public versioned fixture Repository.
 * [OUTPUT]: Verifies that a user installs the older Repository release, sees one Catalog-derived Package card, updates that exact Package, persists v1.3.0 global YAML/Lock and Scope Package Store state, and observes no update card on the next check.
 * [POS]: Serves as the black-box macOS App update lifecycle journey orchestrated by e2e/app.
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

  registerPackageUpdatePreviewJourney();
}

void registerPackageUpdatePreviewJourney() {
  testWidgets(
    'shows Catalog updates for an older installed public fixture release',
    (tester) async {
      final runtime = await JourneyRuntime.start('package_update_preview');
      addTearDown(runtime.close);
      final sandbox = runtime.sandbox.path;
      final hubOrigin = runtime.hubOrigin;
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
      await tester.tap(find.byKey(const Key('package-install-all')));
      await _pumpUntil(
        tester,
        _textEither('Install all skills to', '安装所有技能到'),
        timeout: const Duration(seconds: 30),
      );
      final installFinder = find.byKey(
        const ValueKey('install-location-submit'),
      );
      await _pumpUntilEnabledPrimaryButton(tester, installFinder);
      final install = tester.widget<PrimaryCapsuleButton>(installFinder);
      expect(install.onPressed, isNotNull);
      install.onPressed!();
      await tester.pump();
      const repository = 'github.com/skillsgo/e2e-versioned-skills';
      const newCoordinate = '$repository@v1.3.0';
      await _pumpUntilFile(
        tester,
        File('$sandbox/test-agent/skills/alpha/SKILL.md'),
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
      final manifest = File('$sandbox/home/.agents/skills.yaml');
      expect(manifest.readAsStringSync(), contains('v1.2.0'));

      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('$hubOrigin/api/v1/$repository/versions/v1.3.0'),
        );
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, HttpStatus.ok);
      } finally {
        client.close(force: true);
      }

      final libraryDestination = find.byKey(
        const ValueKey('primary-destination-library'),
      );
      await _pumpUntil(
        tester,
        libraryDestination.hitTestable(),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(libraryDestination.hitTestable());
      await _pumpUntil(
        tester,
        find.byKey(const Key('library-update-filter')),
        timeout: const Duration(seconds: 45),
      );
      await tester.tap(_textEither('Updates', '更新'));
      const packagePath = 'github.com/skillsgo/e2e-versioned-skills';
      final packageCard = find.byKey(
        const ValueKey('library-package-update-$packagePath'),
      );
      await _pumpUntil(
        tester,
        packageCard,
        timeout: const Duration(seconds: 45),
      );
      expect(packageCard, findsOneWidget);
      expect(find.text('beta'), findsNothing);

      final updatePackage = find.byKey(
        const ValueKey('library-package-update-action-$packagePath'),
      );
      await _pumpUntilEnabledButton(tester, updatePackage);
      await tester.tap(updatePackage);
      final alpha = File('$sandbox/test-agent/skills/alpha/SKILL.md');
      await _pumpUntilFileContains(
        tester,
        alpha,
        'Version 1.3.0 fixture content.',
      );
      await _pumpUntilFileContains(tester, manifest, 'v1.3.0');
      expect(
        alpha.readAsStringSync(),
        contains('Version 1.3.0 fixture content.'),
      );
      expect(manifest.readAsStringSync(), contains('v1.3.0'));
      expect(
        File('$sandbox/home/.agents/skills-lock.yaml').existsSync(),
        isTrue,
      );
      expect(
        File(
          '$sandbox/home/.agents/.skillsgo/packages/$newCoordinate/skills/alpha/SKILL.md',
        ).existsSync(),
        isTrue,
      );

      await _pumpUntilGone(
        tester,
        packageCard,
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

Future<void> _pumpUntilFileContains(
  WidgetTester tester,
  File file,
  String expected,
) async {
  final deadline = DateTime.now().add(const Duration(minutes: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (file.existsSync() && file.readAsStringSync().contains(expected)) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    file.existsSync() ? file.readAsStringSync() : null,
    contains(expected),
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

Future<void> _pumpUntilEnabledPrimaryButton(
  WidgetTester tester,
  Finder finder,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final buttons = tester.widgetList<PrimaryCapsuleButton>(finder);
    if (buttons.isNotEmpty && buttons.first.onPressed != null) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(tester.widget<PrimaryCapsuleButton>(finder).onPressed, isNotNull);
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
