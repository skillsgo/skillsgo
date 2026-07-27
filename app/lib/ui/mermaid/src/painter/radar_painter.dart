/*
 * [INPUT]: Depends on Flutter Canvas, complete Radar data/configuration, semantic fallbacks, and official Radar/cScale theme variables.
 * [OUTPUT]: Paints official-coordinate Radar grids, axes/labels, polygon or tension curves, titles, and single/multi-series legends.
 * [POS]: Serves as the chart-specific renderer for Mermaid Radar diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/radar.dart';
import '../models/style.dart';

/// Painter for Radar charts
class RadarPainter extends CustomPainter {
  /// Creates a radar painter
  const RadarPainter({
    required this.radarData,
    required this.style,
    this.deviceConfig,
  });

  /// The Radar data to render
  final RadarChartData radarData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (radarData.axes.isEmpty || radarData.curves.isEmpty) return;

    final intrinsicWidth =
        radarData.width + radarData.marginLeft + radarData.marginRight;
    final horizontalOffset = (size.width - intrinsicWidth) / 2;
    final center = Offset(
      horizontalOffset + radarData.marginLeft + radarData.width / 2,
      radarData.marginTop + radarData.height / 2,
    );
    final radius = math.min(radarData.width, radarData.height) / 2;

    if (radarData.title case final title?) {
      _drawTitle(canvas, title, center.dx, 0);
    }

    // Draw graticule (background grid)
    _drawGraticule(canvas, center, radius);

    // Draw axes
    _drawAxes(canvas, center, radius);

    // Draw data curves
    for (var i = 0; i < radarData.curves.length; i++) {
      _drawCurve(canvas, center, radius, radarData.curves[i], i);
    }

    // Draw legend
    if (radarData.showLegend) {
      _drawLegend(canvas, center);
    }
  }

  /// Draws the title
  void _drawTitle(Canvas canvas, String title, double centerX, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: radarData.theme.titleFontSize ?? 16,
          fontWeight: FontWeight.bold,
          color:
              _color(radarData.theme.titleColor) ??
              Color(
                style.defaultNodeStyle.textColor ?? RadarChartColors.textColor,
              ),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, y));
  }

  /// Draws the graticule (background concentric circles/polygons)
  void _drawGraticule(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color =
          (_color(radarData.theme.graticuleColor) ??
                  const Color(RadarChartColors.graticuleColor))
              .withValues(alpha: radarData.theme.graticuleOpacity ?? 1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radarData.theme.graticuleStrokeWidth ?? 1;

    final ticks = radarData.ticks;
    final axisCount = radarData.axes.length;

    for (var i = 1; i <= ticks; i++) {
      final r = radius * (i / ticks);

      if (radarData.graticule == RadarGraticule.circle) {
        // Draw circle
        canvas.drawCircle(center, r, paint);
      } else {
        // Draw polygon
        final path = Path();
        for (var j = 0; j < axisCount; j++) {
          final angle = _getAngleForAxis(j);
          final x = center.dx + r * math.cos(angle);
          final y = center.dy + r * math.sin(angle);

          if (j == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Draws the axes and labels
  void _drawAxes(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color =
          _color(radarData.theme.axisColor) ??
          const Color(RadarChartColors.axisColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radarData.theme.axisStrokeWidth ?? 1.5;

    final fontSize = radarData.theme.axisLabelFontSize ?? 12;

    for (var i = 0; i < radarData.axes.length; i++) {
      final axis = radarData.axes[i];
      final angle = _getAngleForAxis(i);

      // Draw axis line
      final endX =
          center.dx + radius * radarData.axisScaleFactor * math.cos(angle);
      final endY =
          center.dy + radius * radarData.axisScaleFactor * math.sin(angle);
      canvas.drawLine(center, Offset(endX, endY), paint);

      // Draw axis label
      final labelDistance = radius * radarData.axisLabelFactor;
      final labelX = center.dx + labelDistance * math.cos(angle);
      final labelY = center.dy + labelDistance * math.sin(angle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: axis.label,
          style: TextStyle(
            fontSize: fontSize,
            color:
                _color(radarData.theme.axisColor) ??
                const Color(RadarChartColors.textColor),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      // Adjust label position based on angle
      var offsetX = labelX - textPainter.width / 2;
      var offsetY = labelY - textPainter.height / 2;

      // Fine-tune positioning for better readability
      if (angle.abs() < math.pi / 4) {
        // Top
        offsetY = labelY - textPainter.height - 5;
      } else if (angle.abs() > 3 * math.pi / 4) {
        // Bottom
        offsetY = labelY + 5;
      } else if (angle > 0) {
        // Right side
        offsetX = labelX + 5;
      } else {
        // Left side
        offsetX = labelX - textPainter.width - 5;
      }

      textPainter.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  /// Draws a data curve
  void _drawCurve(
    Canvas canvas,
    Offset center,
    double radius,
    RadarCurve curve,
    int curveIndex,
  ) {
    if (curve.values.isEmpty) return;

    final color =
        _color(radarData.theme.curveColors[curveIndex]) ??
        Color(RadarChartColors.getColorForCurve(curveIndex));
    final points = <Offset>[];

    final max = radarData.effectiveMax;
    final min = radarData.effectiveMin;

    for (
      var i = 0;
      i < math.min(curve.values.length, radarData.axes.length);
      i++
    ) {
      final value = curve.values[i];
      final normalizedValue = (value - min) / (max - min);
      final r = radius * normalizedValue.clamp(0.0, 1.0);
      final angle = _getAngleForAxis(i);

      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final point = Offset(x, y);
      points.add(point);
    }
    if (points.length != radarData.axes.length) return;
    final path = radarData.graticule == RadarGraticule.circle
        ? _closedCurve(points, radarData.curveTension)
        : (Path()..addPolygon(points, true));

    // Draw filled area with transparency
    final fillPaint = Paint()
      ..color = color.withValues(alpha: radarData.theme.curveOpacity ?? 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radarData.theme.curveStrokeWidth ?? 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  Path _closedCurve(List<Offset> points, double tension) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length < 3 || tension == 0) {
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      return path..close();
    }
    final factor = tension;
    for (var index = 0; index < points.length; index++) {
      final p0 = points[(index - 1 + points.length) % points.length];
      final p1 = points[index];
      final p2 = points[(index + 1) % points.length];
      final p3 = points[(index + 2) % points.length];
      final c1 = p1 + (p2 - p0) * factor;
      final c2 = p2 - (p3 - p1) * factor;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  /// Draws the legend
  void _drawLegend(Canvas canvas, Offset center) {
    final fontSize = radarData.theme.legendFontSize ?? 12;
    final boxSize = radarData.theme.legendBoxSize ?? 12;
    final x =
        center.dx + ((radarData.width / 2 + radarData.marginRight) * 3) / 4;
    final firstY =
        center.dy - ((radarData.height / 2 + radarData.marginTop) * 3) / 4;
    for (var i = 0; i < radarData.curves.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: radarData.curves[i].label,
          style: TextStyle(
            fontSize: fontSize,
            color: Color(
              style.defaultNodeStyle.textColor ?? RadarChartColors.textColor,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final color =
          _color(radarData.theme.curveColors[i]) ??
          Color(RadarChartColors.getColorForCurve(i));
      final y = firstY + i * 20;
      canvas.drawRect(
        Rect.fromLTWH(x, y, boxSize, boxSize),
        Paint()
          ..color = color.withValues(alpha: radarData.theme.curveOpacity ?? .2),
      );
      textPainter.paint(canvas, Offset(x + boxSize + 4, y));
    }
  }

  Color? _color(String? source) {
    if (source == null || !source.startsWith('#')) return null;
    var hex = source.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((value) => '$value$value').join();
    }
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null || hex.length != 6
        ? null
        : Color(0xFF000000 | parsed);
  }

  /// Gets the angle for an axis (in radians)
  /// Starts from top (-π/2) and goes clockwise
  double _getAngleForAxis(int index) {
    final axisCount = radarData.axes.length;
    final angleStep = 2 * math.pi / axisCount;
    return -math.pi / 2 + index * angleStep;
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.radarData != radarData ||
        oldDelegate.style != style ||
        oldDelegate.deviceConfig != deviceConfig;
  }
}
