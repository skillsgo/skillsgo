/*
 * [INPUT]: Depends on SkillsGateway contracts, localized copy, shadcn_ui primitives, stateful nested navigation, and SkillsPlay brand tokens.
 * [OUTPUT]: Provides the desktop shell plus persistent Discover, Library, detail, operation, and operational Settings journeys.
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
              'SkillsPlay',
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
  final scrollController = ScrollController();
  final installOperations = <String, _InstallOperation>{};
  _DiscoverRoute selectedRoute = _DiscoverRoute.search;
  List<SkillSummary>? results;
  Object? error;
  bool loading = false;
  int searchGeneration = 0;

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
      setState(() {
        results = null;
        error = null;
        loading = false;
      });
      return;
    }
    final generation = ++searchGeneration;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final found = await widget.gateway.search(query);
      if (!mounted || generation != searchGeneration) return;
      setState(() => results = found);
    } catch (caught) {
      if (!mounted || generation != searchGeneration) return;
      setState(() => error = caught);
    } finally {
      if (mounted && generation == searchGeneration) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    scrollController.dispose();
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
      onSelected: (route) => setState(() => selectedRoute = route),
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
      _DiscoverRoute.ranking => _collectionPage(context.l10n.allTimeRanking),
      _DiscoverRoute.trending => _collectionPage(context.l10n.trendingNow),
      _DiscoverRoute.hot => _collectionPage(context.l10n.hotNow),
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
      Expanded(child: _body()),
    ],
  );

  Widget _collectionPage(String title) => Column(
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
      const SizedBox(height: 22),
      Expanded(
        child: EmptyState(
          title: title,
          message: context.l10n.collectionComingSoon,
        ),
      ),
    ],
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return EmptyState(
        title: error is SkillsException && (error! as SkillsException).isOffline
            ? context.l10n.offlineTitle
            : context.l10n.searchFailedTitle,
        message: error.toString(),
        action: PrimaryCapsuleButton(
          label: context.l10n.tryAgain,
          onPressed: search,
        ),
      );
    }
    if (results == null) {
      return EmptyState(
        title: context.l10n.searchEmptyTitle,
        message: context.l10n.searchEmptyMessage,
      );
    }
    if (results!.isEmpty) {
      return EmptyState(
        title: context.l10n.noSkillsTitle,
        message: context.l10n.noSkillsMessage,
        action: SecondaryCapsuleButton(
          label: context.l10n.focusSearch,
          onPressed: focusNode.requestFocus,
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('discover-results'),
      controller: scrollController,
      itemCount: results!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final skill = results![index];
        return SkillCard(skill: skill, onTap: () => _openDetail(skill));
      },
    );
  }

  Future<void> _openDetail(SkillSummary skill) async {
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
    if (installed == true) widget.onInstalled();
  }
}

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
  CliStatus? cliStatus;
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? EmptyState(
                title: context.l10n.detailFailedTitle,
                message: error.toString(),
                action: PrimaryCapsuleButton(
                  label: context.l10n.retry,
                  onPressed: load,
                ),
              )
            : _detailBody(),
      ),
    ),
  );

  Widget _detailBody() {
    final value = detail!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.l10n.backToSearch,
              onPressed: () =>
                  Navigator.pop(context, result?.succeeded == true),
              icon: const Icon(Icons.arrow_back),
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
              label: context.l10n.installForCodex,
              onPressed: install,
              busy: operating,
            ),
          ],
        ),
        if (value.hasExecutableContent) ...[
          const SizedBox(height: 18),
          const _RiskNotice(),
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
                  child: Markdown(
                    data: value.markdown,
                    selectable: true,
                    shrinkWrap: false,
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
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView(
                          children: value.files
                              .map(
                                (file) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SelectableText(
                                    file.path,
                                    style: const TextStyle(
                                      fontFamily: SkillsTokens.monoFamily,
                                      fontSize: 12,
                                      color: SkillsTokens.textSecondary,
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
}

class _RiskNotice extends StatelessWidget {
  const _RiskNotice();
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
          child: Text(
            context.l10n.executableRisk,
            style: const TextStyle(color: SkillsTokens.amber),
          ),
        ),
      ],
    ),
  );
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
  Object? error;
  bool loading = true;
  bool checking = false;
  Map<String, UpdateState> updates = const {};
  CommandResult? result;
  final operatingSkills = <String>{};
  final scrollController = ScrollController();
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
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      skills = await widget.gateway.listInstalled();
      if (selectedRoute.startsWith('agent:')) {
        final selectedAgent = selectedRoute.substring('agent:'.length);
        if (!_agents.contains(selectedAgent)) selectedRoute = _allRoute;
      }
    } catch (caught) {
      error = caught;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> checkUpdates() async {
    if (skills == null || checking) return;
    setState(() {
      checking = true;
      updates = {for (final skill in skills!) skill.name: UpdateState.checking};
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
        (skills ?? const <InstalledSkill>[])
            .expand((skill) => skill.agents)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  String _agentLabel(String agent) => agent
      .split(RegExp(r'[-_]'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  List<SkillsRailItem<String>> _railItems(BuildContext context) => [
    SkillsRailItem(value: _allRoute, label: context.l10n.all),
    SkillsRailItem(value: _userRoute, label: context.l10n.userScope),
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
    if (selectedRoute == _addProjectRoute) return context.l10n.addProject;
    return _agentLabel(selectedRoute.substring('agent:'.length));
  }

  List<InstalledSkill> get _visibleSkills {
    final current = skills ?? const <InstalledSkill>[];
    if (!selectedRoute.startsWith('agent:')) return current;
    final agent = selectedRoute.substring('agent:'.length);
    return current.where((skill) => skill.agents.contains(agent)).toList();
  }

  @override
  Widget build(BuildContext context) => SkillsDestinationLayout(
    rail: SkillsSideRail<String>(
      semanticLabel: context.l10n.libraryNavigation,
      selected: selectedRoute,
      onSelected: (route) => setState(() => selectedRoute = route),
      items: _railItems(context),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
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
            const Spacer(),
            SecondaryCapsuleButton(
              label: checking
                  ? context.l10n.checking
                  : context.l10n.checkUpdates,
              icon: Icons.sync,
              onPressed: checking ? null : checkUpdates,
            ),
            const SizedBox(width: 10),
            SecondaryCapsuleButton(
              label: context.l10n.refresh,
              icon: Icons.refresh,
              onPressed: loading ? null : load,
            ),
          ],
        ),
        if (result != null) ...[
          const SizedBox(height: 14),
          OperationPanel(result: result!),
        ],
        const SizedBox(height: 20),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return EmptyState(
        title: context.l10n.libraryUnavailable,
        message: error.toString(),
        action: PrimaryCapsuleButton(
          label: context.l10n.retry,
          onPressed: load,
        ),
      );
    }
    if (_visibleSkills.isEmpty) {
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
                        skill.path,
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
              StatusChip(
                label: skill.isLinkedToCodex ? 'CODEX' : context.l10n.notLinked,
                color: skill.isLinkedToCodex
                    ? SkillsTokens.green
                    : SkillsTokens.amber,
              ),
              const SizedBox(width: 8),
              if (state != UpdateState.unknown)
                StatusChip(
                  label: _updateLabel(context, state),
                  color: state == UpdateState.available
                      ? SkillsTokens.orange
                      : SkillsTokens.textSecondary,
                ),
              if (state == UpdateState.available) ...[
                const SizedBox(width: 8),
                SecondaryCapsuleButton(
                  label: context.l10n.update,
                  onPressed: operating ? null : () => update(skill),
                ),
              ],
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
  bool removing = false;
  CommandResult? result;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() => error = null);
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
              child: error != null
                  ? EmptyState(
                      title: context.l10n.localReadFailed,
                      message: error.toString(),
                      action: PrimaryCapsuleButton(
                        label: context.l10n.retry,
                        onPressed: load,
                      ),
                    )
                  : detail == null
                  ? const Center(child: CircularProgressIndicator())
                  : GlassCard(
                      child: Markdown(data: detail!.markdown, selectable: true),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
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
    if (!mounted) return;
    setState(() {
      status = detected;
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

  Widget _agentSettings() => ShadCard(
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
    child: !kReleaseMode
        ? Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShadInput(
                  key: const Key('cli-path'),
                  controller: controller,
                  placeholder: const Text('/path/to/development/skillsgo'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
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
                    ShadButton.outline(
                      enabled: !detecting,
                      onPressed: clear,
                      child: Text(context.l10n.clearCustomPath),
                    ),
                  ],
                ),
              ],
            ),
          )
        : null,
  );

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
