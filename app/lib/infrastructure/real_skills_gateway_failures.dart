/*
 * [INPUT]: Depends on structured command results and the versioned CLI machine-error schema.
 * [OUTPUT]: Provides exit-code fallback translation and typed machine-failure decoding.
 * [POS]: Serves as the failure translation capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayFailures on _RealSkillsGatewayCore {
  @override
  SkillsException _commandFailure(CommandResult result) {
    final machineFailure = _parseMachineFailure(result.output.stdout);
    if (machineFailure != null) return machineFailure;
    final stderr = result.output.stderr.trim();
    final message = stderr.isEmpty
        ? 'SkillsGo CLI exited with code ${result.output.exitCode}.'
        : stderr;
    return switch (result.output.exitCode) {
      69 => SkillsException(
        message,
        kind: SkillsFailureKind.offline,
        isOffline: true,
      ),
      75 => SkillsException(message, kind: SkillsFailureKind.timeout),
      _ => SkillsException(message),
    };
  }

  SkillsException? _parseMachineFailure(String stdout) {
    if (stdout.trim().isEmpty) return null;
    try {
      Object? decoded;
      try {
        decoded = jsonDecode(stdout);
      } on FormatException {
        final lines = const LineSplitter()
            .convert(stdout)
            .where((line) => line.trim().isNotEmpty)
            .toList(growable: false);
        if (lines.isEmpty) rethrow;
        decoded = jsonDecode(lines.last);
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['phase'] != 'error' ||
          decoded['error'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final raw = decoded['error'] as Map<String, dynamic>;
      if (raw['code'] is! String ||
          (raw['code'] as String).isEmpty ||
          raw['retryable'] is! bool ||
          (raw['details'] != null && raw['details'] is! Map<String, dynamic>) ||
          (raw['requestId'] != null && raw['requestId'] is! String) ||
          (raw['diagnostic'] != null && raw['diagnostic'] is! String)) {
        throw const FormatException();
      }
      final code = raw['code'] as String;
      final kind = switch (code) {
        'input.invalid' => SkillsFailureKind.validation,
        'hub.unavailable' => SkillsFailureKind.offline,
        'hub.timeout' => SkillsFailureKind.timeout,
        'hub.rate_limited' || 'hub.server_error' => SkillsFailureKind.server,
        'protocol.invalid_response' => SkillsFailureKind.invalidResponse,
        'protocol.incompatible' ||
        'local.data_invalid' => SkillsFailureKind.invalidLocalData,
        _ => SkillsFailureKind.server,
      };
      return SkillsException(
        code,
        kind: kind,
        isOffline: code == 'hub.unavailable',
        code: code,
        retryable: raw['retryable'] as bool,
        details: Map<String, Object?>.unmodifiable(
          (raw['details'] as Map<String, dynamic>?) ?? const {},
        ),
        requestId: raw['requestId'] as String? ?? '',
        diagnostic: raw['diagnostic'] as String? ?? '',
      );
    } on FormatException {
      return const SkillsException(
        'protocol.incompatible',
        kind: SkillsFailureKind.invalidLocalData,
        code: 'protocol.incompatible',
      );
    }
  }
}
