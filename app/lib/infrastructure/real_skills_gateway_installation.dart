/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, Installation Request codecs, file save picker, and discovery/Library models.
 * [OUTPUT]: Provides direct multi-target installation, compatibility single-target installation, and Local Skill export.
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
    final arguments = <String>['add', skill.id, '--skill', skill.installName];
    for (final selection in selections) {
      arguments.addAll(['--target', _targetArgument(selection)]);
    }
    arguments.addAll([
      '--version',
      immutableVersion,
      if (confirmRisk) '--confirm-risk',
      if (allowCritical) '--allow-critical',
      '--yes',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
    ]);
    final command = await _runCli(arguments);
    try {
      return _directInstallationExecution(
        jsonDecode(command.output.stdout),
        skill,
        immutableVersion,
        selections,
      );
    } on FormatException {
      if (!command.succeeded) throw _commandFailure(command);
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Installation Result JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<CommandResult> install(SkillSummary skill) async {
    await _ensureHubOrigin();
    return _runCli([
      'add',
      skill.id,
      '--skill',
      skill.installName,
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
