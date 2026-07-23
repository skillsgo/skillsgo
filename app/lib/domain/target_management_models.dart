/*
 * [INPUT]: Depends on installation targets, target failures, shared management enums, and stable target identity keys.
 * [OUTPUT]: Provides reviewed exact-path removal plans, target results, execution summaries, and progress events.
 * [POS]: Serves as the focused Target Operation Plan model module used by Library journeys and CLI adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'installation_models.dart';
import 'system_models.dart';

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
  const TargetManagementPlanSummary({required this.removable});

  final int removable;
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
      final action = actions[installationTargetKey(item.target)];
      if (action == null) continue;
      if (!item.allowedActions.contains(action)) {
        throw ArgumentError.value(action, 'actions', 'Action is not allowed.');
      }
      selected.add(item.select(action));
    }
    return TargetManagementPlan(
      targets: List.unmodifiable(selected),
      summary: TargetManagementPlanSummary(removable: selected.length),
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
