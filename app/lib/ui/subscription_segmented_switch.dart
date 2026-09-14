/*
 * Derived from Portal Labs Subscription Pricing Picker, Copyright (c) 2026 Luis Portal, MIT License.
 * See /app/THIRD_PARTY_NOTICES.md for the complete attribution and license text.
 * [INPUT]: Depends on Flutter Material interaction, physics, focus, semantics, and haptic APIs, SkillsGo semantic color tokens, plus HugeIcons rendering.
 * [OUTPUT]: Provides a controlled segmented switch with two or more options, a sliding selection capsule, optional bounded breathing status dots, and single-click selection.
 * [POS]: Serves as the vendored Portal Labs subscription-period switch adapted for compact Library filtering and other short option sets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'design_system/skills_color_tokens.dart';

class SubscriptionSwitchOption {
  const SubscriptionSwitchOption({
    required this.label,
    required this.icon,
    this.showBadge = false,
  });

  final String label;
  final List<List<dynamic>> icon;
  final bool showBadge;
}

class SubscriptionSegmentedSwitch extends StatefulWidget {
  const SubscriptionSegmentedSwitch({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.maxWidth,
    this.showIcons = true,
  }) : assert(options.length >= 2),
       assert(selectedIndex >= 0 && selectedIndex < options.length);

  final List<SubscriptionSwitchOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double? maxWidth;
  final bool showIcons;

  @override
  State<SubscriptionSegmentedSwitch> createState() =>
      _SubscriptionSegmentedSwitchState();
}

class _SubscriptionSegmentedSwitchState
    extends State<SubscriptionSegmentedSwitch>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 18,
  );

  late int selectedIndex;
  late final AnimationController _positionController;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.selectedIndex;
    _positionController = AnimationController.unbounded(
      vsync: this,
      value: selectedIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant SubscriptionSegmentedSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != selectedIndex) {
      selectedIndex = widget.selectedIndex;
      _animateToSelection();
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  void _animateToSelection() {
    final target = selectedIndex.toDouble();

    _positionController.animateWith(
      SpringSimulation(
        _spring,
        _positionController.value,
        target,
        _positionController.velocity,
      ),
    );
  }

  void _select(int index) {
    if (index == selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => selectedIndex = index);
    _animateToSelection();
    widget.onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final skillsColors = Theme.of(context).extension<SkillsColorTokens>();
    final trackColor = skillsColors?.surfaceMuted ?? scheme.surfaceContainer;
    final thumbColor = skillsColors?.surfaceRaised ?? scheme.surface;
    final selectedColor = skillsColors?.foregroundDefault ?? scheme.onSurface;
    final unselectedColor =
        skillsColors?.foregroundMuted ?? scheme.onSurfaceVariant;
    final borderColor = skillsColors?.borderMuted ?? scheme.outlineVariant;
    final shadowColor = skillsColors?.shadow ?? scheme.shadow;
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: unselectedColor,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final widestLabel = widget.options.fold<double>(0, (width, option) {
      final painter = TextPainter(
        text: TextSpan(text: option.label, style: textStyle),
        textScaler: textScaler,
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      return width > painter.width ? width : painter.width;
    });
    const segmentHorizontalPadding = 12.0;
    final hasBadge = widget.options.any((option) => option.showBadge);
    final iconAndGapWidth = widget.showIcons ? (hasBadge ? 29.0 : 20.0) : 0.0;
    final naturalSegmentWidth =
        (widestLabel + iconAndGapWidth + segmentHorizontalPadding * 2)
            .clamp(86.0, double.infinity)
            .toDouble();
    final naturalWidth = naturalSegmentWidth * widget.options.length + 8;
    final availableWidth = widget.maxWidth != null && widget.maxWidth!.isFinite
        ? widget.maxWidth!.clamp(0.0, double.infinity).toDouble()
        : naturalWidth;
    final containerWidth = math.min(naturalWidth, availableWidth);
    final segmentWidth = ((containerWidth - 8) / widget.options.length)
        .clamp(1.0, double.infinity)
        .toDouble();
    final lastIndex = widget.options.length - 1;
    final overshootFraction = 2.5 / segmentWidth;
    double softenOvershoot(double distance) {
      final normalized = (distance / overshootFraction).clamp(0.0, 20.0);
      final exponential = math.exp(2 * normalized);
      return overshootFraction * ((exponential - 1) / (exponential + 1));
    }

    double displayPosition(double value) {
      if (value < 0) {
        return -softenOvershoot(-value);
      }
      if (value > lastIndex) {
        return lastIndex + softenOvershoot(value - lastIndex);
      }
      return value;
    }

    double visualPosition(double value) {
      final logical = displayPosition(value) / lastIndex;
      return textDirection == TextDirection.rtl ? 1 - logical : logical;
    }

    return Semantics(
      container: true,
      label: widget.options.map((option) => option.label).join(', '),
      child: Container(
        width: containerWidth,
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _positionController,
              builder: (context, child) => Align(
                alignment: Alignment.lerp(
                  Alignment.centerLeft,
                  Alignment.centerRight,
                  visualPosition(_positionController.value),
                )!,
                child: child,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / widget.options.length,
                child: SizedBox.expand(
                  child: DecoratedBox(
                    key: const Key('subscription-switch-thumb'),
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor.withValues(alpha: .12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                widget.options.length,
                (index) => _SubscriptionSwitchSegment(
                  option: widget.options[index],
                  selected: selectedIndex == index,
                  width: segmentWidth,
                  showIcon: widget.showIcons,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  onPressed: () => _select(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionSwitchSegment extends StatelessWidget {
  const _SubscriptionSwitchSegment({
    required this.option,
    required this.selected,
    required this.width,
    required this.showIcon,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onPressed,
  });

  final SubscriptionSwitchOption option;
  final bool selected;
  final double width;
  final bool showIcon;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
        label: option.label,
        onTap: onPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showIcon) ...[
                    HugeIcon(
                      icon: option.icon,
                      size: 15,
                      strokeWidth: 1.8,
                      color: selected ? selectedColor : unselectedColor,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: option.showBadge ? 5 : 0,
                          ),
                          child: Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? selectedColor : unselectedColor,
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (option.showBadge)
                          PositionedDirectional(
                            top: -3,
                            end: -3,
                            child: _BreathingStatusDot(
                              key: Key(
                                'subscription-switch-badge-${option.label}',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathingStatusDot extends StatefulWidget {
  const _BreathingStatusDot({super.key});

  @override
  State<_BreathingStatusDot> createState() => _BreathingStatusDotState();
}

class _BreathingStatusDotState extends State<_BreathingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> breath;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    breath = CurvedAnimation(parent: controller, curve: Curves.easeInOutSine);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startBreathing();
  }

  void _startBreathing() {
    if (controller.isAnimating || controller.isCompleted) return;
    controller.repeat(reverse: true, count: 2);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: breath,
      builder: (context, child) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: scheme.error.withValues(alpha: 0.45 - 0.3 * breath.value),
              blurRadius: 4 + 12 * breath.value,
              spreadRadius: 0.5 + 5.5 * breath.value,
            ),
          ],
        ),
      ),
    );
  }
}
