/*
 * [INPUT]: Uses controlled CLI arguments and responses, temporary local Skill trees, file pickers, and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies hostile-argument safety, direct installation, local detail, External inspection, and exact Batch Takeover planning plus named scope-bound execution results.
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
      repositoryId: r'github.com/a/b',
      installName: r"test name';$(touch nope)",
      name: r'test;$(touch nope)',
      source: r'github.com/a/b',
      installs: 0,
    );
    const installed = InstalledSkill(
      inventoryKey: r'hub:github.com/a/b:Test ; $(touch nope)',
      name: r'Test ; $(touch nope)',
      path: r'/tmp/Test ; $(touch nope)',
      agents: ['codex'],
      targetCount: 1,
      repositoryId: r'github.com/a/b',
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.user,
          path: r'/tmp/Test ; $(touch nope)',
          version: 'v1',
        ),
      ],
    );

    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout:
          r'{"schemaVersion":1,"phase":"repository-install","repository":"github.com/a/b","version":"v1","sum":"h1:test","skills":["test;$(touch nope)"],"agents":["codex"],"vendor":"/tmp/vendor","projections":[{"agents":["codex"],"path":"/tmp/projection"}],"workspace":{"manifest":"/tmp/skillsgo.yaml","lock":"/tmp/skillsgo-lock.yaml"}}',
      stderr: '',
    );
    await gateway.installTargets(summary, 'v1', const [
      InstallationTargetSelection(
        agent: 'codex',
        scope: InstallationScope.user,
      ),
    ]);
    expect(
      runner.lastExecutable,
      r'/Applications/Skills Play/$(echo nope)/skillsgo',
    );
    expect(runner.lastArguments, [
      'add',
      r'github.com/a/b@v1',
      '--skill',
      r'test;$(touch nope)',
      '--agent',
      'codex',
      '--global',
      '--yes',
      '--output',
      'json',
      '--hub',
      'https://hub.skillsgo.ai',
    ]);
    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout:
          '{"schemaVersion":1,"phase":"repository-update-preflight","repository":"github.com/a/b","fromVersion":"v1","toVersion":"v2","sum":"h1:test","skills":["Test"],"agents":["codex"],"scope":"user","vendor":"/tmp/vendor","stateToken":"state"}\n',
      stderr: '',
    );
    await gateway.preflightUpdate(
      installed,
      installed.targets,
      toVersion: 'v2',
    );
    expect(runner.lastArguments!.take(3), [
      'update',
      'github.com/a/b@v2',
      '--global',
    ]);
    expect(runner.lastArguments, isNot(contains('--target')));
    expect(runner.lastArguments, isNot(contains('mode')));
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
{"schemaVersion":1,"phase":"management-preflight","targets":[{"target":{"scope":"user","agent":"codex","path":"/tmp/Test ; $(touch nope)"},"name":"Test ; $(touch nope)","skillId":"github.com/a/b/-/Test ; $(touch nope)","version":"","health":"healthy","allowedActions":["remove"],"stateToken":"sha256:state","workspaceMetadataChange":false}],"summary":{"removable":1}}
''',
      stderr: '',
    );
    const external = InstalledSkill(
      inventoryKey: r'external:/tmp/Test ; $(touch nope)',
      name: r'Test ; $(touch nope)',
      path: r'/tmp/Test ; $(touch nope)',
      agents: ['codex'],
      targetCount: 1,
      provenance: LibraryProvenance.external,
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.user,
          path: r'/tmp/Test ; $(touch nope)',
          version: '',
        ),
      ],
    );
    await gateway.preflightTargetManagement(external, external.targets);
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
    'target installation invokes exact Repository Vendor add without a materialization mode',
    () async {
      const repositoryId = 'github.com/example/skills';
      final runner = FakeProcessRunner()
        ..result = ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'phase': 'repository-install',
            'repository': 'github.com/example/skills',
            'version': 'v1',
            'sum': 'h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            'skills': ['demo'],
            'agents': ['codex'],
            'vendor': '/Users/test/.skillsgo/vendor/example/v1',
            'projections': [
              {
                'agents': ['codex'],
                'path': '/Users/test/.codex/skills/example/v1',
              },
            ],
            'workspace': {
              'manifest': '/Users/test/.skillsgo/skillsgo.yaml',
              'lock': '/Users/test/.skillsgo/skillsgo-lock.yaml',
            },
          }),
          stderr: '',
        );
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/Applications/SkillsGo.app/skillsgo',
      );
      const skill = SkillSummary(
        repositoryId: repositoryId,
        installName: 'demo',
        name: 'demo',
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
      expect(
        runner.lastArguments,
        containsAllInOrder([
          'add',
          'github.com/example/skills@v1',
          '--skill',
          'demo',
        ]),
      );
      expect(runner.lastArguments, contains('--global'));
      expect(runner.lastArguments, isNot(contains('--target')));
      expect(runner.lastArguments, isNot(contains('--version')));
      expect(runner.lastArguments, isNot(contains('--copy')));
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
            '{"schemaVersion":3,"planId":"plan-123","summary":{"eligible":4,"skipped":1},"scopes":{"user":{"eligible":1},"projects":[{"projectRoot":"/tmp/Workspace With Spaces","eligible":2},{"projectRoot":"/tmp/Second Workspace","eligible":1}]},"previews":[{"name":"demo","skillId":"github.com/acme/skills/-/demo","scope":"user"}]}',
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
    expect(result.previews.single.skillId, 'github.com/acme/skills/-/demo');
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
      '--hub',
      'https://must-not-be-used.example',
      '--output',
      'json',
    ]);
  });

  test('Batch Takeover executes one Plan for an explicit scope', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":3,"summary":{"takenOver":2,"skipped":1},"results":[{"name":"demo","skillId":"github.com/acme/skills/-/demo","version":"v1.2.3","status":"taken-over","target":{"agent":"codex","scope":"user","path":"/tmp/demo"}},{"name":"project-demo","skillId":"github.com/acme/skills/-/project-demo","version":"v1.2.3","status":"taken-over","target":{"agent":"claude-code","scope":"project","projectRoot":"/tmp/Workspace With Spaces","path":"/tmp/Workspace With Spaces/.claude/skills/demo"}},{"name":"missing-demo","status":"skipped","reason":"missing-target","target":{"scope":"project","projectRoot":"/tmp/Workspace With Spaces","path":""}}]}',
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
    expect(result.items.map((item) => (item.name, item.status)), [
      ('demo', BatchTakeoverItemStatus.takenOver),
      ('project-demo', BatchTakeoverItemStatus.takenOver),
      ('missing-demo', BatchTakeoverItemStatus.skipped),
    ]);
    expect(runner.lastArguments, [
      'takeover',
      '--plan',
      'plan-123',
      '--user',
      '--project',
      '/tmp/Workspace With Spaces',
      '--project',
      '/tmp/Second Workspace',
      '--hub',
      'https://must-not-be-used.example',
      '--yes',
      '--output',
      'json',
    ]);
  });
}
