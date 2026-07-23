/*
 * [INPUT]: Depends on shared installation enums and failure vocabulary.
 * [OUTPUT]: Provides mode-free Repository Projection targets, selections, manifest changes, target results, execution summaries, and target identity keys.
 * [POS]: Serves as the focused Installation Request model module shared by UI journeys, CLI decoding, updates, and target management.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'system_models.dart';

class SkillInstallationTarget {
  const SkillInstallationTarget({
    required this.agent,
    required this.scope,
    required this.path,
    required this.version,
    this.projectRoot = '',
    this.health = InstallationHealth.healthy,
  });

  final String agent;
  final InstallationScope scope;
  final String path;
  final String version;
  final String projectRoot;
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
  });

  final InstallationScope scope;
  final String projectRoot;
  final String agent;
}

class InstallationPlanTarget {
  const InstallationPlanTarget({
    required this.scope,
    required this.agent,
    required this.path,
    this.projectRoot = '',
  });

  final InstallationScope scope;
  final String projectRoot;
  final String agent;
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
    required this.repositoryId,
    required this.skillName,
    required this.version,
    required this.name,
    required this.results,
    required this.summary,
  });

  final String repositoryId;
  final String skillName;
  final String version;
  final String name;
  final List<InstallationTargetResult> results;
  final InstallationExecutionSummary summary;

  bool get hasSuccess => summary.succeeded > 0 || summary.skipped > 0;
}

String installationTargetKey(InstallationPlanTarget target) =>
    targetPartsKey(target.scope, target.projectRoot, target.agent, target.path);

String installedTargetKey(SkillInstallationTarget target) =>
    targetPartsKey(target.scope, target.projectRoot, target.agent, target.path);

String targetPartsKey(
  InstallationScope scope,
  String projectRoot,
  String agent,
  String path,
) => '${scope.name}\u0000$projectRoot\u0000$agent\u0000$path';
