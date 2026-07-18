/*
 * [INPUT]: Depends on Flutter foundation, Riverpod legacy migration support, and the direct SkillsGateway installation contract.
 * [OUTPUT]: Provides immutable per-Skill direct installation operation state and one confirmed install action.
 * [POS]: Serves as the installation operation state boundary while dialogs retain ephemeral selection and confirmation state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/skills_gateway.dart';

class InstallOperationState {
  const InstallOperationState({
    this.operating = false,
    this.execution,
    this.error,
  });

  final bool operating;
  final InstallationExecution? execution;
  final Object? error;
}

final installOperationProvider =
    ChangeNotifierProvider.family<InstallOperationController, String>(
      (ref, installName) => InstallOperationController(),
    );

class InstallOperationController extends ChangeNotifier {
  InstallOperationState _state = const InstallOperationState();
  bool _disposed = false;

  InstallOperationState get state => _state;
  bool get operating => _state.operating;
  InstallationExecution? get execution => _state.execution;
  Object? get error => _state.error;

  void _replace(InstallOperationState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  Future<InstallationExecution?> installTargets(
    SkillsGateway gateway,
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    if (operating) return execution;
    _replace(const InstallOperationState(operating: true));
    try {
      final nextExecution = await gateway.installTargets(
        skill,
        immutableVersion,
        selections,
        confirmRisk: confirmRisk,
        allowCritical: allowCritical,
      );
      _replace(InstallOperationState(execution: nextExecution));
    } catch (caught) {
      _replace(InstallOperationState(error: caught));
    }
    return execution;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
