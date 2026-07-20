/*
 * [INPUT]: Uses shared controls and state from FakeSkillsGatewayCore plus domain gateway models.
 * [OUTPUT]: Provides update planning, execution, and retry behavior.
 * [POS]: Serves as one capability facet of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

mixin FakeGatewayUpdates on FakeSkillsGatewayCore {
  @override
  Future<UpdatePlan> preflightUpdate(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  ) async {
    final items = [
      for (final target in targets)
        UpdatePlanItem(
          target: InstallationPlanTarget(
            scope: target.scope,
            projectRoot: target.projectRoot,
            agent: target.agent,
            mode: target.mode,
            path: target.path,
          ),
          name: skill.name,
          skillId: skill.skillId,
          sourceRef: 'main',
          fromVersion: target.version,
          toVersion: 'v2',
          action: UpdatePlanAction.update,
          stateToken: 'state-${target.agent}-${target.path}',
          workspaceManifestChange: target.scope == InstallationScope.project,
        ),
    ];
    return UpdatePlan(
      targets: items,
      workspaceManifestChanges: [
        for (final item in items)
          if (item.workspaceManifestChange)
            WorkspaceManifestChange(
              projectRoot: item.target.projectRoot,
              path: '${item.target.projectRoot}/skillsgo.mod',
              skill: item.name,
              fromVersion: item.fromVersion,
              toVersion: item.toVersion,
            ),
      ],
      summary: UpdatePlanSummary(
        update: items.length,
        current: 0,
        pinned: 0,
        failed: 0,
      ),
    );
  }

  @override
  Future<UpdateExecution> executeUpdate(
    UpdatePlan plan, {
    void Function(UpdateTargetProgress progress)? onProgress,
  }) async {
    updateCalls++;
    updateTargetHistory.add(
      plan.targets.map((item) => updateTargetKey(item.target)).toList(),
    );
    final configuredFailures = updateCalls <= updateFailures.length
        ? updateFailures[updateCalls - 1]
        : const <String>{};
    var sequence = 0;
    final results = <UpdateTargetResult>[];
    for (final item in plan.targets) {
      onProgress?.call(
        UpdateTargetProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          skillId: item.skillId,
          fromVersion: item.fromVersion,
          toVersion: item.toVersion,
          state: InstallationProgressState.started,
        ),
      );
      final failed = configuredFailures.contains(item.target.agent);
      final result = UpdateTargetResult(
        target: item.target,
        name: item.name,
        skillId: item.skillId,
        fromVersion: item.fromVersion,
        toVersion: item.toVersion,
        outcome: failed
            ? UpdateTargetOutcome.failed
            : UpdateTargetOutcome.succeeded,
        error: failed
            ? const TargetFailure(
                code: 'update.target_failed',
                retryable: true,
                diagnostic: 'Target is not writable.',
              )
            : null,
      );
      results.add(result);
      onProgress?.call(
        UpdateTargetProgress(
          sequence: ++sequence,
          target: item.target,
          name: item.name,
          skillId: item.skillId,
          fromVersion: item.fromVersion,
          toVersion: item.toVersion,
          state: InstallationProgressState.finished,
          result: result,
        ),
      );
    }
    final succeededKeys = results
        .where((result) => result.outcome == UpdateTargetOutcome.succeeded)
        .map((result) => updateTargetKey(result.target))
        .toSet();
    libraryEntries = libraryEntries
        ?.map(
          (skill) => skill.withTargets([
            for (final target in skill.targets)
              if (succeededKeys.contains(
                updateTargetKey(
                  InstallationPlanTarget(
                    scope: target.scope,
                    projectRoot: target.projectRoot,
                    agent: target.agent,
                    mode: target.mode,
                    path: target.path,
                  ),
                ),
              ))
                SkillInstallationTarget(
                  agent: target.agent,
                  scope: target.scope,
                  path: target.path,
                  version: 'v2',
                  projectRoot: target.projectRoot,
                  mode: target.mode,
                  health: target.health,
                )
              else
                target,
          ]),
        )
        .toList(growable: false);
    final succeeded = results
        .where((result) => result.outcome == UpdateTargetOutcome.succeeded)
        .length;
    final failed = results.length - succeeded;
    return UpdateExecution(
      results: results,
      summary: UpdateExecutionSummary(
        succeeded: succeeded,
        skipped: 0,
        failed: failed,
      ),
    );
  }
}
