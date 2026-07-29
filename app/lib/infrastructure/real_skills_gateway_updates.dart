/*
 * [INPUT]: Depends on installed Package scope identity, an explicit immutable target version, CLI Package update, and mutation-free scope Package previews.
 * [OUTPUT]: Provides direct Package-level update commands followed by identity-only receipt validation, plus Scope-by-Package previews without Skill-level compatibility projection or Hub requests.
 * [POS]: Serves as the thin Package Update capability inside RealSkillsGateway while leaving preview and execution rules in the CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayUpdates
    on _RealSkillsGatewayCore, _RealSkillsGatewayExecutionSupport {
  List<String> _packageUpdateScopeArguments(
    InstallationScope scope,
    String projectRoot,
  ) => scope == InstallationScope.global
      ? const ['--global']
      : ['--project', projectRoot];

  @override
  Future<void> updatePackage(
    InstalledSkill skill, {
    required String toVersion,
  }) async {
    if (skill.provenance != LibraryProvenance.hub ||
        skill.packagePath.isEmpty ||
        skill.targets.isEmpty ||
        toVersion.trim().isEmpty ||
        skill.targets.any(
          (target) =>
              target.version.isEmpty ||
              (target.scope == InstallationScope.project &&
                  target.projectRoot.isEmpty),
        )) {
      throw const SkillsException(
        'Package update requires managed scopes and an explicit immutable candidate.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final scopes = <String, SkillInstallationTarget>{};
    for (final target in skill.targets) {
      if (target.version == toVersion) continue;
      scopes['${target.scope.name}\u0000${target.projectRoot}'] = target;
    }
    if (scopes.isEmpty) return;
    late CommandResult command;
    try {
      for (final target in scopes.values) {
        command = await _runCli([
          'update',
          '${skill.packagePath}@$toVersion',
          ..._packageUpdateScopeArguments(target.scope, target.projectRoot),
          '--yes',
          '--output',
          'json',
          '--hub',
          _hubOrigin,
        ]);
        if (!command.succeeded) throw _commandFailure(command);
        final raw = _decodeMachineDocument(
          command.output.stdout,
          phase: 'package-update',
        );
        final expectedScope = target.scope.name;
        final expectedProjectRoot = target.scope == InstallationScope.project
            ? target.projectRoot
            : '';
        if (raw['packagePath'] != skill.packagePath ||
            raw['toVersion'] != toVersion ||
            raw['scope'] != expectedScope ||
            (raw['projectRoot'] ?? '') != expectedProjectRoot) {
          throw const FormatException();
        }
      }
    } on Object catch (error, stackTrace) {
      if (error is! FormatException && error is! TypeError) rethrow;
      throw _invalidCliResponse(
        'update_package',
        'The SkillsGo CLI returned invalid Package Update JSON.',
        command,
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<Map<String, UpdateAvailability>> checkUpdates(
    List<InstalledSkill> skills,
  ) async {
    final states = <String, UpdateAvailability>{};
    final scopes = <String, SkillInstallationTarget>{};
    for (final skill in skills) {
      if (skill.provenance != LibraryProvenance.hub ||
          skill.packagePath.isEmpty) {
        continue;
      }
      for (final target in skill.targets) {
        if (target.version.trim().isEmpty ||
            (target.scope == InstallationScope.project &&
                target.projectRoot.trim().isEmpty)) {
          continue;
        }
        scopes['${target.scope.name}\u0000${target.projectRoot}'] = target;
      }
    }
    if (scopes.isEmpty) return states;

    await _ensureHubOrigin();
    try {
      final command = await _runCli([
        'update',
        '--all',
        '--dry-run',
        '--output',
        'json',
        '--hub',
        _hubOrigin,
      ]);
      if (!command.succeeded && command.output.stdout.trim().isEmpty) {
        throw _commandFailure(command);
      }
      final decoded = _decodeMachineDocument(
        command.output.stdout,
        phase: 'package-update-preview',
      );
      if (decoded['updates'] is! List) throw const FormatException();
      for (final raw in decoded['updates'] as List) {
        if (raw is! Map<String, dynamic> ||
            raw['packagePath'] is! String ||
            raw['scope'] is! String ||
            raw['status'] is! String ||
            raw['toVersion'] is! String ||
            raw['selectedSkillCount'] is! int ||
            raw['removedSkills'] is! List) {
          throw const FormatException();
        }
        final scope = switch (raw['scope']) {
          'global' => InstallationScope.global,
          'project' => InstallationScope.project,
          _ => throw const FormatException(),
        };
        final projectRoot = raw['projectRoot'] as String? ?? '';
        final removed = (raw['removedSkills'] as List)
            .map((entry) {
              if (entry is! Map<String, dynamic> ||
                  entry['name'] is! String ||
                  entry['path'] is! String) {
                throw const FormatException();
              }
              return RemovedSkillImpact(
                name: entry['name'] as String,
                path: entry['path'] as String,
              );
            })
            .toList(growable: false);
        states[packageScopeUpdateKey(
          raw['packagePath'] as String,
          scope,
          projectRoot,
        )] = UpdateAvailability(
          state: switch (raw['status']) {
            'up_to_date' => UpdateState.upToDate,
            'update_available' => UpdateState.available,
            'blocked' || 'failed' => UpdateState.failed,
            _ => throw const FormatException(),
          },
          toVersion: raw['status'] == 'update_available'
              ? raw['toVersion'] as String
              : '',
          selectedSkillCount: raw['selectedSkillCount'] as int,
          removedSkills: removed,
        );
      }
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Package Update Preview JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
    return states;
  }
}
