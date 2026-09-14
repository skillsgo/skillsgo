/*
 * [INPUT]: Depends on the Flutter integration-test binding, loopback TCP sockets, a suite-owned authenticated control file, and the four reusable App Journey functions.
 * [OUTPUT]: Provides one long-lived debug-only E2E Runner that executes requested Journey names sequentially inside a single built App process and returns versioned NDJSON results.
 * [POS]: Serves as the persistent local App E2E execution module behind e2e/app/run.sh; release builds never import it.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'adoption_management_test.dart' as adoption;
import 'machine_failure_recovery_test.dart' as machine_failure;
import 'package_update_check_test.dart' as package_update;
import 'repository_install_all_test.dart' as repository_install;

const _schemaVersion = 1;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('persistent App E2E Runner', (tester) async {
    final controlPath = _requiredEnvironment('SKILLSGO_E2E_CONTROL_FILE');
    final token = _requiredEnvironment('SKILLSGO_E2E_CONTROL_TOKEN');
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final control = File(controlPath);
    await control.parent.create(recursive: true);
    await control.writeAsString(
      jsonEncode({
        'schemaVersion': _schemaVersion,
        'port': server.port,
        'token': token,
        'pid': pid,
      }),
      flush: true,
    );
    try {
      await for (final socket in server) {
        final shouldStop = await _serve(socket, tester, token);
        if (shouldStop) break;
      }
    } finally {
      await server.close();
      if (await control.exists()) await control.delete();
    }
  }, timeout: Timeout.none);
}

Future<bool> _serve(Socket socket, WidgetTester tester, String token) async {
  try {
    final line = await utf8.decoder
        .bind(socket)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 10));
    final raw = jsonDecode(line);
    if (raw is! Map<String, dynamic> ||
        raw['schemaVersion'] != _schemaVersion ||
        raw['token'] != token ||
        raw['journeys'] is! List) {
      throw const FormatException('Invalid E2E Runner command.');
    }
    final journeys = (raw['journeys'] as List).cast<String>();
    if (raw['ping'] == true) {
      _write(socket, {'ok': true, 'ping': true, 'results': const []});
      return false;
    }
    if (raw['shutdown'] == true) {
      _write(socket, {'ok': true, 'shutdown': true, 'results': const []});
      return true;
    }
    final results = <Map<String, Object?>>[];
    for (final journey in journeys) {
      final stopwatch = Stopwatch()..start();
      try {
        await _runJourney(journey, tester);
        results.add({
          'name': journey,
          'ok': true,
          'durationMs': stopwatch.elapsedMilliseconds,
        });
      } on Object catch (error, stackTrace) {
        results.add({
          'name': journey,
          'ok': false,
          'durationMs': stopwatch.elapsedMilliseconds,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        });
        _write(socket, {'ok': false, 'results': results});
        return false;
      }
    }
    _write(socket, {'ok': true, 'results': results});
    return false;
  } on Object catch (error, stackTrace) {
    _write(socket, {
      'ok': false,
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
      'results': const [],
    });
    return false;
  } finally {
    await socket.flush();
    await socket.close();
  }
}

Future<void> _runJourney(String name, WidgetTester tester) => switch (name) {
  'repository_install_all' => repository_install.runRepositoryInstallAllJourney(
    tester,
  ),
  'package_update_preview' => package_update.runPackageUpdatePreviewJourney(
    tester,
  ),
  'adoption_management' => adoption.runAdoptionManagementJourney(tester),
  'machine_failure_recovery' =>
    machine_failure.runMachineFailureRecoveryJourney(tester),
  _ => Future<void>.error(ArgumentError.value(name, 'name', 'Unknown Journey')),
};

void _write(Socket socket, Map<String, Object?> document) {
  socket.writeln(jsonEncode({'schemaVersion': _schemaVersion, ...document}));
}

String _requiredEnvironment(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    throw StateError('$name is required for the persistent E2E Runner.');
  }
  return value;
}
