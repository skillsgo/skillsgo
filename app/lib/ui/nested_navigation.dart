/*
 * [INPUT]: Receives localized rail items, selected values, destination content, SkillsGo component tokens, and reduced-motion preferences.
 * [OUTPUT]: Renders the shared theme-tinted glass desktop side rail with accessible, stateful selection motion.
 * [POS]: Defines the reusable nested-navigation surface shared by Discover, Library, and Settings.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:hugeicons/hugeicons.dart';

import 'brand.dart';

class SkillsRailItem<T> {
  const SkillsRailItem({
    required this.value,
    required this.label,
    this.dividerBefore = false,
    this.icon,
    this.leading,
  });

  final T value;
  final String label;
  final bool dividerBefore;
  final List<List<dynamic>>? icon;
  final Widget? leading;
}

class SkillsDestinationLayout extends StatelessWidget {
  const SkillsDestinationLayout({
    super.key,
    required this.rail,
    required this.child,
  });

  final Widget rail;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 28, 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 184, child: rail),
        const SizedBox(width: 24),
        Expanded(child: child),
      ],
    ),
  );
}

class SkillsSideRail<T> extends StatefulWidget {
  const SkillsSideRail({
    super.key,
    required this.semanticLabel,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.header,
  });

  final String semanticLabel;
  final List<SkillsRailItem<T>> items;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Widget? header;

  @override
  State<SkillsSideRail<T>> createState() => _SkillsSideRailState<T>();
}

class _SkillsSideRailState<T> extends State<SkillsSideRail<T>>
    with SingleTickerProviderStateMixin {
  static const _itemExtent = 44.0;
  static const _separatorExtent = 12.0;
  late final AnimationController _position;
  final _scrollController = ScrollController();
  final _focusNodes = <T, FocusNode>{};

  FocusNode _focusNode(T value) => _focusNodes.putIfAbsent(
    value,
    () => FocusNode(debugLabel: 'Skills rail: $value'),
  );

  int get _selectedIndex =>
      widget.items.indexWhere((item) => item.value == widget.selected);

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: _selectedIndex.clamp(0, widget.items.length - 1).toDouble(),
    )..addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant SkillsSideRail<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentValues = widget.items.map((item) => item.value).toSet();
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
    final scheme = Theme.of(context).colorScheme;
    final components = context.skillsComponents;
    final contentHeight = widget.items.fold<double>(
      0,
      (height, item) =>
          height + _itemExtent + (item.dividerBefore ? _separatorExtent : 0),
    );
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
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: widget.items.length > 10,
                          child: SingleChildScrollView(
                            key: const ValueKey('side-rail-scroll'),
                            controller: _scrollController,
                            child: SizedBox(
                              height: contentHeight,
                              child: Stack(
                                children: [
                                  if (_selectedIndex >= 0)
                                    Positioned(
                                      key: const ValueKey('rail-indicator'),
                                      left: 0,
                                      right: 0,
                                      top:
                                          _animatedItemTop(_position.value) + 2,
                                      height: _itemExtent - 4,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: components.navigationSelected,
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(999),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x29000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  for (
                                    var index = 0;
                                    index < widget.items.length;
                                    index++
                                  )
                                    if (widget.items[index].dividerBefore)
                                      Positioned(
                                        left: 8,
                                        right: 8,
                                        top: _itemTop(index) - _separatorExtent,
                                        height: _separatorExtent,
                                        child: Divider(
                                          height: _separatorExtent,
                                          color: scheme.onSurface.withValues(
                                            alpha: .1,
                                          ),
                                        ),
                                      ),
                                  for (
                                    var index = 0;
                                    index < widget.items.length;
                                    index++
                                  )
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: _itemTop(index),
                                      height: _itemExtent,
                                      child: _RailButton<T>(
                                        item: widget.items[index],
                                        focusNode: _focusNode(
                                          widget.items[index].value,
                                        ),
                                        selected:
                                            widget.items[index].value ==
                                            widget.selected,
                                        onPressed: () => widget.onSelected(
                                          widget.items[index].value,
                                        ),
                                      ),
                                    ),
                                ],
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
          ),
        ),
      ),
    );
  }

  double _itemTop(int index) {
    var top = 0.0;
    for (var current = 0; current <= index; current++) {
      if (widget.items[current].dividerBefore) top += _separatorExtent;
      if (current < index) top += _itemExtent;
    }
    return top;
  }

  double _animatedItemTop(double position) {
    if (widget.items.length <= 1) return _itemTop(0);
    final clamped = position.clamp(0.0, widget.items.length - 1.0);
    final lower = clamped.floor();
    final upper = clamped.ceil();
    if (lower == upper) return _itemTop(lower);
    return _itemTop(lower) +
        (_itemTop(upper) - _itemTop(lower)) * (clamped - lower);
  }
}

class _RailButton<T> extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.focusNode,
    required this.selected,
    required this.onPressed,
  });

  final SkillsRailItem<T> item;
  final FocusNode focusNode;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? context.skillsComponents.navigationSelectedForeground
        : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: TextButton(
        focusNode: focusNode,
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              foregroundColor: foreground,
              backgroundColor: Colors.transparent,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size.fromHeight(44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              textStyle: const TextStyle(
                fontFamily: SkillsTokens.sansFamily,
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return foreground.withValues(alpha: .12);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return foreground.withValues(alpha: .08);
                }
                return Colors.transparent;
              }),
            ),
        child: Row(
          children: [
            if (item.leading != null) ...[
              item.leading!,
              const SizedBox(width: 10),
            ] else if (item.icon != null) ...[
              HugeIcon(
                icon: item.icon!,
                size: 18,
                strokeWidth: 1.5,
                color: foreground,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
