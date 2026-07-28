/*
 * [INPUT]: Depends on SkillsGateway recent/live diagnostic entries, localized copy, native SkillsGo controls, Flutter scrolling/search and per-entry text selection, and theme semantics.
 * [OUTPUT]: Provides the Advanced Settings newest-first live diagnostic-log child page with level/search filtering, pause/follow behavior, local clear, bounded rendering, and mutation-safe per-entry copying.
 * [POS]: Serves as the human-readable real-time App log viewer without parsing or tailing persisted files.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../settings_screen.dart';

extension _DiagnosticLogViewerRoute on _SettingsScreenState {
  Widget _diagnosticLogViewer() => _DiagnosticLogViewer(
    gateway: widget.gateway,
    onBack: () => updateState(() => showingDiagnosticLogs = false),
  );
}

enum _DiagnosticLevelFilter { all, warning, error }

class _DiagnosticLogViewer extends StatefulWidget {
  const _DiagnosticLogViewer({required this.gateway, required this.onBack});

  final SkillsGateway gateway;
  final VoidCallback onBack;

  @override
  State<_DiagnosticLogViewer> createState() => _DiagnosticLogViewerState();
}

class _DiagnosticLogViewerState extends State<_DiagnosticLogViewer> {
  static const _maximumEntries = 2000;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late final StreamSubscription<DiagnosticLogEntry> _subscription;
  late final List<DiagnosticLogEntry> _entries;
  _DiagnosticLevelFilter _filter = _DiagnosticLevelFilter.all;
  bool _paused = false;
  bool _following = true;

  @override
  void initState() {
    super.initState();
    _entries = widget.gateway.recentDiagnosticLogs().toList();
    _subscription = widget.gateway.watchDiagnosticLogs().listen(_append);
    _scrollController.addListener(_updateFollowing);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _scrollController
      ..removeListener(_updateFollowing)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _append(DiagnosticLogEntry entry) {
    if (!mounted) return;
    final shouldFollow = !_paused && _following;
    setState(() {
      _entries.add(entry);
      if (_entries.length > _maximumEntries) {
        _entries.removeRange(0, _entries.length - _maximumEntries);
      }
    });
    if (shouldFollow) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  void _updateFollowing() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final following = position.pixels - position.minScrollExtent < 48;
    if (following != _following && mounted) {
      setState(() => _following = following);
    }
  }

  void _scrollToLatest() {
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
    if (!_following) setState(() => _following = true);
  }

  void _togglePaused() {
    setState(() => _paused = !_paused);
    if (!_paused) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  List<DiagnosticLogEntry> get _visibleEntries {
    final query = _searchController.text.trim().toLowerCase();
    return _entries.reversed
        .where((entry) {
          final matchesLevel = switch (_filter) {
            _DiagnosticLevelFilter.all => true,
            _DiagnosticLevelFilter.warning =>
              entry.level == DiagnosticLogLevel.warning ||
                  entry.level == DiagnosticLogLevel.error,
            _DiagnosticLevelFilter.error =>
              entry.level == DiagnosticLogLevel.error,
          };
          return matchesLevel &&
              (query.isEmpty || entry.formatted.toLowerCase().contains(query));
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SkillsButton.ghost(
              key: const Key('close-diagnostic-log-viewer'),
              onPressed: widget.onBack,
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                size: 16,
                color: scheme.onSurface,
              ),
              child: Text(context.l10n.onboardingBack),
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.diagnosticLogsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 12),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _paused
                    ? scheme.onSurfaceVariant
                    : context.skillsComponents.statusSuccess,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              _paused
                  ? context.l10n.logViewerPaused
                  : context.l10n.logViewerLive,
              style: context.skillsTypography.bodySecondary,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('diagnostic-log-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.l10n.searchLogs,
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            DiscreteTabs(
              key: const Key('diagnostic-log-level-filter'),
              currentIndex: _filter.index,
              onSelect: (index) => setState(
                () => _filter = _DiagnosticLevelFilter.values[index],
              ),
              tabs: [
                DiscreteTab(
                  label: context.l10n.allLogLevels,
                  icon: HugeIcons.strokeRoundedLayers01,
                  activeColor: scheme.onPrimaryContainer,
                ),
                DiscreteTab(
                  label: context.l10n.warningLogs,
                  icon: HugeIcons.strokeRoundedAlert02,
                  activeColor: scheme.onPrimaryContainer,
                ),
                DiscreteTab(
                  label: context.l10n.errorLogs,
                  icon: HugeIcons.strokeRoundedCancelCircle,
                  activeColor: scheme.onPrimaryContainer,
                ),
              ],
              style: DiscreteTabsStyle(
                height: 36,
                horizontalPadding: 8,
                selectedScale: 1,
                selectedLabelWeight: FontWeight.w500,
                backgroundColor: scheme.surfaceContainerHigh,
                activeBackgroundColor: scheme.primaryContainer,
                inactiveIconColor: scheme.onSurfaceVariant,
                shadowColor: Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            SkillsButton.outline(
              key: const Key('pause-diagnostic-logs'),
              onPressed: _togglePaused,
              child: Text(
                _paused
                    ? context.l10n.resumeLogFollow
                    : context.l10n.pauseLogFollow,
              ),
            ),
            const SizedBox(width: 8),
            SkillsButton.outline(
              key: const Key('clear-diagnostic-log-viewer'),
              onPressed: _entries.isEmpty
                  ? null
                  : () => setState(() => _entries.clear()),
              child: Text(context.l10n.clearViewer),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Stack(
              children: [
                if (visible.isEmpty)
                  Center(child: Text(context.l10n.noDiagnosticLogs))
                else
                  ListView.separated(
                    key: const Key('diagnostic-log-list'),
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _logEntry(visible[index]),
                  ),
                if (!_following && visible.isNotEmpty)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: SkillsButton(
                      key: const Key('diagnostic-log-latest'),
                      onPressed: _scrollToLatest,
                      child: Text(context.l10n.backToLatestLog),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _logEntry(DiagnosticLogEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (entry.level) {
      DiagnosticLogLevel.error => scheme.error,
      DiagnosticLogLevel.warning => context.skillsComponents.statusAttention,
      _ => scheme.onSurface,
    };
    return SelectableText(
      key: ValueKey(entry),
      entry.formatted,
      style: TextStyle(
        color: color,
        fontFamily: 'monospace',
        fontSize: 12.5,
        height: 1.45,
      ),
    );
  }
}
