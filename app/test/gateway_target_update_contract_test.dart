/*
 * [INPUT]: Uses controlled CLI target-operation streams, Repository update documents, and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies reviewed Target Operation Plans, Repository-level update preflight/execution projected onto Library targets, progress, and Catalog-only batch update-state contracts.
 * [POS]: Serves as the target-management and update contract suite at the SkillsGateway seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/real_skills_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_process_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Target Management Plans preserve exact targets and parse versioned NDJSON',
    () async {
      const skillId = 'github.com/example/skills/-/test';
      const installed = InstalledSkill(
        inventoryKey: 'hub:$skillId',
        name: 'Test',
        path: '/tmp/Test',
        agents: ['codex'],
        targetCount: 1,
        skillId: skillId,
        targets: [
          SkillInstallationTarget(
            agent: 'codex',
            scope: InstallationScope.user,
            path: '/tmp/Test',
            version: 'v1',
          ),
        ],
      );
      final runner = FakeProcessRunner()
        ..responses.addAll(const [
          ProcessOutput(
            exitCode: 0,
            stdout: '''
{"schemaVersion":1,"phase":"management-preflight","targets":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","health":"healthy","allowedActions":["remove"],"stateToken":"sha256:state","workspaceMetadataChange":false}],"summary":{"removable":1,"repairable":0}}
''',
            stderr: '',
          ),
          ProcessOutput(
            exitCode: 0,
            stdout: '''
{"schemaVersion":1,"phase":"management-progress","sequence":1,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","action":"remove","state":"started"}
{"schemaVersion":1,"phase":"management-progress","sequence":2,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","action":"remove","state":"finished","result":{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","action":"remove","outcome":"succeeded"}}
{"schemaVersion":1,"phase":"management-execution","results":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","action":"remove","outcome":"succeeded"}],"summary":{"succeeded":1,"failed":0}}
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
      expect(runner.lastArguments!.first, 'remove');
      expect(
        runner.lastArguments,
        containsAllInOrder([
          '--path',
          '/tmp/Test',
          '--agent',
          'codex',
          '--expected-state',
          'sha256:state',
        ]),
      );
      expect(runner.lastArguments, containsAll(['--output', 'ndjson']));

      runner.result = const ProcessOutput(
        exitCode: 1,
        stdout: '''
{"schemaVersion":1,"phase":"management-progress","sequence":1,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","action":"remove","state":"started"}
{"schemaVersion":1,"phase":"management-progress","sequence":2,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","action":"remove","state":"finished","result":{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","action":"remove","outcome":"failed","error":{"code":"management.target_failed","retryable":true,"details":{"path":"/tmp/Test"},"diagnostic":"developer detail"}}}
{"schemaVersion":1,"phase":"management-execution","results":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","version":"v1","action":"remove","outcome":"failed","error":{"code":"management.target_failed","retryable":true,"details":{"path":"/tmp/Test"},"diagnostic":"developer detail"}}],"summary":{"succeeded":0,"failed":1}}
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

  test('update check uses one Catalog-only batch CLI request', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout: '''
{"schemaVersion":1,"phase":"update-check","items":[{"key":"hub:github.com/example/skills/-/test","skillId":"github.com/example/skills/-/test","versions":["v1"],"releaseVersion":"v2","releaseStatus":"update_available","status":"update_available"}]}
''',
        stderr: '',
      );
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );

    final states = await gateway.checkUpdates(const [
      InstalledSkill(
        inventoryKey: 'hub:github.com/example/skills/-/test',
        name: 'Test',
        path: '/tmp/Test',
        agents: ['codex'],
        targetCount: 1,
        skillId: 'github.com/example/skills/-/test',
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
      states['hub:github.com/example/skills/-/test']?.state,
      UpdateState.available,
    );
    expect(states['hub:github.com/example/skills/-/test']?.toVersion, 'v2');
    expect(runner.calls, hasLength(1));
    expect(runner.lastArguments!.take(2), ['updates', 'check']);
    expect(
      runner.lastArguments,
      containsAllInOrder(['--installed', isA<String>()]),
    );
    final installedIndex = runner.lastArguments!.indexOf('--installed');
    final installed =
        jsonDecode(runner.lastArguments![installedIndex + 1])
            as Map<String, dynamic>;
    expect(installed, {
      'key': 'hub:github.com/example/skills/-/test',
      'skillId': 'github.com/example/skills/-/test',
      'versions': ['v1'],
    });
    expect(runner.lastArguments, isNot(contains('--preflight')));
    expect(runner.lastArguments, isNot(contains('--target')));
  });

  test('update uses one state-bound Repository coordinate transaction', () async {
    final runner = FakeProcessRunner()
      ..responses.addAll(const [
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"repository-update-preflight","repository":"github.com/example/skills","fromVersion":"v1","toVersion":"v2","sum":"h1:test","skills":["test"],"agents":["codex"],"scope":"user","vendor":"/tmp/vendor","stateToken":"state"}\n',
          stderr: '',
        ),
        ProcessOutput(
          exitCode: 0,
          stdout:
              '{"schemaVersion":1,"phase":"repository-update","repository":"github.com/example/skills","fromVersion":"v1","toVersion":"v2","sum":"h1:test","skills":["test"],"agents":["codex"],"scope":"user","vendor":"/tmp/vendor","stateToken":"state"}\n',
          stderr: '',
        ),
      ]);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bin/skillsgo',
    );
    const installed = InstalledSkill(
      inventoryKey: 'hub:github.com/example/skills/-/test',
      name: 'Test',
      path: '/tmp/Test',
      agents: ['codex'],
      targetCount: 1,
      skillId: 'github.com/example/skills/-/test',
      targets: [
        SkillInstallationTarget(
          scope: InstallationScope.user,
          agent: 'codex',
          path: '/tmp/Test',
          version: 'v1',
        ),
      ],
    );
    final plan = await gateway.preflightUpdate(
      installed,
      installed.targets,
      toVersion: 'v2',
    );
    final progress = <UpdateTargetProgress>[];

    final execution = await gateway.executeUpdate(
      plan,
      onProgress: progress.add,
    );

    expect(progress, hasLength(2));
    expect(execution.summary.succeeded, 1);
    expect(execution.results.single.toVersion, 'v2');
    expect(plan.targets.single.stateToken, 'state');
    expect(runner.calls, hasLength(2));
    expect(runner.calls.first.arguments, [
      'update',
      'github.com/example/skills@v2',
      '--global',
      '--preflight',
      '--output',
      'json',
      '--hub',
      'https://hub.skillsgo.ai',
    ]);
    expect(
      runner.lastArguments,
      containsAllInOrder(['--state-token', 'state', '--output', 'json']),
    );
    expect(runner.lastArguments, isNot(contains('--target')));
    expect(runner.lastArguments, isNot(contains('mode')));

    runner.result = const ProcessOutput(
      exitCode: 1,
      stdout: '{"schemaVersion":1,"phase":"failure","code":"command_failed"}\n',
      stderr: 'Repository Projection Local Modification',
    );
    await expectLater(
      gateway.executeUpdate(plan),
      throwsA(isA<SkillsException>()),
    );

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
