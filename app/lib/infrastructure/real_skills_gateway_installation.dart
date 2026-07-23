/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, Installation Request codecs, file save picker, and discovery/Library models.
 * [OUTPUT]: Provides exact-path Repository Vendor installation grouped by declaration scope.
 * [POS]: Serves as the Installation Request capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayInstallation on _RealSkillsGatewayCore {
  @override
  Future<InstallationExecution> installTargets(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    if (immutableVersion.isEmpty || selections.isEmpty) {
      throw const SkillsException(
        'Select at least one Installation Target.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final repositoryID = skill.repositoryId;
    final groups = <String, List<InstallationTargetSelection>>{};
    for (final selection in selections) {
      final key = '${selection.scope.name}\u0000${selection.projectRoot}';
      groups.putIfAbsent(key, () => []).add(selection);
    }
    final results = <InstallationTargetResult>[];
    for (final group in groups.values) {
      final first = group.first;
      final arguments = <String>[
        'add',
        '$repositoryID@$immutableVersion',
        '--skill-path',
        skill.installationSelector,
        for (final selection in group) ...['--agent', selection.agent],
        if (first.scope == InstallationScope.user) '--global',
        if (first.scope == InstallationScope.project) ...[
          '--project',
          first.projectRoot,
        ],
        '--yes',
        '--output',
        'json',
        '--hub',
        _hubOrigin,
      ];
      final command = await _runCli(arguments);
      if (!command.succeeded) throw _commandFailure(command);
      try {
        results.addAll(
          _repositoryInstallationResults(
            jsonDecode(command.output.stdout),
            skill,
            immutableVersion,
            group,
          ),
        );
      } on FormatException {
        throw const SkillsException(
          'The SkillsGo CLI returned invalid Repository Installation JSON.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
    }
    return InstallationExecution(
      repositoryId: skill.repositoryId,
      skillName: skill.name,
      version: immutableVersion,
      name: skill.installName,
      results: List.unmodifiable(results),
      summary: InstallationExecutionSummary(
        succeeded: results.length,
        skipped: 0,
        conflict: 0,
        failed: 0,
      ),
    );
  }
}
