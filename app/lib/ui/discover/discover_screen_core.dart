/*
 * [INPUT]: Depends on the Discover journey library, Riverpod controller state, focus/scroll primitives, and installation entry points.
 * [OUTPUT]: Provides the public DiscoverScreen plus route-local lifecycle, search intent, detail transitions, and root rendering.
 * [POS]: Serves as the state-owning core of the Discover journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../discover_screen.dart';

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
  void updateState(VoidCallback change) => setState(change);

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
                loadRepositorySkills(widget.gateway, skill, detail).then((
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
          final submission = await submitInstallationRequest(
            context,
            operation,
            InstallationSubmissionRequest(
              choice: choice,
              skill: skill,
              immutableVersion: skill.latestVersion,
              repositorySkills: repositorySkills,
              riskPolicy: riskPolicy,
            ),
          );
          if (submission.succeeded && mounted) {
            ref.invalidate(libraryProvider);
          }
          return submission;
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
                      child: RemoteDetailScreen(
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
}
