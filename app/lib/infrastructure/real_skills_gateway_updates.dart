/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, update codecs, reviewed Update Plans, and progress callbacks.
 * [OUTPUT]: Provides exact-candidate target update preflight and execution, failed-target progress, and one Catalog-only batch Library update-availability check.
 * [POS]: Serves as the Update Plan capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayUpdates
    on _RealSkillsGatewayCore, _RealSkillsGatewayExecutionSupport {
  String _updateTargetArgument(
    String skillId,
    SkillInstallationTarget target, {
    String? candidateVersion,
    String? toVersion,
    String? stateToken,
  }) => jsonEncode({
    'scope': target.scope.name,
    if (target.scope == InstallationScope.project)
      'projectRoot': target.projectRoot,
    'agent': target.agent,
    'mode': target.mode.name,
    'path': target.path,
    'skillId': skillId,
    'version': target.version,
    'candidateVersion': ?candidateVersion,
    'toVersion': ?toVersion,
    'stateToken': ?stateToken,
  });

  @override
  Future<UpdatePlan> preflightUpdate(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets, {
    String? toVersion,
  }) async {
    if (skill.provenance != LibraryProvenance.hub ||
        skill.skillId.isEmpty ||
        targets.isEmpty ||
        targets.any(
          (target) =>
              target.mode == InstallationMode.external ||
              target.version.isEmpty ||
              (target.scope == InstallationScope.project &&
                  target.projectRoot.isEmpty),
        )) {
      throw const SkillsException(
        'Only explicit managed Hub targets can be checked for updates.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final arguments = <String>['update'];
    for (final target in targets) {
      arguments.addAll([
        '--target',
        _updateTargetArgument(
          skill.skillId,
          target,
          candidateVersion: toVersion,
        ),
      ]);
    }
    arguments.addAll(['--preflight', '--output', 'json', '--hub', _hubOrigin]);
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final decoded = jsonDecode(command.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['phase'] != 'update-preflight' ||
          decoded['targets'] is! List ||
          decoded['workspaceManifestChanges'] is! List ||
          decoded['summary'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final rawTargets = decoded['targets'] as List;
      if (rawTargets.length != targets.length) throw const FormatException();
      final items = <UpdatePlanItem>[];
      for (var index = 0; index < rawTargets.length; index++) {
        final raw = rawTargets[index];
        if (raw is! Map<String, dynamic> ||
            raw['name'] is! String ||
            raw['skillId'] != skill.skillId ||
            raw['sourceRef'] is! String ||
            raw['fromVersion'] != targets[index].version ||
            raw['toVersion'] is! String ||
            raw['stateToken'] is! String ||
            raw['workspaceManifestChange'] is! bool ||
            (raw['affectedBindings'] != null &&
                raw['affectedBindings'] is! List) ||
            (raw['reasonCode'] != null && raw['reasonCode'] is! String) ||
            (raw['diagnostic'] != null && raw['diagnostic'] is! String)) {
          throw const FormatException();
        }
        final target = _installationPlanTarget(raw['target']);
        final expected = targets[index];
        final action = _updatePlanAction(raw['action']);
        final reasonCode = raw['reasonCode'] as String? ?? '';
        final fromVersion = expected.version;
        final toVersion = raw['toVersion'] as String;
        final stateToken = raw['stateToken'] as String;
        final workspaceManifestChange = raw['workspaceManifestChange'] as bool;
        if (target.scope != expected.scope ||
            target.projectRoot != expected.projectRoot ||
            target.agent != expected.agent ||
            target.mode != expected.mode ||
            target.path != expected.path ||
            stateToken.isEmpty ||
            (workspaceManifestChange &&
                target.scope != InstallationScope.project) ||
            (action == UpdatePlanAction.update &&
                fromVersion == toVersion &&
                reasonCode != 'workspace-manifest-reconcile') ||
            (reasonCode == 'workspace-manifest-reconcile' &&
                (action != UpdatePlanAction.update ||
                    !workspaceManifestChange ||
                    fromVersion != toVersion))) {
          throw const FormatException();
        }
        items.add(
          UpdatePlanItem(
            target: target,
            name: raw['name'] as String,
            skillId: skill.skillId,
            sourceRef: raw['sourceRef'] as String,
            fromVersion: fromVersion,
            toVersion: toVersion,
            action: action,
            reasonCode: reasonCode,
            diagnostic: raw['diagnostic'] as String? ?? '',
            stateToken: stateToken,
            workspaceManifestChange: workspaceManifestChange,
            affectedBindings: List.unmodifiable([
              for (final binding
                  in raw['affectedBindings'] as List? ?? const [])
                _installationPlanTarget(binding),
            ]),
          ),
        );
      }
      _validateAffectedBindings(
        items,
        targetOf: (item) => item.target,
        affectedBindingsOf: (item) => item.affectedBindings,
      );
      final changes = <WorkspaceManifestChange>[];
      final changeKeys = <String>{};
      for (final raw in decoded['workspaceManifestChanges'] as List) {
        if (raw is! Map<String, dynamic> ||
            raw['projectRoot'] is! String ||
            raw['path'] is! String ||
            raw['skill'] is! String ||
            raw['fromVersion'] is! String ||
            raw['toVersion'] is! String) {
          throw const FormatException();
        }
        final projectRoot = raw['projectRoot'] as String;
        final path = raw['path'] as String;
        final skillName = raw['skill'] as String;
        final fromVersion = raw['fromVersion'] as String;
        final toVersion = raw['toVersion'] as String;
        final key = '$projectRoot\u0000$skillName\u0000$toVersion';
        final matchesItem = items.any(
          (item) =>
              item.workspaceManifestChange &&
              item.target.scope == InstallationScope.project &&
              item.target.projectRoot == projectRoot &&
              item.name == skillName &&
              item.toVersion == toVersion,
        );
        if (projectRoot.isEmpty ||
            skillName.isEmpty ||
            fromVersion.isEmpty ||
            toVersion.isEmpty ||
            p.normalize(path) !=
                p.normalize(p.join(projectRoot, 'skillsgo.mod')) ||
            !matchesItem ||
            !changeKeys.add(key)) {
          throw const FormatException();
        }
        changes.add(
          WorkspaceManifestChange(
            projectRoot: projectRoot,
            path: path,
            skill: skillName,
            fromVersion: fromVersion,
            toVersion: toVersion,
          ),
        );
      }
      final expectedChangeKeys = {
        for (final item in items)
          if (item.workspaceManifestChange)
            '${item.target.projectRoot}\u0000${item.name}\u0000${item.toVersion}',
      };
      if (changeKeys.length != expectedChangeKeys.length ||
          !changeKeys.containsAll(expectedChangeKeys)) {
        throw const FormatException();
      }
      final rawSummary = decoded['summary'] as Map<String, dynamic>;
      final summary = UpdatePlanSummary(
        update: _strictNonNegativeInt(rawSummary['update']),
        current: _strictNonNegativeInt(rawSummary['current']),
        pinned: _strictNonNegativeInt(rawSummary['pinned']),
        failed: _strictNonNegativeInt(rawSummary['failed']),
      );
      if (summary.update !=
              items
                  .where((item) => item.action == UpdatePlanAction.update)
                  .length ||
          summary.current !=
              items
                  .where((item) => item.action == UpdatePlanAction.current)
                  .length ||
          summary.pinned !=
              items
                  .where((item) => item.action == UpdatePlanAction.pinned)
                  .length ||
          summary.failed !=
              items
                  .where((item) => item.action == UpdatePlanAction.failed)
                  .length) {
        throw const FormatException();
      }
      return UpdatePlan(
        targets: List.unmodifiable(items),
        workspaceManifestChanges: List.unmodifiable(changes),
        summary: summary,
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
    final arguments = <String>['update'];
    for (final item in plan.targets) {
      arguments.addAll([
        '--target',
        jsonEncode({
          'scope': item.target.scope.name,
          if (item.target.scope == InstallationScope.project)
            'projectRoot': item.target.projectRoot,
          'agent': item.target.agent,
          'mode': item.target.mode.name,
          'path': item.target.path,
          'skillId': item.skillId,
          'version': item.fromVersion,
          'toVersion': item.toVersion,
          'stateToken': item.stateToken,
        }),
      ]);
    }
    arguments.addAll(['--output', 'ndjson', '--hub', _hubOrigin]);
    final expected = {
      for (final item in plan.targets) updateTargetKey(item.target): item,
    };
    final states = <String, InstallationProgressState>{};
    final terminal = <String, UpdateTargetResult>{};
    var sequence = 1;
    try {
      final raw = await _runNdjsonExecution(
        arguments,
        progressPhase: 'update-progress',
        executionPhase: 'update-execution',
        consumeProgress: (raw) {
          if (raw['sequence'] != sequence++ ||
              raw['name'] is! String ||
              raw['skillId'] is! String ||
              raw['fromVersion'] is! String ||
              raw['toVersion'] is! String) {
            throw const FormatException();
          }
          final target = _installationPlanTarget(raw['target']);
          final key = updateTargetKey(target);
          final item = expected[key];
          if (item == null ||
              raw['name'] != item.name ||
              raw['skillId'] != item.skillId ||
              raw['fromVersion'] != item.fromVersion ||
              raw['toVersion'] != item.toVersion) {
            throw const FormatException();
          }
          final state = switch (raw['state']) {
            'started' => InstallationProgressState.started,
            'finished' => InstallationProgressState.finished,
            _ => throw const FormatException(),
          };
          UpdateTargetResult? result;
          if (state == InstallationProgressState.started) {
            if (states.containsKey(key) || raw.containsKey('result')) {
              throw const FormatException();
            }
          } else {
            if (states[key] != InstallationProgressState.started ||
                raw['result'] == null) {
              throw const FormatException();
            }
            result = _updateTargetResult(raw['result'], item);
            terminal[key] = result;
          }
          states[key] = state;
          onProgress?.call(
            UpdateTargetProgress(
              sequence: raw['sequence'] as int,
              target: target,
              name: item.name,
              skillId: item.skillId,
              fromVersion: item.fromVersion,
              toVersion: item.toVersion,
              state: state,
              result: result,
            ),
          );
        },
        canFinalize: () =>
            states.length == expected.length &&
            states.values.every(
              (state) => state == InstallationProgressState.finished,
            ),
      );
      if (raw['results'] is! List || raw['summary'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final rawResults = raw['results'] as List;
      if (rawResults.length != plan.targets.length) {
        throw const FormatException();
      }
      final results = <UpdateTargetResult>[
        for (var index = 0; index < rawResults.length; index++)
          _updateTargetResult(rawResults[index], plan.targets[index]),
      ];
      for (final result in results) {
        final streamed = terminal[updateTargetKey(result.target)];
        if (streamed == null ||
            streamed.outcome != result.outcome ||
            streamed.error?.code != result.error?.code ||
            streamed.error?.diagnostic != result.error?.diagnostic) {
          throw const FormatException();
        }
      }
      final rawSummary = raw['summary'] as Map<String, dynamic>;
      final summary = UpdateExecutionSummary(
        succeeded: _strictNonNegativeInt(rawSummary['succeeded']),
        skipped: _strictNonNegativeInt(rawSummary['skipped']),
        failed: _strictNonNegativeInt(rawSummary['failed']),
      );
      if (summary.succeeded !=
              results
                  .where(
                    (result) => result.outcome == UpdateTargetOutcome.succeeded,
                  )
                  .length ||
          summary.skipped !=
              results
                  .where(
                    (result) => result.outcome == UpdateTargetOutcome.skipped,
                  )
                  .length ||
          summary.failed !=
              results
                  .where(
                    (result) => result.outcome == UpdateTargetOutcome.failed,
                  )
                  .length) {
        throw const FormatException();
      }
      return UpdateExecution(
        results: List.unmodifiable(results),
        summary: summary,
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
        <({String key, String skillId, List<String> versions})>[];
    for (final skill in skills) {
      if (skill.provenance != LibraryProvenance.hub || skill.skillId.isEmpty) {
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
        skillId: skill.skillId,
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
          'skillId': candidate.skillId,
          'versions': candidate.versions,
        }),
      ],
    ];
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final decoded = jsonDecode(command.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['phase'] != 'update-check' ||
          decoded['items'] is! List ||
          (decoded['items'] as List).length != candidates.length) {
        throw const FormatException();
      }
      final expected = {for (final candidate in candidates) candidate.key};
      for (final raw in decoded['items'] as List) {
        if (raw is! Map<String, dynamic> ||
            raw['key'] is! String ||
            raw['skillId'] is! String ||
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
