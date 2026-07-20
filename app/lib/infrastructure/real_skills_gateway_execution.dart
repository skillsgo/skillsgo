/*
 * [INPUT]: Depends on shared RealSkillsGateway CLI execution, target identity, JSON decoding, and NDJSON progress callbacks.
 * [OUTPUT]: Provides internal affected-binding integrity validation and the ordered NDJSON progress/final-payload execution envelope shared by target mutations.
 * [POS]: Serves as the private protocol-execution seam reused by Update and Target Management capabilities without exposing transport mechanics through SkillsGateway.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayExecutionSupport on _RealSkillsGatewayCore {
  void _validateAffectedBindings<T>(
    Iterable<T> items, {
    required InstallationPlanTarget Function(T item) targetOf,
    required Iterable<InstallationPlanTarget> Function(T item)
    affectedBindingsOf,
  }) {
    final targetKeys = items.map(targetOf).map(updateTargetKey).toSet();
    for (final item in items) {
      final target = targetOf(item);
      final bindings = affectedBindingsOf(item).toList(growable: false);
      if (bindings.isNotEmpty &&
          (!bindings.any(
                (binding) =>
                    updateTargetKey(binding) == updateTargetKey(target),
              ) ||
              bindings.any(
                (binding) => !targetKeys.contains(updateTargetKey(binding)),
              ))) {
        throw const FormatException();
      }
    }
  }

  Future<Map<String, dynamic>> _runNdjsonExecution(
    List<String> arguments, {
    required String progressPhase,
    required String executionPhase,
    required void Function(Map<String, dynamic> payload) consumeProgress,
    required bool Function() canFinalize,
  }) async {
    Map<String, dynamic>? finalPayload;
    Object? streamFailure;
    var sawLine = false;

    void consume(String line) {
      sawLine = true;
      if (streamFailure != null) return;
      try {
        final raw = jsonDecode(line);
        if (raw is! Map<String, dynamic> || raw['schemaVersion'] != 1) {
          throw const FormatException();
        }
        final phase = raw['phase'];
        if (phase == progressPhase) {
          consumeProgress(raw);
        } else if (phase == executionPhase) {
          if (finalPayload != null || !canFinalize()) {
            throw const FormatException();
          }
          finalPayload = raw;
        } else {
          throw const FormatException();
        }
      } catch (error) {
        streamFailure = error;
      }
    }

    final command = await _runCli(arguments, onStdoutLine: consume);
    if (!sawLine) {
      for (final line in const LineSplitter().convert(command.output.stdout)) {
        consume(line);
      }
    }
    if (!command.succeeded && finalPayload == null) {
      throw _commandFailure(command);
    }
    if (streamFailure != null || finalPayload == null) {
      throw const FormatException();
    }
    return finalPayload!;
  }
}
