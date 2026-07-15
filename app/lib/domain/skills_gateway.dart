/*
 * [INPUT]: Depends only on Dart core types and asynchronous result primitives.
 * [OUTPUT]: Defines App contracts for discovery collections, Skills, CLI, Registry settings, risk policy, storage health, and operations.
 * [POS]: Serves as the domain boundary shared by UI journeys, production infrastructure, and contract fakes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

enum CliAvailability { ready, missing, incompatible }

enum CliIssue { missing, damaged, incompatible }

enum UpdateState { unknown, checking, upToDate, available, unsupported, failed }

enum HealthState { ready, notInitialized, unreachable, invalid }

enum SkillsFailureKind { validation, server, timeout, offline, invalidResponse }

enum DiscoveryCollection { search, ranking, trending, hot }

enum SkillTrustLevel {
  unverified,
  communityVerified,
  publisherVerified,
  official,
  warned,
  delisted,
}

enum SkillRiskAssessment { unknown, low, medium, high, critical }

enum SkillMetricKind { allTimeInstalls, installs24h, hotVelocity }

enum RegistryIssue {
  invalidOrigin,
  httpFailure,
  invalidProtocol,
  invalidJson,
  connectionFailure,
  timeout,
}

class RegistryStatus {
  const RegistryStatus({
    required this.origin,
    required this.state,
    this.issue,
    this.httpStatus,
    this.diagnostic,
    this.version,
  });

  final String origin;
  final HealthState state;
  final RegistryIssue? issue;
  final int? httpStatus;
  final String? diagnostic;
  final String? version;

  bool get isReady => state == HealthState.ready;
}

class PersonalRiskPolicy {
  const PersonalRiskPolicy({
    this.confirmHighRisk = true,
    this.allowCriticalOverride = false,
  });

  final bool confirmHighRisk;
  final bool allowCriticalOverride;
}

class StorageStatus {
  const StorageStatus({required this.path, required this.state});

  final String path;
  final HealthState state;
}

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
    this.description = '',
    this.trustLevel = SkillTrustLevel.unverified,
    this.riskAssessment = SkillRiskAssessment.unknown,
    this.metricKind = SkillMetricKind.allTimeInstalls,
    this.metricChange = 0,
    this.localTargetCount = 0,
  });

  final String id;
  final String skillId;
  final String name;
  final String source;
  final int installs;
  final String latestVersion;
  final String description;
  final SkillTrustLevel trustLevel;
  final SkillRiskAssessment riskAssessment;
  final SkillMetricKind metricKind;
  final int metricChange;
  final int localTargetCount;

  bool get isInstalled => localTargetCount > 0;
}

class DiscoveryPage {
  const DiscoveryPage({required this.skills, this.nextOffset});

  final List<SkillSummary> skills;
  final int? nextOffset;
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
    required this.targetCount,
    this.coordinate = '',
  });

  final String name;
  final String path;
  final List<String> agents;
  final int targetCount;
  final String coordinate;

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
  const SkillsException(
    this.message, {
    this.kind = SkillsFailureKind.server,
    this.isOffline = false,
  });

  final String message;
  final SkillsFailureKind kind;
  final bool isOffline;

  @override
  String toString() => message;
}

abstract interface class SkillsGateway {
  Future<CliStatus> detectCli({String? customPath});
  Future<void> saveCustomCliPath(String? path);
  Future<String?> loadCustomCliPath();
  Future<String> loadRegistryOrigin();
  Future<void> saveRegistryOrigin(String origin);
  Future<void> resetRegistryOrigin();
  Future<RegistryStatus> testRegistryOrigin(String origin);
  Future<PersonalRiskPolicy> loadRiskPolicy();
  Future<void> saveRiskPolicy(PersonalRiskPolicy policy);
  Future<StorageStatus> inspectStorage();
  Future<String> loadAppVersion();
  Future<DiscoveryPage> discover(
    DiscoveryCollection collection, {
    String query = '',
    int offset = 0,
    int limit = 20,
  });
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill);
  Future<List<InstalledSkill>> listInstalled();
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill);
  Future<CommandResult> install(SkillSummary skill);
  Future<CommandResult> remove(InstalledSkill skill);
  Future<CommandResult> update(InstalledSkill skill);
  Future<Map<String, UpdateState>> checkUpdates(List<InstalledSkill> skills);
}
