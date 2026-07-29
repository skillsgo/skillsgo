/*
 * [INPUT]: Depends on suite-provided Hub/PostgreSQL binaries and DSN, the bundled CLI path, real process execution, isolated filesystem roots, deterministic English App language, and SharedPreferences.
 * [OUTPUT]: Provides per-Journey Home/Project/Agent/PostgreSQL-schema/Hub isolation while preserving the real App-to-CLI-to-Hub boundary.
 * [POS]: Serves as the reusable runtime fixture for the single-process cross-platform App E2E suite and focused Journey execution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillsgo/domain/skills_gateway.dart';
import 'package:skillsgo/infrastructure/io_process_runner.dart';
import 'package:skillsgo/infrastructure/real_skills_gateway.dart';

final class JourneyRuntime {
  JourneyRuntime._({
    required this.name,
    required this.sandbox,
    required this.hubOrigin,
    required this.gateway,
    required this._hubProcess,
    required this._hubLogSinks,
  });

  final String name;
  final Directory sandbox;
  final String hubOrigin;
  final RealSkillsGateway gateway;
  final Process? _hubProcess;
  final List<IOSink> _hubLogSinks;

  Directory get home => Directory('${sandbox.path}/home');
  Directory get project => Directory('${sandbox.path}/project');
  Directory get testAgent => Directory('${sandbox.path}/test-agent');

  static Future<JourneyRuntime> start(
    String name, {
    bool startHub = true,
  }) async {
    final suiteRoot = _requiredEnvironment('SKILLSGO_E2E_ROOT');
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final sandbox = Directory('$suiteRoot/journeys/$safeName');
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    for (final path in [
      '${sandbox.path}/home',
      '${sandbox.path}/project',
      '${sandbox.path}/tmp',
      '${sandbox.path}/test-agent/skills',
      '${sandbox.path}/hub/cache',
      '${sandbox.path}/hub/storage',
      '${sandbox.path}/hub/home',
    ]) {
      Directory(path).createSync(recursive: true);
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();

    Process? hubProcess;
    final hubLogSinks = <IOSink>[];
    var hubOrigin = 'http://127.0.0.1:1';
    if (startHub) {
      final databaseDSN = _requiredEnvironment('SKILLSGO_E2E_DATABASE_DSN');
      final schema = 'app_e2e_$safeName'.toLowerCase();
      final psql = _requiredEnvironment('SKILLSGO_E2E_PSQL');
      final schemaResult = await Process.run(psql, [
        databaseDSN,
        '-v',
        'ON_ERROR_STOP=1',
        '-c',
        'CREATE SCHEMA $schema',
      ]);
      if (schemaResult.exitCode != 0) {
        throw StateError(
          'Create Journey schema failed: ${schemaResult.stderr}',
        );
      }

      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      hubOrigin = 'http://127.0.0.1:$port';
      final hubLog = File('${sandbox.path}/hub/hub.log');
      hubProcess = await Process.start(
        _requiredEnvironment('SKILLSGO_E2E_HUB_BINARY'),
        const [],
        environment: {
          ...Platform.environment,
          'HOME': '${sandbox.path}/hub/home',
          'TMPDIR': '${sandbox.path}/tmp',
          'SKILLSGO_HUB_PORT': '127.0.0.1:$port',
          'SKILLSGO_HUB_CACHE_DIR': '${sandbox.path}/hub/cache',
          'SKILLSGO_HUB_DATABASE_TYPE': 'postgres',
          'SKILLSGO_HUB_DATABASE_DSN': databaseDSN,
          'SKILLSGO_HUB_DATABASE_SCHEMA': schema,
          'SKILLSGO_HUB_STORAGE_TYPE': 'disk',
          'SKILLSGO_HUB_DISK_STORAGE_ROOT': '${sandbox.path}/hub/storage',
          'SKILLSGO_HUB_LOG_LEVEL': 'info',
        },
      );
      final stdoutLog = hubLog.openWrite();
      final stderrLog = hubLog.openWrite(mode: FileMode.append);
      hubLogSinks.addAll([stdoutLog, stderrLog]);
      hubProcess.stdout.transform(utf8.decoder).listen(stdoutLog.write);
      hubProcess.stderr.transform(utf8.decoder).listen(stderrLog.write);
      await _waitForHub(hubOrigin, hubProcess, hubLog);
    }

    final childEnvironment = <String, String>{
      ...Platform.environment,
      'HOME': '${sandbox.path}/home',
      'CFFIXED_USER_HOME': '${sandbox.path}/home',
      'TMPDIR': '${sandbox.path}/tmp',
      'XDG_CONFIG_HOME': '${sandbox.path}/home/.config',
      'XDG_CACHE_HOME': '${sandbox.path}/home/.cache',
      'XDG_DATA_HOME': '${sandbox.path}/home/.local/share',
      'SKILLSGO_HOME': '${sandbox.path}/home/.skillsgo',
      'SKILLSGO_TEST_AGENT_HOME': '${sandbox.path}/test-agent',
      'SKILLSGO_HUB_URL': hubOrigin,
    };
    final gateway = RealSkillsGateway(
      processRunner: IoProcessRunner(
        workingDirectory: '${sandbox.path}/project',
        environment: childEnvironment,
      ),
      hubBaseUrl: hubOrigin,
    );
    await gateway.saveLanguage(AppLanguage.english);
    return JourneyRuntime._(
      name: name,
      sandbox: sandbox,
      hubOrigin: hubOrigin,
      gateway: gateway,
      hubProcess: hubProcess,
      hubLogSinks: hubLogSinks,
    );
  }

  Future<void> close() async {
    final process = _hubProcess;
    if (process != null) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill();
        await process.exitCode;
      }
    }
    for (final sink in _hubLogSinks) {
      await sink.close();
    }
  }

  static String _requiredEnvironment(String name) {
    final value = Platform.environment[name];
    if (value == null || value.isEmpty) {
      throw StateError('$name is required for App E2E.');
    }
    return value;
  }

  static Future<void> _waitForHub(
    String origin,
    Process process,
    File log,
  ) async {
    final client = HttpClient();
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        try {
          final request = await client.getUrl(Uri.parse('$origin/readyz'));
          final response = await request.close();
          await response.drain<void>();
          if (response.statusCode == HttpStatus.ok) return;
        } on SocketException {
          // Hub startup is asynchronous.
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      client.close(force: true);
    }
    process.kill();
    throw StateError(
      'Journey Hub did not become ready.\n${log.existsSync() ? log.readAsStringSync() : ''}',
    );
  }
}
