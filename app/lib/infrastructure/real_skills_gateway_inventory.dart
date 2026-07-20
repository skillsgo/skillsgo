/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, strict inventory codecs, local filesystem inspection, and Library domain models.
 * [OUTPUT]: Provides Agent catalogs, unified local inventory, exact Batch Takeover planning with safe identity previews and named scope-bound execution results, local Skill detail, and shared structured CLI invocation.
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
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['agents'] is! List) {
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
            final rawTarget = raw['userTarget'];
            AgentUserTarget? target;
            if (rawTarget != null) {
              if (rawTarget is! Map<String, dynamic> ||
                  rawTarget['path'] is! String ||
                  (rawTarget['path'] as String).isEmpty ||
                  rawTarget['exists'] is! bool) {
                throw const FormatException();
              }
              target = AgentUserTarget(
                path: rawTarget['path'] as String,
                exists: rawTarget['exists'] as bool,
              );
            }
            if (scopes.contains(InstallationScope.user) != (target != null)) {
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
              userTarget: target,
              discoveryRoots: discoveryRoots,
            );
          })
          .toList(growable: false);
      return AgentCatalog(schemaVersion: 1, agents: agents);
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
    final arguments = <String>['inventory', '--user'];
    for (final project in projects.where(
      (project) => project.accessState == ProjectAccessState.accessible,
    )) {
      arguments.addAll(['--project', project.path]);
    }
    arguments.addAll(['--output', 'json']);
    final result = await _runCli(arguments);
    if (!result.succeeded) throw _commandFailure(result);
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != _inventorySchemaVersion ||
          decoded['entries'] is! List) {
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
                raw['skillId'] is! String ||
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
                  final mode = _installationMode(target['mode']);
                  if ((scope == InstallationScope.project &&
                          projectRoot.isEmpty) ||
                      (scope == InstallationScope.user &&
                          projectRoot.isNotEmpty) ||
                      (provenance == LibraryProvenance.external &&
                          (version.isNotEmpty ||
                              mode != InstallationMode.external)) ||
                      (provenance != LibraryProvenance.external &&
                          (version.isEmpty ||
                              mode == InstallationMode.external)) ||
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
                    mode: mode,
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
                      (scope == InstallationScope.user &&
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
                ((raw['skillId'] as String).isEmpty ||
                    raw['inventoryKey'] != 'hub:${raw['skillId']}')) {
              throw const FormatException();
            }
            if (provenance == LibraryProvenance.external &&
                ((raw['skillId'] as String).isNotEmpty ||
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
              skillId: raw['skillId'] as String,
              targets: targets,
              visibility: visibility,
              provenance: provenance,
              riskAssessment: _riskAssessment(raw['risk']),
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
  Future<BatchTakeoverPlan> planBatchTakeover({
    List<String> projectRoots = const [],
  }) async {
    final normalizedProjects = _normalizeTakeoverProjectRoots(projectRoots);
    final arguments = <String>[
      'takeover',
      '--preflight',
      '--user',
      for (final projectRoot in normalizedProjects) ...[
        '--project',
        projectRoot,
      ],
      '--output',
      'json',
    ];
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final raw = jsonDecode(command.output.stdout);
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] != 3 ||
          raw['planId'] is! String ||
          (raw['planId'] as String).isEmpty ||
          raw['summary'] is! Map<String, dynamic> ||
          raw['scopes'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final summary = raw['summary'] as Map<String, dynamic>;
      final eligible = summary['eligible'];
      final skipped = summary['skipped'];
      final scopes = raw['scopes'] as Map<String, dynamic>;
      final previewItems = raw['previews'];
      final user = scopes['user'];
      final projects = scopes['projects'];
      if (eligible is! int ||
          eligible < 0 ||
          skipped is! int ||
          skipped < 0 ||
          user is! Map<String, dynamic> ||
          user['eligible'] is! int ||
          (user['eligible'] as int) < 0 ||
          projects is! List ||
          previewItems is! List) {
        throw const FormatException();
      }
      final eligibleCountByProjectRoot = <String, int>{};
      for (final item in projects) {
        if (item is! Map<String, dynamic> ||
            item['projectRoot'] is! String ||
            (item['projectRoot'] as String).isEmpty ||
            item['eligible'] is! int ||
            (item['eligible'] as int) < 0 ||
            eligibleCountByProjectRoot.containsKey(item['projectRoot'])) {
          throw const FormatException();
        }
        eligibleCountByProjectRoot[item['projectRoot'] as String] =
            item['eligible'] as int;
      }
      if (eligibleCountByProjectRoot.length != normalizedProjects.length ||
          normalizedProjects.any(
            (root) => !eligibleCountByProjectRoot.containsKey(root),
          )) {
        throw const FormatException();
      }
      final previews = <BatchTakeoverPreview>[];
      for (final item in previewItems) {
        if (item is! Map<String, dynamic> ||
            item['name'] is! String ||
            (item['name'] as String).trim().isEmpty ||
            item['skillId'] is! String ||
            item['scope'] is! String ||
            (item['projectRoot'] != null && item['projectRoot'] is! String)) {
          throw const FormatException();
        }
        previews.add(
          BatchTakeoverPreview(
            name: item['name'] as String,
            skillId: item['skillId'] as String,
            scope: _installationScope(item['scope']),
            projectRoot: item['projectRoot'] as String? ?? '',
          ),
        );
      }
      return BatchTakeoverPlan(
        id: raw['planId'] as String,
        allEligibleCount: eligible,
        userEligibleCount: user['eligible'] as int,
        eligibleCountByProjectRoot: Map.unmodifiable(
          eligibleCountByProjectRoot,
        ),
        previews: List.unmodifiable(previews),
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Batch Takeover preflight JSON.',
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
  }

  @override
  Future<BatchTakeoverResult> executeBatchTakeover(
    BatchTakeoverPlan plan,
    BatchTakeoverScope scope,
  ) async {
    if (plan.id.trim().isEmpty) {
      throw const SkillsException(
        'Batch Takeover requires a preflight plan.',
        kind: SkillsFailureKind.validation,
      );
    }
    final includeUser = scope.kind != BatchTakeoverScopeKind.project;
    final projectRoots = switch (scope.kind) {
      BatchTakeoverScopeKind.all => plan.eligibleCountByProjectRoot.keys.toList(
        growable: false,
      ),
      BatchTakeoverScopeKind.user => const <String>[],
      BatchTakeoverScopeKind.project => [scope.projectRoot],
    };
    final normalizedProjects = _normalizeTakeoverProjectRoots(projectRoots);
    if (scope.kind == BatchTakeoverScopeKind.project &&
        !plan.eligibleCountByProjectRoot.containsKey(
          normalizedProjects.single,
        )) {
      throw const SkillsException(
        'Batch Takeover Project is not authorized by the plan.',
        kind: SkillsFailureKind.validation,
      );
    }
    final arguments = <String>[
      'takeover',
      '--plan',
      plan.id,
      if (includeUser) '--user',
      for (final projectRoot in normalizedProjects) ...[
        '--project',
        projectRoot,
      ],
      '--yes',
      '--output',
      'json',
    ];
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final raw = jsonDecode(command.output.stdout);
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] != 3 ||
          raw['summary'] is! Map<String, dynamic> ||
          raw['results'] is! List) {
        throw const FormatException();
      }
      final summary = raw['summary'] as Map<String, dynamic>;
      final takenOver = summary['takenOver'];
      final skipped = summary['skipped'];
      if (takenOver is! int ||
          takenOver < 0 ||
          skipped is! int ||
          skipped < 0) {
        throw const FormatException();
      }
      var actualTakenOver = 0;
      var actualSkipped = 0;
      final items = <BatchTakeoverItemResult>[];
      for (final item in raw['results'] as List) {
        if (item is! Map<String, dynamic> ||
            item['name'] is! String ||
            (item['name'] as String).trim().isEmpty ||
            item['status'] is! String ||
            item['target'] is! Map<String, dynamic> ||
            (item['reason'] != null && item['reason'] is! String)) {
          throw const FormatException();
        }
        final target = item['target'] as Map<String, dynamic>;
        if (target['scope'] != 'user' && target['scope'] != 'project' ||
            target['mode'] != 'copy' && target['mode'] != 'symlink' ||
            target['path'] is! String ||
            (target['projectRoot'] != null &&
                target['projectRoot'] is! String)) {
          throw const FormatException();
        }
        switch (item['status']) {
          case 'taken-over':
            if (item['skillId'] is! String ||
                (item['skillId'] as String).isEmpty ||
                item['version'] is! String ||
                (item['version'] as String).isEmpty ||
                (target['path'] as String).isEmpty) {
              throw const FormatException();
            }
            actualTakenOver++;
            items.add(
              BatchTakeoverItemResult(
                name: item['name'] as String,
                skillId: item['skillId'] as String,
                status: BatchTakeoverItemStatus.takenOver,
              ),
            );
          case 'skipped':
            if (item['reason'] is! String ||
                (item['reason'] as String).isEmpty) {
              throw const FormatException();
            }
            actualSkipped++;
            items.add(
              BatchTakeoverItemResult(
                name: item['name'] as String,
                skillId: item['skillId'] as String? ?? '',
                status: BatchTakeoverItemStatus.skipped,
                reason: item['reason'] as String,
              ),
            );
          default:
            throw const FormatException();
        }
      }
      if (actualTakenOver != takenOver || actualSkipped != skipped) {
        throw const FormatException();
      }
      return BatchTakeoverResult(
        takenOver: takenOver,
        skipped: skipped,
        items: List.unmodifiable(items),
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Batch Takeover JSON.',
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
  }

  List<String> _normalizeTakeoverProjectRoots(List<String> projectRoots) {
    final normalizedProjects = <String>[];
    final seenProjects = <String>{};
    for (final projectRoot in projectRoots) {
      final normalized = p.normalize(p.absolute(projectRoot.trim()));
      if (normalized.isEmpty) {
        throw const SkillsException(
          'Batch Takeover Workspace must not be empty.',
          kind: SkillsFailureKind.validation,
        );
      }
      if (seenProjects.add(normalized)) normalizedProjects.add(normalized);
    }
    return normalizedProjects;
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
        final files = await _inspectLocalFiles(targetPath);
        final executableFiles = files
            .where((file) => file.executable)
            .map(
              (file) => SkillRiskEvidence(
                code: 'executable-content',
                path: file.path,
              ),
            )
            .toList(growable: false);
        return SkillDetail(
          name: skill.name,
          source: switch (skill.provenance) {
            LibraryProvenance.hub => 'Hub',
            LibraryProvenance.local => 'Local',
            LibraryProvenance.external => 'External',
          },
          markdown: markdown,
          files: files,
          immutableVersion: immutableVersions.length == 1
              ? immutableVersions.single
              : '',
          riskAssessment: skill.riskAssessment,
          riskEvidence: executableFiles,
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
