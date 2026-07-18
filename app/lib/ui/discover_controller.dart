/*
 * [INPUT]: Depends on Riverpod, SkillsGateway discovery contracts, and the App-scoped Gateway provider.
 * [OUTPUT]: Provides immutable per-route discovery and Repository-summary caches plus race-safe search, initial-load, and pagination actions.
 * [POS]: Serves as the Discover journey's business-state boundary; scroll, focus, and transitions remain widget-owned.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skills_gateway.dart';
import 'app_providers.dart';

enum DiscoverRoute { search, ranking, trending, hot }

class DiscoverRouteState {
  const DiscoverRouteState({
    this.results,
    this.repository,
    this.error,
    this.nextOffset,
    this.generation = 0,
    this.loading = false,
    this.loadingMore = false,
  });

  final List<SkillSummary>? results;
  final RepositorySummary? repository;
  final Object? error;
  final int? nextOffset;
  final int generation;
  final bool loading;
  final bool loadingMore;

  DiscoverRouteState copyWith({
    List<SkillSummary>? results,
    bool clearResults = false,
    RepositorySummary? repository,
    bool clearRepository = false,
    Object? error,
    bool clearError = false,
    int? nextOffset,
    bool clearNextOffset = false,
    int? generation,
    bool? loading,
    bool? loadingMore,
  }) => DiscoverRouteState(
    results: clearResults ? null : results ?? this.results,
    repository: clearRepository ? null : repository ?? this.repository,
    error: clearError ? null : error ?? this.error,
    nextOffset: clearNextOffset ? null : nextOffset ?? this.nextOffset,
    generation: generation ?? this.generation,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

class DiscoverState {
  DiscoverState(Map<DiscoverRoute, DiscoverRouteState> routes)
    : routes = Map.unmodifiable(routes);

  factory DiscoverState.initial() => DiscoverState({
    for (final route in DiscoverRoute.values) route: const DiscoverRouteState(),
  });

  final Map<DiscoverRoute, DiscoverRouteState> routes;

  DiscoverState replace(DiscoverRoute route, DiscoverRouteState routeState) =>
      DiscoverState({...routes, route: routeState});
}

final discoverProvider = NotifierProvider<DiscoverController, DiscoverState>(
  DiscoverController.new,
);

class DiscoverController extends Notifier<DiscoverState> {
  SkillsGateway get _gateway => ref.read(skillsGatewayProvider);

  @override
  DiscoverState build() => DiscoverState.initial();

  void clearSearch() {
    final current = state.routes[DiscoverRoute.search]!;
    state = state.replace(
      DiscoverRoute.search,
      DiscoverRouteState(generation: current.generation + 1),
    );
  }

  Future<void> load(
    DiscoverRoute route, {
    required bool reset,
    String query = '',
  }) async {
    final current = state.routes[route]!;
    final nextOffset = reset ? 0 : current.nextOffset;
    if (nextOffset == null) return;
    final generation = reset ? current.generation + 1 : current.generation;
    state = state.replace(
      route,
      current.copyWith(
        clearError: true,
        clearResults: reset,
        clearRepository: reset,
        clearNextOffset: reset,
        generation: generation,
        loading: reset,
        loadingMore: !reset,
      ),
    );
    try {
      final page = await _gateway.discover(
        _collectionForRoute(route),
        query: query,
        offset: nextOffset,
      );
      final latest = state.routes[route]!;
      if (generation != latest.generation) return;
      state = state.replace(
        route,
        latest.copyWith(
          results: reset ? page.skills : [...?latest.results, ...page.skills],
          repository: reset ? page.repository : latest.repository,
          nextOffset: page.nextOffset,
          clearNextOffset: page.nextOffset == null,
          loading: false,
          loadingMore: false,
        ),
      );
    } catch (error) {
      final latest = state.routes[route]!;
      if (generation != latest.generation) return;
      state = state.replace(
        route,
        latest.copyWith(error: error, loading: false, loadingMore: false),
      );
    }
  }
}

DiscoveryCollection _collectionForRoute(DiscoverRoute route) => switch (route) {
  DiscoverRoute.search => DiscoveryCollection.search,
  DiscoverRoute.ranking => DiscoveryCollection.ranking,
  DiscoverRoute.trending => DiscoveryCollection.trending,
  DiscoverRoute.hot => DiscoveryCollection.hot,
};
