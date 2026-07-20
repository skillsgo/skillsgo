/*
 * [INPUT]: Uses shared controls and state from FakeSkillsGatewayCore plus domain gateway models.
 * [OUTPUT]: Provides target management and batch takeover behavior.
 * [POS]: Serves as one capability facet of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

mixin FakeGatewayTargetManagement on FakeSkillsGatewayCore {
  @override
  Future<TargetManagementPlan> preflightTargetManagement(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  ) async {
    final items = [
      for (final target in targets)
        TargetManagementPlanItem(
          target: InstallationPlanTarget(
            scope: target.scope,
            projectRoot: target.projectRoot,
            agent: target.agent,
            mode: target.mode,
            path: target.path,
          ),
          name: skill.name,
          skillId: skill.skillId,
          version: target.version,
          health: target.health,
          allowedActions: target.health == InstallationHealth.healthy
              ? const [TargetManagementAction.remove]
              : const [TargetManagementAction.repair],
          stateToken: 'manage-${target.agent}-${target.path}',
          workspaceMetadataChange: target.scope == InstallationScope.project,
        ),
    ];
    return TargetManagementPlan(
      targets: items,
      summary: TargetManagementPlanSummary(
        removable: items
            .where(
              (item) =>
                  item.allowedActions.contains(TargetManagementAction.remove),
            )
            .length,
        repairable: items
            .where(
              (item) =>
                  item.allowedActions.contains(TargetManagementAction.repair),
            )
            .length,
      ),
    );
  }

  @override
  Future<TargetManagementExecution> executeTargetManagement(
    TargetManagementPlan plan, {
    void Function(TargetManagementProgress progress)? onProgress,
  }) async {
    managementTargetHistory.add({
      for (final item in plan.targets)
        updateTargetKey(item.target): item.action!,
    });
    var sequence = 0;
    final results = <TargetManagementResult>[];
    for (final item in plan.targets) {
      onProgress?.call(
        TargetManagementProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          skillId: item.skillId,
          version: item.version,
          action: item.action!,
          state: InstallationProgressState.started,
        ),
      );
      final result = TargetManagementResult(
        target: item.target,
        name: item.name,
        skillId: item.skillId,
        version: item.version,
        action: item.action!,
        outcome: TargetManagementOutcome.succeeded,
      );
      results.add(result);
      onProgress?.call(
        TargetManagementProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          skillId: item.skillId,
          version: item.version,
          action: item.action!,
          state: InstallationProgressState.finished,
          result: result,
        ),
      );
    }
    final actions = {
      for (final item in plan.targets)
        updateTargetKey(item.target): item.action!,
    };
    libraryEntries = libraryEntries
        ?.map((skill) {
          final remaining = <SkillInstallationTarget>[];
          for (final target in skill.targets) {
            final key = installedUpdateTargetKey(target);
            final action = actions[key];
            if (action == TargetManagementAction.remove) {
              continue;
            }
            if (action == TargetManagementAction.repair) {
              remaining.add(
                SkillInstallationTarget(
                  agent: target.agent,
                  scope: target.scope,
                  path: target.path,
                  version: target.version,
                  projectRoot: target.projectRoot,
                  mode: target.mode,
                  health: InstallationHealth.healthy,
                ),
              );
            } else {
              remaining.add(target);
            }
          }
          return remaining.isEmpty ? null : skill.withTargets(remaining);
        })
        .whereType<InstalledSkill>()
        .toList(growable: false);
    if (libraryEntries == null || libraryEntries!.isEmpty) installed = false;
    return TargetManagementExecution(
      results: results,
      summary: TargetManagementExecutionSummary(
        succeeded: results.length,
        failed: 0,
      ),
    );
  }
}
