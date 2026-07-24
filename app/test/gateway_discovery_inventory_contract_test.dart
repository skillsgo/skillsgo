/*
 * [INPUT]: Uses controlled CLI Hub/Skill reads, an HTTP Cloud-composed ranking server, inventory responses, the production SkillsGateway adapter, and equivalent GitHub source aliases.
 * [OUTPUT]: Specifies public single/batch Find and Cloud-composed collection discovery including the four-row empty-input matrix, direct explicit-source routing, unified inventory, Agent catalog, visibility, and schema validation contracts.
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
              '{"collection":"find","skills":[{"repositoryId":"github.com/flutter/skills","source":"github.com/flutter/skills","imageUrl":"https://images.example/flutter.png","skillPath":"responsive-layout","name":"responsive-layout","description":"Build adaptive Flutter layouts.","latestVersion":"v1.2.3","trustLevel":"community_verified","riskAssessment":"low"}],"page":{"limit":20,"offset":0,"nextOffset":20}}',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":6,"entries":[{"inventoryKey":"hub:github.com/flutter/skills:responsive-layout","name":"responsive-layout","repositoryId":"github.com/flutter/skills","provenance":"hub","risk":"unknown","health":"healthy","agents":["codex"],"projects":["/tmp/project"],"versions":["v1.2.3"],"versionDivergence":false,"visibility":[],"targets":[{"scope":"user","agent":"codex","path":"/tmp/one","version":"v1.2.3","health":"healthy"},{"scope":"project","projectRoot":"/tmp/project","agent":"codex","path":"/tmp/project/.agents/skills/two","version":"v1.2.3","health":"healthy"}]}]}',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":6,"entries":[{"inventoryKey":"hub:github.com/flutter/skills:responsive-layout","name":"responsive-layout","repositoryId":"github.com/flutter/skills","provenance":"hub","risk":"unknown","health":"healthy","agents":["codex"],"projects":["/tmp/project"],"versions":["v1.2.3"],"versionDivergence":false,"visibility":[],"targets":[{"scope":"user","agent":"codex","path":"/tmp/one","version":"v1.2.3","health":"healthy"},{"scope":"project","projectRoot":"/tmp/project","agent":"codex","path":"/tmp/project/.agents/skills/two","version":"v1.2.3","health":"healthy"}]}]}',
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
    expect(results.single.source, 'github.com/flutter/skills');
    expect(results.single.imageUrl, 'https://images.example/flutter.png');
    expect(results.single.installName, 'responsive-layout');
    expect(results.single.skillPath, 'responsive-layout');
    expect(results.single.metricKind, isNull);
    expect(results.single.description, 'Build adaptive Flutter layouts.');
    expect(results.single.trustLevel, SkillTrustLevel.communityVerified);
    expect(results.single.riskAssessment, SkillRiskAssessment.low);
    expect(results.single.localTargetCount, 2);
    expect(page.nextOffset, 20);
    expect(runner.calls.first.arguments, [
      'find',
      'responsive',
      '--hub',
      'https://hub.skillsgo.ai',
      '--content-locale',
      'en',
      '--offset',
      '0',
      '--limit',
      '20',
    ]);

    final installed = await gateway.listInstalled();
    expect(installed.single.agents, ['codex']);
    expect(installed.single.targetCount, 2);
  });

  test(
    'batch Find uses one CLI process with stdin and no inventory read',
    () async {
      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"collection":"find","results":[{"id":"external:1","q":"ask-matt","skills":[{"repositoryId":"github.com/example/skills","source":"github.com/example/skills","repository":"github.com/example/skills","imageUrl":null,"skillPath":"skills/ask-matt","name":"ask-matt","description":"Route requests.","latestVersion":"v1.2.3","trustLevel":"unverified","riskAssessment":"unknown"}]}]}',
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/usr/local/bin/skillsgo',
      );

      final results = await gateway.findSources(const [
        SourceFindQuery(id: 'external:1', name: 'ask-matt'),
      ]);

      expect(runner.calls, hasLength(1));
      expect(runner.lastArguments, [
        'find',
        '--input',
        '-',
        '--hub',
        'https://hub.skillsgo.ai',
        '--content-locale',
        'en',
      ]);
      expect(jsonDecode(runner.lastStdin!)['queries'], [
        {'id': 'external:1', 'q': 'ask-matt', 'exactName': true},
      ]);
      expect(results.single.skills.single.latestVersion, 'v1.2.3');
    },
  );

  test('Cloud ranking returns authoritative composed Skill cards', () async {
    final cloud = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cloud.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"collection":"hot","items":[{"repositoryId":"github.com/acme/skills","skillName":"demo","name":"demo","description":"Demo Skill","source":"github.com/acme/skills","repository":"github.com/acme/skills","imageUrl":null,"skillPath":"demo","latestVersion":"v1.0.0","trustLevel":"unverified","riskAssessment":"unknown","metric":{"kind":"hot_velocity","value":8,"change":5}}],"page":{"limit":20,"offset":0,"nextOffset":null}}',
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
          stdout: '{"schemaVersion":6,"entries":[]}',
          stderr: '',
        ),
      ]);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
      hubBaseUrl: 'https://hub.example.test',
    );

    final page = await gateway.discover(DiscoveryCollection.hot);

    expect(page.skills.single.repositoryId, 'github.com/acme/skills');
    expect(page.skills.single.installs, 8);
    expect(page.skills.single.metricChange, 5);
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
                'collection': tc.wireCollection,
                'items': <Object>[],
                'page': {'limit': 20, 'offset': 0, 'nextOffset': null},
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
        ]);
        expect(requestedCloudPaths, [
          '/api/v1/rankings/${tc.wireCollection}?offset=0&limit=20',
        ]);
        await cloud?.close(force: true);
      }
    },
  );

  test('explicit Git source discovery goes through CLI info', () async {
    final runner = FakeProcessRunner()
      ..responses.addAll([
        const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"SchemaVersion":1,"Kind":"Repository","ID":"github.com/acme/skills","Version":"v1.2.3","Time":"2026-07-18T12:00:00Z","Description":"Skills for product teams.","License":"MIT","Ref":"refs/tags/v1.2.3","CommitSHA":"commit","Skills":[{"SchemaVersion":1,"Kind":"Skill","RepositoryID":"github.com/acme/skills","SkillPath":"skills/demo","Version":"v1.2.3","Name":"demo","Description":"Demo Skill","ImageURL":"https://github.com/acme.png?size=72","Stars":7,"TrustLevel":"community_verified","RiskAssessment":"low","Ref":"refs/tags/v1.2.3","CommitSHA":"commit","TreeSHA":"tree"}]}',
          stderr: '',
        ),
        const ProcessOutput(
          exitCode: 0,
          stdout: '{"schemaVersion":6,"entries":[]}',
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
    expect(page.skills.single.repositoryId, 'github.com/acme/skills');
    expect(page.skills.single.imageUrl, 'https://github.com/acme.png?size=72');
    expect(page.skills.single.metricKind, isNull);
    expect(page.skills.single.trustLevel, SkillTrustLevel.communityVerified);
    expect(page.skills.single.riskAssessment, SkillRiskAssessment.low);
    expect(page.repository?.id, 'github.com/acme/skills');
    expect(page.repository?.description, 'Skills for product teams.');
    expect(page.repository?.stars, 7);
    expect(page.repository?.latestVersion, 'v1.2.3');
    expect(page.repository?.license, 'MIT');
    expect(page.repository?.updatedAt, DateTime.utc(2026, 7, 18, 12));
    expect(runner.calls.first.arguments, [
      'info',
      'https://github.com/acme/skills',
      '--hub',
      'https://hub.example.test',
      '--output',
      'json',
    ]);
  });

  test('GitHub aliases all bypass keyword search and use CLI info', () async {
    const repositoryInfo =
        '{"SchemaVersion":1,"Kind":"Repository","ID":"github.com/owner/repo","Version":"v0.0.0-20260720120000-abcdef123456","Time":"2026-07-20T12:00:00Z","Ref":"refs/heads/main","CommitSHA":"abcdef1234567890","Skills":[{"SchemaVersion":1,"Kind":"Skill","RepositoryID":"github.com/owner/repo","SkillPath":"skills/demo","Version":"v0.0.0-20260720120000-abcdef123456","Name":"demo","Description":"Demo Skill","Stars":0,"TrustLevel":"unverified","RiskAssessment":"unknown","Ref":"refs/heads/main","CommitSHA":"abcdef1234567890","TreeSHA":"tree"}]}';
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
            stdout: '{"schemaVersion":6,"entries":[]}',
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

      expect(page.repository?.id, 'github.com/owner/repo', reason: source);
      expect(page.skills.single.repositoryId, 'github.com/owner/repo');
      expect(runner.calls.first.arguments, [
        'info',
        source,
        '--hub',
        'https://hub.example.test',
        '--output',
        'json',
      ]);
      expect(
        runner.calls.any((call) => call.arguments.contains('discover')),
        isFalse,
        reason: source,
      );
      expect(
        runner.calls.any((call) => call.arguments.contains('find')),
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
            r'{"schemaVersion":6,"entries":[{"inventoryKey":"hub:github.com/a/b:testing","name":"testing","repositoryId":"github.com/a/b","provenance":"hub","risk":"unknown","health":"missing","agents":["codex","claude-code"],"projects":["/work/project;$(touch nope)"],"versions":["v1.0.0","v2.0.0"],"versionDivergence":true,"visibility":[{"agent":"codex","scope":"user","paths":["/tmp/testing","/tmp/shared/testing"],"verification":"verified"},{"agent":"opencode","scope":"project","projectRoot":"/work/project;$(touch nope)","paths":["/work/project;$(touch nope)/.agents/skills/testing"],"verification":"unverified"}],"targets":[{"scope":"user","projectRoot":"","agent":"codex","path":"/tmp/testing","version":"v1.0.0","health":"local-modification"},{"scope":"project","projectRoot":"/work/project;$(touch nope)","agent":"claude-code","path":"/work/project;$(touch nope)/.claude/skills/testing","version":"v2.0.0","health":"missing"}]}]}',
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
    expect(skills.single.repositoryId, 'github.com/a/b');
    expect(skills.single.isLinkedToCodex, isTrue);
    expect(skills.single.targetCount, 2);
    expect(skills.single.versionDivergence, isTrue);
    expect(skills.single.versions, ['v1.0.0', 'v2.0.0']);
    expect(skills.single.projects, [r'/work/project;$(touch nope)']);
    expect(skills.single.visibility, hasLength(2));
    expect(skills.single.visibility.first.agent, 'codex');
    expect(skills.single.visibility.first.scope, InstallationScope.user);
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
      'inventory',
      '--user',
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
            '{"schemaVersion":6,"entries":[{"inventoryKey":"hub:github.com/a/b:testing","name":"testing","repositoryId":"github.com/a/b","provenance":"hub","risk":"unknown","health":"healthy","agents":["codex"],"projects":[],"versions":["v1.0.0"],"versionDivergence":false,"visibility":[],"targets":[{"scope":"workspace","agent":"codex","path":"/tmp/testing","version":"v1.0.0","health":"healthy"}]}]}',
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
            '{"schemaVersion":6,"entries":[{"inventoryKey":"external:abc","name":"testing","provenance":"external","risk":"unknown","health":"healthy","agents":["codex"],"projects":[],"versions":[],"versionDivergence":false,"visibility":[],"targets":[{"scope":"user","agent":"codex","path":"/tmp/external/testing","version":"","health":"healthy"}]},{"inventoryKey":"hub:github.com/a/b:testing","name":"testing","repositoryId":"github.com/a/b","provenance":"hub","risk":"low","health":"healthy","agents":["codex"],"projects":[],"versions":["v1"],"versionDivergence":false,"visibility":[],"targets":[{"scope":"user","agent":"codex","path":"/tmp/managed/testing","version":"v1","health":"healthy"}]}]}',
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
    expect(external.repositoryId, isEmpty);
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
              r'{"schemaVersion":1,"agents":[{"id":"codex","displayName":"Codex","installed":true,"supportedScopes":["project","user"],"userTarget":{"path":"/Users/test/.codex/skills;$(touch nope)","exists":true}},{"id":"eve","displayName":"Eve","installed":false,"supportedScopes":["project"],"userTarget":null}]}',
          stderr: '',
        );
      const executable = r'/tmp/skillsgo bin;$(touch should-not-run)';
      final gateway = RealSkillsGateway(
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
