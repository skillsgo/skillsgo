/*
 * [INPUT]: Depends on the rendered App, bundled CLI, JourneyRuntime filesystem/Hub/schema isolation, supported skills.sh locks, the public versioned Repository fixture, and the CLI user config projects section.
 * [OUTPUT]: Verifies exact All/User/Project adoption counts, Repository adoption, YAML/Lock, Scope Package Stores, coordinate Projections, preserved Skill bytes, and post-success rescans.
 * [POS]: Serves as the black-box macOS App-to-CLI existing-Skill management journey orchestrated by e2e/app.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/main.dart' as skillsgo;
import 'package:skillsgo/ui/native_components.dart';
import 'package:window_manager/window_manager.dart';

import 'support/journey_runtime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  registerAdoptionManagementJourney();
}

void registerAdoptionManagementJourney() {
  testWidgets(
    'manages existing skills by location and refreshes exact counts',
    (tester) async {
      final runtime = await JourneyRuntime.start('adoption_management');
      addTearDown(runtime.close);
      await runtime.gateway.discover(
        DiscoveryCollection.search,
        query: 'https://github.com/skillsgo/e2e-versioned-skills@v1.2.0',
      );
      final sandbox = runtime.sandbox.path;
      final globalTarget = Directory(
        '$sandbox/test-agent/skills/user-existing',
      );
      final projectRoot = Directory('$sandbox/adoption-project');
      final projectTarget = Directory(
        '${projectRoot.path}/.test-agent/skills/project-existing',
      );
      final userSkillBytes = utf8.encode(
        '---\nname: alpha\ndescription: Stable updated version of the versioned Alpha E2E fixture.\n---\n# Alpha\n\nVersion 1.1.0 fixture content.\n',
      );
      final projectSkillBytes = List<int>.from(userSkillBytes);
      globalTarget.createSync(recursive: true);
      projectTarget.createSync(recursive: true);
      File('${globalTarget.path}/SKILL.md').writeAsBytesSync(userSkillBytes);
      File(
        '${projectTarget.path}/SKILL.md',
      ).writeAsBytesSync(projectSkillBytes);
      _writeJson(File('$sandbox/home/.agents/.skill-lock.json'), {
        'version': 3,
        'skills': {'user-existing': _lockRecord('skills/alpha/SKILL.md')},
      });
      _writeJson(File('${projectRoot.path}/skills-lock.json'), {
        'version': 1,
        'skills': {'project-existing': _lockRecord('skills/alpha/SKILL.md')},
      });

      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('onboarding_completed_v1', true);
      await preferences.setBool('batch_adoption_prompt_seen_v1', true);
      await runtime.gateway.saveReminderSettings(
        const ReminderSettings(updateAvailable: false),
      );
      final configFile = File('$sandbox/home/.skillsgo/config.yaml');
      configFile.parent.createSync(recursive: true);
      configFile.writeAsStringSync(
        'schemaVersion: 1\n'
        'projects:\n'
        '  - ${jsonEncode(projectRoot.path)}\n',
      );
      await runtime.gateway.detectCli();
      await skillsgo.runSkillsGoApp(
        initializeBinding: false,
        gateway: runtime.gateway,
      );
      await windowManager.setSize(const Size(1400, 960));
      await windowManager.center();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final libraryDestination = find.byKey(
        const ValueKey('primary-destination-library'),
      );
      await _pumpUntil(tester, libraryDestination);
      await tester.tap(libraryDestination);
      final globalAdoption = _adoptionCount(1);
      final retry = find.text('Retry');
      await _pumpUntilEither(tester, globalAdoption, retry);
      if (retry.evaluate().isNotEmpty) {
        await tester.tap(retry);
      }
      await _pumpUntil(tester, globalAdoption);
      await _pumpUntil(tester, find.text('adoption-project'));

      await tester.tap(find.text('adoption-project'));
      await _pumpUntilAdoptionCount(tester, 1);
      await _executeAdoption(tester, adopted: 1, failed: 0);
      expect(File('${projectRoot.path}/skills.yaml').existsSync(), isTrue);
      expect(File('${projectRoot.path}/skills-lock.yaml').existsSync(), isTrue);
      expect(
        File(
          '${projectRoot.path}/.skillsgo/packages/github.com/skillsgo/e2e-versioned-skills@v1.2.0/skills/alpha/SKILL.md',
        ).readAsBytesSync(),
        projectSkillBytes,
      );
      expect(
        File(
          '${projectRoot.path}/.test-agent/skills/alpha/SKILL.md',
        ).readAsBytesSync(),
        projectSkillBytes,
      );
      expect(projectTarget.existsSync(), isFalse);
      await _pumpUntilGone(
        tester,
        find.byKey(const Key('library-adoption-review-enter')),
      );

      await tester.tap(_globalRailLabel());
      await _pumpUntilAdoptionCount(tester, 1);
      await _executeAdoption(tester, adopted: 1, failed: 0);
      await _pumpUntilGone(
        tester,
        find.byKey(const Key('library-adoption-review-enter')),
      );
      expect(File('$sandbox/home/.agents/skills.yaml').existsSync(), isTrue);
      expect(
        File('$sandbox/home/.agents/skills-lock.yaml').existsSync(),
        isTrue,
      );
      expect(
        File('$sandbox/test-agent/skills/alpha/SKILL.md').readAsBytesSync(),
        userSkillBytes,
      );
      expect(globalTarget.existsSync(), isFalse);

      await tester.tap(find.text('adoption-project'));
      await _pumpUntilGone(
        tester,
        find.byKey(const Key('library-adoption-review-enter')),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Map<String, Object> _lockRecord(String skillPath) => {
  'source': 'skillsgo/e2e-versioned-skills',
  'sourceType': 'github',
  'sourceUrl': 'https://github.com/skillsgo/e2e-versioned-skills.git',
  'ref': 'v1.2.0',
  'skillPath': skillPath,
  'installedAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};

void _writeJson(File file, Object value) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(value));
}

Finder _adoptionCount(int count) => find.descendant(
  of: find.byKey(const Key('library-adoption-review-enter')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data == 'Let SkillsGo manage $count external skills' ||
            widget.data == '将 $count 个外部技能交给 SkillsGo 管理'),
  ),
);

Finder _globalRailLabel() => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data == 'Global Skills' || widget.data == '全局 Skills'),
);

Future<void> _executeAdoption(
  WidgetTester tester, {
  required int adopted,
  required int failed,
}) async {
  final adoptionAction = find.byKey(const Key('library-adoption-review-enter'));
  await _pumpUntil(tester, adoptionAction);
  await tester.ensureVisible(adoptionAction);
  await tester.tap(adoptionAction);
  final confirmSelection = find.byKey(
    const Key('library-adoption-review-confirm'),
  );
  await _pumpUntilEnabledPrimaryButton(tester, confirmSelection);
  await tester.tap(confirmSelection);
  await _pumpUntil(tester, find.byKey(const Key('batch-adoption-dialog')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('batch-adoption-tetris-story')), findsOneWidget);
  final completed = find.byKey(const Key('batch-adoption-board-complete'));
  await _pumpUntil(tester, completed);
  expect(
    tester.widget<Semantics>(completed).properties.label,
    anyOf(
      '$adopted skills added to management, $failed failed.',
      '已纳入管理 $adopted 个技能，失败 $failed 个。',
    ),
  );
  final close = find.byKey(const Key('batch-adoption-close'));
  await tester.tap(close);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('batch-adoption-modal')), findsNothing);
}

Future<void> _pumpUntilAdoptionCount(WidgetTester tester, int count) =>
    _pumpUntil(tester, _adoptionCount(count));

Future<void> _pumpUntilEither(
  WidgetTester tester,
  Finder first,
  Finder second,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (first.evaluate().isEmpty &&
      second.evaluate().isEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    first.evaluate().isNotEmpty || second.evaluate().isNotEmpty,
    isTrue,
  );
}

Future<void> _pumpUntilEnabledPrimaryButton(
  WidgetTester tester,
  Finder finder,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    final buttons = tester.widgetList<PrimaryCapsuleButton>(finder);
    if (buttons.isNotEmpty && buttons.first.onPressed != null) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(tester.widget<PrimaryCapsuleButton>(finder).onPressed, isNotNull);
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsNothing);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  final adoptionLabels = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('library-adoption-review-enter')),
          matching: find.byType(Text),
        ),
      )
      .map((widget) => widget.data)
      .toList();
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .join(' | ');
  expect(
    finder,
    findsWidgets,
    reason:
        'Rendered adoption labels: $adoptionLabels\nVisible UI: $visibleText',
  );
}
