/*
 * [INPUT]: Depends on Dart process, stream, UTF-8, timeout, working-directory, and child-environment primitives plus the App process contract and App-wide structured logger.
 * [OUTPUT]: Provides one-shot startup probes plus a correlated long-lived CLI Server session with stdin, streamed stdout, bounded execution, synchronous dead-session marking, crash fan-out, and sanitized telemetry.
 * [POS]: Serves as the operating-system process and NDJSON session adapter beneath the App's CLI lifecycle capability.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/skills_gateway.dart';
import 'logging/app_logger.dart';

class IoProcessRunner implements ProcessRunner, CliServerRunner {
  const IoProcessRunner({this.workingDirectory, this.environment});

  final String? workingDirectory;
  final Map<String, String>? environment;

  static const commandTimeout = Duration(minutes: 2);

  @override
  Future<CliServerSession> startCliServer(String executable) async {
    final process = await Process.start(
      executable,
      const ['server', '--stdio'],
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return _IoCliServerSession(process, executable);
  }

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) async {
    final invocationId = appLogger.nextId('invocation');
    final stopwatch = Stopwatch()..start();
    final executableName = executable.split(Platform.pathSeparator).last;
    final sanitizedArguments = appLogger.sanitizeCliArguments(arguments);
    appLogger.info('gateway.cli', 'invocation_started', {
      'invocationId': invocationId,
      'executable': executableName,
      'arguments': sanitizedArguments,
      'hasStdin': stdin != null,
      if (stdin != null) 'stdinBytes': utf8.encode(stdin).length,
      if (stdin != null) 'requestPreview': appLogger.humanPreview(stdin),
      'streaming': onStdoutLine != null,
    });
    try {
      if (onStdoutLine != null) {
        final process = await Process.start(
          executable,
          arguments,
          workingDirectory: workingDirectory,
          environment: environment,
        );
        if (stdin != null) process.stdin.write(stdin);
        await process.stdin.close();
        final stdout = StringBuffer();
        final stdoutDone = Completer<void>();
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (stdout.isNotEmpty) stdout.writeln();
                stdout.write(line);
                onStdoutLine(line);
              },
              onError: stdoutDone.completeError,
              onDone: stdoutDone.complete,
              cancelOnError: true,
            );
        final stderrFuture = process.stderr.transform(utf8.decoder).join();
        var timedOut = false;
        late int exitCode;
        try {
          exitCode = await process.exitCode.timeout(commandTimeout);
        } on TimeoutException {
          timedOut = true;
          process.kill();
          exitCode = await process.exitCode;
        }
        await stdoutDone.future;
        final stderr = await stderrFuture;
        final output = ProcessOutput(
          exitCode: timedOut ? 124 : exitCode,
          stdout: stdout.toString(),
          stderr: timedOut ? 'Command timed out.' : stderr,
        );
        _logCompletion(
          invocationId,
          executableName,
          sanitizedArguments,
          stopwatch,
          output,
          timedOut: timedOut,
        );
        return output;
      }
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
      );
      if (stdin != null) process.stdin.write(stdin);
      await process.stdin.close();
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      var timedOut = false;
      late int exitCode;
      try {
        exitCode = await process.exitCode.timeout(commandTimeout);
      } on TimeoutException {
        timedOut = true;
        process.kill();
        exitCode = await process.exitCode;
      }
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      final output = ProcessOutput(
        exitCode: timedOut ? 124 : exitCode,
        stdout: stdout,
        stderr: timedOut ? 'Command timed out.' : stderr,
      );
      _logCompletion(
        invocationId,
        executableName,
        sanitizedArguments,
        stopwatch,
        output,
        timedOut: timedOut,
      );
      return output;
    } on ProcessException catch (error) {
      final output = ProcessOutput(
        exitCode: 127,
        stdout: '',
        stderr: error.message,
      );
      _logCompletion(
        invocationId,
        executableName,
        sanitizedArguments,
        stopwatch,
        output,
        processError: true,
      );
      return output;
    }
  }

  static void _logCompletion(
    String invocationId,
    String executable,
    List<String> arguments,
    Stopwatch stopwatch,
    ProcessOutput output, {
    bool timedOut = false,
    bool processError = false,
  }) {
    final data = <String, Object?>{
      'invocationId': invocationId,
      'executable': executable,
      'arguments': arguments,
      'exitCode': output.exitCode,
      'durationMs': stopwatch.elapsedMilliseconds,
      'stdoutBytes': utf8.encode(output.stdout).length,
      'stderrBytes': utf8.encode(output.stderr).length,
      'timedOut': timedOut,
      'processError': processError,
      if (output.exitCode != 0)
        'diagnostic': AppLogger.truncate(
          appLogger.sanitizeString(output.stderr),
          16 * 1024,
        ),
      if (output.stdout.trim().isNotEmpty)
        'responsePreview': appLogger.humanPreview(output.stdout),
    };
    if (output.exitCode == 0) {
      appLogger.info('gateway.cli', 'invocation_finished', data);
    } else {
      appLogger.warning('gateway.cli', 'invocation_failed', data);
    }
  }
}

final class _IoCliServerSession implements CliServerSession {
  _IoCliServerSession(this._process, this._executable) {
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_receive, onError: _fail, onDone: _closed);
    _process.stderr.transform(utf8.decoder).listen(_serverStderr.write);
    unawaited(_process.exitCode.then((_) => _closed()));
  }

  final Process _process;
  final String _executable;
  final _pending = <String, _PendingCliServerRequest>{};
  final _serverStderr = StringBuffer();
  var _nextID = 0;
  var _isClosed = false;

  @override
  bool get isClosed => _isClosed;

  @override
  Future<ProcessOutput> run(
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) async {
    if (_isClosed) return _transportFailure('CLI Server is closed.');
    final invocationId = appLogger.nextId('invocation');
    final stopwatch = Stopwatch()..start();
    final sanitizedArguments = appLogger.sanitizeCliArguments(arguments);
    appLogger.info('gateway.cli', 'server_invocation_started', {
      'invocationId': invocationId,
      'executable': _executable.split(Platform.pathSeparator).last,
      'arguments': sanitizedArguments,
      'hasStdin': stdin != null,
      if (stdin != null) 'stdinBytes': utf8.encode(stdin).length,
      'streaming': onStdoutLine != null,
    });
    final id = '${++_nextID}';
    final request = _PendingCliServerRequest(onStdoutLine);
    _pending[id] = request;
    try {
      _process.stdin.writeln(
        jsonEncode({
          'schemaVersion': 1,
          'id': id,
          'arguments': arguments,
          'stdin': ?stdin,
          if (onStdoutLine != null) 'streamStdout': true,
        }),
      );
      await _process.stdin.flush();
    } on Object catch (error) {
      _pending.remove(id);
      final output = _transportFailure('Cannot write to CLI Server: $error');
      _abort(output);
      return output;
    }
    late ProcessOutput output;
    try {
      output = await request.result.future.timeout(
        IoProcessRunner.commandTimeout,
      );
    } on TimeoutException {
      _pending.remove(id);
      output = const ProcessOutput(
        exitCode: 124,
        stdout: '',
        stderr: 'Command timed out.',
      );
      _abort(output);
    }
    IoProcessRunner._logCompletion(
      invocationId,
      _executable.split(Platform.pathSeparator).last,
      sanitizedArguments,
      stopwatch,
      output,
      timedOut: output.exitCode == 124,
      processError: output.exitCode == 127,
    );
    return output;
  }

  void _receive(String line) {
    try {
      final document = jsonDecode(line);
      if (document is! Map<String, dynamic> ||
          document['schemaVersion'] != 1 ||
          document['id'] is! String) {
        throw const FormatException('Invalid CLI Server response.');
      }
      final id = document['id'] as String;
      final request = _pending[id];
      if (document['type'] == 'stdout') {
        if (document['line'] is! String) {
          throw const FormatException('Invalid CLI Server stdout event.');
        }
        request?.onStdoutLine?.call(document['line'] as String);
        return;
      }
      if (document['type'] != 'result' ||
          document['exitCode'] is! int ||
          document['stdout'] is! String ||
          document['stderr'] is! String) {
        throw const FormatException('Invalid CLI Server response.');
      }
      final completed = _pending.remove(id);
      if (completed == null) return;
      completed.result.complete(
        ProcessOutput(
          exitCode: document['exitCode'] as int,
          stdout: document['stdout'] as String,
          stderr: document['stderr'] as String,
        ),
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    _abort(_transportFailure('Invalid CLI Server stream: $error'));
  }

  void _abort(ProcessOutput output) {
    if (_isClosed) return;
    _isClosed = true;
    _finishPending(output);
    _process.kill();
  }

  void _closed() {
    if (_isClosed) return;
    _isClosed = true;
    final diagnostic = _serverStderr.toString().trim();
    _finishPending(
      _transportFailure(
        diagnostic.isEmpty
            ? 'CLI Server exited.'
            : 'CLI Server exited: $diagnostic',
      ),
    );
  }

  void _finishPending(ProcessOutput output) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final request in pending) {
      if (!request.result.isCompleted) request.result.complete(output);
    }
  }

  ProcessOutput _transportFailure(String message) => ProcessOutput(
    exitCode: 127,
    stdout: '',
    stderr: '$_executable: $message',
  );

  @override
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    await _process.stdin.close();
    _process.kill();
    _finishPending(_transportFailure('CLI Server was closed.'));
  }
}

final class _PendingCliServerRequest {
  _PendingCliServerRequest(this.onStdoutLine);

  final void Function(String line)? onStdoutLine;
  final result = Completer<ProcessOutput>();
}
