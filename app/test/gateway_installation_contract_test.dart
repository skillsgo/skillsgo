/*
 * [INPUT]: Uses controlled CLI arguments and responses, temporary local Skill trees, file pickers, and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies hostile-argument safety, direct installation, local detail, External inspection, exact Batch Takeover planning and scope-bound execution, and Local export contracts.
 * [POS]: Serves as the Installation Request and local Skill contract suite at the SkillsGateway seam.
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

  test('hostile write inputs remain exact arguments without a shell', () async {
    final runner = FakeProcessRunner();
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: r'/Applications/Skills Play/$(echo nope)/skillsgo',
    );
    const summary = SkillSummary(
      id: r'github.com/a/b/-/test;$(touch nope)',
      installName: r"test name';$(touch nope)",
      name: 'Test',
      source: r'github.com/a/b/-/test;$(touch nope)',
      installs: 0,
    );
    const installed = InstalledSkill(
      inventoryKey: r'hub:github.com/a/b/-/Test ; $(touch nope)',
      name: r'Test ; $(touch nope)',
      path: r'/tmp/Test ; $(touch nope)',
      agents: ['codex'],
      targetCount: 1,
      skillId: r'github.com/a/b/-/Test ; $(touch nope)',
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
{"schemaVersion":1,"phase":"update-preflight","targets":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test ; $(touch nope)"},"name":"Test ; $(touch nope)","skillId":"github.com/a/b/-/Test ; $(touch nope)","sourceRef":"main","fromVersion":"v1","toVersion":"v2","action":"update","stateToken":"sha256:state","workspaceManifestChange":false}],"workspaceManifestChanges":[],"summary":{"update":1,"current":0,"pinned":0,"failed":0}}
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
      'skillId': r'github.com/a/b/-/Test ; $(touch nope)',
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
{"schemaVersion":1,"phase":"management-preflight","targets":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test ; $(touch nope)"},"name":"Test ; $(touch nope)","skillId":"github.com/a/b/-/Test ; $(touch nope)","version":"v1","health":"healthy","allowedActions":["remove"],"stateToken":"sha256:state","workspaceMetadataChange":false}],"summary":{"removable":1,"repairable":0}}
''',
      stderr: '',
    );
    await gateway.preflightTargetManagement(installed, installed.targets);
    expect(runner.lastArguments!.first, 'remove');
    expect(
      runner.lastArguments,
      containsAllInOrder([
        '--path',
        r'/tmp/Test ; $(touch nope)',
        '--agent',
        'codex',
      ]),
    );
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
    'confirmed target installation invokes add --yes without preflight',
    () async {
      const skillId = 'github.com/example/skills/-/demo';
      const target = {
        'scope': 'user',
        'agent': 'codex',
        'mode': 'symlink',
        'path': '/Users/test/.codex/skills/demo',
        'canonicalPath': '/Users/test/.agents/skills/demo',
      };
      final runner = FakeProcessRunner()
        ..result = ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 3,
            'phase': 'execution',
            'artifact': {
              'source': skillId,
              'skillId': skillId,
              'version': 'v1',
              'name': 'demo',
              'risk': 'low',
            },
            'results': [
              {'target': target, 'action': 'replace', 'outcome': 'succeeded'},
            ],
            'summary': {
              'succeeded': 1,
              'skipped': 0,
              'conflict': 0,
              'failed': 0,
            },
          }),
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/Applications/SkillsGo.app/skillsgo',
      );
      const skill = SkillSummary(
        id: skillId,
        installName: 'demo',
        name: 'Demo',
        source: 'github.com/example/skills',
        installs: 0,
        latestVersion: 'v1',
      );

      final execution = await gateway.installTargets(skill, 'v1', const [
        InstallationTargetSelection(
          scope: InstallationScope.user,
          agent: 'codex',
        ),
      ], confirmRisk: true);

      expect(execution.summary.succeeded, 1);
      expect(runner.lastArguments, contains('--yes'));
      expect(runner.lastArguments, isNot(contains('--preflight')));
      expect(runner.lastArguments, containsAllInOrder(['--output', 'json']));
      expect(runner.lastArguments, contains('--confirm-risk'));

      runner.result = ProcessOutput(
        exitCode: 1,
        stdout: jsonEncode({
          'schemaVersion': 3,
          'phase': 'execution',
          'artifact': {
            'source': skillId,
            'skillId': skillId,
            'version': 'v1',
            'name': 'demo',
            'risk': 'low',
          },
          'results': [
            {
              'target': target,
              'action': 'replace',
              'outcome': 'failed',
              'error': {
                'code': 'workspace.persistence_failed',
                'retryable': true,
                'details': {'path': '/work/project/skillsgo.mod'},
                'requestId': 'req-install',
                'diagnostic': 'permission denied',
              },
            },
          ],
          'summary': {'succeeded': 0, 'skipped': 0, 'conflict': 0, 'failed': 1},
        }),
        stderr: '安装失败',
      );
      final failed = await gateway.installTargets(skill, 'v1', const [
        InstallationTargetSelection(
          scope: InstallationScope.user,
          agent: 'codex',
        ),
      ], confirmRisk: true);
      expect(failed.results.single.error?.code, 'workspace.persistence_failed');
      expect(failed.results.single.error?.retryable, isTrue);
      expect(failed.results.single.error?.requestId, 'req-install');
      expect(
        failed.results.single.error?.details['path'],
        '/work/project/skillsgo.mod',
      );
    },
  );

  test('local detail reads canonical SKILL.md without writing files', () async {
    final directory = await Directory.systemTemp.createTemp('skillsgo-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/SKILL.md');
    await file.writeAsString('# Local');
    final before = await file.lastModified();
    final gateway = RealSkillsGateway(processRunner: FakeProcessRunner());

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
      final gateway = RealSkillsGateway(processRunner: FakeProcessRunner());

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
      final runner = FakeProcessRunner();
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
      );
      final external = InstalledSkill(
        inventoryKey: 'external:abc',
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
      expect(runner.calls, isEmpty);
      for (final file in [skillFile, script, notes, large]) {
        expect(await file.readAsBytes(), before[file.path]);
      }
    },
  );

  test('Batch Takeover Plan parses exact User and Workspace counts', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":2,"planId":"plan-123","summary":{"eligible":4,"skipped":1},"scopes":{"user":{"eligible":1},"projects":[{"projectRoot":"/tmp/Workspace With Spaces","eligible":2},{"projectRoot":"/tmp/Second Workspace","eligible":1}]}}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
      hubBaseUrl: 'https://must-not-be-used.example',
    );

    final result = await gateway.planBatchTakeover(
      projectRoots: const [
        '/tmp//Workspace With Spaces',
        '/tmp/Second Workspace',
      ],
    );

    expect(result.id, 'plan-123');
    expect(result.allEligibleCount, 4);
    expect(result.userEligibleCount, 1);
    expect(result.eligibleForProject('/tmp/Workspace With Spaces'), 2);
    expect(result.eligibleForProject('/tmp/Second Workspace'), 1);
    expect(runner.lastArguments, [
      'takeover',
      '--preflight',
      '--user',
      '--project',
      '/tmp/Workspace With Spaces',
      '--project',
      '/tmp/Second Workspace',
      '--output',
      'json',
    ]);
    expect(runner.lastArguments, isNot(contains('--hub')));
  });

  test('Batch Takeover executes one Plan for an explicit scope', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":2,"summary":{"takenOver":2,"skipped":1},"results":[{"skillId":"github.com/acme/skills/-/demo","artifactSkillId":"captured.skillsgo/source/content/demo","version":"captured-content","status":"taken-over","target":{"agent":"codex","scope":"user","mode":"copy","path":"/tmp/demo"}},{"skillId":"github.com/acme/skills/-/project-demo","artifactSkillId":"captured.skillsgo/source/project/project-demo","version":"captured-project","status":"taken-over","target":{"agent":"claude-code","scope":"project","projectRoot":"/tmp/Workspace With Spaces","mode":"copy","path":"/tmp/Workspace With Spaces/.claude/skills/demo"}},{"status":"skipped","reason":"missing-target","target":{"scope":"project","projectRoot":"/tmp/Workspace With Spaces","mode":"copy","path":""}}]}',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
      hubBaseUrl: 'https://must-not-be-used.example',
    );

    final result = await gateway.executeBatchTakeover(
      const BatchTakeoverPlan(
        id: 'plan-123',
        allEligibleCount: 4,
        userEligibleCount: 1,
        eligibleCountByProjectRoot: {
          '/tmp/Workspace With Spaces': 2,
          '/tmp/Second Workspace': 1,
        },
      ),
      BatchTakeoverScope.all,
    );

    expect(result.takenOver, 2);
    expect(result.skipped, 1);
    expect(runner.lastArguments, [
      'takeover',
      '--plan',
      'plan-123',
      '--user',
      '--project',
      '/tmp/Workspace With Spaces',
      '--project',
      '/tmp/Second Workspace',
      '--yes',
      '--output',
      'json',
    ]);
    expect(runner.lastArguments, isNot(contains('--hub')));
  });

  test(
    'Local export honors cancellation and exact destination arguments',
    () async {
      const local = InstalledSkill(
        inventoryKey: 'local:abc',
        name: 'Private Demo',
        path: '/tmp/private',
        agents: ['codex'],
        targetCount: 1,
        skillId: 'local.skillsgo/abc/Private-Demo',
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
      final cancelledRunner = FakeProcessRunner();
      final cancelled = RealSkillsGateway(
        processRunner: cancelledRunner,
        initialCliPath: '/bin/skillsgo',
        savePathPicker: (_) async => null,
      );
      expect(await cancelled.exportLocalSkill(local), isNull);
      expect(cancelledRunner.calls, isEmpty);

      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"local-export","skillId":"local.skillsgo/abc/Private-Demo","version":"local-abc","destination":"/tmp/export destination.zip"}',
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
        '--skill-id',
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
}
