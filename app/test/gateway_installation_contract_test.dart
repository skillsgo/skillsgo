/*
 * [INPUT]: Uses controlled CLI arguments and responses, temporary local Skill trees, file pickers, the App logger, and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies hostile-argument safety, direct selected-version installation, local detail, External inspection, reviewed adoption request/result contracts, and App-side protocol failure logging.
 * [POS]: Serves as the Installation Request and local Skill contract suite at the SkillsGateway seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/desktop_skills_gateway.dart';
import 'package:skillsgo/infrastructure/logging/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_process_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('installation logs an App protocol error when decoding fails', () async {
    final directory = await Directory.systemTemp.createTemp(
      'skillsgo-install-log-',
    );
    await appLogger.dispose();
    await appLogger.initialize(directory: directory);
    addTearDown(() async {
      await appLogger.dispose();
      await directory.delete(recursive: true);
    });
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout: '{"schemaVersion":1,"phase":"unexpected"}',
        stderr: '',
      );
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: '/Applications/SkillsGo.app/skillsgo',
    );

    await expectLater(
      gateway.installTargets(
        const SkillSummary(
          packagePath: 'github.com/example/skills',
          installName: 'demo',
          name: 'demo',
          path: 'skills/demo',
          latestVersion: 'v1',
        ),
        'v1',
        const [
          InstallationTargetSelection(
            scope: InstallationScope.global,
            agent: 'codex',
          ),
        ],
      ),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.invalidResponse,
        ),
      ),
    );
    await appLogger.flush();

    final event = appLogger.recent().singleWhere(
      (entry) => entry.event == 'response_decode_failed',
    );
    expect(event.level, DiagnosticLogLevel.error);
    expect(event.category, 'gateway.protocol');
    expect(event.data['operation'], 'install_package_members');
    expect(event.data['responsePreview'], contains('"phase": "unexpected"'));
    expect(event.error, contains('FormatException'));
    expect(event.stackTrace, isNotEmpty);
  });

  test('hostile write inputs remain exact arguments without a shell', () async {
    final runner = FakeProcessRunner();
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: r'/Applications/Skills Play/$(echo nope)/skillsgo',
    );
    const summary = SkillSummary(
      packagePath: r'github.com/a/b',
      installName: r"test name';$(touch nope)",
      name: r'test;$(touch nope)',
      path: r'nested/test;$(touch nope)',
      installs: 0,
    );
    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout:
          r'{"schemaVersion":1,"phase":"package-install","packagePath":"github.com/a/b","version":"v1","sum":"h1:test","skills":["nested/test;$(touch nope)"],"agents":["codex"],"packageDir":"/tmp/packages","projections":[{"agents":["codex"],"path":"/tmp/projection"}],"workspace":{"manifest":"/tmp/skills.yaml","lock":"/tmp/skills-lock.yaml"}}',
      stderr: '',
    );
    await gateway.installTargets(summary, 'v1', const [
      InstallationTargetSelection(
        agent: 'codex',
        scope: InstallationScope.global,
      ),
    ]);
    expect(
      runner.lastExecutable,
      r'/Applications/Skills Play/$(echo nope)/skillsgo',
    );
    expect(runner.lastArguments, [
      'add',
      r'github.com/a/b@v1',
      '--skill-path',
      r'nested/test;$(touch nope)',
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
      stdout: r'''
{"schemaVersion":2,"phase":"management-preflight","targets":[{"target":{"scope":"global","agent":"codex","path":"/tmp/Test ; $(touch nope)"},"name":"Test ; $(touch nope)","skillId":"github.com/a/b/-/Test ; $(touch nope)","version":"","health":"healthy","allowedActions":["remove"],"stateToken":"sha256:state","workspaceMetadataChange":false}],"summary":{"removable":1}}
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
          scope: InstallationScope.global,
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
    expect(runner.lastArguments, containsAllInOrder(['--output', 'json']));
    expect(runner.lastArguments, isNot(contains('--preflight')));
    expect(
      runner.calls.map((call) => call.executable),
      isNot(contains('/bin/sh')),
    );
  });

  test(
    'target installation invokes exact Repository Package Store add without a materialization mode',
    () async {
      const packagePath = 'github.com/example/skills';
      final runner = FakeProcessRunner()
        ..result = ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'phase': 'package-install',
            'packagePath': 'github.com/example/skills',
            'version': 'v1',
            'sum': 'h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
            'skills': ['nested/demo'],
            'agents': ['codex'],
            'packageDir': '/Users/test/.skillsgo/packages/example/v1',
            'projections': [
              {
                'agents': ['codex'],
                'path': '/Users/test/.codex/skills/example/v1',
              },
            ],
            'workspace': {
              'manifest': '/Users/test/.agents/skills.yaml',
              'lock': '/Users/test/.agents/skills-lock.yaml',
            },
          }),
          stderr: '',
        );
      final gateway = DesktopSkillsGateway(
        processRunner: runner,
        initialCliPath: '/Applications/SkillsGo.app/skillsgo',
      );
      const skill = SkillSummary(
        packagePath: packagePath,
        installName: 'demo',
        name: 'demo',
        path: 'nested/demo',
        installs: 0,
        latestVersion: 'v1',
      );

      final execution = await gateway.installTargets(skill, 'v1', const [
        InstallationTargetSelection(
          scope: InstallationScope.global,
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
          '--skill-path',
          'nested/demo',
        ]),
      );
      expect(runner.lastArguments, contains('--global'));
      expect(runner.lastArguments, isNot(contains('--target')));
      expect(runner.lastArguments, isNot(contains('--version')));
      expect(runner.lastArguments, isNot(contains('--copy')));
    },
  );

  test(
    'Package installation accepts repeated Agent projections from declared members',
    () async {
      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"package-install","packagePath":"github.com/example/skills","version":"v1","sum":"h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","skills":["existing/member","skills/alpha","nested/beta"],"agents":["codex"],"packageDir":"/tmp/packages","projections":[{"agents":["codex"],"path":"/tmp/alpha"},{"agents":["codex"],"path":"/tmp/beta"},{"agents":["codex"],"path":"/tmp/existing"}],"workspace":{"manifest":"/tmp/skills.yaml","lock":"/tmp/skills-lock.yaml"}}',
          stderr: '',
        );
      final gateway = DesktopSkillsGateway(
        processRunner: runner,
        initialCliPath: '/Applications/SkillsGo.app/skillsgo',
      );
      const skills = [
        SkillSummary(
          packagePath: 'github.com/example/skills',
          installName: 'alpha',
          name: 'alpha',
          path: 'skills/alpha',
          latestVersion: 'v1',
        ),
        SkillSummary(
          packagePath: 'github.com/example/skills',
          installName: 'beta',
          name: 'beta',
          path: 'nested/beta',
          latestVersion: 'v1',
        ),
      ];

      final executions = await gateway.installPackageTargets(skills, const [
        InstallationTargetSelection(
          scope: InstallationScope.global,
          agent: 'codex',
        ),
      ], confirmRisk: true);

      expect(executions, hasLength(2));
      expect(executions.every((execution) => execution.hasSuccess), isTrue);
      expect(
        executions.every((execution) => execution.results.isEmpty),
        isTrue,
      );
      expect(runner.calls, hasLength(1));
      expect(runner.lastArguments, [
        'add',
        'github.com/example/skills@v1',
        '--skill-path',
        'skills/alpha',
        '--skill-path',
        'nested/beta',
        '--agent',
        'codex',
        '--global',
        '--yes',
        '--output',
        'json',
        '--hub',
        'https://hub.skillsgo.ai',
      ]);
    },
  );

  test('local detail reads canonical SKILL.md without writing files', () async {
    final directory = await Directory.systemTemp.createTemp('skillsgo-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/SKILL.md');
    await file.writeAsString('# Local');
    final before = await file.lastModified();
    final gateway = DesktopSkillsGateway(processRunner: FakeProcessRunner());

    final detail = await gateway.loadLocalDetail(
      InstalledSkill(
        name: 'Local',
        path: directory.path,
        agents: const ['codex'],
        targetCount: 1,
      ),
    );

    expect(detail.content, '# Local');
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
      final gateway = DesktopSkillsGateway(processRunner: FakeProcessRunner());

      final detail = await gateway.loadLocalDetail(
        InstalledSkill(
          name: 'Local',
          path: missing.path,
          agents: const ['codex'],
          targetCount: 2,
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.global,
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

      expect(detail.content, '# Healthy target');
      expect(detail.version, 'v1');
      expect(detail.installationTargets, hasLength(2));
    },
  );

  test(
    'External detail inspection is read-only and reads canonical SKILL.md',
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
      final gateway = DesktopSkillsGateway(
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
            scope: InstallationScope.global,
            path: directory.path,
            version: '',
          ),
        ],
      );

      final detail = await gateway.loadLocalDetail(external);

      expect(detail.path, directory.path);
      expect(detail.content, '# External instructions');
      await expectLater(
        gateway.updatePackage(external, toVersion: 'v2'),
        throwsA(isA<SkillsException>()),
      );
      expect(runner.calls, isEmpty);
      for (final file in [skillFile, script, notes, large]) {
        expect(await file.readAsBytes(), before[file.path]);
      }
    },
  );

  test(
    'Adoption sends reviewed mapping through stdin and parses results',
    () async {
      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"results":[{"inventoryKey":"external:demo","status":"adopted"},{"inventoryKey":"external:project-demo","status":"failed","reason":"install failed"}]}',
          stderr: '',
        );
      final gateway = DesktopSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
        hubBaseUrl: 'https://must-not-be-used.example',
      );

      final result = await gateway.adopt(const [
        AdoptionRequestItem(
          inventoryKey: 'external:demo',
          name: 'demo',
          packagePath: 'github.com/acme/skills',
          version: 'v1.2.3',
          skillPath: 'skills/demo',
          targets: [
            AdoptionTarget(
              agent: 'codex',
              scope: InstallationScope.global,
              path: '/tmp/demo',
            ),
          ],
        ),
        AdoptionRequestItem(
          inventoryKey: 'external:project-demo',
          name: 'project-demo',
          packagePath: 'github.com/acme/skills',
          version: 'v1.2.3',
          skillPath: 'skills/project-demo',
          targets: [
            AdoptionTarget(
              agent: 'claude-code',
              scope: InstallationScope.project,
              projectRoot: '/tmp/Workspace With Spaces',
              path: '/tmp/Workspace With Spaces/.claude/skills/project-demo',
            ),
          ],
        ),
      ]);

      expect(result.adopted, 1);
      expect(result.failed, 1);
      expect(result.items.last.status, BatchAdoptionItemStatus.failed);
      expect(result.items.last.reason, 'install failed');
      expect(runner.lastArguments, [
        'adopt',
        '--input',
        '-',
        '--output',
        'json',
        '--hub',
        'https://must-not-be-used.example',
      ]);
      expect(jsonDecode(runner.lastStdin!), {
        'schemaVersion': 1,
        'items': [
          {
            'inventoryKey': 'external:demo',
            'name': 'demo',
            'packagePath': 'github.com/acme/skills',
            'version': 'v1.2.3',
            'skillPath': 'skills/demo',
            'targets': [
              {'agent': 'codex', 'scope': 'global', 'path': '/tmp/demo'},
            ],
          },
          {
            'inventoryKey': 'external:project-demo',
            'name': 'project-demo',
            'packagePath': 'github.com/acme/skills',
            'version': 'v1.2.3',
            'skillPath': 'skills/project-demo',
            'targets': [
              {
                'agent': 'claude-code',
                'scope': 'project',
                'projectRoot': '/tmp/Workspace With Spaces',
                'path':
                    '/tmp/Workspace With Spaces/.claude/skills/project-demo',
              },
            ],
          },
        ],
      });
    },
  );

  test('Adoption rejects duplicate result identities', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":1,"results":[{"inventoryKey":"external:demo","status":"adopted"},{"inventoryKey":"external:demo","status":"adopted"}]}',
        stderr: '',
      );
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
      hubBaseUrl: 'https://must-not-be-used.example',
    );

    await expectLater(
      gateway.adopt(const [
        AdoptionRequestItem(
          inventoryKey: 'external:demo',
          name: 'demo',
          packagePath: 'github.com/acme/skills',
          version: 'v1.2.3',
          skillPath: 'skills/demo',
          targets: [
            AdoptionTarget(
              agent: 'codex',
              scope: InstallationScope.global,
              path: '/tmp/demo',
            ),
          ],
        ),
      ]),
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
