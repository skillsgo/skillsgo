/*
 * [INPUT]: Depends on Flutter Canvas, Path, Curve, color, and animation math primitives.
 * [OUTPUT]: Provides the arc slider painter, bloom overshoot/spring curves, and morphing ring painter.
 * [POS]: Serves as the pure rendering and motion segment of the Bloom color picker; derived from Portal Labs under the repository MIT notice.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../bloom_color_picker.dart';

class ArcSliderPainter extends CustomPainter {
  /// Creates a new `ArcSliderPainter`.
  ArcSliderPainter({
    required this.currentColor,
    required this.lightness,
    required this.radius,
    required this.strokeWidth,
    required this.arcAngle,
    required this.thumbScale,
  });

  /// The active color used to generate the gradient.
  final Color currentColor;

  /// The lightness factor.
  final double lightness;

  /// The radial offset of the slider.
  final double radius;

  /// The thickness of the slider arc.
  final double strokeWidth;

  /// The sweep boundary angle.
  final double arcAngle;

  /// The active scale multiplier for the thumb handle.
  final double thumbScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-arcAngle - 0.2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect localRect = Rect.fromCircle(center: Offset.zero, radius: radius);

    final HSLColor hsl = HSLColor.fromColor(currentColor);
    final Color topColor = hsl.withLightness(0.95).toColor();
    final Color bottomColor = hsl.withLightness(0.05).toColor();

    final double totalSpan = 2 * arcAngle + 0.4;
    paint.shader = SweepGradient(
      colors: [topColor, currentColor, bottomColor],
      stops: [
        0.2 / totalSpan,
        (arcAngle + 0.2) / totalSpan,
        (2 * arcAngle + 0.2) / totalSpan,
      ],
      endAngle: totalSpan,
    ).createShader(localRect);

    // Draw ambient shadow (tighter and shifted down to prevent top-tip bleed)
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    // Slight vertical offset for the shadow, calculated before rotation
    canvas.save();
    // Revert the rotation to apply a strict vertical offset
    canvas.rotate(arcAngle + 0.2);
    canvas.translate(0, 3.5);
    canvas.rotate(-arcAngle - 0.2);
    canvas.drawArc(localRect, 0.2, 2 * arcAngle, false, shadowPaint);
    canvas.restore();

    canvas.drawArc(localRect, 0.2, 2 * arcAngle, false, paint);
    canvas.restore();

    // Draw Thumb
    final double thumbTheta = -arcAngle + (1.0 - lightness) * (2 * arcAngle);
    final Offset thumbCenter =
        center +
        Offset(radius * math.cos(thumbTheta), radius * math.sin(thumbTheta));
    final double baseRadius = strokeWidth / 2;

    final thumbShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      thumbCenter,
      (baseRadius + 4) * thumbScale,
      thumbShadowPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, (baseRadius + 2) * thumbScale, borderPaint);

    final HSLColor thumbHsl = HSLColor.fromColor(
      currentColor,
    ).withLightness(lightness);
    final innerPaint = Paint()
      ..color = thumbHsl.toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, (baseRadius - 1) * thumbScale, innerPaint);
  }

  @override
  bool shouldRepaint(covariant ArcSliderPainter oldDelegate) {
    return oldDelegate.currentColor != currentColor ||
        oldDelegate.lightness != lightness ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.arcAngle != arcAngle ||
        oldDelegate.thumbScale != thumbScale;
  }
}

/// A custom curve that simulates a liquid burst or overshoot effect.
/// It scales up beyond 1.0 (reaching up to 1.15) during the first half of the animation,
/// and then smoothly contracts back to 1.0 at the end.
class BloomOvershootCurve extends Curve {
  /// Creates a new `BloomOvershootCurve`.
  const BloomOvershootCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.55) {
      // Scale up rapidly: map 0.0 -> 0.55 to 0.0 -> 1.15
      final double x = t / 0.55;
      final double easeOutVal = 1.0 - math.pow(1.0 - x, 3).toDouble();
      return easeOutVal * 1.15;
    } else {
      // Contract and settle: map 0.55 -> 1.0 to 1.15 -> 1.0
      final double x = (t - 0.55) / 0.45;
      final double easeInOutVal = x < 0.5
          ? 4 * x * x * x
          : 1.0 - math.pow(-2 * x + 2, 3).toDouble() / 2;
      return 1.15 - (easeInOutVal * 0.15);
    }
  }
}

/// A custom spring curve based on damped harmonic motion.
/// It overshoots its target value slightly and bounces back to settle at 1.0.
class BloomSpringCurve extends Curve {
  /// Creates a new `BloomSpringCurve`.
  const BloomSpringCurve();

  @override
  double transformInternal(double t) {
    if (t >= 0.99) return 1.0;
    // Damped harmonic oscillator starting from rest (initial velocity = 0)
    // decay = 3.0, omega = 5.0
    final double raw =
        1.0 -
        math.exp(-3.0 * t) * (math.cos(5.0 * t) + 0.6 * math.sin(5.0 * t));
    final double endVal =
        1.0 - math.exp(-3.0) * (math.cos(5.0) + 0.6 * math.sin(5.0));
    return raw / endVal;
  }
}

/// A custom painter that draws a concentrically peeling colored ring.
/// Starts as a filled circle matching the closed button (with a white border and black drop shadow),
/// and opens outward with a hollow center starting from the inside.
class MorphingRingPainter extends CustomPainter {
  /// Creates a new `MorphingRingPainter`.
  MorphingRingPainter({
    required this.progress,
    required this.color,
    required this.closedRadius,
    required this.targetOuterRadius,
    required this.endBorderWidth,
  });

  /// The animation progress from 0.0 (closed) to 1.0 (open).
  final double progress;

  /// The current selected color of the picker.
  final Color color;

  /// The radius of the picker in the closed state.
  final double closedRadius;

  /// The final outer radius of the ring.
  final double targetOuterRadius;

  /// The final stroke thickness of the ring.
  final double endBorderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Calculate current outer radius (smooth linear interpolation style)
    final double outerRadius = lerpDouble(
      closedRadius,
      targetOuterRadius,
      progress,
    )!;

    // 2. Calculate current inner radius (the hole size).
    // To make it "peel from the inside", the inner radius (the hole) must start at 0
    // and grow slowly at first (ease-in), then expand to its target size.
    final double innerProgress = Curves.easeInCubic.transform(
      progress.clamp(0.0, 1.0),
    );
    final double targetInnerRadius = targetOuterRadius - endBorderWidth;
    final double innerRadius = lerpDouble(
      0.0,
      targetInnerRadius,
      innerProgress,
    )!;

    // 3. Draw black drop shadow for initial button matching.
    // Fades out completely in the first 50% of the transition.
    if (progress < 0.5) {
      final double blackShadowOpacity = (1.0 - progress * 2.0).clamp(0.0, 1.0);
      if (blackShadowOpacity > 0.01) {
        final shadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.08 * blackShadowOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          center + const Offset(0, 4),
          outerRadius,
          shadowPaint,
        );
      }
    }

    // 4. Draw colored glow that radiates outward and fades.
    final double glowAlpha = lerpDouble(0.45, 0.0, progress.clamp(0.0, 1.0))!;
    if (glowAlpha > 0.01) {
      final double glowRadius = lerpDouble(
        20.0,
        0.0,
        progress.clamp(0.0, 1.0),
      )!;
      final double glowSpread = lerpDouble(6.0, 0.0, progress.clamp(0.0, 1.0))!;
      if (glowRadius > 0.1) {
        final shadowPaint = Paint()
          ..color = color.withValues(alpha: glowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, outerRadius + glowSpread, shadowPaint);
      }
    }

    // 5. Draw the colored disc/ring
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (innerRadius <= 0.05) {
      // Solid circle
      canvas.drawCircle(center, outerRadius, paint);
    } else {
      // Hollow ring using Path.combine (difference)
      final outerPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: outerRadius));
      final innerPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
      final ringPath = Path.combine(
        PathOperation.difference,
        outerPath,
        innerPath,
      );
      canvas.drawPath(ringPath, paint);
    }

    // 6. Draw white border (which matches the closed button's white border).
    // Fades out completely in the first 50% of the transition.
    if (progress < 0.5) {
      final double whiteBorderOpacity = (1.0 - progress * 2.0).clamp(0.0, 1.0);
      if (whiteBorderOpacity > 0.01) {
        final whiteBorderPaint = Paint()
          ..color = Colors.white.withValues(alpha: whiteBorderOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..isAntiAlias = true;
        canvas.drawCircle(center, outerRadius - 1.5, whiteBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MorphingRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.closedRadius != closedRadius ||
        oldDelegate.targetOuterRadius != targetOuterRadius ||
        oldDelegate.endBorderWidth != endBorderWidth;
  }
}
