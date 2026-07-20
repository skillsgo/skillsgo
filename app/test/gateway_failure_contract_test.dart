/*
 * [INPUT]: Uses controlled CLI exit codes, versioned machine-error responses, and the production SkillsGateway adapter.
 * [OUTPUT]: Specifies typed failure classification, additive-field tolerance, malformed protocol handling, and NDJSON error extraction contracts.
 * [POS]: Serves as the CLI failure-translation contract suite at the SkillsGateway seam.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/real_skills_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_process_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'CLI exit codes distinguish availability from malformed output',
    () async {
      for (final testCase in [
        (exitCode: 69, kind: SkillsFailureKind.offline, offline: true),
        (exitCode: 75, kind: SkillsFailureKind.timeout, offline: false),
        (exitCode: 1, kind: SkillsFailureKind.server, offline: false),
      ]) {
        final gateway = RealSkillsGateway(
          processRunner: FakeProcessRunner()
            ..result = ProcessOutput(
              exitCode: testCase.exitCode,
              stdout: '',
              stderr: 'arbitrary localized diagnostics',
            ),
          initialCliPath: '/usr/local/bin/skillsgo',
        );

        await expectLater(
          gateway.inspectAgents(),
          throwsA(
            isA<SkillsException>()
                .having((error) => error.kind, 'kind', testCase.kind)
                .having(
                  (error) => error.isOffline,
                  'isOffline',
                  testCase.offline,
                ),
          ),
        );
      }

      final malformed = RealSkillsGateway(
        processRunner: FakeProcessRunner()
          ..result = const ProcessOutput(
            exitCode: 0,
            stdout: 'not JSON',
            stderr: '',
          ),
        initialCliPath: '/usr/local/bin/skillsgo',
      );
      await expectLater(
        malformed.inspectAgents(),
        throwsA(
          isA<SkillsException>().having(
            (error) => error.kind,
            'kind',
            SkillsFailureKind.invalidLocalData,
          ),
        ),
      );
    },
  );

  test('CLI machine failures classify without localized stderr', () async {
    final gateway = RealSkillsGateway(
      processRunner: FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 69,
          stdout:
              '{"schemaVersion":1,"phase":"error","error":{"code":"hub.unavailable","retryable":true,"requestId":"req-123","diagnostic":"connection refused"}}',
          stderr: '任意本地化诊断，不属于机器协议',
        ),
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(
      gateway.inspectAgents(),
      throwsA(
        isA<SkillsException>()
            .having((error) => error.kind, 'kind', SkillsFailureKind.offline)
            .having((error) => error.code, 'code', 'hub.unavailable')
            .having((error) => error.retryable, 'retryable', isTrue)
            .having((error) => error.requestId, 'requestId', 'req-123')
            .having(
              (error) => error.diagnostic,
              'diagnostic',
              'connection refused',
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('任意本地化诊断')),
            ),
      ),
    );
  });

  test('Hub processing failures are not classified as offline', () async {
    final gateway = RealSkillsGateway(
      processRunner: FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 1,
          stdout:
              '{"schemaVersion":1,"phase":"error","error":{"code":"hub.server_error","retryable":true,"diagnostic":"Hub returned HTTP 500"}}',
          stderr: '',
        ),
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(
      gateway.inspectAgents(),
      throwsA(
        isA<SkillsException>()
            .having((error) => error.kind, 'kind', SkillsFailureKind.server)
            .having((error) => error.isOffline, 'isOffline', isFalse)
            .having((error) => error.code, 'code', 'hub.server_error')
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });

  test(
    'CLI machine failures tolerate unknown codes and additive fields',
    () async {
      final gateway = RealSkillsGateway(
        processRunner: FakeProcessRunner()
          ..result = const ProcessOutput(
            exitCode: 1,
            stdout:
                '{"schemaVersion":1,"phase":"error","future":"ignored","error":{"code":"future.new_failure","retryable":false,"futureDetail":42}}',
            stderr: 'must not become product copy',
          ),
        initialCliPath: '/usr/local/bin/skillsgo',
      );

      await expectLater(
        gateway.inspectAgents(),
        throwsA(
          isA<SkillsException>()
              .having((error) => error.kind, 'kind', SkillsFailureKind.server)
              .having((error) => error.code, 'code', 'future.new_failure')
              .having((error) => error.retryable, 'retryable', isFalse),
        ),
      );
    },
  );

  test('malformed CLI machine failure is a protocol failure', () async {
    final gateway = RealSkillsGateway(
      processRunner: FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 69,
          stdout:
              '{"schemaVersion":2,"phase":"error","error":{"code":"hub.unavailable","retryable":true}}',
          stderr: 'offline text must not override the malformed protocol',
        ),
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(
      gateway.inspectAgents(),
      throwsA(
        isA<SkillsException>()
            .having(
              (error) => error.kind,
              'kind',
              SkillsFailureKind.invalidLocalData,
            )
            .having((error) => error.code, 'code', 'protocol.incompatible'),
      ),
    );
  });

  test('CLI machine failure reads the final NDJSON line', () async {
    final gateway = RealSkillsGateway(
      processRunner: FakeProcessRunner()
        ..result = const ProcessOutput(
          exitCode: 75,
          stdout:
              '{"schemaVersion":1,"phase":"update-progress","sequence":1}\n'
              '{"schemaVersion":1,"phase":"error","error":{"code":"hub.timeout","retryable":true}}\n',
          stderr: 'localized timeout diagnostic',
        ),
      initialCliPath: '/usr/local/bin/skillsgo',
    );

    await expectLater(
      gateway.inspectAgents(),
      throwsA(
        isA<SkillsException>()
            .having((error) => error.kind, 'kind', SkillsFailureKind.timeout)
            .having((error) => error.code, 'code', 'hub.timeout')
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });
}
