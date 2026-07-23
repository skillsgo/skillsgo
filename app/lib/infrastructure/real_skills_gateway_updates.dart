/*
 * [INPUT]: Depends on the shared gateway state, Repository-level CLI update preflight/execution, reviewed Update Plans, and progress callbacks.
 * [OUTPUT]: Provides Repository-coordinate update preflight and execution projected onto selected Library targets, plus one Catalog-only batch update-availability check.
 * [POS]: Serves as the Repository Update capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayUpdates
    on _RealSkillsGatewayCore, _RealSkillsGatewayExecutionSupport {
  List<String> _repositoryUpdateScopeArguments(
    InstallationScope scope,
    String projectRoot,
  ) => scope == InstallationScope.user
      ? const ['--global']
      : ['--project', projectRoot];

  @override
  Future<UpdatePlan> preflightUpdate(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets, {
    String? toVersion,
  }) async {
    if (skill.provenance != LibraryProvenance.hub ||
        skill.repositoryId.isEmpty ||
        targets.isEmpty ||
        toVersion == null ||
        toVersion.isEmpty ||
        targets.any(
          (target) =>
              target.version.isEmpty ||
              (target.scope == InstallationScope.project &&
                  target.projectRoot.isEmpty),
        )) {
      throw const SkillsException(
        'Repository updates require managed targets and an explicit immutable candidate.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final repository = skill.repositoryId;
    try {
      final items = <UpdatePlanItem>[];
      final changes = <WorkspaceManifestChange>[];
      final grouped = <String, List<SkillInstallationTarget>>{};
      for (final target in targets) {
        final key = '${target.scope.name}\u0000${target.projectRoot}';
        grouped.putIfAbsent(key, () => []).add(target);
      }
      for (final group in grouped.values) {
        final representative = group.first;
        if (group.any((target) => target.version != representative.version)) {
          throw const FormatException();
        }
        final command = await _runCli([
          'update',
          '$repository@$toVersion',
          ..._repositoryUpdateScopeArguments(
            representative.scope,
            representative.projectRoot,
          ),
          '--preflight',
          '--output',
          'json',
          '--hub',
          _hubOrigin,
        ]);
        if (!command.succeeded) throw _commandFailure(command);
        final raw = _decodeMachineDocument(
          command.output.stdout,
          phase: 'repository-update-preflight',
        );
        if (raw['repository'] != repository ||
            raw['fromVersion'] != representative.version ||
            raw['toVersion'] != toVersion ||
            raw['stateToken'] is! String ||
            (raw['stateToken'] as String).isEmpty ||
            raw['scope'] != representative.scope.name ||
            (representative.scope == InstallationScope.project &&
                raw['projectRoot'] != representative.projectRoot)) {
          throw const FormatException();
        }
        final stateToken = raw['stateToken'] as String;
        for (final installed in group) {
          items.add(
            UpdatePlanItem(
              target: InstallationPlanTarget(
                scope: installed.scope,
                projectRoot: installed.projectRoot,
                agent: installed.agent,
                path: installed.path,
              ),
              name: skill.name,
              repositoryId: skill.repositoryId,
              sourceRef: repository,
              fromVersion: installed.version,
              toVersion: toVersion,
              action: UpdatePlanAction.update,
              stateToken: stateToken,
              workspaceManifestChange:
                  installed.scope == InstallationScope.project,
            ),
          );
        }
        if (representative.scope == InstallationScope.project) {
          changes.add(
            WorkspaceManifestChange(
              projectRoot: representative.projectRoot,
              path: p.join(representative.projectRoot, 'skillsgo.yaml'),
              skill: skill.name,
              fromVersion: representative.version,
              toVersion: toVersion,
            ),
          );
        }
      }
      return UpdatePlan(
        targets: List.unmodifiable(items),
        workspaceManifestChanges: List.unmodifiable(changes),
        summary: UpdatePlanSummary(
          update: items.length,
          current: 0,
          pinned: 0,
          failed: 0,
        ),
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Update Plan JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<UpdateExecution> executeUpdate(
    UpdatePlan plan, {
    void Function(UpdateTargetProgress progress)? onProgress,
  }) async {
    if (plan.targets.isEmpty ||
        plan.targets.any((item) => item.action != UpdatePlanAction.update)) {
      throw const SkillsException(
        'Update execution requires explicit updateable targets.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final grouped = <String, List<UpdatePlanItem>>{};
    for (final item in plan.targets) {
      final key =
          '${item.repositoryId}\u0000${item.name}\u0000${item.target.scope.name}\u0000${item.target.projectRoot}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final results = <UpdateTargetResult>[];
    var sequence = 1;
    try {
      for (final group in grouped.values) {
        final representative = group.first;
        for (final item in group) {
          onProgress?.call(
            UpdateTargetProgress(
              sequence: sequence++,
              target: item.target,
              name: item.name,
              repositoryId: item.repositoryId,
              fromVersion: item.fromVersion,
              toVersion: item.toVersion,
              state: InstallationProgressState.started,
            ),
          );
        }
        if (group.any(
          (item) =>
              item.repositoryId != representative.repositoryId ||
              item.name != representative.name ||
              item.fromVersion != representative.fromVersion ||
              item.toVersion != representative.toVersion ||
              item.stateToken != representative.stateToken,
        )) {
          throw const FormatException();
        }
        final repository = representative.repositoryId;
        final command = await _runCli([
          'update',
          '$repository@${representative.toVersion}',
          ..._repositoryUpdateScopeArguments(
            representative.target.scope,
            representative.target.projectRoot,
          ),
          '--state-token',
          representative.stateToken,
          '--output',
          'json',
          '--hub',
          _hubOrigin,
        ]);
        if (!command.succeeded) throw _commandFailure(command);
        final raw = _decodeMachineDocument(
          command.output.stdout,
          phase: 'repository-update',
        );
        if (raw['repository'] != repository ||
            raw['fromVersion'] != representative.fromVersion ||
            raw['toVersion'] != representative.toVersion) {
          throw const FormatException();
        }
        for (final item in group) {
          final result = UpdateTargetResult(
            target: item.target,
            name: item.name,
            repositoryId: item.repositoryId,
            fromVersion: item.fromVersion,
            toVersion: item.toVersion,
            outcome: UpdateTargetOutcome.succeeded,
          );
          results.add(result);
          onProgress?.call(
            UpdateTargetProgress(
              sequence: sequence++,
              target: item.target,
              name: item.name,
              repositoryId: item.repositoryId,
              fromVersion: item.fromVersion,
              toVersion: item.toVersion,
              state: InstallationProgressState.finished,
              result: result,
            ),
          );
        }
      }
      return UpdateExecution(
        results: List.unmodifiable(results),
        summary: UpdateExecutionSummary(
          succeeded: results.length,
          skipped: 0,
          failed: 0,
        ),
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Update Result NDJSON.',
        kind: SkillsFailureKind.invalidResponse,
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
          ({
            String key,
            String repositoryId,
            String name,
            List<String> versions,
          })
        >[];
    for (final skill in skills) {
      if (skill.provenance != LibraryProvenance.hub ||
          skill.repositoryId.isEmpty) {
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
        repositoryId: skill.repositoryId,
        name: skill.name,
        versions: versions,
      ));
    }
    if (candidates.isEmpty) return states;

    await _ensureHubOrigin();
    final arguments = <String>[
      'updates',
      'check',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
      for (final candidate in candidates) ...[
        '--installed',
        jsonEncode({
          'key': candidate.key,
          'repositoryId': candidate.repositoryId,
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
            raw['repositoryId'] is! String ||
            raw['name'] is! String ||
            raw['versions'] is! List ||
            raw['status'] is! String ||
            !expected.remove(raw['key'])) {
          throw const FormatException();
        }
        final releaseVersion = raw['releaseVersion'];
        final headVersion = raw['headVersion'];
        final releaseStatus = raw['releaseStatus'];
        final headStatus = raw['headStatus'];
        if ((releaseVersion != null && releaseVersion is! String) ||
            (headVersion != null && headVersion is! String) ||
            (releaseStatus != null && releaseStatus is! String) ||
            (headStatus != null && headStatus is! String)) {
          throw const FormatException();
        }
        final toVersion = releaseStatus == 'update_available'
            ? releaseVersion as String? ?? ''
            : headStatus == 'update_available'
            ? headVersion as String? ?? ''
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
