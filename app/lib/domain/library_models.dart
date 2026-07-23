/*
 * [INPUT]: Depends on discovery audit models, installation targets, and shared Library, project, Agent, onboarding, health, trust, and risk vocabulary.
 * [OUTPUT]: Provides Agent catalogs, Added Projects, onboarding state, unified Library entries, local/remote Skill detail, and Batch Takeover scope/plan/preview plus named per-item result values.
 * [POS]: Serves as the focused local Library and inventory model module shared by onboarding, Library journeys, and CLI decoding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'discovery_models.dart';
import 'installation_models.dart';
import 'system_models.dart';

class BatchTakeoverResult {
  const BatchTakeoverResult({
    required this.takenOver,
    required this.skipped,
    this.items = const [],
  });

  final int takenOver;
  final int skipped;
  final List<BatchTakeoverItemResult> items;
}

enum BatchTakeoverItemStatus { takenOver, skipped }

class BatchTakeoverItemResult {
  const BatchTakeoverItemResult({
    required this.name,
    required this.skillId,
    required this.status,
    this.reason = '',
  });

  final String name;
  final String skillId;
  final BatchTakeoverItemStatus status;
  final String reason;
}

enum BatchTakeoverScopeKind { all, user, project }

class BatchTakeoverScope {
  const BatchTakeoverScope._(this.kind, this.projectRoot);

  static const all = BatchTakeoverScope._(BatchTakeoverScopeKind.all, '');
  static const user = BatchTakeoverScope._(BatchTakeoverScopeKind.user, '');

  factory BatchTakeoverScope.project(String projectRoot) =>
      BatchTakeoverScope._(BatchTakeoverScopeKind.project, projectRoot);

  final BatchTakeoverScopeKind kind;
  final String projectRoot;
}

class BatchTakeoverPlan {
  const BatchTakeoverPlan({
    required this.id,
    required this.allEligibleCount,
    required this.userEligibleCount,
    this.eligibleCountByProjectRoot = const {},
    this.previews = const [],
  });

  final String id;
  final int allEligibleCount;
  final int userEligibleCount;
  final Map<String, int> eligibleCountByProjectRoot;
  final List<BatchTakeoverPreview> previews;

  int eligibleCount(BatchTakeoverScope scope) => switch (scope.kind) {
    BatchTakeoverScopeKind.all => allEligibleCount,
    BatchTakeoverScopeKind.user => userEligibleCount,
    BatchTakeoverScopeKind.project => eligibleForProject(scope.projectRoot),
  };

  int eligibleForProject(String projectRoot) =>
      eligibleCountByProjectRoot[projectRoot] ?? 0;
}

class BatchTakeoverPreview {
  const BatchTakeoverPreview({
    required this.name,
    required this.skillId,
    required this.scope,
    this.projectRoot = '',
  });

  final String name;
  final String skillId;
  final InstallationScope scope;
  final String projectRoot;
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
    this.discoveryRoots = const [],
  });

  final String id;
  final String displayName;
  final bool installed;
  final List<InstallationScope> supportedScopes;
  final AgentUserTarget? userTarget;
  final List<String> discoveryRoots;
}

class AgentCatalog {
  const AgentCatalog({required this.schemaVersion, required this.agents});

  final int schemaVersion;
  final List<AgentStatus> agents;

  List<AgentStatus> get installed =>
      agents.where((agent) => agent.installed).toList(growable: false);
}

class OnboardingState {
  const OnboardingState({required this.completed, required this.step});

  final bool completed;
  final OnboardingStep step;

  @override
  bool operator ==(Object other) =>
      other is OnboardingState &&
      other.completed == completed &&
      other.step == step;

  @override
  int get hashCode => Object.hash(completed, step);
}

class AddedProject {
  const AddedProject({
    required this.id,
    required this.name,
    this.description = '',
    required this.path,
    required this.accessState,
    this.diagnostic,
    this.icon,
  });

  final String id;
  final String name;
  final String description;
  final String path;
  final ProjectAccessState accessState;
  final String? diagnostic;
  final ProjectIcon? icon;

  bool get isAccessible => accessState == ProjectAccessState.accessible;

  AddedProject copyWith({ProjectIcon? icon, bool clearIcon = false}) =>
      AddedProject(
        id: id,
        name: name,
        description: description,
        path: path,
        accessState: accessState,
        diagnostic: diagnostic,
        icon: clearIcon ? null : icon ?? this.icon,
      );
}

class ProjectIcon {
  const ProjectIcon({required this.path, required this.sourceFingerprint});

  final String path;
  final String sourceFingerprint;
}

class SkillDetail {
  const SkillDetail({
    required this.name,
    required this.source,
    required this.markdown,
    required this.files,
    this.imageUrl,
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
    this.sum = '',
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
  final String sum;
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
    this.repositoryId = '',
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
  final String repositoryId;
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
      if (target.version.isNotEmpty) {
        selectedVersions.add(target.version);
      }
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
      repositoryId: repositoryId,
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
