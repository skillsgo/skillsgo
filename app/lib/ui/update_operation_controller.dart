/*
 * [INPUT]: Depends on Riverpod, the App-scoped SkillsGateway provider, Library Inventory reconciliation, and typed update plan, progress, and execution contracts.
 * [OUTPUT]: Provides immutable per-Skill Update operation state plus execute and failed-target retry actions.
 * [POS]: Serves as the Update mutation state machine while dialogs retain only ephemeral target selection state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
import 'app_providers.dart';
import 'library_controller.dart';

class UpdateOperationState {
  UpdateOperationState({
    this.operating = false,
    this.execution,
    this.error,
    Map<String, UpdateTargetProgress> progress = const {},
    Set<String> activeTargetKeys = const {},
  }) : progress = Map.unmodifiable(progress),
       activeTargetKeys = Set.unmodifiable(activeTargetKeys);

  final bool operating;
  final UpdateExecution? execution;
  final Object? error;
  final Map<String, UpdateTargetProgress> progress;
  final Set<String> activeTargetKeys;

  int get finishedCount => progress.values
      .where(
        (event) =>
            activeTargetKeys.contains(updateTargetKey(event.target)) &&
            event.state == InstallationProgressState.finished,
      )
      .length;

  UpdateOperationState copyWith({
    bool? operating,
    UpdateExecution? execution,
    Object? error,
    bool clearError = false,
    Map<String, UpdateTargetProgress>? progress,
    Set<String>? activeTargetKeys,
  }) => UpdateOperationState(
    operating: operating ?? this.operating,
    execution: execution ?? this.execution,
    error: clearError ? null : error ?? this.error,
    progress: progress ?? this.progress,
    activeTargetKeys: activeTargetKeys ?? this.activeTargetKeys,
  );
}

final updateOperationProvider = NotifierProvider.family
    .autoDispose<UpdateOperationController, UpdateOperationState, String>(
      UpdateOperationController.new,
    );

class UpdateOperationController extends Notifier<UpdateOperationState> {
  UpdateOperationController(this.inventoryKey);

  final String inventoryKey;

  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);

  @override
  UpdateOperationState build() => UpdateOperationState();

  Future<void> execute(UpdatePlan plan) async {
    if (plan.targets.isEmpty || state.operating) return;
    final activeKeys = {
      for (final item in plan.targets) updateTargetKey(item.target),
    };
    final nextProgress = {...state.progress}
      ..removeWhere((key, _) => activeKeys.contains(key));
    state = state.copyWith(
      operating: true,
      clearError: true,
      activeTargetKeys: activeKeys,
      progress: nextProgress,
    );
    try {
      final next = await _gateway.executeUpdate(
        plan,
        onProgress: (event) {
          if (!ref.mounted) return;
          state = state.copyWith(
            progress: {...state.progress, updateTargetKey(event.target): event},
          );
        },
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        execution: state.execution == null
            ? next
            : mergeUpdateExecutions(state.execution!, next),
      );
    } catch (error) {
      if (ref.mounted) state = state.copyWith(error: error);
    } finally {
      if (ref.mounted) state = state.copyWith(operating: false);
    }
  }

  Future<void> retryFailed(InstalledSkill skill) async {
    final current = state.execution;
    if (current == null || state.operating) return;
    final failed = current.results
        .where((result) => result.outcome == UpdateTargetOutcome.failed)
        .map((result) => updateTargetKey(result.target))
        .toSet();
    state = state.copyWith(operating: true, clearError: true);
    try {
      final refreshed = await ref
          .read(libraryProvider.notifier)
          .refreshEntry(LibraryEntryQuery.byInventoryKey(skill.inventoryKey));
      final refreshedSkill = refreshed.entry;
      if (refreshedSkill == null) {
        throw const SkillsException(
          'The failed Update Targets are no longer installed.',
          kind: SkillsFailureKind.validation,
        );
      }
      final failedTargets = refreshedSkill.targets
          .where((target) => failed.contains(installedUpdateTargetKey(target)))
          .toList(growable: false);
      if (failedTargets.length != failed.length) {
        throw const SkillsException(
          'The failed Update Targets changed before retry.',
          kind: SkillsFailureKind.validation,
        );
      }
      final retryPlan = await _gateway.preflightUpdate(
        refreshedSkill,
        failedTargets,
      );
      if (!ref.mounted) return;
      final passiveResults = [
        for (final item in retryPlan.targets)
          if (item.action != UpdatePlanAction.update)
            UpdateTargetResult(
              target: item.target,
              name: item.name,
              skillId: item.skillId,
              fromVersion: item.fromVersion,
              toVersion: item.toVersion,
              outcome: item.action == UpdatePlanAction.failed
                  ? UpdateTargetOutcome.failed
                  : UpdateTargetOutcome.skipped,
              error: item.action == UpdatePlanAction.failed
                  ? TargetFailure(
                      code: 'update.target_failed',
                      retryable: true,
                      diagnostic: item.diagnostic,
                    )
                  : null,
            ),
      ];
      final updateItems = retryPlan.targets
          .where((item) => item.action == UpdatePlanAction.update)
          .toList(growable: false);
      if (passiveResults.isNotEmpty) {
        final passive = UpdateExecution(
          results: passiveResults,
          summary: UpdateExecutionSummary(
            succeeded: 0,
            skipped: passiveResults
                .where(
                  (result) => result.outcome == UpdateTargetOutcome.skipped,
                )
                .length,
            failed: passiveResults
                .where((result) => result.outcome == UpdateTargetOutcome.failed)
                .length,
          ),
        );
        state = state.copyWith(
          execution: mergeUpdateExecutions(current, passive),
        );
      }
      state = state.copyWith(operating: false);
      if (updateItems.isNotEmpty) {
        await execute(retryPlan.selectTargets(updateItems));
      }
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(operating: false, error: error);
      }
    }
  }
}

UpdateExecution mergeUpdateExecutions(
  UpdateExecution previous,
  UpdateExecution retried,
) {
  final retryByTarget = {
    for (final result in retried.results)
      updateTargetKey(result.target): result,
  };
  final results = [
    for (final result in previous.results)
      retryByTarget[updateTargetKey(result.target)] ?? result,
  ];
  int count(UpdateTargetOutcome outcome) =>
      results.where((result) => result.outcome == outcome).length;
  return UpdateExecution(
    results: List.unmodifiable(results),
    summary: UpdateExecutionSummary(
      succeeded: count(UpdateTargetOutcome.succeeded),
      skipped: count(UpdateTargetOutcome.skipped),
      failed: count(UpdateTargetOutcome.failed),
    ),
  );
}
