/*
 * [INPUT]: Depends on Riverpod, SkillsGateway discovery contracts, and the App-scoped Gateway provider.
 * [OUTPUT]: Provides immutable per-route discovery and Repository-summary caches plus query-bound, race-safe, lifecycle-safe initial-load, locale reload, refresh, and pagination actions.
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
    this.refreshError,
    this.paginationError,
    this.nextOffset,
    this.query = '',
    this.generation = 0,
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
  });

  final List<SkillSummary>? results;
  final RepositorySummary? repository;
  final Object? error;
  final Object? refreshError;
  final Object? paginationError;
  final int? nextOffset;
  final String query;
  final int generation;
  final bool loading;
  final bool refreshing;
  final bool loadingMore;

  DiscoverRouteState copyWith({
    List<SkillSummary>? results,
    bool clearResults = false,
    RepositorySummary? repository,
    bool clearRepository = false,
    Object? error,
    bool clearError = false,
    Object? refreshError,
    bool clearRefreshError = false,
    Object? paginationError,
    bool clearPaginationError = false,
    int? nextOffset,
    bool clearNextOffset = false,
    String? query,
    int? generation,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
  }) => DiscoverRouteState(
    results: clearResults ? null : results ?? this.results,
    repository: clearRepository ? null : repository ?? this.repository,
    error: clearError ? null : error ?? this.error,
    refreshError: clearRefreshError ? null : refreshError ?? this.refreshError,
    paginationError: clearPaginationError
        ? null
        : paginationError ?? this.paginationError,
    nextOffset: clearNextOffset ? null : nextOffset ?? this.nextOffset,
    query: query ?? this.query,
    generation: generation ?? this.generation,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
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

  Future<void> reloadLocalizedContent() async {
    final loadedRoutes = [
      for (final entry in state.routes.entries)
        if (entry.value.results != null)
          (route: entry.key, query: entry.value.query),
    ];
    await Future.wait([
      for (final entry in loadedRoutes)
        load(
          entry.route,
          reset: true,
          query: entry.query,
          preserveResults: true,
        ),
    ]);
  }

  Future<void> load(
    DiscoverRoute route, {
    required bool reset,
    String query = '',
    bool preserveResults = false,
  }) async {
    final current = state.routes[route]!;
    if (!reset &&
        (current.loading || current.refreshing || current.loadingMore)) {
      return;
    }
    if (reset && preserveResults && (current.loading || current.refreshing)) {
      return;
    }
    final nextOffset = reset ? 0 : current.nextOffset;
    if (nextOffset == null) return;
    final generation = reset ? current.generation + 1 : current.generation;
    final requestQuery = reset ? query : current.query;
    state = state.replace(
      route,
      current.copyWith(
        clearError: true,
        clearRefreshError: true,
        clearPaginationError: true,
        clearResults: reset && !preserveResults,
        clearRepository: reset && !preserveResults,
        clearNextOffset: reset,
        query: requestQuery,
        generation: generation,
        loading: reset && !preserveResults,
        refreshing: reset && preserveResults,
        loadingMore: !reset,
      ),
    );
    try {
      final page = await _gateway.discover(
        _collectionForRoute(route),
        query: requestQuery,
        offset: nextOffset,
      );
      if (!ref.mounted) return;
      final latest = state.routes[route]!;
      if (generation != latest.generation) return;
      state = state.replace(
        route,
        latest.copyWith(
          results: reset
              ? page.skills
              : _appendUnique(latest.results ?? const [], page.skills),
          repository: reset ? page.repository : latest.repository,
          nextOffset: page.nextOffset,
          clearNextOffset: page.nextOffset == null,
          loading: false,
          refreshing: false,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      final latest = state.routes[route]!;
      if (generation != latest.generation) return;
      state = state.replace(
        route,
        latest.copyWith(
          error: reset && !preserveResults ? error : null,
          refreshError: reset && preserveResults ? error : null,
          paginationError: !reset ? error : null,
          loading: false,
          refreshing: false,
          loadingMore: false,
        ),
      );
    }
  }
}

List<SkillSummary> _appendUnique(
  List<SkillSummary> current,
  List<SkillSummary> incoming,
) {
  final seen = current.map((skill) => skill.coordinateKey).toSet();
  return [
    ...current,
    ...incoming.where((skill) => seen.add(skill.coordinateKey)),
  ];
}

DiscoveryCollection _collectionForRoute(DiscoverRoute route) => switch (route) {
  DiscoverRoute.search => DiscoveryCollection.search,
  DiscoverRoute.ranking => DiscoveryCollection.ranking,
  DiscoverRoute.trending => DiscoveryCollection.trending,
  DiscoverRoute.hot => DiscoveryCollection.hot,
};
