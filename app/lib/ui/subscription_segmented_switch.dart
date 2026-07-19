/*
 * Derived from Portal Labs Subscription Pricing Picker, Copyright (c) 2026 Luis Portal, MIT License.
 * See /app/THIRD_PARTY_NOTICES.md for the complete attribution and license text.
 * [INPUT]: Depends on Flutter Material interaction, physics, focus, semantics, and haptic APIs, SkillsGo semantic color tokens, plus HugeIcons rendering.
 * [OUTPUT]: Provides a controlled two-option segmented switch with a sliding selection capsule and single-click selection.
 * [POS]: Serves as the vendored Portal Labs subscription-period switch adapted for compact Library filtering.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'design_system/skills_color_tokens.dart';

class SubscriptionSwitchOption {
  const SubscriptionSwitchOption({required this.label, required this.icon});

  final String label;
  final List<List<dynamic>> icon;
}

class SubscriptionSegmentedSwitch extends StatefulWidget {
  const SubscriptionSegmentedSwitch({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(options.length == 2),
       assert(selectedIndex == 0 || selectedIndex == 1);

  final List<SubscriptionSwitchOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

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
    if (MediaQuery.disableAnimationsOf(context)) {
      _positionController.value = target;
      return;
    }
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
    const iconAndGapWidth = 20.0;
    final segmentWidth =
        (widestLabel + iconAndGapWidth + segmentHorizontalPadding * 2).clamp(
          86.0,
          double.infinity,
        );
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
      if (value > 1) {
        return 1 + softenOvershoot(value - 1);
      }
      return value;
    }

    return Semantics(
      container: true,
      label: '${widget.options[0].label}, ${widget.options[1].label}',
      child: Container(
        width: segmentWidth * 2 + 8,
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
                  displayPosition(_positionController.value),
                )!,
                child: child,
              ),
              child: FractionallySizedBox(
                widthFactor: .5,
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
    required this.selectedColor,
    required this.unselectedColor,
    required this.onPressed,
  });

  final SubscriptionSwitchOption option;
  final bool selected;
  final double width;
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
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: option.icon,
                    size: 15,
                    strokeWidth: 1.8,
                    color: selected ? selectedColor : unselectedColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    option.label,
                    style: TextStyle(
                      color: selected ? selectedColor : unselectedColor,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
