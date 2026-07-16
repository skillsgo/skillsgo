/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, Riverpod Discover state, installation flows, localization, and shared components.
 * [OUTPUT]: Provides the Discover destination, route-local UI lifecycle state, search, collections, detail transitions, and installation entry points.
 * [POS]: Serves as the Discover feature view module split from the desktop shell while sharing its private library contracts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'app_shell.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.gateway,
    required this.onInstalled,
    required this.onDismissHandlerChanged,
  });
  final SkillsGateway gateway;
  final VoidCallback onInstalled;
  final ValueChanged<VoidCallback?> onDismissHandlerChanged;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  final routeUiStates = <DiscoverRoute, _DiscoveryRouteUiState>{
    for (final route in DiscoverRoute.values) route: _DiscoveryRouteUiState(),
  };
  DiscoverRoute selectedRoute = DiscoverRoute.hot;
  DiscoverRoute lastCollectionRoute = DiscoverRoute.hot;
  String? submittedQuery;
  SkillSummary? selectedSkill;
  FocusNode? selectedSkillFocus;
  double selectedSkillScrollOffset = 0;
  bool openPlanOnDetailLoad = false;
  bool detailTransitioning = false;
  late final AnimationController detailTransition;

  @override
  void initState() {
    super.initState();
    widget.onDismissHandlerChanged(dismissDetail);
    detailTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      reverseDuration: const Duration(milliseconds: 200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadRoute(DiscoverRoute.hot, reset: true));
    });
  }

  Future<void> search([String? value]) async {
    final query = (value ?? controller.text).trim();
    if (query.isEmpty) {
      setState(() {
        selectedSkill = null;
        selectedSkillFocus = null;
        selectedRoute = lastCollectionRoute;
        submittedQuery = null;
      });
      ref.read(discoverProvider.notifier).clearSearch();
      return;
    }
    setState(() {
      selectedSkill = null;
      selectedSkillFocus = null;
      selectedRoute = DiscoverRoute.search;
      submittedQuery = query;
    });
    await _loadRoute(DiscoverRoute.search, reset: true, query: query);
  }

  void _selectRoute(DiscoverRoute route) {
    setState(() {
      selectedSkill = null;
      selectedSkillFocus = null;
      selectedRoute = route;
      if (route != DiscoverRoute.search) lastCollectionRoute = route;
    });
    final state = ref.read(discoverProvider).routes[route]!;
    if (route != DiscoverRoute.search &&
        state.results == null &&
        !state.loading) {
      unawaited(_loadRoute(route, reset: true));
    }
  }

  void dismissDetail() {
    if (selectedSkill == null) return;
    detailTransition.value = 0;
    setState(() {
      selectedSkill = null;
      selectedSkillFocus = null;
      selectedSkillScrollOffset = 0;
      openPlanOnDetailLoad = false;
      detailTransitioning = false;
    });
  }

  void _viewLibrary() {
    dismissDetail();
    widget.onInstalled();
  }

  Future<void> _loadRoute(
    DiscoverRoute route, {
    required bool reset,
    String? query,
  }) async {
    final uiState = routeUiStates[route]!;
    if (reset && uiState.scrollController.hasClients) {
      uiState.scrollController.jumpTo(0);
    }
    await ref
        .read(discoverProvider.notifier)
        .load(route, reset: reset, query: query ?? controller.text.trim());
  }

  Future<void> _installFromCard(
    InstallLocationMenuPresenter present,
    SkillSummary skill,
  ) async {
    final operation = ref.read(installOperationProvider(skill.id));
    if (operation.operating) return;
    try {
      late SkillDetail detail;
      late AgentCatalog catalog;
      late PersonalRiskPolicy riskPolicy;
      late List<SkillSummary> repositorySkills;
      var projects = const <AddedProject>[];
      final selections = await present(
        InstallLocationMenuRequest.loading(
          summary: skill,
          loader: () async {
            final catalogFuture = widget.gateway.inspectAgents();
            final projectsFuture = widget.gateway.loadAddedProjects();
            final riskPolicyFuture = widget.gateway.loadRiskPolicy();
            detail = await widget.gateway.loadRemoteDetail(skill);
            repositorySkills = [skill];
            final repositorySkillsFuture =
                _loadRepositorySkills(widget.gateway, skill, detail).then((
                  skills,
                ) {
                  repositorySkills = skills;
                  return skills;
                });
            final values = await Future.wait([
              catalogFuture,
              projectsFuture,
              riskPolicyFuture,
            ]);
            catalog = values[0] as AgentCatalog;
            projects = values[1] as List<AddedProject>;
            riskPolicy = values[2] as PersonalRiskPolicy;
            return InstallLocationMenuRequest(
              gateway: widget.gateway,
              catalog: catalog,
              detail: detail,
              projects: projects,
              repositorySkills: repositorySkills,
              repositorySkillsFuture: repositorySkillsFuture,
              onProjectAdded: (project) {
                final index = projects.indexWhere(
                  (item) => item.id == project.id,
                );
                projects = index < 0
                    ? [...projects, project]
                    : ([...projects]..[index] = project);
              },
            );
          },
        ),
      );
      if (!mounted || selections == null || selections.selections.isEmpty) {
        return;
      }
      if (selections.action == InstallLocationAction.repositorySkills) {
        await _installRepositorySkills(
          widget.gateway,
          repositorySkills,
          selections.selections,
          riskPolicy,
        );
        if (mounted) {
          await _loadRoute(
            selectedRoute,
            reset: true,
            query: selectedRoute == DiscoverRoute.search
                ? controller.text.trim()
                : null,
          );
        }
        return;
      }
      operation.editTargets();
      final plan = await operation.preflight(
        widget.gateway,
        skill,
        detail.immutableVersion,
        selections.selections,
        allowCritical: riskPolicy.allowCriticalOverride,
      );
      if (!mounted) return;
      final requiresReview =
          plan == null ||
          plan.summary.conflict > 0 ||
          plan.summary.blockedByRisk > 0;
      if (!requiresReview) {
        final execution = await operation.execute(widget.gateway);
        if (!mounted) return;
        if (execution != null &&
            execution.summary.failed == 0 &&
            execution.summary.conflict == 0) {
          ref.invalidate(libraryProvider);
          await _loadRoute(
            selectedRoute,
            reset: true,
            query: selectedRoute == DiscoverRoute.search
                ? controller.text.trim()
                : null,
          );
          return;
        }
      }
      await showSkillsDialog<_InstallationPlanOutcome>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _InstallationPlanDialog(
          gateway: widget.gateway,
          skill: skill,
          detail: detail,
          catalog: catalog,
          initialProjects: projects,
          operation: operation,
          riskPolicy: riskPolicy,
          onProjectAdded: (_) {},
        ),
      );
      if (mounted && operation.execution?.hasSuccess == true) {
        ref.invalidate(libraryProvider);
        await _loadRoute(
          selectedRoute,
          reset: true,
          query: selectedRoute == DiscoverRoute.search
              ? controller.text.trim()
              : null,
        );
      }
    } on Object {
      if (mounted) {
        _openDetail(
          skill,
          routeUiStates[selectedRoute]!.focusNodeFor(skill.id),
        );
      }
    }
  }

  @override
  void dispose() {
    widget.onDismissHandlerChanged(null);
    controller.dispose();
    focusNode.dispose();
    for (final state in routeUiStates.values) {
      state.dispose();
    }
    detailTransition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoverState = ref.watch(discoverProvider);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, meta: true): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              focusNode.requestFocus();
              return null;
            },
          ),
        },
        child: SkillsDestinationLayout(
          rail: SkillsSideRail<DiscoverRoute>(
            semanticLabel: context.l10n.discoverNavigation,
            selected: selectedRoute,
            onSelected: _selectRoute,
            header: SkillSearchField(
              controller: controller,
              focusNode: focusNode,
              onSubmitted: search,
              onCleared: search,
              onChanged: (_) => setState(() {}),
              active:
                  submittedQuery != null &&
                  controller.text.trim() == submittedQuery,
              loading: discoverState.routes[DiscoverRoute.search]!.loading,
              compact: true,
            ),
            items: [
              SkillsRailItem(
                value: DiscoverRoute.hot,
                label: context.l10n.hot,
                icon: HugeIcons.strokeRoundedFire,
              ),
              SkillsRailItem(
                value: DiscoverRoute.ranking,
                label: context.l10n.ranking,
                icon: HugeIcons.strokeRoundedChampion,
              ),
              SkillsRailItem(
                value: DiscoverRoute.trending,
                label: context.l10n.trending,
                icon: HugeIcons.strokeRoundedChartLineData01,
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: selectedSkill != null && !detailTransitioning,
                child: IgnorePointer(
                  ignoring: selectedSkill != null,
                  child: ExcludeFocus(
                    excluding: selectedSkill != null,
                    child: KeyedSubtree(
                      key: const ValueKey('discover-list-motion'),
                      child: _discoverPage(),
                    ),
                  ),
                ),
              ),
              if (selectedSkill != null)
                KeyedSubtree(
                  key: const ValueKey('discover-detail-motion'),
                  child: SlideTransition(
                    position: disableAnimations
                        ? const AlwaysStoppedAnimation(Offset.zero)
                        : Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: detailTransition,
                              curve: Curves.easeOutCubic,
                              reverseCurve: Curves.easeOutCubic,
                            ),
                          ),
                    child: ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: _RemoteDetailScreen(
                        key: ValueKey('discover-detail-${selectedSkill!.id}'),
                        gateway: widget.gateway,
                        skill: selectedSkill!,
                        operation: ref.read(
                          installOperationProvider(selectedSkill!.id),
                        ),
                        openPlanOnLoad: openPlanOnDetailLoad,
                        onBack: _closeDetail,
                        onViewLibrary: _viewLibrary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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

  Widget _searchPage() =>
      _body(DiscoverRoute.search, title: context.l10n.discoverTitle);

  Widget _collectionPage(DiscoverRoute route, String title) =>
      _body(route, title: title);

  Widget _body(DiscoverRoute route, {required String title}) {
    final state = ref.watch(discoverProvider).routes[route]!;
    final uiState = routeUiStates[route]!;
    if (state.loading && state.results == null) {
      return _discoverLoading(uiState, title);
    }
    if (state.error != null && state.results == null) {
      final copy = _failureCopy(context, state.error!);
      return _discoverStateScroll(
        uiState,
        title,
        EmptyState(
          title: copy.title,
          message: copy.message,
          action: SkillsButton(
            onPressed: () =>
                _loadRoute(route, reset: true, query: controller.text.trim()),
            child: Text(context.l10n.tryAgain),
          ),
        ),
      );
    }
    if (state.results == null) {
      return _discoverStateScroll(
        uiState,
        title,
        EmptyState(
          title: context.l10n.searchEmptyTitle,
          message: context.l10n.searchEmptyMessage,
        ),
      );
    }
    if (state.results!.isEmpty) {
      return _discoverStateScroll(
        uiState,
        title,
        EmptyState(
          title: route == DiscoverRoute.search
              ? context.l10n.noSkillsTitle
              : context.l10n.collectionEmptyTitle,
          message: route == DiscoverRoute.search
              ? context.l10n.noSkillsMessage
              : context.l10n.collectionEmptyMessage,
          action: route == DiscoverRoute.search
              ? SkillsButton.outline(
                  onPressed: focusNode.requestFocus,
                  child: Text(context.l10n.focusSearch),
                )
              : null,
        ),
      );
    }
    final showMore = state.nextOffset != null || state.loadingMore;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        return CustomScrollView(
          key: ValueKey(
            route == DiscoverRoute.search
                ? 'discover-results'
                : 'discover-results-${route.name}',
          ),
          controller: uiState.scrollController,
          slivers: [
            _discoverTitleSliver(title),
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
                  child: state.error != null
                      ? Column(
                          children: [
                            Text(
                              _failureCopy(context, state.error!).message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SkillsButton.outline(
                              onPressed: () => _loadRoute(route, reset: false),
                              child: Text(context.l10n.tryAgain),
                            ),
                          ],
                        )
                      : Center(
                          child: SkillsButton.outline(
                            enabled: !state.loadingMore,
                            onPressed: () => _loadRoute(route, reset: false),
                            child: state.loadingMore
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(context.l10n.loadMore),
                          ),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _discoverLoading(_DiscoveryRouteUiState state, String title) =>
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
                _discoverTitleSliver(title),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: 170,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => const _SkillCardSkeleton(),
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
    String title,
    Widget child,
  ) => CustomScrollView(
    controller: state.scrollController,
    slivers: [
      _discoverTitleSliver(title),
      SliverFillRemaining(hasScrollBody: false, child: child),
    ],
  );

  Widget _discoverTitleSliver(String title) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: SkillsTokens.serifFamily,
          fontSize: 38,
          fontWeight: FontWeight.w200,
        ),
      ),
    ),
  );

  void _openDetail(
    SkillSummary skill,
    FocusNode cardFocus, {
    bool openPlan = false,
  }) {
    setState(() {
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
      if (mounted) setState(() => detailTransitioning = false);
    } else {
      unawaited(_animateDetailOpen(skill));
    }
  }

  Future<void> _animateDetailOpen(SkillSummary skill) async {
    await detailTransition.forward(from: 0);
    if (!mounted || selectedSkill?.id != skill.id) return;
    setState(() => detailTransitioning = false);
  }

  Future<void> _closeDetail({required bool installed}) async {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final cardFocus = selectedSkillFocus;
    final routeState = routeUiStates[selectedRoute]!;
    final scrollOffset = selectedSkillScrollOffset;
    setState(() => detailTransitioning = true);
    if (disableAnimations) {
      detailTransition.value = 0;
    } else {
      await detailTransition.reverse();
    }
    if (!mounted) return;
    setState(() {
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

class _DiscoveryRouteUiState {
  final scrollController = ScrollController();
  final focusNodes = <String, FocusNode>{};

  FocusNode focusNodeFor(String skillId) => focusNodes.putIfAbsent(
    skillId,
    () => FocusNode(debugLabel: 'skill-card-$skillId'),
  );

  void dispose() {
    scrollController.dispose();
    for (final node in focusNodes.values) {
      node.dispose();
    }
  }
}
