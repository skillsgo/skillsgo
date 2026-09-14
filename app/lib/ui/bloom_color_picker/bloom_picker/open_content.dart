/*
 * [INPUT]: Depends on Bloom picker state, preset values, polar layout, hover tooltips, color selection, and open-surface animation.
 * [OUTPUT]: Provides the expanded preset rings, center control, labels, hover feedback, and close interaction.
 * [POS]: Serves as the expanded preset-content segment of the Bloom color picker; derived from Portal Labs under the repository MIT notice.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../bloom_color_picker.dart';

extension _BloomOpenContent on _BloomColorPickerState {
  Widget _buildOpenContent(double width, double height, double bloomSize) {
    final double circleSize = widget.style.closedRadius * 2 - 8.0;

    // Distribute inner and outer rings proportionally to the configured bloom radius
    final double outerRadiusOffset = widget.style.bloomRadius * 0.48;
    final double innerRadiusOffset = widget.style.bloomRadius * 0.25;

    assert(widget.presets.length == 18);
    final outerPresets = widget.presets.take(12).toList(growable: false);
    final innerPresets = widget.presets
        .skip(12)
        .take(6)
        .toList(growable: false);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Gradient Slider (Arc)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final bool isReversing =
                  _controller.status == AnimationStatus.reverse;
              final double scale;
              final double translationProgress;
              if (isReversing) {
                // Collapse and disappear faster in reverse (completed by 0.55) to not linger on screen.
                // Use Curves.easeInCubic for a smooth closing transition.
                scale = const Interval(
                  0.55,
                  1.0,
                  curve: Curves.easeInCubic,
                ).transform(_controller.value);
                translationProgress = scale;
              } else {
                scale = const Interval(
                  0.10,
                  0.85,
                  curve: Curves.easeOutCubic,
                ).transform(_controller.value);
                translationProgress = const Interval(
                  0.10,
                  0.85,
                  curve: BloomSpringCurve(),
                ).transform(_controller.value);
              }
              final double visualScale = lerpDouble(0.85, 1.0, scale)!;
              final double sliderRadius = widget.style.bloomRadius + 12.0;
              final double translationX =
                  (translationProgress - 1.0) * sliderRadius;

              return Opacity(
                opacity: scale,
                child: Transform.translate(
                  offset: Offset(translationX, 0.0),
                  child: Transform.scale(scale: visualScale, child: child),
                ),
              );
            },
            child: _buildLightnessSlider(width, height),
          ),

          // 12 Outer Ring Colors
          ...List.generate(12, (index) {
            final double angle =
                (index / 12) * 2 * math.pi - math.pi / 2; // start from top
            final double dx = outerRadiusOffset * math.cos(angle);
            final double dy = outerRadiusOffset * math.sin(angle);
            final preset = outerPresets[index];
            final color = preset.color;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final bool isReversing =
                    _controller.status == AnimationStatus.reverse;
                final double start = 0.10 + (index / 12) * 0.45;
                final double end = (start + 0.30).clamp(0.0, 1.0);
                final double scale;
                if (isReversing) {
                  // Shift by +0.15 for reverse transition to fit inside the [0.15, 1.0] closing window,
                  // and use Curves.easeInCubic for smooth reverse scaling.
                  final double reverseStart = start + 0.15;
                  final double reverseEnd = (end + 0.15).clamp(0.0, 1.0);
                  scale = Interval(
                    reverseStart,
                    reverseEnd,
                    curve: Curves.easeInCubic,
                  ).transform(_controller.value);
                } else {
                  scale = Interval(
                    start,
                    end,
                    curve: Curves.easeOutCubic,
                  ).transform(_controller.value);
                }

                final double opacity = scale;
                // Shrink and collapse all the way to 0.0 in sync with the shrinking background circle (_bloomProgress.value)
                final double visualScale = isReversing
                    ? scale * _bloomProgress.value
                    : lerpDouble(0.7, 1.0, scale)!;
                final double translationFactor = isReversing
                    ? scale * _bloomProgress.value
                    : lerpDouble(0.7, 1.0, scale)!;

                return Transform.translate(
                  offset: Offset(
                    dx * translationFactor,
                    dy * translationFactor,
                  ),
                  child: Transform.scale(
                    scale: visualScale,
                    child: MouseRegion(
                      key: ValueKey('bloom-preset-${preset.name}'),
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) =>
                          _setHoveredPreset(preset.name, Offset(dx, dy)),
                      onExit: (_) => _setHoveredPreset(null),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectColor(color),
                        child: Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: opacity),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.30 * opacity),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 6 Inner Ring Colors
          ...List.generate(6, (index) {
            final double angle =
                (index / 6) * 2 * math.pi - math.pi / 2; // start from top
            final double dx = innerRadiusOffset * math.cos(angle);
            final double dy = innerRadiusOffset * math.sin(angle);
            final preset = innerPresets[index];
            final color = preset.color;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final bool isReversing =
                    _controller.status == AnimationStatus.reverse;
                final double start = 0.20 + (index / 6) * 0.35;
                final double end = (start + 0.30).clamp(0.0, 1.0);
                final double scale;
                if (isReversing) {
                  // Shift by +0.15 for reverse transition to fit inside the [0.15, 1.0] closing window,
                  // and use Curves.easeInCubic for smooth reverse scaling.
                  final double reverseStart = start + 0.15;
                  final double reverseEnd = (end + 0.15).clamp(0.0, 1.0);
                  scale = Interval(
                    reverseStart,
                    reverseEnd,
                    curve: Curves.easeInCubic,
                  ).transform(_controller.value);
                } else {
                  scale = Interval(
                    start,
                    end,
                    curve: Curves.easeOutCubic,
                  ).transform(_controller.value);
                }

                final double opacity = scale;
                // Shrink and collapse all the way to 0.0 in sync with the shrinking background circle (_bloomProgress.value)
                final double visualScale = isReversing
                    ? scale * _bloomProgress.value
                    : lerpDouble(0.7, 1.0, scale)!;
                final double translationFactor = isReversing
                    ? scale * _bloomProgress.value
                    : lerpDouble(0.7, 1.0, scale)!;

                return Transform.translate(
                  offset: Offset(
                    dx * translationFactor,
                    dy * translationFactor,
                  ),
                  child: Transform.scale(
                    scale: visualScale,
                    child: MouseRegion(
                      key: ValueKey('bloom-preset-${preset.name}'),
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) =>
                          _setHoveredPreset(preset.name, Offset(dx, dy)),
                      onExit: (_) => _setHoveredPreset(null),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectColor(color),
                        child: Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: opacity),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.20 * opacity),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Center white preset. It participates in the same selection
          // contract as the surrounding presets and closes after selection.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final bool isReversing =
                  _controller.status == AnimationStatus.reverse;
              final double scale;
              if (isReversing) {
                // Shift by +0.15 for reverse transition to fit inside the [0.15, 1.0] closing window,
                // and use Curves.easeInCubic for smooth reverse scaling.
                scale = const Interval(
                  0.25,
                  0.95,
                  curve: Curves.easeInCubic,
                ).transform(_controller.value);
              } else {
                scale = const Interval(
                  0.10,
                  0.80,
                  curve: Curves.easeOutCubic,
                ).transform(_controller.value);
              }
              final double opacity = scale;
              final double visualScale = lerpDouble(0.7, 1.0, scale)!;

              return Transform.scale(
                scale: visualScale,
                child: GestureDetector(
                  onTap: () => _selectColor(Colors.white),
                  child: Container(
                    key: const Key('bloom-center-white'),
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: opacity),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10 * opacity),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Paint the label last so it stays above the center button and every
          // color swatch. A nested Material Tooltip would create a second
          // overlay and cannot reliably resolve the follower transform while
          // the bloom is animating.
          Transform.translate(
            offset: _hoveredPresetOffset - Offset(0, circleSize / 2 + 12),
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: _hoveredPresetName == null
                    ? const SizedBox()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.inverseSurface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _hoveredPresetName!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onInverseSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
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
