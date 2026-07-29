/*
 * [INPUT]: Uses controlled CLI Find reads, an HTTP Cloud-composed ranking server, inventory responses, the production SkillsGateway adapter, and equivalent GitHub source aliases.
 * [OUTPUT]: Specifies current-language single Find with local installed versions, source-language bounded candidate Find, CLI-owned unified explicit-source discovery, empty-input semantics, unified inventory, Agent catalog, visibility, and schema validation.
 * [POS]: Serves as the discovery and local inventory contract suite at the SkillsGateway seam.
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
  HttpOverrides.global = null;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('search returns domain summaries from the official response', () async {
    final runner = FakeProcessRunner()
      ..responses.addAll(const [
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"skills":[{"packagePath":"github.com/flutter/skills","imageUrl":"https://images.example/flutter.png","path":"responsive-layout","name":"responsive-layout","description":"Build adaptive Flutter layouts.","latestVersion":"v1.2.3"}],"pagination":{"page":0,"perPage":20,"hasMore":true}}',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout: '{"schemaVersion":1,"phase":"project-list","projects":[]}',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":7,"entries":[{"inventoryKey":"hub:github.com/flutter/skills:responsive-layout","name":"responsive-layout","packagePath":"github.com/flutter/skills","provenance":"hub","health":"healthy","agents":["codex"],"projects":["/tmp/project"],"versions":["v1.2.3"],"versionDivergence":false,"visibility":[],"targets":[{"scope":"global","agent":"codex","path":"/tmp/one","version":"v1.2.3","health":"healthy"},{"scope":"project","projectRoot":"/tmp/project","agent":"codex","path":"/tmp/project/.agents/skills/two","version":"v1.2.3","health":"healthy"}]}]}',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":7,"entries":[{"inventoryKey":"hub:github.com/flutter/skills:responsive-layout","name":"responsive-layout","packagePath":"github.com/flutter/skills","provenance":"hub","health":"healthy","agents":["codex"],"projects":["/tmp/project"],"versions":["v1.2.3"],"versionDivergence":false,"visibility":[],"targets":[{"scope":"global","agent":"codex","path":"/tmp/one","version":"v1.2.3","health":"healthy"},{"scope":"project","projectRoot":"/tmp/project","agent":"codex","path":"/tmp/project/.agents/skills/two","version":"v1.2.3","health":"healthy"}]}]}',
          stderr: '',
        ),
      ]);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    final page = await gateway.discover(
      DiscoveryCollection.search,
      query: 'responsive',
    );
    final results = page.skills;

    expect(results, hasLength(1));
    expect(results.single.packagePath, 'github.com/flutter/skills');
    expect(results.single.imageUrl, 'https://images.example/flutter.png');
    expect(results.single.installName, 'responsive-layout');
    expect(results.single.path, 'responsive-layout');
    expect(results.single.metricKind, isNull);
    expect(results.single.description, 'Build adaptive Flutter layouts.');
    expect(results.single.localTargetCount, 2);
    expect(results.single.localVersions, ['v1.2.3']);
    expect(page.pagination.nextPage, 1);
    expect(
      runner.calls
          .firstWhere((call) => call.arguments.first == 'find')
          .arguments,
      [
        'find',
        'responsive',
        '--hub',
        'https://hub.skillsgo.ai',
        '--lang',
        'en',
        '--page',
        '0',
        '--per-page',
        '20',
        '--output',
        'json',
      ],
    );

    final installed = await gateway.listInstalled();
    expect(installed.single.agents, ['codex']);
    expect(installed.single.targetCount, 2);
  });

  test('remote detail requests the CLI JSON contract explicitly', () async {
    final runner = FakeProcessRunner()
      ..responses.addAll(const [
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"packagePath":"github.com/example/skills","version":"v1.2.3","time":"2026-07-26T00:00:00Z","name":"demo","path":"skills/demo","description":"Demo skill.","content":"# Demo","sourceLanguage":"en","translated":true}',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout: '{"schemaVersion":7,"entries":[]}',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"packagePath":"github.com/example/skills","version":"v1.2.3","time":"2026-07-26T00:00:00Z","name":"demo","path":"skills/demo","description":"Demo skill.","content":"# Demo","sourceLanguage":"en","translated":false}',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout: '{"schemaVersion":7,"entries":[]}',
          stderr: '',
        ),
      ]);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    final detail = await gateway.loadRemoteDetail(
      const SkillSummary(
        packagePath: 'github.com/example/skills',
        installName: 'demo',
        name: 'demo',
        path: 'skills/demo',
        description: 'Demo skill.',
        latestVersion: 'v1.2.3',
      ),
    );

    expect(detail.content, '# Demo');
    expect(runner.calls.first.arguments, [
      'show',
      'github.com/example/skills@v1.2.3',
      '--path',
      'skills/demo',
      '--hub',
      'https://hub.skillsgo.ai',
      '--output',
      'json',
      '--lang',
      'en',
    ]);

    await gateway.loadRemoteDetail(
      const SkillSummary(
        packagePath: 'github.com/example/skills',
        installName: 'demo',
        name: 'demo',
        path: 'skills/demo',
        description: 'Demo skill.',
        latestVersion: 'v1.2.3',
      ),
      source: true,
    );
    final showCalls = runner.calls
        .where((call) => call.arguments.contains('show'))
        .toList();
    expect(showCalls.last.arguments, [
      'show',
      'github.com/example/skills@v1.2.3',
      '--path',
      'skills/demo',
      '--hub',
      'https://hub.skillsgo.ai',
      '--output',
      'json',
    ]);
  });

  test(
    'batch Find uses one CLI process with stdin and no inventory read',
    () async {
      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"candidates":[[{"packagePath":"github.com/example/skills","versions":["v1.2.3","v1.1.0"],"path":"skills/ask-matt","name":"ask-matt","description":"Route requests.","imageUrl":"https://github.com/example.png?size=256"}]]}',
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/usr/local/bin/skillsgo',
      );

      final results = await gateway.findSources(const [
        PackageFindQuery(name: 'ask-matt'),
      ]);

      expect(runner.calls, hasLength(1));
      expect(runner.lastArguments, [
        'hub',
        'find-candidates',
        '--input',
        '-',
        '--hub',
        'https://hub.skillsgo.ai',
        '--output',
        'json',
      ]);
      expect(jsonDecode(runner.lastStdin!)['queries'], [
        {'name': 'ask-matt'},
      ]);
      expect(results.single.single.versions, ['v1.2.3', 'v1.1.0']);
      expect(
        results.single.single.imageUrl,
        'https://github.com/example.png?size=256',
      );
    },
  );

  test('batch Find keeps ordinary large libraries below wire limits', () async {
    final runner = FakeProcessRunner();
    for (final range in [(0, 80), (80, 160), (160, 205)]) {
      runner.responses.add(
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'candidates': [
              for (var index = range.$1; index < range.$2; index++) <Object>[],
            ],
          }),
          stderr: '',
        ),
      );
    }
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    final results = await gateway.findSources([
      for (var index = 0; index < 205; index++)
        PackageFindQuery(name: 'skill-$index'),
    ]);

    expect(runner.calls, hasLength(3));
    expect(
      runner.stdins.map(
        (stdin) => (jsonDecode(stdin!)['queries'] as List).length,
      ),
      [80, 80, 45],
    );
    expect(results, hasLength(205));
  });

  test('Cloud ranking returns authoritative composed Skill cards', () async {
    final cloud = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestedCloudUris = <Uri>[];
    cloud.listen((request) async {
      requestedCloudUris.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"skills":[{"packagePath":"github.com/acme/skills","name":"demo","description":"Demo Skill","imageUrl":null,"path":"demo","latestVersion":"v1.0.0","metric":{"value":8,"change":5}}],"pagination":{"page":0,"perPage":20,"hasMore":false}}',
      );
      await request.response.close();
    });
    final runner = FakeProcessRunner()
      ..responses.addAll([
        ProcessOutput(
          exitCode: 0,
          stdout: '{"mode":"cloud","cloud":"http://127.0.0.1:${cloud.port}"}',
          stderr: '',
        ),
        const ProcessOutput(
          exitCode: 0,
          stdout: '{"schemaVersion":7,"entries":[]}',
          stderr: '',
        ),
      ]);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
      hubBaseUrl: 'https://hub.example.test',
    );
    await gateway.saveLanguage(AppLanguage.simplifiedChinese);

    final page = await gateway.discover(DiscoveryCollection.hot);

    expect(page.skills.single.packagePath, 'github.com/acme/skills');
    expect(page.skills.single.installs, 8);
    expect(page.skills.single.metricChange, 5);
    expect(requestedCloudUris.single.queryParameters['lang'], 'zh-Hans-CN');
    expect(runner.calls, hasLength(2));
    await cloud.close(force: true);
  });

  test(
    'empty-input discovery matrix preserves browse and search semantics',
    () async {
      final tests =
          <
            ({
              String name,
              DiscoveryCollection collection,
              String? wireCollection,
            })
          >[
            (
              name: 'empty search is rejected',
              collection: DiscoveryCollection.search,
              wireCollection: null,
            ),
            (
              name: 'ranking browses without a query',
              collection: DiscoveryCollection.ranking,
              wireCollection: 'all_time',
            ),
            (
              name: 'trending browses without a query',
              collection: DiscoveryCollection.trending,
              wireCollection: 'trending',
            ),
            (
              name: 'hot browses without a query',
              collection: DiscoveryCollection.hot,
              wireCollection: 'hot',
            ),
          ];

      expect(tests, hasLength(4));
      for (final tc in tests) {
        final runner = FakeProcessRunner();
        HttpServer? cloud;
        final requestedCloudPaths = <String>[];
        if (tc.wireCollection != null) {
          cloud = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          cloud.listen((request) async {
            requestedCloudPaths.add(request.uri.toString());
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'skills': <Object>[],
                'pagination': {'page': 0, 'perPage': 20, 'hasMore': false},
              }),
            );
            await request.response.close();
          });
          runner.responses.addAll([
            ProcessOutput(
              exitCode: 0,
              stdout:
                  '{"mode":"cloud","cloud":"http://127.0.0.1:${cloud.port}"}',
              stderr: '',
            ),
          ]);
        }
        final gateway = RealSkillsGateway(
          processRunner: runner,
          initialCliPath: '/usr/local/bin/skillsgo',
          hubBaseUrl: 'https://hub.example.test',
        );

        if (tc.wireCollection == null) {
          await expectLater(
            gateway.discover(tc.collection),
            throwsA(
              isA<SkillsException>().having(
                (error) => error.kind,
                'kind',
                SkillsFailureKind.validation,
              ),
            ),
            reason: tc.name,
          );
          expect(runner.calls, isEmpty, reason: tc.name);
          continue;
        }

        final page = await gateway.discover(tc.collection);
        expect(page.skills, isEmpty, reason: tc.name);
        expect(runner.calls.first.arguments, [
          'hub',
          'info',
          '--hub',
          'https://hub.example.test',
          '--output',
          'json',
        ]);
        expect(requestedCloudPaths, [
          '/api/v1/rankings/${tc.wireCollection}?page=0&perPage=20&lang=en',
        ]);
        await cloud?.close(force: true);
      }
    },
  );

  test(
    'explicit Git source discovery delegates unchanged input to CLI find',
    () async {
      final runner = FakeProcessRunner()
        ..responses.addAll([
          const ProcessOutput(
            exitCode: 0,
            stdout:
                '{"skills":[{"packagePath":"github.com/acme/skills","path":"skills/demo","latestVersion":"v1.2.3","name":"demo","description":"Demo Skill","imageUrl":"https://github.com/acme.png?size=72"}],"package":{"packagePath":"github.com/acme/skills","description":"Skills for product teams.","stars":7,"latestVersion":"v1.2.3","updatedAt":"2026-07-18T12:00:00Z"},"pagination":{"page":0,"perPage":20,"hasMore":false}}',
            stderr: '',
          ),
          const ProcessOutput(
            exitCode: 0,
            stdout: '{"schemaVersion":7,"entries":[]}',
            stderr: '',
          ),
        ]);
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/usr/local/bin/skillsgo',
        hubBaseUrl: 'https://hub.example.test',
      );

      final page = await gateway.discover(
        DiscoveryCollection.search,
        query: 'https://github.com/acme/skills',
      );

      expect(page.skills, hasLength(1));
      expect(page.skills.single.packagePath, 'github.com/acme/skills');
      expect(
        page.skills.single.imageUrl,
        'https://github.com/acme.png?size=72',
      );
      expect(page.skills.single.metricKind, isNull);
      expect(page.module?.id, 'github.com/acme/skills');
      expect(page.module?.description, 'Skills for product teams.');
      expect(page.module?.stars, 7);
      expect(page.module?.latestVersion, 'v1.2.3');
      expect(page.module?.updatedAt, DateTime.utc(2026, 7, 18, 12));
      expect(runner.calls.first.arguments, [
        'find',
        'https://github.com/acme/skills',
        '--hub',
        'https://hub.example.test',
        '--lang',
        'en',
        '--page',
        '0',
        '--per-page',
        '20',
        '--output',
        'json',
      ]);
    },
  );

  test('GitHub aliases are passed unchanged to CLI find', () async {
    const repositoryInfo =
        '{"skills":[{"packagePath":"github.com/owner/repo","path":"skills/demo","latestVersion":"v0.0.0-20260720120000-abcdef123456","name":"demo","description":"Demo Skill"}],"package":{"packagePath":"github.com/owner/repo","description":"","stars":0,"latestVersion":"v0.0.0-20260720120000-abcdef123456","updatedAt":"2026-07-20T12:00:00Z"},"pagination":{"page":0,"perPage":20,"hasMore":false}}';
    for (final source in const [
      'owner/repo@main',
      'github/owner/repo@main',
      'github.com/owner/repo@main',
      'https://github.com/owner/repo@main',
    ]) {
      final runner = FakeProcessRunner()
        ..responses.addAll(const [
          ProcessOutput(exitCode: 0, stdout: repositoryInfo, stderr: ''),
          ProcessOutput(
            exitCode: 0,
            stdout: '{"schemaVersion":7,"entries":[]}',
            stderr: '',
          ),
        ]);
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/usr/local/bin/skillsgo',
        hubBaseUrl: 'https://hub.example.test',
      );

      final page = await gateway.discover(
        DiscoveryCollection.search,
        query: source,
      );

      expect(page.module?.id, 'github.com/owner/repo', reason: source);
      expect(page.skills.single.packagePath, 'github.com/owner/repo');
      expect(runner.calls.first.arguments, [
        'find',
        source,
        '--hub',
        'https://hub.example.test',
        '--lang',
        'en',
        '--page',
        '0',
        '--per-page',
        '20',
        '--output',
        'json',
      ]);
      expect(
        runner.calls.any((call) => call.arguments.contains('discover')),
        isFalse,
        reason: source,
      );
    }
  });

  test('listInstalled parses unified inventory for explicit locations', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            r'{"schemaVersion":7,"entries":[{"inventoryKey":"hub:github.com/a/b:testing","name":"testing","packagePath":"github.com/a/b","provenance":"hub","health":"missing","agents":["codex","claude-code"],"projects":["/work/project;$(touch nope)"],"versions":["v1.0.0","v2.0.0"],"versionDivergence":true,"visibility":[{"agent":"codex","scope":"global","paths":["/tmp/testing","/tmp/shared/testing"],"verification":"verified"},{"agent":"opencode","scope":"project","projectRoot":"/work/project;$(touch nope)","paths":["/work/project;$(touch nope)/.agents/skills/testing"],"verification":"unverified"}],"targets":[{"scope":"global","projectRoot":"","agent":"codex","path":"/tmp/testing","version":"v1.0.0","health":"local-modification"},{"scope":"project","projectRoot":"/work/project;$(touch nope)","agent":"claude-code","path":"/work/project;$(touch nope)/.claude/skills/testing","version":"v2.0.0","health":"missing"}]}]}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
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
    expect(skills.single.inventoryKey, 'hub:github.com/a/b:testing');
    expect(skills.single.packagePath, 'github.com/a/b');
    expect(skills.single.isLinkedToCodex, isTrue);
    expect(skills.single.targetCount, 2);
    expect(skills.single.versionDivergence, isTrue);
    expect(skills.single.versions, ['v1.0.0', 'v2.0.0']);
    expect(skills.single.projects, [r'/work/project;$(touch nope)']);
    expect(skills.single.visibility, hasLength(2));
    expect(skills.single.visibility.first.agent, 'codex');
    expect(skills.single.visibility.first.scope, InstallationScope.global);
    expect(skills.single.visibility.first.paths, [
      '/tmp/testing',
      '/tmp/shared/testing',
    ]);
    expect(
      skills.single.visibility.first.verification,
      DiscoveryVerification.verified,
    );
    expect(skills.single.visibility.last.agent, 'opencode');
    expect(
      skills.single.visibility.last.verification,
      DiscoveryVerification.unverified,
    );
    expect(
      skills.single.targets.first.health,
      InstallationHealth.localModification,
    );
    expect(skills.single.targets.last.health, InstallationHealth.missing);
    expect(runner.lastArguments, [
      'list',
      '--global',
      '--project',
      r'/work/project;$(touch nope)',
      '--output',
      'json',
    ]);
  });

  test('listInstalled rejects an unknown installation scope', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":7,"entries":[{"inventoryKey":"hub:github.com/a/b:testing","name":"testing","packagePath":"github.com/a/b","provenance":"hub","health":"healthy","agents":["codex"],"projects":[],"versions":["v1.0.0"],"versionDivergence":false,"visibility":[],"targets":[{"scope":"workspace","agent":"codex","path":"/tmp/testing","version":"v1.0.0","health":"healthy"}]}]}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(
      gateway.listInstalled(),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.invalidLocalData,
        ),
      ),
    );
  });

  test('listInstalled rejects the obsolete inventory schema', () async {
    final gateway = RealSkillsGateway(
      processRunner: FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout: '{"schemaVersion":4,"entries":[]}',
          stderr: '',
        ),
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(gateway.listInstalled(), throwsA(isA<SkillsException>()));
  });

  test('listInstalled keeps same-name External Installations distinct', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":7,"entries":[{"inventoryKey":"external:abc","name":"testing","provenance":"external","health":"healthy","agents":["codex"],"projects":[],"versions":[],"versionDivergence":false,"visibility":[],"targets":[{"scope":"global","agent":"codex","path":"/tmp/external/testing","version":"","health":"healthy"}]},{"inventoryKey":"hub:github.com/a/b:testing","name":"testing","packagePath":"github.com/a/b","provenance":"hub","health":"healthy","agents":["codex"],"projects":[],"versions":["v1"],"versionDivergence":false,"visibility":[],"targets":[{"scope":"global","agent":"codex","path":"/tmp/managed/testing","version":"v1","health":"healthy"}]}]}',
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
    expect(external.inventoryKey, 'external:abc');
    expect(external.packagePath, isEmpty);
    expect(external.versions, isEmpty);
    expect(external.targets.single.version, isEmpty);
  });

  test(
    'inspectAgents parses complete versioned JSON and preserves a hostile CLI path',
    () async {
      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              r'{"schemaVersion":2,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["project","global"],"globalTarget":{"path":"/Users/test/.codex/skills;$(touch nope)","exists":true}},{"id":"eve","displayName":"Eve","installed":false,"supportedScopes":["project"],"globalTarget":null}]}',
          stderr: '',
        );
      const executable = r'/tmp/skillsgo bin;$(touch should-not-run)';
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: executable,
      );

      final report = await gateway.inspectAgents();

      expect(report.schemaVersion, 2);
      expect(report.agents, hasLength(2));
      expect(report.installed.single.id, 'codex');
      expect(report.agents.first.displayName, 'Codex');
      expect(report.agents.first.supportedScopes, [
        InstallationScope.project,
        InstallationScope.global,
      ]);
      expect(
        report.agents.first.globalTarget?.path,
        r'/Users/test/.codex/skills;$(touch nope)',
      );
      expect(runner.calls.single.executable, executable);
      expect(runner.calls.single.arguments, ['agents', '--output', 'json']);
    },
  );

  test('inspectAgents rejects malformed machine schemas', () async {
    for (final body in [
      '{"schemaVersion":1,"agents":[]}',
      '{"schemaVersion":2,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["machine"],"globalTarget":null}]}',
      '{"schemaVersion":2,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["global"],"globalTarget":null}]}',
      '{"schemaVersion":2,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["project"],"globalTarget":{"path":"/tmp","exists":true}}]}',
      '{"schemaVersion":2,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["project"],"globalTarget":null},{"id":"codex","displayName":"Duplicate","installed":false,"supportedScopes":["project"],"globalTarget":null}]}',
    ]) {
      final gateway = RealSkillsGateway(
        processRunner: FakeProcessRunner()
          ..result = ProcessOutput(exitCode: 0, stdout: body, stderr: ''),
        initialCliPath: '/usr/local/bin/skillsgo',
      );

      await expectLater(
        gateway.inspectAgents(),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            SkillsFailureKind.invalidLocalData,
          ),
        ),
      );
    }
  });
}
