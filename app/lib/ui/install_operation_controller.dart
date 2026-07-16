/*
 * [INPUT]: Depends on Flutter foundation, Riverpod legacy migration support, and typed SkillsGateway installation contracts.
 * [OUTPUT]: Provides immutable per-Skill installation operation state, providers, preflight/execute/retry actions, target progress, and stable retry result merging.
 * [POS]: Serves as the installation operation state boundary while dialogs retain only ephemeral selection and confirmation state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/skills_gateway.dart';

String operationTargetKey(InstallationPlanTarget target) =>
    '${target.scope.name}\u0000${target.projectRoot}\u0000${target.agent}\u0000${target.mode.name}\u0000${target.path}';

class InstallOperationState {
  InstallOperationState({
    this.operating = false,
    this.plan,
    this.execution,
    this.error,
    List<InstallationTargetSelection> selections = const [],
    Map<String, InstallationTargetProgress> progressByTarget = const {},
  }) : selections = List.unmodifiable(selections),
       progressByTarget = Map.unmodifiable(progressByTarget);

  final bool operating;
  final InstallationPlan? plan;
  final InstallationExecution? execution;
  final Object? error;
  final List<InstallationTargetSelection> selections;
  final Map<String, InstallationTargetProgress> progressByTarget;

  List<InstallationTargetProgress> get progress {
    final currentPlan = plan;
    if (currentPlan == null) return const [];
    return [
      for (final item in currentPlan.targets)
        ?progressByTarget[operationTargetKey(item.target)],
    ];
  }

  int get finishedTargetCount => progressByTarget.values
      .where((event) => event.state == InstallationProgressState.finished)
      .length;

  InstallOperationState copyWith({
    bool? operating,
    InstallationPlan? plan,
    bool clearPlan = false,
    InstallationExecution? execution,
    bool clearExecution = false,
    Object? error,
    bool clearError = false,
    List<InstallationTargetSelection>? selections,
    Map<String, InstallationTargetProgress>? progressByTarget,
  }) => InstallOperationState(
    operating: operating ?? this.operating,
    plan: clearPlan ? null : plan ?? this.plan,
    execution: clearExecution ? null : execution ?? this.execution,
    error: clearError ? null : error ?? this.error,
    selections: selections ?? this.selections,
    progressByTarget: progressByTarget ?? this.progressByTarget,
  );
}

final installOperationProvider =
    ChangeNotifierProvider.family<InstallOperationController, String>(
      (ref, skillId) => InstallOperationController(),
    );

class InstallOperationController extends ChangeNotifier {
  InstallOperationState _state = InstallOperationState();
  bool _disposed = false;

  InstallOperationState get state => _state;
  bool get operating => _state.operating;
  InstallationPlan? get plan => _state.plan;
  InstallationExecution? get execution => _state.execution;
  Object? get error => _state.error;
  List<InstallationTargetSelection> get selections => _state.selections;
  List<InstallationTargetProgress> get progress => _state.progress;
  int get finishedTargetCount => _state.finishedTargetCount;

  void _replace(InstallOperationState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  Future<InstallationPlan?> preflight(
    SkillsGateway gateway,
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool riskConfirmed = false,
    bool allowCritical = false,
  }) async {
    if (operating) return plan;
    _replace(InstallOperationState(operating: true, selections: selections));
    try {
      final nextPlan = await gateway.preflightInstall(
        skill,
        immutableVersion,
        selections,
        riskConfirmed: riskConfirmed,
        allowCritical: allowCritical,
      );
      _replace(_state.copyWith(plan: nextPlan));
    } catch (caught) {
      _replace(_state.copyWith(error: caught));
    } finally {
      _replace(_state.copyWith(operating: false));
    }
    return plan;
  }

  Future<InstallationExecution?> execute(SkillsGateway gateway) async {
    final currentPlan = plan;
    if (operating || currentPlan == null) return execution;
    _replace(
      _state.copyWith(
        operating: true,
        clearExecution: true,
        clearError: true,
        progressByTarget: const {},
      ),
    );
    try {
      final nextExecution = await gateway.executeInstall(
        currentPlan,
        onProgress: _recordProgress,
      );
      _replace(_state.copyWith(execution: nextExecution));
    } catch (caught) {
      _replace(_state.copyWith(error: caught));
    } finally {
      _replace(_state.copyWith(operating: false));
    }
    return execution;
  }

  Future<InstallationExecution?> retryFailed(
    SkillsGateway gateway,
    SkillSummary skill,
  ) async {
    final originalPlan = plan;
    final previous = execution;
    if (operating || originalPlan == null || previous == null) return previous;
    final failedKeys = previous.results
        .where((result) => result.outcome == InstallationTargetOutcome.failed)
        .map((result) => operationTargetKey(result.target))
        .toSet();
    if (failedKeys.isEmpty) return previous;
    final retrySelections = <InstallationTargetSelection>[];
    final expectedTargets = <InstallationPlanTarget>[];
    for (var index = 0; index < originalPlan.targets.length; index++) {
      final target = originalPlan.targets[index].target;
      if (failedKeys.contains(operationTargetKey(target))) {
        retrySelections.add(originalPlan.selections[index]);
        expectedTargets.add(target);
      }
    }
    final retainedProgress = {..._state.progressByTarget}
      ..removeWhere((key, _) => failedKeys.contains(key));
    _replace(
      _state.copyWith(
        operating: true,
        clearError: true,
        progressByTarget: retainedProgress,
      ),
    );
    try {
      final retryPlan = await gateway.preflightInstall(
        skill,
        originalPlan.version,
        retrySelections,
        riskConfirmed: originalPlan.riskConfirmed,
        allowCritical: originalPlan.allowCritical,
      );
      if (retryPlan.source != originalPlan.source ||
          retryPlan.coordinate != originalPlan.coordinate ||
          retryPlan.version != originalPlan.version ||
          retryPlan.name != originalPlan.name ||
          retryPlan.targets.length != expectedTargets.length) {
        throw const SkillsException(
          'Retry changed the immutable artifact or target identities.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      for (var index = 0; index < expectedTargets.length; index++) {
        if (operationTargetKey(retryPlan.targets[index].target) !=
            operationTargetKey(expectedTargets[index])) {
          throw const SkillsException(
            'Retry changed the immutable artifact or target identities.',
            kind: SkillsFailureKind.invalidResponse,
          );
        }
      }
      final retried = await gateway.executeInstall(
        retryPlan,
        onProgress: _recordProgress,
      );
      _replace(
        _state.copyWith(execution: mergeRetryExecution(previous, retried)),
      );
    } catch (caught) {
      _replace(_state.copyWith(error: caught));
    } finally {
      _replace(_state.copyWith(operating: false));
    }
    return execution;
  }

  void _recordProgress(InstallationTargetProgress progress) {
    _replace(
      _state.copyWith(
        progressByTarget: {
          ..._state.progressByTarget,
          operationTargetKey(progress.target): progress,
        },
      ),
    );
  }

  void editTargets() {
    _replace(InstallOperationState(selections: plan?.selections ?? selections));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

InstallationExecution mergeRetryExecution(
  InstallationExecution previous,
  InstallationExecution retried,
) {
  if (previous.coordinate != retried.coordinate ||
      previous.version != retried.version ||
      previous.name != retried.name) {
    throw const SkillsException(
      'Retry changed the immutable artifact identity.',
      kind: SkillsFailureKind.invalidResponse,
    );
  }
  final retriedByTarget = {
    for (final result in retried.results)
      operationTargetKey(result.target): result,
  };
  final results = [
    for (final result in previous.results)
      retriedByTarget[operationTargetKey(result.target)] ?? result,
  ];
  if (retriedByTarget.length != retried.results.length ||
      !retriedByTarget.keys.every(
        (key) => previous.results.any(
          (result) => operationTargetKey(result.target) == key,
        ),
      )) {
    throw const SkillsException(
      'Retry returned an unknown Installation Target.',
      kind: SkillsFailureKind.invalidResponse,
    );
  }
  int count(InstallationTargetOutcome outcome) =>
      results.where((result) => result.outcome == outcome).length;
  return InstallationExecution(
    coordinate: previous.coordinate,
    version: previous.version,
    name: previous.name,
    results: List.unmodifiable(results),
    summary: InstallationExecutionSummary(
      succeeded: count(InstallationTargetOutcome.succeeded),
      skipped: count(InstallationTargetOutcome.skipped),
      conflict: count(InstallationTargetOutcome.conflict),
      failed: count(InstallationTargetOutcome.failed),
    ),
  );
}
