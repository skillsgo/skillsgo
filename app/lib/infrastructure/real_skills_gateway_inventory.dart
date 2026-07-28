/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, strict inventory codecs, local filesystem inspection, and Library domain models.
 * [OUTPUT]: Provides Agent catalogs, unified local inventory, local Skill detail, and shared structured CLI invocation.
 * [POS]: Serves as the offline-capable local inventory capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayInventory on _RealSkillsGatewayCore {
  @override
  Future<AgentCatalog> inspectOnboardingAgents() async {
    final arguments = const ['agents', '--output', 'json'];
    final output = await _runner.run(_bundledCliPath, arguments);
    return _parseAgentCatalog(
      CommandResult(command: [_bundledCliPath, ...arguments], output: output),
      requireHandshake: true,
    );
  }

  @override
  Future<AgentCatalog> inspectAgents() async =>
      _parseAgentCatalog(await _runCli(const ['agents', '--output', 'json']));

  AgentCatalog _parseAgentCatalog(
    CommandResult result, {
    bool requireHandshake = false,
  }) {
    if (!result.succeeded) throw _commandFailure(result);
    try {
      final decoded = _decodeVersionedDocument(
        result.output.stdout,
        schemaVersion: 2,
      );
      if (decoded['agents'] is! List) {
        throw const FormatException();
      }
      if (requireHandshake &&
          (decoded['product'] != 'skillsgo' ||
              decoded['version'] is! String ||
              (decoded['version'] as String).trim().isEmpty ||
              decoded['appProtocolVersion'] != _appProtocolVersion ||
              decoded['os'] != _expectedCliOS ||
              decoded['architecture'] is! String ||
              (decoded['architecture'] as String).trim().isEmpty)) {
        throw const FormatException();
      }
      final seen = <String>{};
      final agents = (decoded['agents'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['id'] is! String ||
                (raw['id'] as String).isEmpty ||
                raw['displayName'] is! String ||
                (raw['displayName'] as String).isEmpty ||
                raw['installed'] is! bool ||
                raw['supportedScopes'] is! List ||
                !seen.add(raw['id'] as String)) {
              throw const FormatException();
            }
            final scopes = (raw['supportedScopes'] as List)
                .map(_installationScope)
                .toList(growable: false);
            if (scopes.isEmpty || scopes.toSet().length != scopes.length) {
              throw const FormatException();
            }
            final rawTarget = raw['globalTarget'];
            AgentGlobalTarget? target;
            if (rawTarget != null) {
              if (rawTarget is! Map<String, dynamic> ||
                  rawTarget['path'] is! String ||
                  (rawTarget['path'] as String).isEmpty ||
                  rawTarget['exists'] is! bool) {
                throw const FormatException();
              }
              target = AgentGlobalTarget(
                path: rawTarget['path'] as String,
                exists: rawTarget['exists'] as bool,
              );
            }
            if (scopes.contains(InstallationScope.global) != (target != null)) {
              throw const FormatException();
            }
            final rawDiscoveryRoots = raw['discoveryRoots'];
            if (rawDiscoveryRoots != null &&
                (rawDiscoveryRoots is! List ||
                    rawDiscoveryRoots.any(
                      (root) => root is! String || root.isEmpty,
                    ))) {
              throw const FormatException();
            }
            final discoveryRoots = rawDiscoveryRoots == null
                ? <String>[if (target != null) target.path]
                : List<String>.unmodifiable(rawDiscoveryRoots.cast<String>());
            return AgentStatus(
              id: raw['id'] as String,
              displayName: raw['displayName'] as String,
              installed: raw['installed'] as bool,
              supportedScopes: scopes,
              globalTarget: target,
              discoveryRoots: discoveryRoots,
            );
          })
          .toList(growable: false);
      return AgentCatalog(schemaVersion: 2, agents: agents);
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Agent JSON.',
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
  }

  @override
  Future<List<InstalledSkill>> listInstalled({
    List<AddedProject> projects = const [],
  }) async {
    final arguments = <String>['list', '--global'];
    for (final project in projects.where(
      (project) => project.accessState == ProjectAccessState.accessible,
    )) {
      arguments.addAll(['--project', project.path]);
    }
    arguments.addAll(['--output', 'json']);
    final result = await _runCli(arguments);
    if (!result.succeeded) throw _commandFailure(result);
    try {
      final decoded = _decodeVersionedDocument(
        result.output.stdout,
        schemaVersion: _inventorySchemaVersion,
      );
      if (decoded['entries'] is! List) {
        throw const FormatException();
      }
      return (decoded['entries'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['inventoryKey'] is! String ||
                (raw['inventoryKey'] as String).isEmpty ||
                raw['name'] is! String ||
                (raw['name'] as String).isEmpty ||
                (raw['description'] != null && raw['description'] is! String) ||
                (raw['packagePath'] != null && raw['packagePath'] is! String) ||
                raw['versionDivergence'] is! bool ||
                raw['targets'] is! List ||
                raw['visibility'] is! List) {
              throw const FormatException();
            }
            final provenance = _libraryProvenance(raw['provenance']);
            final targetKeys = <String>{};
            final targets = (raw['targets'] as List)
                .map((target) {
                  if (target is! Map<String, dynamic> ||
                      target['agent'] is! String ||
                      (target['agent'] as String).isEmpty ||
                      target['path'] is! String ||
                      (target['path'] as String).isEmpty ||
                      target['version'] is! String ||
                      (target['projectRoot'] != null &&
                          target['projectRoot'] is! String)) {
                    throw const FormatException();
                  }
                  final scope = _installationScope(target['scope']);
                  final projectRoot = target['projectRoot'] as String? ?? '';
                  final version = target['version'] as String;
                  if ((scope == InstallationScope.project &&
                          projectRoot.isEmpty) ||
                      (scope == InstallationScope.global &&
                          projectRoot.isNotEmpty) ||
                      (provenance == LibraryProvenance.external &&
                          version.isNotEmpty) ||
                      (provenance != LibraryProvenance.external &&
                          version.isEmpty) ||
                      !targetKeys.add(
                        '${target['agent']}\u0000${target['scope']}\u0000${target['path']}',
                      )) {
                    throw const FormatException();
                  }
                  return SkillInstallationTarget(
                    agent: target['agent'] as String,
                    scope: scope,
                    path: target['path'] as String,
                    version: version,
                    projectRoot: projectRoot,
                    health: _installationHealth(target['health']),
                  );
                })
                .toList(growable: false);
            if (targets.isEmpty) throw const FormatException();
            final agents = _strictStringList(raw['agents']);
            final projectRoots = _strictStringList(raw['projects']);
            final versions = _strictStringList(raw['versions']);
            final visibilityKeys = <String>{};
            final visibility = (raw['visibility'] as List)
                .map((item) {
                  if (item is! Map<String, dynamic> ||
                      item['agent'] is! String ||
                      (item['agent'] as String).isEmpty ||
                      item['paths'] is! List ||
                      (item['projectRoot'] != null &&
                          item['projectRoot'] is! String)) {
                    throw const FormatException();
                  }
                  final scope = _installationScope(item['scope']);
                  final projectRoot = item['projectRoot'] as String? ?? '';
                  final paths = _strictStringList(item['paths']);
                  final key =
                      '${item['agent']}\u0000${item['scope']}\u0000$projectRoot';
                  if (paths.isEmpty ||
                      (scope == InstallationScope.project &&
                          projectRoot.isEmpty) ||
                      (scope == InstallationScope.global &&
                          projectRoot.isNotEmpty) ||
                      !visibilityKeys.add(key)) {
                    throw const FormatException();
                  }
                  return SkillVisibility(
                    agent: item['agent'] as String,
                    scope: scope,
                    projectRoot: projectRoot,
                    paths: paths,
                    verification: _discoveryVerification(item['verification']),
                  );
                })
                .toList(growable: false);
            if ((provenance != LibraryProvenance.external &&
                    versions.isEmpty) ||
                !_sameStringSet(
                  agents,
                  targets.map((target) => target.agent),
                ) ||
                !_sameStringSet(
                  projectRoots,
                  targets
                      .map((target) => target.projectRoot)
                      .where((root) => root.isNotEmpty),
                ) ||
                !_sameStringSet(
                  versions,
                  targets
                      .map((target) => target.version)
                      .where((version) => version.isNotEmpty),
                ) ||
                (raw['versionDivergence'] as bool) != (versions.length > 1)) {
              throw const FormatException();
            }
            if (provenance == LibraryProvenance.hub &&
                ((raw['packagePath'] as String? ?? '').isEmpty ||
                    raw['inventoryKey'] !=
                        'hub:${raw['packagePath']}:${raw['name']}')) {
              throw const FormatException();
            }
            if (provenance == LibraryProvenance.external &&
                ((raw['packagePath'] as String? ?? '').isNotEmpty ||
                    versions.isNotEmpty ||
                    !(raw['inventoryKey'] as String).startsWith('external:'))) {
              throw const FormatException();
            }
            return InstalledSkill(
              inventoryKey: raw['inventoryKey'] as String,
              name: raw['name'] as String,
              description: raw['description'] as String? ?? '',
              path: targets.first.path,
              agents: agents,
              targetCount: targets.length,
              packagePath: raw['packagePath'] as String? ?? '',
              targets: targets,
              visibility: visibility,
              provenance: provenance,
              health: _installationHealth(raw['health']),
              projects: projectRoots,
              versions: versions,
              versionDivergence: raw['versionDivergence'] as bool,
            );
          })
          .toList(growable: false);
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid inventory JSON.',
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
  }

  @override
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill) async {
    final immutableVersions = {
      ...skill.versions.where((version) => version.isNotEmpty),
      ...skill.targets
          .map((target) => target.version)
          .where((version) => version.isNotEmpty),
    };
    final targetPaths = skill.targets.isEmpty
        ? [skill.path]
        : ([...skill.targets]..sort(
                (left, right) => _localTargetReadRank(
                  left,
                ).compareTo(_localTargetReadRank(right)),
              ))
              .map((target) => target.path)
              .toList(growable: false);
    FileSystemException? lastFileError;
    for (final targetPath in targetPaths) {
      try {
        final markdown = await File(
          p.join(targetPath, 'SKILL.md'),
        ).readAsString();
        if (markdown.trim().isEmpty) continue;
        return SkillDetail(
          name: skill.name,
          path: targetPath,
          content: markdown,
          packagePath: skill.packagePath,
          version: immutableVersions.length == 1
              ? immutableVersions.single
              : '',
          installationTargets: skill.targets,
        );
      } on FileSystemException catch (error) {
        lastFileError = error;
      }
    }
    throw SkillsException(
      lastFileError == null
          ? 'The local SKILL.md is empty.'
          : 'Cannot read local Skill: ${lastFileError.message}',
    );
  }
}
