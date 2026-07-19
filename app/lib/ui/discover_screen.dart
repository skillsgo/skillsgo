/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, Riverpod Discover state, installation flows, localization, and shared components.
 * [OUTPUT]: Provides the Discover destination, route-local desktop pull-to-refresh and automatic pagination behavior, catalog search, Repository source headers, detail transitions, and installation entry points.
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
  Timer? searchDebounce;
  late final AnimationController detailTransition;

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_searchFocusChanged);
    HardwareKeyboard.instance.addHandler(_handleSearchHardwareKey);
    widget.onDismissHandlerChanged(dismissDetail);
    detailTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      reverseDuration: const Duration(milliseconds: 200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadRoute(DiscoverRoute.hot, reset: true));
      if (MediaQuery.sizeOf(context).width >= 640) {
        focusNode.requestFocus();
      }
    });
  }

  void _searchFocusChanged() {
    if (mounted) setState(() {});
  }

  bool _handleSearchHardwareKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.slash || focusNode.hasFocus) {
      return false;
    }
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final editingText =
        focusedContext?.widget is EditableText ||
        focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    var focusedRender = focusedContext?.findRenderObject();
    final discoverRender = context.findRenderObject();
    var focusInsideDiscover = focusedRender == null;
    while (focusedRender != null && !focusInsideDiscover) {
      focusInsideDiscover = identical(focusedRender, discoverRender);
      focusedRender = focusedRender.parent;
    }
    if (editingText || !focusInsideDiscover) return false;
    focusNode.requestFocus();
    return true;
  }

  Future<void> search([String? value]) async {
    searchDebounce?.cancel();
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

  void _searchChanged(String rawValue) {
    searchDebounce?.cancel();
    final query = rawValue.trim();
    if (query.isEmpty) {
      unawaited(search(''));
      return;
    }
    setState(() {
      selectedSkill = null;
      selectedSkillFocus = null;
      selectedRoute = DiscoverRoute.search;
      submittedQuery = query;
    });
    if (query.length < 2) {
      ref.read(discoverProvider.notifier).clearSearch();
      return;
    }
    final debounceMilliseconds = (350 - 50 * query.length).clamp(150, 250);
    searchDebounce = Timer(
      Duration(milliseconds: debounceMilliseconds),
      () => unawaited(search(query)),
    );
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
    bool preserveResults = false,
  }) async {
    final uiState = routeUiStates[route]!;
    if (reset && !preserveResults && uiState.scrollController.hasClients) {
      uiState.scrollController.jumpTo(0);
    }
    await ref
        .read(discoverProvider.notifier)
        .load(
          route,
          reset: reset,
          query: query ?? controller.text.trim(),
          preserveResults: preserveResults,
        );
  }

  Future<void> _installFromCard(
    InstallLocationMenuPresenter present,
    SkillSummary skill, {
    InstallLocationAction preferredAction = InstallLocationAction.currentSkill,
  }) async {
    final operation = ref.read(installOperationProvider(skill.id));
    if (operation.operating) return;
    try {
      late SkillDetail detail;
      late AgentCatalog catalog;
      late PersonalRiskPolicy riskPolicy;
      late List<SkillSummary> repositorySkills;
      var projects = const <AddedProject>[];
      await present(
        InstallLocationMenuRequest.loading(
          summary: skill,
          loader: () async {
            final catalogFuture = ref
                .read(agentCatalogProvider.notifier)
                .ensureLoaded();
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
              preferredAction: preferredAction,
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
        (choice) async {
          try {
            if (choice.selections.isEmpty) {
              return InstallLocationSubmission.failure(
                title: context.l10n.installationFailed,
                message: context.l10n.installationPlanFailed,
              );
            }
            if (choice.action == InstallLocationAction.repositorySkills) {
              await _installRepositorySkills(
                widget.gateway,
                repositorySkills,
                choice.selections,
                riskPolicy,
              );
            } else {
              final execution = await operation.installTargets(
                widget.gateway,
                skill,
                detail.immutableVersion,
                choice.selections,
                confirmRisk: true,
                allowCritical: riskPolicy.allowCriticalOverride,
              );
              if (execution == null || operation.error != null) {
                if (!mounted) {
                  return const InstallLocationSubmission.success();
                }
                final copy = _failureCopy(
                  context,
                  operation.error ?? StateError('Installation failed.'),
                );
                return InstallLocationSubmission.failure(
                  title: context.l10n.installationFailed,
                  message: copy.message,
                );
              }
            }
            if (mounted) {
              ref.invalidate(libraryProvider);
            }
            return const InstallLocationSubmission.success();
          } on Object catch (error) {
            if (!mounted) {
              return const InstallLocationSubmission.success();
            }
            final copy = _failureCopy(context, error);
            return InstallLocationSubmission.failure(
              title: context.l10n.installationFailed,
              message: copy.message,
            );
          }
        },
      );
    } on Object {
      // Loading failures are rendered by the installation popover itself.
    }
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleSearchHardwareKey);
    focusNode.removeListener(_searchFocusChanged);
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
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const ActivateIntent(),
        if (focusNode.hasFocus && controller.text.isNotEmpty)
          const SingleActivator(LogicalKeyboardKey.escape):
              const DismissIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) focusNode.requestFocus();
              });
              return null;
            },
          ),
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              controller.clear();
              unawaited(search());
              return null;
            },
          ),
        },
        child: SkillsContentFrame(
          child: Stack(
            key: const Key('discover-body-stack'),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _discoverLeaderboardHeader(discoverState),
                          Expanded(child: _discoverPage()),
                        ],
                      ),
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
      final copy = _failureCopy(context, state.error!);
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
              : _failureCopy(context, state.refreshError!).message,
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
                                _failureCopy(
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

class _RepositorySourceHeader extends StatelessWidget {
  const _RepositorySourceHeader({
    required this.source,
    required this.skills,
    required this.onInstallAll,
    this.repository,
  });

  final String source;
  final List<SkillSummary> skills;
  final ValueChanged<InstallLocationMenuPresenter> onInstallAll;
  final RepositorySummary? repository;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstSkill = skills.first;
    final summary = repository;
    final description = summary?.description.trim() ?? '';
    final metadata = <String>[
      if ((summary?.stars ?? 0) > 0)
        '★ ${_repositoryCompactCount(summary!.stars)}',
      context.l10n.skillCount(skills.length),
      if (summary?.license?.trim().isNotEmpty ?? false)
        summary!.license!.trim(),
      if (summary?.updatedAt != null)
        '${context.l10n.detailUpdated} ${_repositoryDate(summary!.updatedAt!)}',
    ];
    final version = summary?.latestVersion.isNotEmpty == true
        ? summary!.latestVersion
        : firstSkill.latestVersion;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepositoryAvatar(
          source: source,
          imageUrl: summary?.imageUrl ?? firstSkill.imageUrl,
          size: 88,
          borderRadius: 16,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _repositorySourceLabel(source),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var index = 0; index < metadata.length; index++) ...[
                    if (index > 0)
                      Text('·', style: TextStyle(color: scheme.outline)),
                    Text(
                      metadata[index],
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (version.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 150),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _repositoryVersionLabel(context, version),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.skillsTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 28),
            InstallLocationMenuAnchor(
              builder: (context, present) => PrimaryCapsuleButton(
                key: const Key('repository-install-all'),
                label: context.l10n.installAll,
                height: 40,
                horizontalPadding: 18,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                onPressed: () => onInstallAll(present),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _repositoryDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _repositorySourceLabel(String source) {
  final segments = source.split('/');
  return segments.length > 1 && segments.first.contains('.')
      ? segments.skip(1).join(' / ')
      : source;
}

String _repositoryCompactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}K';
  }
  return '$value';
}

String _repositoryVersionLabel(BuildContext context, String version) {
  if (RegExp(r'^v\d+\.\d+\.\d+').hasMatch(version)) return version;
  return context.l10n.latestCommit;
}

class _DiscoverLeaderboardTabs extends StatefulWidget {
  const _DiscoverLeaderboardTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DiscoverRoute selected;
  final ValueChanged<DiscoverRoute> onSelected;

  @override
  State<_DiscoverLeaderboardTabs> createState() =>
      _DiscoverLeaderboardTabsState();
}

class _DiscoverLeaderboardTabsState extends State<_DiscoverLeaderboardTabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position;

  static int _indexOf(DiscoverRoute route) => switch (route) {
    DiscoverRoute.ranking => 0,
    DiscoverRoute.trending => 1,
    DiscoverRoute.hot => 2,
    DiscoverRoute.search => 0,
  };

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: _indexOf(widget.selected).toDouble(),
    )..addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant _DiscoverLeaderboardTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _indexOf(widget.selected).toDouble();
    if (_position.value == target) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = target;
      return;
    }
    _position.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 32),
        _position.value,
        target,
        _position.velocity,
      ),
    );
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final components = context.skillsComponents;
    final tabs = <(DiscoverRoute, String)>[
      (DiscoverRoute.ranking, context.l10n.ranking),
      (DiscoverRoute.trending, context.l10n.trending),
      (DiscoverRoute.hot, context.l10n.hot),
    ];
    final textStyle = context.skillsTypography.bodySecondary.copyWith(
      height: 20 / 14,
    );
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final widths = tabs.map((tab) {
      final painter = TextPainter(
        text: TextSpan(text: tab.$2, style: textStyle),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      return painter.width;
    }).toList();
    final offsets = <double>[];
    var offset = 0.0;
    for (final width in widths) {
      offsets.add(offset);
      offset += width + 16;
    }
    double interpolate(List<double> values, double position) {
      final lower = position.floor().clamp(0, values.length - 2);
      return values[lower] +
          (values[lower + 1] - values[lower]) * (position - lower);
    }

    final indicatorLeft = interpolate(offsets, _position.value);
    final indicatorWidth = interpolate(widths, _position.value);
    return Semantics(
      container: true,
      label: context.l10n.discoverNavigation,
      child: SizedBox(
        height: 26,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                for (var index = 0; index < tabs.length; index++) ...[
                  Semantics(
                    label: tabs[index].$2,
                    excludeSemantics: true,
                    selected: tabs[index].$1 == widget.selected,
                    button: true,
                    onTap: () => widget.onSelected(tabs[index].$1),
                    child: TextButton(
                      key: ValueKey('discover-tab-${tabs[index].$1.name}'),
                      onPressed: () => widget.onSelected(tabs[index].$1),
                      style: ButtonStyle(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.only(bottom: 4),
                        ),
                        minimumSize: const WidgetStatePropertyAll(Size.zero),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: const WidgetStatePropertyAll(
                          RoundedRectangleBorder(),
                        ),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (tabs[index].$1 == widget.selected ||
                              states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused)) {
                            return scheme.onSurface;
                          }
                          return scheme.onSurfaceVariant;
                        }),
                        textStyle: WidgetStatePropertyAll(textStyle),
                      ),
                      child: Text(tabs[index].$2),
                    ),
                  ),
                  if (index != tabs.length - 1) const SizedBox(width: 16),
                ],
              ],
            ),
            Positioned(
              key: const Key('discover-tab-indicator'),
              left: indicatorLeft,
              bottom: 0,
              width: indicatorWidth,
              height: 2,
              child: ColoredBox(color: components.focusRing),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverHeaderReveal extends StatelessWidget {
  const _DiscoverHeaderReveal({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: const Cubic(0, 0, 0.2, 1),
      builder: (context, progress, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: progress,
          child: Opacity(opacity: progress, child: child),
        ),
      ),
      child: ExcludeSemantics(excluding: !visible, child: child),
    );
  }
}

class _DiscoverStatePanel extends StatelessWidget {
  const _DiscoverStatePanel({
    required this.title,
    required this.message,
    required this.icon,
    this.action,
    this.flat = false,
  });

  final String title;
  final String message;
  final List<List<dynamic>> icon;
  final Widget? action;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: flat ? 720 : double.infinity),
        child: Container(
          key: const Key('discover-state-panel'),
          width: double.infinity,
          padding: flat
              ? const EdgeInsets.symmetric(horizontal: 22, vertical: 16)
              : const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: flat
              ? BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                )
              : BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  border: Border.all(
                    color: context.skillsComponents.controlBorder,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
          child: Row(
            children: [
              if (flat)
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      size: 28,
                      strokeWidth: 1.5,
                      color: context.skillsComponents.statusDanger,
                    ),
                  ),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HugeIcon(
                    icon: icon,
                    size: 20,
                    strokeWidth: 1.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

String? _gitSourceLabel(String? rawInput) {
  final input = rawInput?.trim() ?? '';
  if (input.isEmpty || input.contains(RegExp(r'\s'))) return null;
  final candidate = input.contains('://') ? input : 'https://$input';
  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.host.contains('.')) return null;
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (segments.length < 2) return null;
  final boundary = segments.indexOf('-');
  final sourceSegments = boundary >= 2 ? segments.take(boundary) : segments;
  final path = sourceSegments.join('/').replaceFirst(RegExp(r'@[^/]+$'), '');
  return '${uri.host.toLowerCase()}/$path';
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

class _DesktopDiscoverScroller extends StatefulWidget {
  const _DesktopDiscoverScroller({
    required this.controller,
    required this.refreshing,
    required this.canLoadMore,
    required this.onRefresh,
    required this.onLoadMore,
    required this.child,
    this.refreshError,
  });

  final ScrollController controller;
  final bool refreshing;
  final bool canLoadMore;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Widget child;
  final String? refreshError;

  @override
  State<_DesktopDiscoverScroller> createState() =>
      _DesktopDiscoverScrollerState();
}

class _DesktopDiscoverScrollerState extends State<_DesktopDiscoverScroller> {
  static const _refreshThreshold = 44.0;
  static const _paginationThreshold = 560.0;
  static const _minimumRefreshVisibility = Duration(milliseconds: 400);

  double _pullExtent = 0;
  bool _refreshGestureActive = false;
  bool _refreshRequestActive = false;
  bool _loadMoreScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleUnderfilledPagination();
  }

  @override
  void didUpdateWidget(_DesktopDiscoverScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.canLoadMore) _loadMoreScheduled = false;
    if (widget.canLoadMore && !oldWidget.canLoadMore) {
      _scheduleUnderfilledPagination();
    }
  }

  void _scheduleUnderfilledPagination() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.canLoadMore || _loadMoreScheduled) return;
      if (!widget.controller.hasClients ||
          widget.controller.position.extentAfter > _paginationThreshold) {
        return;
      }
      _requestNextPage();
    });
  }

  void _requestNextPage() {
    if (!widget.canLoadMore || _loadMoreScheduled) return;
    _loadMoreScheduled = true;
    unawaited(widget.onLoadMore());
  }

  Future<void> _beginRefresh() async {
    if (widget.refreshing || _refreshRequestActive) return;
    final startedAt = DateTime.now();
    _refreshRequestActive = true;
    setState(() {
      _refreshGestureActive = false;
      _pullExtent = _refreshThreshold;
    });
    await widget.onRefresh();
    final remaining =
        _minimumRefreshVisibility - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;
    if (widget.controller.hasClients) {
      final position = widget.controller.position;
      if (position.pixels < position.minScrollExtent) {
        widget.controller.jumpTo(position.minScrollExtent);
      }
    }
    setState(() {
      _refreshRequestActive = false;
      _refreshGestureActive = false;
      _pullExtent = 0;
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.extentAfter < _paginationThreshold) {
      _requestNextPage();
    }
    if (widget.refreshing || _refreshRequestActive) return false;

    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < notification.metrics.minScrollExtent) {
      setState(() {
        _refreshGestureActive = true;
        final nextExtent =
            ((notification.metrics.minScrollExtent -
                        notification.metrics.pixels) *
                    .72)
                .clamp(0, _refreshThreshold + 18);
        final nextExtentValue = nextExtent.toDouble();
        if (nextExtentValue > _pullExtent) _pullExtent = nextExtentValue;
      });
      if (_pullExtent >= _refreshThreshold) unawaited(_beginRefresh());
    } else if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      setState(() {
        _refreshGestureActive = true;
        _pullExtent = (_pullExtent + -notification.overscroll * .48).clamp(
          0,
          _refreshThreshold + 18,
        );
      });
      if (_pullExtent >= _refreshThreshold) unawaited(_beginRefresh());
    } else if ((notification is ScrollEndNotification ||
            notification is UserScrollNotification &&
                notification.direction == ScrollDirection.idle) &&
        _refreshGestureActive) {
      if (_pullExtent >= _refreshThreshold) {
        unawaited(_beginRefresh());
      } else {
        setState(() {
          _refreshGestureActive = false;
          _pullExtent = 0;
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final refreshActive = widget.refreshing || _refreshRequestActive;
    final visibleExtent = refreshActive ? _refreshThreshold : _pullExtent;
    final pullProgress = (visibleExtent / _refreshThreshold).clamp(0.0, 1.0);
    final offset = visibleExtent * 1.18;
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: offset),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.translate(offset: Offset(0, value), child: child),
            child: widget.child,
          ),
          Positioned(
            key: const Key('discover-refresh-loading'),
            top: 7,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ExcludeSemantics(
                excluding: visibleExtent == 0,
                child: Semantics(
                  liveRegion: refreshActive,
                  label: MaterialLocalizations.of(
                    context,
                  ).refreshIndicatorSemanticLabel,
                  child: Center(
                    child: AnimatedOpacity(
                      key: const Key('discover-refresh-opacity'),
                      opacity: pullProgress,
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: TickerMode(
                        enabled: !reduceMotion && visibleExtent > 0,
                        child: SkillsLoadingShape(
                          size: 34,
                          progress: refreshActive ? null : pullProgress,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!refreshActive &&
              visibleExtent == 0 &&
              widget.refreshError != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  key: const Key('discover-refresh-error'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.refreshError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
