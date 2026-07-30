/*
 * [INPUT]: Uses controlled process output and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies bundled CLI startup handshake, platform compatibility, developer override, non-destructive concurrent detection, safe-read transport recovery, and revalidation contracts.
 * [POS]: Serves as the CLI lifecycle contract suite at the SkillsGateway seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
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
    'detectCli verifies the bundled executable without searching PATH',
    () async {
      final runner = FakeProcessRunner()
        ..result = ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '0.1.0',
            'appProtocolVersion': 17,
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
    final runner = FakeProcessRunner()
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
    final runner = FakeProcessRunner()
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
    final runner = FakeProcessRunner()
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
    final runner = FakeProcessRunner()
      ..result = ProcessOutput(
        exitCode: 0,
        stdout: jsonEncode({
          'schemaVersion': 1,
          'product': 'skillsgo',
          'version': '0.1.0',
          'appProtocolVersion': 17,
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
      final runner = FakeProcessRunner()
        ..result = ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '7.4.2',
            'appProtocolVersion': 17,
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
    final runner = FakeProcessRunner()
      ..result = ProcessOutput(
        exitCode: 0,
        stdout: jsonEncode({
          'schemaVersion': 1,
          'product': 'skillsgo',
          'version': 'dev',
          'appProtocolVersion': 17,
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
    final runner = FakeProcessRunner()
      ..result = ProcessOutput(
        exitCode: 0,
        stdout: jsonEncode({
          'schemaVersion': 1,
          'product': 'skillsgo',
          'version': '1.0.0',
          'appProtocolVersion': 17,
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

  test('failed revalidation preserves the healthy CLI runtime', () async {
    final runner = FakeCliServerRunner()
      ..responses.addAll([
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '0.1.0',
            'appProtocolVersion': 17,
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
      ])
      ..serverResponses.add(
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({'schemaVersion': 7, 'entries': <Object>[]}),
          stderr: '',
        ),
      );
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

    expect(await gateway.listInstalled(), isEmpty);
    expect(runner.calls, hasLength(2));
    expect(runner.starts, 1);
  });

  test('App commands reuse one CLI Server session', () async {
    final runner = FakeCliServerRunner()
      ..responses.add(
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '0.1.0',
            'appProtocolVersion': 17,
            'os': 'darwin',
            'architecture': 'arm64',
          }),
          stderr: '',
        ),
      );
    final agents = jsonEncode({'schemaVersion': 2, 'agents': <Object>[]});
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
      expectedCliOS: 'darwin',
    );

    runner.serverResponses.addAll([
      ProcessOutput(exitCode: 0, stdout: agents, stderr: ''),
      ProcessOutput(exitCode: 0, stdout: agents, stderr: ''),
    ]);
    expect((await gateway.detectCli()).isReady, isTrue);
    await gateway.inspectAgents();
    await gateway.inspectAgents();

    expect(runner.starts, 1);
    expect(runner.sessions.single.calls, [
      ['agents', '--output', 'json'],
      ['agents', '--output', 'json'],
    ]);
    expect(runner.calls, hasLength(1));
  });

  test('a dead CLI Server is rebuilt for the next command', () async {
    final runner = FakeCliServerRunner();
    final agents = jsonEncode({'schemaVersion': 2, 'agents': <Object>[]});
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bundle/skillsgo',
    );

    runner.serverResponses.add(
      ProcessOutput(exitCode: 0, stdout: agents, stderr: ''),
    );
    await gateway.inspectAgents();
    runner.sessions.single.isClosed = true;
    runner.serverResponses.add(
      ProcessOutput(exitCode: 0, stdout: agents, stderr: ''),
    );
    await gateway.inspectAgents();

    expect(runner.starts, 2);
  });

  test('concurrent cold commands share detection and Server startup', () async {
    final runner = FakeCliServerRunner()
      ..responses.add(
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '0.1.0',
            'appProtocolVersion': 17,
            'os': 'darwin',
            'architecture': 'arm64',
          }),
          stderr: '',
        ),
      );
    final agents = jsonEncode({'schemaVersion': 2, 'agents': <Object>[]});
    runner.serverResponses.addAll([
      ProcessOutput(exitCode: 0, stdout: agents, stderr: ''),
      ProcessOutput(exitCode: 0, stdout: agents, stderr: ''),
    ]);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
      expectedCliOS: 'darwin',
    );

    await Future.wait([gateway.inspectAgents(), gateway.inspectAgents()]);

    expect(runner.calls, hasLength(1));
    expect(runner.starts, 1);
    expect(runner.sessions.single.calls, hasLength(2));
  });

  test(
    'concurrent detection does not interrupt an active CLI request',
    () async {
      final runner = _BlockingCliServerRunner();
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bundle/skillsgo',
        bundledCliPath: '/bundle/skillsgo',
        allowDeveloperCliOverride: false,
        expectedCliOS: 'darwin',
      );

      final inventory = gateway.listInstalled();
      await runner.requestStarted.future;
      final detection = gateway.detectCli();
      await Future<void>.delayed(Duration.zero);

      expect(runner.session.isClosed, isFalse);
      runner.completeRequest();
      await inventory;
      expect((await detection).isReady, isTrue);
      expect(runner.starts, 1);
    },
  );

  test('a failed concurrent detection preserves the active request', () async {
    final runner = _BlockingCliServerRunner(detectionSucceeds: false);
    final gateway = RealSkillsGateway(
      processRunner: runner,
      initialCliPath: '/bundle/skillsgo',
      bundledCliPath: '/bundle/skillsgo',
      allowDeveloperCliOverride: false,
      expectedCliOS: 'darwin',
    );

    final inventory = gateway.listInstalled();
    await runner.requestStarted.future;
    final detection = gateway.detectCli();
    await Future<void>.delayed(Duration.zero);

    expect(runner.session.isClosed, isFalse);
    runner.completeRequest();
    expect(await inventory, isEmpty);
    expect((await detection).availability, CliAvailability.incompatible);
    expect(runner.session.isClosed, isFalse);
  });

  test(
    'custom-path detection waits for and follows startup detection',
    () async {
      final runner = _QueuedDetectionRunner();
      final gateway = RealSkillsGateway(
        processRunner: runner,
        bundledCliPath: '/bundle/skillsgo',
        allowDeveloperCliOverride: true,
        expectedCliOS: 'darwin',
      );

      final startup = gateway.detectCli();
      final custom = gateway.detectCli(customPath: '/custom/skillsgo');

      expect((await startup).path, '/bundle/skillsgo');
      expect((await custom).path, '/custom/skillsgo');
      expect(runner.calls.map((call) => call.executable), [
        '/bundle/skillsgo',
        '/custom/skillsgo',
      ]);
    },
  );

  test(
    'safe read reconnects once after a CLI Server transport failure',
    () async {
      final runner = _RecoveringCliServerRunner();
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bundle/skillsgo',
      );

      expect((await gateway.inspectAgents()).agents, isEmpty);
      expect(runner.starts, 2);
    },
  );

  test(
    'mutating commands are not replayed after a transport failure',
    () async {
      final runner = _RecoveringCliServerRunner();
      final gateway = RealSkillsGateway(
        processRunner: runner,
        initialCliPath: '/bundle/skillsgo',
      );

      await expectLater(
        gateway.removeProject('/project'),
        throwsA(isA<SkillsException>()),
      );
      expect(runner.starts, 1);
    },
  );
}

class _QueuedDetectionRunner extends FakeProcessRunner {
  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) async {
    calls.add((executable: executable, arguments: List.of(arguments)));
    await Future<void>.delayed(Duration.zero);
    return ProcessOutput(
      exitCode: 0,
      stdout: jsonEncode({
        'schemaVersion': 1,
        'product': 'skillsgo',
        'version': '1.0.0',
        'appProtocolVersion': 17,
        'os': 'darwin',
        'architecture': 'arm64',
      }),
      stderr: '',
    );
  }
}

class _RecoveringCliServerRunner extends FakeProcessRunner
    implements CliServerRunner {
  int starts = 0;

  @override
  Future<CliServerSession> startCliServer(String executable) async {
    starts++;
    return _RecoveringCliServerSession(fails: starts == 1);
  }
}

class _RecoveringCliServerSession implements CliServerSession {
  _RecoveringCliServerSession({required this.fails});

  final bool fails;

  @override
  bool isClosed = false;

  @override
  Future<ProcessOutput> run(
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) async {
    if (fails) {
      isClosed = true;
      return const ProcessOutput(
        exitCode: 127,
        stdout: '',
        stderr: '/bundle/skillsgo: CLI Server exited.',
        transportFailure: true,
      );
    }
    return ProcessOutput(
      exitCode: 0,
      stdout: jsonEncode({'schemaVersion': 2, 'agents': <Object>[]}),
      stderr: '',
    );
  }

  @override
  Future<void> close() async => isClosed = true;
}

class _BlockingCliServerRunner extends FakeProcessRunner
    implements CliServerRunner {
  _BlockingCliServerRunner({this.detectionSucceeds = true}) {
    result = ProcessOutput(
      exitCode: 0,
      stdout: detectionSucceeds
          ? jsonEncode({
              'schemaVersion': 1,
              'product': 'skillsgo',
              'version': '1.0.0',
              'appProtocolVersion': 17,
              'os': 'darwin',
              'architecture': 'arm64',
            })
          : '{"product":"damaged"}',
      stderr: '',
    );
  }

  final bool detectionSucceeds;
  final requestStarted = Completer<void>();
  final _requestResult = Completer<ProcessOutput>();
  late final _BlockingCliServerSession session;
  int starts = 0;

  @override
  Future<CliServerSession> startCliServer(String executable) async {
    starts++;
    return session = _BlockingCliServerSession(
      executable,
      requestStarted,
      _requestResult,
    );
  }

  void completeRequest() => _requestResult.complete(
    ProcessOutput(
      exitCode: 0,
      stdout: jsonEncode({'schemaVersion': 7, 'entries': <Object>[]}),
      stderr: '',
    ),
  );
}

class _BlockingCliServerSession implements CliServerSession {
  _BlockingCliServerSession(
    this.executable,
    this.requestStarted,
    this.requestResult,
  );

  final String executable;
  final Completer<void> requestStarted;
  final Completer<ProcessOutput> requestResult;

  @override
  bool isClosed = false;

  @override
  Future<ProcessOutput> run(
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) {
    if (!requestStarted.isCompleted) requestStarted.complete();
    return requestResult.future;
  }

  @override
  Future<void> close() async => isClosed = true;
}
