/*
 * [INPUT]: Uses Dart line decoding and the App process contract.
 * [OUTPUT]: Specifies a deterministic queued ProcessRunner adapter with recorded executable, structured arguments, and per-call stdin documents.
 * [POS]: Serves as the shared process test adapter for SkillsGateway contract suites.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';

import 'package:skillsgo/domain/skills_gateway.dart';

class FakeProcessRunner implements ProcessRunner {
  ProcessOutput result = const ProcessOutput(
    exitCode: 0,
    stdout: '',
    stderr: '',
  );
  List<String>? lastArguments;
  String? lastExecutable;
  String? lastStdin;
  final calls = <({String executable, List<String> arguments})>[];
  final stdins = <String?>[];
  final responses = <ProcessOutput>[];

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  }) async {
    lastExecutable = executable;
    lastArguments = arguments;
    lastStdin = stdin;
    calls.add((executable: executable, arguments: List.of(arguments)));
    stdins.add(stdin);
    final response = responses.isNotEmpty ? responses.removeAt(0) : result;
    if (onStdoutLine != null) {
      for (final line in const LineSplitter().convert(response.stdout)) {
        onStdoutLine(line);
      }
    }
    return response;
  }
}
