/*
 * Derived from Portal Labs FolderTabs, Copyright (c) 2026 Luis Portal, MIT License.
 * See /app/THIRD_PARTY_NOTICES.md for the complete attribution and license text.
 * [INPUT]: Depends on Flutter painting, focus, semantics, haptics, physics, and ambient text-direction APIs plus typed SkillsGo destinations.
 * [OUTPUT]: Provides a persistent full-height primary folder shell with direction-aware accessible tabs and an always-mounted child.
 * [POS]: Serves as the top-level primary navigation surface without owning or recreating destination page state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class SkillsFolderTab<T> {
  const SkillsFolderTab({
    required this.id,
    required this.value,
    required this.label,
  });

  final String id;
  final T value;
  final String label;
}

class SkillsPrimaryFolder<T> extends StatefulWidget {
  const SkillsPrimaryFolder({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    required this.child,
    this.style = const SkillsPrimaryFolderStyle(),
  }) : assert(tabs.length > 0);

  final List<SkillsFolderTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget child;
  final SkillsPrimaryFolderStyle style;

  @override
  State<SkillsPrimaryFolder<T>> createState() => _SkillsPrimaryFolderState<T>();
}

class _SkillsPrimaryFolderState<T> extends State<SkillsPrimaryFolder<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late int selectedIndex;
  late double animatedIndex;
  late double startIndex;
  late double targetIndex;

  @override
  void initState() {
    super.initState();
    selectedIndex = _indexOf(widget.selected);
    animatedIndex = selectedIndex.toDouble();
    startIndex = animatedIndex;
    targetIndex = animatedIndex;
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_advanceAnimation);
  }

  @override
  void didUpdateWidget(covariant SkillsPrimaryFolder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _indexOf(widget.selected);
    if (nextIndex != selectedIndex) _animateTo(nextIndex);
  }

  int _indexOf(T value) {
    final index = widget.tabs.indexWhere((tab) => tab.value == value);
    assert(index >= 0, 'The selected value must exist in tabs.');
    return index < 0 ? 0 : index;
  }

  void _advanceAnimation() {
    final curve = _PortalSpringCurve(
      mass: widget.style.springMass,
      stiffness: widget.style.springStiffness,
      damping: widget.style.springDamping,
    );
    setState(() {
      animatedIndex = lerpDouble(
        startIndex,
        targetIndex,
        curve.transform(controller.value),
      )!;
    });
  }

  void _animateTo(int index) {
    selectedIndex = index;
    startIndex = animatedIndex;
    targetIndex = index.toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      animatedIndex = targetIndex;
      return;
    }
    controller.forward(from: 0);
  }

  void _select(int index) {
    if (index == selectedIndex) return;
    if (widget.style.enableHaptics) HapticFeedback.lightImpact();
    widget.onSelected(widget.tabs[index].value);
  }

  @override
  void dispose() {
    controller
      ..removeListener(_advanceAnimation)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tabWidth = constraints.maxWidth / widget.tabs.length;
      final rightToLeft = Directionality.of(context) == TextDirection.rtl;
      double visualIndex(double logicalIndex) =>
          rightToLeft ? widget.tabs.length - 1 - logicalIndex : logicalIndex;
      return CustomPaint(
        key: const ValueKey('primary-folder-shell'),
        painter: _FolderPainter(
          bodyColor: widget.style.folderColor,
          activeTabColor: widget.style.activeTabColor,
          inactiveTabColor: widget.style.inactiveTabColor,
          borderRadius: widget.style.borderRadius,
          tabBorderRadius: widget.style.tabBorderRadius,
          tabHeight: widget.style.tabHeight,
          tabCurveWidth: widget.style.tabCurveWidth,
          animatedIndex: visualIndex(animatedIndex),
          selectedIndex: visualIndex(selectedIndex.toDouble()).round(),
          tabCount: widget.tabs.length,
          shadows: widget.style.shadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: widget.style.tabHeight,
              child: Stack(
                children: [
                  for (var index = 0; index < widget.tabs.length; index++)
                    Positioned(
                      left: tabWidth * visualIndex(index.toDouble()),
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: _FolderTabButton(
                        key: ValueKey(
                          'primary-destination-${widget.tabs[index].id}',
                        ),
                        label: widget.tabs[index].label,
                        selected: selectedIndex == index,
                        activeStyle: widget.style.activeLabelStyle,
                        inactiveStyle: widget.style.inactiveLabelStyle,
                        onPressed: () => _select(index),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: widget.style.padding,
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FolderTabButton extends StatelessWidget {
  const _FolderTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.activeStyle,
    required this.inactiveStyle,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final TextStyle activeStyle;
  final TextStyle inactiveStyle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
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
      label: label,
      button: true,
      selected: selected,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            style: selected ? activeStyle : inactiveStyle,
            child: ExcludeSemantics(
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SkillsPrimaryFolderStyle {
  const SkillsPrimaryFolderStyle({
    this.folderColor = const Color(0xFF17191A),
    this.activeTabColor = const Color(0xFF34302A),
    this.inactiveTabColor = const Color(0xFF211F1C),
    this.inactiveLabelStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: Color(0x99FFFFFF),
    ),
    this.activeLabelStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
    this.borderRadius = 24,
    this.tabBorderRadius = 24,
    this.tabHeight = 44,
    this.tabCurveWidth = 30,
    this.padding = EdgeInsets.zero,
    this.shadows = const [
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
    ],
    this.enableHaptics = true,
    this.springMass = 1,
    this.springStiffness = 210,
    this.springDamping = 22,
  });

  final Color folderColor;
  final Color activeTabColor;
  final Color inactiveTabColor;
  final TextStyle inactiveLabelStyle;
  final TextStyle activeLabelStyle;
  final double borderRadius;
  final double tabBorderRadius;
  final double tabHeight;
  final double tabCurveWidth;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadows;
  final bool enableHaptics;
  final double springMass;
  final double springStiffness;
  final double springDamping;
}

class _PortalSpringCurve extends Curve {
  const _PortalSpringCurve({
    required this.mass,
    required this.stiffness,
    required this.damping,
  });

  final double mass;
  final double stiffness;
  final double damping;

  @override
  double transformInternal(double t) => SpringSimulation(
    SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
    0,
    1,
    0,
  ).x(t).clamp(-.1, 1.1);
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter({
    required this.bodyColor,
    required this.activeTabColor,
    required this.inactiveTabColor,
    required this.borderRadius,
    required this.tabBorderRadius,
    required this.tabHeight,
    required this.tabCurveWidth,
    required this.animatedIndex,
    required this.selectedIndex,
    required this.tabCount,
    required this.shadows,
  });

  final Color bodyColor;
  final Color activeTabColor;
  final Color inactiveTabColor;
  final double borderRadius;
  final double tabBorderRadius;
  final double tabHeight;
  final double tabCurveWidth;
  final double animatedIndex;
  final int selectedIndex;
  final int tabCount;
  final List<BoxShadow> shadows;

  Path _path(Size size, double index) {
    final tabWidth = size.width / tabCount;
    final centerX = tabWidth * index + tabWidth / 2;
    final halfWidth = tabWidth / 2;
    final leftMorph = index.clamp(0.0, 1.0);
    final rightMorph = ((tabCount - 1) - index).clamp(0.0, 1.0);
    final topLeftY = lerpDouble(0, tabHeight, leftMorph)!;
    final topRightY = lerpDouble(0, tabHeight, rightMorph)!;
    final topLeftRadius = lerpDouble(tabBorderRadius, borderRadius, leftMorph)!;
    final topRightRadius = lerpDouble(
      tabBorderRadius,
      borderRadius,
      rightMorph,
    )!;
    final tabLeft = centerX - halfWidth;
    final tabRight = centerX + halfWidth;
    final path = Path()
      ..moveTo(0, size.height - borderRadius)
      ..lineTo(0, topLeftY + topLeftRadius)
      ..arcToPoint(
        Offset(topLeftRadius, topLeftY),
        radius: Radius.circular(topLeftRadius),
      );

    if (leftMorph > 0) {
      final curve = tabCurveWidth * leftMorph;
      final start = (tabLeft - curve).clamp(topLeftRadius, size.width);
      final edge = tabLeft.clamp(topLeftRadius, size.width);
      final end = (tabLeft + curve).clamp(topLeftRadius, size.width);
      path
        ..lineTo(start, topLeftY)
        ..cubicTo(edge, topLeftY, edge, 0, end, 0);
    } else {
      path.lineTo(topLeftRadius, 0);
    }

    path.lineTo(tabRight - tabCurveWidth * rightMorph, 0);
    if (rightMorph > 0) {
      final curve = tabCurveWidth * rightMorph;
      final start = (tabRight - curve).clamp(0.0, size.width - topRightRadius);
      final edge = tabRight.clamp(0.0, size.width - topRightRadius);
      final end = (tabRight + curve).clamp(0.0, size.width - topRightRadius);
      path
        ..lineTo(start, 0)
        ..cubicTo(edge, 0, edge, topRightY, end, topRightY);
    } else {
      path.lineTo(size.width - topRightRadius, 0);
    }

    return path
      ..lineTo(size.width - topRightRadius, topRightY)
      ..arcToPoint(
        Offset(size.width, topRightY + topRightRadius),
        radius: Radius.circular(topRightRadius),
      )
      ..lineTo(size.width, size.height - borderRadius)
      ..arcToPoint(
        Offset(size.width - borderRadius, size.height),
        radius: Radius.circular(borderRadius),
      )
      ..lineTo(borderRadius, size.height)
      ..arcToPoint(
        Offset(0, size.height - borderRadius),
        radius: Radius.circular(borderRadius),
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final inactiveBody = RRect.fromRectAndCorners(
      Rect.fromLTRB(0, tabHeight, size.width, size.height),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );
    canvas.drawRRect(inactiveBody, Paint()..color = inactiveTabColor);

    final topLeftRadius = selectedIndex == 0 ? 0.0 : borderRadius;
    final topRightRadius = selectedIndex == tabCount - 1 ? 0.0 : borderRadius;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(0, tabHeight, size.width, size.height),
      topLeft: Radius.circular(topLeftRadius),
      topRight: Radius.circular(topRightRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );
    canvas.drawRRect(body, Paint()..color = bodyColor);

    // Folder paths describe both the cap and the body. The body is painted
    // independently above, so this layer must expose only pixels above the
    // body seam. A hard clip prevents anti-aliased body edges from leaking
    // into the cap layer as horizontal extension lines.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width, tabHeight),
      doAntiAlias: false,
    );
    for (var index = 0; index < tabCount; index++) {
      final visibility = (animatedIndex - index).abs().clamp(0.0, 1.0);
      if (visibility < .01) continue;
      final path = _path(size, index.toDouble());
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: .08 * visibility)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawPath(path, Paint()..color = inactiveTabColor);
    }

    final front = _path(size, animatedIndex);
    for (final shadow in shadows) {
      canvas
        ..save()
        ..translate(shadow.offset.dx, shadow.offset.dy)
        ..drawPath(
          front,
          Paint()
            ..color = shadow.color
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              shadow.blurRadius * .5,
            ),
        )
        ..restore();
    }
    canvas.drawPath(front, Paint()..color = activeTabColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.activeTabColor != activeTabColor ||
      oldDelegate.inactiveTabColor != inactiveTabColor ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.tabBorderRadius != tabBorderRadius ||
      oldDelegate.tabHeight != tabHeight ||
      oldDelegate.tabCurveWidth != tabCurveWidth ||
      oldDelegate.animatedIndex != animatedIndex ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.tabCount != tabCount ||
      oldDelegate.shadows != shadows;
}
