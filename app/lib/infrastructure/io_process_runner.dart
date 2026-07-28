/*
 * [INPUT]: Depends on Dart process, stream, UTF-8, timeout, working-directory, and child-environment primitives plus the App process contract and App-wide structured logger.
 * [OUTPUT]: Provides the production ProcessRunner adapter with structured arguments, optional stdin, streamed stdout, bounded execution, process-scope isolation, and self-identifying sanitized CLI completion telemetry including bounded readable request/response previews.
 * [POS]: Serves as the local operating-system process adapter used by the CLI machine-protocol module and as the process event source for App diagnostics.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/skills_gateway.dart';
import 'logging/app_logger.dart';

class IoProcessRunner implements ProcessRunner {
  const IoProcessRunner({this.workingDirectory, this.environment});

  final String? workingDirectory;
  final Map<String, String>? environment;

  static const commandTimeout = Duration(minutes: 2);

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
