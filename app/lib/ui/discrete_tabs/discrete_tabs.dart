/*
 * Derived from Portal Labs Discrete Tabs, Copyright (c) 2026 Luis Portal, MIT License.
 * See /app/THIRD_PARTY_NOTICES.md for the complete attribution and license text.
 * [INPUT]: Depends on Flutter Material animation, focus, semantics, and haptic APIs.
 * [OUTPUT]: Provides an accessible controlled or uncontrolled expanding pill tab selector.
 * [POS]: Serves as the vendored Portal Labs appearance-mode selector in the App UI module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shimmer_text.dart';

class DiscreteTab {
  const DiscreteTab({
    required this.label,
    required this.icon,
    required this.activeColor,
  });

  final String label;
  final IconData icon;
  final Color activeColor;
}

class DiscreteTabsStyle {
  const DiscreteTabsStyle({
    required this.backgroundColor,
    required this.activeBackgroundColor,
    required this.inactiveIconColor,
    required this.shadowColor,
    this.border,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  final Color backgroundColor;
  final Color activeBackgroundColor;
  final Color inactiveIconColor;
  final Color shadowColor;
  final BoxBorder? border;
  final BorderRadiusGeometry borderRadius;
}

class DiscreteTabs extends StatefulWidget {
  const DiscreteTabs({
    super.key,
    required this.tabs,
    required this.style,
    this.onSelect,
    this.currentIndex,
    this.initialIndex = 0,
    this.spacing = 8,
  }) : assert(tabs.length > 0);

  final List<DiscreteTab> tabs;
  final ValueChanged<int>? onSelect;
  final int? currentIndex;
  final int initialIndex;
  final double spacing;
  final DiscreteTabsStyle style;

  @override
  State<DiscreteTabs> createState() => _DiscreteTabsState();
}

class _DiscreteTabsState extends State<DiscreteTabs> {
  late int selectedIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.currentIndex ?? widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant DiscreteTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != null && widget.currentIndex != selectedIndex) {
      selectedIndex = widget.currentIndex!;
    }
  }

  void select(int index) {
    if (selectedIndex == index) return;
    HapticFeedback.lightImpact();
    if (widget.currentIndex == null) setState(() => selectedIndex = index);
    widget.onSelect?.call(index);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    clipBehavior: Clip.none,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.tabs.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index == widget.tabs.length - 1 ? 0 : widget.spacing,
          ),
          child: _DiscreteTabItem(
            tab: widget.tabs[index],
            selected: selectedIndex == index,
            style: widget.style,
            onPressed: () => select(index),
          ),
        );
      }),
    ),
  );
}

class _DiscreteTabItem extends StatelessWidget {
  const _DiscreteTabItem({
    required this.tab,
    required this.selected,
    required this.style,
    required this.onPressed,
  });

  final DiscreteTab tab;
  final bool selected;
  final DiscreteTabsStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 600);
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.label,
        onTap: onPressed,
        child: GestureDetector(
          key: ValueKey('discrete-tab-${tab.label}'),
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: AnimatedContainer(
            duration: duration,
            curve: reduceMotion ? Curves.linear : Curves.easeOutBack,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? style.activeBackgroundColor
                  : style.backgroundColor,
              borderRadius: style.borderRadius,
              border: style.border,
              boxShadow: [
                BoxShadow(
                  color: style.shadowColor,
                  blurRadius: selected ? 10 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: duration,
                  curve: reduceMotion ? Curves.linear : Curves.easeOutBack,
                  child: Icon(
                    tab.icon,
                    size: 20,
                    color: selected ? tab.activeColor : style.inactiveIconColor,
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: duration,
                    curve: reduceMotion ? Curves.linear : Curves.easeOutBack,
                    alignment: Alignment.centerLeft,
                    child: selected
                        ? TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(-10 * (1 - value), 0),
                                child: child,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ShimmerText(
                                text: tab.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.5,
                                  color: tab.activeColor,
                                ),
                                baseColor: tab.activeColor,
                                highlightColor:
                                    Color.lerp(
                                      tab.activeColor,
                                      Theme.of(context).colorScheme.onSurface,
                                      .8,
                                    ) ??
                                    tab.activeColor,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
