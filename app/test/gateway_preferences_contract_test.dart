/*
 * [INPUT]: Uses SharedPreferences, temporary filesystem boundaries, controlled CLI output, and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies appearance, language, reminder, one-time takeover-introduction, Hub-origin, onboarding, Added Project, offline local-management, risk, storage, and diagnostics contracts.
 * [POS]: Serves as the preferences, onboarding, and project contract suite at the SkillsGateway seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/real_skills_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_process_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('language settings persist with System as the default', () async {
    final gateway = RealSkillsGateway();
    expect(await gateway.loadLanguage(), AppLanguage.system);
    await gateway.saveLanguage(AppLanguage.simplifiedChinese);
    expect(await gateway.loadLanguage(), AppLanguage.simplifiedChinese);

    final restored = RealSkillsGateway();
    expect(await restored.loadLanguage(), AppLanguage.simplifiedChinese);
  });

  test('unset theme color defaults to white', () async {
    final gateway = RealSkillsGateway();

    expect(await gateway.loadFolderTheme(), '#FFFFFF');
  });

  test('reminder settings persist with user-safe defaults', () async {
    final gateway = RealSkillsGateway();
    final defaults = await gateway.loadReminderSettings();
    expect(defaults.updateAvailable, isTrue);
    expect(defaults.securityAdvisory, isTrue);

    await gateway.saveReminderSettings(
      const ReminderSettings(updateAvailable: false, securityAdvisory: false),
    );
    final restored = await RealSkillsGateway().loadReminderSettings();
    expect(restored.updateAvailable, isFalse);
    expect(restored.securityAdvisory, isFalse);
  });

  test(
    'Batch Takeover introduction is unseen until an explicit choice',
    () async {
      final gateway = RealSkillsGateway();
      expect(await gateway.loadBatchTakeoverPromptSeen(), isFalse);

      await gateway.markBatchTakeoverPromptSeen();

      expect(await RealSkillsGateway().loadBatchTakeoverPromptSeen(), isTrue);
    },
  );

  test(
    'selected language is forwarded to Hub Find as canonical content locale',
    () async {
      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"collection":"search","skills":[],"page":{"limit":20,"offset":0,"nextOffset":null}}',
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/usr/local/bin/skillsgo',
        hubBaseUrl: 'https://hub.example.test',
      );
      await gateway.saveLanguage(AppLanguage.simplifiedChinese);

      await gateway.discover(DiscoveryCollection.search, query: 'layout');

      final discoverCall = runner.calls.firstWhere(
        (call) => call.arguments.contains('find'),
      );
      expect(
        discoverCall.arguments,
        containsAllInOrder([
          'find',
          'layout',
          '--hub',
          'https://hub.example.test',
          '--content-locale',
          'zh-Hans',
        ]),
      );
    },
  );

  test('hub settings reject unsafe or malformed origins', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = RealSkillsGateway(
      hubBaseUrl: 'https://official.example',
      appVersion: '1.2.3',
    );

    final status = await gateway.testHubOrigin(
      'https://user:password@example.com?secret=yes',
    );
    expect(status.state, HealthState.invalid);
    await expectLater(
      gateway.saveHubOrigin('file:///tmp/hub'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'Added Projects persist, relocate by stable inventoryKey, and remove only the App reference',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('skillsgo-projects-');
      addTearDown(() => root.delete(recursive: true));
      final original = Directory('${root.path}/plain project');
      final second = Directory('${root.path}/second project');
      final relocated = Directory('${root.path}/moved project');
      final unselected = Directory('${root.path}/never selected');
      await original.create();
      await second.create();
      await relocated.create();
      await unselected.create();
      await File(
        '${original.path}/skillsgo.yaml',
      ).writeAsString('dependencies: {}\n');
      await File(
        '${original.path}/skillsgo.lock',
      ).writeAsString('dependencies: {}\n');
      await Directory(
        '${original.path}/.agents/skills',
      ).create(recursive: true);
      final inspected = <String>[];
      Future<({ProjectAccessState state, String? diagnostic})> inspect(
        String path,
      ) async {
        inspected.add(path);
        return (state: ProjectAccessState.accessible, diagnostic: null);
      }

      final gateway = RealSkillsGateway(
        directoryPathsPicker: ({initialDirectory}) async => [
          original.path,
          second.path,
          original.path,
        ],
        projectPathInspector: inspect,
      );
      final added = await gateway.addProjects();
      expect(added.map((project) => project.name), [
        'plain project',
        'second project',
      ]);
      expect(inspected, added.map((project) => project.path));
      expect(inspected, isNot(contains(unselected.path)));

      final restarted = RealSkillsGateway(
        directoryPicker: ({initialDirectory}) async {
          expect(initialDirectory, added.first.path);
          return relocated.path;
        },
        projectPathInspector: inspect,
      );
      final restored = await restarted.loadAddedProjects();
      expect(restored, hasLength(2));
      expect(
        restored.map((project) => project.path),
        added.map((project) => project.path),
      );
      final moved = await restarted.relocateProject(added.first.id);
      final canonicalRelocatedPath = await relocated.resolveSymbolicLinks();
      expect(moved!.id, added.first.id);
      expect(moved.path, canonicalRelocatedPath);
      final savedProjects =
          jsonDecode(
                (await SharedPreferences.getInstance()).getString(
                  'added_projects_v1',
                )!,
              )
              as List<dynamic>;
      expect(
        (savedProjects.first as Map<String, dynamic>)['path'],
        canonicalRelocatedPath,
      );

      await restarted.removeProject(added.first.id);
      expect(
        (await restarted.loadAddedProjects()).map((project) => project.path),
        [added[1].path],
      );
      expect(
        await File('${original.path}/skillsgo.yaml').readAsString(),
        'dependencies: {}\n',
      );
      expect(
        await File('${original.path}/skillsgo.lock').readAsString(),
        'dependencies: {}\n',
      );
      expect(
        await Directory('${original.path}/.agents/skills').exists(),
        isTrue,
      );
    },
  );

  test(
    'Added Projects reject file paths supplied outside the directory picker',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'skillsgo-project-file-',
      );
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/not-a-project.txt');
      await file.writeAsString('not a directory');
      final gateway = RealSkillsGateway(
        directoryPathsPicker: ({initialDirectory}) async => [file.path],
      );

      await expectLater(
        gateway.addProjects(),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.message,
            'message',
            'Only directories can be added as projects.',
          ),
        ),
      );
      expect(await gateway.loadAddedProjects(), isEmpty);
    },
  );

  test('Onboarding Agent inspection uses one bundled CLI command', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":1,"product":"skillsgo","version":"test","appProtocolVersion":10,"os":"darwin","architecture":"arm64","agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["user"],"userTarget":{"path":"/Users/test/.codex/skills","exists":true}}]}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/Applications/SkillsGo.app/Contents/Resources/skillsgo',
      expectedCliOS: 'darwin',
    );

    final agents = await gateway.inspectOnboardingAgents();

    expect(agents.installed.single.id, 'codex');
    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.arguments, ['agents', '--output', 'json']);

    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout:
          '{"schemaVersion":1,"product":"skillsgo","version":"old","appProtocolVersion":9,"os":"darwin","architecture":"arm64","agents":[]}',
      stderr: '',
    );
    await expectLater(
      gateway.inspectOnboardingAgents(),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.invalidLocalData,
        ),
      ),
    );
  });

  test(
    'existing App state bypasses Mandatory Onboarding after upgrade',
    () async {
      SharedPreferences.setMockInitialValues({'folder_theme': '#294556'});

      final state = await RealSkillsGateway().loadOnboardingState();

      expect(state.completed, isTrue);
    },
  );

  test('Onboarding reset preserves App data and returns to Welcome', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed_v1': true,
      'onboarding_step_v1': OnboardingStep.projects.name,
      'added_projects_v1': '[{"id":"one","name":"One","path":"/one"}]',
      'theme_mode': AppThemeMode.dark.name,
    });
    final gateway = RealSkillsGateway();

    await gateway.resetOnboarding();

    expect(
      await gateway.loadOnboardingState(),
      const OnboardingState(completed: false, step: OnboardingStep.welcome),
    );
    expect(await gateway.loadAddedProjects(), hasLength(1));
    expect(await gateway.loadThemeMode(), AppThemeMode.dark);
  });

  test('Added Projects retain diagnosable inaccessible states', () async {
    SharedPreferences.setMockInitialValues({});
    final selections = <String>[
      '/Volumes/missing',
      '/private/denied',
      '/mnt/offline',
    ];
    final states = <String, ({ProjectAccessState state, String? diagnostic})>{
      '/Volumes/missing': (
        state: ProjectAccessState.missing,
        diagnostic: 'missing media',
      ),
      '/private/denied': (
        state: ProjectAccessState.permissionDenied,
        diagnostic: 'permission denied',
      ),
      '/mnt/offline': (
        state: ProjectAccessState.inaccessible,
        diagnostic: 'device unavailable',
      ),
    };
    final gateway = RealSkillsGateway(
      directoryPathsPicker: ({initialDirectory}) async => selections,
      projectPathInspector: (path) async => states[path]!,
    );

    await gateway.addProjects();
    final projects = await gateway.loadAddedProjects();

    expect(projects.map((project) => project.accessState), [
      ProjectAccessState.missing,
      ProjectAccessState.permissionDenied,
      ProjectAccessState.inaccessible,
    ]);
    expect(projects.map((project) => project.diagnostic), [
      'missing media',
      'permission denied',
      'device unavailable',
    ]);
  });

  test(
    'local Library boundaries remain usable without any Hub request',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'skillsgo-offline-library-',
      );
      addTearDown(() => root.delete(recursive: true));
      final project = Directory('${root.path}/project');
      final skillDirectory = Directory('${root.path}/external-skill');
      await project.create();
      await skillDirectory.create();
      await File(
        '${skillDirectory.path}/SKILL.md',
      ).writeAsString('# Offline Skill');
      SharedPreferences.setMockInitialValues({
        'added_projects_v1': jsonEncode([
          {
            'id': 'offline-project',
            'name': 'Offline Project',
            'path': project.path,
          },
        ]),
      });
      final runner = FakeProcessRunner()
        ..responses.addAll([
          ProcessOutput(
            exitCode: 0,
            stdout: jsonEncode({
              'schemaVersion': 6,
              'entries': [
                {
                  'inventoryKey': 'external:offline',
                  'name': 'offline-skill',
                  'skillId': '',
                  'provenance': 'external',
                  'risk': 'unknown',
                  'health': 'healthy',
                  'agents': ['codex'],
                  'projects': <String>[],
                  'versions': <String>[],
                  'versionDivergence': false,
                  'visibility': <Object>[],
                  'targets': [
                    {
                      'scope': 'user',
                      'agent': 'codex',
                      'path': skillDirectory.path,
                      'mode': 'external',
                      'version': '',
                      'health': 'healthy',
                    },
                  ],
                },
              ],
            }),
            stderr: '',
          ),
          const ProcessOutput(
            exitCode: 0,
            stdout:
                '{"schemaVersion":1,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["user"],"userTarget":{"path":"/Users/test/.codex/skills","exists":true}}]}',
            stderr: '',
          ),
        ]);
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
      );

      final projects = await gateway.loadAddedProjects();
      final inventory = await gateway.listInstalled(projects: projects);
      final agents = await gateway.inspectAgents();
      final detail = await gateway.loadLocalDetail(inventory.single);
      await gateway.removeProject('offline-project');

      expect(projects.single.name, 'Offline Project');
      expect(inventory.single.provenance, LibraryProvenance.external);
      expect(agents.installed.single.id, 'codex');
      expect(detail.markdown, '# Offline Skill');
      expect(await gateway.loadAddedProjects(), isEmpty);
    },
  );

  test('hub settings turn transport failures into structured health', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = RealSkillsGateway(
      processRunner: FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 69,
          stdout: '',
          stderr: 'Hub offline',
        ),
      initialCliPath: '/bin/skillsgo',
      hubBaseUrl: 'https://official.example',
      appVersion: '1.2.3',
    );

    final status = await gateway.testHubOrigin('https://self-hosted.example');

    expect(status.state, HealthState.unreachable);
    expect(status.issue, HubIssue.connectionFailure);
  });

  test('Personal risk policy and product version are stable', () async {
    SharedPreferences.setMockInitialValues({});
    final runner = FakeProcessRunner();
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/Applications/SkillsGo.app/skillsgo',
      hubBaseUrl: 'https://official.example',
      appVersion: '3.2.1',
    );

    expect((await gateway.loadRiskPolicy()).confirmHighRisk, isTrue);
    expect((await gateway.loadRiskPolicy()).allowCriticalOverride, isFalse);
    await gateway.saveRiskPolicy(
      const PersonalRiskPolicy(allowCriticalOverride: true),
    );
    expect((await gateway.loadRiskPolicy()).allowCriticalOverride, isTrue);
    expect(await gateway.loadAppVersion(), '3.2.1');
  });
}
