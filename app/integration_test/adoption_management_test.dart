/*
 * [INPUT]: Depends on the rendered App, bundled CLI, JourneyRuntime filesystem/Hub/schema isolation, supported skills.sh locks, the public versioned Repository fixture, and SharedPreferences-backed Added Projects.
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
import 'package:skillsgo/main.dart' as skillsgo;
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
      await preferences.setString(
        'added_projects_v1',
        jsonEncode([
          {
            'id': 'adoption-project',
            'name': 'adoption-project',
            'path': projectRoot.path,
          },
        ]),
      );

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

      await _pumpUntilAdoptionCount(tester, 2);
      await _pumpUntil(tester, _projectRailCount('adoption-project', 1));
      expect(_projectRailCount('adoption-project', 1), findsOneWidget);

      await tester.tap(_railButton(find.text('adoption-project')));
      await _pumpUntilAdoptionCount(tester, 1);
      await _executeAdoption(tester, adopted: 1, skipped: 0);
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
          '${projectRoot.path}/.test-agent/skills/github.com/skillsgo/e2e-versioned-skills@v1.2.0/skills/alpha/SKILL.md',
        ).readAsBytesSync(),
        projectSkillBytes,
      );
      expect(projectTarget.existsSync(), isFalse);
      await _pumpUntil(tester, _projectRailCount('adoption-project', 0));
      expect(_projectRailCount('adoption-project', 0), findsOneWidget);

      await tester.tap(_railButton(_globalRailLabel()));
      await _pumpUntilAdoptionCount(tester, 1);
      await _executeAdoption(tester, adopted: 1, skipped: 0);
      await _pumpUntilAdoptionCount(tester, 0);
      expect(File('$sandbox/home/.agents/skills.yaml').existsSync(), isTrue);
      expect(
        File('$sandbox/home/.agents/skills-lock.yaml').existsSync(),
        isTrue,
      );
      expect(
        File(
          '$sandbox/test-agent/skills/github.com/skillsgo/e2e-versioned-skills@v1.2.0/skills/alpha/SKILL.md',
        ).readAsBytesSync(),
        userSkillBytes,
      );
      expect(globalTarget.existsSync(), isFalse);

      await tester.tap(_railButton(_allSkillsRailLabel()));
      await _pumpUntilAdoptionCount(tester, 0);
      expect(_adoptionCount(0), findsOneWidget);
      expect(_projectRailCount('adoption-project', 0), findsOneWidget);
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
  of: find.byKey(const Key('library-batch-adoption')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data == 'Manage ($count)' || widget.data == '纳入管理（$count）'),
  ),
);

Finder _projectRailCount(String projectName, int count) => find.descendant(
  of: _railButton(find.text(projectName)),
  matching: find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == '$count',
  ),
);

Finder _globalRailLabel() => find.byWidgetPredicate(
  (widget) =>
      widget is Text && (widget.data == 'Global' || widget.data == '全局安装'),
);

Finder _allSkillsRailLabel() => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data == 'All Skills' || widget.data == '全部 Skills'),
);

Finder _railButton(Finder label) =>
    find.ancestor(of: label, matching: find.byType(TextButton)).first;

Future<void> _executeAdoption(
  WidgetTester tester, {
  required int adopted,
  required int skipped,
}) async {
  final adoptionAction = find.descendant(
    of: find.byKey(const Key('library-batch-adoption')),
    matching: find.byType(OutlinedButton),
  );
  await _pumpUntil(tester, adoptionAction);
  await tester.ensureVisible(adoptionAction);
  await tester.tap(adoptionAction);
  await _pumpUntil(tester, find.byKey(const Key('batch-adoption-dialog')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('batch-adoption-tetris-story')), findsOneWidget);
  final confirm = find.byKey(const Key('batch-adoption-confirm'));
  expect(confirm, findsOneWidget);
  await tester.tap(confirm);
  final completed = find.byKey(const Key('batch-adoption-board-complete'));
  await _pumpUntil(tester, completed);
  expect(
    tester.widget<Semantics>(completed).properties.label,
    anyOf(
      '$adopted skills added to management, $skipped skipped.',
      '已纳入管理 $adopted 个技能，跳过 $skipped 个。',
    ),
  );
  final close = find.byKey(const Key('batch-adoption-close'));
  await tester.tap(close);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('batch-adoption-modal')), findsNothing);
}

Future<void> _pumpUntilAdoptionCount(WidgetTester tester, int count) =>
    _pumpUntil(tester, _adoptionCount(count));

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  final adoptionLabels = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('library-batch-adoption')),
          matching: find.byType(Text),
        ),
      )
      .map((widget) => widget.data)
      .toList();
  expect(
    finder,
    findsWidgets,
    reason: 'Rendered adoption labels: $adoptionLabels',
  );
}
