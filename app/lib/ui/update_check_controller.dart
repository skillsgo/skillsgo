/*
 * [INPUT]: Depends on Riverpod, the App-scoped SkillsGateway, installed Package targets, persisted update results, and an injectable UTC clock.
 * [OUTPUT]: Provides one App-scoped single-flight update check with automatic, Updates-view, manual, and post-mutation freshness policies.
 * [POS]: Serves as the sole App coordinator for CLI-backed update previews so independent screens reuse one cached result.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
import 'app_providers.dart';

enum UpdateCheckTrigger { automatic, updatesView, manual, mutation }

class UpdateCheckState {
  const UpdateCheckState({
    this.results = const {},
    this.lastSuccessfulAt,
    this.checking = false,
    this.error,
  });

  final Map<String, UpdateAvailability> results;
  final DateTime? lastSuccessfulAt;
  final bool checking;
  final Object? error;

  UpdateCheckState copyWith({
    Map<String, UpdateAvailability>? results,
    DateTime? lastSuccessfulAt,
    bool? checking,
    Object? error,
    bool clearError = false,
  }) => UpdateCheckState(
    results: results ?? this.results,
    lastSuccessfulAt: lastSuccessfulAt ?? this.lastSuccessfulAt,
    checking: checking ?? this.checking,
    error: clearError ? null : error ?? this.error,
  );
}

final updateCheckClockProvider = Provider<DateTime Function()>(
  (_) =>
      () => DateTime.now().toUtc(),
);

final updateCheckProvider =
    AsyncNotifierProvider<UpdateCheckController, UpdateCheckState>(
      UpdateCheckController.new,
      retry: (_, _) => null,
    );

class UpdateCheckController extends AsyncNotifier<UpdateCheckState> {
  static const automaticTtl = Duration(hours: 6);
  static const updatesViewTtl = Duration(minutes: 2);
  static const manualDebounce = Duration(seconds: 10);

  Future<Map<String, UpdateAvailability>>? _inFlight;

  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);
  DateTime get _now => ref.read(updateCheckClockProvider)().toUtc();

  @override
  Future<UpdateCheckState> build() async {
    final cached = await _gateway.loadUpdateCheckCache();
    if (cached == null) return const UpdateCheckState();
    return UpdateCheckState(
      results: Map.unmodifiable(cached.results),
      lastSuccessfulAt: cached.checkedAt.toUtc(),
    );
  }

  Future<Map<String, UpdateAvailability>> check(
    List<InstalledSkill> skills, {
    required UpdateCheckTrigger trigger,
  }) async {
    final active = _inFlight;
    if (active != null) return active;
    final current = state.value ?? await future;
    final requiredKeys = _requiredKeys(skills);
    final ttl = switch (trigger) {
      UpdateCheckTrigger.automatic => automaticTtl,
      UpdateCheckTrigger.updatesView => updatesViewTtl,
      UpdateCheckTrigger.manual => manualDebounce,
      UpdateCheckTrigger.mutation => Duration.zero,
    };
    final checkedAt = current.lastSuccessfulAt;
    final covered = requiredKeys.every(current.results.containsKey);
    if (covered &&
        checkedAt != null &&
        _now.difference(checkedAt) >= Duration.zero &&
        _now.difference(checkedAt) < ttl) {
      return current.results;
    }
    if (requiredKeys.isEmpty) return const {};

    final operation = _performCheck(skills, current);
    _inFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_inFlight, operation)) _inFlight = null;
    }
  }

  Future<Map<String, UpdateAvailability>> _performCheck(
    List<InstalledSkill> skills,
    UpdateCheckState current,
  ) async {
    state = AsyncData(current.copyWith(checking: true, clearError: true));
    try {
      final results = Map<String, UpdateAvailability>.unmodifiable(
        await _gateway.checkUpdates(skills),
      );
      final checkedAt = _now;
      await _gateway.saveUpdateCheckCache(
        UpdateCheckCache(checkedAt: checkedAt, results: results),
      );
      state = AsyncData(
        UpdateCheckState(results: results, lastSuccessfulAt: checkedAt),
      );
      return results;
    } catch (error, stackTrace) {
      state = AsyncData(current.copyWith(checking: false, error: error));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Set<String> _requiredKeys(List<InstalledSkill> skills) => {
    for (final skill in skills)
      if (skill.provenance == LibraryProvenance.hub &&
          skill.packagePath.isNotEmpty)
        for (final target in skill.targets)
          packageScopeUpdateKey(
            skill.packagePath,
            target.scope,
            target.projectRoot,
          ),
  };
}
