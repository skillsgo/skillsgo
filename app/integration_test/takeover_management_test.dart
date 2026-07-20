/*
 * [INPUT]: Depends on the rendered App, its bundled CLI, isolated user/project Agent roots, supported skills.sh locks, and SharedPreferences-backed Added Projects.
 * [OUTPUT]: Verifies exact All/User/Project takeover counts, localized Before/After confirmation, scoped execution, complete metadata persistence, preserved Skill bytes, and post-success rescans.
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'manages existing skills by location and refreshes exact counts',
    (tester) async {
      final sandbox = Platform.environment['SKILLSGO_E2E_SANDBOX'];
      expect(sandbox, isNotNull);
      final userTarget = Directory('$sandbox/test-agent/skills/user-existing');
      final projectRoot = Directory('$sandbox/takeover-project');
      final projectTarget = Directory(
        '${projectRoot.path}/.test-agent/skills/project-existing',
      );
      final userSkillBytes = utf8.encode(
        '---\nname: user-existing\ndescription: existing user skill\n---\n# User\n',
      );
      final projectSkillBytes = utf8.encode(
        '---\nname: project-existing\ndescription: existing project skill\n---\n# Project\n',
      );
      userTarget.createSync(recursive: true);
      projectTarget.createSync(recursive: true);
      File('${userTarget.path}/SKILL.md').writeAsBytesSync(userSkillBytes);
      File(
        '${projectTarget.path}/SKILL.md',
      ).writeAsBytesSync(projectSkillBytes);
      _writeJson(File('$sandbox/home/.agents/.skill-lock.json'), {
        'version': 3,
        'skills': {
          'user-existing': _lockRecord('skills/user-existing/SKILL.md'),
        },
      });
      _writeJson(File('${projectRoot.path}/skills-lock.json'), {
        'version': 1,
        'skills': {
          'project-existing': _lockRecord('skills/project-existing/SKILL.md'),
        },
      });

      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('onboarding_completed_v1', true);
      await preferences.setString(
        'added_projects_v1',
        jsonEncode([
          {
            'id': 'takeover-project',
            'name': 'takeover-project',
            'path': projectRoot.path,
          },
        ]),
      );

      await skillsgo.runSkillsGoApp(initializeBinding: false);
      await windowManager.setSize(const Size(1400, 960));
      await windowManager.center();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(
        find.byKey(const ValueKey('primary-destination-library')),
      );

      await _pumpUntilTakeoverCount(tester, 2);
      expect(_railCountLabel(2), findsOneWidget);
      await _dismissAutomaticTakeoverStory(tester);

      await tester.tap(_railButton(find.text('takeover-project')));
      await _pumpUntilTakeoverCount(tester, 1);
      await _executeTakeover(tester, takenOver: 1, skipped: 0);
      expect(File('${projectRoot.path}/skillsgo.mod').existsSync(), isTrue);
      expect(File('${projectRoot.path}/skillsgo.sum').existsSync(), isTrue);
      expect(
        Directory('${projectRoot.path}/.skillsgo/receipts')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.yaml')),
        hasLength(1),
      );
      expect(
        File('${projectTarget.path}/SKILL.md').readAsBytesSync(),
        projectSkillBytes,
      );
      await _pumpUntil(tester, _railCountLabel(0));
      expect(_railCountLabel(0), findsOneWidget);
      expect(_railCountLabel(1), findsNWidgets(2));

      await tester.tap(_railButton(_globalRailLabel()));
      await _pumpUntilTakeoverCount(tester, 1);
      await _executeTakeover(tester, takenOver: 1, skipped: 0);
      await _pumpUntil(tester, _railCountLabel(0));
      expect(File('$sandbox/home/.skillsgo/skillsgo.mod').existsSync(), isTrue);
      expect(File('$sandbox/home/.skillsgo/skillsgo.sum').existsSync(), isTrue);
      expect(
        File('${userTarget.path}/SKILL.md').readAsBytesSync(),
        userSkillBytes,
      );

      await tester.tap(_railButton(_allSkillsRailLabel()));
      await _pumpUntilTakeoverCount(tester, 0);
      expect(_railCountLabel(0), findsNWidgets(3));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _dismissAutomaticTakeoverStory(WidgetTester tester) async {
  final storyTitle = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data == 'Turn scattered skills into one clear Library' ||
            widget.data == '把散落的技能，整理成一个清晰的 Library'),
  );
  await _pumpUntil(tester, storyTitle);
  final skipLabel = find.byWidgetPredicate(
    (widget) =>
        widget is Text && (widget.data == 'Not now' || widget.data == '暂时跳过'),
  );
  await tester.tap(
    find.ancestor(of: skipLabel, matching: find.byType(OutlinedButton)).first,
  );
  await _pumpUntilGone(tester, storyTitle);
}

Map<String, Object> _lockRecord(String skillPath) => {
  'source': 'acme/skills',
  'sourceType': 'github',
  'sourceUrl': 'https://github.com/acme/skills.git',
  'ref': 'main',
  'skillPath': skillPath,
  'installedAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};

void _writeJson(File file, Object value) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(value));
}

Finder _takeoverCount(int count) => find.descendant(
  of: find.byKey(const Key('library-batch-takeover')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data == 'Manage ($count)' || widget.data == '纳入管理（$count）'),
  ),
);

Finder _railCountLabel(int count) => find.descendant(
  of: find.byKey(const Key('library-location-rail')),
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

Future<void> _executeTakeover(
  WidgetTester tester, {
  required int takenOver,
  required int skipped,
}) async {
  await tester.tap(find.byKey(const Key('library-batch-takeover')));
  await _pumpUntil(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data == 'Turn scattered skills into one clear Library' ||
              widget.data == '把散落的技能，整理成一个清晰的 Library'),
    ),
  );
  final confirmLabel = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data == 'Add to management' || widget.data == '纳入管理'),
  );
  await tester.tap(
    find.ancestor(of: confirmLabel, matching: find.byType(FilledButton)).first,
  );
  await _pumpUntil(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data ==
                  '$takenOver skills added to management, $skipped skipped.' ||
              widget.data == '已纳入管理 $takenOver 个技能，跳过 $skipped 个。'),
    ),
  );
  final closeLabel = find.byWidgetPredicate(
    (widget) =>
        widget is Text && (widget.data == 'Close' || widget.data == '关闭'),
  );
  await tester.tap(
    find.ancestor(of: closeLabel, matching: find.byType(FilledButton)).first,
  );
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (closeLabel.evaluate().isNotEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(closeLabel, findsNothing);
}

Future<void> _pumpUntilTakeoverCount(WidgetTester tester, int count) =>
    _pumpUntil(tester, _takeoverCount(count));

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  final takeoverLabels = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('library-batch-takeover')),
          matching: find.byType(Text),
        ),
      )
      .map((widget) => widget.data)
      .toList();
  expect(
    finder,
    findsWidgets,
    reason: 'Rendered takeover labels: $takeoverLabels',
  );
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (finder.evaluate().isNotEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsNothing);
}
