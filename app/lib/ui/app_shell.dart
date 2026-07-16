/*
 * [INPUT]: Depends on SkillsGateway contracts, localized copy, the vendored named-preset Bloom color picker, native Material components, the accessible themeable primary folder, stateful nested navigation, and SkillsGo brand tokens.
 * [OUTPUT]: Provides the desktop shell with persistent themeable folder-tab navigation plus Installation/Update/Target Management/External Adoption flows, offline recovery alerts, Local install-more/export actions, opaque directional Skill detail transitions and glassy scroll-aware detail chrome, outage-resilient managed/external Library detail, project and Agent views, operations, and Settings journeys.
 * [POS]: Serves as the primary rendered product surface and translates domain states into accessible localized UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path/path.dart' as p;
import 'bloom_color_picker/bloom_color_picker.dart';
import 'discrete_tabs/discrete_tabs.dart';
import 'native_components.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'agent_logo.dart';
import 'brand.dart';
import 'brand_theme_presets.dart';
import 'color_scheme_inspector.dart';
import 'install_location_popover.dart';
import 'nested_navigation.dart';
import 'primary_folder_shell.dart';
import 'skill_markdown_view.dart';

extension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

({String title, String message}) _failureCopy(
  BuildContext context,
  Object error, {
  bool detail = false,
}) {
  final kind = error is SkillsException ? error.kind : SkillsFailureKind.server;
  return switch (kind) {
    SkillsFailureKind.validation => (
      title: context.l10n.validationTitle,
      message: context.l10n.validationMessage,
    ),
    SkillsFailureKind.server => (
      title: context.l10n.serverTitle,
      message: context.l10n.serverMessage,
    ),
    SkillsFailureKind.timeout => (
      title: context.l10n.timeoutTitle,
      message: context.l10n.timeoutMessage,
    ),
    SkillsFailureKind.offline => (
      title: context.l10n.offlineTitle,
      message: context.l10n.offlineMessage,
    ),
    SkillsFailureKind.invalidResponse when detail => (
      title: context.l10n.detailInvalidTitle,
      message: context.l10n.detailInvalidMessage,
    ),
    SkillsFailureKind.invalidResponse => (
      title: context.l10n.invalidResponseTitle,
      message: context.l10n.invalidResponseMessage,
    ),
    SkillsFailureKind.artifactUnavailable => (
      title: context.l10n.artifactUnavailableTitle,
      message: context.l10n.artifactUnavailableMessage,
    ),
  };
}

String _cliStatusMessage(BuildContext context, CliStatus status) =>
    switch (status.issue) {
      CliIssue.missing => context.l10n.cliMissingBundled,
      CliIssue.damaged => context.l10n.cliDamagedBundled,
      CliIssue.incompatible => context.l10n.cliIncompatibleBundled,
      null => status.message ?? context.l10n.cliNeedsAttention,
    };

enum _Destination { discover, library, settings }

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.gateway});

  final SkillsGateway gateway;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final discoverKey = GlobalKey<_DiscoverScreenState>();
  _Destination destination = _Destination.discover;
  int libraryRevision = 0;
  CliStatus? cliStatus;
  String folderTheme = '#514532';
  AppThemeMode themeMode = AppThemeMode.system;

  @override
  void initState() {
    super.initState();
    unawaited(_detectCli());
    unawaited(_loadFolderTheme());
    unawaited(_loadThemeMode());
  }

  Future<void> _detectCli() async {
    final detected = await widget.gateway.detectCli();
    if (mounted) setState(() => cliStatus = detected);
  }

  static const _legacyFolderThemes = <String, Color>{
    'manila': Color(0xFF514532),
    'blue': Color(0xFF294556),
    'sage': Color(0xFF3D5141),
    'charcoal': Color(0xFF292A2B),
  };

  Color get _folderColor => _folderThemeColor(folderTheme);

  Future<void> _loadFolderTheme() async {
    final saved = await widget.gateway.loadFolderTheme();
    if (mounted) {
      setState(() => folderTheme = _folderThemeHex(_folderThemeColor(saved)));
    }
  }

  Future<void> _setFolderTheme(Color value) async {
    final theme = _folderThemeHex(value);
    setState(() => folderTheme = theme);
    await widget.gateway.saveFolderTheme(theme);
  }

  Future<void> _loadThemeMode() async {
    final saved = await widget.gateway.loadThemeMode();
    if (mounted) setState(() => themeMode = saved);
  }

  Future<void> _setThemeMode(AppThemeMode value) async {
    setState(() => themeMode = value);
    await widget.gateway.saveThemeMode(value);
  }

  Brightness _effectiveBrightness(BuildContext context) => switch (themeMode) {
    AppThemeMode.system => MediaQuery.platformBrightnessOf(context),
    AppThemeMode.light => Brightness.light,
    AppThemeMode.dark => Brightness.dark,
  };

  static Color _folderThemeColor(String value) {
    final legacy = _legacyFolderThemes[value];
    if (legacy != null) return legacy;
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null || normalized.length != 6) {
      return _legacyFolderThemes['manila']!;
    }
    return Color(0xFF000000 | parsed);
  }

  static String _folderThemeHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _showLibrary() => setState(() {
    destination = _Destination.library;
    libraryRevision++;
  });

  @override
  Widget build(BuildContext context) {
    final theme = buildSkillsTheme(
      _folderColor,
      brightness: _effectiveBrightness(context),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return SkillsBackground(
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Column(
                  children: [
                    if (cliStatus != null && !cliStatus!.isReady)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
                        child: _CliBanner(
                          status: cliStatus!,
                          onOpenSettings: () => setState(
                            () => destination = _Destination.settings,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
                        child: SkillsPrimaryFolder<_Destination>(
                          tabs: [
                            SkillsFolderTab(
                              id: 'discover',
                              value: _Destination.discover,
                              label: context.l10n.discover,
                            ),
                            SkillsFolderTab(
                              id: 'library',
                              value: _Destination.library,
                              label: context.l10n.library,
                            ),
                            SkillsFolderTab(
                              id: 'settings',
                              value: _Destination.settings,
                              label: context.l10n.settings,
                            ),
                          ],
                          selected: destination,
                          onSelected: (value) {
                            if (value != _Destination.discover) {
                              discoverKey.currentState?.dismissDetail();
                            }
                            setState(() => destination = value);
                          },
                          style: SkillsPrimaryFolderStyle(
                            folderColor: scheme.surfaceContainerHighest,
                            activeTabColor: scheme.surfaceContainerHighest,
                            inactiveTabColor: scheme.surfaceContainer,
                            activeLabelStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                            inactiveLabelStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          child: IndexedStack(
                            index: destination.index,
                            children: [
                              TickerMode(
                                enabled: destination == _Destination.discover,
                                child: DiscoverScreen(
                                  key: discoverKey,
                                  gateway: widget.gateway,
                                  onInstalled: _showLibrary,
                                ),
                              ),
                              TickerMode(
                                enabled: destination == _Destination.library,
                                child: LibraryScreen(
                                  gateway: widget.gateway,
                                  revision: libraryRevision,
                                ),
                              ),
                              TickerMode(
                                enabled: destination == _Destination.settings,
                                child: SettingsScreen(
                                  gateway: widget.gateway,
                                  folderTheme: folderTheme,
                                  onFolderThemeChanged: _setFolderTheme,
                                  themeMode: themeMode,
                                  onThemeModeChanged: _setThemeMode,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CliBanner extends StatelessWidget {
  const _CliBanner({required this.status, required this.onOpenSettings});
  final CliStatus status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: SkillsTokens.amber.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: SkillsTokens.amber.withValues(alpha: .3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.terminal, size: 17, color: SkillsTokens.amber),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            _cliStatusMessage(context, status),
            style: const TextStyle(color: SkillsTokens.amber),
          ),
        ),
        TextButton(
          onPressed: onOpenSettings,
          child: Text(context.l10n.openSettings),
        ),
      ],
    ),
  );
}

enum _DiscoverRoute { search, ranking, trending, hot }

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.gateway,
    required this.onInstalled,
  });
  final SkillsGateway gateway;
  final VoidCallback onInstalled;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  final installOperations = <String, _InstallOperation>{};
  final routeStates = <_DiscoverRoute, _DiscoveryRouteState>{
    for (final route in _DiscoverRoute.values) route: _DiscoveryRouteState(),
  };
  _DiscoverRoute selectedRoute = _DiscoverRoute.hot;
  _DiscoverRoute lastCollectionRoute = _DiscoverRoute.hot;
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
    detailTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
      reverseDuration: const Duration(milliseconds: 200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadRoute(_DiscoverRoute.hot, reset: true));
    });
  }

  Future<void> search([String? value]) async {
    final query = (value ?? controller.text).trim();
    if (query.isEmpty) {
      final state = routeStates[_DiscoverRoute.search]!;
      setState(() {
        selectedSkill = null;
        selectedSkillFocus = null;
        selectedRoute = lastCollectionRoute;
        submittedQuery = null;
        state.generation++;
        state.results = null;
        state.error = null;
        state.loading = false;
        state.loadingMore = false;
        state.nextOffset = null;
      });
      return;
    }
    setState(() {
      selectedSkill = null;
      selectedSkillFocus = null;
      selectedRoute = _DiscoverRoute.search;
      submittedQuery = query;
    });
    await _loadRoute(_DiscoverRoute.search, reset: true, query: query);
  }

  void _selectRoute(_DiscoverRoute route) {
    setState(() {
      selectedSkill = null;
      selectedSkillFocus = null;
      selectedRoute = route;
      if (route != _DiscoverRoute.search) lastCollectionRoute = route;
    });
    final state = routeStates[route]!;
    if (route != _DiscoverRoute.search &&
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
    _DiscoverRoute route, {
    required bool reset,
    String? query,
  }) async {
    final state = routeStates[route]!;
    final nextOffset = reset ? 0 : state.nextOffset;
    if (nextOffset == null) return;
    final generation = reset ? ++state.generation : state.generation;
    if (reset && state.scrollController.hasClients) {
      state.scrollController.jumpTo(0);
    }
    setState(() {
      state.error = null;
      if (reset) {
        state.loading = true;
        state.loadingMore = false;
        state.results = null;
        state.nextOffset = null;
      } else {
        state.loadingMore = true;
      }
    });
    try {
      final page = await widget.gateway.discover(
        _collectionForRoute(route),
        query: query ?? controller.text.trim(),
        offset: nextOffset,
      );
      if (!mounted || generation != state.generation) return;
      setState(() {
        state.results = reset
            ? page.skills
            : [...?state.results, ...page.skills];
        state.nextOffset = page.nextOffset;
      });
    } catch (caught) {
      if (!mounted || generation != state.generation) return;
      setState(() => state.error = caught);
    } finally {
      if (mounted && generation == state.generation) {
        setState(() {
          state.loading = false;
          state.loadingMore = false;
        });
      }
    }
  }

  Future<void> _installFromCard(
    InstallLocationMenuPresenter present,
    SkillSummary skill,
  ) async {
    final operation = installOperations.putIfAbsent(
      skill.id,
      _InstallOperation.new,
    );
    if (operation.operating) return;
    try {
      final detail = await widget.gateway.loadRemoteDetail(skill);
      final values = await Future.wait([
        widget.gateway.inspectAgents(),
        widget.gateway.loadAddedProjects(),
        widget.gateway.loadRiskPolicy(),
        _loadRepositorySkills(widget.gateway, skill, detail),
      ]);
      if (!mounted) return;
      final catalog = values[0] as AgentCatalog;
      var projects = values[1] as List<AddedProject>;
      final riskPolicy = values[2] as PersonalRiskPolicy;
      final repositorySkills = values[3] as List<SkillSummary>;
      if (catalog.installed.isEmpty) return;
      final selections = await present(
        InstallLocationMenuRequest(
          gateway: widget.gateway,
          catalog: catalog,
          detail: detail,
          projects: projects,
          repositorySkills: repositorySkills,
          onProjectAdded: (project) {
            final index = projects.indexWhere((item) => item.id == project.id);
            projects = index < 0
                ? [...projects, project]
                : ([...projects]..[index] = project);
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
            query: selectedRoute == _DiscoverRoute.search
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
          await _loadRoute(
            selectedRoute,
            reset: true,
            query: selectedRoute == _DiscoverRoute.search
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
        await _loadRoute(
          selectedRoute,
          reset: true,
          query: selectedRoute == _DiscoverRoute.search
              ? controller.text.trim()
              : null,
        );
      }
    } on Object {
      if (mounted) {
        _openDetail(skill, routeStates[selectedRoute]!.focusNodeFor(skill.id));
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    for (final state in routeStates.values) {
      state.dispose();
    }
    for (final operation in installOperations.values) {
      operation.dispose();
    }
    detailTransition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          rail: SkillsSideRail<_DiscoverRoute>(
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
              loading: routeStates[_DiscoverRoute.search]!.loading,
              compact: true,
            ),
            items: [
              SkillsRailItem(
                value: _DiscoverRoute.hot,
                label: context.l10n.hot,
                icon: HugeIcons.strokeRoundedFire,
              ),
              SkillsRailItem(
                value: _DiscoverRoute.ranking,
                label: context.l10n.ranking,
                icon: HugeIcons.strokeRoundedChampion,
              ),
              SkillsRailItem(
                value: _DiscoverRoute.trending,
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
                        operation: installOperations.putIfAbsent(
                          selectedSkill!.id,
                          _InstallOperation.new,
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
      _DiscoverRoute.search => _searchPage(),
      _DiscoverRoute.ranking => _collectionPage(
        _DiscoverRoute.ranking,
        context.l10n.allTimeRanking,
      ),
      _DiscoverRoute.trending => _collectionPage(
        _DiscoverRoute.trending,
        context.l10n.trendingNow,
      ),
      _DiscoverRoute.hot => _collectionPage(
        _DiscoverRoute.hot,
        context.l10n.hotNow,
      ),
    },
  );

  Widget _searchPage() =>
      _body(_DiscoverRoute.search, title: context.l10n.discoverTitle);

  Widget _collectionPage(_DiscoverRoute route, String title) =>
      _body(route, title: title);

  Widget _body(_DiscoverRoute route, {required String title}) {
    final state = routeStates[route]!;
    if (state.loading && state.results == null) {
      return _discoverStateScroll(
        state,
        title,
        const Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null && state.results == null) {
      final copy = _failureCopy(context, state.error!);
      return _discoverStateScroll(
        state,
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
        state,
        title,
        EmptyState(
          title: context.l10n.searchEmptyTitle,
          message: context.l10n.searchEmptyMessage,
        ),
      );
    }
    if (state.results!.isEmpty) {
      return _discoverStateScroll(
        state,
        title,
        EmptyState(
          title: route == _DiscoverRoute.search
              ? context.l10n.noSkillsTitle
              : context.l10n.collectionEmptyTitle,
          message: route == _DiscoverRoute.search
              ? context.l10n.noSkillsMessage
              : context.l10n.collectionEmptyMessage,
          action: route == _DiscoverRoute.search
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
            route == _DiscoverRoute.search
                ? 'discover-results'
                : 'discover-results-${route.name}',
          ),
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
              delegate: SliverChildBuilderDelegate((context, index) {
                final skill = state.results![index];
                final cardFocus = state.focusNodeFor(skill.id);
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

  Widget _discoverStateScroll(
    _DiscoveryRouteState state,
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
      final routeState = routeStates[selectedRoute]!;
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
    final routeState = routeStates[selectedRoute]!;
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
        query: selectedRoute == _DiscoverRoute.search
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

class _DiscoveryRouteState {
  final scrollController = ScrollController();
  final focusNodes = <String, FocusNode>{};
  List<SkillSummary>? results;
  Object? error;
  int? nextOffset;
  int generation = 0;
  bool loading = false;
  bool loadingMore = false;

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

DiscoveryCollection _collectionForRoute(_DiscoverRoute route) =>
    switch (route) {
      _DiscoverRoute.search => DiscoveryCollection.search,
      _DiscoverRoute.ranking => DiscoveryCollection.ranking,
      _DiscoverRoute.trending => DiscoveryCollection.trending,
      _DiscoverRoute.hot => DiscoveryCollection.hot,
    };

Future<List<SkillSummary>> _loadRepositorySkills(
  SkillsGateway gateway,
  SkillSummary current,
  SkillDetail detail,
) async {
  final repository = detail.repository.trim();
  if (repository.isEmpty) return [current];
  try {
    final skills = <String, SkillSummary>{};
    var offset = 0;
    while (true) {
      final page = await gateway.discover(
        DiscoveryCollection.search,
        query: repository,
        offset: offset,
        limit: 100,
      );
      for (final skill in page.skills) {
        if (skill.id == repository || skill.id.startsWith('$repository/-/')) {
          skills[skill.id] = skill;
        }
      }
      final next = page.nextOffset;
      if (next == null || next <= offset) break;
      offset = next;
    }
    skills[current.id] = current;
    final values = skills.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return values;
  } on Object {
    return [current];
  }
}

Future<void> _installRepositorySkills(
  SkillsGateway gateway,
  List<SkillSummary> skills,
  List<InstallationTargetSelection> selections,
  PersonalRiskPolicy riskPolicy,
) async {
  for (final skill in skills) {
    final detail = await gateway.loadRemoteDetail(skill);
    final operation = _InstallOperation();
    final plan = await operation.preflight(
      gateway,
      skill,
      detail.immutableVersion,
      selections,
      allowCritical: riskPolicy.allowCriticalOverride,
    );
    if (plan == null ||
        plan.summary.conflict > 0 ||
        plan.summary.blockedByRisk > 0) {
      continue;
    }
    await operation.execute(gateway);
  }
}

String _operationTargetKey(InstallationPlanTarget target) =>
    '${target.scope.name}\u0000${target.projectRoot}\u0000${target.agent}\u0000${target.mode.name}\u0000${target.path}';

class _InstallOperation extends ChangeNotifier {
  bool operating = false;
  InstallationPlan? plan;
  InstallationExecution? execution;
  Object? error;
  final _progressByTarget = <String, InstallationTargetProgress>{};
  bool _disposed = false;

  List<InstallationTargetProgress> get progress {
    final currentPlan = plan;
    if (currentPlan == null) return const [];
    return [
      for (final item in currentPlan.targets)
        ?_progressByTarget[_operationTargetKey(item.target)],
    ];
  }

  int get finishedTargetCount => _progressByTarget.values
      .where((event) => event.state == InstallationProgressState.finished)
      .length;

  Future<InstallationPlan?> preflight(
    SkillsGateway gateway,
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool riskConfirmed = false,
    bool allowCritical = false,
  }) async {
    if (operating) return plan;
    operating = true;
    plan = null;
    execution = null;
    error = null;
    _progressByTarget.clear();
    _notify();
    try {
      plan = await gateway.preflightInstall(
        skill,
        immutableVersion,
        selections,
        riskConfirmed: riskConfirmed,
        allowCritical: allowCritical,
      );
    } catch (caught) {
      error = caught;
    } finally {
      operating = false;
      _notify();
    }
    return plan;
  }

  Future<InstallationExecution?> execute(SkillsGateway gateway) async {
    if (operating || plan == null) return execution;
    operating = true;
    execution = null;
    error = null;
    _progressByTarget.clear();
    _notify();
    try {
      execution = await gateway.executeInstall(
        plan!,
        onProgress: _recordProgress,
      );
    } catch (caught) {
      error = caught;
    } finally {
      operating = false;
      _notify();
    }
    return execution;
  }

  Future<InstallationExecution?> retryFailed(
    SkillsGateway gateway,
    SkillSummary skill,
  ) async {
    final originalPlan = plan;
    final previous = execution;
    if (operating || originalPlan == null || previous == null) return previous;
    final failedKeys = previous.results
        .where((result) => result.outcome == InstallationTargetOutcome.failed)
        .map((result) => _operationTargetKey(result.target))
        .toSet();
    if (failedKeys.isEmpty) return previous;
    final retrySelections = <InstallationTargetSelection>[];
    final expectedTargets = <InstallationPlanTarget>[];
    for (var index = 0; index < originalPlan.targets.length; index++) {
      final target = originalPlan.targets[index].target;
      if (failedKeys.contains(_operationTargetKey(target))) {
        retrySelections.add(originalPlan.selections[index]);
        expectedTargets.add(target);
        _progressByTarget.remove(_operationTargetKey(target));
      }
    }
    operating = true;
    error = null;
    _notify();
    try {
      final retryPlan = await gateway.preflightInstall(
        skill,
        originalPlan.version,
        retrySelections,
        riskConfirmed: originalPlan.riskConfirmed,
        allowCritical: originalPlan.allowCritical,
      );
      if (retryPlan.source != originalPlan.source ||
          retryPlan.coordinate != originalPlan.coordinate ||
          retryPlan.version != originalPlan.version ||
          retryPlan.name != originalPlan.name ||
          retryPlan.targets.length != expectedTargets.length) {
        throw const SkillsException(
          'Retry changed the immutable artifact or target identities.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      for (var index = 0; index < expectedTargets.length; index++) {
        if (_operationTargetKey(retryPlan.targets[index].target) !=
            _operationTargetKey(expectedTargets[index])) {
          throw const SkillsException(
            'Retry changed the immutable artifact or target identities.',
            kind: SkillsFailureKind.invalidResponse,
          );
        }
      }
      final retried = await gateway.executeInstall(
        retryPlan,
        onProgress: _recordProgress,
      );
      execution = _mergeRetryExecution(previous, retried);
    } catch (caught) {
      error = caught;
    } finally {
      operating = false;
      _notify();
    }
    return execution;
  }

  void _recordProgress(InstallationTargetProgress progress) {
    _progressByTarget[_operationTargetKey(progress.target)] = progress;
    _notify();
  }

  void editTargets() {
    plan = null;
    execution = null;
    error = null;
    _progressByTarget.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

InstallationExecution _mergeRetryExecution(
  InstallationExecution previous,
  InstallationExecution retried,
) {
  if (previous.coordinate != retried.coordinate ||
      previous.version != retried.version ||
      previous.name != retried.name) {
    throw const SkillsException(
      'Retry changed the immutable artifact identity.',
      kind: SkillsFailureKind.invalidResponse,
    );
  }
  final retriedByTarget = {
    for (final result in retried.results)
      _operationTargetKey(result.target): result,
  };
  final results = [
    for (final result in previous.results)
      retriedByTarget[_operationTargetKey(result.target)] ?? result,
  ];
  if (retriedByTarget.length != retried.results.length ||
      !retriedByTarget.keys.every(
        (key) => previous.results.any(
          (result) => _operationTargetKey(result.target) == key,
        ),
      )) {
    throw const SkillsException(
      'Retry returned an unknown Installation Target.',
      kind: SkillsFailureKind.invalidResponse,
    );
  }
  int count(InstallationTargetOutcome outcome) =>
      results.where((result) => result.outcome == outcome).length;
  return InstallationExecution(
    coordinate: previous.coordinate,
    version: previous.version,
    name: previous.name,
    results: List.unmodifiable(results),
    summary: InstallationExecutionSummary(
      succeeded: count(InstallationTargetOutcome.succeeded),
      skipped: count(InstallationTargetOutcome.skipped),
      conflict: count(InstallationTargetOutcome.conflict),
      failed: count(InstallationTargetOutcome.failed),
    ),
  );
}

enum _InstallationPlanOutcome { viewLibrary }

class _InstallationPlanDialog extends StatefulWidget {
  const _InstallationPlanDialog({
    required this.gateway,
    required this.skill,
    required this.detail,
    required this.catalog,
    required this.initialProjects,
    required this.operation,
    required this.onProjectAdded,
    required this.riskPolicy,
  });

  final SkillsGateway gateway;
  final SkillSummary skill;
  final SkillDetail detail;
  final AgentCatalog catalog;
  final List<AddedProject> initialProjects;
  final _InstallOperation operation;
  final ValueChanged<AddedProject> onProjectAdded;
  final PersonalRiskPolicy riskPolicy;

  @override
  State<_InstallationPlanDialog> createState() =>
      _InstallationPlanDialogState();
}

class _InstallationPlanDialogState extends State<_InstallationPlanDialog> {
  late List<AddedProject> projects;
  final selected = <String, InstallationTargetSelection>{};
  bool riskConfirmed = false;

  @override
  void initState() {
    super.initState();
    projects = List.of(widget.initialProjects);
    for (final selection in widget.operation.plan?.selections ?? const []) {
      selected[_selectionKey(selection)] = selection;
    }
  }

  List<
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
  >
  get rows => [
    (
      key: 'user',
      label: context.l10n.userScope,
      scope: InstallationScope.user,
      projectRoot: '',
      enabled: true,
    ),
    ...projects.map(
      (project) => (
        key: 'project:${project.id}',
        label: project.name,
        scope: InstallationScope.project,
        projectRoot: project.path,
        enabled: project.isAccessible,
      ),
    ),
  ];

  List<AgentStatus> get agents => widget.catalog.installed;

  String _selectionKey(InstallationTargetSelection selection) =>
      '${selection.scope.name}\u0000${selection.projectRoot}\u0000${selection.agent}';

  InstallationTargetSelection _selectionFor(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
  ) => InstallationTargetSelection(
    scope: row.scope,
    projectRoot: row.projectRoot,
    agent: agent.id,
  );

  bool _isInstalled(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
  ) => widget.detail.installationTargets.any(
    (target) =>
        target.scope == row.scope &&
        target.projectRoot == row.projectRoot &&
        target.agent == agent.id &&
        target.version == widget.detail.immutableVersion &&
        target.health == InstallationHealth.healthy,
  );

  bool _isEligible(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
  ) =>
      row.enabled &&
      agent.supportedScopes.contains(row.scope) &&
      !_isInstalled(row, agent);

  List<InstallationTargetSelection> get selectedInMatrixOrder => [
    for (final row in rows)
      for (final agent in agents)
        if (selected.containsKey(_selectionKey(_selectionFor(row, agent))))
          selected[_selectionKey(_selectionFor(row, agent))]!,
  ];

  void _toggleCell(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
    bool value,
  ) {
    final selection = _selectionFor(row, agent);
    setState(() {
      if (value) {
        selected[_selectionKey(selection)] = selection;
      } else {
        selected.remove(_selectionKey(selection));
      }
    });
  }

  void _toggleRow(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    bool value,
  ) {
    setState(() {
      for (final agent in agents.where((agent) => _isEligible(row, agent))) {
        final selection = _selectionFor(row, agent);
        if (value) {
          selected[_selectionKey(selection)] = selection;
        } else {
          selected.remove(_selectionKey(selection));
        }
      }
    });
  }

  void _toggleAgent(AgentStatus agent, bool value) {
    setState(() {
      for (final row in rows.where((row) => _isEligible(row, agent))) {
        final selection = _selectionFor(row, agent);
        if (value) {
          selected[_selectionKey(selection)] = selection;
        } else {
          selected.remove(_selectionKey(selection));
        }
      }
    });
  }

  Future<void> _addProject() async {
    final project = await widget.gateway.addProject();
    if (project == null || !mounted) return;
    setState(() {
      final index = projects.indexWhere((item) => item.id == project.id);
      if (index < 0) {
        projects = [...projects, project];
      } else {
        projects[index] = project;
      }
    });
    widget.onProjectAdded(project);
  }

  Future<void> _preflight() async {
    await widget.operation.preflight(
      widget.gateway,
      widget.skill,
      widget.detail.immutableVersion,
      selectedInMatrixOrder,
      riskConfirmed: riskConfirmed,
      allowCritical: widget.riskPolicy.allowCriticalOverride,
    );
    if (mounted) setState(() {});
  }

  Future<void> _execute() async {
    await widget.operation.execute(widget.gateway);
    if (mounted) setState(() {});
  }

  Future<void> _retryFailed() async {
    await widget.operation.retryFailed(widget.gateway, widget.skill);
    if (mounted) setState(() {});
  }

  void _editTargets() {
    widget.operation.editTargets();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final execution = widget.operation.execution;
    final plan = widget.operation.plan;
    final showingProgress =
        widget.operation.operating &&
        widget.operation.progress.isNotEmpty &&
        execution == null;
    return SkillsDialog(
      constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
      closeIcon: Semantics(
        container: true,
        label: context.l10n.closeInstallationPlan,
        button: true,
        child: ExcludeSemantics(
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ),
      title: Text(
        showingProgress
            ? context.l10n.installationProgressTitle
            : execution != null
            ? context.l10n.installationResults
            : plan != null
            ? context.l10n.reviewInstallationPlan
            : context.l10n.installationPlanTitle,
      ),
      description: Text(
        showingProgress
            ? context.l10n.installationProgressSummary(
                widget.operation.finishedTargetCount,
                plan?.targets.length ?? 0,
              )
            : execution != null
            ? context.l10n.installationResultsDescription
            : plan != null
            ? context.l10n.reviewInstallationPlanDescription
            : context.l10n.installationPlanDescription,
      ),
      actions: _actions(plan, execution),
      child: SizedBox(
        width: 940,
        height: 540,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: showingProgress && plan != null
              ? _progress(plan)
              : execution != null
              ? _result(execution)
              : plan != null
              ? _preflightReview(plan)
              : _matrix(),
        ),
      ),
    );
  }

  List<Widget> _actions(
    InstallationPlan? plan,
    InstallationExecution? execution,
  ) {
    if (execution != null) {
      return [
        SkillsButton.outline(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.stayHere),
        ),
        SkillsButton(
          enabled: execution.hasSuccess,
          onPressed: () =>
              Navigator.pop(context, _InstallationPlanOutcome.viewLibrary),
          child: Text(context.l10n.viewInLibrary),
        ),
        if (execution.summary.failed > 0)
          SkillsButton.outline(
            enabled: !widget.operation.operating,
            onPressed: _retryFailed,
            child: widget.operation.operating
                ? SizedBox(
                    width: 32,
                    child: SkillsProgress(
                      minHeight: 4,
                      semanticsLabel: context.l10n.installationInProgress,
                    ),
                  )
                : Text(
                    context.l10n.retryFailedTargets(execution.summary.failed),
                  ),
          ),
      ];
    }
    if (widget.operation.operating && widget.operation.progress.isNotEmpty) {
      return [
        SkillsButton.outline(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.stayHere),
        ),
      ];
    }
    if (plan != null) {
      final unresolved =
          plan.summary.conflict > 0 || plan.summary.blockedByRisk > 0;
      return [
        SkillsButton.outline(
          enabled: !widget.operation.operating,
          onPressed: _editTargets,
          child: Text(context.l10n.backToTargets),
        ),
        SkillsButton(
          enabled:
              !widget.operation.operating && (!unresolved || _canRefresh(plan)),
          onPressed: unresolved ? _preflight : _execute,
          child: widget.operation.operating
              ? SizedBox(
                  width: 32,
                  child: SkillsProgress(
                    minHeight: 4,
                    semanticsLabel: context.l10n.installationInProgress,
                  ),
                )
              : Text(
                  unresolved
                      ? context.l10n.refreshInstallationPlan
                      : context.l10n.installSelectedTargets(
                          plan.targets.length,
                        ),
                ),
        ),
      ];
    }
    return [
      SkillsButton.outline(
        enabled: !widget.operation.operating,
        onPressed: _addProject,
        child: Text(context.l10n.addProject),
      ),
      SkillsButton.outline(
        enabled: !widget.operation.operating,
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      SkillsButton(
        enabled: selected.isNotEmpty && !widget.operation.operating,
        onPressed: _preflight,
        child: widget.operation.operating
            ? SizedBox(
                width: 32,
                child: SkillsProgress(
                  minHeight: 4,
                  semanticsLabel: context.l10n.installationInProgress,
                ),
              )
            : Text(context.l10n.reviewTargets(selected.length)),
      ),
    ];
  }

  Widget _matrix() {
    final width = 210.0 + agents.length * 176.0;
    return Column(
      key: const ValueKey('installation-matrix'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionEyebrow(context.l10n.locationAgentMatrix),
            const Spacer(),
            Text(
              context.l10n.targetsSelected(selected.length),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _matrixHeader(),
                  SkillsSeparator.horizontal(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      itemBuilder: (context, index) => _matrixRow(rows[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.operation.error != null) ...[
          const SizedBox(height: 10),
          _PlanError(error: widget.operation.error!),
        ],
      ],
    );
  }

  Widget _matrixHeader() => SizedBox(
    height: 76,
    child: Row(
      children: [
        SizedBox(
          width: 210,
          child: Text(
            context.l10n.location,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...agents.map((agent) {
          final eligible = rows.where((row) => _isEligible(row, agent));
          final allSelected =
              eligible.isNotEmpty &&
              eligible.every(
                (row) => selected.containsKey(
                  _selectionKey(_selectionFor(row, agent)),
                ),
              );
          return SizedBox(
            width: 176,
            child: Semantics(
              label: context.l10n.selectAgentTargets(agent.displayName),
              checked: allSelected,
              enabled: eligible.isNotEmpty,
              onTap: eligible.isEmpty
                  ? null
                  : () => _toggleAgent(agent, !allSelected),
              excludeSemantics: true,
              child: SkillsCheckbox(
                value: allSelected,
                enabled: eligible.isNotEmpty,
                onChanged: (value) => _toggleAgent(agent, value),
                label: SizedBox(
                  width: 132,
                  child: Text(
                    agent.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),
  );

  Widget _matrixRow(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
  ) {
    final eligible = agents.where((agent) => _isEligible(row, agent));
    final allSelected =
        eligible.isNotEmpty &&
        eligible.every(
          (agent) =>
              selected.containsKey(_selectionKey(_selectionFor(row, agent))),
        );
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          SizedBox(
            width: 210,
            child: Semantics(
              label: context.l10n.selectLocationTargets(row.label),
              checked: allSelected,
              enabled: eligible.isNotEmpty,
              onTap: eligible.isEmpty
                  ? null
                  : () => _toggleRow(row, !allSelected),
              excludeSemantics: true,
              child: SkillsCheckbox(
                value: allSelected,
                enabled: eligible.isNotEmpty,
                onChanged: (value) => _toggleRow(row, value),
                label: SizedBox(
                  width: 164,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (!row.enabled)
                        Text(
                          context.l10n.projectUnavailable,
                          style: const TextStyle(
                            color: SkillsTokens.amber,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ...agents.map((agent) => _matrixCell(row, agent)),
        ],
      ),
    );
  }

  Widget _matrixCell(
    ({
      String key,
      String label,
      InstallationScope scope,
      String projectRoot,
      bool enabled,
    })
    row,
    AgentStatus agent,
  ) {
    final selection = _selectionFor(row, agent);
    final key = _selectionKey(selection);
    final installed = _isInstalled(row, agent);
    final eligible = _isEligible(row, agent);
    return SizedBox(
      width: 176,
      child: Center(
        child: installed
            ? StatusChip(
                label: context.l10n.installedCell,
                color: SkillsTokens.green,
              )
            : eligible
            ? Semantics(
                label: context.l10n.selectTarget(row.label, agent.displayName),
                checked: selected.containsKey(key),
                enabled: true,
                onTap: () =>
                    _toggleCell(row, agent, !selected.containsKey(key)),
                excludeSemantics: true,
                child: SkillsCheckbox(
                  value: selected.containsKey(key),
                  onChanged: (value) => _toggleCell(row, agent, value),
                  label: Text(context.l10n.select),
                ),
              )
            : StatusChip(
                label: context.l10n.unsupportedCell,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
              ),
      ),
    );
  }

  Widget _preflightReview(InstallationPlan plan) => Column(
    key: const ValueKey('installation-preflight'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusChip(
            label: context.l10n.planCreateCount(plan.summary.create),
            color: SkillsTokens.green,
          ),
          StatusChip(
            label: context.l10n.planSkipCount(plan.summary.skip),
            color: SkillsTokens.blue,
          ),
          StatusChip(
            label: context.l10n.planReplaceCount(plan.summary.replace),
            color: SkillsTokens.amber,
          ),
          StatusChip(
            label: context.l10n.planConflictCount(plan.summary.conflict),
            color: plan.summary.conflict > 0
                ? SkillsTokens.amber
                : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
          ),
          StatusChip(
            label: context.l10n.planRiskCount(plan.summary.blockedByRisk),
            color: plan.summary.blockedByRisk > 0
                ? SkillsTokens.red
                : Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
          ),
          StatusChip(label: plan.version, color: SkillsTokens.teal),
        ],
      ),
      const SizedBox(height: 14),
      SelectableText(
        plan.coordinate,
        style: TextStyle(
          fontFamily: SkillsTokens.monoFamily,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 14),
      if (plan.summary.blockedByRisk > 0) ...[
        _riskResolution(plan),
        const SizedBox(height: 12),
      ],
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: GlassCard(
                child: ListView.separated(
                  itemCount: plan.targets.length,
                  separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) =>
                      _plannedTarget(plan.targets[index]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionEyebrow(context.l10n.workspaceLockChanges),
                    const SizedBox(height: 10),
                    Expanded(
                      child: plan.workspaceLockChanges.isEmpty
                          ? Text(
                              context.l10n.noWorkspaceLockChanges,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : ListView.separated(
                              itemCount: plan.workspaceLockChanges.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final change = plan.workspaceLockChanges[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      change.projectRoot,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.lockVersionChange(
                                        change.fromVersion.isEmpty
                                            ? context.l10n.notPresent
                                            : change.fromVersion,
                                        change.toVersion,
                                      ),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontFamily: SkillsTokens.monoFamily,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      if (widget.operation.error != null) ...[
        const SizedBox(height: 10),
        _PlanError(error: widget.operation.error!),
      ],
    ],
  );

  Widget _plannedTarget(InstallationPlanItem item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _targetLabel(context, item.target),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.target.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
                      fontFamily: SkillsTokens.monoFamily,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusChip(
              label: _planActionLabel(context, item.action),
              color: switch (item.action) {
                InstallationPlanAction.create => SkillsTokens.green,
                InstallationPlanAction.skip => SkillsTokens.blue,
                InstallationPlanAction.replace => SkillsTokens.amber,
                InstallationPlanAction.conflict ||
                InstallationPlanAction.blockedByRisk => SkillsTokens.red,
              },
            ),
          ],
        ),
        if (item.action == InstallationPlanAction.conflict) ...[
          const SizedBox(height: 8),
          if (item.reasonCode == 'shared-target-conflict')
            SkillsAlert.destructive(
              icon: const Icon(Icons.hub_outlined),
              title: Text(context.l10n.sharedTargetConflict),
              description: Text(
                context.l10n.sharedTargetConflictDescription(
                  item.affectedBindings
                      .map((binding) => binding.agent)
                      .toSet()
                      .join(', '),
                ),
              ),
            )
          else
            SkillsCheckbox(
              value: _selectionMatchesReview(item),
              onChanged: (value) => _setResolution(item, value),
              label: Text(_conflictResolutionLabel(context, item.reasonCode)),
            ),
        ],
      ],
    ),
  );

  InstallationTargetSelection _selectionForTarget(
    InstallationPlanTarget target,
  ) {
    final fallback = InstallationTargetSelection(
      scope: target.scope,
      projectRoot: target.projectRoot,
      agent: target.agent,
      mode: target.mode,
    );
    return selected[_selectionKey(fallback)] ?? fallback;
  }

  bool _selectionMatchesReview(InstallationPlanItem item) {
    final selection = _selectionForTarget(item.target);
    return selection.resolution == InstallationTargetResolution.replace &&
        selection.expectedReason == item.reasonCode &&
        selection.expectedState == item.stateToken;
  }

  void _setResolution(InstallationPlanItem item, bool replace) {
    final current = _selectionForTarget(item.target);
    setState(() {
      selected[_selectionKey(current)] = current.copyWith(
        resolution: replace
            ? InstallationTargetResolution.replace
            : InstallationTargetResolution.none,
        expectedReason: replace ? item.reasonCode : '',
        expectedState: replace ? item.stateToken : '',
      );
    });
  }

  bool _canRefresh(InstallationPlan plan) {
    final conflictsResolved = plan.targets
        .where((item) => item.action == InstallationPlanAction.conflict)
        .every(_selectionMatchesReview);
    if (!conflictsResolved) return false;
    final blocked = plan.targets.where(
      (item) => item.action == InstallationPlanAction.blockedByRisk,
    );
    if (blocked.isEmpty) return true;
    final critical = blocked.any((item) => item.reasonCode == 'critical-risk');
    return riskConfirmed &&
        (!critical || widget.riskPolicy.allowCriticalOverride);
  }

  Widget _riskResolution(InstallationPlan plan) {
    final critical = plan.targets.any(
      (item) =>
          item.action == InstallationPlanAction.blockedByRisk &&
          item.reasonCode == 'critical-risk',
    );
    if (critical && !widget.riskPolicy.allowCriticalOverride) {
      return SkillsAlert.destructive(
        icon: const Icon(Icons.shield_outlined),
        title: Text(context.l10n.criticalRiskBlocked),
        description: Text(context.l10n.criticalRiskOverrideDisabled),
      );
    }
    return SkillsAlert(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(
        critical
            ? context.l10n.confirmCriticalRiskArtifact
            : context.l10n.confirmHighRiskArtifact,
      ),
      description: SkillsCheckbox(
        value: riskConfirmed,
        onChanged: (value) => setState(() => riskConfirmed = value),
        label: Text(context.l10n.confirmRiskForSelectedTargets),
      ),
    );
  }

  Widget _progress(InstallationPlan plan) {
    final progress = {
      for (final event in widget.operation.progress)
        _operationTargetKey(event.target): event,
    };
    return Column(
      key: const ValueKey('installation-progress'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillsCard(
          width: double.infinity,
          title: Text(context.l10n.installationProgressTitle),
          description: Text(
            context.l10n.installationProgressSummary(
              widget.operation.finishedTargetCount,
              plan.targets.length,
            ),
          ),
          footer: SkillsProgress(
            value: plan.targets.isEmpty
                ? 0
                : widget.operation.finishedTargetCount / plan.targets.length,
            minHeight: 5,
            semanticsLabel: context.l10n.installationInProgress,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GlassCard(
            child: ListView.separated(
              itemCount: plan.targets.length,
              separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final item = plan.targets[index];
                final event = progress[_operationTargetKey(item.target)];
                final finished =
                    event?.state == InstallationProgressState.finished;
                final failed =
                    event?.result?.outcome == InstallationTargetOutcome.failed;
                final label = event == null
                    ? context.l10n.targetWaiting
                    : finished
                    ? _targetOutcomeLabel(context, event.result!.outcome)
                    : context.l10n.targetRunning;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        finished
                            ? failed
                                  ? Icons.error
                                  : Icons.check_circle
                            : Icons.pending_outlined,
                        color: finished
                            ? failed
                                  ? SkillsTokens.red
                                  : SkillsTokens.green
                            : SkillsTokens.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _targetLabel(context, item.target),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      StatusChip(
                        label: label,
                        color: failed ? SkillsTokens.red : SkillsTokens.blue,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _result(InstallationExecution execution) => Column(
    key: const ValueKey('installation-result'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.installationResultSummary(
          execution.summary.succeeded,
          execution.summary.failed,
        ),
        style: const TextStyle(
          fontFamily: SkillsTokens.serifFamily,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        execution.coordinate,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFamily: SkillsTokens.monoFamily,
        ),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: GlassCard(
          child: ListView.separated(
            itemCount: execution.results.length,
            separatorBuilder: (_, _) => SkillsSeparator.horizontal(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final result = execution.results[index];
              final success =
                  result.outcome == InstallationTargetOutcome.succeeded ||
                  result.outcome == InstallationTargetOutcome.skipped;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success ? SkillsTokens.green : SkillsTokens.red,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _targetLabel(context, result.target),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (result.errorCode.isNotEmpty)
                            Text(
                              _installationErrorLabel(
                                context,
                                result.errorCode,
                              ),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: _targetOutcomeLabel(context, result.outcome),
                      color: success ? SkillsTokens.green : SkillsTokens.red,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      if (widget.operation.error != null) ...[
        const SizedBox(height: 10),
        _PlanError(error: widget.operation.error!),
      ],
    ],
  );
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final copy = _failureCopy(context, error);
    return SkillsAlert.destructive(
      icon: const Icon(Icons.error_outline),
      title: Text(context.l10n.installationPlanFailed),
      description: Text(copy.message),
    );
  }
}

class _InstallationCompletionBanner extends StatelessWidget {
  const _InstallationCompletionBanner({required this.execution});
  final InstallationExecution execution;

  @override
  Widget build(BuildContext context) => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.installationResults),
    description: Text(
      context.l10n.installationResultSummary(
        execution.summary.succeeded,
        execution.summary.failed,
      ),
    ),
  );
}

String _targetLabel(BuildContext context, InstallationPlanTarget target) {
  final location = target.scope == InstallationScope.user
      ? context.l10n.userScope
      : p.basename(target.projectRoot);
  return '$location / ${target.agent}';
}

String _planActionLabel(BuildContext context, InstallationPlanAction action) =>
    switch (action) {
      InstallationPlanAction.create => context.l10n.planActionCreate,
      InstallationPlanAction.replace => context.l10n.planActionReplace,
      InstallationPlanAction.skip => context.l10n.planActionSkip,
      InstallationPlanAction.conflict => context.l10n.planActionConflict,
      InstallationPlanAction.blockedByRisk =>
        context.l10n.planActionBlockedByRisk,
    };

String _targetOutcomeLabel(
  BuildContext context,
  InstallationTargetOutcome outcome,
) => switch (outcome) {
  InstallationTargetOutcome.succeeded => context.l10n.targetSucceeded,
  InstallationTargetOutcome.skipped => context.l10n.targetSkipped,
  InstallationTargetOutcome.conflict => context.l10n.targetConflict,
  InstallationTargetOutcome.failed => context.l10n.targetFailed,
};

String _installationErrorLabel(BuildContext context, String code) =>
    switch (code) {
      'target-path-exists' => context.l10n.targetPathExists,
      'blocked-by-risk' => context.l10n.targetBlockedByRisk,
      'install-failed' => context.l10n.targetInstallFailed,
      'workspace-update-failed' => context.l10n.targetWorkspaceUpdateFailed,
      _ => context.l10n.installationPlanFailed,
    };

String _conflictResolutionLabel(BuildContext context, String code) =>
    switch (code) {
      'version-conflict' => context.l10n.replaceVersionConflict,
      'identity-collision' => context.l10n.replaceIdentityCollision,
      'local-modification' => context.l10n.replaceLocalModification,
      _ => context.l10n.replaceConflictingTarget,
    };

class _RemoteDetailScreen extends StatefulWidget {
  const _RemoteDetailScreen({
    super.key,
    required this.gateway,
    required this.skill,
    required this.operation,
    required this.onBack,
    required this.onViewLibrary,
    this.openPlanOnLoad = false,
  });
  final SkillsGateway gateway;
  final SkillSummary skill;
  final _InstallOperation operation;
  final Future<void> Function({required bool installed}) onBack;
  final VoidCallback onViewLibrary;
  final bool openPlanOnLoad;

  @override
  State<_RemoteDetailScreen> createState() => _RemoteDetailScreenState();
}

class _RemoteDetailScreenState extends State<_RemoteDetailScreen> {
  final detailScrollController = ScrollController();
  SkillDetail? detail;
  Object? error;
  bool loading = true;
  CliStatus? cliStatus;
  AgentCatalog? agentCatalog;
  List<AddedProject> addedProjects = const [];
  List<SkillSummary> repositorySkills = const [];
  PersonalRiskPolicy riskPolicy = const PersonalRiskPolicy();
  bool didOpenInitialPlan = false;
  bool installationDialogOpen = false;
  bool get operating => widget.operation.operating;
  InstallationExecution? get execution => widget.operation.execution;

  @override
  void initState() {
    super.initState();
    widget.operation.addListener(_operationChanged);
    detailScrollController.addListener(_detailScrollChanged);
    unawaited(load());
  }

  void _detailScrollChanged() {
    if (mounted) setState(() {});
  }

  void _operationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.operation.removeListener(_operationChanged);
    detailScrollController
      ..removeListener(_detailScrollChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.gateway.loadRemoteDetail(widget.skill),
        widget.gateway.detectCli(),
        widget.gateway.loadAddedProjects(),
        widget.gateway.loadRiskPolicy(),
      ]);
      detail = values[0] as SkillDetail;
      cliStatus = values[1] as CliStatus;
      addedProjects = values[2] as List<AddedProject>;
      riskPolicy = values[3] as PersonalRiskPolicy;
      repositorySkills = await _loadRepositorySkills(
        widget.gateway,
        widget.skill,
        detail!,
      );
      if (cliStatus!.isReady) {
        try {
          agentCatalog = await widget.gateway.inspectAgents();
        } on Object {
          agentCatalog = null;
        }
      }
    } catch (caught) {
      error = caught;
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> install(InstallLocationMenuPresenter present) async {
    if (agentCatalog == null || detail == null) return;
    final selections = await present(
      InstallLocationMenuRequest(
        gateway: widget.gateway,
        catalog: agentCatalog!,
        detail: detail!,
        projects: addedProjects,
        repositorySkills: repositorySkills,
        onProjectAdded: (project) {
          final index = addedProjects.indexWhere(
            (item) => item.id == project.id,
          );
          if (index < 0) {
            addedProjects = [...addedProjects, project];
          } else {
            addedProjects = [...addedProjects]..[index] = project;
          }
        },
      ),
    );
    if (!mounted || selections == null || selections.selections.isEmpty) return;
    if (selections.action == InstallLocationAction.repositorySkills) {
      await _installRepositorySkills(
        widget.gateway,
        repositorySkills,
        selections.selections,
        riskPolicy,
      );
      if (mounted) setState(() {});
      return;
    }
    widget.operation.editTargets();
    final plan = await widget.operation.preflight(
      widget.gateway,
      widget.skill,
      detail!.immutableVersion,
      selections.selections,
      allowCritical: riskPolicy.allowCriticalOverride,
    );
    if (!mounted) return;
    final requiresReview =
        plan == null ||
        plan.summary.conflict > 0 ||
        plan.summary.blockedByRisk > 0;
    if (!requiresReview) {
      final result = await widget.operation.execute(widget.gateway);
      if (!mounted) return;
      if (result != null &&
          result.summary.failed == 0 &&
          result.summary.conflict == 0) {
        setState(() {});
        return;
      }
    }
    setState(() => installationDialogOpen = true);
    final outcome = await showSkillsDialog<_InstallationPlanOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _InstallationPlanDialog(
        gateway: widget.gateway,
        skill: widget.skill,
        detail: detail!,
        catalog: agentCatalog!,
        initialProjects: addedProjects,
        operation: widget.operation,
        riskPolicy: riskPolicy,
        onProjectAdded: (project) {},
      ),
    );
    if (mounted) setState(() => installationDialogOpen = false);
    if (outcome == _InstallationPlanOutcome.viewLibrary && mounted) {
      widget.onViewLibrary();
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          widget.onBack(installed: execution?.hasSuccess == true),
      const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true): () =>
          widget.onBack(installed: execution?.hasSuccess == true),
    },
    child: Focus(
      autofocus: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _content(),
            Align(alignment: Alignment.topCenter, child: _detailToolbar()),
          ],
        ),
      ),
    ),
  );

  Widget _detailToolbar() {
    final scheme = Theme.of(context).colorScheme;
    final offset = detailScrollController.hasClients
        ? detailScrollController.offset
        : 0.0;
    final materialProgress = ((offset - 12) / 52).clamp(0.0, 1.0);
    final compactProgress = ((offset - 72) / 56).clamp(0.0, 1.0);
    final value = detail;
    return SizedBox(
      key: const Key('detail-sticky-toolbar'),
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, .04, .96, 1],
              ).createShader(bounds),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0, .16, .68, 1],
                ).createShader(bounds),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 22 * materialProgress,
                    sigmaY: 22 * materialProgress,
                  ),
                  child: ColoredBox(
                    color: scheme.surface.withValues(
                      alpha: .62 * materialProgress,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Semantics(
                  label: context.l10n.backToSearch,
                  button: true,
                  child: Material(
                    color: scheme.surfaceContainerHigh.withValues(alpha: .82),
                    elevation: 3,
                    shadowColor: scheme.shadow.withValues(alpha: .28),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      key: const Key('detail-back'),
                      onPressed: () => widget.onBack(
                        installed: execution?.hasSuccess == true,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        fixedSize: const Size.square(40),
                        minimumSize: const Size.square(40),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedLessThan,
                        size: 20,
                        strokeWidth: 1.8,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (value != null && compactProgress > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Opacity(
                      key: const Key('detail-compact-identity'),
                      opacity: compactProgress,
                      child: IgnorePointer(
                        ignoring: compactProgress < .95,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RepositoryAvatar(
                              source: value.source,
                              imageUrl: value.imageUrl,
                              size: 26,
                              borderRadius: 7,
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                value.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (value != null && compactProgress > 0)
                  Opacity(
                    key: const Key('detail-compact-install'),
                    opacity: compactProgress,
                    child: IgnorePointer(
                      ignoring: compactProgress < .95,
                      child: InstallLocationMenuAnchor(
                        builder: (context, present) => PrimaryCapsuleButton(
                          label: context.l10n.install,
                          height: 36,
                          horizontalPadding: 16,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w400,
                          ),
                          onPressed:
                              agentCatalog != null &&
                                  agentCatalog!.installed.isEmpty
                              ? null
                              : () => install(present),
                          busy: operating,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (loading) {
      return Center(
        child: Semantics(
          label: context.l10n.detailLoading,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                context.l10n.detailLoading,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      final copy = _failureCopy(context, error!, detail: true);
      return EmptyState(
        title: copy.title,
        message: copy.message,
        action: SkillsButton(onPressed: load, child: Text(context.l10n.retry)),
      );
    }
    return _detailBody();
  }

  Widget _detailBody() {
    final value = detail!;
    return SingleChildScrollView(
      key: const Key('detail-scroll-view'),
      controller: detailScrollController,
      padding: const EdgeInsets.only(top: 76, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepositoryAvatar(
                key: const Key('detail-skill-avatar'),
                source: value.source,
                imageUrl: value.imageUrl,
                size: 116,
                borderRadius: 24,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 112),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                value.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: SkillsTokens.sansFamily,
                                  fontSize: 30,
                                  height: 1.12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            InstallLocationMenuAnchor(
                              builder: (context, present) =>
                                  PrimaryCapsuleButton(
                                    key: const Key('detail-hero-install'),
                                    label: context.l10n.install,
                                    height: 40,
                                    horizontalPadding: 18,
                                    labelStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    onPressed:
                                        agentCatalog != null &&
                                            agentCatalog!.installed.isEmpty
                                        ? null
                                        : () => install(present),
                                    busy: operating,
                                  ),
                            ),
                          ],
                        ),
                        if (value.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SkillMarkdownView(
                            key: const Key('detail-description-markdown'),
                            data: value.description.trim(),
                            scrollable: false,
                            maxHeight: 68,
                            presentation: SkillMarkdownPresentation.summary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _detailProductMetadata(value),
          if (value.hasExecutableContent || value.riskEvidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RiskNotice(detail: value),
          ],
          if (value.installationTargets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    context.l10n.knownInstallationTargets,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: value.installationTargets
                        .map(
                          (target) => StatusChip(
                            label: context.l10n.targetSummary(
                              switch (target.scope) {
                                InstallationScope.user =>
                                  context.l10n.userScope,
                                InstallationScope.project =>
                                  context.l10n.projectScope,
                              },
                              target.agent,
                              target.version,
                            ),
                            color: SkillsTokens.green,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ],
          if (agentCatalog != null && agentCatalog!.installed.isEmpty) ...[
            const SizedBox(height: 12),
            SkillsCard(
              width: double.infinity,
              title: Text(context.l10n.noInstalledAgentsTitle),
              description: Text(context.l10n.noInstalledAgentsMessage),
            ),
          ],
          if (operating &&
              widget.operation.progress.isNotEmpty &&
              execution == null) ...[
            const SizedBox(height: 14),
            SkillsCard(
              width: double.infinity,
              title: Text(context.l10n.installationProgressTitle),
              description: Text(
                context.l10n.installationProgressSummary(
                  widget.operation.finishedTargetCount,
                  widget.operation.plan?.targets.length ?? 0,
                ),
              ),
              footer: SkillsProgress(
                minHeight: 5,
                semanticsLabel: context.l10n.installationInProgress,
              ),
            ),
          ],
          if (execution != null && !installationDialogOpen) ...[
            const SizedBox(height: 14),
            _InstallationCompletionBanner(execution: execution!),
          ],
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SkillMarkdownView(
                key: const Key('detail-instructions'),
                data: value.markdown,
                scrollable: false,
                stripFrontMatter: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailProductMetadata(SkillDetail value) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        label: context.l10n.detailInstalls,
        value: _compactCount(value.installs),
      ),
      (
        label: context.l10n.detailRepository,
        value: _repositoryDisplayName(
          value.repository.isEmpty ? value.source : value.repository,
        ),
      ),
      (
        label: context.l10n.detailGitHubStars,
        value: _compactCount(value.githubStars),
      ),
      (
        label: context.l10n.detailUpdated,
        value: _shortDate(value.sourceUpdatedAt),
      ),
      (
        label: context.l10n.detailArchiveSize,
        value: _fileSize(value.archiveSize),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .55),
          ),
        ),
      ),
      child: SizedBox(
        height: 88,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0)
                SizedBox(
                  height: 48,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: scheme.outlineVariant.withValues(alpha: .55),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 18,
                        width: double.infinity,
                        child: Center(
                          child: Text(
                            items[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 24,
                        width: double.infinity,
                        child: Center(
                          child: Tooltip(
                            message: index == 1 ? items[index].value : '',
                            child: Text(
                              items[index].value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: switch (index) {
                                  1 => 12,
                                  3 => 16,
                                  _ => 18,
                                },
                                height: 1,
                                fontWeight: index == 1
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _repositoryDisplayName(String repository) {
    final firstSeparator = repository.indexOf('/');
    if (firstSeparator <= 0) {
      return repository;
    }
    final firstSegment = repository.substring(0, firstSeparator);
    return firstSegment.contains('.')
        ? repository.substring(firstSeparator + 1)
        : repository;
  }

  String _compactCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 100000 ? 0 : 1)}K';
    }
    return '$value';
  }

  String _shortDate(DateTime? value) {
    if (value == null || value.year <= 1) return '—';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _fileSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes >= 1 << 20) {
      return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(bytes >= 10240 ? 0 : 1)} KB';
  }
}

class _RiskNotice extends StatelessWidget {
  const _RiskNotice({required this.detail});
  final SkillDetail detail;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SkillsTokens.amber.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SkillsTokens.amber.withValues(alpha: .35)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: SkillsTokens.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.executableRisk,
                style: const TextStyle(color: SkillsTokens.amber),
              ),
              if (detail.riskEvidence.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  context.l10n.riskEvidence(
                    detail.riskEvidence
                        .map((evidence) => evidence.path)
                        .join(', '),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: SkillsTokens.monoFamily,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _TargetManagementDialog extends StatefulWidget {
  const _TargetManagementDialog({required this.gateway, required this.plan});

  final SkillsGateway gateway;
  final TargetManagementPlan plan;

  @override
  State<_TargetManagementDialog> createState() =>
      _TargetManagementDialogState();
}

class _TargetManagementDialogState extends State<_TargetManagementDialog> {
  final selectedActions = <String, TargetManagementAction>{};
  final progress = <String, TargetManagementProgress>{};
  TargetManagementExecution? execution;
  Object? error;
  bool operating = false;

  TargetManagementPlan get selectedPlan =>
      widget.plan.selectActions(selectedActions);

  int get finishedCount => progress.values
      .where((event) => event.state == InstallationProgressState.finished)
      .length;

  void _selectAction(
    TargetManagementPlanItem item,
    TargetManagementAction action,
  ) {
    setState(() {
      final key = updateTargetKey(item.target);
      if (selectedActions[key] == action) {
        selectedActions.remove(key);
        if (action == TargetManagementAction.repair) {
          for (final binding in item.affectedBindings) {
            selectedActions.remove(updateTargetKey(binding));
          }
        }
        return;
      }
      final bindings = action == TargetManagementAction.repair
          ? item.affectedBindings
          : const <InstallationPlanTarget>[];
      if (bindings.isEmpty) {
        selectedActions[key] = action;
      } else {
        for (final binding in bindings) {
          selectedActions[updateTargetKey(binding)] = action;
        }
      }
    });
  }

  Future<void> _execute() async {
    final plan = selectedPlan;
    if (plan.targets.isEmpty || operating) return;
    setState(() {
      operating = true;
      error = null;
      progress.clear();
    });
    try {
      final next = await widget.gateway.executeTargetManagement(
        plan,
        onProgress: (event) {
          if (!mounted) return;
          setState(() => progress[updateTargetKey(event.target)] = event);
        },
      );
      if (mounted) setState(() => execution = next);
    } catch (caught) {
      if (mounted) setState(() => error = caught);
    } finally {
      if (mounted) setState(() => operating = false);
    }
  }

  Widget _applyButton(BuildContext context) {
    final enabled = !operating && selectedActions.isNotEmpty;
    final child = Text(context.l10n.applyTargetActions);
    final destructive = selectedActions.values.any(
      (action) => action != TargetManagementAction.repair,
    );
    if (destructive) {
      return SkillsButton.destructive(
        enabled: enabled,
        onPressed: _execute,
        child: child,
      );
    }
    return SkillsButton(enabled: enabled, onPressed: _execute, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final result = execution;
    return SkillsDialog(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 740),
      title: Text(
        operating
            ? context.l10n.managementProgressTitle
            : result == null
            ? context.l10n.manageTargetsTitle
            : context.l10n.managementResultsTitle,
      ),
      description: Text(
        result == null
            ? context.l10n.manageTargetsDescription
            : context.l10n.managementResultSummary(
                result.summary.succeeded,
                result.summary.failed,
              ),
      ),
      actions: [
        if (result == null) ...[
          SkillsButton.outline(
            enabled: !operating,
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          _applyButton(context),
        ] else
          SkillsButton(
            onPressed: () => Navigator.pop(context, result),
            child: Text(context.l10n.closeUpdatePlan),
          ),
      ],
      child: SizedBox(
        height: 530,
        child: result == null ? _selection() : _results(result),
      ),
    );
  }

  Widget _selection() {
    final plan = selectedPlan;
    final changesWorkspace = plan.targets.any(
      (item) =>
          item.workspaceMetadataChange &&
          item.action != TargetManagementAction.repair,
    );
    final preservesContent = plan.targets.any(
      (item) => item.action == TargetManagementAction.stopManaging,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillsCard(
          width: double.infinity,
          title: Text(
            context.l10n.targetActionsSelected(
              selectedActions.length,
              widget.plan.targets.length,
            ),
          ),
          description: Text(context.l10n.manageTargetsDescription),
          footer: operating
              ? SkillsProgress(
                  value: plan.targets.isEmpty
                      ? 0
                      : finishedCount / plan.targets.length,
                  semanticsLabel: context.l10n.managementProgressTitle,
                )
              : null,
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            _failureCopy(context, error!).message,
            style: const TextStyle(color: SkillsTokens.red),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: GlassCard(
            child: ListView.separated(
              itemCount: widget.plan.targets.length,
              separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final item = widget.plan.targets[index];
                final key = updateTargetKey(item.target);
                final selected = selectedActions[key];
                final removable =
                    item.allowedActions.length == 1 &&
                    item.allowedActions.single == TargetManagementAction.remove;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _targetLabel(context, item.target),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.target.path,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontFamily: SkillsTokens.monoFamily,
                                fontSize: 11,
                              ),
                            ),
                            if (item.diagnostic.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.diagnostic,
                                style: const TextStyle(
                                  color: SkillsTokens.amber,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (item.allowedActions.contains(
                              TargetManagementAction.stopManaging,
                            )) ...[
                              const SizedBox(height: 3),
                              Text(
                                context.l10n.stopManagingDescription,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _installationHealthChip(context, item.health),
                      const SizedBox(width: 10),
                      if (removable)
                        SkillsCheckbox(
                          value: selected == TargetManagementAction.remove,
                          enabled: !operating,
                          onChanged: (_) => _selectAction(
                            item,
                            TargetManagementAction.remove,
                          ),
                          label: Text(context.l10n.remove),
                        )
                      else
                        Wrap(
                          spacing: 7,
                          children: [
                            if (item.allowedActions.contains(
                              TargetManagementAction.repair,
                            ))
                              SkillsButton.outline(
                                size: SkillsButtonSize.sm,
                                enabled: !operating,
                                backgroundColor:
                                    selected == TargetManagementAction.repair
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainer
                                    : null,
                                onPressed: () => _selectAction(
                                  item,
                                  TargetManagementAction.repair,
                                ),
                                child: Text(context.l10n.repairTarget),
                              ),
                            if (item.allowedActions.contains(
                              TargetManagementAction.stopManaging,
                            ))
                              SkillsButton.outline(
                                size: SkillsButtonSize.sm,
                                enabled: !operating,
                                backgroundColor:
                                    selected ==
                                        TargetManagementAction.stopManaging
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainer
                                    : null,
                                onPressed: () => _selectAction(
                                  item,
                                  TargetManagementAction.stopManaging,
                                ),
                                child: Text(context.l10n.stopManaging),
                              ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (changesWorkspace) ...[
          const SizedBox(height: 10),
          Text(
            context.l10n.workspaceOwnershipChanges,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
        if (preservesContent) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.targetContentPreserved,
            style: const TextStyle(color: SkillsTokens.teal, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _results(TargetManagementExecution execution) => GlassCard(
    child: ListView.separated(
      itemCount: execution.results.length,
      separatorBuilder: (_, _) => SkillsSeparator.horizontal(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final result = execution.results[index];
        final failed = result.outcome == TargetManagementOutcome.failed;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _targetLabel(context, result.target),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _managementActionLabel(context, result.action),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (result.diagnostic.isNotEmpty)
                      Text(
                        result.diagnostic,
                        style: const TextStyle(color: SkillsTokens.red),
                      ),
                  ],
                ),
              ),
              StatusChip(
                label: failed
                    ? context.l10n.targetFailed
                    : context.l10n.targetSucceeded,
                color: failed ? SkillsTokens.red : SkillsTokens.green,
              ),
            ],
          ),
        );
      },
    ),
  );
}

String _managementActionLabel(
  BuildContext context,
  TargetManagementAction action,
) => switch (action) {
  TargetManagementAction.remove => context.l10n.remove,
  TargetManagementAction.repair => context.l10n.repairTarget,
  TargetManagementAction.stopManaging => context.l10n.stopManaging,
};

class _UpdatePlanDialog extends StatefulWidget {
  const _UpdatePlanDialog({
    required this.gateway,
    required this.skill,
    required this.plan,
  });

  final SkillsGateway gateway;
  final InstalledSkill skill;
  final UpdatePlan plan;

  @override
  State<_UpdatePlanDialog> createState() => _UpdatePlanDialogState();
}

class _UpdatePlanDialogState extends State<_UpdatePlanDialog> {
  late final Set<String> selected = {
    for (final item in widget.plan.targets)
      if (item.action == UpdatePlanAction.update) updateTargetKey(item.target),
  };
  final progress = <String, UpdateTargetProgress>{};
  final activeTargetKeys = <String>{};
  UpdateExecution? execution;
  Object? error;
  bool operating = false;

  List<UpdatePlanItem> get selectedItems => widget.plan.targets
      .where((item) => selected.contains(updateTargetKey(item.target)))
      .toList(growable: false);

  int get availableCount => widget.plan.targets
      .where((item) => item.action == UpdatePlanAction.update)
      .length;

  int get finishedCount => progress.values
      .where(
        (event) =>
            activeTargetKeys.contains(updateTargetKey(event.target)) &&
            event.state == InstallationProgressState.finished,
      )
      .length;

  Future<void> _execute({UpdatePlan? retryPlan}) async {
    final plan = retryPlan ?? widget.plan.selectTargets(selectedItems);
    if (plan.targets.isEmpty || operating) return;
    setState(() {
      operating = true;
      error = null;
      activeTargetKeys
        ..clear()
        ..addAll(plan.targets.map((item) => updateTargetKey(item.target)));
      for (final item in plan.targets) {
        progress.remove(updateTargetKey(item.target));
      }
    });
    try {
      final next = await widget.gateway.executeUpdate(
        plan,
        onProgress: (event) {
          if (!mounted) return;
          setState(() => progress[updateTargetKey(event.target)] = event);
        },
      );
      if (!mounted) return;
      setState(() {
        execution = execution == null
            ? next
            : _mergeUpdateExecutions(execution!, next);
      });
    } catch (caught) {
      if (mounted) setState(() => error = caught);
    } finally {
      if (mounted) setState(() => operating = false);
    }
  }

  Future<void> _retryFailed() async {
    final current = execution;
    if (current == null || operating) return;
    final failed = current.results
        .where((result) => result.outcome == UpdateTargetOutcome.failed)
        .map((result) => updateTargetKey(result.target))
        .toSet();
    setState(() {
      operating = true;
      error = null;
    });
    try {
      final projects = await widget.gateway.loadAddedProjects();
      final entries = await widget.gateway.listInstalled(projects: projects);
      final refreshed = entries.where(
        (entry) => entry.identity == widget.skill.identity,
      );
      if (refreshed.isEmpty) {
        throw const SkillsException(
          'The failed Update Targets are no longer installed.',
          kind: SkillsFailureKind.validation,
        );
      }
      final refreshedSkill = refreshed.first;
      final failedTargets = refreshedSkill.targets
          .where((target) => failed.contains(installedUpdateTargetKey(target)))
          .toList(growable: false);
      if (failedTargets.length != failed.length) {
        throw const SkillsException(
          'The failed Update Targets changed before retry.',
          kind: SkillsFailureKind.validation,
        );
      }
      final retryPlan = await widget.gateway.preflightUpdate(
        refreshedSkill,
        failedTargets,
      );
      if (!mounted) return;
      final passiveResults = [
        for (final item in retryPlan.targets)
          if (item.action != UpdatePlanAction.update)
            UpdateTargetResult(
              target: item.target,
              name: item.name,
              coordinate: item.coordinate,
              fromVersion: item.fromVersion,
              toVersion: item.toVersion,
              outcome: item.action == UpdatePlanAction.failed
                  ? UpdateTargetOutcome.failed
                  : UpdateTargetOutcome.skipped,
              errorCode: item.reasonCode,
              diagnostic: item.diagnostic,
            ),
      ];
      final updateItems = retryPlan.targets
          .where((item) => item.action == UpdatePlanAction.update)
          .toList(growable: false);
      setState(() {
        operating = false;
        if (passiveResults.isNotEmpty) {
          final passive = UpdateExecution(
            results: passiveResults,
            summary: UpdateExecutionSummary(
              succeeded: 0,
              skipped: passiveResults
                  .where(
                    (result) => result.outcome == UpdateTargetOutcome.skipped,
                  )
                  .length,
              failed: passiveResults
                  .where(
                    (result) => result.outcome == UpdateTargetOutcome.failed,
                  )
                  .length,
            ),
          );
          execution = _mergeUpdateExecutions(current, passive);
        }
      });
      if (updateItems.isNotEmpty) {
        await _execute(retryPlan: retryPlan.selectTargets(updateItems));
      }
    } catch (caught) {
      if (mounted) {
        setState(() {
          operating = false;
          error = caught;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentExecution = execution;
    final title = operating
        ? context.l10n.updateProgressTitle
        : currentExecution != null
        ? context.l10n.updateResultsTitle
        : context.l10n.updatePlanTitle;
    return SkillsDialog(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
      title: Text(title),
      description: Text(
        operating
            ? context.l10n.updateProgressSummary(
                finishedCount,
                (currentExecution == null
                    ? selectedItems.length
                    : currentExecution.results
                          .where(
                            (result) =>
                                result.outcome == UpdateTargetOutcome.failed,
                          )
                          .length),
              )
            : currentExecution != null
            ? context.l10n.installationResultSummary(
                currentExecution.summary.succeeded,
                currentExecution.summary.failed,
              )
            : context.l10n.updatePlanDescription,
      ),
      actions: [
        if (currentExecution == null) ...[
          SkillsButton.outline(
            enabled: !operating,
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          SkillsButton(
            enabled: !operating && selectedItems.isNotEmpty,
            onPressed: _execute,
            child: Text(context.l10n.updateSelectedTargets),
          ),
        ] else ...[
          if (currentExecution.summary.failed > 0)
            SkillsButton.outline(
              enabled: !operating,
              onPressed: _retryFailed,
              child: Text(
                context.l10n.retryFailedUpdates(
                  currentExecution.summary.failed,
                ),
              ),
            ),
          SkillsButton(
            enabled: !operating,
            onPressed: () => Navigator.pop(context, currentExecution),
            child: Text(context.l10n.closeUpdatePlan),
          ),
        ],
      ],
      child: SizedBox(
        height: 500,
        child: operating && currentExecution == null
            ? _liveProgress(selectedItems)
            : currentExecution != null
            ? _results(currentExecution)
            : _selection(),
      ),
    );
  }

  Widget _selection() {
    final selectedPlan = widget.plan.selectTargets(selectedItems);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillsCard(
          width: double.infinity,
          title: Text(
            context.l10n.updateTargetsSelected(
              selectedItems.length,
              availableCount,
            ),
          ),
          description: Text(context.l10n.updatePlanDescription),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            _failureCopy(context, error!).message,
            style: const TextStyle(color: SkillsTokens.red),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: GlassCard(
            child: ListView.separated(
              itemCount: widget.plan.targets.length,
              separatorBuilder: (_, _) => SkillsSeparator.horizontal(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final item = widget.plan.targets[index];
                final key = updateTargetKey(item.target);
                final enabled = item.action == UpdatePlanAction.update;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SkillsCheckbox(
                    value: selected.contains(key),
                    enabled: enabled && !operating,
                    onChanged: (value) => setState(() {
                      final bindings = item.affectedBindings.isEmpty
                          ? [item.target]
                          : item.affectedBindings;
                      for (final binding in bindings) {
                        final bindingKey = updateTargetKey(binding);
                        if (value) {
                          selected.add(bindingKey);
                        } else {
                          selected.remove(bindingKey);
                        }
                      }
                    }),
                    label: SizedBox(
                      width: 690,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _targetLabel(context, item.target),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  context.l10n.sourceReference(item.sourceRef),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                if (item.affectedBindings.isNotEmpty)
                                  Text(
                                    context.l10n.agentsSummary(
                                      item.affectedBindings.length,
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: .72),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          StatusChip(
                            label: _updatePlanItemLabel(context, item),
                            color: enabled
                                ? SkillsTokens.orange
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (selectedPlan.workspaceLockChanges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.workspaceLockChanges,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final change in selectedPlan.workspaceLockChanges)
            Text(
              '${change.path}: ${change.fromVersion} → ${change.toVersion}',
              style: TextStyle(
                fontFamily: SkillsTokens.monoFamily,
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }

  Widget _liveProgress(List<UpdatePlanItem> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkillsCard(
        width: double.infinity,
        title: Text(context.l10n.updateProgressTitle),
        description: Text(
          context.l10n.updateProgressSummary(finishedCount, items.length),
        ),
        footer: SkillsProgress(
          value: items.isEmpty ? 0 : finishedCount / items.length,
          minHeight: 5,
          semanticsLabel: context.l10n.updateProgressTitle,
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: GlassCard(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => SkillsSeparator.horizontal(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final event = progress[updateTargetKey(item.target)];
              final finished =
                  event?.state == InstallationProgressState.finished;
              final failed =
                  event?.result?.outcome == UpdateTargetOutcome.failed;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Icon(
                      finished
                          ? failed
                                ? Icons.error
                                : Icons.check_circle
                          : Icons.pending_outlined,
                      color: finished
                          ? failed
                                ? SkillsTokens.red
                                : SkillsTokens.green
                          : SkillsTokens.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _targetLabel(context, item.target),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusChip(
                      label: event == null
                          ? context.l10n.targetWaiting
                          : finished
                          ? failed
                                ? context.l10n.targetFailed
                                : context.l10n.update
                          : context.l10n.updateProgressTitle,
                      color: failed ? SkillsTokens.red : SkillsTokens.blue,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _results(UpdateExecution current) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (operating)
        SkillsProgress(
          value: current.results.isEmpty
              ? null
              : finishedCount / current.results.length,
          minHeight: 5,
          semanticsLabel: context.l10n.updateProgressTitle,
        ),
      if (error != null) ...[
        const SizedBox(height: 10),
        Text(
          _failureCopy(context, error!).message,
          style: const TextStyle(color: SkillsTokens.red),
        ),
      ],
      const SizedBox(height: 12),
      Expanded(
        child: GlassCard(
          child: ListView.separated(
            itemCount: current.results.length,
            separatorBuilder: (_, _) => SkillsSeparator.horizontal(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final result = current.results[index];
              final failed = result.outcome == UpdateTargetOutcome.failed;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: [
                    Icon(
                      failed ? Icons.error : Icons.check_circle,
                      color: failed ? SkillsTokens.red : SkillsTokens.green,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _targetLabel(context, result.target),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            context.l10n.updateVersionChange(
                              result.fromVersion,
                              result.toVersion,
                            ),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (result.diagnostic.isNotEmpty)
                            Text(
                              result.diagnostic,
                              style: const TextStyle(color: SkillsTokens.red),
                            ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: failed
                          ? context.l10n.targetFailed
                          : context.l10n.update,
                      color: failed ? SkillsTokens.red : SkillsTokens.green,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

UpdateExecution _mergeUpdateExecutions(
  UpdateExecution previous,
  UpdateExecution retried,
) {
  final retryByTarget = {
    for (final result in retried.results)
      updateTargetKey(result.target): result,
  };
  final results = [
    for (final result in previous.results)
      retryByTarget[updateTargetKey(result.target)] ?? result,
  ];
  int count(UpdateTargetOutcome outcome) =>
      results.where((result) => result.outcome == outcome).length;
  return UpdateExecution(
    results: List.unmodifiable(results),
    summary: UpdateExecutionSummary(
      succeeded: count(UpdateTargetOutcome.succeeded),
      skipped: count(UpdateTargetOutcome.skipped),
      failed: count(UpdateTargetOutcome.failed),
    ),
  );
}

String _updatePlanItemLabel(BuildContext context, UpdatePlanItem item) =>
    item.reasonCode == 'workspace-lock-reconcile'
    ? context.l10n.reconcileWorkspaceLockTarget
    : switch (item.action) {
        UpdatePlanAction.update => context.l10n.updateVersionChange(
          item.fromVersion,
          item.toVersion,
        ),
        UpdatePlanAction.current => context.l10n.currentVersionTarget,
        UpdatePlanAction.pinned => context.l10n.fixedVersionTarget,
        UpdatePlanAction.failed => context.l10n.updateCheckTargetFailed,
      };

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.gateway,
    required this.revision,
  });
  final SkillsGateway gateway;
  final int revision;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  static const _allRoute = 'all';
  static const _userRoute = 'user';
  static const _addProjectRoute = 'add-project';
  List<InstalledSkill>? skills;
  AgentCatalog? agentCatalog;
  List<AddedProject> projects = const [];
  Object? error;
  bool loading = true;
  bool checking = false;
  Object? updateCheckError;
  Map<String, UpdateState> updates = const {};
  CommandResult? result;
  final operatingSkills = <String>{};
  final scrollController = ScrollController();
  final librarySearchController = TextEditingController();
  final librarySearchFocusNode = FocusNode();
  String selectedRoute = _allRoute;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) unawaited(load());
  }

  @override
  void dispose() {
    scrollController.dispose();
    librarySearchController.dispose();
    librarySearchFocusNode.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final restoredProjects = await widget.gateway.loadAddedProjects();
      final values = await Future.wait([
        widget.gateway.listInstalled(projects: restoredProjects),
        widget.gateway.inspectAgents(),
      ]);
      skills = values[0] as List<InstalledSkill>;
      agentCatalog = values[1] as AgentCatalog;
      projects = restoredProjects;
      if (selectedRoute.startsWith('agent:')) {
        final selectedAgent = selectedRoute.substring('agent:'.length);
        if (!_agents.contains(selectedAgent)) selectedRoute = _allRoute;
      }
      if (selectedRoute.startsWith('project:') && _selectedProject == null) {
        selectedRoute = _allRoute;
      }
    } catch (caught) {
      error = caught;
    }
    if (mounted) setState(() => loading = false);
  }

  AddedProject? get _selectedProject {
    if (!selectedRoute.startsWith('project:')) return null;
    final id = selectedRoute.substring('project:'.length);
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  Future<void> _addProject() async {
    try {
      final project = await widget.gateway.addProject();
      if (project == null || !mounted) return;
      final restored = await widget.gateway.loadAddedProjects();
      if (!mounted) return;
      setState(() {
        projects = restored;
        selectedRoute = 'project:${project.id}';
      });
      await load();
    } on Object catch (caught) {
      if (mounted) setState(() => error = caught);
    }
  }

  Future<void> _relocateProject(AddedProject project) async {
    try {
      final relocated = await widget.gateway.relocateProject(project.id);
      if (relocated == null || !mounted) return;
      final restored = await widget.gateway.loadAddedProjects();
      if (mounted) {
        setState(() => projects = restored);
        await load();
      }
    } on Object catch (caught) {
      if (mounted) setState(() => error = caught);
    }
  }

  Future<void> _removeProject(AddedProject project) async {
    final confirmed = await _confirmCommand(
      context,
      title: context.l10n.removeProjectTitle(project.name),
      description: context.l10n.removeProjectDescription,
      facts: [project.path],
      confirmLabel: context.l10n.removeFromList,
    );
    if (!confirmed || !mounted) return;
    await widget.gateway.removeProject(project.id);
    if (!mounted) return;
    final restored = await widget.gateway.loadAddedProjects();
    if (mounted) {
      setState(() {
        projects = restored;
        selectedRoute = _allRoute;
      });
      await load();
    }
  }

  Future<void> checkUpdates() async {
    if (skills == null || checking) return;
    setState(() {
      checking = true;
      updateCheckError = null;
      updates = {
        for (final skill in skills!)
          _libraryUpdateKey(skill): skill.provenance == LibraryProvenance.hub
              ? UpdateState.checking
              : UpdateState.unsupported,
      };
    });
    try {
      updates = await widget.gateway.checkUpdates(skills!);
    } catch (caught) {
      updateCheckError = caught;
      updates = {
        for (final skill in skills!)
          _libraryUpdateKey(skill): UpdateState.failed,
      };
    }
    if (mounted) setState(() => checking = false);
  }

  Future<void> update(InstalledSkill skill) async {
    if (operatingSkills.contains(skill.name)) return;
    setState(() => operatingSkills.add(skill.name));
    setState(() => result = null);
    try {
      final plan = await widget.gateway.preflightUpdate(skill, skill.targets);
      if (!mounted) return;
      final execution = await showSkillsDialog<UpdateExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _UpdatePlanDialog(
          gateway: widget.gateway,
          skill: skill,
          plan: plan,
        ),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        await load();
        await checkUpdates();
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => operatingSkills.remove(skill.name));
  }

  Future<void> manage(InstalledSkill skill) async {
    if (operatingSkills.contains(skill.name)) return;
    setState(() => operatingSkills.add(skill.name));
    setState(() => result = null);
    try {
      final plan = await widget.gateway.preflightTargetManagement(
        skill,
        skill.targets,
      );
      if (!mounted) return;
      final execution = await showSkillsDialog<TargetManagementExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _TargetManagementDialog(gateway: widget.gateway, plan: plan),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        await load();
        await checkUpdates();
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => operatingSkills.remove(skill.name));
  }

  List<String> get _agents {
    final values =
        <String>{
          ...?agentCatalog?.installed.map((agent) => agent.id),
          ...(skills ?? const <InstalledSkill>[]).expand(
            (skill) => skill.agents,
          ),
        }.toList()..sort(
          (left, right) => _agentLabel(left).compareTo(_agentLabel(right)),
        );
    return values;
  }

  bool get _hasUpdateableSkills => (skills ?? const <InstalledSkill>[]).any(
    (skill) => skill.provenance == LibraryProvenance.hub,
  );

  String _agentLabel(String agent) {
    for (final status in agentCatalog?.agents ?? const <AgentStatus>[]) {
      if (status.id == agent) return status.displayName;
    }
    return agent
        .split(RegExp(r'[-_]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  List<SkillsRailItem<String>> _railItems(BuildContext context) => [
    SkillsRailItem(value: _allRoute, label: context.l10n.all),
    SkillsRailItem(value: _userRoute, label: context.l10n.userScope),
    for (final project in projects)
      SkillsRailItem(
        value: 'project:${project.id}',
        label: project.isAccessible
            ? project.name
            : context.l10n.projectRailUnavailable(project.name),
      ),
    SkillsRailItem(value: _addProjectRoute, label: context.l10n.addProject),
    for (var index = 0; index < _agents.length; index++)
      SkillsRailItem(
        value: 'agent:${_agents[index]}',
        label: _agentLabel(_agents[index]),
        leading: AgentLogo(
          key: ValueKey('library-agent-logo-${_agents[index]}'),
          agentId: _agents[index],
          displayName: _agentLabel(_agents[index]),
        ),
        dividerBefore: index == 0,
      ),
  ];

  String _routeTitle(BuildContext context) {
    if (selectedRoute == _allRoute) return context.l10n.all;
    if (selectedRoute == _userRoute) return context.l10n.userScope;
    if (_selectedProject != null) return _selectedProject!.name;
    return _agentLabel(selectedRoute.substring('agent:'.length));
  }

  List<InstalledSkill> get _visibleSkills {
    final current = skills ?? const <InstalledSkill>[];
    final visible = <InstalledSkill>[];
    for (final skill in current) {
      final targets = switch (selectedRoute) {
        _userRoute =>
          skill.targets
              .where((target) => target.scope == InstallationScope.user)
              .toList(growable: false),
        _
            when selectedRoute.startsWith('project:') &&
                _selectedProject != null =>
          skill.targets
              .where((target) => target.projectRoot == _selectedProject!.path)
              .toList(growable: false),
        _ when selectedRoute.startsWith('agent:') =>
          skill.targets
              .where(
                (target) =>
                    target.agent == selectedRoute.substring('agent:'.length),
              )
              .toList(growable: false),
        _ => skill.targets,
      };
      if (targets.isEmpty) continue;
      final scoped = targets.length == skill.targets.length
          ? skill
          : skill.withTargets(targets);
      final query = librarySearchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final searchable = [
          scoped.name,
          scoped.coordinate,
          ...scoped.agents,
          ...scoped.projects,
          ...scoped.versions,
        ].join('\n').toLowerCase();
        if (!searchable.contains(query)) continue;
      }
      visible.add(scoped);
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) => SkillsDestinationLayout(
    rail: SkillsSideRail<String>(
      semanticLabel: context.l10n.libraryNavigation,
      selected: selectedRoute,
      onSelected: (route) {
        if (route == _addProjectRoute) {
          unawaited(_addProject());
          return;
        }
        setState(() => selectedRoute = route);
      },
      items: _railItems(context),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionEyebrow(
                    _routeTitle(context),
                    color: SkillsTokens.violet,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.yourLibrary,
                    style: const TextStyle(
                      fontFamily: SkillsTokens.serifFamily,
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (_selectedProject != null) ...[
                    SecondaryCapsuleButton(
                      label: context.l10n.relocateProject,
                      icon: Icons.drive_file_move_outline,
                      onPressed: () => _relocateProject(_selectedProject!),
                    ),
                    SecondaryCapsuleButton(
                      label: context.l10n.removeFromList,
                      icon: Icons.remove_circle_outline,
                      onPressed: () => _removeProject(_selectedProject!),
                    ),
                  ],
                  SecondaryCapsuleButton(
                    label: checking
                        ? context.l10n.checking
                        : context.l10n.checkUpdates,
                    icon: Icons.sync,
                    onPressed: checking || !_hasUpdateableSkills
                        ? null
                        : checkUpdates,
                  ),
                  SecondaryCapsuleButton(
                    label: context.l10n.refresh,
                    icon: Icons.refresh,
                    onPressed: loading ? null : load,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (result != null) ...[
          const SizedBox(height: 14),
          OperationPanel(result: result!),
        ],
        if (updateCheckError != null) ...[
          const SizedBox(height: 14),
          SkillsAlert(
            icon: const Icon(Icons.cloud_off_outlined),
            title: Text(_failureCopy(context, updateCheckError!).title),
            description: Text(_failureCopy(context, updateCheckError!).message),
          ),
        ],
        const SizedBox(height: 14),
        SkillsInput(
          key: const Key('library-search'),
          controller: librarySearchController,
          focusNode: librarySearchFocusNode,
          onChanged: (_) => setState(() {}),
          leading: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          placeholder: Text(context.l10n.searchLibrary),
          placeholderStyle: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      final copy = _failureCopy(context, error!);
      return EmptyState(
        title: copy.title,
        message: copy.message,
        action: PrimaryCapsuleButton(
          label: context.l10n.retry,
          onPressed: load,
        ),
      );
    }
    final project = _selectedProject;
    if (project != null) {
      if (!project.isAccessible) {
        final copy = switch (project.accessState) {
          ProjectAccessState.missing => (
            title: context.l10n.projectMissingTitle,
            message: context.l10n.projectMissingMessage,
          ),
          ProjectAccessState.permissionDenied => (
            title: context.l10n.projectPermissionTitle,
            message: context.l10n.projectPermissionMessage,
          ),
          ProjectAccessState.inaccessible => (
            title: context.l10n.projectInaccessibleTitle,
            message: context.l10n.projectInaccessibleMessage,
          ),
          ProjectAccessState.accessible => throw StateError(
            'Accessible project reached inaccessible state.',
          ),
        };
        return EmptyState(
          title: copy.title,
          message: '${copy.message}\n${project.path}',
          action: PrimaryCapsuleButton(
            label: context.l10n.relocateProject,
            onPressed: () => _relocateProject(project),
          ),
        );
      }
    }
    if (_visibleSkills.isEmpty) {
      if (librarySearchController.text.trim().isNotEmpty) {
        return EmptyState(
          title: context.l10n.libraryNoMatches,
          message: context.l10n.libraryNoMatchesMessage,
        );
      }
      if (project != null) {
        return EmptyState(
          title: context.l10n.emptyProjectTitle(project.name),
          message: context.l10n.emptyProjectMessage,
        );
      }
      return EmptyState(
        title: context.l10n.libraryEmpty,
        message: context.l10n.libraryEmptyMessage,
      );
    }
    return ListView.separated(
      key: const ValueKey('library-results'),
      controller: scrollController,
      itemCount: _visibleSkills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final skill = _visibleSkills[index];
        final state = updates[_libraryUpdateKey(skill)] ?? UpdateState.unknown;
        final operating = operatingSkills.contains(skill.name);
        return GlassCard(
          child: Row(
            children: [
              SkillGlyph(name: skill.name),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final appTheme = Theme.of(context);
                    final removed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => Theme(
                          data: appTheme,
                          child: LocalDetailScreen(
                            gateway: widget.gateway,
                            skill: skill,
                          ),
                        ),
                      ),
                    );
                    if (removed == true) await load();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        skill.coordinate.isEmpty
                            ? skill.path
                            : skill.coordinate,
                        style: TextStyle(
                          fontFamily: SkillsTokens.monoFamily,
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _libraryProvenanceChip(context, skill.provenance),
                    if (skill.provenance == LibraryProvenance.external)
                      StatusChip(
                        label: context.l10n.readOnly,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    StatusChip(
                      label: context.l10n.localTargets(skill.targetCount),
                      color: SkillsTokens.green,
                    ),
                    StatusChip(
                      label: context.l10n.agentsSummary(skill.agents.length),
                      color: SkillsTokens.blue,
                    ),
                    if (skill.projects.isNotEmpty)
                      StatusChip(
                        label: context.l10n.projectsSummary(
                          skill.projects.length,
                        ),
                        color: SkillsTokens.violet,
                      ),
                    if (skill.versions.isNotEmpty)
                      StatusChip(
                        label: context.l10n.versionsSummary(
                          skill.versions.length,
                        ),
                        color: skill.versionDivergence
                            ? SkillsTokens.orange
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    if (skill.versionDivergence)
                      StatusChip(
                        label: context.l10n.versionDivergence,
                        color: SkillsTokens.orange,
                      ),
                    _installationHealthChip(context, skill.health),
                    SkillRiskChip(risk: skill.riskAssessment),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (skill.provenance == LibraryProvenance.hub &&
                  state != UpdateState.unknown)
                StatusChip(
                  label: _updateLabel(context, state),
                  color: state == UpdateState.available
                      ? SkillsTokens.orange
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              if (skill.provenance == LibraryProvenance.hub &&
                  state == UpdateState.available) ...[
                const SizedBox(width: 8),
                SecondaryCapsuleButton(
                  label: context.l10n.update,
                  onPressed: operating ? null : () => update(skill),
                ),
              ],
              if (skill.provenance != LibraryProvenance.external) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: context.l10n.manageTargets,
                  child: Semantics(
                    label: context.l10n.manageTargets,
                    button: true,
                    child: SkillsButton.ghost(
                      width: 38,
                      height: 38,
                      padding: EdgeInsets.zero,
                      enabled: !operating,
                      onPressed: () => manage(skill),
                      child: Icon(
                        Icons.tune,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ExternalAdoptionDialog extends StatefulWidget {
  const _ExternalAdoptionDialog({required this.gateway, required this.plan});

  final SkillsGateway gateway;
  final ExternalAdoptionPlan plan;

  @override
  State<_ExternalAdoptionDialog> createState() =>
      _ExternalAdoptionDialogState();
}

class _ExternalAdoptionDialogState extends State<_ExternalAdoptionDialog> {
  HubContentMatch? selectedMatch;
  bool operating = false;
  Object? error;

  ExternalAdoptionPlan? get selectedPlan {
    final match = selectedMatch;
    if (match != null) return widget.plan.selectHubMatch(match);
    if (widget.plan.matches.isEmpty && widget.plan.canImportLocal) {
      return widget.plan.selectLocalImport();
    }
    return null;
  }

  Future<void> execute() async {
    final plan = selectedPlan;
    if (operating || plan == null) return;
    setState(() {
      operating = true;
      error = null;
    });
    try {
      final result = await widget.gateway.executeExternalAdoption(plan);
      if (mounted) Navigator.pop(context, result);
    } catch (caught) {
      if (mounted) {
        setState(() {
          operating = false;
          error = caught;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMatches = widget.plan.matches.isNotEmpty;
    return SkillsDialog(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
      title: Text(context.l10n.adoptExternalTitle),
      description: Text(context.l10n.adoptExternalDescription),
      actions: [
        SkillsButton.outline(
          enabled: !operating,
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        SkillsButton(
          enabled: !operating && selectedPlan != null,
          onPressed: execute,
          child: operating
              ? const SizedBox(width: 42, child: SkillsProgress(minHeight: 4))
              : Text(
                  hasMatches
                      ? context.l10n.confirmAdoption
                      : context.l10n.confirmLocalImport,
                ),
        ),
      ],
      child: SizedBox(
        width: 680,
        height: 470,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkillsCard(
              width: double.infinity,
              title: Text(context.l10n.adoptionContentDigest),
              description: SelectableText(
                widget.plan.contentDigest,
                style: const TextStyle(
                  fontFamily: SkillsTokens.monoFamily,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SkillsAlert(
              icon: const Icon(Icons.lock_outline),
              description: Text(context.l10n.adoptionPreservesContent),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              SkillsAlert.destructive(
                icon: const Icon(Icons.error_outline),
                title: Text(context.l10n.adoptionFailed),
                description: Text(_failureCopy(context, error!).message),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              hasMatches
                  ? context.l10n.hubContentMatches
                  : context.l10n.importAsLocal,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: hasMatches
                  ? ListView.separated(
                      itemCount: widget.plan.matches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final match = widget.plan.matches[index];
                        final selected = identical(selectedMatch, match);
                        return SkillsButton.outline(
                          width: double.infinity,
                          height: 86,
                          onPressed: operating
                              ? null
                              : () => setState(() => selectedMatch = match),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected
                                    ? SkillsTokens.teal
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 560,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      match.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.hubMatchSource(match.source),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      context.l10n.hubMatchVersion(
                                        match.immutableVersion,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: SkillsTokens.monoFamily,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : SkillsCard(
                      width: double.infinity,
                      title: Text(context.l10n.importAsLocal),
                      description: Text(context.l10n.importAsLocalDescription),
                      footer: Text(
                        context.l10n.exportLocalSkillDescription,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            if (hasMatches && selectedMatch == null)
              Text(
                context.l10n.chooseHubMatch,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LocalDetailScreen extends StatefulWidget {
  const LocalDetailScreen({
    super.key,
    required this.gateway,
    required this.skill,
  });
  final SkillsGateway gateway;
  final InstalledSkill skill;
  @override
  State<LocalDetailScreen> createState() => _LocalDetailScreenState();
}

class _LocalDetailScreenState extends State<LocalDetailScreen> {
  late InstalledSkill skill;
  SkillDetail? detail;
  Object? error;
  String? selectedFilePath;
  bool managing = false;
  bool updating = false;
  bool adopting = false;
  bool installingMore = false;
  bool exporting = false;
  CommandResult? result;
  @override
  void initState() {
    super.initState();
    skill = widget.skill;
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      error = null;
      selectedFilePath = null;
    });
    try {
      detail = await widget.gateway.loadLocalDetail(skill);
    } catch (caught) {
      error = caught;
    }
    if (mounted) setState(() {});
  }

  Future<void> manage() async {
    if (managing || skill.provenance == LibraryProvenance.external) return;
    setState(() {
      managing = true;
      result = null;
    });
    try {
      final plan = await widget.gateway.preflightTargetManagement(
        skill,
        skill.targets,
      );
      if (!mounted) return;
      final execution = await showSkillsDialog<TargetManagementExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _TargetManagementDialog(gateway: widget.gateway, plan: plan),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        final projects = await widget.gateway.loadAddedProjects();
        final entries = await widget.gateway.listInstalled(projects: projects);
        final refreshed = entries.where(
          (entry) => entry.identity == skill.identity,
        );
        if (!mounted) return;
        if (refreshed.isEmpty) {
          Navigator.pop(context, true);
          return;
        }
        skill = refreshed.first;
        await load();
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => managing = false);
  }

  Future<void> update() async {
    if (updating || skill.provenance != LibraryProvenance.hub) return;
    setState(() {
      updating = true;
      result = null;
    });
    try {
      final plan = await widget.gateway.preflightUpdate(skill, skill.targets);
      if (!mounted) return;
      final execution = await showSkillsDialog<UpdateExecution>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _UpdatePlanDialog(
          gateway: widget.gateway,
          skill: skill,
          plan: plan,
        ),
      );
      if (execution != null && execution.summary.succeeded > 0) {
        final projects = await widget.gateway.loadAddedProjects();
        final entries = await widget.gateway.listInstalled(projects: projects);
        final refreshed = entries.where(
          (entry) => entry.identity == skill.identity,
        );
        if (refreshed.isNotEmpty) {
          skill = refreshed.first;
          await load();
        }
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => updating = false);
  }

  Future<void> adopt() async {
    if (adopting || skill.provenance != LibraryProvenance.external) return;
    setState(() {
      adopting = true;
      result = null;
    });
    try {
      final plan = await widget.gateway.preflightExternalAdoption(skill);
      if (!mounted) return;
      final adopted = await showSkillsDialog<ExternalAdoptionResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _ExternalAdoptionDialog(gateway: widget.gateway, plan: plan),
      );
      if (adopted != null) {
        await _refreshManagedSkill(
          coordinate: adopted.coordinate,
          targetPath: adopted.target.path,
        );
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => adopting = false);
  }

  Future<void> installMore() async {
    final currentDetail = detail;
    if (installingMore ||
        skill.provenance == LibraryProvenance.external ||
        currentDetail == null) {
      return;
    }
    setState(() {
      installingMore = true;
      result = null;
    });
    final operation = _InstallOperation();
    try {
      final values = await Future.wait([
        widget.gateway.inspectAgents(),
        widget.gateway.loadAddedProjects(),
        widget.gateway.loadRiskPolicy(),
      ]);
      if (!mounted) return;
      var projects = values[1] as List<AddedProject>;
      await showSkillsDialog<_InstallationPlanOutcome>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _InstallationPlanDialog(
          gateway: widget.gateway,
          skill: SkillSummary(
            id: skill.coordinate,
            skillId: skill.coordinate,
            name: skill.name,
            source: currentDetail.source,
            imageUrl: currentDetail.imageUrl,
            installs: 0,
            latestVersion: currentDetail.immutableVersion,
            description: currentDetail.description,
            riskAssessment: skill.riskAssessment,
            localTargetCount: skill.targetCount,
          ),
          detail: currentDetail,
          catalog: values[0] as AgentCatalog,
          initialProjects: projects,
          operation: operation,
          onProjectAdded: (project) {
            projects = [...projects, project];
          },
          riskPolicy: values[2] as PersonalRiskPolicy,
        ),
      );
      if (operation.execution?.hasSuccess ?? false) {
        await _refreshManagedSkill(coordinate: skill.coordinate);
      }
    } catch (caught) {
      result = _exceptionResult(caught);
    } finally {
      operation.dispose();
    }
    if (mounted) setState(() => installingMore = false);
  }

  Future<void> exportLocal() async {
    if (exporting || skill.provenance != LibraryProvenance.local) return;
    setState(() {
      exporting = true;
      result = null;
    });
    try {
      final exported = await widget.gateway.exportLocalSkill(skill);
      if (exported != null) result = exported;
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (mounted) setState(() => exporting = false);
  }

  Future<void> _refreshManagedSkill({
    required String coordinate,
    String? targetPath,
  }) async {
    final projects = await widget.gateway.loadAddedProjects();
    final entries = await widget.gateway.listInstalled(projects: projects);
    final refreshed = entries.where(
      (entry) =>
          entry.coordinate == coordinate &&
          (targetPath == null ||
              entry.targets.any((target) => target.path == targetPath)),
    );
    if (!mounted || refreshed.isEmpty) return;
    skill = refreshed.first;
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: context.l10n.backToLibrary,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                SkillGlyph(name: skill.name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        style: const TextStyle(
                          fontFamily: SkillsTokens.serifFamily,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SelectableText(
                        skill.path,
                        style: TextStyle(
                          fontFamily: SkillsTokens.monoFamily,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _libraryProvenanceChip(context, skill.provenance),
                const SizedBox(width: 8),
                SkillRiskChip(risk: skill.riskAssessment),
                const SizedBox(width: 8),
                if (skill.provenance == LibraryProvenance.external) ...[
                  StatusChip(
                    label: context.l10n.readOnly,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  SecondaryCapsuleButton(
                    label: context.l10n.bringUnderManagement,
                    icon: Icons.add_link,
                    onPressed: adopting ? null : adopt,
                  ),
                ] else ...[
                  if (skill.provenance == LibraryProvenance.hub) ...[
                    SecondaryCapsuleButton(
                      label: context.l10n.update,
                      icon: Icons.sync,
                      onPressed: updating || managing ? null : update,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Tooltip(
                    message: context.l10n.manageTargets,
                    child: Semantics(
                      label: context.l10n.manageTargets,
                      button: true,
                      child: SkillsButton.ghost(
                        width: 38,
                        height: 38,
                        padding: EdgeInsets.zero,
                        enabled: !managing && !installingMore && !updating,
                        onPressed: manage,
                        child: const Icon(Icons.tune, size: 18),
                      ),
                    ),
                  ),
                  if (detail?.immutableVersion.isNotEmpty ?? false) ...[
                    const SizedBox(width: 8),
                    SecondaryCapsuleButton(
                      label: context.l10n.installMoreTargets,
                      icon: Icons.add_to_photos_outlined,
                      onPressed: installingMore || managing || updating
                          ? null
                          : installMore,
                    ),
                  ],
                  if (skill.provenance == LibraryProvenance.local) ...[
                    const SizedBox(width: 8),
                    SecondaryCapsuleButton(
                      label: context.l10n.exportLocalSkill,
                      icon: Icons.ios_share_outlined,
                      onPressed: exporting ? null : exportLocal,
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (result != null) ...[
              OperationPanel(result: result!),
              const SizedBox(height: 14),
            ],
            Expanded(
              child: Column(
                children: [
                  _InstallationTargetsPanel(skill: skill),
                  const SizedBox(height: 14),
                  if (detail?.hasExecutableContent ?? false) ...[
                    _RiskNotice(detail: detail!),
                    const SizedBox(height: 14),
                  ],
                  Expanded(
                    child: error != null
                        ? EmptyState(
                            title: context.l10n.localReadFailed,
                            message: context.l10n.localReadFailedMessage,
                            action: PrimaryCapsuleButton(
                              label: context.l10n.retry,
                              onPressed: load,
                            ),
                          )
                        : detail == null
                        ? const Center(child: CircularProgressIndicator())
                        : _LocalSkillDocuments(
                            detail: detail!,
                            selectedFilePath: selectedFilePath,
                            onSelected: (path) =>
                                setState(() => selectedFilePath = path),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InstallationTargetsPanel extends StatelessWidget {
  const _InstallationTargetsPanel({required this.skill});

  final InstalledSkill skill;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.knownInstallationTargets,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final (index, target) in skill.targets.indexed) ...[
          if (index > 0)
            SkillsSeparator.horizontal(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.targetSummary(
                        target.scope == InstallationScope.user
                            ? context.l10n.userScope
                            : context.l10n.projectScope,
                        _agentDisplayLabel(target.agent),
                        target.version.isEmpty
                            ? context.l10n.unversioned
                            : target.version,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      target.path,
                      style: TextStyle(
                        fontFamily: SkillsTokens.monoFamily,
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusChip(
                label: _installationModeLabel(context, target.mode),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              StatusChip(
                label: _receiptStateLabel(context, target.receiptState),
                color: target.receiptState == ReceiptState.present
                    ? SkillsTokens.teal
                    : SkillsTokens.amber,
              ),
              const SizedBox(width: 7),
              _installationHealthChip(context, target.health),
            ],
          ),
        ],
      ],
    ),
  );
}

class _LocalSkillDocuments extends StatelessWidget {
  const _LocalSkillDocuments({
    required this.detail,
    required this.selectedFilePath,
    required this.onSelected,
  });

  final SkillDetail detail;
  final String? selectedFilePath;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final supportingFiles = detail.files
        .where((file) => file.kind != 'instructions' && file.path != 'SKILL.md')
        .toList(growable: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedFilePath ?? context.l10n.instructionsTab,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(child: _document(context)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 260,
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionEyebrow(context.l10n.supportingFiles),
                const SizedBox(height: 10),
                SkillsButton.ghost(
                  width: double.infinity,
                  mainAxisAlignment: MainAxisAlignment.start,
                  backgroundColor: selectedFilePath == null
                      ? Theme.of(context).colorScheme.surfaceContainer
                      : null,
                  onPressed: () => onSelected(null),
                  child: Text(context.l10n.instructionsTab),
                ),
                SkillsSeparator.horizontal(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: ListView(
                    children: supportingFiles
                        .map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SkillsButton.ghost(
                              width: double.infinity,
                              mainAxisAlignment: MainAxisAlignment.start,
                              backgroundColor: selectedFilePath == file.path
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer
                                  : null,
                              onPressed: () => onSelected(file.path),
                              leading: Icon(
                                file.executable
                                    ? Icons.terminal
                                    : file.binary
                                    ? Icons.data_object
                                    : Icons.description_outlined,
                                size: 15,
                                color: file.executable
                                    ? SkillsTokens.amber
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: .72),
                              ),
                              child: Flexible(
                                child: Text(
                                  file.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: SkillsTokens.monoFamily,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _document(BuildContext context) {
    if (selectedFilePath == null) {
      return SkillMarkdownView(data: detail.markdown);
    }
    final file = detail.files.firstWhere(
      (candidate) => candidate.path == selectedFilePath,
    );
    if (file.binary || file.contents.isEmpty) {
      return Center(
        child: Text(
          context.l10n.fileContentUnavailable,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final content = file.path.toLowerCase().endsWith('.md')
        ? SkillMarkdownView(data: file.contents)
        : SingleChildScrollView(
            child: SelectableText(
              file.contents,
              style: const TextStyle(fontFamily: SkillsTokens.monoFamily),
            ),
          );
    if (!file.truncated) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.fileContentTruncated,
          style: const TextStyle(color: SkillsTokens.amber),
        ),
        const SizedBox(height: 8),
        Expanded(child: content),
      ],
    );
  }
}

enum _SettingsRoute {
  general,
  agents,
  hub,
  installationPolicy,
  storage,
  colorScheme,
  about,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.gateway,
    required this.folderTheme,
    required this.onFolderThemeChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });
  final SkillsGateway gateway;
  final String folderTheme;
  final ValueChanged<Color> onFolderThemeChanged;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final controller = TextEditingController();
  final hubController = TextEditingController();
  final scrollController = ScrollController();
  _SettingsRoute selectedRoute = _SettingsRoute.general;
  CliStatus? status;
  HubStatus? hubStatus;
  PersonalRiskPolicy? riskPolicy;
  StorageStatus? storageStatus;
  String? appVersion;
  bool detecting = true;
  bool loadingSettings = true;
  bool testingHub = false;
  String? notice;
  AgentCatalog? agentCatalog;
  Object? agentInspectionError;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final customCliPath = await widget.gateway.loadCustomCliPath() ?? '';
    if (!mounted) return;
    controller.text = customCliPath;
    final values = await Future.wait([
      widget.gateway.loadHubOrigin(),
      widget.gateway.loadRiskPolicy(),
      widget.gateway.loadAppVersion(),
    ]);
    if (!mounted) return;
    hubController.text = values[0] as String;
    riskPolicy = values[1] as PersonalRiskPolicy;
    appVersion = values[2] as String;
    await detect();
    if (!mounted) return;
    final inspectedStorage = await widget.gateway.inspectStorage();
    if (!mounted) return;
    setState(() {
      storageStatus = inspectedStorage;
      loadingSettings = false;
    });
  }

  Future<void> detect() async {
    if (!mounted) return;
    setState(() => detecting = true);
    final detected = await widget.gateway.detectCli(
      customPath: controller.text,
    );
    AgentCatalog? inspected;
    Object? inspectionError;
    if (detected.isReady) {
      try {
        inspected = await widget.gateway.inspectAgents();
      } on Object catch (caught) {
        inspectionError = caught;
      }
    }
    if (!mounted) return;
    setState(() {
      status = detected;
      agentCatalog = inspected;
      agentInspectionError = inspectionError;
      detecting = false;
    });
  }

  Future<void> save() async {
    await widget.gateway.saveCustomCliPath(controller.text);
    await detect();
  }

  Future<void> clear() async {
    controller.clear();
    await widget.gateway.saveCustomCliPath(null);
    await detect();
  }

  Future<HubStatus?> testHub() async {
    if (!mounted) return null;
    final origin = hubController.text;
    setState(() {
      testingHub = true;
      notice = null;
    });
    HubStatus tested;
    try {
      tested = await widget.gateway.testHubOrigin(origin);
    } on Object catch (error) {
      tested = HubStatus(
        origin: origin,
        state: HealthState.unreachable,
        issue: HubIssue.connectionFailure,
        diagnostic: error.toString(),
      );
    } finally {
      if (mounted) setState(() => testingHub = false);
    }
    if (!mounted) return null;
    setState(() => hubStatus = tested);
    return tested;
  }

  Future<void> saveHub() async {
    try {
      final tested = await testHub();
      if (!mounted || tested?.isReady != true) return;
      await widget.gateway.saveHubOrigin(hubController.text);
      final savedOrigin = await widget.gateway.loadHubOrigin();
      if (!mounted) return;
      hubController.text = savedOrigin;
      setState(() => notice = context.l10n.hubOriginSaved);
    } on FormatException catch (error) {
      if (mounted) {
        setState(
          () => hubStatus = HubStatus(
            origin: hubController.text,
            state: HealthState.invalid,
            issue: HubIssue.invalidOrigin,
            diagnostic: error.message,
          ),
        );
      }
    }
  }

  Future<void> resetHub() async {
    await widget.gateway.resetHubOrigin();
    if (!mounted) return;
    final defaultOrigin = await widget.gateway.loadHubOrigin();
    if (!mounted) return;
    hubController.text = defaultOrigin;
    await testHub();
  }

  Future<void> setCriticalOverride(bool value) async {
    final policy = PersonalRiskPolicy(allowCriticalOverride: value);
    await widget.gateway.saveRiskPolicy(policy);
    if (mounted) {
      setState(() {
        riskPolicy = policy;
        notice = context.l10n.policySaved;
      });
    }
  }

  Future<void> refreshStorage() async {
    final inspected = await widget.gateway.inspectStorage();
    if (mounted) setState(() => storageStatus = inspected);
  }

  void _selectRoute(_SettingsRoute route) {
    setState(() => selectedRoute = route);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) scrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    hubController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SkillsDestinationLayout(
    rail: SkillsSideRail<_SettingsRoute>(
      semanticLabel: context.l10n.settingsNavigation,
      selected: selectedRoute,
      onSelected: _selectRoute,
      items: [
        SkillsRailItem(
          value: _SettingsRoute.general,
          label: context.l10n.general,
        ),
        SkillsRailItem(
          value: _SettingsRoute.agents,
          label: context.l10n.agents,
        ),
        SkillsRailItem(value: _SettingsRoute.hub, label: context.l10n.hub),
        SkillsRailItem(
          value: _SettingsRoute.installationPolicy,
          label: context.l10n.installationPolicy,
        ),
        SkillsRailItem(
          value: _SettingsRoute.storage,
          label: context.l10n.storage,
        ),
        SkillsRailItem(
          value: _SettingsRoute.colorScheme,
          label: context.l10n.colorScheme,
        ),
        SkillsRailItem(value: _SettingsRoute.about, label: context.l10n.about),
      ],
    ),
    child: loadingSettings
        ? const Center(child: CircularProgressIndicator())
        : _settingsPage(),
  );

  Widget _settingsPage() => ListView(
    controller: scrollController,
    children: [
      SectionEyebrow(context.l10n.localConfiguration, color: SkillsTokens.gold),
      const SizedBox(height: 8),
      Text(
        _routeTitle(),
        style: const TextStyle(
          fontFamily: SkillsTokens.serifFamily,
          fontSize: 36,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 22),
      if (notice != null) ...[
        Text(notice!, style: const TextStyle(color: SkillsTokens.green)),
        const SizedBox(height: 12),
      ],
      switch (selectedRoute) {
        _SettingsRoute.general => _generalSettings(),
        _SettingsRoute.agents => _agentSettings(),
        _SettingsRoute.hub => _hubSettings(),
        _SettingsRoute.installationPolicy => _policySettings(),
        _SettingsRoute.storage => _storageSettings(),
        _SettingsRoute.colorScheme => ColorSchemeInspector(
          seed: _AppShellState._folderThemeColor(widget.folderTheme),
        ),
        _SettingsRoute.about => _aboutSettings(),
      },
    ],
  );

  String _routeTitle() => switch (selectedRoute) {
    _SettingsRoute.general => context.l10n.general,
    _SettingsRoute.agents => context.l10n.agents,
    _SettingsRoute.hub => context.l10n.hub,
    _SettingsRoute.installationPolicy => context.l10n.installationPolicy,
    _SettingsRoute.storage => context.l10n.storage,
    _SettingsRoute.colorScheme => context.l10n.colorScheme,
    _SettingsRoute.about => context.l10n.about,
  };

  Widget _generalSettings() => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.generalSettingsTitle),
    description: Text(context.l10n.generalSettingsDescription),
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.privacySummary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.appearanceMode,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.appearanceModeDescription,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _themeModeTabs(),
          const SizedBox(height: 20),
          SkillsSeparator.horizontal(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.folderColorTheme,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.folderColorThemeDescription,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: const Key('folder-theme-picker'),
            child: BloomColorPicker(
              initialColor: _AppShellState._folderThemeColor(
                widget.folderTheme,
              ),
              onColorChanged: widget.onFolderThemeChanged,
              presets: brandThemePresets,
              style: BloomColorPickerStyle(
                alignment: BloomColorPickerAlignment.circleLeft,
                hapticFeedback: false,
                pillBackgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                pillTextColor: Theme.of(context).colorScheme.onSurface,
                iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _themeModeTabs() {
    final scheme = Theme.of(context).colorScheme;
    return DiscreteTabs(
      key: const Key('appearance-mode-tabs'),
      currentIndex: widget.themeMode.index,
      onSelect: (index) =>
          widget.onThemeModeChanged(AppThemeMode.values[index]),
      tabs: [
        DiscreteTab(
          label: context.l10n.followSystem,
          icon: Icons.brightness_auto_rounded,
          activeColor: scheme.onPrimaryContainer,
        ),
        DiscreteTab(
          label: context.l10n.lightMode,
          icon: Icons.light_mode_rounded,
          activeColor: scheme.onPrimaryContainer,
        ),
        DiscreteTab(
          label: context.l10n.darkMode,
          icon: Icons.dark_mode_rounded,
          activeColor: scheme.onPrimaryContainer,
        ),
      ],
      style: DiscreteTabsStyle(
        backgroundColor: scheme.surfaceContainerHigh,
        activeBackgroundColor: scheme.primaryContainer,
        inactiveIconColor: scheme.onSurfaceVariant,
        shadowColor: scheme.shadow.withValues(alpha: .22),
      ),
    );
  }

  Widget _agentSettings() {
    final cliCard = SkillsCard(
      width: double.infinity,
      title: Row(
        children: [
          Expanded(child: Text(context.l10n.agentsSettingsTitle)),
          if (detecting)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            StatusChip(
              label: status?.isReady == true
                  ? context.l10n.ready
                  : _cliAvailabilityLabel(context, status?.availability),
              color: status?.isReady == true
                  ? SkillsTokens.green
                  : SkillsTokens.amber,
            ),
        ],
      ),
      description: Text(
        status?.isReady == true
            ? '${status!.path} · v${status!.version}'
            : status == null
            ? context.l10n.detecting
            : _cliStatusMessage(context, status!),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!kReleaseMode) ...[
              SkillsInput(
                key: const Key('cli-path'),
                controller: controller,
                placeholder: const Text('/path/to/development/skillsgo'),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!kReleaseMode)
                  SkillsButton(
                    enabled: !detecting,
                    onPressed: save,
                    child: Text(context.l10n.saveAndDetect),
                  ),
                SkillsButton.outline(
                  enabled: !detecting,
                  onPressed: detect,
                  child: Text(context.l10n.detectAgain),
                ),
                if (!kReleaseMode)
                  SkillsButton.outline(
                    enabled: !detecting,
                    onPressed: clear,
                    child: Text(context.l10n.clearCustomPath),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cliCard,
        if (agentInspectionError != null) ...[
          const SizedBox(height: 14),
          SkillsCard(
            width: double.infinity,
            description: Text(context.l10n.agentInspectionFailed),
          ),
        ],
        if (agentCatalog != null) ...[
          const SizedBox(height: 14),
          _agentCatalogCard(agentCatalog!),
        ],
      ],
    );
  }

  Widget _agentCatalogCard(AgentCatalog catalog) {
    final agents = [...catalog.agents]
      ..sort((left, right) {
        if (left.installed != right.installed) return left.installed ? -1 : 1;
        return left.displayName.compareTo(right.displayName);
      });
    return SkillsCard(
      width: double.infinity,
      title: Text(
        context.l10n.agentCatalogSummary(
          catalog.installed.length,
          catalog.agents.length,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            for (var index = 0; index < agents.length; index++) ...[
              _AgentStatusRow(status: agents[index]),
              if (index != agents.length - 1)
                SkillsSeparator.horizontal(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hubSettings() => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.hubSettingsTitle),
    description: Text(context.l10n.hubSettingsDescription),
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkillsInput(
            key: const Key('hub-origin'),
            controller: hubController,
            placeholder: const Text('https://hub.example.com'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SkillsButton(
                enabled: !testingHub,
                onPressed: saveHub,
                child: Text(context.l10n.saveOrigin),
              ),
              SkillsButton.outline(
                enabled: !testingHub,
                onPressed: testHub,
                child: Text(context.l10n.testConnection),
              ),
              SkillsButton.outline(
                enabled: !testingHub,
                onPressed: resetHub,
                child: Text(context.l10n.resetDefault),
              ),
            ],
          ),
          if (hubStatus != null) ...[
            const SizedBox(height: 14),
            Text(
              hubStatus!.isReady
                  ? context.l10n.connectionReady
                  : '${context.l10n.connectionFailed}: ${_hubStatusMessage(context, hubStatus!)}',
              style: TextStyle(
                color: hubStatus!.isReady
                    ? SkillsTokens.green
                    : SkillsTokens.amber,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _policySettings() => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.riskPolicyTitle),
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          SkillsSwitch(
            value: true,
            enabled: false,
            label: Text(context.l10n.confirmHighRisk),
            sublabel: Text(context.l10n.confirmHighRiskDescription),
          ),
          const SizedBox(height: 14),
          SkillsSwitch(
            key: const Key('critical-risk-override'),
            value: riskPolicy?.allowCriticalOverride ?? false,
            onChanged: setCriticalOverride,
            label: Text(context.l10n.allowCriticalOverride),
            sublabel: Text(context.l10n.allowCriticalOverrideDescription),
          ),
        ],
      ),
    ),
  );

  Widget _storageSettings() {
    final storage = storageStatus!;
    final label = switch (storage.state) {
      HealthState.ready => context.l10n.storageHealthy,
      HealthState.notInitialized => context.l10n.storageNotInitialized,
      _ => context.l10n.storageUnavailable,
    };
    return SkillsCard(
      width: double.infinity,
      title: Text(context.l10n.storageSettingsTitle),
      description: Text(
        storage.path.isEmpty
            ? context.l10n.storagePathUnavailable
            : storage.path,
      ),
      footer: SkillsButton.outline(
        onPressed: refreshStorage,
        child: Text(context.l10n.refresh),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: [
            StatusChip(
              label: label,
              color: storage.state == HealthState.ready
                  ? SkillsTokens.green
                  : SkillsTokens.amber,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_storageStatusMessage(context, storage))),
          ],
        ),
      ),
    );
  }

  Widget _aboutSettings() => SkillsCard(
    width: double.infinity,
    title: Text(context.l10n.aboutSettingsTitle),
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          _versionRow(context.l10n.appVersion, appVersion ?? '—'),
          const SizedBox(height: 12),
          _versionRow(context.l10n.cliVersion, status?.version ?? '—'),
          const SizedBox(height: 12),
          StatusChip(
            label: status == null
                ? context.l10n.detecting
                : status!.isReady
                ? context.l10n.compatible
                : _cliAvailabilityLabel(context, status!.availability),
            color: status?.isReady == true
                ? SkillsTokens.green
                : SkillsTokens.amber,
          ),
          if (status != null && !status!.isReady) ...[
            const SizedBox(height: 12),
            Text(
              _cliStatusMessage(context, status!),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _versionRow(String label, String version) => Row(
    children: [
      Expanded(child: Text(label)),
      SelectableText(
        version,
        style: const TextStyle(fontFamily: SkillsTokens.monoFamily),
      ),
    ],
  );
}

class _AgentStatusRow extends StatelessWidget {
  const _AgentStatusRow({required this.status});

  final AgentStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            StatusChip(
              label: status.installed
                  ? context.l10n.agentInstalled
                  : context.l10n.agentSupported,
              color: status.installed
                  ? SkillsTokens.green
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: status.supportedScopes
              .map(
                (scope) => StatusChip(
                  label: switch (scope) {
                    InstallationScope.user => context.l10n.userScope,
                    InstallationScope.project => context.l10n.projectScope,
                  },
                  color: SkillsTokens.blue,
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 6),
        Text(
          status.installed
              ? context.l10n.agentDetectedDescription
              : context.l10n.agentSupportedDescription,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        if (status.userTarget != null) ...[
          const SizedBox(height: 5),
          SelectableText(
            context.l10n.agentUserTarget(status.userTarget!.path),
            style: TextStyle(
              fontFamily: SkillsTokens.monoFamily,
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: .72),
            ),
          ),
        ],
      ],
    ),
  );
}

class OperationPanel extends StatelessWidget {
  const OperationPanel({super.key, required this.result});
  final CommandResult result;
  @override
  Widget build(BuildContext context) {
    if (result.output.exitCode == 69) {
      return SkillsAlert(
        icon: const Icon(Icons.cloud_off_outlined),
        title: Text(context.l10n.offlineTitle),
        description: Text(context.l10n.offlineMessage),
      );
    }
    if (result.output.exitCode == 75) {
      return SkillsAlert(
        icon: const Icon(Icons.timer_off_outlined),
        title: Text(context.l10n.timeoutTitle),
        description: Text(context.l10n.timeoutMessage),
      );
    }
    return ExpansionTile(
      collapsedBackgroundColor:
          (result.succeeded ? SkillsTokens.green : SkillsTokens.red).withValues(
            alpha: .1,
          ),
      backgroundColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      leading: Icon(
        result.succeeded ? Icons.check_circle_outline : Icons.error_outline,
        color: result.succeeded ? SkillsTokens.green : SkillsTokens.red,
      ),
      title: Text(
        result.succeeded
            ? context.l10n.commandCompleted
            : context.l10n.commandFailed,
      ),
      subtitle: Text(context.l10n.commandExit(result.output.exitCode)),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            '\$ ${result.command.join(' ')}\n\nstdout:\n${result.output.stdout}\n\nstderr:\n${result.output.stderr}',
            style: const TextStyle(
              fontFamily: SkillsTokens.monoFamily,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> _confirmCommand(
  BuildContext context, {
  required String title,
  required String description,
  required List<String> facts,
  required String confirmLabel,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              const SizedBox(height: 16),
              ...facts.map(
                (fact) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    fact,
                    style: TextStyle(
                      fontFamily: SkillsTokens.monoFamily,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: destructive ? SkillsTokens.red : Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

CommandResult _exceptionResult(Object error) {
  final exitCode = error is SkillsException
      ? switch (error.kind) {
          SkillsFailureKind.offline => 69,
          SkillsFailureKind.timeout => 75,
          _ => 1,
        }
      : 1;
  return CommandResult(
    command: const ['skills'],
    output: ProcessOutput(
      exitCode: exitCode,
      stdout: '',
      stderr: error.toString(),
    ),
  );
}

String _updateLabel(BuildContext context, UpdateState state) => switch (state) {
  UpdateState.unknown => context.l10n.updateUnknown,
  UpdateState.checking => context.l10n.updateChecking,
  UpdateState.upToDate => context.l10n.upToDate,
  UpdateState.available => context.l10n.updateAvailable,
  UpdateState.unsupported => context.l10n.updateUnavailable,
  UpdateState.failed => context.l10n.updateCheckFailed,
};

String _libraryUpdateKey(InstalledSkill skill) =>
    skill.identity.isEmpty ? skill.name : skill.identity;

String _agentDisplayLabel(String agent) => agent
    .split(RegExp(r'[-_]'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _installationModeLabel(BuildContext context, InstallationMode mode) =>
    switch (mode) {
      InstallationMode.symlink => context.l10n.modeSymlink,
      InstallationMode.copy => context.l10n.modeCopy,
      InstallationMode.external => context.l10n.modeExternal,
    };

String _receiptStateLabel(BuildContext context, ReceiptState state) =>
    switch (state) {
      ReceiptState.present => context.l10n.receiptPresent,
      ReceiptState.missing => context.l10n.receiptMissing,
      ReceiptState.invalid => context.l10n.receiptInvalid,
    };

Widget _libraryProvenanceChip(
  BuildContext context,
  LibraryProvenance provenance,
) {
  final presentation = switch (provenance) {
    LibraryProvenance.hub => (
      label: context.l10n.hubManaged,
      color: SkillsTokens.teal,
    ),
    LibraryProvenance.local => (
      label: context.l10n.localManaged,
      color: SkillsTokens.violet,
    ),
    LibraryProvenance.external => (
      label: context.l10n.externalInstallation,
      color: SkillsTokens.amber,
    ),
  };
  return StatusChip(label: presentation.label, color: presentation.color);
}

Widget _installationHealthChip(
  BuildContext context,
  InstallationHealth health,
) {
  final presentation = switch (health) {
    InstallationHealth.healthy => (
      label: context.l10n.healthHealthy,
      color: SkillsTokens.green,
    ),
    InstallationHealth.undeclared => (
      label: context.l10n.healthUndeclared,
      color: SkillsTokens.amber,
    ),
    InstallationHealth.workspaceUnreadable => (
      label: context.l10n.healthWorkspaceUnreadable,
      color: SkillsTokens.orange,
    ),
    InstallationHealth.lockMismatch => (
      label: context.l10n.healthLockMismatch,
      color: SkillsTokens.orange,
    ),
    InstallationHealth.missing => (
      label: context.l10n.healthMissing,
      color: SkillsTokens.red,
    ),
    InstallationHealth.replaced => (
      label: context.l10n.healthReplaced,
      color: SkillsTokens.red,
    ),
    InstallationHealth.localModification => (
      label: context.l10n.healthLocalModification,
      color: SkillsTokens.amber,
    ),
    InstallationHealth.unreadable => (
      label: context.l10n.healthUnreadable,
      color: SkillsTokens.red,
    ),
    InstallationHealth.unexpectedPath => (
      label: context.l10n.healthUnexpectedPath,
      color: SkillsTokens.red,
    ),
    InstallationHealth.receiptMissing => (
      label: context.l10n.healthReceiptMissing,
      color: SkillsTokens.red,
    ),
  };
  return StatusChip(label: presentation.label, color: presentation.color);
}

String _hubStatusMessage(BuildContext context, HubStatus status) =>
    switch (status.issue) {
      HubIssue.invalidOrigin => context.l10n.hubInvalidOrigin,
      HubIssue.httpFailure => context.l10n.hubHttpFailure(
        status.httpStatus ?? 0,
      ),
      HubIssue.invalidProtocol => context.l10n.hubInvalidProtocol,
      HubIssue.invalidJson => context.l10n.hubInvalidJson,
      HubIssue.connectionFailure => context.l10n.hubConnectionFailure,
      HubIssue.timeout => context.l10n.hubConnectionTimeout,
      null => context.l10n.hubInvalidProtocol,
    };

String _storageStatusMessage(BuildContext context, StorageStatus status) =>
    switch (status.state) {
      HealthState.ready => context.l10n.storageHealthyDescription,
      HealthState.notInitialized =>
        context.l10n.storageNotInitializedDescription,
      HealthState.unreachable => context.l10n.storageUnavailableDescription,
      HealthState.invalid => context.l10n.storageInvalidResponse,
    };

String _cliAvailabilityLabel(
  BuildContext context,
  CliAvailability? availability,
) => switch (availability) {
  CliAvailability.ready => context.l10n.ready,
  CliAvailability.missing => context.l10n.missing,
  CliAvailability.incompatible => context.l10n.incompatible,
  null => context.l10n.unknown,
};
