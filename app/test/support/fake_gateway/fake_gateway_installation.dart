/*
 * [INPUT]: Uses shared controls and state from FakeSkillsGatewayCore plus domain gateway models.
 * [OUTPUT]: Provides installation execution and reviewed External adoption behavior.
 * [POS]: Serves as one capability facet of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

mixin FakeGatewayInstallation on FakeSkillsGatewayCore {
  @override
  Future<BatchAdoptionResult> adopt(List<AdoptionRequestItem> items) async {
    repositoryInstallCalls++;
    adoptionRequests.add(List.unmodifiable(items));
    for (final item in items) {
      installCalls++;
      installationSkillHistory.add(
        SkillSummary(
          packagePath: item.packagePath,
          installName: item.name,
          name: item.name,
          path: item.skillPath,
          latestVersion: item.version,
        ),
      );
      installationVersionHistory.add(item.version);
      executionSelectionHistory.add([
        for (final target in item.targets)
          InstallationTargetSelection(
            scope: target.scope,
            projectRoot: target.projectRoot,
            agent: target.agent,
          ),
      ]);
    }
    var failed = false;
    var reason = '';
    if (installCompleter != null) {
      final command = await installCompleter!.future;
      failed = !command.succeeded;
      reason = command.output.stderr;
    }
    return BatchAdoptionResult(
      adopted: failed ? 0 : items.length,
      failed: failed ? items.length : 0,
      items: [
        for (final item in items)
          BatchAdoptionItemResult(
            name: item.name,
            skillId: '${item.packagePath}:${item.skillPath}',
            status: failed
                ? BatchAdoptionItemStatus.failed
                : BatchAdoptionItemStatus.adopted,
            reason: reason,
          ),
      ],
    );
  }

  @override
  Future<List<AdoptionBackup>> listAdoptionBackups() async =>
      List.unmodifiable(adoptionBackups);

  @override
  Future<void> restoreAdoptionBackup(String backupId) async {
    final index = adoptionBackups.indexWhere((backup) => backup.id == backupId);
    if (index < 0) {
      throw const SkillsException(
        'Adoption backup not found.',
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
    adoptionBackups.removeAt(index);
  }

  @override
  Future<List<InstallationExecution>> installPackageTargets(
    List<SkillSummary> skills,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    repositoryInstallCalls++;
    return Future.wait([
      for (final skill in skills)
        installTargets(
          skill,
          skill.latestVersion,
          selections,
          confirmRisk: confirmRisk,
          allowCritical: allowCritical,
        ),
    ]);
  }

  @override
  Future<InstallationExecution> installTargets(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    if (installPlanErrors.isNotEmpty) throw installPlanErrors.removeAt(0);
    installCalls++;
    installationSkillHistory.add(skill);
    installationVersionHistory.add(immutableVersion);
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
              path: selection.scope == InstallationScope.global
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
      final index = entries.indexWhere(
        (entry) =>
            entry.packagePath == skill.packagePath && entry.name == skill.name,
      );
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
      packagePath: skill.packagePath,
      skillName: skill.name,
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
}
