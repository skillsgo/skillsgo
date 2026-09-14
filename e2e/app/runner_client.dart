/*
 * [INPUT]: Depends on a Runner control-file path, its versioned loopback endpoint and token, and requested Journey names, ping, or shutdown intent.
 * [OUTPUT]: Reads the App PID or sends one bounded authenticated NDJSON command to the persistent App E2E Runner, prints its result, and exits nonzero for unavailable, stalled, or failed runs.
 * [POS]: Serves as the cross-platform command adapter used by run.sh without exposing socket details to callers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

const _schemaVersion = 1;
const _requestTimeout = Duration(minutes: 8);

Future<void> main(List<String> arguments) async {
  if (arguments.length < 2) {
    stderr.writeln(
      'usage: dart runner_client.dart CONTROL_FILE JOURNEY... | --pid | --ping | --shutdown',
    );
    exitCode = 64;
    return;
  }
  final controlFile = File(arguments.first);
  if (!await controlFile.exists()) {
    stderr.writeln('Persistent App E2E Runner is not ready.');
    exitCode = 75;
    return;
  }
  try {
    final control = jsonDecode(await controlFile.readAsString());
    if (control is! Map<String, dynamic> ||
        control['schemaVersion'] != _schemaVersion ||
        control['port'] is! int ||
        control['token'] is! String ||
        control['pid'] is! int) {
      throw const FormatException('Invalid E2E Runner control file.');
    }
    if (arguments.length == 2 && arguments[1] == '--pid') {
      stdout.writeln(control['pid']);
      return;
    }
    final shutdown = arguments.length == 2 && arguments[1] == '--shutdown';
    final ping = arguments.length == 2 && arguments[1] == '--ping';
    final journeys = shutdown || ping
        ? const <String>[]
        : arguments.skip(1).toList();
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      control['port'] as int,
      timeout: const Duration(seconds: 2),
    );
    final line = await (() async {
      socket.writeln(
        jsonEncode({
          'schemaVersion': _schemaVersion,
          'token': control['token'],
          'journeys': journeys,
          if (ping) 'ping': true,
          if (shutdown) 'shutdown': true,
        }),
      );
      await socket.flush();
      return utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first;
    })().timeout(_requestTimeout);
    await socket.close();
    final response = jsonDecode(line);
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(response));
    if (response is! Map<String, dynamic> || response['ok'] != true) {
      exitCode = 1;
    }
  } on Object catch (error) {
    stderr.writeln('Persistent App E2E Runner request failed: $error');
    exitCode = 75;
  }
}
