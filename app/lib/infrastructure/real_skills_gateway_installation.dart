/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, Installation Request codecs, file save picker, and discovery/Library models.
 * [OUTPUT]: Provides single-Skill and atomic multi-Skill exact-path Repository Vendor installation grouped by declaration scope.
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
    final executions = await _installRepositoryMembers(
      [skill],
      immutableVersion,
      selections,
    );
    return executions.single;
  }

  @override
  Future<List<InstallationExecution>> installRepositoryTargets(
    List<SkillSummary> skills,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    if (skills.isEmpty) {
      throw const SkillsException(
        'Select at least one Repository Skill.',
        kind: SkillsFailureKind.validation,
      );
    }
    final repositoryID = skills.first.repositoryId;
    final immutableVersion = skills.first.latestVersion;
    if (skills.any(
      (skill) =>
          skill.repositoryId != repositoryID ||
          skill.latestVersion != immutableVersion,
    )) {
      throw const SkillsException(
        'Repository installation requires one Repository version.',
        kind: SkillsFailureKind.validation,
      );
    }
    return _installRepositoryMembers(skills, immutableVersion, selections);
  }

  Future<List<InstallationExecution>> _installRepositoryMembers(
    List<SkillSummary> skills,
    String immutableVersion,
    List<InstallationTargetSelection> selections,
  ) async {
    if (immutableVersion.isEmpty || selections.isEmpty) {
      throw const SkillsException(
        'Select at least one Installation Target.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final repositoryID = skills.first.repositoryId;
    final groups = <String, List<InstallationTargetSelection>>{};
    for (final selection in selections) {
      final key = '${selection.scope.name}\u0000${selection.projectRoot}';
      groups.putIfAbsent(key, () => []).add(selection);
    }
    final results = [for (final _ in skills) <InstallationTargetResult>[]];
    for (final group in groups.values) {
      final first = group.first;
      final arguments = <String>[
        'add',
        '$repositoryID@$immutableVersion',
        for (final skill in skills) ...[
          '--skill-path',
          skill.installationSelector,
        ],
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
        final payload = jsonDecode(command.output.stdout);
        for (var index = 0; index < skills.length; index++) {
          results[index].addAll(
            _repositoryInstallationResults(
              payload,
              skills[index],
              immutableVersion,
              group,
            ),
          );
        }
      } on FormatException {
        throw const SkillsException(
          'The SkillsGo CLI returned invalid Repository Installation JSON.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
    }
    return List.unmodifiable([
      for (var index = 0; index < skills.length; index++)
        InstallationExecution(
          repositoryId: skills[index].repositoryId,
          skillName: skills[index].name,
          version: immutableVersion,
          name: skills[index].installName,
          results: List.unmodifiable(results[index]),
          summary: InstallationExecutionSummary(
            succeeded: results[index].length,
            skipped: 0,
            conflict: 0,
            failed: 0,
          ),
        ),
    ]);
  }
}
