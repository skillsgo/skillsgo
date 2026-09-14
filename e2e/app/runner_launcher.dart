/*
 * [INPUT]: Depends on a host-script path, log/PID files, and the persistent Runner environment supplied by run.sh.
 * [OUTPUT]: Starts the Runner host in an OS-detached process and records its PID without retaining the caller's terminal or stdio.
 * [POS]: Serves as the cross-platform daemonization boundary for the local App E2E Runner.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 7) {
    stderr.writeln(
      'usage: dart runner_launcher.dart HOST LOG PID TOKEN WORKSPACE REPOSITORY SCRIPT',
    );
    exitCode = 64;
    return;
  }
  final [host, log, pidFile, token, workspace, repository, script] = arguments;
  final environment = {
    ...Platform.environment,
    'SKILLSGO_E2E_RUNNER_HOST': '1',
    'SKILLSGO_E2E_CONTROL_TOKEN': token,
    'SKILLSGO_E2E_WORKSPACE_DIR': workspace,
    'SKILLSGO_E2E_REPOSITORY_ROOT': repository,
    'SKILLSGO_E2E_SCRIPT_PATH': script,
    'SKILLSGO_E2E_RUNNER_LOG': log,
  };
  if (Platform.isWindows) {
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r"$process = Start-Process -FilePath 'bash.exe' -ArgumentList @('" +
          _powerShellLiteral(host) +
          r"') -PassThru; Set-Content -LiteralPath '" +
          _powerShellLiteral(pidFile) +
          r"' -Value $process.Id",
    ], environment: environment);
    if (result.exitCode != 0) {
      stderr.write(result.stderr);
      exitCode = result.exitCode;
    }
    return;
  }
  final process = await Process.start(
    host,
    const [],
    environment: environment,
    mode: ProcessStartMode.detached,
  );
  await File(pidFile).writeAsString('${process.pid}\n', flush: true);
}

String _powerShellLiteral(String value) => value.replaceAll("'", "''");
