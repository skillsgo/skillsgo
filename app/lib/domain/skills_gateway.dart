/*
 * [INPUT]: Depends only on Dart core types and asynchronous result primitives.
 * [OUTPUT]: Defines the App's Skill, CLI, process, and operation contracts at the SkillsGateway seam.
 * [POS]: Serves as the domain boundary shared by UI journeys, production infrastructure, and contract fakes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

enum CliAvailability { ready, missing, incompatible }

enum CliIssue { missing, damaged, incompatible }

enum UpdateState { unknown, checking, upToDate, available, unsupported, failed }

class CliStatus {
  const CliStatus({
    required this.availability,
    this.path,
    this.version,
    this.message,
    this.issue,
  });

  final CliAvailability availability;
  final String? path;
  final String? version;
  final String? message;
  final CliIssue? issue;

  bool get isReady => availability == CliAvailability.ready;
}

class SkillSummary {
  const SkillSummary({
    required this.id,
    required this.skillId,
    required this.name,
    required this.source,
    required this.installs,
    this.latestVersion = 'main',
  });

  final String id;
  final String skillId;
  final String name;
  final String source;
  final int installs;
  final String latestVersion;
}

class SkillFile {
  const SkillFile({required this.path, required this.contents});

  final String path;
  final String contents;
}

class SkillDetail {
  const SkillDetail({
    required this.name,
    required this.source,
    required this.markdown,
    required this.files,
    this.installs = 0,
  });

  final String name;
  final String source;
  final String markdown;
  final List<SkillFile> files;
  final int installs;

  bool get hasExecutableContent => files.any((file) {
    final lower = file.path.toLowerCase();
    const extensions = [
      '.sh',
      '.bash',
      '.zsh',
      '.fish',
      '.ps1',
      '.bat',
      '.cmd',
      '.exe',
      '.js',
      '.mjs',
      '.py',
      '.rb',
    ];
    return extensions.any(lower.endsWith) || lower.contains('/scripts/');
  });
}

class InstalledSkill {
  const InstalledSkill({
    required this.name,
    required this.path,
    required this.agents,
  });

  final String name;
  final String path;
  final List<String> agents;

  bool get isLinkedToCodex =>
      agents.any((agent) => agent.toLowerCase() == 'codex');
}

class ProcessOutput {
  const ProcessOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract interface class ProcessRunner {
  Future<ProcessOutput> run(String executable, List<String> arguments);
}

class CommandResult {
  const CommandResult({required this.command, required this.output});

  final List<String> command;
  final ProcessOutput output;

  bool get succeeded => output.exitCode == 0;
}

class SkillsException implements Exception {
  const SkillsException(this.message, {this.isOffline = false});

  final String message;
  final bool isOffline;

  @override
  String toString() => message;
}

abstract interface class SkillsGateway {
  Future<CliStatus> detectCli({String? customPath});
  Future<void> saveCustomCliPath(String? path);
  Future<String?> loadCustomCliPath();
  Future<List<SkillSummary>> search(String query);
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill);
  Future<List<InstalledSkill>> listInstalled();
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill);
  Future<CommandResult> install(SkillSummary skill);
  Future<CommandResult> remove(InstalledSkill skill);
  Future<CommandResult> update(InstalledSkill skill);
  Future<Map<String, UpdateState>> checkUpdates(List<InstalledSkill> skills);
}
