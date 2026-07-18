/*
 * [INPUT]: Depends only on Dart core types and asynchronous result primitives.
 * [OUTPUT]: Defines App contracts for discovery metadata including Repository source summaries and Hub image URLs, auditable artifacts, unified Hub/Local/External Library entries, managed targets, derived Agent visibility, explicit Installation/Update/Target Management/External Adoption flows, Local export, project references, Agent inspection, CLI machine failures, Hub and typed appearance/wallpaper settings, risk policy, storage health, and operations.
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
  invalidLocalData,
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

enum DiscoveryVerification { verified, unverified }

enum InstallationPlanAction { create, replace, skip, conflict, blockedByRisk }

enum InstallationTargetOutcome { succeeded, skipped, conflict, failed }

enum InstallationProgressState { started, finished }

enum UpdatePlanAction { update, current, pinned, failed }

enum UpdateTargetOutcome { succeeded, skipped, failed }

enum TargetManagementAction { remove, repair, stopManaging }

enum TargetManagementOutcome { succeeded, failed }

enum ExternalAdoptionAction { associateHub, importLocal }

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
}

enum LibraryProvenance { hub, local, external }

enum ProjectAccessState { accessible, missing, permissionDenied, inaccessible }

enum SkillMetricKind { allTimeInstalls, installs24h, hotVelocity }

enum HubIssue {
  invalidOrigin,
  httpFailure,
  invalidProtocol,
  invalidJson,
  connectionFailure,
  timeout,
}

class HubStatus {
  const HubStatus({
    required this.origin,
    required this.state,
    this.issue,
    this.httpStatus,
    this.diagnostic,
    this.version,
  });

  final String origin;
  final HealthState state;
  final HubIssue? issue;
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
    required this.installName,
    required this.name,
    required this.source,
    required this.installs,
    this.imageUrl,
    this.latestVersion = 'main',
    this.description = '',
    this.trustLevel = SkillTrustLevel.unverified,
    this.riskAssessment = SkillRiskAssessment.unknown,
    this.metricKind = SkillMetricKind.allTimeInstalls,
    this.metricChange = 0,
    this.localTargetCount = 0,
  });

  final String id;
  final String installName;
  final String name;
  final String source;
  final String? imageUrl;
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

class RepositorySummary {
  const RepositorySummary({
    required this.id,
    this.imageUrl,
    this.description = '',
    this.stars = 0,
    this.latestVersion = '',
    this.updatedAt,
    this.license,
  });

  final String id;
  final String? imageUrl;
  final String description;
  final int stars;
  final String latestVersion;
  final DateTime? updatedAt;
  final String? license;
}

class DiscoveryPage {
  const DiscoveryPage({required this.skills, this.nextOffset, this.repository});

  final List<SkillSummary> skills;
  final int? nextOffset;
  final RepositorySummary? repository;
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
    this.health = InstallationHealth.healthy,
  });

  final String agent;
  final InstallationScope scope;
  final String path;
  final String version;
  final String projectRoot;
  final InstallationMode mode;
  final InstallationHealth health;
}

class SkillVisibility {
  const SkillVisibility({
    required this.agent,
    required this.scope,
    required this.paths,
    required this.verification,
    this.projectRoot = '',
  });

  final String agent;
  final InstallationScope scope;
  final String projectRoot;
  final List<String> paths;
  final DiscoveryVerification verification;
}

class InstallationTargetSelection {
  const InstallationTargetSelection({
    required this.scope,
    required this.agent,
    this.projectRoot = '',
    this.mode = InstallationMode.symlink,
  });

  final InstallationScope scope;
  final String projectRoot;
  final String agent;
  final InstallationMode mode;
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

class WorkspaceManifestChange {
  const WorkspaceManifestChange({
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

class TargetFailure {
  const TargetFailure({
    required this.code,
    required this.retryable,
    this.details = const {},
    this.requestId = '',
    this.diagnostic = '',
  });

  final String code;
  final bool retryable;
  final Map<String, Object?> details;
  final String requestId;
  final String diagnostic;
}

class InstallationTargetResult {
  const InstallationTargetResult({
    required this.target,
    required this.action,
    required this.outcome,
    this.error,
  });

  final InstallationPlanTarget target;
  final InstallationPlanAction action;
  final InstallationTargetOutcome outcome;
  final TargetFailure? error;
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
    required this.skillId,
    required this.version,
    required this.name,
    required this.results,
    required this.summary,
  });

  final String skillId;
  final String version;
  final String name;
  final List<InstallationTargetResult> results;
  final InstallationExecutionSummary summary;

  bool get hasSuccess => summary.succeeded > 0 || summary.skipped > 0;
}

class UpdatePlanItem {
  const UpdatePlanItem({
    required this.target,
    required this.name,
    required this.skillId,
    required this.sourceRef,
    required this.fromVersion,
    required this.toVersion,
    required this.action,
    required this.stateToken,
    required this.workspaceManifestChange,
    this.reasonCode = '',
    this.diagnostic = '',
    this.affectedBindings = const [],
  });

  final InstallationPlanTarget target;
  final String name;
  final String skillId;
  final String sourceRef;
  final String fromVersion;
  final String toVersion;
  final UpdatePlanAction action;
  final String reasonCode;
  final String diagnostic;
  final String stateToken;
  final bool workspaceManifestChange;
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
    required this.workspaceManifestChanges,
    required this.summary,
  });

  final List<UpdatePlanItem> targets;
  final List<WorkspaceManifestChange> workspaceManifestChanges;
  final UpdatePlanSummary summary;

  UpdatePlan selectTargets(Iterable<UpdatePlanItem> selected) {
    final values = List<UpdatePlanItem>.unmodifiable(selected);
    return UpdatePlan(
      targets: values,
      workspaceManifestChanges: List.unmodifiable(
        workspaceManifestChanges.where(
          (change) => values.any(
            (item) =>
                item.workspaceManifestChange &&
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
    required this.skillId,
    required this.fromVersion,
    required this.toVersion,
    required this.outcome,
    this.error,
  });

  final InstallationPlanTarget target;
  final String name;
  final String skillId;
  final String fromVersion;
  final String toVersion;
  final UpdateTargetOutcome outcome;
  final TargetFailure? error;
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
    required this.skillId,
    required this.fromVersion,
    required this.toVersion,
    required this.state,
    this.result,
  });

  final int sequence;
  final InstallationPlanTarget target;
  final String name;
  final String skillId;
  final String fromVersion;
  final String toVersion;
  final InstallationProgressState state;
  final UpdateTargetResult? result;
}

class TargetManagementPlanItem {
  const TargetManagementPlanItem({
    required this.target,
    required this.name,
    required this.skillId,
    required this.version,
    required this.health,
    required this.allowedActions,
    required this.stateToken,
    required this.workspaceMetadataChange,
    this.action,
    this.diagnostic = '',
    this.affectedBindings = const [],
  });

  final InstallationPlanTarget target;
  final String name;
  final String skillId;
  final String version;
  final InstallationHealth health;
  final List<TargetManagementAction> allowedActions;
  final TargetManagementAction? action;
  final String stateToken;
  final bool workspaceMetadataChange;
  final String diagnostic;
  final List<InstallationPlanTarget> affectedBindings;

  TargetManagementPlanItem select(TargetManagementAction selectedAction) =>
      TargetManagementPlanItem(
        target: target,
        name: name,
        skillId: skillId,
        version: version,
        health: health,
        allowedActions: allowedActions,
        action: selectedAction,
        stateToken: stateToken,
        workspaceMetadataChange: workspaceMetadataChange,
        diagnostic: diagnostic,
        affectedBindings: affectedBindings,
      );
}

class TargetManagementPlanSummary {
  const TargetManagementPlanSummary({
    required this.removable,
    required this.repairable,
    required this.stoppable,
  });

  final int removable;
  final int repairable;
  final int stoppable;
}

class TargetManagementPlan {
  const TargetManagementPlan({required this.targets, required this.summary});

  final List<TargetManagementPlanItem> targets;
  final TargetManagementPlanSummary summary;

  TargetManagementPlan selectActions(
    Map<String, TargetManagementAction> actions,
  ) {
    final selected = <TargetManagementPlanItem>[];
    for (final item in targets) {
      final action = actions[updateTargetKey(item.target)];
      if (action == null) continue;
      if (!item.allowedActions.contains(action)) {
        throw ArgumentError.value(action, 'actions', 'Action is not allowed.');
      }
      selected.add(item.select(action));
    }
    return TargetManagementPlan(
      targets: List.unmodifiable(selected),
      summary: TargetManagementPlanSummary(
        removable: selected
            .where((item) => item.action == TargetManagementAction.remove)
            .length,
        repairable: selected
            .where((item) => item.action == TargetManagementAction.repair)
            .length,
        stoppable: selected
            .where((item) => item.action == TargetManagementAction.stopManaging)
            .length,
      ),
    );
  }
}

class TargetManagementResult {
  const TargetManagementResult({
    required this.target,
    required this.name,
    required this.skillId,
    required this.version,
    required this.action,
    required this.outcome,
    this.error,
  });

  final InstallationPlanTarget target;
  final String name;
  final String skillId;
  final String version;
  final TargetManagementAction action;
  final TargetManagementOutcome outcome;
  final TargetFailure? error;
}

class TargetManagementExecutionSummary {
  const TargetManagementExecutionSummary({
    required this.succeeded,
    required this.failed,
  });

  final int succeeded;
  final int failed;
}

class TargetManagementExecution {
  const TargetManagementExecution({
    required this.results,
    required this.summary,
  });

  final List<TargetManagementResult> results;
  final TargetManagementExecutionSummary summary;
}

class TargetManagementProgress {
  const TargetManagementProgress({
    required this.sequence,
    required this.target,
    required this.name,
    required this.skillId,
    required this.version,
    required this.action,
    required this.state,
    this.result,
  });

  final int sequence;
  final InstallationPlanTarget target;
  final String name;
  final String skillId;
  final String version;
  final TargetManagementAction action;
  final InstallationProgressState state;
  final TargetManagementResult? result;
}

class HubContentMatch {
  const HubContentMatch({
    required this.skillId,
    required this.name,
    required this.source,
    required this.immutableVersion,
    required this.commitSHA,
    required this.treeSHA,
    required this.contentDigest,
    this.skillPath = '',
  });

  final String skillId;
  final String name;
  final String source;
  final String skillPath;
  final String immutableVersion;
  final String commitSHA;
  final String treeSHA;
  final String contentDigest;
}

class ExternalAdoptionPlan {
  const ExternalAdoptionPlan({
    required this.inventoryKey,
    required this.name,
    required this.target,
    required this.contentDigest,
    required this.stateToken,
    required this.matches,
    required this.canImportLocal,
    this.sourceHint = '',
    this.action,
    this.selectedMatch,
  });

  final String inventoryKey;
  final String name;
  final InstallationPlanTarget target;
  final String contentDigest;
  final String sourceHint;
  final String stateToken;
  final List<HubContentMatch> matches;
  final bool canImportLocal;
  final ExternalAdoptionAction? action;
  final HubContentMatch? selectedMatch;

  ExternalAdoptionPlan selectHubMatch(HubContentMatch match) =>
      ExternalAdoptionPlan(
        inventoryKey: inventoryKey,
        name: name,
        target: target,
        contentDigest: contentDigest,
        sourceHint: sourceHint,
        stateToken: stateToken,
        matches: matches,
        canImportLocal: canImportLocal,
        action: ExternalAdoptionAction.associateHub,
        selectedMatch: match,
      );

  ExternalAdoptionPlan selectLocalImport() => ExternalAdoptionPlan(
    inventoryKey: inventoryKey,
    name: name,
    target: target,
    contentDigest: contentDigest,
    sourceHint: sourceHint,
    stateToken: stateToken,
    matches: matches,
    canImportLocal: canImportLocal,
    action: ExternalAdoptionAction.importLocal,
  );
}

class ExternalAdoptionResult {
  const ExternalAdoptionResult({
    required this.action,
    required this.name,
    required this.skillId,
    required this.version,
    required this.provenance,
    required this.contentDigest,
    required this.target,
  });

  final ExternalAdoptionAction action;
  final String name;
  final String skillId;
  final String version;
  final LibraryProvenance provenance;
  final String contentDigest;
  final InstallationPlanTarget target;
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
    this.description = '',
    required this.path,
    required this.accessState,
    this.diagnostic,
  });

  final String id;
  final String name;
  final String description;
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
    this.imageUrl,
    this.installs = 0,
    this.repository = '',
    this.stars = 0,
    this.sourceUpdatedAt,
    this.archiveSize = 0,
    this.description = '',
    this.requestedVersion = '',
    this.immutableVersion = '',
    this.commitSHA = '',
    this.treeSHA = '',
    this.sourceRef = '',
    this.contentDigest = '',
    this.trustLevel = SkillTrustLevel.unverified,
    this.riskAssessment = SkillRiskAssessment.unknown,
    this.riskScannerVersion = '',
    this.riskEvidence = const [],
    this.installationTargets = const [],
    this.hubExecutableSignal = false,
  });

  final String name;
  final String source;
  final String markdown;
  final List<SkillFile> files;
  final String? imageUrl;
  final int installs;
  final String repository;
  final int stars;
  final DateTime? sourceUpdatedAt;
  final int archiveSize;
  final String description;
  final String requestedVersion;
  final String immutableVersion;
  final String commitSHA;
  final String treeSHA;
  final String sourceRef;
  final String contentDigest;
  final SkillTrustLevel trustLevel;
  final SkillRiskAssessment riskAssessment;
  final String riskScannerVersion;
  final List<SkillRiskEvidence> riskEvidence;
  final List<SkillInstallationTarget> installationTargets;
  final bool hubExecutableSignal;

  bool get hasExecutableContent =>
      hubExecutableSignal ||
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
    this.description = '',
    required this.path,
    required this.agents,
    required this.targetCount,
    this.inventoryKey = '',
    this.skillId = '',
    this.targets = const [],
    this.visibility = const [],
    this.provenance = LibraryProvenance.hub,
    this.riskAssessment = SkillRiskAssessment.unknown,
    this.health = InstallationHealth.healthy,
    this.projects = const [],
    this.versions = const [],
    this.versionDivergence = false,
  });

  final String name;
  final String description;
  final String path;
  final List<String> agents;
  final int targetCount;
  final String inventoryKey;
  final String skillId;
  final List<SkillInstallationTarget> targets;
  final List<SkillVisibility> visibility;
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
      inventoryKey: inventoryKey,
      name: name,
      description: description,
      path: selectedTargets.first.path,
      agents: (selectedAgents.toList()..sort()),
      targetCount: selectedTargets.length,
      skillId: skillId,
      targets: List.unmodifiable(selectedTargets),
      visibility: visibility,
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

enum AppThemeMode { system, light, dark }

enum AppWallpaper {
  sun,
  mercury,
  venus,
  earth,
  mars,
  jupiter,
  saturn,
  uranus,
  neptune,
  pluto,
  moon,
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
    this.code = '',
    this.retryable = false,
    this.details = const {},
    this.requestId = '',
    this.diagnostic = '',
  });

  final String message;
  final SkillsFailureKind kind;
  final bool isOffline;
  final String code;
  final bool retryable;
  final Map<String, Object?> details;
  final String requestId;
  final String diagnostic;

  @override
  String toString() => message;
}

abstract interface class SkillsGateway {
  Future<CliStatus> detectCli({String? customPath});
  Future<void> saveCustomCliPath(String? path);
  Future<String?> loadCustomCliPath();
  Future<String> loadHubOrigin();
  Future<void> saveHubOrigin(String origin);
  Future<void> resetHubOrigin();
  Future<String> loadFolderTheme();
  Future<void> saveFolderTheme(String theme);
  Future<AppWallpaper> loadWallpaper();
  Future<void> saveWallpaper(AppWallpaper wallpaper);
  Future<AppThemeMode> loadThemeMode();
  Future<void> saveThemeMode(AppThemeMode mode);
  Future<HubStatus> testHubOrigin(String origin);
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
  Future<CommandResult> install(SkillSummary skill);
  Future<TargetManagementPlan> preflightTargetManagement(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  );
  Future<InstallationExecution> installTargets(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  });
  Future<TargetManagementExecution> executeTargetManagement(
    TargetManagementPlan plan, {
    void Function(TargetManagementProgress progress)? onProgress,
  });
  Future<ExternalAdoptionPlan> preflightExternalAdoption(InstalledSkill skill);
  Future<ExternalAdoptionResult> executeExternalAdoption(
    ExternalAdoptionPlan plan,
  );
  Future<CommandResult?> exportLocalSkill(InstalledSkill skill);
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
