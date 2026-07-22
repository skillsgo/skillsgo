/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, Installation Request codecs, file save picker, and discovery/Library models.
 * [OUTPUT]: Provides Repository Vendor installation grouped by declaration scope, compatibility single-target installation, and Local Skill export.
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
    final repositoryID = skill.id.split('/-/').first;
    final memberPath = skill.id.contains('/-/')
        ? skill.id.split('/-/').last
        : '.';
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
        '--skill',
        memberPath,
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
      skillId: skill.id,
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

  @override
  Future<CommandResult> install(SkillSummary skill) async {
    await _ensureHubOrigin();
    return _runCli([
      'add',
      '${skill.id.split('/-/').first}@${skill.latestVersion}',
      '--skill',
      skill.id.contains('/-/') ? skill.id.split('/-/').last : '.',
      '--global',
      '--agent',
      'codex',
      '--yes',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
    ]);
  }

  @override
  Future<CommandResult?> exportLocalSkill(InstalledSkill skill) async {
    if (skill.provenance != LibraryProvenance.local || skill.targets.isEmpty) {
      throw const SkillsException(
        'Only managed private Local Skills can be exported.',
        kind: SkillsFailureKind.validation,
      );
    }
    final versions = skill.targets
        .map((target) => target.version)
        .where((version) => version.isNotEmpty)
        .toSet();
    if (skill.skillId.isEmpty || versions.length != 1) {
      throw const SkillsException(
        'Local Skill export requires one immutable version.',
        kind: SkillsFailureKind.validation,
      );
    }
    final destination = await _savePathPicker('${skill.name}.zip');
    if (destination == null) return null;
    final result = await _runCli([
      'export',
      '--skill-id',
      skill.skillId,
      '--version',
      versions.single,
      '--destination',
      destination,
      '--output',
      'json',
    ]);
    if (!result.succeeded) return result;
    try {
      final raw = jsonDecode(result.output.stdout);
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] != 1 ||
          raw['phase'] != 'local-export' ||
          raw['skillId'] != skill.skillId ||
          raw['version'] != versions.single ||
          raw['destination'] != destination) {
        throw const FormatException();
      }
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Local Skill export JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
    return result;
  }
}
