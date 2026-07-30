/*
 * [INPUT]: Uses controlled CLI target-operation streams, Package update receipts, and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies Target Operation Plans, direct Package updates with identity-only receipt validation, and Scope-by-Package preview contracts.
 * [POS]: Serves as the target-management and update contract suite at the SkillsGateway seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/desktop_skills_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_process_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('managed removal uses the Package member machine protocol', () async {
    const installed = InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills:demo',
      name: 'demo',
      path: '/work/.codex/skills/demo',
      agents: ['codex'],
      targetCount: 1,
      packagePath: 'github.com/example/skills',
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.project,
          projectRoot: '/work',
          path: '/work/.codex/skills/demo',
          version: 'v1.2.3',
        ),
      ],
    );
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout:
            '{"schemaVersion":1,"phase":"package-remove","skills":["demo"],"scope":"project"}\n',
        stderr: '',
      );
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );

    final preflight = await gateway.preflightTargetManagement(
      installed,
      installed.targets,
    );
    final plan = preflight.selectActions({
      installationTargetKey(preflight.targets.single.target):
          TargetManagementAction.remove,
    });
    final execution = await gateway.executeTargetManagement(plan);

    expect(execution.summary.succeeded, 1);
    expect(runner.lastArguments, [
      'remove',
      'demo',
      '--project',
      '/work',
      '--yes',
      '--output',
      'json',
    ]);
  });

  test('managed removal executes every Skill in the same Scope', () async {
    InstalledSkill installed(String name) => InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills:$name',
      name: name,
      path: '/work/.codex/skills/$name',
      agents: const ['codex'],
      targetCount: 1,
      packagePath: 'github.com/example/skills',
      targets: [
        SkillInstallationTarget(
          agent: 'codex',
          scope: InstallationScope.project,
          projectRoot: '/work',
          path: '/work/.codex/skills/$name',
          version: 'v1.2.3',
        ),
      ],
    );
    final runner = FakeProcessRunner()
      ..responses.addAll(const [
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"package-remove","skills":["alpha"],"scope":"project"}\n',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"package-remove","skills":["beta"],"scope":"project"}\n',
          stderr: '',
        ),
      ]);
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );
    final preflights = await Future.wait([
      for (final skill in [installed('alpha'), installed('beta')])
        gateway.preflightTargetManagement(skill, skill.targets),
    ]);
    final targets = [for (final plan in preflights) ...plan.targets];
    final plan = TargetManagementPlan(
      targets: [
        for (final item in targets) item.select(TargetManagementAction.remove),
      ],
      summary: const TargetManagementPlanSummary(removable: 2),
    );

    final execution = await gateway.executeTargetManagement(plan);

    expect(execution.summary.succeeded, 2);
    expect(
      runner.calls.map((call) => call.arguments),
      containsAllInOrder([
        ['remove', 'alpha', '--project', '/work', '--yes', '--output', 'json'],
        ['remove', 'beta', '--project', '/work', '--yes', '--output', 'json'],
      ]),
    );
  });

  test(
    'Target Management Plans preserve exact targets and parse versioned NDJSON',
    () async {
      const installed = InstalledSkill(
        inventoryKey: 'external:/tmp/Test',
        name: 'Test',
        path: '/tmp/Test',
        agents: ['codex'],
        targetCount: 1,
        provenance: LibraryProvenance.external,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.global,
            path: '/tmp/Test',
            version: '',
          ),
        ],
      );
      final runner = FakeProcessRunner()
        ..responses.addAll(const [
          ProcessOutput(
            exitCode: 0,
            stdout: '''
{"schemaVersion":2,"phase":"management-preflight","targets":[{"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","health":"healthy","allowedActions":["remove"],"stateToken":"sha256:state","workspaceMetadataChange":false}],"summary":{"removable":1}}
''',
            stderr: '',
          ),
          ProcessOutput(
            exitCode: 0,
            stdout: '''
{"schemaVersion":2,"phase":"management-progress","sequence":1,"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","action":"remove","state":"started"}
{"schemaVersion":2,"phase":"management-progress","sequence":2,"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","action":"remove","state":"finished","result":{"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","action":"remove","outcome":"succeeded"}}
{"schemaVersion":2,"phase":"management-execution","results":[{"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","action":"remove","outcome":"succeeded"}],"summary":{"succeeded":1,"failed":0}}
''',
            stderr: '',
          ),
        ]);
      final gateway = DesktopSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
      );

      final preflight = await gateway.preflightTargetManagement(
        installed,
        installed.targets,
      );
      final targetKey = installationTargetKey(preflight.targets.single.target);
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
      expect(runner.lastArguments!.first, 'remove');
      expect(
        runner.lastArguments,
        containsAllInOrder([
          '--path',
          '/tmp/Test',
          '--agent',
          'codex',
          '--yes',
        ]),
      );
      expect(
        runner.lastArguments,
        containsAll(['--yes', '--output', 'ndjson']),
      );

      runner.result = const ProcessOutput(
        exitCode: 1,
        stdout: '''
{"schemaVersion":2,"phase":"management-progress","sequence":1,"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","action":"remove","state":"started"}
{"schemaVersion":2,"phase":"management-progress","sequence":2,"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","action":"remove","state":"finished","result":{"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","action":"remove","outcome":"failed","error":{"code":"management.target_failed","retryable":true,"details":{"path":"/tmp/Test"},"diagnostic":"developer detail"}}}
{"schemaVersion":2,"phase":"management-execution","results":[{"target":{"scope":"global","agent":"codex","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"","action":"remove","outcome":"failed","error":{"code":"management.target_failed","retryable":true,"details":{"path":"/tmp/Test"},"diagnostic":"developer detail"}}],"summary":{"succeeded":0,"failed":1}}
''',
        stderr: 'localized stderr must not classify',
      );
      final failedExecution = await gateway.executeTargetManagement(plan);
      expect(failedExecution.summary.failed, 1);
      expect(
        failedExecution.results.single.error?.code,
        'management.target_failed',
      );
      expect(failedExecution.results.single.error?.retryable, isTrue);
      expect(
        failedExecution.results.single.error?.details['path'],
        '/tmp/Test',
      );
      expect(
        failedExecution.results.single.error?.diagnostic,
        'developer detail',
      );

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

  test(
    'update check uses one deduplicated mutation-free cross-Scope preview',
    () async {
      final runner = FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 0,
          stdout: '''
{"schemaVersion":1,"phase":"package-update-preview","updates":[{"schemaVersion":1,"phase":"package-update-preview","packagePath":"github.com/example/skills","fromVersion":"v1","toVersion":"v2","scope":"global","status":"update_available","selectedSkillCount":1,"removedSkills":[{"name":"Retired Skill","path":"skills/retired/SKILL.md"}]},{"schemaVersion":1,"phase":"package-update-preview","packagePath":"github.com/example/skills","fromVersion":"v2","toVersion":"v2","scope":"project","projectRoot":"/work","status":"up_to_date","selectedSkillCount":1,"removedSkills":[]}]}
''',
          stderr: '',
        );
      final gateway = DesktopSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bin/skillsgo',
      );

      final states = await gateway.checkUpdates(const [
        InstalledSkill(
          inventoryKey: 'hub:github.com/example/skills:test',
          name: 'test',
          path: '/tmp/Test',
          agents: ['codex'],
          targetCount: 1,
          packagePath: 'github.com/example/skills',
          targets: [
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.global,
              path: '/tmp/Test',
              version: 'v1',
            ),
            SkillInstallationTarget(
              agent: 'codex',
              scope: InstallationScope.project,
              projectRoot: '/work',
              path: '/work/.codex/skills/test',
              version: 'v2',
            ),
          ],
        ),
      ]);

      expect(
        states['github.com/example/skills\u0000global\u0000']?.state,
        UpdateState.available,
      );
      expect(
        states['github.com/example/skills\u0000global\u0000']?.toVersion,
        'v2',
      );
      expect(
        states['github.com/example/skills\u0000global\u0000']
            ?.removedSkills
            .single
            .name,
        'Retired Skill',
      );
      expect(
        states['github.com/example/skills\u0000project\u0000/work']?.state,
        UpdateState.upToDate,
      );
      expect(runner.calls, hasLength(1));
      expect(runner.lastArguments!.first, 'update');
      expect(runner.lastArguments, containsAll(['--all', '--dry-run']));
      expect(runner.lastArguments, isNot(contains('--yes')));
    },
  );

  test('update delegates one Package coordinate per scope to CLI', () async {
    final runner = FakeProcessRunner()
      ..responses.addAll(const [
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"package-update","packagePath":"github.com/example/skills","fromVersion":"v1","toVersion":"v2","sum":"h1:test","skills":["test"],"agents":["codex"],"scope":"global","packageDir":"/tmp/packages"}\n',
          stderr: '',
        ),
      ]);
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );
    const installed = InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills:test',
      name: 'test',
      path: '/tmp/Test',
      agents: ['codex'],
      targetCount: 1,
      packagePath: 'github.com/example/skills',
      targets: [
        SkillInstallationTarget(
          scope: InstallationScope.global,
          agent: 'codex',
          path: '/tmp/Test',
          version: 'v1',
        ),
      ],
    );
    expect(runner.calls, isEmpty);
    await gateway.updatePackage(installed, toVersion: 'v2');
    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.arguments, [
      'update',
      'github.com/example/skills@v2',
      '--global',
      '--yes',
      '--output',
      'json',
      '--hub',
      'https://hub.skillsgo.ai',
    ]);
    expect(runner.lastArguments, isNot(contains('--target')));
    expect(runner.lastArguments, isNot(contains('mode')));

    runner.result = const ProcessOutput(
      exitCode: 1,
      stdout: '{"schemaVersion":1,"phase":"failure","code":"command_failed"}\n',
      stderr: 'Repository Projection Local Modification',
    );
    await expectLater(
      gateway.updatePackage(installed, toVersion: 'v2'),
      throwsA(isA<SkillsException>()),
    );

    runner.result = const ProcessOutput(
      exitCode: 0,
      stdout: '正在更新目标……',
      stderr: '',
    );
    await expectLater(
      gateway.updatePackage(installed, toVersion: 'v2'),
      throwsA(
        isA<SkillsException>().having(
          (error) => error.kind,
          'kind',
          SkillsFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('update deduplicates Agents into one command for each Scope', () async {
    final runner = FakeProcessRunner()
      ..responses.addAll(const [
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"package-update","packagePath":"github.com/example/skills","fromVersion":"v1","toVersion":"v2","sum":"h1:test","skills":["test"],"agents":["codex","claude-code"],"scope":"global","packageDir":"/tmp/global"}\n',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"package-update","packagePath":"github.com/example/skills","fromVersion":"v1","toVersion":"v2","sum":"h1:test","skills":["test"],"agents":["codex"],"scope":"project","projectRoot":"/work","packageDir":"/work/.skillsgo/packages"}\n',
          stderr: '',
        ),
      ]);
    final gateway = DesktopSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );
    const installed = InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills:test',
      name: 'test',
      path: '/tmp/Test',
      agents: ['codex', 'claude-code'],
      targetCount: 3,
      packagePath: 'github.com/example/skills',
      targets: [
        SkillInstallationTarget(
          scope: InstallationScope.global,
          agent: 'codex',
          path: '/tmp/codex/Test',
          version: 'v1',
        ),
        SkillInstallationTarget(
          scope: InstallationScope.global,
          agent: 'claude-code',
          path: '/tmp/claude/Test',
          version: 'v1',
        ),
        SkillInstallationTarget(
          scope: InstallationScope.project,
          projectRoot: '/work',
          agent: 'codex',
          path: '/work/.codex/skills/Test',
          version: 'v1',
        ),
      ],
    );

    await gateway.updatePackage(installed, toVersion: 'v2');

    expect(runner.calls, hasLength(2));
    expect(runner.calls[0].arguments, contains('--global'));
    expect(
      runner.calls[1].arguments,
      containsAllInOrder(['--project', '/work']),
    );
  });
}
