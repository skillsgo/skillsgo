/*
 * [INPUT]: Uses controlled process output and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies bundled CLI startup handshake, platform compatibility, developer override, and revalidation contracts.
 * [POS]: Serves as the CLI lifecycle contract suite at the SkillsGateway seam.
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
    'detectCli verifies the bundled executable without searching PATH',
    () async {
      final runner = FakeProcessRunner()
        ..result = ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '0.1.0',
            'appProtocolVersion': 10,
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
          'appProtocolVersion': 10,
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
            'appProtocolVersion': 10,
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
          'appProtocolVersion': 10,
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
          'appProtocolVersion': 10,
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
    final runner = FakeProcessRunner()
      ..responses.addAll([
        ProcessOutput(
          exitCode: 0,
          stdout: jsonEncode({
            'schemaVersion': 1,
            'product': 'skillsgo',
            'version': '0.1.0',
            'appProtocolVersion': 10,
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
    expect(runner.lastArguments, ['version', '--output', 'json']);
  });
}
