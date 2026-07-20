/*
 * [INPUT]: Depends on Discover route state, scroll notifications, pagination callbacks, and desktop scrollbar primitives.
 * [OUTPUT]: Provides the desktop Discover scroller with underfilled-page pagination and stable scroll restoration.
 * [POS]: Serves as the scrolling and pagination segment of the Discover journey.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../discover_screen.dart';

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
