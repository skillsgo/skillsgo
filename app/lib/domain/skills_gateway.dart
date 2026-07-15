/*
 * [INPUT]: Depends only on Dart core types and asynchronous result primitives.
 * [OUTPUT]: Defines App contracts for discovery, auditable artifacts, unified Library entries/targets, explicit Installation and Update Plans/progress/results, project references, Agent inspection, CLI, Registry settings, risk policy, storage health, and operations.
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

enum InstallationMode { symlink, copy, external }

enum InstallationPlanAction { create, replace, skip, conflict, blockedByRisk }

enum InstallationTargetResolution { none, replace }

enum InstallationTargetOutcome { succeeded, skipped, conflict, failed }

enum InstallationProgressState { started, finished }

enum UpdatePlanAction { update, current, pinned, failed }

enum UpdateTargetOutcome { succeeded, skipped, failed }

enum ReceiptState { present, missing, invalid }

enum InstallationHealth {
  healthy,
  missing,
  replaced,
  localModification,
  unreadable,
  undeclared,
  workspaceUnreadable,
  lockMismatch,
  unexpectedPath,
  receiptMissing,
}

enum LibraryProvenance { registry, local, external }

enum ProjectAccessState { accessible, missing, permissionDenied, inaccessible }

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
    this.projectRoot = '',
    this.mode = InstallationMode.symlink,
    this.receiptState = ReceiptState.present,
    this.health = InstallationHealth.healthy,
  });

  final String agent;
  final InstallationScope scope;
  final String path;
  final String version;
  final String projectRoot;
  final InstallationMode mode;
  final ReceiptState receiptState;
  final InstallationHealth health;
}

class InstallationTargetSelection {
  const InstallationTargetSelection({
    required this.scope,
    required this.agent,
    this.projectRoot = '',
    this.mode = InstallationMode.symlink,
    this.resolution = InstallationTargetResolution.none,
    this.expectedReason = '',
    this.expectedState = '',
  });

  final InstallationScope scope;
  final String projectRoot;
  final String agent;
  final InstallationMode mode;
  final InstallationTargetResolution resolution;
  final String expectedReason;
  final String expectedState;

  InstallationTargetSelection copyWith({
    InstallationTargetResolution? resolution,
    String? expectedReason,
    String? expectedState,
  }) => InstallationTargetSelection(
    scope: scope,
    projectRoot: projectRoot,
    agent: agent,
    mode: mode,
    resolution: resolution ?? this.resolution,
    expectedReason: expectedReason ?? this.expectedReason,
    expectedState: expectedState ?? this.expectedState,
  );
}

class InstallationPlanTarget {
  const InstallationPlanTarget({
    required this.scope,
    required this.agent,
    required this.mode,
    required this.path,
    this.projectRoot = '',
  });

  final InstallationScope scope;
  final String projectRoot;
  final String agent;
  final InstallationMode mode;
  final String path;
}

class InstallationPlanItem {
  const InstallationPlanItem({
    required this.target,
    required this.action,
    required this.workspaceLockChange,
    this.reasonCode = '',
    this.stateToken = '',
    this.affectedBindings = const [],
  });

  final InstallationPlanTarget target;
  final InstallationPlanAction action;
  final bool workspaceLockChange;
  final String reasonCode;
  final String stateToken;
  final List<InstallationAffectedBinding> affectedBindings;
}

class InstallationAffectedBinding {
  const InstallationAffectedBinding({
    required this.agent,
    required this.scope,
    required this.mode,
    required this.path,
  });

  final String agent;
  final InstallationScope scope;
  final InstallationMode mode;
  final String path;
}

class InstallationPlanSummary {
  const InstallationPlanSummary({
    required this.create,
    required this.replace,
    required this.skip,
    required this.conflict,
    required this.blockedByRisk,
  });

  final int create;
  final int replace;
  final int skip;
  final int conflict;
  final int blockedByRisk;
}

class WorkspaceLockChange {
  const WorkspaceLockChange({
    required this.projectRoot,
    required this.path,
    required this.skill,
    required this.toVersion,
    this.fromVersion = '',
  });

  final String projectRoot;
  final String path;
  final String skill;
  final String fromVersion;
  final String toVersion;
}

class InstallationPlan {
  const InstallationPlan({
    required this.source,
    required this.coordinate,
    required this.version,
    required this.name,
    required this.selections,
    required this.targets,
    required this.summary,
    required this.workspaceLockChanges,
    required this.riskAssessment,
    required this.riskConfirmed,
    required this.allowCritical,
  });

  final String source;
  final String coordinate;
  final String version;
  final String name;
  final List<InstallationTargetSelection> selections;
  final List<InstallationPlanItem> targets;
  final InstallationPlanSummary summary;
  final List<WorkspaceLockChange> workspaceLockChanges;
  final SkillRiskAssessment riskAssessment;
  final bool riskConfirmed;
  final bool allowCritical;
}

class InstallationTargetResult {
  const InstallationTargetResult({
    required this.target,
    required this.action,
    required this.outcome,
    this.errorCode = '',
    this.diagnostic = '',
  });

  final InstallationPlanTarget target;
  final InstallationPlanAction action;
  final InstallationTargetOutcome outcome;
  final String errorCode;
  final String diagnostic;
}

class InstallationExecutionSummary {
  const InstallationExecutionSummary({
    required this.succeeded,
    required this.skipped,
    required this.conflict,
    required this.failed,
  });

  final int succeeded;
  final int skipped;
  final int conflict;
  final int failed;
}

class InstallationExecution {
  const InstallationExecution({
    required this.coordinate,
    required this.version,
    required this.name,
    required this.results,
    required this.summary,
  });

  final String coordinate;
  final String version;
  final String name;
  final List<InstallationTargetResult> results;
  final InstallationExecutionSummary summary;

  bool get hasSuccess => summary.succeeded > 0 || summary.skipped > 0;
}

class InstallationTargetProgress {
  const InstallationTargetProgress({
    required this.sequence,
    required this.target,
    required this.action,
    required this.state,
    this.result,
  });

  final int sequence;
  final InstallationPlanTarget target;
  final InstallationPlanAction action;
  final InstallationProgressState state;
  final InstallationTargetResult? result;
}

class UpdatePlanItem {
  const UpdatePlanItem({
    required this.target,
    required this.name,
    required this.coordinate,
    required this.sourceRef,
    required this.fromVersion,
    required this.toVersion,
    required this.action,
    required this.stateToken,
    required this.workspaceLockChange,
    this.reasonCode = '',
    this.diagnostic = '',
    this.affectedBindings = const [],
  });

  final InstallationPlanTarget target;
  final String name;
  final String coordinate;
  final String sourceRef;
  final String fromVersion;
  final String toVersion;
  final UpdatePlanAction action;
  final String reasonCode;
  final String diagnostic;
  final String stateToken;
  final bool workspaceLockChange;
  final List<InstallationPlanTarget> affectedBindings;
}

class UpdatePlanSummary {
  const UpdatePlanSummary({
    required this.update,
    required this.current,
    required this.pinned,
    required this.failed,
  });

  final int update;
  final int current;
  final int pinned;
  final int failed;
}

class UpdatePlan {
  const UpdatePlan({
    required this.targets,
    required this.workspaceLockChanges,
    required this.summary,
  });

  final List<UpdatePlanItem> targets;
  final List<WorkspaceLockChange> workspaceLockChanges;
  final UpdatePlanSummary summary;

  UpdatePlan selectTargets(Iterable<UpdatePlanItem> selected) {
    final values = List<UpdatePlanItem>.unmodifiable(selected);
    return UpdatePlan(
      targets: values,
      workspaceLockChanges: List.unmodifiable(
        workspaceLockChanges.where(
          (change) => values.any(
            (item) =>
                item.workspaceLockChange &&
                item.target.projectRoot == change.projectRoot &&
                item.name == change.skill &&
                item.toVersion == change.toVersion,
          ),
        ),
      ),
      summary: UpdatePlanSummary(
        update: values
            .where((item) => item.action == UpdatePlanAction.update)
            .length,
        current: values
            .where((item) => item.action == UpdatePlanAction.current)
            .length,
        pinned: values
            .where((item) => item.action == UpdatePlanAction.pinned)
            .length,
        failed: values
            .where((item) => item.action == UpdatePlanAction.failed)
            .length,
      ),
    );
  }
}

String updateTargetKey(InstallationPlanTarget target) => _updateTargetKey(
  target.scope,
  target.projectRoot,
  target.agent,
  target.mode,
  target.path,
);

String installedUpdateTargetKey(SkillInstallationTarget target) =>
    _updateTargetKey(
      target.scope,
      target.projectRoot,
      target.agent,
      target.mode,
      target.path,
    );

String _updateTargetKey(
  InstallationScope scope,
  String projectRoot,
  String agent,
  InstallationMode mode,
  String path,
) => '${scope.name}\u0000$projectRoot\u0000$agent\u0000${mode.name}\u0000$path';

class UpdateTargetResult {
  const UpdateTargetResult({
    required this.target,
    required this.name,
    required this.coordinate,
    required this.fromVersion,
    required this.toVersion,
    required this.outcome,
    this.errorCode = '',
    this.diagnostic = '',
  });

  final InstallationPlanTarget target;
  final String name;
  final String coordinate;
  final String fromVersion;
  final String toVersion;
  final UpdateTargetOutcome outcome;
  final String errorCode;
  final String diagnostic;
}

class UpdateExecutionSummary {
  const UpdateExecutionSummary({
    required this.succeeded,
    required this.skipped,
    required this.failed,
  });

  final int succeeded;
  final int skipped;
  final int failed;
}

class UpdateExecution {
  const UpdateExecution({required this.results, required this.summary});

  final List<UpdateTargetResult> results;
  final UpdateExecutionSummary summary;
}

class UpdateTargetProgress {
  const UpdateTargetProgress({
    required this.sequence,
    required this.target,
    required this.name,
    required this.coordinate,
    required this.fromVersion,
    required this.toVersion,
    required this.state,
    this.result,
  });

  final int sequence;
  final InstallationPlanTarget target;
  final String name;
  final String coordinate;
  final String fromVersion;
  final String toVersion;
  final InstallationProgressState state;
  final UpdateTargetResult? result;
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

class AddedProject {
  const AddedProject({
    required this.id,
    required this.name,
    required this.path,
    required this.accessState,
    this.diagnostic,
  });

  final String id;
  final String name;
  final String path;
  final ProjectAccessState accessState;
  final String? diagnostic;

  bool get isAccessible => accessState == ProjectAccessState.accessible;
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
    this.identity = '',
    this.coordinate = '',
    this.targets = const [],
    this.provenance = LibraryProvenance.registry,
    this.riskAssessment = SkillRiskAssessment.unknown,
    this.health = InstallationHealth.healthy,
    this.projects = const [],
    this.versions = const [],
    this.versionDivergence = false,
  });

  final String name;
  final String path;
  final List<String> agents;
  final int targetCount;
  final String identity;
  final String coordinate;
  final List<SkillInstallationTarget> targets;
  final LibraryProvenance provenance;
  final SkillRiskAssessment riskAssessment;
  final InstallationHealth health;
  final List<String> projects;
  final List<String> versions;
  final bool versionDivergence;

  bool get isLinkedToCodex =>
      agents.any((agent) => agent.toLowerCase() == 'codex');

  InstalledSkill withTargets(List<SkillInstallationTarget> selectedTargets) {
    if (selectedTargets.isEmpty) {
      throw ArgumentError.value(
        selectedTargets,
        'selectedTargets',
        'A Library Entry must retain at least one target.',
      );
    }
    final selectedAgents = <String>{};
    final selectedProjects = <String>{};
    final selectedVersions = <String>{};
    var selectedHealth = InstallationHealth.healthy;
    for (final target in selectedTargets) {
      selectedAgents.add(target.agent);
      if (target.projectRoot.isNotEmpty) {
        selectedProjects.add(target.projectRoot);
      }
      if (target.version.isNotEmpty) selectedVersions.add(target.version);
      if (selectedHealth == InstallationHealth.healthy &&
          target.health != InstallationHealth.healthy) {
        selectedHealth = target.health;
      }
    }
    final versionList = selectedVersions.toList()..sort();
    return InstalledSkill(
      identity: identity,
      name: name,
      path: selectedTargets.first.path,
      agents: (selectedAgents.toList()..sort()),
      targetCount: selectedTargets.length,
      coordinate: coordinate,
      targets: List.unmodifiable(selectedTargets),
      provenance: provenance,
      riskAssessment: riskAssessment,
      health: selectedHealth,
      projects: (selectedProjects.toList()..sort()),
      versions: versionList,
      versionDivergence: versionList.length > 1,
    );
  }
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
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  });
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
  Future<List<AddedProject>> loadAddedProjects();
  Future<AddedProject?> addProject();
  Future<AddedProject?> relocateProject(String id);
  Future<void> removeProject(String id);
  Future<List<InstalledSkill>> listInstalled({
    List<AddedProject> projects = const [],
  });
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill);
  Future<InstallationPlan> preflightInstall(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool riskConfirmed = false,
    bool allowCritical = false,
  });
  Future<InstallationExecution> executeInstall(
    InstallationPlan plan, {
    void Function(InstallationTargetProgress progress)? onProgress,
  });
  Future<CommandResult> install(SkillSummary skill);
  Future<CommandResult> remove(InstalledSkill skill);
  Future<UpdatePlan> preflightUpdate(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  );
  Future<UpdateExecution> executeUpdate(
    UpdatePlan plan, {
    void Function(UpdateTargetProgress progress)? onProgress,
  });
  Future<Map<String, UpdateState>> checkUpdates(List<InstalledSkill> skills);
}
