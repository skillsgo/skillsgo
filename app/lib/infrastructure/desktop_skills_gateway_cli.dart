/*
 * [INPUT]: Depends on the shared gateway state, ProcessRunner, startup handshake schema, and typed CLI failures.
 * [OUTPUT]: Provides coalesced non-destructive CLI compatibility detection, developer override persistence, required-path resolution, coalesced CLI Server startup, structured command execution, safe-read transport recovery, and dead-session replacement.
 * [POS]: Serves as the CLI lifecycle capability inside the DesktopSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'desktop_skills_gateway.dart';

mixin _DesktopSkillsGatewayCli on _DesktopSkillsGatewayCore {
  @override
  Future<CliStatus> detectCli({String? customPath}) {
    final current = _cliDetection;
    if (customPath != null && current != null) {
      return current.then((_) => _detectCli(customPath: customPath));
    }
    if (current != null) return current;
    final detection = _detectCli(customPath: customPath);
    _cliDetection = detection;
    return detection.whenComplete(() {
      if (identical(_cliDetection, detection)) _cliDetection = null;
    });
  }

  Future<CliStatus> _detectCli({String? customPath}) async {
    final previouslyResolvedPath = _cliPath;
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
        await _activateCliPath(candidate);
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
    bool retryOnTransportFailure = false,
  }) async {
    if (_cliPath == null) {
      final status = await _detectCliOnce();
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
    for (var attempt = 0; ; attempt++) {
      final session = await _requireCliServer(executable);
      _activeCliRequests++;
      late final ProcessOutput output;
      try {
        output = await session.run(
          arguments,
          stdin: stdin,
          onStdoutLine: onStdoutLine,
        );
      } finally {
        _activeCliRequests--;
        if (_activeCliRequests == 0) {
          _cliRequestsDrained?.complete();
          _cliRequestsDrained = null;
        }
      }
      final transportFailure = _isCliTransportFailure(output);
      if (session.isClosed || transportFailure) {
        if (identical(_cliServerSession, session)) {
          _cliServerSession = null;
          _cliServerStart = null;
        }
        if (transportFailure && !session.isClosed) await session.close();
      }
      if (!retryOnTransportFailure || !transportFailure || attempt > 0) {
        return CommandResult(
          command: [executable, ...arguments],
          output: output,
        );
      }
    }
  }

  Future<CliStatus> _detectCliOnce() => detectCli();

  bool _isCliTransportFailure(ProcessOutput output) => output.transportFailure;

  Future<CliServerSession> _requireCliServer(String executable) async {
    final current = _cliServerSession;
    if (current != null && !current.isClosed) return current;
    final starting = _cliServerStart;
    if (starting != null) return starting;
    final future = _runner.startCliServer(executable);
    _cliServerStart = future;
    try {
      final session = await future;
      _cliServerSession = session;
      return session;
    } finally {
      _cliServerStart = null;
    }
  }

  Future<void> _closeCliServer() async {
    if (_activeCliRequests > 0) {
      await (_cliRequestsDrained ??= Completer<void>()).future;
    }
    final current = _cliServerSession;
    _cliServerSession = null;
    _cliServerStart = null;
    await current?.close();
  }

  Future<void> _activateCliPath(String path) async {
    if (_cliPath != null && _cliPath != path) await _closeCliServer();
    _cliPath = path;
  }
}
