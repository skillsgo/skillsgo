/*
 * [INPUT]: Depends on Riverpod, the App-scoped SkillsGateway provider, and typed Target Management plan, progress, and execution contracts.
 * [OUTPUT]: Provides immutable per-dialog Target Management execution, progress, result, and error state.
 * [POS]: Serves as the Target Management mutation state machine while dialogs retain only ephemeral action selection state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
import 'app_providers.dart';

class TargetManagementOperationState {
  TargetManagementOperationState({
    this.operating = false,
    this.execution,
    this.error,
    Map<String, TargetManagementProgress> progress = const {},
  }) : progress = Map.unmodifiable(progress);

  final bool operating;
  final TargetManagementExecution? execution;
  final Object? error;
  final Map<String, TargetManagementProgress> progress;

  int get finishedCount => progress.values
      .where((event) => event.state == InstallationProgressState.finished)
      .length;

  TargetManagementOperationState copyWith({
    bool? operating,
    TargetManagementExecution? execution,
    Object? error,
    bool clearError = false,
    Map<String, TargetManagementProgress>? progress,
  }) => TargetManagementOperationState(
    operating: operating ?? this.operating,
    execution: execution ?? this.execution,
    error: clearError ? null : error ?? this.error,
    progress: progress ?? this.progress,
  );
}

final targetManagementOperationProvider = NotifierProvider.family
    .autoDispose<
      TargetManagementOperationController,
      TargetManagementOperationState,
      String
    >(TargetManagementOperationController.new);

class TargetManagementOperationController
    extends Notifier<TargetManagementOperationState> {
  TargetManagementOperationController(this.operationKey);

  final String operationKey;

  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);

  @override
  TargetManagementOperationState build() => TargetManagementOperationState();

  Future<void> execute(TargetManagementPlan plan) async {
    if (plan.targets.isEmpty || state.operating) return;
    state = TargetManagementOperationState(operating: true);
    try {
      final execution = await _gateway.executeTargetManagement(
        plan,
        onProgress: (event) {
          if (!ref.mounted) return;
          state = state.copyWith(
            progress: {...state.progress, updateTargetKey(event.target): event},
          );
        },
      );
      if (ref.mounted) state = state.copyWith(execution: execution);
    } catch (error) {
      if (ref.mounted) state = state.copyWith(error: error);
    } finally {
      if (ref.mounted) state = state.copyWith(operating: false);
    }
  }
}
