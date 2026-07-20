/*
 * [INPUT]: Depends on DiscoverScreen state, localized failure copy, repository helpers, and shared card/installation widgets.
 * [OUTPUT]: Provides the Discover route, loading, empty, refresh, pagination, repository context, and detail-opening render methods.
 * [POS]: Serves as the private rendering implementation of the Discover journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../discover_screen.dart';

extension _DiscoverRendering on _DiscoverScreenState {
  Widget _discoverLeaderboardHeader(DiscoverState discoverState) {
    final hasQuery = controller.text.trim().isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkillSearchField(
            key: const Key('skill-search-input'),
            controller: controller,
            focusNode: focusNode,
            onSubmitted: search,
            onCleared: () => unawaited(search('')),
            onChanged: _searchChanged,
            active:
                submittedQuery != null &&
                controller.text.trim() == submittedQuery,
            loading: false,
            height: 45,
            appearance: SkillSearchAppearance.leaderboard,
            showShortcutHint: constraints.maxWidth >= 640,
          ),
          const SizedBox(height: 24),
          _DiscoverHeaderReveal(
            key: const Key('discover-leaderboard-tabs-motion'),
            visible: !hasQuery,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DiscoverLeaderboardTabs(
                  key: const Key('discovery-options-mode'),
                  selected: selectedRoute,
                  onSelected: _selectRoute,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _discoverPage() => KeyedSubtree(
    key: const ValueKey('discover-list'),
    child: switch (selectedRoute) {
      DiscoverRoute.search => _searchPage(),
      DiscoverRoute.ranking => _collectionPage(
        DiscoverRoute.ranking,
        context.l10n.allTimeRanking,
      ),
      DiscoverRoute.trending => _collectionPage(
        DiscoverRoute.trending,
        context.l10n.trendingNow,
      ),
      DiscoverRoute.hot => _collectionPage(
        DiscoverRoute.hot,
        context.l10n.hotNow,
      ),
    },
  );

  Widget _searchPage() => _body(DiscoverRoute.search);

  Widget _collectionPage(DiscoverRoute route, String title) => _body(route);

  Widget _body(DiscoverRoute route, {String? title}) {
    final state = ref.watch(discoverProvider).routes[route]!;
    final uiState = routeUiStates[route]!;
    final source = route == DiscoverRoute.search
        ? _gitSourceLabel(submittedQuery)
        : null;
    if (state.loading && state.results == null) {
      return source == null
          ? _discoverLoading(uiState, title)
          : _repositoryParsing(uiState);
    }
    if (state.error != null && state.results == null) {
      final copy = failureCopy(context, state.error!);
      return _discoverStateScroll(
        uiState,
        title,
        _DiscoverStatePanel(
          title: copy.title,
          message: copy.message,
          icon: HugeIcons.strokeRoundedAlertCircle,
          flat: true,
          action: TextButton(
            onPressed: () =>
                _loadRoute(route, reset: true, query: controller.text.trim()),
            style: TextButton.styleFrom(
              foregroundColor: context.skillsComponents.statusDanger,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(context.l10n.tryAgain),
          ),
        ),
      );
    }
    if (state.results == null) {
      return _discoverStateScroll(
        uiState,
        title,
        _DiscoverStatePanel(
          title: context.l10n.searchEmptyTitle,
          message: context.l10n.searchEmptyMessage,
          icon: HugeIcons.strokeRoundedSearch01,
        ),
      );
    }
    if (state.results!.isEmpty) {
      return _discoverStateScroll(
        uiState,
        title,
        _DiscoverStatePanel(
          title: source != null
              ? context.l10n.sourceSearchEmptyTitle
              : route == DiscoverRoute.search
              ? context.l10n.noSkillsTitle
              : context.l10n.collectionEmptyTitle,
          message: source != null
              ? context.l10n.sourceSearchEmptyMessage(source)
              : route == DiscoverRoute.search
              ? context.l10n.noSkillsMessage
              : context.l10n.collectionEmptyMessage,
          icon: source != null
              ? HugeIcons.strokeRoundedLink01
              : HugeIcons.strokeRoundedArchive02,
          action: source != null
              ? SkillsButton.outline(
                  enabled: false,
                  onPressed: () {},
                  child: Text(context.l10n.inspectSource),
                )
              : route == DiscoverRoute.search
              ? SkillsButton.outline(
                  onPressed: focusNode.requestFocus,
                  child: Text(context.l10n.focusSearch),
                )
              : null,
        ),
      );
    }
    final showMore = state.loadingMore || state.paginationError != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        return _DesktopDiscoverScroller(
          controller: uiState.scrollController,
          refreshing: state.refreshing,
          refreshError: state.refreshError == null
              ? null
              : failureCopy(context, state.refreshError!).message,
          canLoadMore:
              state.nextOffset != null &&
              !state.loading &&
              !state.refreshing &&
              !state.loadingMore,
          onRefresh: () => _loadRoute(
            route,
            reset: true,
            preserveResults: true,
            query: state.query,
          ),
          onLoadMore: () => _loadRoute(route, reset: false),
          child: CustomScrollView(
            key: ValueKey(
              route == DiscoverRoute.search
                  ? 'discover-results'
                  : 'discover-results-${route.name}',
            ),
            controller: uiState.scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              if (title != null) _discoverTitleSliver(title),
              if (source != null)
                _sourceContextSliver(source, state.results!, state.repository),
              SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 170,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final skill = state.results![index];
                  final cardFocus = uiState.focusNodeFor(skill.id);
                  return SkillCard(
                    skill: skill,
                    focusNode: cardFocus,
                    onTap: () => _openDetail(skill, cardFocus),
                    onInstall: (present) =>
                        unawaited(_installFromCard(present, skill)),
                  );
                }, childCount: state.results!.length),
              ),
              if (showMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 4),
                    child: state.paginationError != null
                        ? Column(
                            children: [
                              Text(
                                failureCopy(
                                  context,
                                  state.paginationError!,
                                ).message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SkillsButton.outline(
                                onPressed: () =>
                                    _loadRoute(route, reset: false),
                                child: Text(context.l10n.tryAgain),
                              ),
                            ],
                          )
                        : const Center(
                            child: SkillsLoadingShape(
                              key: Key('discover-pagination-loading'),
                              size: 30,
                              variant: SkillsLoadingVariant.progressiveDots,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _repositoryParsing(_DiscoveryRouteUiState state) => Semantics(
    liveRegion: true,
    label: context.l10n.repositoryParsing,
    child: CustomScrollView(
      key: const ValueKey('discover-repository-loading'),
      controller: state.scrollController,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: const Alignment(0, -0.16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExcludeSemantics(child: SkillsRepositoryLoadingShape()),
                const SizedBox(height: 18),
                Text(
                  context.l10n.repositoryParsing,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _discoverLoading(_DiscoveryRouteUiState state, String? title) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1080
              ? 3
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          return Semantics(
            liveRegion: true,
            label: context.l10n.loading,
            child: CustomScrollView(
              key: const ValueKey('discover-skeleton'),
              controller: state.scrollController,
              slivers: [
                if (title != null) _discoverTitleSliver(title),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 170,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => const SkillCardSkeleton(),
                    childCount: columns * 3,
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _discoverStateScroll(
    _DiscoveryRouteUiState state,
    String? title,
    Widget child,
  ) => CustomScrollView(
    controller: state.scrollController,
    slivers: [
      if (title != null) _discoverTitleSliver(title),
      SliverToBoxAdapter(child: child),
    ],
  );

  Widget _discoverTitleSliver(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.35,
          height: 1.12,
        ),
      ),
    ),
  );

  Widget _sourceContextSliver(
    String source,
    List<SkillSummary> skills,
    RepositorySummary? repository,
  ) => SliverToBoxAdapter(
    child: Semantics(
      container: true,
      label: context.l10n.sourceResultsSummary(source, skills.length),
      child: Container(
        key: const Key('discover-source-context'),
        margin: const EdgeInsets.only(bottom: 22),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Theme.of(context).colorScheme.surfaceContainer
              : context.skillsComponents.cardRest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: _RepositorySourceHeader(
          source: source,
          skills: skills,
          repository: repository,
          onInstallAll: (present) => _installFromCard(
            present,
            skills.first,
            preferredAction: InstallLocationAction.repositorySkills,
          ),
        ),
      ),
    ),
  );

  void _openDetail(
    SkillSummary skill,
    FocusNode cardFocus, {
    bool openPlan = false,
  }) {
    updateState(() {
      selectedSkill = skill;
      selectedSkillFocus = cardFocus;
      final routeState = routeUiStates[selectedRoute]!;
      selectedSkillScrollOffset = routeState.scrollController.hasClients
          ? routeState.scrollController.offset
          : 0;
      openPlanOnDetailLoad = openPlan;
      detailTransitioning = true;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      detailTransition.value = 1;
      if (mounted) updateState(() => detailTransitioning = false);
    } else {
      unawaited(_animateDetailOpen(skill));
    }
  }

  Future<void> _animateDetailOpen(SkillSummary skill) async {
    await detailTransition.forward(from: 0);
    if (!mounted || selectedSkill?.id != skill.id) return;
    updateState(() => detailTransitioning = false);
  }

  Future<void> _closeDetail({required bool installed}) async {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final cardFocus = selectedSkillFocus;
    final routeState = routeUiStates[selectedRoute]!;
    final scrollOffset = selectedSkillScrollOffset;
    updateState(() => detailTransitioning = true);
    if (disableAnimations) {
      detailTransition.value = 0;
    } else {
      await detailTransition.reverse();
    }
    if (!mounted) return;
    updateState(() {
      selectedSkill = null;
      selectedSkillFocus = null;
      selectedSkillScrollOffset = 0;
      openPlanOnDetailLoad = false;
      detailTransitioning = false;
    });
    if (installed) {
      await _loadRoute(
        selectedRoute,
        reset: true,
        query: selectedRoute == DiscoverRoute.search
            ? controller.text.trim()
            : null,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !routeState.scrollController.hasClients) return;
        routeState.scrollController.jumpTo(
          scrollOffset.clamp(
            0,
            routeState.scrollController.position.maxScrollExtent,
          ),
        );
      });
    }
    if (!installed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !routeState.scrollController.hasClients) return;
        routeState.scrollController.jumpTo(
          scrollOffset.clamp(
            0,
            routeState.scrollController.position.maxScrollExtent,
          ),
        );
      });
    }
    if (cardFocus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) cardFocus.requestFocus();
      });
    }
  }
}
