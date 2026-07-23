/*
 * [INPUT]: Depends on the shared gateway state, CLI execution, target codecs, reviewed Target Operation Plans, and progress callbacks.
 * [OUTPUT]: Provides managed Repository-member and External Installation removal planning, execution, target results, and progress translation.
 * [POS]: Serves as the Target Operation Plan capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayTargetManagement
    on _RealSkillsGatewayCore, _RealSkillsGatewayExecutionSupport {
  @override
  Future<TargetManagementPlan> preflightTargetManagement(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  ) async {
    final external = skill.provenance == LibraryProvenance.external;
    if (!external) return _managedRemovalPlan(skill, targets);
    if (targets.isEmpty ||
        targets.any(
          (target) =>
              target.version.isNotEmpty ||
              (target.scope == InstallationScope.project &&
                  target.projectRoot.isEmpty),
        )) {
      throw const SkillsException(
        'Only exact External Installation removals can enter a Target Management Plan.',
        kind: SkillsFailureKind.validation,
      );
    }
    final arguments = <String>['remove'];
    for (final target in targets) {
      arguments.addAll(['--path', target.path, '--agent', target.agent]);
      if (target.scope == InstallationScope.project) {
        arguments.addAll(['--project', target.projectRoot]);
      }
    }
    arguments.addAll(['--preflight', '--output', 'json']);
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final decoded = _decodeMachineDocument(
        command.output.stdout,
        phase: 'management-preflight',
      );
      if (decoded['targets'] is! List ||
          decoded['summary'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final rawTargets = decoded['targets'] as List;
      if (rawTargets.length != targets.length) throw const FormatException();
      final items = <TargetManagementPlanItem>[];
      for (var index = 0; index < rawTargets.length; index++) {
        final raw = rawTargets[index];
        if (raw is! Map<String, dynamic> ||
            raw['name'] is! String ||
            raw['skillId'] is! String ||
            raw['version'] != targets[index].version ||
            raw['allowedActions'] is! List ||
            raw['stateToken'] is! String ||
            (raw['stateToken'] as String).isEmpty ||
            raw['workspaceMetadataChange'] is! bool ||
            raw['action'] != null ||
            (raw['diagnostic'] != null && raw['diagnostic'] is! String) ||
            (raw['affectedBindings'] != null &&
                raw['affectedBindings'] is! List)) {
          throw const FormatException();
        }
        final target = _installationPlanTarget(raw['target']);
        final expected = targets[index];
        if (target.scope != expected.scope ||
            target.projectRoot != expected.projectRoot ||
            target.agent != expected.agent ||
            target.path != expected.path ||
            raw['workspaceMetadataChange'] as bool) {
          throw const FormatException();
        }
        final health = _installationHealth(raw['health']);
        final actionValues = raw['allowedActions'] as List;
        final allowedActions = actionValues
            .map(_targetManagementAction)
            .toList(growable: false);
        if (health != InstallationHealth.healthy ||
            allowedActions.length != 1 ||
            allowedActions.single != TargetManagementAction.remove) {
          throw const FormatException();
        }
        items.add(
          TargetManagementPlanItem(
            target: target,
            name: raw['name'] as String,
            skillId: raw['skillId'] as String,
            version: expected.version,
            health: health,
            allowedActions: List.unmodifiable(allowedActions),
            stateToken: raw['stateToken'] as String,
            workspaceMetadataChange: raw['workspaceMetadataChange'] as bool,
            diagnostic: raw['diagnostic'] as String? ?? '',
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
      final rawSummary = decoded['summary'] as Map<String, dynamic>;
      final summary = TargetManagementPlanSummary(
        removable: _strictNonNegativeInt(rawSummary['removable']),
      );
      if (summary.removable != items.length) {
        throw const FormatException();
      }
      return TargetManagementPlan(
        targets: List.unmodifiable(items),
        summary: summary,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Target Management Plan JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  TargetManagementPlan _managedRemovalPlan(
    InstalledSkill skill,
    List<SkillInstallationTarget> requested,
  ) {
    if (skill.repositoryId.isEmpty ||
        requested.isEmpty ||
        requested.any((target) => target.version.isEmpty)) {
      throw const SkillsException(
        'Managed removal requires exact Repository-backed targets.',
        kind: SkillsFailureKind.validation,
      );
    }
    String scopeKey(SkillInstallationTarget target) =>
        '${target.scope.name}\u0000${target.projectRoot}';
    final requestedScopes = requested.map(scopeKey).toSet();
    final bindings = skill.targets
        .where((target) => requestedScopes.contains(scopeKey(target)))
        .toList(growable: false);
    if (bindings.isEmpty ||
        bindings.any((target) => target.health != InstallationHealth.healthy)) {
      throw const SkillsException(
        'Locally modified Repository Projections must be resolved by the user.',
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
    final planTargets = [
      for (final target in bindings)
        InstallationPlanTarget(
          scope: target.scope,
          projectRoot: target.projectRoot,
          agent: target.agent,
          path: target.path,
        ),
    ];
    return TargetManagementPlan(
      targets: List.unmodifiable([
        for (var index = 0; index < bindings.length; index++)
          TargetManagementPlanItem(
            target: planTargets[index],
            name: skill.name,
            skillId: '',
            repositoryId: skill.repositoryId,
            version: bindings[index].version,
            health: bindings[index].health,
            allowedActions: const [TargetManagementAction.remove],
            stateToken:
                'repository:${skill.repositoryId}:${skill.name}:${bindings[index].version}',
            workspaceMetadataChange: true,
            affectedBindings: List.unmodifiable([
              for (
                var bindingIndex = 0;
                bindingIndex < bindings.length;
                bindingIndex++
              )
                if (scopeKey(bindings[bindingIndex]) ==
                    scopeKey(bindings[index]))
                  planTargets[bindingIndex],
            ]),
          ),
      ]),
      summary: TargetManagementPlanSummary(removable: bindings.length),
    );
  }

  @override
  Future<TargetManagementExecution> executeTargetManagement(
    TargetManagementPlan plan, {
    void Function(TargetManagementProgress progress)? onProgress,
  }) async {
    for (final item in plan.targets) {
      final action = item.action;
      if (action == null) {
        throw const SkillsException(
          'Target Management execution requires explicit reviewed actions.',
          kind: SkillsFailureKind.validation,
        );
      }
      if (action != TargetManagementAction.remove) {
        throw const FormatException();
      }
    }
    final execution = plan.targets.every((item) => item.version.isNotEmpty)
        ? await _executeManagedRemoval(plan, onProgress: onProgress)
        : await _executeTargetManagementBatch(plan, onProgress: onProgress);
    final results = execution.results;
    final ordered = <TargetManagementResult>[
      for (final item in plan.targets)
        results.singleWhere(
          (result) =>
              updateTargetKey(result.target) == updateTargetKey(item.target),
        ),
    ];
    return TargetManagementExecution(
      results: List.unmodifiable(ordered),
      summary: TargetManagementExecutionSummary(
        succeeded: ordered
            .where(
              (result) => result.outcome == TargetManagementOutcome.succeeded,
            )
            .length,
        failed: ordered
            .where((result) => result.outcome == TargetManagementOutcome.failed)
            .length,
      ),
    );
  }

  Future<TargetManagementExecution> _executeManagedRemoval(
    TargetManagementPlan plan, {
    void Function(TargetManagementProgress progress)? onProgress,
  }) async {
    final groups = <String, List<TargetManagementPlanItem>>{};
    for (final item in plan.targets) {
      final key = '${item.target.scope.name}\u0000${item.target.projectRoot}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    final results = <TargetManagementResult>[];
    var sequence = 0;
    for (final items in groups.values) {
      final first = items.first;
      for (final item in items) {
        onProgress?.call(
          TargetManagementProgress(
            sequence: ++sequence,
            target: item.target,
            name: item.name,
            skillId: item.skillId,
            repositoryId: item.repositoryId,
            version: item.version,
            action: TargetManagementAction.remove,
            state: InstallationProgressState.started,
          ),
        );
      }
      final arguments = <String>['remove', first.name];
      if (first.target.scope == InstallationScope.user) {
        arguments.add('--global');
      } else {
        arguments.addAll(['--project', first.target.projectRoot]);
      }
      arguments.addAll(['--yes', '--output', 'json']);
      final command = await _runCli(arguments);
      if (!command.succeeded) throw _commandFailure(command);
      final raw = _decodeMachineDocument(
        command.output.stdout,
        phase: 'repository-remove',
      );
      if (raw['skills'] is! List ||
          !(raw['skills'] as List).contains(first.name)) {
        throw const SkillsException(
          'The SkillsGo CLI returned invalid Repository removal JSON.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      for (final item in items) {
        final result = TargetManagementResult(
          target: item.target,
          name: item.name,
          skillId: item.skillId,
          repositoryId: item.repositoryId,
          version: item.version,
          action: TargetManagementAction.remove,
          outcome: TargetManagementOutcome.succeeded,
        );
        results.add(result);
        onProgress?.call(
          TargetManagementProgress(
            sequence: ++sequence,
            target: item.target,
            name: item.name,
            skillId: item.skillId,
            version: item.version,
            action: TargetManagementAction.remove,
            state: InstallationProgressState.finished,
            result: result,
          ),
        );
      }
    }
    return TargetManagementExecution(
      results: List.unmodifiable(results),
      summary: TargetManagementExecutionSummary(
        succeeded: results.length,
        failed: 0,
      ),
    );
  }

  Future<TargetManagementExecution> _executeTargetManagementBatch(
    TargetManagementPlan plan, {
    void Function(TargetManagementProgress progress)? onProgress,
  }) async {
    if (plan.targets.isEmpty ||
        plan.targets.any(
          (item) =>
              item.action == null || !item.allowedActions.contains(item.action),
        )) {
      throw const SkillsException(
        'Target Management execution requires explicit reviewed actions.',
        kind: SkillsFailureKind.validation,
      );
    }
    final action = plan.targets.first.action!;
    final arguments = <String>[_targetManagementActionValue(action)];
    for (final item in plan.targets) {
      arguments.addAll([
        '--path',
        item.target.path,
        '--agent',
        item.target.agent,
        '--expected-state',
        item.stateToken,
      ]);
      if (item.target.scope == InstallationScope.project) {
        arguments.addAll(['--project', item.target.projectRoot]);
      }
    }
    arguments.addAll(['--output', 'ndjson']);
    final expected = {
      for (final item in plan.targets) updateTargetKey(item.target): item,
    };
    final states = <String, InstallationProgressState>{};
    final terminal = <String, TargetManagementResult>{};
    var sequence = 1;
    try {
      final raw = await _runNdjsonExecution(
        arguments,
        progressPhase: 'management-progress',
        executionPhase: 'management-execution',
        consumeProgress: (raw) {
          if (raw['sequence'] != sequence++ ||
              raw['name'] is! String ||
              raw['skillId'] is! String ||
              raw['version'] is! String ||
              raw['action'] is! String) {
            throw const FormatException();
          }
          final target = _installationPlanTarget(raw['target']);
          final key = updateTargetKey(target);
          final item = expected[key];
          if (item == null ||
              raw['name'] != item.name ||
              raw['skillId'] != item.skillId ||
              raw['version'] != item.version ||
              raw['action'] != _targetManagementActionValue(item.action!)) {
            throw const FormatException();
          }
          final state = switch (raw['state']) {
            'started' => InstallationProgressState.started,
            'finished' => InstallationProgressState.finished,
            _ => throw const FormatException(),
          };
          TargetManagementResult? result;
          if (state == InstallationProgressState.started) {
            if (states.containsKey(key) || raw.containsKey('result')) {
              throw const FormatException();
            }
          } else {
            if (states[key] != InstallationProgressState.started ||
                raw['result'] == null) {
              throw const FormatException();
            }
            result = _targetManagementResult(raw['result'], item);
            terminal[key] = result;
          }
          states[key] = state;
          onProgress?.call(
            TargetManagementProgress(
              sequence: raw['sequence'] as int,
              target: target,
              name: item.name,
              skillId: item.skillId,
              repositoryId: item.repositoryId,
              version: item.version,
              action: item.action!,
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
      final results = <TargetManagementResult>[
        for (var index = 0; index < rawResults.length; index++)
          _targetManagementResult(rawResults[index], plan.targets[index]),
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
      final summary = TargetManagementExecutionSummary(
        succeeded: _strictNonNegativeInt(rawSummary['succeeded']),
        failed: _strictNonNegativeInt(rawSummary['failed']),
      );
      if (summary.succeeded !=
              results
                  .where(
                    (result) =>
                        result.outcome == TargetManagementOutcome.succeeded,
                  )
                  .length ||
          summary.failed !=
              results
                  .where(
                    (result) =>
                        result.outcome == TargetManagementOutcome.failed,
                  )
                  .length) {
        throw const FormatException();
      }
      return TargetManagementExecution(
        results: List.unmodifiable(results),
        summary: summary,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Target Management Result NDJSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }
}
