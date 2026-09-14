/*
 * [INPUT]: Depends on the production App composition, fixed frontend Skill data, fixed task states, the test Gateway, and a no-network updater.
 * [OUTPUT]: Launches an interactive local Mock App without Hub, update-feed, CLI, or filesystem dependencies.
 * [POS]: Serves as the developer-only product demonstration entry point and is excluded from normal startup and release packaging.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/app_updater.dart';
import 'package:skillsgo/main.dart' as skillsgo;
import 'package:skillsgo/ui/installation_task_controller.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/fake_skills_gateway.dart';

const mockHubOrigin = 'https://mock-hub.skillsgo.local';
final mockUpdateSource = Uri.parse(
  'https://mock-updates.skillsgo.local/macos-arm64/',
);

Future<void> main() async {
  await skillsgo.runSkillsGoApp(
    gateway: FakeSkillsGateway(
      installed: false,
      hubOrigin: mockHubOrigin,
      language: AppLanguage.simplifiedChinese,
      agentNames: const ['claude-code', 'codex', 'github-copilot'],
      searchResults: _mockSkills,
    ),
    appUpdater: const _MockAppUpdater(),
    appUpdateSource: mockUpdateSource,
    appUpdateChannel: 'mock-macos-arm64',
    initialInstallationTasks: _mockTasks,
    manageInitialWindowVisibility: false,
  );
  await windowManager.show();
  await windowManager.focus();
}

const _mockSkills = [
  SkillSummary(
    packagePath: 'github.com/s1dashu/ip-as-logo-skill',
    installName: 'ip-as-logo',
    name: 'ip-as-logo',
    latestVersion: 'v0.0.0-mock',
    installs: 4400,
    description: '生成极简、圆润、具有鲜明人格的方形 IP 角色图标。',
  ),
  SkillSummary(
    packagePath: 'github.com/skillsgo/design-skills',
    installName: 'design-taste',
    name: 'design-taste',
    latestVersion: 'v1.4.0',
    installs: 3280,
    description: '为产品界面提供克制、清晰且一致的视觉设计指导。',
  ),
  SkillSummary(
    packagePath: 'github.com/skillsgo/research-skills',
    installName: 'deep-research',
    name: 'deep-research',
    latestVersion: 'v2.1.0',
    installs: 2710,
    description: '从可信来源开展结构化研究并形成可复核的结论。',
  ),
  SkillSummary(
    packagePath: 'github.com/skillsgo/flutter-skills',
    installName: 'flutter-pro',
    name: 'Flutter Pro',
    latestVersion: 'v1.2.3',
    installs: 1960,
    description: '使用可靠的工程流程构建和验证 Flutter 桌面产品。',
  ),
];

final _mockTasks = [
  InstallationTask(
    id: 'mock-running',
    skill: _mockSkills[0],
    status: InstallationTaskStatus.running,
    startedAt: DateTime(2026, 8, 27, 18),
  ),
  InstallationTask(
    id: 'mock-success',
    skill: _mockSkills[1],
    status: InstallationTaskStatus.succeeded,
    startedAt: DateTime(2026, 8, 27, 17, 59),
  ),
  InstallationTask(
    id: 'mock-failed',
    skill: _mockSkills[2],
    status: InstallationTaskStatus.failed,
    startedAt: DateTime(2026, 8, 27, 17, 58),
    failureMessage: '网络连接中断，稍后可重新尝试。',
  ),
];

final class _MockAppUpdater implements AppUpdater {
  const _MockAppUpdater();

  @override
  Future<void> initializeRuntime() async {}

  @override
  Future<AppUpdateCheck> checkForUpdate(Uri source, {String? channel}) async =>
      const AppUpdateCheck(
        currentVersion: '0.0.12-mock',
        availableVersion: null,
      );

  @override
  Future<bool> applyAvailableUpdateAndRestart(
    Uri source, {
    String? channel,
  }) async => false;
}
