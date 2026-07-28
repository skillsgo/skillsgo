/*
 * [INPUT]: Depends on installed Package scope identity, an explicit immutable target version, CLI Package update, and Catalog update checks.
 * [OUTPUT]: Provides direct Package-level update commands followed by identity-only receipt validation, plus one latest-only Catalog batch update check.
 * [POS]: Serves as the thin Package Update capability inside RealSkillsGateway without reproducing CLI planning or target execution rules.
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
    final states = {
      for (final skill in skills)
        _installedSkillUpdateKey(skill): const UpdateAvailability(
          state: UpdateState.unsupported,
        ),
    };
    final candidates =
        <
          ({String key, String packagePath, String name, List<String> versions})
        >[];
    for (final skill in skills) {
      if (skill.provenance != LibraryProvenance.hub ||
          skill.packagePath.isEmpty) {
        continue;
      }
      final versions =
          skill.targets
              .map((target) => target.version.trim())
              .where((version) => version.isNotEmpty)
              .toSet()
              .toList(growable: false)
            ..sort();
      if (versions.isEmpty) continue;
      candidates.add((
        key: _installedSkillUpdateKey(skill),
        packagePath: skill.packagePath,
        name: skill.name,
        versions: versions,
      ));
    }
    if (candidates.isEmpty) return states;

    await _ensureHubOrigin();
    final arguments = <String>[
      'hub',
      'check-update',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
      for (final candidate in candidates) ...[
        '--installed',
        jsonEncode({
          'key': candidate.key,
          'packagePath': candidate.packagePath,
          'name': candidate.name,
          'versions': candidate.versions,
        }),
      ],
    ];
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final decoded = _decodeMachineDocument(
        command.output.stdout,
        phase: 'update-check',
      );
      if (decoded['items'] is! List ||
          (decoded['items'] as List).length != candidates.length) {
        throw const FormatException();
      }
      final expected = {for (final candidate in candidates) candidate.key};
      for (final raw in decoded['items'] as List) {
        if (raw is! Map<String, dynamic> ||
            raw['key'] is! String ||
            raw['packagePath'] is! String ||
            raw['name'] is! String ||
            raw['versions'] is! List ||
            raw['status'] is! String ||
            !expected.remove(raw['key'])) {
          throw const FormatException();
        }
        final latestVersion = raw['latestVersion'];
        final latestStatus = raw['latestStatus'];
        if ((latestVersion != null && latestVersion is! String) ||
            (latestStatus != null && latestStatus is! String)) {
          throw const FormatException();
        }
        final toVersion = latestStatus == 'update_available'
            ? latestVersion as String? ?? ''
            : '';
        states[raw['key'] as String] = UpdateAvailability(
          state: switch (raw['status']) {
            'current' => UpdateState.upToDate,
            'update_available' => UpdateState.available,
            'unsupported' => UpdateState.unsupported,
            _ => throw const FormatException(),
          },
          toVersion: toVersion,
        );
      }
      if (expected.isNotEmpty) throw const FormatException();
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Update Check JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
    return states;
  }
}
