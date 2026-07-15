/*
 * [INPUT]: Receives localized rail items, selected values, destination content, and reduced-motion preferences.
 * [OUTPUT]: Renders the shared Burrow-inspired desktop side rail with accessible, stateful selection motion.
 * [POS]: Defines the reusable nested-navigation surface shared by Discover, Library, and Settings.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'brand.dart';

class SkillsRailItem<T> {
  const SkillsRailItem({
    required this.value,
    required this.label,
    this.dividerBefore = false,
  });

  final T value;
  final String label;
  final bool dividerBefore;
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
  });

  final String semanticLabel;
  final List<SkillsRailItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;

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

  int get _selectedIndex {
    final index = widget.items.indexWhere(
      (item) => item.value == widget.selected,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: _selectedIndex.toDouble(),
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
    if (restoreFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode(widget.selected).requestFocus();
      });
    }
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
          color: Colors.black.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: SkillsTokens.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
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
                      Positioned(
                        key: const ValueKey('rail-indicator'),
                        left: 0,
                        right: 0,
                        top: _animatedItemTop(_position.value) + 2,
                        height: _itemExtent - 4,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      for (var index = 0; index < widget.items.length; index++)
                        if (widget.items[index].dividerBefore)
                          Positioned(
                            left: 8,
                            right: 8,
                            top: _itemTop(index) - _separatorExtent,
                            height: _separatorExtent,
                            child: const Divider(
                              height: _separatorExtent,
                              color: SkillsTokens.hairline,
                            ),
                          ),
                      for (var index = 0; index < widget.items.length; index++)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: _itemTop(index),
                          height: _itemExtent,
                          child: _RailButton<T>(
                            item: widget.items[index],
                            focusNode: _focusNode(widget.items[index].value),
                            selected:
                                widget.items[index].value == widget.selected,
                            onPressed: () =>
                                widget.onSelected(widget.items[index].value),
                          ),
                        ),
                    ],
                  ),
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
  Widget build(BuildContext context) => Tooltip(
    message: item.label,
    child: Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: TextButton(
        focusNode: focusNode,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.black : SkillsTokens.textSecondary,
          backgroundColor: Colors.transparent,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size.fromHeight(44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
          textStyle: const TextStyle(
            fontFamily: SkillsTokens.sansFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    ),
  );
}
