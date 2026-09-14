/*
 * [INPUT]: Depends on Riverpod, SkillsGateway Agent inspection, and a periodic foreground-safe refresh cadence.
 * [OUTPUT]: Provides App-scoped stale-while-revalidate AgentCatalog state, lifecycle-safe single-flight loading, and explicit mutation refresh.
 * [POS]: Serves as the single local Agent capability source shared by Discover, Library, Settings, and installation flows.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
import 'app_providers.dart';

class AgentCatalogState {
  const AgentCatalogState({this.catalog, this.refreshing = false, this.error});

  final AgentCatalog? catalog;
  final bool refreshing;
  final Object? error;

  AgentCatalogState copyWith({
    AgentCatalog? catalog,
    bool? refreshing,
    Object? error,
    bool clearError = false,
  }) => AgentCatalogState(
    catalog: catalog ?? this.catalog,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : error ?? this.error,
  );
}

final agentCatalogProvider =
    NotifierProvider<AgentCatalogController, AgentCatalogState>(
      AgentCatalogController.new,
    );

class AgentCatalogController extends Notifier<AgentCatalogState> {
  static const refreshInterval = Duration(seconds: 60);
  Future<AgentCatalog>? _inFlight;
  DateTime? _lastSuccessAt;

  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);

  @override
  AgentCatalogState build() {
    final timer = Timer.periodic(
      refreshInterval,
      (_) => unawaited(refreshSilently()),
    );
    ref.onDispose(timer.cancel);
    Future<void>.microtask(refreshSilently);
    return const AgentCatalogState(refreshing: true);
  }

  Future<AgentCatalog> ensureLoaded() =>
      state.catalog == null ? refresh() : Future.value(state.catalog!);

  Future<AgentCatalog> refreshIfStale({
    Duration minimumAge = const Duration(seconds: 10),
  }) {
    final loadedAt = _lastSuccessAt;
    if (loadedAt != null && DateTime.now().difference(loadedAt) < minimumAge) {
      return Future.value(state.catalog!);
    }
    return refresh();
  }

  Future<void> refreshSilently() async {
    try {
      await refresh();
    } on Object {
      // State retains the last valid catalog and records the refresh error.
    }
  }

  Future<void> refreshIfStaleSilently() async {
    try {
      await refreshIfStale();
    } on Object {
      // State retains the last valid catalog and records the refresh error.
    }
  }

  Future<AgentCatalog> refresh() {
    final current = _inFlight;
    if (current != null) return current;
    state = state.copyWith(refreshing: true, clearError: true);
    final request = _completeRefresh();
    _inFlight = request;
    return request;
  }

  Future<AgentCatalog> _completeRefresh() async {
    try {
      final catalog = await _gateway.inspectAgents();
      if (ref.mounted) {
        _lastSuccessAt = DateTime.now();
        state = AgentCatalogState(catalog: catalog);
      }
      return catalog;
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = state.copyWith(refreshing: false, error: error);
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      _inFlight = null;
    }
  }
}
