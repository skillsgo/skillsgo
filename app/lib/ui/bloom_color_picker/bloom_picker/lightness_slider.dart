/*
 * [INPUT]: Depends on Bloom picker state, arc geometry, pointer gestures, HSL lightness conversion, and slider painter.
 * [OUTPUT]: Provides the curved lightness slider rendering and drag interaction.
 * [POS]: Serves as the lightness-control segment of the Bloom color picker; derived from Portal Labs under the repository MIT notice.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../bloom_color_picker.dart';

extension _BloomLightnessSlider on _BloomColorPickerState {
  Widget _buildLightnessSlider(double width, double height) {
    final double sliderRadius = widget.style.bloomRadius + 12.0;
    final double strokeWidth = widget.style.sliderWidth;
    final double arcAngle = math.pi / 6;

    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        onPanDown: (details) {
          final center = Offset(width / 2, height / 2);
          final localOffset = details.localPosition - center;
          final double distance = localOffset.distance;
          final double angle = math.atan2(localOffset.dy, localOffset.dx);

          // Restrict gesture detection to be near the slider arc.
          // Allow 24px radial padding on each side and 0.15 radians of angular padding.
          final bool isWithinRadius =
              (distance - sliderRadius).abs() <= (strokeWidth / 2 + 24.0);
          final bool isWithinAngle =
              angle >= -arcAngle - 0.15 && angle <= arcAngle + 0.15;

          if (isWithinRadius && isWithinAngle) {
            if (widget.style.hapticFeedback) HapticFeedback.lightImpact();
            updateState(() {
              _isDraggingSlider = true;
            });
            _handleArcDrag(
              details.localPosition,
              width,
              height,
              sliderRadius,
              arcAngle,
            );
          }
        },
        onPanUpdate: (details) {
          if (!_isDraggingSlider) return;
          _handleArcDrag(
            details.localPosition,
            width,
            height,
            sliderRadius,
            arcAngle,
          );
        },
        // Close the picker when the user finishes adjusting/selecting the lightness.
        onPanEnd: (details) {
          if (!_isDraggingSlider) return;
          updateState(() {
            _isDraggingSlider = false;
          });
          _toggleState();
        },
        onPanCancel: () {
          if (!_isDraggingSlider) return;
          updateState(() {
            _isDraggingSlider = false;
          });
          _toggleState();
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.0, end: _isDraggingSlider ? 1.15 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return CustomPaint(
              size: Size(width, height),
              painter: ArcSliderPainter(
                currentColor: _currentColor,
                lightness: _lightness,
                radius: sliderRadius,
                strokeWidth: strokeWidth,
                arcAngle: arcAngle,
                thumbScale: scale,
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleArcDrag(
    Offset localPosition,
    double width,
    double height,
    double sliderRadius,
    double arcAngle,
  ) {
    final center = Offset(width / 2, height / 2);
    final localOffset = localPosition - center;
    double angle = math.atan2(localOffset.dy, localOffset.dx);

    angle = angle.clamp(-arcAngle, arcAngle);

    final double pct = (angle - (-arcAngle)) / (2 * arcAngle);
    final double targetLightness = (1.0 - pct).clamp(0.05, 0.95);

    updateState(() {
      _lightness = targetLightness;
      final hsl = HSLColor.fromColor(_currentColor);
      _currentColor = hsl.withLightness(_lightness).toColor();
      _updateHexController();
    });
    widget.onColorChanged(_currentColor);
  }
}
