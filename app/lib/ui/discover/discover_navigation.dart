/*
 * [INPUT]: Depends on Discover route state, localized collection labels, tab animation, and shared status panels.
 * [OUTPUT]: Provides leaderboard tabs, header reveal, route status panels, and route-local UI state.
 * [POS]: Serves as the navigation and status presentation segment of the Discover journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../discover_screen.dart';

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

    final indicatorStart = interpolate(offsets, _position.value);
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
            PositionedDirectional(
              key: const Key('discover-tab-indicator'),
              start: indicatorStart,
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
