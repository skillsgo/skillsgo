/*
 * [INPUT]: Depends on Dart process, stream, UTF-8, and timeout primitives plus the App process contract.
 * [OUTPUT]: Provides the production ProcessRunner adapter with structured arguments, streamed stdout, bounded execution, and typed output.
 * [POS]: Serves as the local operating-system process adapter used by the CLI machine-protocol module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/skills_gateway.dart';

class IoProcessRunner implements ProcessRunner {
  const IoProcessRunner();

  static const commandTimeout = Duration(minutes: 2);

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    try {
      if (onStdoutLine != null) {
        final process = await Process.start(executable, arguments);
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
        return ProcessOutput(
          exitCode: timedOut ? 124 : exitCode,
          stdout: stdout.toString(),
          stderr: timedOut ? 'Command timed out.' : stderr,
        );
      }
      final process = await Process.start(executable, arguments);
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
      return ProcessOutput(
        exitCode: timedOut ? 124 : exitCode,
        stdout: stdout,
        stderr: timedOut ? 'Command timed out.' : stderr,
      );
    } on ProcessException catch (error) {
      return ProcessOutput(exitCode: 127, stdout: '', stderr: error.message);
    }
  }
}
