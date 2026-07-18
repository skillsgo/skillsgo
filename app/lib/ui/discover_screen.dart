/*
 * [INPUT]: Depends on the app_shell library for Flutter UI primitives, Riverpod Discover state, installation flows, localization, and shared components.
 * [OUTPUT]: Provides the Discover destination, route-local UI lifecycle state, catalog search, Git-source-aware result presentation, detail transitions, and installation entry points.
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
    focusNode.addListener(_searchFocusChanged);
    HardwareKeyboard.instance.addHandler(_handleSearchHardwareKey);
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
      await present(
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
              await _loadRoute(
                selectedRoute,
                reset: true,
                query: selectedRoute == DiscoverRoute.search
                    ? controller.text.trim()
                    : null,
              );
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
        child: SkillsDestinationLayout(
          rail: SkillsSideRail<DiscoverRoute>(
            key: const Key('discovery-options-mode'),
            semanticLabel: context.l10n.discoverNavigation,
            selected: selectedRoute,
            onSelected: _selectRoute,
            header: SkillSearchField(
              key: const Key('skill-search-input'),
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

  Widget _body(DiscoverRoute route, {String? title}) {
    final state = ref.watch(discoverProvider).routes[route]!;
    final uiState = routeUiStates[route]!;
    final source = route == DiscoverRoute.search
        ? _gitSourceLabel(submittedQuery)
        : null;
    if (state.loading && state.results == null) {
      return _discoverLoading(uiState, title);
    }
    if (state.error != null && state.results == null) {
      final copy = _failureCopy(context, state.error!);
      return _discoverStateScroll(
        uiState,
        title,
        _DiscoverStatePanel(
          title: copy.title,
          message: copy.message,
          icon: Icons.error_outline_rounded,
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
        _DiscoverStatePanel(
          title: context.l10n.searchEmptyTitle,
          message: context.l10n.searchEmptyMessage,
          icon: Icons.search_rounded,
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
              ? Icons.link_rounded
              : Icons.inventory_2_outlined,
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
            if (title != null) _discoverTitleSliver(title),
            if (source != null)
              _sourceContextSliver(source, state.results!.length),
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

  Widget _sourceContextSliver(String source, int count) => SliverToBoxAdapter(
    child: Semantics(
      container: true,
      label: context.l10n.sourceResultsSummary(source, count),
      child: Container(
        key: const Key('discover-source-context'),
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(color: context.skillsComponents.controlBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.link_rounded, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.skillsFromLink,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.textSecondary,
                      fontFamily: SkillsTokens.monoFamily,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.skillCount(count),
              style: TextStyle(
                color: Theme.of(context).colorScheme.textSecondary,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
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

class _DiscoverStatePanel extends StatelessWidget {
  const _DiscoverStatePanel({
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('discover-state-panel'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: context.skillsComponents.controlBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
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
