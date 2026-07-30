/*
 * [INPUT]: Uses SharedPreferences, temporary filesystem boundaries, controlled CLI output, and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies appearance including persistent first-run wallpaper selection, language, reminder, one-time adoption-introduction, independent Hub/Cloud Origins, onboarding, Added Project, offline local-management, risk, storage, and diagnostics contracts.
 * [POS]: Serves as the preferences, onboarding, and project contract suite at the SkillsGateway seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/desktop_skills_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_process_runner.dart';

class _ManagedProjectsRunner implements ProcessRunner {
  _ManagedProjectsRunner({this.fallback});

  final ProcessRunner? fallback;
  final projects = <String, ({String name, String root})>{};

  @override
  Future<CliServerSession> startCliServer(String executable) async =>
      _ManagedProjectsSession(this, executable);

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) async {
    if (arguments.length >= 2 && arguments.first == 'project') {
      final action = arguments[1];
      if (action == 'add') {
        final root = await _canonical(arguments[2]);
        projects.putIfAbsent(
          root,
          () => (name: root.split(Platform.pathSeparator).last, root: root),
        );
        return _document('project-add', [projects[root]!]);
      }
      if (action == 'remove') {
        final value = await _canonical(arguments[2]);
        projects.remove(value);
        return _document('project-remove', const []);
      }
      if (action == 'list') {
        return _document('project-list', projects.values.toList());
      }
    }
    return fallback?.run(
          executable,
          arguments,
          stdin: stdin,
          onStdoutLine: onStdoutLine,
        ) ??
        const ProcessOutput(exitCode: 1, stdout: '', stderr: 'unexpected');
  }

  Future<String> _canonical(String path) async {
    try {
      return await Directory(path).resolveSymbolicLinks();
    } on FileSystemException {
      return Directory(path).absolute.path;
    }
  }

  ProcessOutput _document(
    String phase,
    List<({String name, String root})> values,
  ) => ProcessOutput(
    exitCode: 0,
    stdout: jsonEncode({
      'schemaVersion': 1,
      'phase': phase,
      'projects': [
        for (final project in values)
          {'name': project.name, 'root': project.root},
      ],
    }),
    stderr: '',
  );
}

class _ManagedProjectsSession implements CliServerSession {
  _ManagedProjectsSession(this.runner, this.executable);

  final _ManagedProjectsRunner runner;
  final String executable;

  @override
  bool isClosed = false;

  @override
  Future<ProcessOutput> run(
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) => runner.run(
    executable,
    arguments,
    stdin: stdin,
    onStdoutLine: onStdoutLine,
  );

  @override
  Future<void> close() async => isClosed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('language settings persist with System as the default', () async {
    final gateway = DesktopSkillsGateway();
    expect(await gateway.loadLanguage(), AppLanguage.system);
    await gateway.saveLanguage(AppLanguage.simplifiedChinese);
    expect(await gateway.loadLanguage(), AppLanguage.simplifiedChinese);

    final restored = DesktopSkillsGateway();
    expect(await restored.loadLanguage(), AppLanguage.simplifiedChinese);
  });

  test('unset theme color defaults to white', () async {
    final gateway = DesktopSkillsGateway();

    expect(await gateway.loadFolderTheme(), '#FFFFFF');
  });

  test('first launch selects and persists one wallpaper', () async {
    final gateway = DesktopSkillsGateway();

    final selected = await gateway.loadWallpaper();

    expect(AppWallpaper.values, contains(selected));
    expect(
      (await SharedPreferences.getInstance()).getString('wallpaper'),
      selected.name,
    );
    expect(await DesktopSkillsGateway().loadWallpaper(), selected);
  });

  test('reminder settings persist with user-safe defaults', () async {
    final gateway = DesktopSkillsGateway();
    final defaults = await gateway.loadReminderSettings();
    expect(defaults.updateAvailable, isTrue);
    expect(defaults.securityAdvisory, isTrue);

    await gateway.saveReminderSettings(
      const ReminderSettings(updateAvailable: false, securityAdvisory: false),
    );
    final restored = await DesktopSkillsGateway().loadReminderSettings();
    expect(restored.updateAvailable, isFalse);
    expect(restored.securityAdvisory, isFalse);
  });

  test('update check cache persists exact scope results', () async {
    final gateway = DesktopSkillsGateway();
    expect(await gateway.loadUpdateCheckCache(), isNull);
    final checkedAt = DateTime.utc(2026, 7, 29, 12, 30);
    await gateway.saveUpdateCheckCache(
      UpdateCheckCache(
        checkedAt: checkedAt,
        results: const {
          'github.com/example/skills\u0000global\u0000': UpdateAvailability(
            state: UpdateState.available,
            toVersion: 'v1.1.0',
            selectedSkillCount: 2,
            removedSkills: [
              RemovedSkillImpact(name: 'old', path: 'skills/old'),
            ],
          ),
        },
      ),
    );

    final restored = await DesktopSkillsGateway().loadUpdateCheckCache();
    expect(restored?.checkedAt, checkedAt);
    final result = restored?.results.values.single;
    expect(result?.state, UpdateState.available);
    expect(result?.toVersion, 'v1.1.0');
    expect(result?.selectedSkillCount, 2);
    expect(result?.removedSkills.single.name, 'old');
  });

  test(
    'selected language is forwarded to Hub Find as canonical content locale',
    () async {
      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"skills":[],"pagination":{"page":0,"perPage":20,"hasMore":false}}',
          stderr: '',
        );
      final gateway = DesktopSkillsGateway(
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
          '--lang',
          'zh-Hans-CN',
        ]),
      );
    },
  );

  test('hub settings reject unsafe or malformed origins', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = DesktopSkillsGateway(
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
    'Added Projects persist and removal only drops the App reference',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('skillsgo-projects-');
      addTearDown(() => root.delete(recursive: true));
      final original = Directory('${root.path}/plain project');
      final second = Directory('${root.path}/second project');
      final unselected = Directory('${root.path}/never selected');
      await original.create();
      await second.create();
      await unselected.create();
      await File(
        '${original.path}/skills.yaml',
      ).writeAsString('dependencies: {}\n');
      await File(
        '${original.path}/skills-lock.yaml',
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

      final runner = _ManagedProjectsRunner();
      final gateway = DesktopSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
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

      final restarted = DesktopSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
        projectPathInspector: inspect,
      );
      final restored = await restarted.loadAddedProjects();
      expect(restored, hasLength(2));
      expect(
        restored.map((project) => project.path),
        added.map((project) => project.path),
      );
      await restarted.removeProject(added.first.id);
      expect(
        (await restarted.loadAddedProjects()).map((project) => project.path),
        [added[1].path],
      );
      expect(
        await File('${original.path}/skills.yaml').readAsString(),
        'dependencies: {}\n',
      );
      expect(
        await File('${original.path}/skills-lock.yaml').readAsString(),
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
      final gateway = DesktopSkillsGateway(
        processRunner: _ManagedProjectsRunner(),
        initialCliPath: '/bin/skillsgo',
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

  test('Onboarding Agent inspection uses the bundled CLI Server', () async {
    final runner = FakeCliServerRunner()
      ..responses.add(
        const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"product":"skillsgo","version":"test","appProtocolVersion":17,"os":"darwin","architecture":"arm64"}',
          stderr: '',
        ),
      )
      ..serverResponses.add(
        const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":2,"product":"skillsgo","version":"test","appProtocolVersion":17,"os":"darwin","architecture":"arm64","agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["global"],"globalTarget":{"path":"/Users/test/.codex/skills","exists":true}}]}',
          stderr: '',
        ),
      );
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/Applications/SkillsGo.app/Contents/Resources/skillsgo',
      expectedCliOS: 'darwin',
    );

    final agents = await gateway.inspectOnboardingAgents();

    expect(agents.installed.single.id, 'codex');
    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.arguments, ['version', '--output', 'json']);
    expect(runner.starts, 1);
    expect(runner.sessions.single.calls.single, ['agents', '--output', 'json']);

    runner.sessions.single.result = const ProcessOutput(
      exitCode: 0,
      stdout:
          '{"schemaVersion":2,"product":"skillsgo","version":"old","appProtocolVersion":10,"os":"darwin","architecture":"arm64","agents":[]}',
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

  test('Onboarding reset preserves App data and returns to Welcome', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed_v1': true,
      'onboarding_step_v1': OnboardingStep.projects.name,
      'theme_mode': AppThemeMode.dark.name,
    });
    final runner = _ManagedProjectsRunner();
    runner.projects['/one'] = (name: 'One', root: '/one');
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );

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
    final gateway = DesktopSkillsGateway(
      processRunner: _ManagedProjectsRunner(),
      initialCliPath: '/bin/skillsgo',
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
      SharedPreferences.setMockInitialValues({});
      final fallback = FakeProcessRunner()
        ..responses.addAll([
          ProcessOutput(
            exitCode: 0,
            stdout: jsonEncode({
              'schemaVersion': 7,
              'entries': [
                {
                  'inventoryKey': 'external:offline',
                  'name': 'offline-skill',
                  'skillId': '',
                  'provenance': 'external',
                  'health': 'healthy',
                  'agents': ['codex'],
                  'projects': <String>[],
                  'versions': <String>[],
                  'versionDivergence': false,
                  'visibility': <Object>[],
                  'targets': [
                    {
                      'scope': 'global',
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
                '{"schemaVersion":2,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["global"],"globalTarget":{"path":"/Users/test/.codex/skills","exists":true}}]}',
            stderr: '',
          ),
        ]);
      final runner = _ManagedProjectsRunner(fallback: fallback);
      final canonicalProjectPath = await project.resolveSymbolicLinks();
      runner.projects[canonicalProjectPath] = (
        name: 'Offline Project',
        root: canonicalProjectPath,
      );
      final gateway = DesktopSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
      );

      final projects = await gateway.loadAddedProjects();
      final inventory = await gateway.listInstalled(projects: projects);
      final agents = await gateway.inspectAgents();
      final detail = await gateway.loadLocalDetail(inventory.single);
      await gateway.removeProject(projects.single.id);

      expect(projects.single.name, 'Offline Project');
      expect(inventory.single.provenance, LibraryProvenance.external);
      expect(agents.installed.single.id, 'codex');
      expect(detail.content, '# Offline Skill');
      expect(await gateway.loadAddedProjects(), isEmpty);
    },
  );

  test('hub settings turn transport failures into structured health', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = DesktopSkillsGateway(
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

  test('Cloud Origin persists independently from Hub discovery', () async {
    SharedPreferences.setMockInitialValues({});
    final runner = FakeProcessRunner();
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
      hubBaseUrl: 'https://official-hub.example',
    );

    expect(await gateway.loadCloudOrigin(), 'https://cloud.skillsgo.ai');
    await gateway.saveCloudOrigin('https://private-cloud.example/path/');
    expect(
      await gateway.loadCloudOrigin(),
      'https://private-cloud.example/path',
    );
    expect(await gateway.loadHubOrigin(), 'https://official-hub.example');

    expect(runner.calls, isEmpty);

    await gateway.resetCloudOrigin();
    expect(await gateway.loadCloudOrigin(), 'https://cloud.skillsgo.ai');
  });

  test('Cloud Origin health validates the ranking protocol', () async {
    SharedPreferences.setMockInitialValues({});
    final cloud = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => cloud.close(force: true));
    Uri? requested;
    cloud.listen((request) async {
      requested = request.uri;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"skills":[],"pagination":{"page":0,"perPage":1,"hasMore":false}}',
      );
      await request.response.close();
    });
    final gateway = DesktopSkillsGateway(
      initialCliPath: '/bin/skillsgo',
      cloudBaseUrl: 'http://127.0.0.1:${cloud.port}',
    );

    final status = await gateway.testCloudOrigin(
      'http://127.0.0.1:${cloud.port}',
    );

    expect(status.isReady, isTrue);
    expect(
      requested.toString(),
      '/api/v1/rankings/all_time?page=0&perPage=1&lang=en',
    );
  });

  test('Cloud Origin health rejects an incomplete ranking protocol', () async {
    SharedPreferences.setMockInitialValues({});
    final cloud = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => cloud.close(force: true));
    cloud.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"skills":[],"pagination":{}}');
      await request.response.close();
    });
    final gateway = DesktopSkillsGateway(initialCliPath: '/bin/skillsgo');

    final status = await gateway.testCloudOrigin(
      'http://127.0.0.1:${cloud.port}',
    );

    expect(status.state, HealthState.invalid);
    expect(status.issue, HubIssue.invalidProtocol);
  });

  test('Personal risk policy and product version are stable', () async {
    SharedPreferences.setMockInitialValues({});
    final runner = FakeProcessRunner();
    final gateway = DesktopSkillsGateway(
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
