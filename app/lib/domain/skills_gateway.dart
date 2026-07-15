/*
 * [INPUT]: Depends only on Dart core types and asynchronous result primitives.
 * [OUTPUT]: Defines App contracts for discovery, auditable artifacts, Agent inspection, local targets, CLI, Registry settings, risk policy, storage health, and operations.
 * [POS]: Serves as the domain boundary shared by UI journeys, production infrastructure, and contract fakes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

enum CliAvailability { ready, missing, incompatible }

enum CliIssue { missing, damaged, incompatible }

enum UpdateState { unknown, checking, upToDate, available, unsupported, failed }

enum HealthState { ready, notInitialized, unreachable, invalid }

enum SkillsFailureKind {
  validation,
  server,
  timeout,
  offline,
  invalidResponse,
  artifactUnavailable,
}

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

enum InstallationScope { user, project }

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
  const SkillFile({
    required this.path,
    required this.contents,
    this.size = 0,
    this.kind = 'text',
    this.executable = false,
    this.binary = false,
    this.truncated = false,
  });

  final String path;
  final String contents;
  final int size;
  final String kind;
  final bool executable;
  final bool binary;
  final bool truncated;
}

class SkillRiskEvidence {
  const SkillRiskEvidence({required this.code, required this.path});

  final String code;
  final String path;
}

class SkillInstallationTarget {
  const SkillInstallationTarget({
    required this.agent,
    required this.scope,
    required this.path,
    required this.version,
  });

  final String agent;
  final InstallationScope scope;
  final String path;
  final String version;
}

class AgentUserTarget {
  const AgentUserTarget({required this.path, required this.exists});

  final String path;
  final bool exists;
}

class AgentStatus {
  const AgentStatus({
    required this.id,
    required this.displayName,
    required this.installed,
    required this.supportedScopes,
    this.userTarget,
  });

  final String id;
  final String displayName;
  final bool installed;
  final List<InstallationScope> supportedScopes;
  final AgentUserTarget? userTarget;
}

class AgentCatalog {
  const AgentCatalog({required this.schemaVersion, required this.agents});

  final int schemaVersion;
  final List<AgentStatus> agents;

  List<AgentStatus> get installed =>
      agents.where((agent) => agent.installed).toList(growable: false);
}

class SkillDetail {
  const SkillDetail({
    required this.name,
    required this.source,
    required this.markdown,
    required this.files,
    this.installs = 0,
    this.description = '',
    this.requestedVersion = '',
    this.immutableVersion = '',
    this.commitSHA = '',
    this.treeSHA = '',
    this.sourceRef = '',
    this.contentDigest = '',
    this.manifest = '',
    this.trustLevel = SkillTrustLevel.unverified,
    this.riskAssessment = SkillRiskAssessment.unknown,
    this.riskScannerVersion = '',
    this.riskEvidence = const [],
    this.installationTargets = const [],
    this.registryExecutableSignal = false,
  });

  final String name;
  final String source;
  final String markdown;
  final List<SkillFile> files;
  final int installs;
  final String description;
  final String requestedVersion;
  final String immutableVersion;
  final String commitSHA;
  final String treeSHA;
  final String sourceRef;
  final String contentDigest;
  final String manifest;
  final SkillTrustLevel trustLevel;
  final SkillRiskAssessment riskAssessment;
  final String riskScannerVersion;
  final List<SkillRiskEvidence> riskEvidence;
  final List<SkillInstallationTarget> installationTargets;
  final bool registryExecutableSignal;

  bool get hasExecutableContent =>
      registryExecutableSignal ||
      files.any((file) {
        if (file.executable) return true;
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
    this.targets = const [],
  });

  final String name;
  final String path;
  final List<String> agents;
  final int targetCount;
  final String coordinate;
  final List<SkillInstallationTarget> targets;

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
  Future<AgentCatalog> inspectAgents();
  Future<List<InstalledSkill>> listInstalled();
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill);
  Future<CommandResult> install(SkillSummary skill);
  Future<CommandResult> remove(InstalledSkill skill);
  Future<CommandResult> update(InstalledSkill skill);
  Future<Map<String, UpdateState>> checkUpdates(List<InstalledSkill> skills);
}
