/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, strict inventory codecs, local filesystem inspection, and Library domain models.
 * [OUTPUT]: Provides Agent catalogs, unified usage-aware local inventory with per-Agent evidence, cached Hub-configured Package avatars and lock-backed External Adoption hints, local Skill detail, and shared structured CLI invocation.
 * [POS]: Serves as the offline-capable local inventory capability inside the DesktopSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'desktop_skills_gateway.dart';

mixin _DesktopSkillsGatewayInventory on _DesktopSkillsGatewayCore {
  @override
  Future<AgentCatalog> inspectOnboardingAgents() async {
    return _parseAgentCatalog(
      await _runCli(const [
        'agents',
        '--output',
        'json',
      ], retryOnTransportFailure: true),
      requireHandshake: true,
    );
  }

  @override
  Future<AgentCatalog> inspectAgents() async => _parseAgentCatalog(
    await _runCli(const [
      'agents',
      '--output',
      'json',
    ], retryOnTransportFailure: true),
  );

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
    bool includeUsage = false,
  }) async {
    final arguments = <String>['list', '--global'];
    for (final project in projects.where(
      (project) => project.accessState == ProjectAccessState.accessible,
    )) {
      arguments.addAll(['--project', project.path]);
    }
    if (includeUsage) arguments.add('--usage');
    arguments.addAll(['--output', 'json']);
    final result = await _runCli(arguments, retryOnTransportFailure: true);
    if (!result.succeeded) throw _commandFailure(result);
    _beginHubInfoRefresh();
    // Keep the offline-first Library bounded while avoiding a direct GitHub
    // avatar request before the Hub's image policy is known. Usage enrichment
    // runs after first paint, so it can wait for the policy and reproject images.
    await _waitForHubInfoRefresh(
      timeout: includeUsage ? null : const Duration(milliseconds: 100),
    );
    try {
      final decoded = _decodeVersionedDocument(
        result.output.stdout,
        schemaVersion: _inventorySchemaVersion,
      );
      if (decoded['entries'] is! List) {
        throw const FormatException();
      }
      final entries = (decoded['entries'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['inventoryKey'] is! String ||
                (raw['inventoryKey'] as String).isEmpty ||
                raw['name'] is! String ||
                (raw['name'] as String).isEmpty ||
                (raw['description'] != null && raw['description'] is! String) ||
                (raw['packagePath'] != null && raw['packagePath'] is! String) ||
                (raw['adoptionPackagePath'] != null &&
                    raw['adoptionPackagePath'] is! String) ||
                raw['versionDivergence'] is! bool ||
                (raw['usagePending'] != null && raw['usagePending'] is! bool) ||
                raw['usage'] is! Map<String, dynamic> ||
                (raw['usageByAgent'] != null &&
                    raw['usageByAgent'] is! Map<String, dynamic>) ||
                raw['targets'] is! List ||
                raw['visibility'] is! List) {
              throw const FormatException();
            }
            final provenance = _libraryProvenance(raw['provenance']);
            final usage = raw['usage'] as Map<String, dynamic>;
            if (usage['hits45Days'] is! int ||
                usage['hits90Days'] is! int ||
                (usage['hits45Days'] as int) < 0 ||
                (usage['hits90Days'] as int) < (usage['hits45Days'] as int)) {
              throw const FormatException();
            }
            final usageByAgent = _parseUsageByAgent(raw['usageByAgent']);
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
                    (raw['adoptionPackagePath'] as String? ?? '').isNotEmpty ||
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
              imageUrl: _resolvePackageImageUrl(
                raw['packagePath'] as String? ?? '',
              ),
              targets: targets,
              visibility: visibility,
              provenance: provenance,
              health: _installationHealth(raw['health']),
              projects: projectRoots,
              versions: versions,
              versionDivergence: raw['versionDivergence'] as bool,
              adoptionPackagePath: raw['adoptionPackagePath'] as String? ?? '',
              hits45Days: usage['hits45Days'] as int,
              hits90Days: usage['hits90Days'] as int,
              usageByAgent: usageByAgent,
              usageState: includeUsage
                  ? (raw['usagePending'] == true
                        ? SkillUsageState.loading
                        : raw['usageByAgent'] is Map<String, dynamic>
                        ? SkillUsageState.available
                        : raw['usageAvailable'] == true
                        ? SkillUsageState.available
                        : SkillUsageState.unavailable)
                  : SkillUsageState.loading,
            );
          })
          .toList(growable: false);
      return entries;
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid inventory JSON.',
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
  }

  Map<String, SkillAgentUsage> _parseUsageByAgent(Object? raw) {
    if (raw == null) return const {};
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final result = <String, SkillAgentUsage>{};
    for (final entry in raw.entries) {
      if (entry.key.isEmpty || entry.value is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final value = entry.value as Map<String, dynamic>;
      final hits45Days = value['hits45Days'];
      final hits90Days = value['hits90Days'];
      final rawError = value['error'];
      if (rawError != null && rawError is! String) {
        throw const FormatException();
      }
      final error = rawError as String? ?? '';
      if (hits45Days is! int ||
          hits90Days is! int ||
          hits45Days < 0 ||
          hits90Days < hits45Days) {
        throw const FormatException();
      }
      result[entry.key] = SkillAgentUsage(
        hits45Days: hits45Days,
        hits90Days: hits90Days,
        error: error,
      );
    }
    return Map.unmodifiable(result);
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
