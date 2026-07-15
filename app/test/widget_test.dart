/*
 * [INPUT]: Uses SkillsPlayApp with a controllable SkillsGateway fake and Flutter platform locale settings.
 * [OUTPUT]: Specifies visible Personal User journeys for startup, discovery, settings, and local mutations.
 * [POS]: Serves as the highest App behavior suite at the rendered desktop interface seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsplay/app.dart';
import 'package:skillsplay/domain/skills_gateway.dart';

void main() {
  testWidgets('follows the system locale and renders Simplified Chinese', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(SkillsPlayApp(gateway: FakeSkillsGateway()));
    await tester.pumpAndSettle();

    expect(find.text('发现'), findsOneWidget);
    expect(find.text('技能库'), findsOneWidget);
    expect(find.text('找到下一步所需的技能。'), findsOneWidget);
  });

  testWidgets('localizes missing bundled CLI recovery guidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    tester.binding.platformDispatcher.localesTestValue = const [
      Locale('zh', 'CN'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      SkillsPlayApp(gateway: FakeSkillsGateway(cliReady: false)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('内置的 SkillsGo CLI 缺失或无法运行。请重新安装 SkillsPlay。'),
      findsOneWidget,
    );
    expect(find.text('raw process diagnostic'), findsNothing);
  });

  testWidgets('starts in Discover and searches through the gateway', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Find a skill for your next move.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('skill-search')), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(gateway.queries, ['flutter']);
    expect(find.text('Flutter Pro'), findsOneWidget);
    expect(find.text('example/skills'), findsOneWidget);
  });

  testWidgets('Settings shows a missing CLI and accepts a custom path', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(cliReady: false);
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('MISSING'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('cli-path')), '/custom/skills');
    await tester.tap(find.text('Save & detect'));
    await tester.pumpAndSettle();

    expect(gateway.savedPath, '/custom/skills');
  });

  testWidgets('Library exposes update state after an explicit check', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway();
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('local-skill'), findsOneWidget);
    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE'), findsOneWidget);
  });

  testWidgets('core flow searches, installs, checks updates and removes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    final gateway = FakeSkillsGateway(installed: false);
    await tester.pumpWidget(SkillsPlayApp(gateway: gateway));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('skill-search')), 'flutter');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter Pro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('--agent codex --yes'), findsOneWidget);

    await tester.tap(find.text('Install for Codex'));
    await tester.pumpAndSettle();
    expect(find.text('Command completed'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to search'));
    await tester.pumpAndSettle();
    expect(find.text('local-skill'), findsOneWidget);

    await tester.tap(find.text('Check updates'));
    await tester.pumpAndSettle();
    expect(find.text('UPDATE'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove local-skill'));
    await tester.pumpAndSettle();
    expect(find.text('Remove local-skill?'), findsOneWidget);
    await tester.tap(find.text('Remove Skill'));
    await tester.pumpAndSettle();
    expect(find.text('Your Library is empty'), findsOneWidget);
  });
}

class FakeSkillsGateway implements SkillsGateway {
  FakeSkillsGateway({this.cliReady = true, this.installed = true});
  final bool cliReady;
  bool installed;
  final queries = <String>[];
  String? savedPath;

  @override
  Future<CliStatus> detectCli({String? customPath}) async => cliReady
      ? CliStatus(
          availability: CliAvailability.ready,
          path: customPath?.isNotEmpty == true
              ? customPath
              : '/usr/local/bin/skills',
          version: '1.5.17',
        )
      : const CliStatus(
          availability: CliAvailability.missing,
          message: 'raw process diagnostic',
          issue: CliIssue.missing,
        );

  @override
  Future<String?> loadCustomCliPath() async => savedPath;
  @override
  Future<void> saveCustomCliPath(String? path) async => savedPath = path;
  @override
  Future<List<SkillSummary>> search(String query) async {
    queries.add(query);
    return const [
      SkillSummary(
        id: 'example/skills/flutter-pro',
        skillId: 'flutter-pro',
        name: 'Flutter Pro',
        source: 'example/skills',
        installs: 1200,
      ),
    ];
  }

  @override
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill) async =>
      const SkillDetail(
        name: 'Flutter Pro',
        source: 'example/skills',
        markdown: '# Flutter Pro',
        files: [SkillFile(path: 'SKILL.md', contents: '# Flutter Pro')],
      );
  @override
  Future<List<InstalledSkill>> listInstalled() async => installed
      ? const [
          InstalledSkill(
            name: 'local-skill',
            path: '/tmp/local-skill',
            agents: ['codex'],
          ),
        ]
      : const [];
  @override
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill) async =>
      const SkillDetail(
        name: 'local-skill',
        source: 'Local',
        markdown: '# Local',
        files: [SkillFile(path: 'SKILL.md', contents: '# Local')],
      );
  @override
  Future<Map<String, UpdateState>> checkUpdates(
    List<InstalledSkill> skills,
  ) async => {'local-skill': UpdateState.available};
  @override
  Future<CommandResult> install(SkillSummary skill) async {
    installed = true;
    return _success(['skills', 'add']);
  }

  @override
  Future<CommandResult> remove(InstalledSkill skill) async {
    installed = false;
    return _success(['skills', 'remove']);
  }

  @override
  Future<CommandResult> update(InstalledSkill skill) async =>
      _success(['skills', 'update']);
}

CommandResult _success(List<String> command) => CommandResult(
  command: command,
  output: const ProcessOutput(exitCode: 0, stdout: 'ok', stderr: ''),
);
