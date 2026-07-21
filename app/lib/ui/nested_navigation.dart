/*
 * [INPUT]: Receives localized fixed and scrollable rail items with optional exact count badges, standard or compact density, selected values, destination content, an optional destination-wide foreground, optional transition identity, SkillsGo component tokens, and reduced-motion preferences.
 * [OUTPUT]: Renders the shared desktop rail/content layout with optional short depth entrance and a destination-wide foreground layer, plus the theme-tinted glass side rail with accessible density-aware selection motion and counts, optional fixed leading destinations and section dividers, an independently scrollable item region with one slim desktop scrollbar, and an optional pinned footer action.
 * [POS]: Defines the reusable nested-navigation surface shared by Discover, Library, and Settings.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:hugeicons/hugeicons.dart';

import 'brand.dart';

part 'navigation/rail_button.dart';

const _standardRailItemExtent = 44.0;
const _compactRailItemExtent = 38.0;

class SkillsRailItem<T> {
  const SkillsRailItem({
    required this.value,
    required this.label,
    this.compact = false,
    this.icon,
    this.leading,
    this.count,
    this.countLabel,
  });

  final T value;
  final String label;
  final bool compact;
  final List<List<dynamic>>? icon;
  final Widget? leading;
  final int? count;
  final String? countLabel;
}

class SkillsDestinationLayout extends StatefulWidget {
  const SkillsDestinationLayout({
    super.key,
    required this.rail,
    required this.child,
    this.foreground,
    this.bodyTransitionKey,
  });

  final Widget rail;
  final Widget child;
  final Widget? foreground;
  final Object? bodyTransitionKey;

  @override
  State<SkillsDestinationLayout> createState() =>
      _SkillsDestinationLayoutState();
}

class _SkillsDestinationLayoutState extends State<SkillsDestinationLayout>
    with SingleTickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 180);
  late final AnimationController _bodyEntrance;

  @override
  void initState() {
    super.initState();
    _bodyEntrance = AnimationController(
      vsync: this,
      duration: _transitionDuration,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant SkillsDestinationLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bodyTransitionKey == null ||
        oldWidget.bodyTransitionKey == widget.bodyTransitionKey) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _bodyEntrance.value = 1;
      return;
    }
    _bodyEntrance.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _bodyEntrance.value = 1;
    }
  }

  @override
  void dispose() {
    _bodyEntrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 26, 28, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 184, child: widget.rail),
              const SizedBox(width: 24),
              Expanded(child: body),
            ],
          ),
        ),
        if (widget.foreground case final foreground?)
          Positioned.fill(child: foreground),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.bodyTransitionKey == null ||
        MediaQuery.disableAnimationsOf(context)) {
      return KeyedSubtree(
        key: const Key('skills-destination-body'),
        child: widget.child,
      );
    }
    final curved = CurvedAnimation(
      parent: _bodyEntrance,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      key: const Key('skills-destination-body'),
      opacity: Tween<double>(begin: .86, end: 1).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .012),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: .985, end: 1).animate(curved),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class SkillsSideRail<T> extends StatefulWidget {
  const SkillsSideRail({
    super.key,
    required this.semanticLabel,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.fixedItems = const [],
    this.sectionDividers = false,
    this.header,
    this.footer,
  });

  final String semanticLabel;
  final List<SkillsRailItem<T>> fixedItems;
  final List<SkillsRailItem<T>> items;
  final bool sectionDividers;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Widget? header;
  final Widget? footer;

  @override
  State<SkillsSideRail<T>> createState() => _SkillsSideRailState<T>();
}

class _SkillsSideRailState<T> extends State<SkillsSideRail<T>>
    with SingleTickerProviderStateMixin {
  static const _sectionDividerExtent = 12.0;
  late final AnimationController _position;
  final _scrollController = ScrollController();
  final _focusNodes = <T, FocusNode>{};

  FocusNode _focusNode(T value) => _focusNodes.putIfAbsent(
    value,
    () => FocusNode(debugLabel: 'Skills rail: $value'),
  );

  List<SkillsRailItem<T>> get _allItems => [
    ...widget.fixedItems,
    ...widget.items,
  ];

  int get _selectedIndex =>
      _allItems.indexWhere((item) => item.value == widget.selected);

  @override
  void initState() {
    super.initState();
    final selectedIndex = _selectedIndex;
    _position = AnimationController.unbounded(
      vsync: this,
      value: selectedIndex < 0 ? 0 : selectedIndex.toDouble(),
    )..addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant SkillsSideRail<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentValues = _allItems.map((item) => item.value).toSet();
    var restoreFocus = false;
    for (final value
        in _focusNodes.keys
            .where((value) => !currentValues.contains(value))
            .toList()) {
      final node = _focusNodes.remove(value)!;
      restoreFocus = restoreFocus || node.hasFocus;
      node.dispose();
    }
    if (restoreFocus && _selectedIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode(widget.selected as T).requestFocus();
      });
    }
    if (_selectedIndex < 0) return;
    final target = _selectedIndex.toDouble();
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
    _position
      ..removeListener(_rebuild)
      ..dispose();
    _scrollController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final components = context.skillsComponents;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3D000000),
              blurRadius: 32,
              spreadRadius: -6,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: components.navigationRest.withValues(alpha: .88),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    if (widget.header != null) ...[
                      widget.header!,
                      const SizedBox(height: 8),
                    ],
                    Expanded(
                      child: FocusTraversalGroup(
                        policy: OrderedTraversalPolicy(),
                        child: Column(
                          children: [
                            if (widget.fixedItems.isNotEmpty)
                              SizedBox(
                                height: _contentHeight(widget.fixedItems),
                                child: _itemStack(
                                  context,
                                  items: widget.fixedItems,
                                  globalOffset: 0,
                                ),
                              ),
                            if (widget.sectionDividers &&
                                widget.fixedItems.isNotEmpty)
                              _sectionDivider(
                                context,
                                key: const ValueKey('side-rail-header-divider'),
                              ),
                            Expanded(
                              child: Scrollbar(
                                key: const ValueKey('side-rail-scrollbar'),
                                controller: _scrollController,
                                thumbVisibility: widget.items.length > 10,
                                thickness: 2,
                                radius: const Radius.circular(999),
                                child: ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(
                                    context,
                                  ).copyWith(scrollbars: false),
                                  child: SingleChildScrollView(
                                    key: const ValueKey('side-rail-scroll'),
                                    controller: _scrollController,
                                    child: SizedBox(
                                      height: _contentHeight(widget.items),
                                      child: _itemStack(
                                        context,
                                        items: widget.items,
                                        globalOffset: widget.fixedItems.length,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.footer != null) ...[
                      if (widget.sectionDividers)
                        _sectionDivider(
                          context,
                          key: const ValueKey('side-rail-footer-divider'),
                        )
                      else
                        const SizedBox(height: 8),
                      widget.footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemStack(
    BuildContext context, {
    required List<SkillsRailItem<T>> items,
    required int globalOffset,
  }) {
    final components = context.skillsComponents;
    final selectedInSection =
        _selectedIndex >= globalOffset &&
        _selectedIndex < globalOffset + items.length;
    final selectedItem = selectedInSection
        ? items[_selectedIndex - globalOffset]
        : null;
    final compactSelection = selectedItem?.compact ?? false;
    return Stack(
      children: [
        if (selectedInSection)
          Positioned(
            key: const ValueKey('rail-indicator'),
            left: compactSelection ? 4 : 0,
            right: compactSelection ? 4 : 0,
            top: _animatedItemTop(items, _position.value - globalOffset) + 2,
            height: _itemExtent(selectedItem!) - 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: components.navigationSelected,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                boxShadow: [
                  BoxShadow(
                    color: compactSelection
                        ? const Color(0x1F000000)
                        : const Color(0x29000000),
                    blurRadius: compactSelection ? 4 : 6,
                    offset: Offset(0, compactSelection ? 1 : 2),
                  ),
                ],
              ),
            ),
          ),
        for (var index = 0; index < items.length; index++)
          Positioned(
            left: 0,
            right: 0,
            top: _itemTop(items, index),
            height: _itemExtent(items[index]),
            child: _RailButton<T>(
              item: items[index],
              focusNode: _focusNode(items[index].value),
              selected: items[index].value == widget.selected,
              onPressed: () => widget.onSelected(items[index].value),
            ),
          ),
      ],
    );
  }

  double _contentHeight(List<SkillsRailItem<T>> items) =>
      items.fold<double>(0, (height, item) => height + _itemExtent(item));

  Widget _sectionDivider(BuildContext context, {required Key key}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Divider(
      key: key,
      height: _sectionDividerExtent,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .1),
    ),
  );

  double _itemExtent(SkillsRailItem<T> item) =>
      item.compact ? _compactRailItemExtent : _standardRailItemExtent;

  double _itemTop(List<SkillsRailItem<T>> items, int index) {
    var top = 0.0;
    for (var current = 0; current <= index; current++) {
      if (current < index) top += _itemExtent(items[current]);
    }
    return top;
  }

  double _animatedItemTop(List<SkillsRailItem<T>> items, double position) {
    if (items.length <= 1) return _itemTop(items, 0);
    final clamped = position.clamp(0.0, items.length - 1.0);
    final lower = clamped.floor();
    final upper = clamped.ceil();
    if (lower == upper) return _itemTop(items, lower);
    return _itemTop(items, lower) +
        (_itemTop(items, upper) - _itemTop(items, lower)) * (clamped - lower);
  }
}
