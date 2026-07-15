/*
 * [INPUT]: Uses SkillsGateway with controlled HTTP, process, preferences, and temporary-filesystem boundaries.
 * [OUTPUT]: Specifies settings, discovery/detail parsing, strict Agent machine contracts, local targets, typed failures, storage health, argument safety, and CLI handshake behavior.
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
  test('registry settings persist and validate the search protocol', () async {
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
      registryBaseUrl: 'https://official.example',
      appVersion: '1.2.3',
    );

    expect(await gateway.loadRegistryOrigin(), 'https://official.example');
    final status = await gateway.testRegistryOrigin(
      'https://self-hosted.example/base',
    );
    expect(status.isReady, isTrue);
    expect(requests.single.path, '/base/v1/search');

    await gateway.saveRegistryOrigin('https://self-hosted.example/base/');
    expect(
      await gateway.loadRegistryOrigin(),
      'https://self-hosted.example/base',
    );
    await gateway.discover(DiscoveryCollection.search, query: 'flutter');
    expect(requests.last.host, 'self-hosted.example');
    expect(requests.last.path, '/base/v1/search');
    final restored = RealSkillsGateway(
      httpClient: client,
      registryBaseUrl: 'https://official.example',
      appVersion: '1.2.3',
    );
    expect(
      await restored.loadRegistryOrigin(),
      'https://self-hosted.example/base',
    );

    await restored.resetRegistryOrigin();
    expect(await restored.loadRegistryOrigin(), 'https://official.example');
  });

  test('registry settings reject unsafe or malformed origins', () async {
    SharedPreferences.setMockInitialValues({});
    final gateway = RealSkillsGateway(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      registryBaseUrl: 'https://official.example',
      appVersion: '1.2.3',
    );

    final status = await gateway.testRegistryOrigin(
      'https://user:password@example.com?secret=yes',
    );
    expect(status.state, HealthState.invalid);
    await expectLater(
      gateway.saveRegistryOrigin('file:///tmp/registry'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'registry settings turn transport failures into structured health',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = RealSkillsGateway(
        httpClient: MockClient(
          (request) async =>
              throw http.ClientException('TLS handshake failed', request.url),
        ),
        registryBaseUrl: 'https://official.example',
        appVersion: '1.2.3',
      );

      final status = await gateway.testRegistryOrigin(
        'https://self-hosted.example',
      );

      expect(status.state, HealthState.unreachable);
      expect(status.issue, RegistryIssue.connectionFailure);
    },
  );

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
      registryBaseUrl: 'https://official.example',
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
            'appProtocolVersion': 1,
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
          'appProtocolVersion': 2,
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
          'appProtocolVersion': 1,
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
          'appProtocolVersion': 1,
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
            'appProtocolVersion': 1,
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
            '[{"name":"Responsive Layout","coordinate":"github.com/flutter/skills/-/responsive-layout","version":"v1.2.3","target":{"path":"/tmp/one","scope":"user","agent":"codex","mode":"copy"}},{"name":"Responsive Layout","coordinate":"github.com/flutter/skills/-/responsive-layout","version":"v1.2.3","target":{"path":"/tmp/two","scope":"project","agent":"codex","mode":"copy"}}]',
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
    'ranked discovery routes use distinct Registry collection parameters',
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

  test('listInstalled parses the CLI global JSON contract', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '[{"name":"testing","coordinate":"github.com/a/b","version":"v1.0.0","target":{"path":"/tmp/testing","scope":"user","agent":"codex","mode":"copy"}}]',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    final skills = await gateway.listInstalled();

    expect(skills.single.name, 'testing');
    expect(skills.single.coordinate, 'github.com/a/b');
    expect(skills.single.isLinkedToCodex, isTrue);
    expect(skills.single.targetCount, 1);
    expect(runner.lastArguments, ['list', '--global', '--json']);
  });

  test('listInstalled rejects an unknown installation scope', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '[{"name":"testing","coordinate":"github.com/a/b","version":"v1.0.0","target":{"path":"/tmp/testing","scope":"workspace","agent":"codex","mode":"copy"}}]',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      processRunner: runner,
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(gateway.listInstalled(), throwsA(isA<SkillsException>()));
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
    'remote detail reads one auditable Registry contract and local targets',
    () async {
      final runner = _FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '[{"name":"Test","coordinate":"github.com/a/b/-/test","version":"v0.0.0-test","target":{"path":"/tmp/test","scope":"user","agent":"codex","mode":"copy"}}]',
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
      name: r'Test ; $(touch nope)',
      path: r'/tmp/Test ; $(touch nope)',
      agents: ['codex'],
      targetCount: 1,
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
      '--registry',
      'http://localhost:3000',
    ]);
    await gateway.update(installed);
    expect(runner.lastArguments, [
      'update',
      r'Test ; $(touch nope)',
      '--global',
      '--yes',
      '--registry',
      'http://localhost:3000',
    ]);
    await gateway.remove(installed);
    expect(runner.lastArguments, [
      'remove',
      r'Test ; $(touch nope)',
      '--global',
      '--yes',
    ]);
    expect(
      runner.calls.map((call) => call.executable),
      isNot(contains('/bin/sh')),
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

  test('update check delegates to SkillsGo JSON contract', () async {
    final runner = _FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout: '[{"name":"Test","available":true}]',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );

    final states = await gateway.checkUpdates(const [
      InstalledSkill(
        name: 'Test',
        path: '/tmp/Test',
        agents: ['codex'],
        targetCount: 1,
      ),
    ]);

    expect(states['Test'], UpdateState.available);
    expect(runner.lastArguments, [
      'update',
      'Test',
      '--global',
      '--check',
      '--output',
      'json',
      '--registry',
      'http://localhost:3000',
    ]);
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
  Future<ProcessOutput> run(String executable, List<String> arguments) async {
    lastExecutable = executable;
    lastArguments = arguments;
    calls.add((executable: executable, arguments: List.of(arguments)));
    if (responses.isNotEmpty) return responses.removeAt(0);
    return result;
  }
}
