/*
 * [INPUT]: Uses controlled CLI plan, progress, and result streams plus the production SkillsGateway adapter.
 * [OUTPUT]: Specifies reviewed Target Operation Plan and Update Plan parsing, execution, progress, retry, and Catalog-only batch update-state contracts.
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
{"schemaVersion":1,"phase":"update-check","items":[{"key":"hub:github.com/example/skills/-/test","skillId":"github.com/example/skills/-/test","versions":["v1"],"latestVersion":"v2","status":"update_available"}]}
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
      states['hub:github.com/example/skills/-/test'],
      UpdateState.available,
    );
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

  test('update execution parses only versioned target NDJSON', () async {
    final runner = FakeProcessRunner()
      ..result = const ProcessOutput(
        exitCode: 0,
        stdout: '''
{"schemaVersion":1,"phase":"update-progress","sequence":1,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","state":"started"}
{"schemaVersion":1,"phase":"update-progress","sequence":2,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","state":"finished","result":{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","outcome":"succeeded"}}
{"schemaVersion":1,"phase":"update-execution","results":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","outcome":"succeeded"}],"summary":{"succeeded":1,"skipped":0,"failed":0}}
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
          skillId: 'github.com/example/skills/-/test',
          sourceRef: 'main',
          fromVersion: 'v1',
          toVersion: 'v2',
          action: UpdatePlanAction.update,
          stateToken: 'sha256:state',
          workspaceManifestChange: false,
        ),
      ],
      workspaceManifestChanges: [],
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
      exitCode: 1,
      stdout: '''
{"schemaVersion":1,"phase":"update-progress","sequence":1,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","state":"started"}
{"schemaVersion":1,"phase":"update-progress","sequence":2,"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","state":"finished","result":{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","outcome":"failed","error":{"code":"update.target_failed","retryable":true,"requestId":"req-42","diagnostic":"developer detail","future":"ignored"}}}
{"schemaVersion":1,"phase":"update-execution","results":[{"target":{"scope":"user","agent":"codex","mode":"symlink","path":"/tmp/Test"},"name":"Test","skillId":"github.com/example/skills/-/test","fromVersion":"v1","toVersion":"v2","outcome":"failed","error":{"code":"update.target_failed","retryable":true,"requestId":"req-42","diagnostic":"developer detail","future":"ignored"}}],"summary":{"succeeded":0,"skipped":0,"failed":1}}
''',
      stderr: '任意本地化诊断',
    );
    final failedExecution = await gateway.executeUpdate(plan);
    expect(failedExecution.summary.failed, 1);
    expect(failedExecution.results.single.error?.code, 'update.target_failed');
    expect(failedExecution.results.single.error?.retryable, isTrue);
    expect(failedExecution.results.single.error?.requestId, 'req-42');
    expect(
      failedExecution.results.single.error?.diagnostic,
      'developer detail',
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
