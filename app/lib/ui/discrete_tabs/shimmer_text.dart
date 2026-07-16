/*
 * Derived from Portal Labs Discrete Tabs, Copyright (c) 2026 Luis Portal, MIT License.
 * See /app/THIRD_PARTY_NOTICES.md for the complete attribution and license text.
 * [INPUT]: Depends on Flutter shader, animation, and text rendering APIs.
 * [OUTPUT]: Provides the single-pass highlight animation used by selected Discrete Tab labels.
 * [POS]: Serves as the animated label primitive for the vendored Discrete Tabs component.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

class ShimmerText extends StatefulWidget {
  const ShimmerText({
    super.key,
    required this.text,
    required this.style,
    required this.baseColor,
    required this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  final String text;
  final TextStyle style;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(widget.text, style: widget.style);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
          stops: const [.35, .5, .65],
          transform: _SlidingGradientTransform(offset: controller.value),
        ).createShader(bounds),
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: widget.style.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.offset});

  final double offset;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (offset * 2 - 1), 0, 0);
}
