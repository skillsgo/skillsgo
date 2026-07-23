/*
 * [INPUT]: Uses shared controls and state from FakeSkillsGatewayCore plus domain gateway models.
 * [OUTPUT]: Provides installation planning/execution plus Batch Takeover plan/scope execution behavior.
 * [POS]: Serves as one capability facet of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

mixin FakeGatewayInstallation on FakeSkillsGatewayCore {
  @override
  Future<InstallationExecution> installTargets(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    final risk = remoteDetail.riskAssessment;
    if ((risk == SkillRiskAssessment.high && !confirmRisk) ||
        (risk == SkillRiskAssessment.critical &&
            (!confirmRisk || !allowCritical))) {
      throw const SkillsException(
        'Risk confirmation is required.',
        kind: SkillsFailureKind.validation,
      );
    }
    if (installPlanErrors.isNotEmpty) throw installPlanErrors.removeAt(0);
    installCalls++;
    lastPlanSelections = List.unmodifiable(selections);
    executionSelectionHistory.add(List.unmodifiable(selections));

    var forceAllFailed = false;
    var failureDiagnostic = '';
    if (installCompleter != null) {
      final command = await installCompleter!.future;
      forceAllFailed = !command.succeeded;
      failureDiagnostic = command.output.stderr;
    }
    final configuredFailures = installCalls <= installFailures.length
        ? installFailures[installCalls - 1]
        : const <String>{};
    final results = selections
        .map((selection) {
          final failed =
              forceAllFailed || configuredFailures.contains(selection.agent);
          return InstallationTargetResult(
            target: InstallationPlanTarget(
              scope: selection.scope,
              projectRoot: selection.projectRoot,
              agent: selection.agent,
              path: selection.scope == InstallationScope.user
                  ? '/Users/test/.${selection.agent}/skills/${skill.installName}'
                  : '${selection.projectRoot}/.agents/skills/${skill.installName}',
            ),
            action: planConflictReason.isEmpty
                ? InstallationPlanAction.create
                : InstallationPlanAction.replace,
            outcome: failed
                ? InstallationTargetOutcome.failed
                : InstallationTargetOutcome.succeeded,
            error: failed
                ? TargetFailure(
                    code: 'installation.target_failed',
                    retryable: true,
                    diagnostic: failureDiagnostic,
                  )
                : null,
          );
        })
        .toList(growable: false);
    final succeeded = results
        .where(
          (result) => result.outcome == InstallationTargetOutcome.succeeded,
        )
        .length;
    final failed = results.length - succeeded;
    installed = succeeded > 0;
    final entries = libraryEntries;
    if (entries != null && succeeded > 0) {
      final index = entries.indexWhere((entry) => entry.skillId == skill.id);
      if (index >= 0) {
        final existing = entries[index];
        final targets = List<SkillInstallationTarget>.of(existing.targets);
        for (final result in results.where(
          (item) => item.outcome == InstallationTargetOutcome.succeeded,
        )) {
          if (targets.any(
            (target) =>
                target.scope == result.target.scope &&
                target.projectRoot == result.target.projectRoot &&
                target.agent == result.target.agent,
          )) {
            continue;
          }
          targets.add(
            SkillInstallationTarget(
              agent: result.target.agent,
              scope: result.target.scope,
              projectRoot: result.target.projectRoot,
              path: result.target.path,
              version: immutableVersion,
            ),
          );
        }
        entries[index] = existing.withTargets(targets);
      }
    }
    return InstallationExecution(
      skillId: skill.id,
      version: immutableVersion,
      name: skill.installName,
      results: results,
      summary: InstallationExecutionSummary(
        succeeded: succeeded,
        skipped: 0,
        conflict: 0,
        failed: failed,
      ),
    );
  }

  @override
  Future<CommandResult> install(SkillSummary skill) async {
    installCalls++;
    if (installCompleter != null) {
      final result = await installCompleter!.future;
      installed = result.succeeded;
      return result;
    }
    installed = true;
    return successCommand(['skills', 'add']);
  }

  @override
  Future<BatchTakeoverPlan> planBatchTakeover({
    List<String> projectRoots = const [],
  }) async {
    takeoverPlanRequests.add(List.unmodifiable(projectRoots));
    if (takeoverPlanCompleter != null) {
      return takeoverPlanCompleter!.future;
    }
    return takeoverPlan;
  }

  @override
  Future<BatchTakeoverResult> executeBatchTakeover(
    BatchTakeoverPlan plan,
    BatchTakeoverScope scope,
  ) async {
    takeoverRequests.add((plan: plan, scope: scope));
    if (takeoverCompleter != null) return takeoverCompleter!.future;
    return takeoverResult;
  }
}
