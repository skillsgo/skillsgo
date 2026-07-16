/*
 * [INPUT]: Uses SkillsGateway with controlled HTTP, process, preferences, and temporary-filesystem boundaries.
 * [OUTPUT]: Specifies settings, discovery/detail parsing including repository product metadata and Hub image URLs, managed/external CLI inventory including Local Modifications, Hub-independent local inspection/project persistence, strict Installation/Update/Target Management/External Adoption contracts, Local export, stable CLI availability mapping, typed failures, storage health, argument safety, and CLI handshake behavior.
 * [POS]: Serves as the App integration-contract suite at the highest non-Widget orchestration seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/real_skills_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('hub settings persist and validate the search protocol', () async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.queryParameters['q'] == 'skillsgo-settings-probe') {
        return http.Response('{"skills":[]}', 200);
      }
      return http.Response(
        '{"collection":"search","skills":[],"page":{"limit":20,"offset":0,"nextOffset":null}}',
        200,
      );
    });
    final gateway = RealSkillsGateway(
      httpClient: client,
      processRunner: _FakeProcessRunner()
        ..result = const ProcessOutput(exitCode: 0, stdout: '[]', stderr: ''),
      initialCliPath: '/usr/local/bin/skillsgo',
      hubBaseUrl: 'https://official.example',
      appVersion: '1.2.3',
    );

    expect(await gateway.loadHubOrigin(), 'https://official.example');
    final status = await gateway.testHubOrigin(
      'https://self-hosted.example/base',
    );
    expect(status.isReady, isTrue);
    expect(requests.single.path, '/base/v1/search');

    await gateway.saveHubOrigin('https://self-hosted.example/base/');
    expect(await gateway.loadHubOrigin(), 'https://self-hosted.example/base');
    await gateway.discover(DiscoveryCollection.search, query: 'flutter');
    expect(requests.last.host, 'self-hosted.example');
    expect(requests.last.path, '/base/v1/search');
    final restored = RealSkillsGateway(
      httpClient: client,
      hubBaseUrl: 'https://official.example',
      appVersion: '1.2.3',
    );
    expect(await restored.loadHubOrigin(), 'https://self-hosted.example/base');

    await restored.resetHubOrigin();
    expect(await restored.loadHubOrigin(), 'https://official.example');
  });

  test('hub settings reject unsafe or malformed origins', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = RealSkillsGateway(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
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
    'Added Projects persist, relocate by stable identity, and remove only the App reference',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('skillsgo-projects-');
      addTearDown(() => root.delete(recursive: true));
      final original = Directory('${root.path}/plain project');
      final relocated = Directory('${root.path}/moved project');
      final unselected = Directory('${root.path}/never selected');
      await original.create();
      await relocated.create();
      await unselected.create();
      await File('${original.path}/skillsgo.yaml').writeAsString('keep: true');
      await File('${original.path}/skillsgo-lock.yaml').writeAsString('keep');
      await Directory(
        '${original.path}/.agents/skills',
      ).create(recursive: true);
      final selections = <String>[original.path, relocated.path];
      final inspected = <String>[];
      Future<({ProjectAccessState state, String? diagnostic})> inspect(
        String path,
      ) async {
        inspected.add(path);
        return (state: ProjectAccessState.accessible, diagnostic: null);
      }

      final gateway = RealSkillsGateway(
        directoryPicker: ({initialDirectory}) async => selections.removeAt(0),
        projectPathInspector: inspect,
      );
      final added = await gateway.addProject();
      expect(added, isNotNull);
      expect(added!.name, 'plain project');
      expect(inspected, [original.path]);
      expect(inspected, isNot(contains(unselected.path)));

      final restarted = RealSkillsGateway(
        directoryPicker: ({initialDirectory}) async {
          expect(initialDirectory, original.path);
          return selections.removeAt(0);
        },
        projectPathInspector: inspect,
      );
      final restored = await restarted.loadAddedProjects();
      expect(restored.single.id, added.id);
      expect(restored.single.path, original.path);
      final moved = await restarted.relocateProject(added.id);
      expect(moved!.id, added.id);
      expect(moved.path, relocated.path);

      await restarted.removeProject(added.id);
      expect(await restarted.loadAddedProjects(), isEmpty);
      expect(
        await File('${original.path}/skillsgo.yaml').readAsString(),
        'keep: true',
      );
      expect(
        await File('${original.path}/skillsgo-lock.yaml').readAsString(),
        'keep',
      );
      expect(
        await Directory('${original.path}/.agents/skills').exists(),
        isTrue,
      );
    },
  );

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
      directoryPicker: ({initialDirectory}) async => selections.removeAt(0),
      projectPathInspector: (path) async => states[path]!,
    );

    for (var index = 0; index < 3; index++) {
      await gateway.addProject();
    }
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
      var hubRequests = 0;
      final runner = _FakeProcessRunner()
        ..responses.addAll([
          ProcessOutput(
            exitCode: 0,
            stdout: jsonEncode({
              'schemaVersion': 3,
              'entries': [
                {
                  'identity': 'external:offline',
                  'name': 'offline-skill',
                  'coordinate': '',
                  'provenance': 'external',
                  'risk': 'unknown',
                  'health': 'healthy',
                  'agents': ['codex'],
                  'projects': <String>[],
                  'versions': <String>[],
                  'versionDivergence': false,
                  'targets': [
                    {
                      'scope': 'user',
                      'agent': 'codex',
                      'path': skillDirectory.path,
                      'mode': 'external',
                      'version': '',
                      'receiptState': 'missing',
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
        httpClient: MockClient((request) async {
          hubRequests++;
          throw const SocketException('Hub offline');
        }),
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
      expect(hubRequests, 0);
    },
  );

  test('hub settings turn transport failures into structured health', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = RealSkillsGateway(
      httpClient: MockClient(
        (request) async =>
            throw http.ClientException('TLS handshake failed', request.url),
      ),
      hubBaseUrl: 'https://official.example',
      appVersion: '1.2.3',
    );

    final status = await gateway.testHubOrigin('https://self-hosted.example');

    expect(status.state, HealthState.unreachable);
    expect(status.issue, HubIssue.connectionFailure);
  });

  test('Personal risk policy and product diagnostics are stable', () async {
    SharedPreferences.setMockInitialValues({});
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":1,"store":{"path":"/Users/test/.skillsgo/store","state":"not_initialized"}}',
        stderr: '',
      );
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
    expect((await gateway.inspectStorage()).state, HealthState.notInitialized);
    expect(runner.lastArguments, ['diagnostics', '--output', 'json']);
    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout:
          '{"schemaVersion":1,"store":{"path":"/Users/test/.skillsgo/store","state":"ready"}}',
      stderr: '',
    );
    expect((await gateway.inspectStorage()).state, HealthState.ready);
    expect(await gateway.loadAppVersion(), '3.2.1');
  });

  test(
    'detectCli verifies the bundled executable without searching PATH',
    () async {
      final runner = _FakeProcessRunner()
        ..result = ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '0.1.0',
            'appProtocolVersion': 8,
            'os': 'darwin',
            'architecture': 'arm64',
          }),
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        bundledCliPath:
            '/Applications/SkillsGo.app/Contents/Resources/bin/skillsgo',
        allowDeveloperCliOverride: false,
        expectedCliOS: 'darwin',
      );

      final status = await gateway.detectCli();

      expect(status.availability, CliAvailability.ready);
      expect(status.version, '0.1.0');
      expect(
        status.path,
        '/Applications/SkillsGo.app/Contents/Resources/bin/skillsgo',
      );
      expect(runner.calls, hasLength(1));
      expect(
        runner.calls.single.executable,
        '/Applications/SkillsGo.app/Contents/Resources/bin/skillsgo',
      );
      expect(runner.calls.single.arguments, ['version', '--output', 'json']);
    },
  );

  test('detectCli reports a damaged bundled executable response', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout: '{"product":"not-skillsgo"}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
      expectedCliOS: 'darwin',
    );

    final status = await gateway.detectCli();

    expect(status.availability, CliAvailability.incompatible);
    expect(status.issue, CliIssue.damaged);
    expect(status.path, '/bundle/skillsgo');
  });

  test('detectCli reports a missing or non-runnable bundled CLI', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 127,
        stdout: '',
        stderr: 'No such file',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
    );

    final status = await gateway.detectCli();

    expect(status.availability, CliAvailability.missing);
    expect(status.issue, CliIssue.missing);
    expect(runner.calls, hasLength(1));
  });

  test('detectCli rejects an incompatible App protocol', () async {
    final runner = _FakeProcessRunner()
      ..result = ProcessOutput(
        exitCode: 0,
        stdout: jsonEncode({
          'schemaVersion': 1,
          'product': 'skillsgo',
          'version': '9.0.0',
          'appProtocolVersion': 1,
          'os': 'darwin',
          'architecture': 'arm64',
        }),
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
    );

    final status = await gateway.detectCli();

    expect(status.availability, CliAvailability.incompatible);
    expect(status.issue, CliIssue.incompatible);
    expect(status.version, '9.0.0');
  });

  test('detectCli rejects a CLI built for another operating system', () async {
    final runner = _FakeProcessRunner()
      ..result = ProcessOutput(
        exitCode: 0,
        stdout: jsonEncode({
          'schemaVersion': 1,
          'product': 'skillsgo',
          'version': '0.1.0',
          'appProtocolVersion': 8,
          'os': 'linux',
          'architecture': 'arm64',
        }),
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
    );

    final status = await gateway.detectCli();

    expect(status.availability, CliAvailability.incompatible);
    expect(status.issue, CliIssue.incompatible);
  });

  test(
    'detectCli accepts a different version with a compatible protocol',
    () async {
      final runner = _FakeProcessRunner()
        ..result = ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '7.4.2',
            'appProtocolVersion': 8,
            'os': 'darwin',
            'architecture': 'arm64',
          }),
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        bundledCliPath: '/bundle/skillsgo',
        allowDeveloperCliOverride: false,
        expectedCliOS: 'darwin',
      );

      final status = await gateway.detectCli();

      expect(status.availability, CliAvailability.ready);
      expect(status.version, '7.4.2');
    },
  );

  test('detectCli permits an explicit development override', () async {
    final runner = _FakeProcessRunner()
      ..result = ProcessOutput(
        exitCode: 0,
        stdout: jsonEncode({
          'schemaVersion': 1,
          'product': 'skillsgo',
          'version': 'dev',
          'appProtocolVersion': 8,
          'os': 'darwin',
          'architecture': 'arm64',
        }),
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: true,
      expectedCliOS: 'darwin',
    );

    final status = await gateway.detectCli(customPath: '/dev bin/skillsgo');

    expect(status.availability, CliAvailability.ready);
    expect(status.path, '/dev bin/skillsgo');
    expect(runner.calls.single.executable, '/dev bin/skillsgo');
    expect(runner.calls.single.arguments, ['version', '--output', 'json']);
  });

  test('detectCli ignores development overrides in production mode', () async {
    final runner = _FakeProcessRunner()
      ..result = ProcessOutput(
        exitCode: 0,
        stdout: jsonEncode({
          'schemaVersion': 1,
          'product': 'skillsgo',
          'version': '1.0.0',
          'appProtocolVersion': 8,
          'os': 'darwin',
          'architecture': 'arm64',
        }),
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
      expectedCliOS: 'darwin',
    );

    await gateway.detectCli(customPath: '/untrusted/skillsgo');

    expect(runner.calls.single.executable, '/bundle/skillsgo');
  });

  test('failed revalidation prevents later CLI operations', () async {
    final runner = _FakeProcessRunner()
      ..responses.addAll([
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '0.1.0',
            'appProtocolVersion': 8,
            'os': 'darwin',
            'architecture': 'arm64',
          }),
          stderr: '',
        ),
        const ProcessOutput(
          exitCode: 0,
          stdout: '{"product":"damaged"}',
          stderr: '',
        ),
        const ProcessOutput(
          exitCode: 0,
          stdout: '{"product":"still-damaged"}',
          stderr: '',
        ),
      ]);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
      expectedCliOS: 'darwin',
    );

    expect((await gateway.detectCli()).isReady, isTrue);
    expect(
      (await gateway.detectCli()).availability,
      CliAvailability.incompatible,
    );

    await expectLater(gateway.listInstalled(), throwsA(isA<SkillsException>()));
    expect(runner.lastArguments, ['version', '--output', 'json']);
  });

  test('search returns domain summaries from the official response', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":3,"entries":[{"identity":"hub:github.com/flutter/skills/-/responsive-layout","name":"Responsive Layout","coordinate":"github.com/flutter/skills/-/responsive-layout","provenance":"hub","risk":"unknown","health":"healthy","agents":["codex"],"projects":["/tmp/project"],"versions":["v1.2.3"],"versionDivergence":false,"targets":[{"scope":"user","agent":"codex","path":"/tmp/one","mode":"copy","version":"v1.2.3","receiptState":"present","health":"healthy"},{"scope":"project","projectRoot":"/tmp/project","agent":"codex","path":"/tmp/project/.agents/skills/two","mode":"copy","version":"v1.2.3","receiptState":"present","health":"healthy"}]}]}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/search');
        expect(request.url.queryParameters['offset'], '0');
        return http.Response(
          jsonEncode({
            'collection': 'search',
            'skills': [
              {
                'coordinate': 'github.com/flutter/skills/-/responsive-layout',
                'source': 'github.com/flutter/skills',
                'imageUrl': 'https://images.example/flutter.png',
                'skillPath': 'responsive-layout',
                'name': 'Responsive Layout',
                'description': 'Build adaptive Flutter layouts.',
                'latestVersion': 'v1.2.3',
                'trustLevel': 'community_verified',
                'riskAssessment': 'low',
                'metric': {
                  'kind': 'all_time_installs',
                  'value': 1200,
                  'change': 0,
                },
              },
            ],
            'page': {'limit': 20, 'offset': 0, 'nextOffset': 20},
          }),
          200,
        );
      }),
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    final page = await gateway.discover(
      DiscoveryCollection.search,
      query: 'responsive',
    );
    final results = page.skills;

    expect(results, hasLength(1));
    expect(results.single.source, 'github.com/flutter/skills');
    expect(results.single.imageUrl, 'https://images.example/flutter.png');
    expect(results.single.skillId, 'responsive-layout');
    expect(results.single.installs, 1200);
    expect(results.single.description, 'Build adaptive Flutter layouts.');
    expect(results.single.trustLevel, SkillTrustLevel.communityVerified);
    expect(results.single.riskAssessment, SkillRiskAssessment.low);
    expect(results.single.localTargetCount, 2);
    expect(page.nextOffset, 20);

    final installed = await gateway.listInstalled();
    expect(installed.single.agents, ['codex']);
    expect(installed.single.targetCount, 2);
  });

  test(
    'ranked discovery routes use distinct Hub collection parameters',
    () async {
      final requests = <Uri>[];
      final gateway = RealSkillsGateway(
        httpClient: MockClient((request) async {
          requests.add(request.url);
          final collection = request.url.queryParameters['sort']!;
          return http.Response(
            '{"collection":"$collection","skills":[],"page":{"limit":10,"offset":30,"nextOffset":null}}',
            200,
          );
        }),
        processRunner: _FakeProcessRunner()
          ..result = const ProcessOutput(exitCode: 0, stdout: '[]', stderr: ''),
        initialCliPath: '/usr/local/bin/skillsgo',
      );

      for (final collection in const [
        DiscoveryCollection.ranking,
        DiscoveryCollection.trending,
        DiscoveryCollection.hot,
      ]) {
        await gateway.discover(collection, limit: 10, offset: 30);
      }

      expect(requests.map((request) => request.queryParameters['sort']), [
        'all_time',
        'trending',
        'hot',
      ]);
    },
  );

  test('listInstalled parses unified inventory for explicit locations', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            r'{"schemaVersion":3,"entries":[{"identity":"hub:github.com/a/b","name":"testing","coordinate":"github.com/a/b","provenance":"hub","risk":"unknown","health":"receipt-missing","agents":["codex","claude-code"],"projects":["/work/project;$(touch nope)"],"versions":["v1.0.0","v2.0.0"],"versionDivergence":true,"targets":[{"scope":"user","projectRoot":"","agent":"codex","path":"/tmp/testing","mode":"copy","version":"v1.0.0","receiptState":"present","health":"local-modification"},{"scope":"project","projectRoot":"/work/project;$(touch nope)","agent":"claude-code","path":"/work/project;$(touch nope)/.claude/skills/testing","mode":"symlink","version":"v2.0.0","receiptState":"missing","health":"receipt-missing"}]}]}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    final skills = await gateway.listInstalled(
      projects: const [
        AddedProject(
          id: 'project-id',
          name: 'Project',
          path: r'/work/project;$(touch nope)',
          accessState: ProjectAccessState.accessible,
        ),
        AddedProject(
          id: 'missing',
          name: 'Missing',
          path: '/work/missing',
          accessState: ProjectAccessState.missing,
        ),
      ],
    );

    expect(skills.single.name, 'testing');
    expect(skills.single.identity, 'hub:github.com/a/b');
    expect(skills.single.coordinate, 'github.com/a/b');
    expect(skills.single.isLinkedToCodex, isTrue);
    expect(skills.single.targetCount, 2);
    expect(skills.single.versionDivergence, isTrue);
    expect(skills.single.versions, ['v1.0.0', 'v2.0.0']);
    expect(skills.single.projects, [r'/work/project;$(touch nope)']);
    expect(skills.single.targets.last.mode, InstallationMode.symlink);
    expect(skills.single.health, InstallationHealth.receiptMissing);
    expect(
      skills.single.targets.first.health,
      InstallationHealth.localModification,
    );
    expect(skills.single.targets.last.receiptState, ReceiptState.missing);
    expect(
      skills.single.targets.last.health,
      InstallationHealth.receiptMissing,
    );
    expect(runner.lastArguments, [
      'inventory',
      '--user',
      '--project',
      r'/work/project;$(touch nope)',
      '--output',
      'json',
    ]);
  });

  test('listInstalled rejects an unknown installation scope', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":3,"entries":[{"identity":"hub:github.com/a/b","name":"testing","coordinate":"github.com/a/b","provenance":"hub","risk":"unknown","health":"healthy","agents":["codex"],"projects":[],"versions":["v1.0.0"],"versionDivergence":false,"targets":[{"scope":"workspace","agent":"codex","path":"/tmp/testing","mode":"copy","version":"v1.0.0","receiptState":"present","health":"healthy"}]}]}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(gateway.listInstalled(), throwsA(isA<SkillsException>()));
  });

  test('listInstalled rejects the obsolete inventory schema', () async {
    final gateway = RealSkillsGateway(
      processRunner: _FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout: '{"schemaVersion":2,"entries":[]}',
          stderr: '',
        ),
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(gateway.listInstalled(), throwsA(isA<SkillsException>()));
  });

  test('listInstalled keeps same-name External Installations distinct', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":3,"entries":[{"identity":"external:abc","name":"testing","coordinate":"","provenance":"external","risk":"unknown","health":"healthy","agents":["codex"],"projects":[],"versions":[],"versionDivergence":false,"targets":[{"scope":"user","agent":"codex","path":"/tmp/external/testing","mode":"external","version":"","receiptState":"missing","health":"healthy"}]},{"identity":"hub:github.com/a/b/-/testing","name":"testing","coordinate":"github.com/a/b/-/testing","provenance":"hub","risk":"low","health":"healthy","agents":["codex"],"projects":[],"versions":["v1"],"versionDivergence":false,"targets":[{"scope":"user","agent":"codex","path":"/tmp/managed/testing","mode":"copy","version":"v1","receiptState":"present","health":"healthy"}]}]}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    final skills = await gateway.listInstalled();

    expect(skills, hasLength(2));
    expect(skills.map((skill) => skill.name).toSet(), {'testing'});
    final external = skills.singleWhere(
      (skill) => skill.provenance == LibraryProvenance.external,
    );
    expect(external.identity, 'external:abc');
    expect(external.coordinate, isEmpty);
    expect(external.versions, isEmpty);
    expect(external.targets.single.mode, InstallationMode.external);
    expect(external.targets.single.version, isEmpty);
    expect(external.targets.single.receiptState, ReceiptState.missing);
  });

  test(
    'inspectAgents parses complete versioned JSON and preserves a hostile CLI path',
    () async {
      final runner = _FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              r'{"schemaVersion":1,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["project","user"],"userTarget":{"path":"/Users/test/.codex/skills;$(touch nope)","exists":true}},{"id":"eve","displayName":"Eve","installed":false,"supportedScopes":["project"],"userTarget":null}]}',
          stderr: '',
        );
      const executable = r'/tmp/skillsgo bin;$(touch should-not-run)';
      final gateway = RealSkillsGateway(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        processRunner: runner,
        initialCliPath: executable,
      );

      final report = await gateway.inspectAgents();

      expect(report.schemaVersion, 1);
      expect(report.agents, hasLength(2));
      expect(report.installed.single.id, 'codex');
      expect(report.agents.first.displayName, 'Codex');
      expect(report.agents.first.supportedScopes, [
        InstallationScope.project,
        InstallationScope.user,
      ]);
      expect(
        report.agents.first.userTarget?.path,
        r'/Users/test/.codex/skills;$(touch nope)',
      );
      expect(runner.calls.single.executable, executable);
      expect(runner.calls.single.arguments, ['agents', '--output', 'json']);
    },
  );

  test('inspectAgents rejects malformed machine schemas', () async {
    for (final body in [
      '{"schemaVersion":2,"agents":[]}',
      '{"schemaVersion":1,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["machine"],"userTarget":null}]}',
      '{"schemaVersion":1,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["user"],"userTarget":null}]}',
      '{"schemaVersion":1,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["project"],"userTarget":{"path":"/tmp","exists":true}}]}',
      '{"schemaVersion":1,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["project"],"userTarget":null},{"id":"codex","displayName":"Duplicate","installed":false,"supportedScopes":["project"],"userTarget":null}]}',
    ]) {
      final gateway = RealSkillsGateway(
        processRunner: _FakeProcessRunner()
          ..result = ProcessOutput(exitCode: 0, stdout: body, stderr: ''),
        initialCliPath: '/usr/local/bin/skillsgo',
      );

      await expectLater(
        gateway.inspectAgents(),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            SkillsFailureKind.invalidResponse,
          ),
        ),
      );
    }
  });

  test(
    'CLI exit codes distinguish availability from malformed output',
    () async {
      for (final testCase in [
        (exitCode: 69, kind: SkillsFailureKind.offline, offline: true),
        (exitCode: 75, kind: SkillsFailureKind.timeout, offline: false),
        (exitCode: 1, kind: SkillsFailureKind.server, offline: false),
      ]) {
        final gateway = RealSkillsGateway(
          processRunner: _FakeProcessRunner()
            ..result = ProcessOutput(
              exitCode: testCase.exitCode,
              stdout: '',
              stderr: 'arbitrary localized diagnostics',
            ),
          initialCliPath: '/usr/local/bin/skillsgo',
        );

        await expectLater(
          gateway.inspectAgents(),
          throwsA(
            isA<SkillsException>()
                .having((error) => error.kind, 'kind', testCase.kind)
                .having(
                  (error) => error.isOffline,
                  'isOffline',
                  testCase.offline,
                ),
          ),
        );
      }

      final malformed = RealSkillsGateway(
        processRunner: _FakeProcessRunner()
          ..result = const ProcessOutput(
            exitCode: 0,
            stdout: 'not JSON',
            stderr: '',
          ),
        initialCliPath: '/usr/local/bin/skillsgo',
      );
      await expectLater(
        malformed.inspectAgents(),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            SkillsFailureKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test('search rejects non-2xx, invalid JSON and missing fields', () async {
    for (final failure in [
      (
        response: http.Response('nope', 400),
        kind: SkillsFailureKind.validation,
      ),
      (response: http.Response('nope', 503), kind: SkillsFailureKind.server),
      (
        response: http.Response('{', 200),
        kind: SkillsFailureKind.invalidResponse,
      ),
      (
        response: http.Response(
          '{"collection":"search","skills":[{"name":"missing"}],"page":{"limit":20,"offset":0,"nextOffset":null}}',
          200,
        ),
        kind: SkillsFailureKind.invalidResponse,
      ),
    ]) {
      final gateway = RealSkillsGateway(
        httpClient: MockClient((_) async => failure.response),
        processRunner: _FakeProcessRunner(),
      );
      await expectLater(
        gateway.discover(DiscoveryCollection.search, query: 'test'),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            failure.kind,
          ),
        ),
      );
    }
  });

  test('search distinguishes offline and timeout transport failures', () async {
    final offline = RealSkillsGateway(
      httpClient: MockClient(
        (_) async => throw const SocketException('offline'),
      ),
      processRunner: _FakeProcessRunner(),
    );
    await expectLater(
      offline.discover(DiscoveryCollection.search, query: 'test'),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.offline,
        ),
      ),
    );

    final timeout = RealSkillsGateway(
      httpClient: MockClient(
        (_) => Future.delayed(
          const Duration(milliseconds: 20),
          () => http.Response('{}', 200),
        ),
      ),
      processRunner: _FakeProcessRunner(),
      discoveryTimeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      timeout.discover(DiscoveryCollection.search, query: 'test'),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.timeout,
        ),
      ),
    );
  });

  test(
    'remote detail reads one auditable Hub contract and local targets',
    () async {
      final runner = _FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":3,"entries":[{"identity":"hub:github.com/a/b/-/test","name":"Test","coordinate":"github.com/a/b/-/test","provenance":"hub","risk":"unknown","health":"healthy","agents":["codex"],"projects":[],"versions":["v0.0.0-test"],"versionDivergence":false,"targets":[{"scope":"user","agent":"codex","path":"/tmp/test","mode":"copy","version":"v0.0.0-test","receiptState":"present","health":"healthy"}]}]}',
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/skills/github.com/a/b/-/test');
          return http.Response(
            jsonEncode({
              'coordinate': 'github.com/a/b/-/test',
              'name': 'Test',
              'description': 'Test Skill',
              'source': 'github.com/a/b',
              'repository': 'github.com/a/b',
              'imageUrl': 'https://images.example/a.png',
              'installs': 42,
              'githubStars': 12800,
              'sourceUpdatedAt': '2026-07-15T00:00:00Z',
              'archiveSize': 24576,
              'requestedVersion': 'main',
              'immutableVersion': 'v0.0.0-test',
              'commitSHA': 'commit-abc',
              'treeSHA': 'tree-def',
              'sourceRef': 'refs/heads/main',
              'contentDigest': 'sha256:digest',
              'manifest': 'name: test\ndescription: Test Skill',
              'instructions': '# Real instructions',
              'trustLevel': 'publisher_verified',
              'riskAssessment': {
                'level': 'medium',
                'scannerVersion': 'file-signals/v1',
                'evidence': [
                  {'code': 'script_file', 'path': 'scripts/run.sh'},
                ],
              },
              'files': [
                {
                  'path': 'SKILL.md',
                  'size': 30,
                  'kind': 'instructions',
                  'executable': false,
                  'binary': false,
                  'content': '# Real instructions',
                  'truncated': false,
                },
                {
                  'path': 'scripts/run.sh',
                  'size': 12,
                  'kind': 'script',
                  'executable': true,
                  'binary': false,
                  'content': 'echo test',
                  'truncated': false,
                },
              ],
              'hasExecutableContent': true,
              'executableFiles': ['scripts/run.sh'],
            }),
            200,
          );
        }),
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
      );
      const skill = SkillSummary(
        id: 'github.com/a/b/-/test',
        skillId: 'test',
        name: 'Test',
        source: 'github.com/a/b/-/test',
        installs: 2,
      );

      final detail = await gateway.loadRemoteDetail(skill);
      expect(detail.markdown, '# Real instructions');
      expect(detail.imageUrl, 'https://images.example/a.png');
      expect(detail.installs, 42);
      expect(detail.repository, 'github.com/a/b');
      expect(detail.githubStars, 12800);
      expect(detail.sourceUpdatedAt, DateTime.utc(2026, 7, 15).toLocal());
      expect(detail.archiveSize, 24576);
      expect(detail.immutableVersion, 'v0.0.0-test');
      expect(detail.commitSHA, 'commit-abc');
      expect(detail.treeSHA, 'tree-def');
      expect(detail.contentDigest, 'sha256:digest');
      expect(detail.trustLevel, SkillTrustLevel.publisherVerified);
      expect(detail.riskAssessment, SkillRiskAssessment.medium);
      expect(detail.riskEvidence.single.path, 'scripts/run.sh');
      expect(detail.files.last.contents, 'echo test');
      expect(detail.hasExecutableContent, isTrue);
      expect(detail.installationTargets.single.agent, 'codex');
      expect(detail.installationTargets.single.version, 'v0.0.0-test');
    },
  );

  test(
    'remote detail classifies malformed, unavailable, offline and timeout states',
    () async {
      for (final testCase in [
        (
          response: http.Response(
            '{"code":"artifact_invalid","error":"invalid"}',
            502,
          ),
          error: null,
          timeout: const Duration(seconds: 1),
          kind: SkillsFailureKind.invalidResponse,
        ),
        (
          response: http.Response(
            '{"code":"artifact_unavailable","error":"missing"}',
            503,
          ),
          error: null,
          timeout: const Duration(seconds: 1),
          kind: SkillsFailureKind.artifactUnavailable,
        ),
        (
          response: null,
          error: const SocketException('offline'),
          timeout: const Duration(seconds: 1),
          kind: SkillsFailureKind.offline,
        ),
        (
          response: null,
          error: null,
          timeout: const Duration(milliseconds: 1),
          kind: SkillsFailureKind.timeout,
        ),
      ]) {
        final gateway = RealSkillsGateway(
          httpClient: MockClient((_) async {
            if (testCase.error != null) throw testCase.error!;
            if (testCase.response != null) return testCase.response!;
            return Future.delayed(
              const Duration(milliseconds: 20),
              () => http.Response('{}', 200),
            );
          }),
          processRunner: _FakeProcessRunner(),
          detailTimeout: testCase.timeout,
        );

        await expectLater(
          gateway.loadRemoteDetail(
            const SkillSummary(
              id: 'github.com/a/b/-/test',
              skillId: 'test',
              name: 'Test',
              source: 'github.com/a/b',
              installs: 0,
            ),
          ),
          throwsA(
            isA<SkillsException>().having(
              (error) => error.kind,
              'kind',
              testCase.kind,
            ),
          ),
        );
      }
    },
  );

  test('hostile write inputs remain exact arguments without a shell', () async {
    final runner = _FakeProcessRunner();
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: r'/Applications/Skills Play/$(echo nope)/skillsgo',
    );
    const summary = SkillSummary(
      id: r'github.com/a/b/-/test;$(touch nope)',
      skillId: r"test name';$(touch nope)",
      name: 'Test',
      source: r'github.com/a/b/-/test;$(touch nope)',
      installs: 0,
    );
    const installed = InstalledSkill(
      identity: r'hub:github.com/a/b/-/Test ; $(touch nope)',
      name: r'Test ; $(touch nope)',
      path: r'/tmp/Test ; $(touch nope)',
      agents: ['codex'],
      targetCount: 1,
      coordinate: r'github.com/a/b/-/Test ; $(touch nope)',
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.user,
          path: r'/tmp/Test ; $(touch nope)',
          version: 'v1',
        ),
      ],
    );

    await gateway.install(summary);
    expect(
      runner.lastExecutable,
      r'/Applications/Skills Play/$(echo nope)/skillsgo',
    );
    expect(runner.lastArguments, [
      'add',
      r'github.com/a/b/-/test;$(touch nope)',
      '--skill',
      r"test name';$(touch nope)",
      '--global',
      '--agent',
      'codex',
      '--yes',
      '--output',
      'json',
      '--hub',
      'https://hub.skillsgo.ai',
    ]);
    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout: r'''
{"schemaVersion":1,"phase":"update-preflight","targets":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test ; $(touch nope)"},"name":"Test ; $(touch nope)","coordinate":"github.com/a/b/-/Test ; $(touch nope)","sourceRef":"main","fromVersion":"v1","toVersion":"v2","action":"update","stateToken":"sha256:state","workspaceLockChange":false}],"workspaceLockChanges":[],"summary":{"update":1,"current":0,"pinned":0,"failed":0}}
''',
      stderr: '',
    );
    await gateway.preflightUpdate(installed, installed.targets);
    expect(runner.lastArguments!.first, 'update');
    expect(runner.lastArguments![1], '--target');
    expect(jsonDecode(runner.lastArguments![2]), {
      'scope': 'user',
      'agent': 'codex',
      'mode': 'symlink',
      'path': r'/tmp/Test ; $(touch nope)',
      'coordinate': r'github.com/a/b/-/Test ; $(touch nope)',
      'version': 'v1',
    });
    expect(
      runner.lastArguments,
      containsAllInOrder([
        '--preflight',
        '--output',
        'json',
        '--hub',
        'https://hub.skillsgo.ai',
      ]),
    );
    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout: r'''
{"schemaVersion":1,"phase":"management-preflight","targets":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test ; $(touch nope)"},"name":"Test ; $(touch nope)","coordinate":"github.com/a/b/-/Test ; $(touch nope)","version":"v1","health":"healthy","receiptState":"present","allowedActions":["remove"],"stateToken":"sha256:state","workspaceMetadataChange":false}],"summary":{"removable":1,"repairable":0,"stoppable":0}}
''',
      stderr: '',
    );
    await gateway.preflightTargetManagement(installed, installed.targets);
    expect(runner.lastArguments!.first, 'manage');
    expect(runner.lastArguments![1], '--target');
    expect(jsonDecode(runner.lastArguments![2]), {
      'scope': 'user',
      'agent': 'codex',
      'mode': 'symlink',
      'path': r'/tmp/Test ; $(touch nope)',
      'coordinate': r'github.com/a/b/-/Test ; $(touch nope)',
      'version': 'v1',
    });
    expect(
      runner.lastArguments,
      containsAllInOrder(['--preflight', '--output', 'json']),
    );
    expect(
      runner.calls.map((call) => call.executable),
      isNot(contains('/bin/sh')),
    );
  });

  test(
    'explicit Installation Plans preserve cells and parse target results',
    () async {
      const coordinate = 'github.com/a/b/-/test';
      const projectRoot = r'/work/Project ;$(touch never)';
      final userTarget = {
        'scope': 'user',
        'agent': 'codex',
        'mode': 'symlink',
        'path': '/Users/test/.codex/skills/test',
      };
      final projectTarget = {
        'scope': 'project',
        'projectRoot': projectRoot,
        'agent': 'claude-code',
        'mode': 'copy',
        'path': '$projectRoot/.claude/skills/test',
      };
      final artifact = {
        'source': coordinate,
        'coordinate': coordinate,
        'version': 'v1',
        'name': 'test',
        'risk': 'high',
      };
      final runner = _FakeProcessRunner()
        ..responses.addAll([
          ProcessOutput(
            exitCode: 0,
            stdout: jsonEncode({
              'schemaVersion': 2,
              'phase': 'preflight',
              'artifact': artifact,
              'targets': [
                {
                  'target': userTarget,
                  'action': 'skip',
                  'reasonCode': 'identical-target',
                  'workspaceLockChange': false,
                },
                {
                  'target': projectTarget,
                  'action': 'replace',
                  'reasonCode': 'identity-collision',
                  'stateToken': 'sha256:reviewed-project',
                  'workspaceLockChange': true,
                },
              ],
              'summary': {
                'create': 0,
                'replace': 1,
                'skip': 1,
                'conflict': 0,
                'blockedByRisk': 0,
              },
              'workspaceLockChanges': [
                {
                  'projectRoot': projectRoot,
                  'path': '$projectRoot/skillsgo-lock.yaml',
                  'skill': 'test',
                  'toVersion': 'v1',
                },
              ],
            }),
            stderr: '',
          ),
          ProcessOutput(
            exitCode: 0,
            stdout: [
              {
                'schemaVersion': 2,
                'phase': 'execution-progress',
                'sequence': 1,
                'artifact': artifact,
                'target': userTarget,
                'action': 'skip',
                'state': 'started',
              },
              {
                'schemaVersion': 2,
                'phase': 'execution-progress',
                'sequence': 2,
                'artifact': artifact,
                'target': userTarget,
                'action': 'skip',
                'state': 'finished',
                'result': {
                  'target': userTarget,
                  'action': 'skip',
                  'outcome': 'skipped',
                },
              },
              {
                'schemaVersion': 2,
                'phase': 'execution-progress',
                'sequence': 3,
                'artifact': artifact,
                'target': projectTarget,
                'action': 'replace',
                'state': 'started',
              },
              {
                'schemaVersion': 2,
                'phase': 'execution-progress',
                'sequence': 4,
                'artifact': artifact,
                'target': projectTarget,
                'action': 'replace',
                'state': 'finished',
                'result': {
                  'target': projectTarget,
                  'action': 'replace',
                  'outcome': 'succeeded',
                },
              },
              {
                'schemaVersion': 2,
                'phase': 'execution',
                'artifact': artifact,
                'results': [
                  {
                    'target': userTarget,
                    'action': 'skip',
                    'outcome': 'skipped',
                  },
                  {
                    'target': projectTarget,
                    'action': 'replace',
                    'outcome': 'succeeded',
                  },
                ],
                'summary': {
                  'succeeded': 1,
                  'skipped': 1,
                  'conflict': 0,
                  'failed': 0,
                },
              },
            ].map(jsonEncode).join('\n'),
            stderr: '',
          ),
        ]);
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: r'/Applications/Skills Go/$(echo never)/skillsgo',
      );
      const skill = SkillSummary(
        id: coordinate,
        skillId: 'test',
        name: 'Test',
        source: 'github.com/a/b',
        installs: 0,
        latestVersion: 'v1',
      );
      const selections = [
        InstallationTargetSelection(
          scope: InstallationScope.user,
          agent: 'codex',
        ),
        InstallationTargetSelection(
          scope: InstallationScope.project,
          projectRoot: projectRoot,
          agent: 'claude-code',
          mode: InstallationMode.copy,
          resolution: InstallationTargetResolution.replace,
          expectedReason: 'identity-collision',
          expectedState: 'sha256:reviewed-project',
        ),
      ];

      final plan = await gateway.preflightInstall(
        skill,
        'v1',
        selections,
        riskConfirmed: true,
      );

      expect(plan.version, 'v1');
      expect(plan.riskAssessment, SkillRiskAssessment.high);
      expect(plan.targets.map((target) => target.action), [
        InstallationPlanAction.skip,
        InstallationPlanAction.replace,
      ]);
      expect(plan.workspaceLockChanges.single.projectRoot, projectRoot);
      expect(runner.lastArguments!.take(4), [
        'add',
        coordinate,
        '--skill',
        'test',
      ]);
      expect(
        runner.lastArguments,
        containsAllInOrder([
          '--version',
          'v1',
          '--confirm-risk',
          '--preflight',
        ]),
      );
      expect(runner.lastArguments, isNot(contains('--risk')));
      final targetArguments = <Map<String, dynamic>>[];
      for (var index = 0; index < runner.lastArguments!.length; index++) {
        if (runner.lastArguments![index] == '--target') {
          targetArguments.add(
            jsonDecode(runner.lastArguments![index + 1])
                as Map<String, dynamic>,
          );
        }
      }
      expect(targetArguments, [
        {'scope': 'user', 'agent': 'codex', 'mode': 'symlink'},
        {
          'scope': 'project',
          'projectRoot': projectRoot,
          'agent': 'claude-code',
          'mode': 'copy',
          'resolution': 'replace',
          'expectedReason': 'identity-collision',
          'expectedState': 'sha256:reviewed-project',
        },
      ]);

      final progress = <InstallationTargetProgress>[];
      final execution = await gateway.executeInstall(
        plan,
        onProgress: progress.add,
      );

      expect(execution.summary.succeeded, 1);
      expect(execution.summary.skipped, 1);
      expect(progress.map((event) => event.sequence), [1, 2, 3, 4]);
      expect(
        progress.last.result?.outcome,
        InstallationTargetOutcome.succeeded,
      );
      expect(runner.lastArguments, containsAllInOrder(['--version', 'v1']));
      expect(runner.lastArguments, containsAllInOrder(['--output', 'ndjson']));
      expect(
        runner.calls.map((call) => call.executable),
        everyElement(r'/Applications/Skills Go/$(echo never)/skillsgo'),
      );
      expect(
        runner.calls.expand((call) => call.arguments),
        isNot(contains('/bin/sh')),
      );
    },
  );

  test('Installation execution never parses human-readable output', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout: '已安装 1 个目标。',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/Applications/SkillsGo.app/skillsgo',
    );
    const target = InstallationPlanTarget(
      scope: InstallationScope.user,
      agent: 'codex',
      mode: InstallationMode.symlink,
      path: '/Users/test/.codex/skills/test',
    );
    const plan = InstallationPlan(
      source: 'github.com/a/b/-/test',
      coordinate: 'github.com/a/b/-/test',
      version: 'v1',
      name: 'test',
      selections: [
        InstallationTargetSelection(
          scope: InstallationScope.user,
          agent: 'codex',
        ),
      ],
      targets: [
        InstallationPlanItem(
          target: target,
          action: InstallationPlanAction.create,
          workspaceLockChange: false,
        ),
      ],
      summary: InstallationPlanSummary(
        create: 1,
        replace: 0,
        skip: 0,
        conflict: 0,
        blockedByRisk: 0,
      ),
      workspaceLockChanges: [],
      riskAssessment: SkillRiskAssessment.low,
      riskConfirmed: false,
      allowCritical: false,
    );

    await expectLater(
      gateway.executeInstall(plan),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.invalidResponse,
        ),
      ),
    );
    expect(runner.lastArguments, containsAllInOrder(['--output', 'ndjson']));
  });

  test('Installation Plan rejects malformed machine contracts', () async {
    const coordinate = 'github.com/a/b/-/test';
    const projectRoot = '/work/project';
    const skill = SkillSummary(
      id: coordinate,
      skillId: 'test',
      name: 'Test',
      source: 'github.com/a/b',
      installs: 0,
      latestVersion: 'v1',
    );
    const selections = [
      InstallationTargetSelection(
        scope: InstallationScope.user,
        agent: 'codex',
      ),
      InstallationTargetSelection(
        scope: InstallationScope.project,
        projectRoot: projectRoot,
        agent: 'claude-code',
        mode: InstallationMode.copy,
      ),
    ];

    Map<String, dynamic> validPreflight() => {
      'schemaVersion': 2,
      'phase': 'preflight',
      'artifact': {
        'source': coordinate,
        'coordinate': coordinate,
        'version': 'v1',
        'name': 'test',
        'risk': 'low',
      },
      'targets': [
        {
          'target': {
            'scope': 'user',
            'agent': 'codex',
            'mode': 'symlink',
            'path': '/Users/test/.codex/skills/test',
          },
          'action': 'skip',
          'reasonCode': 'identical-target',
          'workspaceLockChange': false,
        },
        {
          'target': {
            'scope': 'project',
            'projectRoot': projectRoot,
            'agent': 'claude-code',
            'mode': 'copy',
            'path': '$projectRoot/.claude/skills/test',
          },
          'action': 'create',
          'workspaceLockChange': true,
        },
      ],
      'summary': {
        'create': 1,
        'replace': 0,
        'skip': 1,
        'conflict': 0,
        'blockedByRisk': 0,
      },
      'workspaceLockChanges': <Map<String, dynamic>>[
        {
          'projectRoot': projectRoot,
          'path': '$projectRoot/skillsgo-lock.yaml',
          'skill': 'test',
          'toVersion': 'v1',
        },
      ],
    };

    final malformedPreflights = <Map<String, dynamic> Function()>[
      () => validPreflight()..['schemaVersion'] = 1,
      () => validPreflight()..['phase'] = 'execution',
      () {
        final value = validPreflight();
        ((value['targets'] as List).first as Map<String, dynamic>)['action'] =
            'unknown';
        return value;
      },
      () {
        final value = validPreflight();
        ((value['artifact'] as Map<String, dynamic>))['coordinate'] =
            'github.com/attacker/repo/-/test';
        return value;
      },
      () {
        final value = validPreflight();
        final targets = value['targets'] as List;
        value['targets'] = targets.reversed.toList();
        return value;
      },
      () {
        final value = validPreflight();
        ((value['summary'] as Map<String, dynamic>))['create'] = 2;
        return value;
      },
      () {
        final value = validPreflight();
        final locks = value['workspaceLockChanges'] as List;
        locks.add(Map<String, dynamic>.from(locks.single as Map));
        return value;
      },
      () {
        final value = validPreflight();
        final target = (value['targets'] as List).first as Map<String, dynamic>;
        target
          ..['action'] = 'conflict'
          ..['reasonCode'] = 'shared-target-conflict'
          ..['stateToken'] = 'sha256:shared'
          ..['affectedBindings'] = [
            {
              'agent': 'codex',
              'scope': 'user',
              'mode': 'symlink',
              'path': '/Users/test/.codex/skills/test',
            },
            {
              'agent': 'claude-code',
              'scope': 'user',
              'mode': 'symlink',
              'path': '/tmp/not-the-shared-target',
            },
          ];
        final summary = value['summary'] as Map<String, dynamic>;
        summary
          ..['skip'] = 0
          ..['conflict'] = 1;
        return value;
      },
    ];

    for (final malformed in malformedPreflights) {
      final runner = _FakeProcessRunner()
        ..responses.add(
          ProcessOutput(
            exitCode: 0,
            stdout: jsonEncode(malformed()),
            stderr: '',
          ),
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/Applications/SkillsGo.app/skillsgo',
      );
      await expectLater(
        gateway.preflightInstall(skill, 'v1', selections),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            SkillsFailureKind.invalidResponse,
          ),
        ),
      );
    }

    final runner = _FakeProcessRunner()
      ..responses.addAll([
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode(validPreflight()),
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 2,
            'phase': 'execution',
            'artifact': validPreflight()['artifact'],
            'results': [
              {
                'target':
                    ((validPreflight()['targets'] as List).first
                        as Map<String, dynamic>)['target'],
                'action': 'skip',
                'outcome': 'unknown',
              },
              {
                'target':
                    ((validPreflight()['targets'] as List).last
                        as Map<String, dynamic>)['target'],
                'action': 'create',
                'outcome': 'succeeded',
              },
            ],
            'summary': {
              'succeeded': 1,
              'skipped': 1,
              'conflict': 0,
              'failed': 0,
            },
          }),
          stderr: '',
        ),
      ]);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/Applications/SkillsGo.app/skillsgo',
    );
    final plan = await gateway.preflightInstall(skill, 'v1', selections);
    await expectLater(
      gateway.executeInstall(plan),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('local detail reads canonical SKILL.md without writing files', () async {
    final directory = await Directory.systemTemp.createTemp('skillsgo-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/SKILL.md');
    await file.writeAsString('# Local');
    final before = await file.lastModified();
    final gateway = RealSkillsGateway(processRunner: _FakeProcessRunner());

    final detail = await gateway.loadLocalDetail(
      InstalledSkill(
        name: 'Local',
        path: directory.path,
        agents: const ['codex'],
        targetCount: 1,
      ),
    );

    expect(detail.markdown, '# Local');
    expect(await file.lastModified(), before);
  });

  test(
    'local detail prefers a healthy target over an unhealthy first target',
    () async {
      final root = await Directory.systemTemp.createTemp('skillsgo-targets-');
      addTearDown(() => root.delete(recursive: true));
      final missing = Directory('${root.path}/missing');
      final healthy = Directory('${root.path}/healthy');
      await healthy.create();
      await File('${healthy.path}/SKILL.md').writeAsString('# Healthy target');
      final gateway = RealSkillsGateway(processRunner: _FakeProcessRunner());

      final detail = await gateway.loadLocalDetail(
        InstalledSkill(
          name: 'Local',
          path: missing.path,
          agents: const ['codex'],
          targetCount: 2,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.user,
              path: missing.path,
              version: 'v1',
              health: InstallationHealth.missing,
            ),
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.project,
              projectRoot: root.path,
              path: healthy.path,
              version: 'v1',
            ),
          ],
        ),
      );

      expect(detail.markdown, '# Healthy target');
      expect(detail.immutableVersion, 'v1');
      expect(detail.installationTargets, hasLength(2));
    },
  );

  test(
    'External detail inspection is read-only and exposes supporting files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'skillsgo-external-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await Directory('${directory.path}/scripts').create();
      final skillFile = File('${directory.path}/SKILL.md');
      final script = File('${directory.path}/scripts/run.sh');
      final notes = File('${directory.path}/notes.md');
      final large = File('${directory.path}/large.txt');
      await skillFile.writeAsString('# External instructions');
      await script.writeAsString('#!/bin/sh\necho external\n');
      await notes.writeAsString('# Notes');
      await large.writeAsString(
        'preview-${List.filled(256 * 1024, 'x').join()}',
      );
      final before = {
        for (final file in [skillFile, script, notes, large])
          file.path: await file.readAsBytes(),
      };
      final runner = _FakeProcessRunner();
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
      );
      final external = InstalledSkill(
        identity: 'external:abc',
        name: 'external',
        path: directory.path,
        agents: const ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        versions: const [],
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: directory.path,
            version: '',
            mode: InstallationMode.external,
            receiptState: ReceiptState.missing,
          ),
        ],
      );

      final detail = await gateway.loadLocalDetail(external);

      expect(detail.source, 'External');
      expect(detail.markdown, '# External instructions');
      expect(detail.riskAssessment, SkillRiskAssessment.unknown);
      expect(
        detail.files.map((file) => file.path),
        containsAll(['SKILL.md', 'notes.md', 'scripts/run.sh']),
      );
      expect(detail.hasExecutableContent, isTrue);
      expect(
        detail.files.singleWhere((file) => file.path == 'notes.md').contents,
        '# Notes',
      );
      final largePreview = detail.files.singleWhere(
        (file) => file.path == 'large.txt',
      );
      expect(largePreview.truncated, isTrue);
      expect(largePreview.contents, startsWith('preview-'));
      expect(largePreview.contents, isNotEmpty);
      await expectLater(
        gateway.preflightUpdate(external, external.targets),
        throwsA(isA<SkillsException>()),
      );
      await expectLater(
        gateway.preflightTargetManagement(external, external.targets),
        throwsA(isA<SkillsException>()),
      );
      expect(runner.calls, isEmpty);
      for (final file in [skillFile, script, notes, large]) {
        expect(await file.readAsBytes(), before[file.path]);
      }
    },
  );

  test(
    'External adoption preserves exact target arguments and reviewed Hub identity',
    () async {
      const path = '/tmp/external demo';
      const installed = InstalledSkill(
        identity: 'external:abc',
        name: 'External Demo',
        path: path,
        agents: ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: path,
            version: '',
            mode: InstallationMode.external,
            receiptState: ReceiptState.missing,
          ),
        ],
      );
      final runner = _FakeProcessRunner()
        ..responses.addAll(const [
          ProcessOutput(
            exitCode: 0,
            stdout:
                '{"schemaVersion":1,"phase":"adoption-preflight","identity":"external:abc","name":"External Demo","target":{"scope":"user","agent":"codex","path":"/tmp/external demo"},"contentDigest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","sourceHint":"github.com/acme/skills","stateToken":"sha256:state","matches":[{"coordinate":"github.com/acme/skills/-/demo","name":"Demo","source":"github.com/acme/skills","skillPath":"demo","immutableVersion":"sha256:version","commitSHA":"commit","treeSHA":"tree","contentDigest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}],"canImportLocal":true}',
            stderr: '',
          ),
          ProcessOutput(
            exitCode: 0,
            stdout:
                '{"schemaVersion":1,"phase":"adoption-execution","action":"associate-hub","name":"External Demo","coordinate":"github.com/acme/skills/-/demo","version":"sha256:version","provenance":"hub","contentDigest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","target":{"scope":"user","agent":"codex","path":"/tmp/external demo"}}',
            stderr: '',
          ),
        ]);
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
        hubBaseUrl: 'https://hub.example/base',
      );

      final preflight = await gateway.preflightExternalAdoption(installed);
      expect(preflight.matches.single.source, 'github.com/acme/skills');
      expect(preflight.matches.single.immutableVersion, 'sha256:version');
      expect(runner.lastArguments, [
        'adopt',
        '--target',
        jsonEncode({
          'identity': 'external:abc',
          'name': 'External Demo',
          'scope': 'user',
          'agent': 'codex',
          'path': path,
        }),
        '--preflight',
        '--output',
        'json',
        '--hub',
        'https://hub.example/base',
      ]);

      final result = await gateway.executeExternalAdoption(
        preflight.selectHubMatch(preflight.matches.single),
      );

      expect(result.provenance, LibraryProvenance.hub);
      expect(result.coordinate, 'github.com/acme/skills/-/demo');
      expect(jsonDecode(runner.lastArguments![2]), {
        'identity': 'external:abc',
        'name': 'External Demo',
        'scope': 'user',
        'agent': 'codex',
        'path': path,
        'action': 'associate-hub',
        'matchCoordinate': 'github.com/acme/skills/-/demo',
        'matchVersion': 'sha256:version',
        'stateToken': 'sha256:state',
      });
      expect(runner.lastArguments, contains('https://hub.example/base'));
    },
  );

  test(
    'Local import execution has no Hub argument and rejects human output',
    () async {
      const target = InstallationPlanTarget(
        scope: InstallationScope.user,
        agent: 'codex',
        mode: InstallationMode.copy,
        path: '/tmp/private',
      );
      const plan = ExternalAdoptionPlan(
        identity: 'external:private',
        name: 'Private',
        target: target,
        contentDigest:
            'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        stateToken: 'sha256:state',
        matches: [],
        canImportLocal: true,
      );
      final runner = _FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"adoption-execution","action":"import-local","name":"Private","coordinate":"local.skillsgo/abc/Private","version":"local-abc","provenance":"local","contentDigest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","target":{"scope":"user","agent":"codex","path":"/tmp/private"}}',
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
        hubBaseUrl: 'https://must-not-be-used.example',
      );

      final result = await gateway.executeExternalAdoption(
        plan.selectLocalImport(),
      );

      expect(result.provenance, LibraryProvenance.local);
      expect(runner.lastArguments, isNot(contains('--hub')));
      expect(jsonDecode(runner.lastArguments![2]), {
        'identity': 'external:private',
        'name': 'Private',
        'scope': 'user',
        'agent': 'codex',
        'path': '/tmp/private',
        'action': 'import-local',
        'stateToken': 'sha256:state',
      });

      runner.result = const ProcessOutput(
        exitCode: 0,
        stdout: 'Imported successfully.',
        stderr: '',
      );
      await expectLater(
        gateway.executeExternalAdoption(plan.selectLocalImport()),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            SkillsFailureKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test(
    'Local export honors cancellation and exact destination arguments',
    () async {
      const local = InstalledSkill(
        identity: 'local:abc',
        name: 'Private Demo',
        path: '/tmp/private',
        agents: ['codex'],
        targetCount: 1,
        coordinate: 'local.skillsgo/abc/Private-Demo',
        provenance: LibraryProvenance.local,
        versions: ['local-abc'],
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/tmp/private',
            version: 'local-abc',
            mode: InstallationMode.copy,
          ),
        ],
      );
      final cancelledRunner = _FakeProcessRunner();
      final cancelled = RealSkillsGateway(
        processRunner: cancelledRunner,
        initialCliPath: '/bin/skillsgo',
        savePathPicker: (_) async => null,
      );
      expect(await cancelled.exportLocalSkill(local), isNull);
      expect(cancelledRunner.calls, isEmpty);

      final runner = _FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"local-export","coordinate":"local.skillsgo/abc/Private-Demo","version":"local-abc","destination":"/tmp/export destination.zip"}',
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
        savePathPicker: (name) async {
          expect(name, 'Private Demo.zip');
          return '/tmp/export destination.zip';
        },
      );

      final result = await gateway.exportLocalSkill(local);

      expect(result?.succeeded, isTrue);
      expect(runner.lastArguments, [
        'export',
        '--coordinate',
        'local.skillsgo/abc/Private-Demo',
        '--version',
        'local-abc',
        '--destination',
        '/tmp/export destination.zip',
        '--output',
        'json',
      ]);

      runner.result = const ProcessOutput(
        exitCode: 0,
        stdout: 'Exported successfully.',
        stderr: '',
      );
      await expectLater(
        gateway.exportLocalSkill(local),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            SkillsFailureKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test(
    'Target Management Plans preserve exact targets and parse versioned NDJSON',
    () async {
      const coordinate = 'github.com/example/skills/-/test';
      const installed = InstalledSkill(
        identity: 'hub:$coordinate',
        name: 'Test',
        path: '/tmp/Test',
        agents: ['codex'],
        targetCount: 1,
        coordinate: coordinate,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/tmp/Test',
            version: 'v1',
          ),
        ],
      );
      final runner = _FakeProcessRunner()
        ..responses.addAll(const [
          ProcessOutput(
            exitCode: 0,
            stdout: '''
{"schemaVersion":1,"phase":"management-preflight","targets":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","version":"v1","health":"healthy","receiptState":"present","allowedActions":["remove"],"stateToken":"sha256:state","workspaceMetadataChange":false}],"summary":{"removable":1,"repairable":0,"stoppable":0}}
''',
            stderr: '',
          ),
          ProcessOutput(
            exitCode: 0,
            stdout: '''
{"schemaVersion":1,"phase":"management-progress","sequence":1,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","version":"v1","action":"remove","state":"started"}
{"schemaVersion":1,"phase":"management-progress","sequence":2,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","version":"v1","action":"remove","state":"finished","result":{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","version":"v1","action":"remove","outcome":"succeeded"}}
{"schemaVersion":1,"phase":"management-execution","results":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","version":"v1","action":"remove","outcome":"succeeded"}],"summary":{"succeeded":1,"failed":0}}
''',
            stderr: '',
          ),
        ]);
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
      );

      final preflight = await gateway.preflightTargetManagement(
        installed,
        installed.targets,
      );
      final targetKey = updateTargetKey(preflight.targets.single.target);
      final plan = preflight.selectActions({
        targetKey: TargetManagementAction.remove,
      });
      final progress = <TargetManagementProgress>[];
      final execution = await gateway.executeTargetManagement(
        plan,
        onProgress: progress.add,
      );

      expect(preflight.targets.single.allowedActions, [
        TargetManagementAction.remove,
      ]);
      expect(progress.map((event) => event.sequence), [1, 2]);
      expect(execution.summary.succeeded, 1);
      expect(execution.results.single.action, TargetManagementAction.remove);
      expect(runner.lastArguments!.first, 'manage');
      expect(jsonDecode(runner.lastArguments![2]), {
        'scope': 'user',
        'agent': 'codex',
        'mode': 'symlink',
        'path': '/tmp/Test',
        'coordinate': coordinate,
        'version': 'v1',
        'action': 'remove',
        'stateToken': 'sha256:state',
      });
      expect(runner.lastArguments, containsAll(['--output', 'ndjson']));

      runner.result = const ProcessOutput(
        exitCode: 0,
        stdout: 'Removed one target.',
        stderr: '',
      );
      await expectLater(
        gateway.executeTargetManagement(plan),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            SkillsFailureKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test('update check uses explicit target Update Plan JSON', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout: '''
{"schemaVersion":1,"phase":"update-preflight","targets":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","sourceRef":"main","fromVersion":"v1","toVersion":"v2","action":"update","stateToken":"sha256:state","workspaceLockChange":false}],"workspaceLockChanges":[],"summary":{"update":1,"current":0,"pinned":0,"failed":0}}
''',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );

    final states = await gateway.checkUpdates(const [
      InstalledSkill(
        identity: 'hub:github.com/example/skills/-/test',
        name: 'Test',
        path: '/tmp/Test',
        agents: ['codex'],
        targetCount: 1,
        coordinate: 'github.com/example/skills/-/test',
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/tmp/Test',
            version: 'v1',
          ),
        ],
      ),
    ]);

    expect(
      states['hub:github.com/example/skills/-/test'],
      UpdateState.available,
    );
    expect(runner.lastArguments!.first, 'update');
    expect(
      runner.lastArguments,
      containsAllInOrder(['--target', isA<String>()]),
    );
    final target = jsonDecode(runner.lastArguments![2]) as Map<String, dynamic>;
    expect(target, {
      'scope': 'user',
      'agent': 'codex',
      'mode': 'symlink',
      'path': '/tmp/Test',
      'coordinate': 'github.com/example/skills/-/test',
      'version': 'v1',
    });
    expect(runner.lastArguments, containsAll(['--preflight', 'json']));
  });

  test('update execution parses only versioned target NDJSON', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout: '''
{"schemaVersion":1,"phase":"update-progress","sequence":1,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","state":"started"}
{"schemaVersion":1,"phase":"update-progress","sequence":2,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","state":"finished","result":{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","outcome":"succeeded"}}
{"schemaVersion":1,"phase":"update-execution","results":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","coordinate":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","outcome":"succeeded"}],"summary":{"succeeded":1,"skipped":0,"failed":0}}
''',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );
    const target = InstallationPlanTarget(
      scope: InstallationScope.user,
      agent: 'codex',
      mode: InstallationMode.symlink,
      path: '/tmp/Test',
    );
    const plan = UpdatePlan(
      targets: [
        UpdatePlanItem(
          target: target,
          name: 'Test',
          coordinate: 'github.com/example/skills/-/test',
          sourceRef: 'main',
          fromVersion: 'v1',
          toVersion: 'v2',
          action: UpdatePlanAction.update,
          stateToken: 'sha256:state',
          workspaceLockChange: false,
        ),
      ],
      workspaceLockChanges: [],
      summary: UpdatePlanSummary(update: 1, current: 0, pinned: 0, failed: 0),
    );
    final progress = <UpdateTargetProgress>[];

    final execution = await gateway.executeUpdate(
      plan,
      onProgress: progress.add,
    );

    expect(progress, hasLength(2));
    expect(execution.summary.succeeded, 1);
    expect(execution.results.single.toVersion, 'v2');
    expect(runner.lastArguments, containsAll(['--output', 'ndjson']));

    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout: '正在更新目标……',
      stderr: '',
    );
    await expectLater(
      gateway.executeUpdate(plan),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.invalidResponse,
        ),
      ),
    );
  });
}

class _FakeProcessRunner implements ProcessRunner {
  ProcessOutput result = const ProcessOutput(
    exitCode: 0,
    stdout: '',
    stderr: '',
  );
  List<String>? lastArguments;
  String? lastExecutable;
  final calls = <({String executable, List<String> arguments})>[];
  final responses = <ProcessOutput>[];

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    lastExecutable = executable;
    lastArguments = arguments;
    calls.add((executable: executable, arguments: List.of(arguments)));
    final response = responses.isNotEmpty ? responses.removeAt(0) : result;
    if (onStdoutLine != null) {
      for (final line in const LineSplitter().convert(response.stdout)) {
        onStdoutLine(line);
      }
    }
    return response;
  }
}
