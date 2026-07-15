/*
 * [INPUT]: Depends on SkillsGateway contracts, localized copy, shadcn_ui primitives, stateful nested navigation, and SkillsGo brand tokens.
 * [OUTPUT]: Provides the desktop shell plus persistent Discover, searchable managed/external multi-target Library/detail, read-only External inspection, explicit-project and Agent views, operations, and operational Settings journeys.
 * [POS]: Serves as the primary rendered product surface and translates domain states into accessible localized UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../domain/skills_gateway.dart';
import '../l10n/app_localizations.dart';
import 'brand.dart';
import 'nested_navigation.dart';

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
  _Destination destination = _Destination.discover;
  int libraryRevision = 0;
  CliStatus? cliStatus;

  @override
  void initState() {
    super.initState();
    unawaited(_detectCli());
  }

  Future<void> _detectCli() async {
    final detected = await widget.gateway.detectCli();
    if (mounted) setState(() => cliStatus = detected);
  }

  Color get _tint => switch (destination) {
    _Destination.discover => const Color(0xFF0E2A27),
    _Destination.library => const Color(0xFF1A1730),
    _Destination.settings => const Color(0xFF241D11),
  };

  void _showLibrary() => setState(() {
    destination = _Destination.library;
    libraryRevision++;
  });

  @override
  Widget build(BuildContext context) => SkillsBackground(
    tint: _tint,
    child: Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _TopBar(
              selected: destination,
              onSelected: (value) => setState(() => destination = value),
            ),
            if (cliStatus != null && !cliStatus!.isReady)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
                child: _CliBanner(
                  status: cliStatus!,
                  onOpenSettings: () =>
                      setState(() => destination = _Destination.settings),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: destination.index,
                children: [
                  TickerMode(
                    enabled: destination == _Destination.discover,
                    child: DiscoverScreen(
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
                    child: SettingsScreen(gateway: widget.gateway),
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

class _TopBar extends StatefulWidget {
  const _TopBar({required this.selected, required this.onSelected});
  final _Destination selected;
  final ValueChanged<_Destination> onSelected;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> with SingleTickerProviderStateMixin {
  static const _itemWidth = 84.0;
  late final AnimationController _position;

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: widget.selected.index.toDouble(),
    )..addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant _TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = widget.selected.index.toDouble();
      return;
    }
    _position.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 32),
        _position.value,
        widget.selected.index.toDouble(),
        _position.velocity,
      ),
    );
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _position
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SkillsGo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Align(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: SkillsTokens.hairline),
              ),
              child: SizedBox(
                width: _itemWidth * _Destination.values.length,
                height: 30,
                child: Stack(
                  children: [
                    Positioned(
                      left: _position.value * _itemWidth,
                      top: 0,
                      bottom: 0,
                      width: _itemWidth,
                      child: const DecoratedBox(
                        key: ValueKey('nav-indicator'),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ),
                    ),
                    Row(
                      children: _Destination.values
                          .map(
                            (item) => SizedBox(
                              width: _itemWidth,
                              child: Center(
                                child: _NavButton(
                                  label: switch (item) {
                                    _Destination.discover =>
                                      context.l10n.discover,
                                    _Destination.library =>
                                      context.l10n.library,
                                    _Destination.settings =>
                                      context.l10n.settings,
                                  },
                                  selected: widget.selected == item,
                                  onPressed: () => widget.onSelected(item),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.black : SkillsTokens.textSecondary,
        backgroundColor: Colors.transparent,
        shape: const StadiumBorder(),
        padding: EdgeInsets.zero,
        fixedSize: const Size(80, 26),
        minimumSize: const Size(80, 26),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
        textStyle: TextStyle(
          fontFamily: SkillsTokens.sansFamily,
          fontSize: 14,
          height: 1,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      child: Transform.translate(
        offset: const Offset(0, 1.5),
        child: Text(
          label,
          key: const ValueKey('nav-label'),
          maxLines: 1,
          softWrap: false,
        ),
      ),
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

class _DiscoverScreenState extends State<DiscoverScreen> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  final installOperations = <String, _InstallOperation>{};
  final routeStates = <_DiscoverRoute, _DiscoveryRouteState>{
    for (final route in _DiscoverRoute.values) route: _DiscoveryRouteState(),
  };
  _DiscoverRoute selectedRoute = _DiscoverRoute.search;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => focusNode.requestFocus(),
    );
  }

  Future<void> search([String? value]) async {
    final query = (value ?? controller.text).trim();
    if (query.isEmpty) {
      final state = routeStates[_DiscoverRoute.search]!;
      setState(() {
        state.generation++;
        state.results = null;
        state.error = null;
        state.loading = false;
        state.loadingMore = false;
        state.nextOffset = null;
      });
      return;
    }
    await _loadRoute(_DiscoverRoute.search, reset: true, query: query);
  }

  void _selectRoute(_DiscoverRoute route) {
    setState(() => selectedRoute = route);
    final state = routeStates[route]!;
    if (route != _DiscoverRoute.search &&
        state.results == null &&
        !state.loading) {
      unawaited(_loadRoute(route, reset: true));
    }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SkillsDestinationLayout(
    rail: SkillsSideRail<_DiscoverRoute>(
      semanticLabel: context.l10n.discoverNavigation,
      selected: selectedRoute,
      onSelected: _selectRoute,
      items: [
        SkillsRailItem(
          value: _DiscoverRoute.search,
          label: context.l10n.search,
        ),
        SkillsRailItem(
          value: _DiscoverRoute.ranking,
          label: context.l10n.ranking,
        ),
        SkillsRailItem(
          value: _DiscoverRoute.trending,
          label: context.l10n.trending,
        ),
        SkillsRailItem(value: _DiscoverRoute.hot, label: context.l10n.hot),
      ],
    ),
    child: switch (selectedRoute) {
      _DiscoverRoute.search => _searchPage(),
      _DiscoverRoute.ranking => _collectionPage(
        _DiscoverRoute.ranking,
        context.l10n.allTimeRanking,
        context.l10n.allTimeDescription,
      ),
      _DiscoverRoute.trending => _collectionPage(
        _DiscoverRoute.trending,
        context.l10n.trendingNow,
        context.l10n.trendingDescription,
      ),
      _DiscoverRoute.hot => _collectionPage(
        _DiscoverRoute.hot,
        context.l10n.hotNow,
        context.l10n.hotDescription,
      ),
    },
  );

  Widget _searchPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionEyebrow(context.l10n.officialIndex, color: SkillsTokens.teal),
      const SizedBox(height: 10),
      Text(
        context.l10n.discoverTitle,
        style: TextStyle(
          fontFamily: SkillsTokens.serifFamily,
          fontSize: 38,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 22),
      Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              ActivateIntent(),
        },
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => focusNode.requestFocus(),
            ),
          },
          child: SkillSearchField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: search,
          ),
        ),
      ),
      const SizedBox(height: 22),
      Expanded(child: _body(_DiscoverRoute.search)),
    ],
  );

  Widget _collectionPage(
    _DiscoverRoute route,
    String title,
    String description,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionEyebrow(context.l10n.officialIndex, color: SkillsTokens.teal),
      const SizedBox(height: 10),
      Text(
        title,
        style: const TextStyle(
          fontFamily: SkillsTokens.serifFamily,
          fontSize: 38,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        style: const TextStyle(color: SkillsTokens.textSecondary),
      ),
      const SizedBox(height: 22),
      Expanded(child: _body(route)),
    ],
  );

  Widget _body(_DiscoverRoute route) {
    final state = routeStates[route]!;
    if (state.loading && state.results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.results == null) {
      final copy = _failureCopy(context, state.error!);
      return EmptyState(
        title: copy.title,
        message: copy.message,
        action: ShadButton(
          onPressed: () =>
              _loadRoute(route, reset: true, query: controller.text.trim()),
          child: Text(context.l10n.tryAgain),
        ),
      );
    }
    if (state.results == null) {
      return EmptyState(
        title: context.l10n.searchEmptyTitle,
        message: context.l10n.searchEmptyMessage,
      );
    }
    if (state.results!.isEmpty) {
      return EmptyState(
        title: route == _DiscoverRoute.search
            ? context.l10n.noSkillsTitle
            : context.l10n.collectionEmptyTitle,
        message: route == _DiscoverRoute.search
            ? context.l10n.noSkillsMessage
            : context.l10n.collectionEmptyMessage,
        action: route == _DiscoverRoute.search
            ? ShadButton.outline(
                onPressed: focusNode.requestFocus,
                child: Text(context.l10n.focusSearch),
              )
            : null,
      );
    }
    final showMore = state.nextOffset != null || state.loadingMore;
    return ListView.separated(
      key: ValueKey(
        route == _DiscoverRoute.search
            ? 'discover-results'
            : 'discover-results-${route.name}',
      ),
      controller: state.scrollController,
      itemCount: state.results!.length + (showMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == state.results!.length) {
          if (state.error != null) {
            final copy = _failureCopy(context, state.error!);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    copy.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SkillsTokens.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  ShadButton.outline(
                    onPressed: () => _loadRoute(route, reset: false),
                    child: Text(context.l10n.tryAgain),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: ShadButton.outline(
              enabled: !state.loadingMore,
              onPressed: () => _loadRoute(route, reset: false),
              child: state.loadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.loadMore),
            ),
          );
        }
        final skill = state.results![index];
        final cardFocus = state.focusNodeFor(skill.id);
        return SkillCard(
          skill: skill,
          focusNode: cardFocus,
          onTap: () => _openDetail(skill, cardFocus),
        );
      },
    );
  }

  Future<void> _openDetail(SkillSummary skill, FocusNode cardFocus) async {
    final operation = installOperations.putIfAbsent(
      skill.id,
      _InstallOperation.new,
    );
    final installed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RemoteDetailScreen(
          gateway: widget.gateway,
          skill: skill,
          operation: operation,
        ),
      ),
    );
    if (installed == true) {
      widget.onInstalled();
    } else if (mounted) {
      cardFocus.requestFocus();
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

class _InstallOperation extends ChangeNotifier {
  bool operating = false;
  CommandResult? result;
  bool _disposed = false;

  Future<void> execute(SkillsGateway gateway, SkillSummary skill) async {
    if (operating) return;
    operating = true;
    result = null;
    _notify();
    try {
      result = await gateway.install(skill);
    } catch (caught) {
      result = _exceptionResult(caught);
    } finally {
      operating = false;
      _notify();
    }
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

class _RemoteDetailScreen extends StatefulWidget {
  const _RemoteDetailScreen({
    required this.gateway,
    required this.skill,
    required this.operation,
  });
  final SkillsGateway gateway;
  final SkillSummary skill;
  final _InstallOperation operation;

  @override
  State<_RemoteDetailScreen> createState() => _RemoteDetailScreenState();
}

class _RemoteDetailScreenState extends State<_RemoteDetailScreen> {
  SkillDetail? detail;
  Object? error;
  bool loading = true;
  bool showingManifest = false;
  String? selectedFilePath;
  CliStatus? cliStatus;
  AgentCatalog? agentCatalog;
  bool get operating => widget.operation.operating;
  CommandResult? get result => widget.operation.result;

  @override
  void initState() {
    super.initState();
    widget.operation.addListener(_operationChanged);
    unawaited(load());
  }

  void _operationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.operation.removeListener(_operationChanged);
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
      ]);
      detail = values[0] as SkillDetail;
      cliStatus = values[1] as CliStatus;
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
    if (mounted) setState(() => loading = false);
  }

  Future<void> install() async {
    await widget.operation.execute(widget.gateway, widget.skill);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SkillsTokens.nearBlack,
    body: SafeArea(
      child: Padding(padding: const EdgeInsets.all(28), child: _content()),
    ),
  );

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
                style: const TextStyle(color: SkillsTokens.textSecondary),
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
        action: ShadButton(onPressed: load, child: Text(context.l10n.retry)),
      );
    }
    return _detailBody();
  }

  Widget _detailBody() {
    final value = detail!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShadTooltip(
              builder: (_) => Text(context.l10n.backToSearch),
              child: Semantics(
                label: context.l10n.backToSearch,
                button: true,
                child: ShadButton.ghost(
                  width: 36,
                  height: 36,
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      Navigator.pop(context, result?.succeeded == true),
                  child: const Icon(Icons.arrow_back),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SkillGlyph(name: value.name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.name,
                    style: const TextStyle(
                      fontFamily: SkillsTokens.serifFamily,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${value.source} · ${context.l10n.installs('${value.installs}')}',
                    style: const TextStyle(color: SkillsTokens.textSecondary),
                  ),
                ],
              ),
            ),
            PrimaryCapsuleButton(
              label: widget.skill.isInstalled
                  ? context.l10n.installToMoreTargets
                  : context.l10n.installForCodex,
              onPressed: agentCatalog != null && agentCatalog!.installed.isEmpty
                  ? null
                  : widget.skill.isInstalled
                  ? () => Navigator.pop(context, true)
                  : install,
              busy: operating,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SkillTrustChip(trust: value.trustLevel),
            SkillRiskChip(risk: value.riskAssessment),
            StatusChip(
              label: context.l10n.immutableVersionLabel(value.immutableVersion),
              color: SkillsTokens.blue,
            ),
            StatusChip(
              label: context.l10n.commitIdentity(
                _shortIdentity(value.commitSHA),
              ),
              color: SkillsTokens.textSecondary,
            ),
            StatusChip(
              label: context.l10n.treeIdentity(_shortIdentity(value.treeSHA)),
              color: SkillsTokens.textSecondary,
            ),
            StatusChip(
              label: context.l10n.contentIdentity(
                _shortIdentity(value.contentDigest),
              ),
              color: SkillsTokens.textTertiary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.trustDoesNotProveSafety,
          style: const TextStyle(
            color: SkillsTokens.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
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
                  style: const TextStyle(
                    color: SkillsTokens.textSecondary,
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
                              InstallationScope.user => context.l10n.userScope,
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
          ShadCard(
            width: double.infinity,
            title: Text(context.l10n.noInstalledAgentsTitle),
            description: Text(context.l10n.noInstalledAgentsMessage),
          ),
        ],
        const SizedBox(height: 14),
        _CommandPreview(
          executable: cliStatus?.path ?? context.l10n.cliNotDetected,
          arguments: [
            'add',
            '${widget.skill.source}@${widget.skill.skillId}',
            '--global',
            '--agent',
            'codex',
            '--yes',
          ],
        ),
        if (result != null) ...[
          const SizedBox(height: 14),
          OperationPanel(result: result!),
        ],
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _documentTitle(value),
                        key: const Key('detail-document-title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: SkillsTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _document(value)),
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
                      SectionEyebrow(context.l10n.snapshotFiles),
                      const SizedBox(height: 10),
                      ShadButton.ghost(
                        width: double.infinity,
                        mainAxisAlignment: MainAxisAlignment.start,
                        backgroundColor:
                            !showingManifest && selectedFilePath == null
                            ? SkillsTokens.cardHover
                            : null,
                        onPressed: () => setState(() {
                          showingManifest = false;
                          selectedFilePath = null;
                        }),
                        child: Text(context.l10n.instructionsTab),
                      ),
                      ShadButton.ghost(
                        width: double.infinity,
                        mainAxisAlignment: MainAxisAlignment.start,
                        backgroundColor: showingManifest
                            ? SkillsTokens.cardHover
                            : null,
                        onPressed: () => setState(() {
                          showingManifest = true;
                          selectedFilePath = null;
                        }),
                        child: Text(context.l10n.manifestTab),
                      ),
                      const ShadSeparator.horizontal(
                        color: SkillsTokens.hairline,
                      ),
                      Expanded(
                        child: ListView(
                          children: value.files
                              .map(
                                (file) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: ShadButton.ghost(
                                    width: double.infinity,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    backgroundColor:
                                        selectedFilePath == file.path
                                        ? SkillsTokens.cardHover
                                        : null,
                                    onPressed: () => setState(() {
                                      showingManifest = false;
                                      selectedFilePath = file.path;
                                    }),
                                    leading: Icon(
                                      file.executable
                                          ? Icons.terminal
                                          : file.binary
                                          ? Icons.data_object
                                          : Icons.description_outlined,
                                      size: 15,
                                      color: file.executable
                                          ? SkillsTokens.amber
                                          : SkillsTokens.textTertiary,
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
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _documentTitle(SkillDetail value) {
    if (showingManifest) return context.l10n.manifestTab;
    return selectedFilePath ?? context.l10n.instructionsTab;
  }

  Widget _document(SkillDetail value) {
    if (showingManifest) {
      return SingleChildScrollView(
        child: SelectableText(
          value.manifest,
          key: const Key('detail-manifest'),
          style: const TextStyle(fontFamily: SkillsTokens.monoFamily),
        ),
      );
    }
    if (selectedFilePath == null) {
      return Markdown(
        key: const Key('detail-instructions'),
        data: value.markdown,
        selectable: true,
      );
    }
    final file = value.files.firstWhere(
      (candidate) => candidate.path == selectedFilePath,
    );
    if (file.binary || file.contents.isEmpty) {
      return Center(
        child: Text(
          context.l10n.fileContentUnavailable,
          style: const TextStyle(color: SkillsTokens.textSecondary),
        ),
      );
    }
    final preview = file.path.toLowerCase().endsWith('.md')
        ? Markdown(data: file.contents, selectable: true)
        : SingleChildScrollView(
            child: SelectableText(
              file.contents,
              key: ValueKey('detail-file-${file.path}'),
              style: const TextStyle(fontFamily: SkillsTokens.monoFamily),
            ),
          );
    if (!file.truncated) return preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.fileContentTruncated,
          style: const TextStyle(color: SkillsTokens.amber),
        ),
        const SizedBox(height: 8),
        Expanded(child: preview),
      ],
    );
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
                  style: const TextStyle(
                    color: SkillsTokens.textSecondary,
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

String _shortIdentity(String value) {
  final normalized = value.startsWith('sha256:')
      ? value.substring('sha256:'.length)
      : value;
  return normalized.length <= 12 ? normalized : normalized.substring(0, 12);
}

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
      updates = {
        for (final skill in skills!)
          skill.name: skill.provenance == LibraryProvenance.registry
              ? UpdateState.checking
              : UpdateState.unsupported,
      };
    });
    try {
      updates = await widget.gateway.checkUpdates(skills!);
    } catch (_) {
      updates = {for (final skill in skills!) skill.name: UpdateState.failed};
    }
    if (mounted) setState(() => checking = false);
  }

  Future<void> update(InstalledSkill skill) async {
    if (operatingSkills.contains(skill.name)) return;
    setState(() => operatingSkills.add(skill.name));
    setState(() => result = null);
    try {
      result = await widget.gateway.update(skill);
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (result!.succeeded) {
      await load();
      await checkUpdates();
    }
    if (mounted) setState(() => operatingSkills.remove(skill.name));
  }

  Future<void> remove(InstalledSkill skill) async {
    if (operatingSkills.contains(skill.name)) return;
    final confirmed = await _confirmCommand(
      context,
      title: context.l10n.removeTitle(skill.name),
      description: context.l10n.removeDescription,
      facts: [
        context.l10n.skillFact(skill.name),
        context.l10n.scopeGlobal,
        context.l10n.agentImpactCodex,
      ],
      confirmLabel: context.l10n.removeSkill,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => operatingSkills.add(skill.name));
    try {
      result = await widget.gateway.remove(skill);
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (result!.succeeded) await load();
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
    (skill) => skill.provenance == LibraryProvenance.registry,
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
        const SizedBox(height: 14),
        ShadInput(
          key: const Key('library-search'),
          controller: librarySearchController,
          focusNode: librarySearchFocusNode,
          onChanged: (_) => setState(() {}),
          leading: const Icon(Icons.search, color: SkillsTokens.textSecondary),
          placeholder: Text(context.l10n.searchLibrary),
          placeholderStyle: const TextStyle(color: SkillsTokens.textTertiary),
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
        final state = updates[skill.name] ?? UpdateState.unknown;
        final operating = operatingSkills.contains(skill.name);
        return GlassCard(
          child: Row(
            children: [
              SkillGlyph(name: skill.name),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final removed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => LocalDetailScreen(
                          gateway: widget.gateway,
                          skill: skill,
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
                        style: const TextStyle(
                          fontFamily: SkillsTokens.monoFamily,
                          fontSize: 11,
                          color: SkillsTokens.textSecondary,
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
                        color: SkillsTokens.textSecondary,
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
                            : SkillsTokens.textSecondary,
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
              if (skill.provenance == LibraryProvenance.registry &&
                  state != UpdateState.unknown)
                StatusChip(
                  label: _updateLabel(context, state),
                  color: state == UpdateState.available
                      ? SkillsTokens.orange
                      : SkillsTokens.textSecondary,
                ),
              if (skill.provenance == LibraryProvenance.registry &&
                  state == UpdateState.available) ...[
                const SizedBox(width: 8),
                SecondaryCapsuleButton(
                  label: context.l10n.update,
                  onPressed: operating ? null : () => update(skill),
                ),
              ],
              if (skill.provenance != LibraryProvenance.external) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: context.l10n.removeNamed(skill.name),
                  onPressed: operating ? null : () => remove(skill),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: SkillsTokens.textSecondary,
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
  SkillDetail? detail;
  Object? error;
  String? selectedFilePath;
  bool removing = false;
  CommandResult? result;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      error = null;
      selectedFilePath = null;
    });
    try {
      detail = await widget.gateway.loadLocalDetail(widget.skill);
    } catch (caught) {
      error = caught;
    }
    if (mounted) setState(() {});
  }

  Future<void> remove() async {
    final confirmed = await _confirmCommand(
      context,
      title: context.l10n.removeTitle(widget.skill.name),
      description: context.l10n.removeDescription,
      facts: [
        context.l10n.skillFact(widget.skill.name),
        context.l10n.scopeGlobal,
        context.l10n.agentImpactCodex,
      ],
      confirmLabel: context.l10n.removeSkill,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => removing = true);
    try {
      result = await widget.gateway.remove(widget.skill);
    } catch (caught) {
      result = _exceptionResult(caught);
    }
    if (!mounted) return;
    setState(() => removing = false);
    if (result!.succeeded) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SkillsTokens.nearBlack,
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
                SkillGlyph(name: widget.skill.name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.skill.name,
                        style: const TextStyle(
                          fontFamily: SkillsTokens.serifFamily,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SelectableText(
                        widget.skill.path,
                        style: const TextStyle(
                          fontFamily: SkillsTokens.monoFamily,
                          color: SkillsTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _libraryProvenanceChip(context, widget.skill.provenance),
                const SizedBox(width: 8),
                SkillRiskChip(risk: widget.skill.riskAssessment),
                const SizedBox(width: 8),
                if (widget.skill.provenance == LibraryProvenance.external)
                  StatusChip(
                    label: context.l10n.readOnly,
                    color: SkillsTokens.textSecondary,
                  )
                else
                  SecondaryCapsuleButton(
                    label: context.l10n.remove,
                    icon: Icons.delete_outline,
                    onPressed: removing ? null : remove,
                  ),
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
                  _InstallationTargetsPanel(skill: widget.skill),
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
            const ShadSeparator.horizontal(color: SkillsTokens.hairline),
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
                      style: const TextStyle(
                        fontFamily: SkillsTokens.monoFamily,
                        fontSize: 11,
                        color: SkillsTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusChip(
                label: _installationModeLabel(context, target.mode),
                color: SkillsTokens.textSecondary,
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
                ShadButton.ghost(
                  width: double.infinity,
                  mainAxisAlignment: MainAxisAlignment.start,
                  backgroundColor: selectedFilePath == null
                      ? SkillsTokens.cardHover
                      : null,
                  onPressed: () => onSelected(null),
                  child: Text(context.l10n.instructionsTab),
                ),
                const ShadSeparator.horizontal(color: SkillsTokens.hairline),
                Expanded(
                  child: ListView(
                    children: supportingFiles
                        .map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ShadButton.ghost(
                              width: double.infinity,
                              mainAxisAlignment: MainAxisAlignment.start,
                              backgroundColor: selectedFilePath == file.path
                                  ? SkillsTokens.cardHover
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
                                    : SkillsTokens.textTertiary,
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
      return Markdown(data: detail.markdown, selectable: true);
    }
    final file = detail.files.firstWhere(
      (candidate) => candidate.path == selectedFilePath,
    );
    if (file.binary || file.contents.isEmpty) {
      return Center(
        child: Text(
          context.l10n.fileContentUnavailable,
          style: const TextStyle(color: SkillsTokens.textSecondary),
        ),
      );
    }
    final content = file.path.toLowerCase().endsWith('.md')
        ? Markdown(data: file.contents, selectable: true)
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
  registry,
  installationPolicy,
  storage,
  about,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.gateway});
  final SkillsGateway gateway;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final controller = TextEditingController();
  final registryController = TextEditingController();
  final scrollController = ScrollController();
  _SettingsRoute selectedRoute = _SettingsRoute.general;
  CliStatus? status;
  RegistryStatus? registryStatus;
  PersonalRiskPolicy? riskPolicy;
  StorageStatus? storageStatus;
  String? appVersion;
  bool detecting = true;
  bool loadingSettings = true;
  bool testingRegistry = false;
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
      widget.gateway.loadRegistryOrigin(),
      widget.gateway.loadRiskPolicy(),
      widget.gateway.loadAppVersion(),
    ]);
    if (!mounted) return;
    registryController.text = values[0] as String;
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

  Future<RegistryStatus?> testRegistry() async {
    if (!mounted) return null;
    final origin = registryController.text;
    setState(() {
      testingRegistry = true;
      notice = null;
    });
    RegistryStatus tested;
    try {
      tested = await widget.gateway.testRegistryOrigin(origin);
    } on Object catch (error) {
      tested = RegistryStatus(
        origin: origin,
        state: HealthState.unreachable,
        issue: RegistryIssue.connectionFailure,
        diagnostic: error.toString(),
      );
    } finally {
      if (mounted) setState(() => testingRegistry = false);
    }
    if (!mounted) return null;
    setState(() => registryStatus = tested);
    return tested;
  }

  Future<void> saveRegistry() async {
    try {
      final tested = await testRegistry();
      if (!mounted || tested?.isReady != true) return;
      await widget.gateway.saveRegistryOrigin(registryController.text);
      final savedOrigin = await widget.gateway.loadRegistryOrigin();
      if (!mounted) return;
      registryController.text = savedOrigin;
      setState(() => notice = context.l10n.registryOriginSaved);
    } on FormatException catch (error) {
      if (mounted) {
        setState(
          () => registryStatus = RegistryStatus(
            origin: registryController.text,
            state: HealthState.invalid,
            issue: RegistryIssue.invalidOrigin,
            diagnostic: error.message,
          ),
        );
      }
    }
  }

  Future<void> resetRegistry() async {
    await widget.gateway.resetRegistryOrigin();
    if (!mounted) return;
    final defaultOrigin = await widget.gateway.loadRegistryOrigin();
    if (!mounted) return;
    registryController.text = defaultOrigin;
    await testRegistry();
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

  @override
  void dispose() {
    controller.dispose();
    registryController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SkillsDestinationLayout(
    rail: SkillsSideRail<_SettingsRoute>(
      semanticLabel: context.l10n.settingsNavigation,
      selected: selectedRoute,
      onSelected: (route) => setState(() => selectedRoute = route),
      items: [
        SkillsRailItem(
          value: _SettingsRoute.general,
          label: context.l10n.general,
        ),
        SkillsRailItem(
          value: _SettingsRoute.agents,
          label: context.l10n.agents,
        ),
        SkillsRailItem(
          value: _SettingsRoute.registry,
          label: context.l10n.registry,
        ),
        SkillsRailItem(
          value: _SettingsRoute.installationPolicy,
          label: context.l10n.installationPolicy,
        ),
        SkillsRailItem(
          value: _SettingsRoute.storage,
          label: context.l10n.storage,
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
        _SettingsRoute.registry => _registrySettings(),
        _SettingsRoute.installationPolicy => _policySettings(),
        _SettingsRoute.storage => _storageSettings(),
        _SettingsRoute.about => _aboutSettings(),
      },
    ],
  );

  String _routeTitle() => switch (selectedRoute) {
    _SettingsRoute.general => context.l10n.general,
    _SettingsRoute.agents => context.l10n.agents,
    _SettingsRoute.registry => context.l10n.registry,
    _SettingsRoute.installationPolicy => context.l10n.installationPolicy,
    _SettingsRoute.storage => context.l10n.storage,
    _SettingsRoute.about => context.l10n.about,
  };

  Widget _generalSettings() => ShadCard(
    width: double.infinity,
    title: Text(context.l10n.generalSettingsTitle),
    description: Text(context.l10n.generalSettingsDescription),
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        context.l10n.privacySummary,
        style: const TextStyle(color: SkillsTokens.textSecondary, height: 1.5),
      ),
    ),
  );

  Widget _agentSettings() {
    final cliCard = ShadCard(
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
              ShadInput(
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
                  ShadButton(
                    enabled: !detecting,
                    onPressed: save,
                    child: Text(context.l10n.saveAndDetect),
                  ),
                ShadButton.outline(
                  enabled: !detecting,
                  onPressed: detect,
                  child: Text(context.l10n.detectAgain),
                ),
                if (!kReleaseMode)
                  ShadButton.outline(
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
          ShadCard(
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
    return ShadCard(
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
                const ShadSeparator.horizontal(color: SkillsTokens.hairline),
            ],
          ],
        ),
      ),
    );
  }

  Widget _registrySettings() => ShadCard(
    width: double.infinity,
    title: Text(context.l10n.registrySettingsTitle),
    description: Text(context.l10n.registrySettingsDescription),
    child: Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            key: const Key('registry-origin'),
            controller: registryController,
            placeholder: const Text('https://registry.example.com'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ShadButton(
                enabled: !testingRegistry,
                onPressed: saveRegistry,
                child: Text(context.l10n.saveOrigin),
              ),
              ShadButton.outline(
                enabled: !testingRegistry,
                onPressed: testRegistry,
                child: Text(context.l10n.testConnection),
              ),
              ShadButton.outline(
                enabled: !testingRegistry,
                onPressed: resetRegistry,
                child: Text(context.l10n.resetDefault),
              ),
            ],
          ),
          if (registryStatus != null) ...[
            const SizedBox(height: 14),
            Text(
              registryStatus!.isReady
                  ? context.l10n.connectionReady
                  : '${context.l10n.connectionFailed}: ${_registryStatusMessage(context, registryStatus!)}',
              style: TextStyle(
                color: registryStatus!.isReady
                    ? SkillsTokens.green
                    : SkillsTokens.amber,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _policySettings() => ShadCard(
    width: double.infinity,
    title: Text(context.l10n.riskPolicyTitle),
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          ShadSwitch(
            value: true,
            enabled: false,
            label: Text(context.l10n.confirmHighRisk),
            sublabel: Text(context.l10n.confirmHighRiskDescription),
          ),
          const SizedBox(height: 14),
          ShadSwitch(
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
    return ShadCard(
      width: double.infinity,
      title: Text(context.l10n.storageSettingsTitle),
      description: Text(
        storage.path.isEmpty
            ? context.l10n.storagePathUnavailable
            : storage.path,
      ),
      footer: ShadButton.outline(
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

  Widget _aboutSettings() => ShadCard(
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
              style: const TextStyle(color: SkillsTokens.textSecondary),
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
                  : SkillsTokens.textTertiary,
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
          style: const TextStyle(
            color: SkillsTokens.textSecondary,
            height: 1.4,
          ),
        ),
        if (status.userTarget != null) ...[
          const SizedBox(height: 5),
          SelectableText(
            context.l10n.agentUserTarget(status.userTarget!.path),
            style: const TextStyle(
              fontFamily: SkillsTokens.monoFamily,
              fontSize: 11,
              color: SkillsTokens.textTertiary,
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
  Widget build(BuildContext context) => ExpansionTile(
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

class _CommandPreview extends StatelessWidget {
  const _CommandPreview({required this.executable, required this.arguments});
  final String executable;
  final List<String> arguments;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        SectionEyebrow(context.l10n.command),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            [executable, ...arguments].join(' '),
            maxLines: 2,
            style: const TextStyle(
              fontFamily: SkillsTokens.monoFamily,
              fontSize: 11,
              color: SkillsTokens.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
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
                    style: const TextStyle(
                      fontFamily: SkillsTokens.monoFamily,
                      color: SkillsTokens.textSecondary,
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

CommandResult _exceptionResult(Object error) => CommandResult(
  command: const ['skills'],
  output: ProcessOutput(exitCode: 1, stdout: '', stderr: error.toString()),
);

String _updateLabel(BuildContext context, UpdateState state) => switch (state) {
  UpdateState.unknown => context.l10n.updateUnknown,
  UpdateState.checking => context.l10n.updateChecking,
  UpdateState.upToDate => context.l10n.upToDate,
  UpdateState.available => context.l10n.updateAvailable,
  UpdateState.unsupported => context.l10n.updateUnavailable,
  UpdateState.failed => context.l10n.updateCheckFailed,
};

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
    LibraryProvenance.registry => (
      label: context.l10n.registryManaged,
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

String _registryStatusMessage(BuildContext context, RegistryStatus status) =>
    switch (status.issue) {
      RegistryIssue.invalidOrigin => context.l10n.registryInvalidOrigin,
      RegistryIssue.httpFailure => context.l10n.registryHttpFailure(
        status.httpStatus ?? 0,
      ),
      RegistryIssue.invalidProtocol => context.l10n.registryInvalidProtocol,
      RegistryIssue.invalidJson => context.l10n.registryInvalidJson,
      RegistryIssue.connectionFailure => context.l10n.registryConnectionFailure,
      RegistryIssue.timeout => context.l10n.registryConnectionTimeout,
      null => context.l10n.registryInvalidProtocol,
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
