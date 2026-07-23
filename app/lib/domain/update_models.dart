/*
 * [INPUT]: Depends on installation target identity and shared update enums.
 * [OUTPUT]: Provides reviewed Update Plans, immutable target results, execution summaries, progress, and compatibility target-key helpers.
 * [POS]: Serves as the focused Update Plan model module used by Library journeys and CLI adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'installation_models.dart';
import 'system_models.dart';

class UpdatePlanItem {
  const UpdatePlanItem({
    required this.target,
    required this.name,
    required this.repositoryId,
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
  final String repositoryId;
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

String updateTargetKey(InstallationPlanTarget target) =>
    installationTargetKey(target);

String installedUpdateTargetKey(SkillInstallationTarget target) =>
    installedTargetKey(target);

class UpdateTargetResult {
  const UpdateTargetResult({
    required this.target,
    required this.name,
    required this.repositoryId,
    required this.fromVersion,
    required this.toVersion,
    required this.outcome,
    this.error,
  });

  final InstallationPlanTarget target;
  final String name;
  final String repositoryId;
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
    required this.repositoryId,
    required this.fromVersion,
    required this.toVersion,
    required this.state,
    this.result,
  });

  final int sequence;
  final InstallationPlanTarget target;
  final String name;
  final String repositoryId;
  final String fromVersion;
  final String toVersion;
  final InstallationProgressState state;
  final UpdateTargetResult? result;
}
