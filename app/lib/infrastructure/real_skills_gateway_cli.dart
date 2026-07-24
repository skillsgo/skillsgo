/*
 * [INPUT]: Depends on the shared gateway state, ProcessRunner, startup handshake schema, and typed CLI failures.
 * [OUTPUT]: Provides CLI detection, developer override persistence, required-path resolution, and structured command execution.
 * [POS]: Serves as the CLI lifecycle capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayCli on _RealSkillsGatewayCore {
  @override
  Future<CliStatus> detectCli({String? customPath}) async {
    final previouslyResolvedPath = _cliPath;
    _cliPath = null;
    final saved = allowDeveloperCliOverride
        ? customPath ?? await loadCustomCliPath()
        : null;
    final candidates = <String>{
      if (saved != null && saved.trim().isNotEmpty) saved.trim(),
      if (allowDeveloperCliOverride) ...[
        ?previouslyResolvedPath,
        ?Platform.environment['SKILLSGO_CLI_PATH'],
      ],
      _bundledCliPath,
    };

    for (final candidate in candidates) {
      if (candidate.trim().isEmpty) continue;
      final versionResult = await _runner.run(candidate, const [
        'version',
        '--output',
        'json',
      ]);
      if (versionResult.exitCode != 0) continue;
      try {
        final decoded = jsonDecode(versionResult.stdout);
        if (decoded is! Map<String, dynamic> ||
            decoded['schemaVersion'] != _startupHandshakeSchemaVersion ||
            decoded['product'] != 'skillsgo' ||
            decoded['appProtocolVersion'] is! int ||
            decoded['version'] is! String ||
            (decoded['version'] as String).trim().isEmpty ||
            decoded['os'] is! String ||
            (decoded['os'] as String).trim().isEmpty ||
            decoded['architecture'] is! String ||
            (decoded['architecture'] as String).trim().isEmpty) {
          throw const FormatException('Invalid SkillsGo startup handshake.');
        }
        final version = decoded['version'] as String;
        if (decoded['appProtocolVersion'] != _appProtocolVersion) {
          return CliStatus(
            availability: CliAvailability.incompatible,
            path: candidate,
            version: version,
            message: 'The SkillsGo CLI App protocol is incompatible.',
            issue: CliIssue.incompatible,
          );
        }
        if (decoded['os'] != _expectedCliOS) {
          return CliStatus(
            availability: CliAvailability.incompatible,
            path: candidate,
            version: version,
            message: 'The SkillsGo CLI was built for another platform.',
            issue: CliIssue.incompatible,
          );
        }
        _cliPath = candidate;
        return CliStatus(
          availability: CliAvailability.ready,
          path: candidate,
          version: version,
        );
      } on FormatException {
        return CliStatus(
          availability: CliAvailability.incompatible,
          path: candidate,
          message: 'The SkillsGo CLI startup handshake is invalid.',
          issue: CliIssue.damaged,
        );
      }
    }
    _cliPath = null;
    return const CliStatus(
      availability: CliAvailability.missing,
      message: 'The bundled SkillsGo CLI is missing or cannot run.',
      issue: CliIssue.missing,
    );
  }

  @override
  Future<String?> loadCustomCliPath() async =>
      (await SharedPreferences.getInstance()).getString(_customCliKey);

  @override
  Future<void> saveCustomCliPath(String? path) async {
    final preferences = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await preferences.remove(_customCliKey);
    } else {
      await preferences.setString(_customCliKey, path.trim());
    }
  }

  String get _requiredCli {
    final path = _cliPath;
    if (path == null) {
      throw const SkillsException(
        'The SkillsGo CLI is not ready. Open Settings.',
      );
    }
    return path;
  }

  @override
  Future<CommandResult> _runCli(
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) async {
    if (_cliPath == null) {
      final status = await detectCli();
      if (!status.isReady) {
        throw SkillsException(
          status.message ?? 'The SkillsGo CLI is not ready. Open Settings.',
          kind: status.issue == CliIssue.damaged
              ? SkillsFailureKind.invalidLocalData
              : SkillsFailureKind.server,
        );
      }
    }
    final executable = _requiredCli;
    final output = await _runner.run(
      executable,
      arguments,
      stdin: stdin,
      onStdoutLine: onStdoutLine,
    );
    return CommandResult(command: [executable, ...arguments], output: output);
  }
}
