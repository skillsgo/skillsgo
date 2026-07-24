/*
 * [INPUT]: Depends on Flutter foundation, Riverpod legacy migration support, the App-scoped Gateway provider, and direct SkillsGateway installation contracts.
 * [OUTPUT]: Provides a compact InstallationRequest interface plus discovery-snapshot version preservation, atomic Repository installation, execution aggregation, success classification, and error state.
 * [POS]: Serves as the deep Installation Request module while selectors retain only ephemeral location choices and presentation feedback.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/skills_gateway.dart';
import 'app_providers.dart';

class InstallationRequest {
  const InstallationRequest.skill(
    this._skill,
    this._immutableVersion, {
    required this.selections,
    required this.riskPolicy,
  }) : _repositorySkills = const [];

  const InstallationRequest.repository(
    this._repositorySkills, {
    required this.selections,
    required this.riskPolicy,
  }) : _skill = null,
       _immutableVersion = null;

  final SkillSummary? _skill;
  final String? _immutableVersion;
  final List<SkillSummary> _repositorySkills;
  final List<InstallationTargetSelection> selections;
  final PersonalRiskPolicy riskPolicy;

  bool get isRepository => _repositorySkills.isNotEmpty;
}

class InstallOperationState {
  const InstallOperationState({
    this.operating = false,
    this.executions = const [],
    this.error,
  });

  final bool operating;
  final List<InstallationExecution> executions;
  final Object? error;

  InstallationExecution? get execution =>
      executions.isEmpty ? null : executions.last;

  bool get succeeded =>
      error == null &&
      executions.isNotEmpty &&
      executions.every((execution) => execution.hasSuccess);
}

final installOperationProvider =
    ChangeNotifierProvider.family<InstallOperationController, String>(
      (ref, installName) =>
          InstallOperationController(ref.read(skillsGatewayProvider)),
    );

class InstallOperationController extends ChangeNotifier {
  InstallOperationController(this._gateway);

  final SkillsGateway _gateway;
  InstallOperationState _state = const InstallOperationState();
  bool _disposed = false;

  InstallOperationState get state => _state;
  bool get operating => _state.operating;
  InstallationExecution? get execution => _state.execution;
  List<InstallationExecution> get executions => _state.executions;
  Object? get error => _state.error;

  void _replace(InstallOperationState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  Future<InstallOperationState> submit(InstallationRequest request) async {
    if (operating) return state;
    _replace(const InstallOperationState(operating: true));
    final executions = <InstallationExecution>[];
    try {
      if (request.selections.isEmpty) {
        throw const SkillsException(
          'Installation requires at least one explicit target.',
          kind: SkillsFailureKind.validation,
        );
      }
      final resolved = <({SkillSummary skill, String immutableVersion})>[];
      if (request.isRepository) {
        executions.addAll(
          await _gateway.installRepositoryTargets(
            request._repositorySkills,
            request.selections,
            confirmRisk: true,
            allowCritical: request.riskPolicy.allowCriticalOverride,
          ),
        );
      } else {
        final skill = request._skill;
        final immutableVersion = request._immutableVersion;
        if (skill == null ||
            immutableVersion == null ||
            immutableVersion.isEmpty) {
          throw const SkillsException(
            'Installation requires an immutable Skill version.',
            kind: SkillsFailureKind.validation,
          );
        }
        resolved.add((skill: skill, immutableVersion: immutableVersion));
      }
      if (!request.isRepository && resolved.isEmpty) {
        throw const SkillsException(
          'Installation requires at least one Skill.',
          kind: SkillsFailureKind.validation,
        );
      }
      for (final item in resolved) {
        executions.add(
          await _gateway.installTargets(
            item.skill,
            item.immutableVersion,
            request.selections,
            confirmRisk: true,
            allowCritical: request.riskPolicy.allowCriticalOverride,
          ),
        );
      }
      final failed = executions.any((execution) => !execution.hasSuccess);
      _replace(
        InstallOperationState(
          executions: List.unmodifiable(executions),
          error: failed ? StateError('Installation failed.') : null,
        ),
      );
    } catch (caught) {
      _replace(
        InstallOperationState(
          executions: List.unmodifiable(executions),
          error: caught,
        ),
      );
    }
    return state;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
