/*
 * [INPUT]: Depends on Flutter Canvas, configured Quadrant data, point/class styles, semantic fallbacks, and all official theme variables.
 * [OUTPUT]: Paints themed four-quadrant geometry, positioned axes, labels, borders, and individually styled data points.
 * [POS]: Serves as the dedicated native painter for Mermaid Quadrant Chart diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/quadrant.dart';
import '../models/style.dart';

class QuadrantChartPainter extends CustomPainter {
  const QuadrantChartPainter({required this.data, required this.style});

  final QuadrantChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final titleHeight = data.title == null
        ? 0.0
        : data.titleFontSize + data.titlePadding * 2;
    final leftAxisSpace = data.yAxisPosition == 'left'
        ? data.yAxisLabelFontSize + data.yAxisLabelPadding * 2
        : 0.0;
    final rightAxisSpace = data.yAxisPosition == 'right'
        ? data.yAxisLabelFontSize + data.yAxisLabelPadding * 2
        : 0.0;
    final topAxisSpace = data.xAxisPosition == 'top'
        ? data.xAxisLabelFontSize + data.xAxisLabelPadding * 2
        : 0.0;
    final bottomAxisSpace = data.xAxisPosition == 'bottom'
        ? data.xAxisLabelFontSize + data.xAxisLabelPadding * 2
        : 0.0;
    final chart = Rect.fromLTRB(
      data.quadrantPadding + leftAxisSpace,
      titleHeight + data.quadrantPadding + topAxisSpace,
      size.width - data.quadrantPadding - rightAxisSpace,
      size.height - data.quadrantPadding - bottomAxisSpace,
    );
    final center = chart.center;
    final primary = Color(style.defaultNodeStyle.strokeColor ?? 0xFF1976D2);
    final fill = Color(style.defaultNodeStyle.fillColor ?? 0xFFE3F2FD);
    final internalLine = Paint()
      ..color = _color(data.theme.internalBorderStrokeFill) ?? primary
      ..strokeWidth = data.quadrantInternalBorderStrokeWidth;
    final externalLine = Paint()
      ..color = _color(data.theme.externalBorderStrokeFill) ?? primary
      ..strokeWidth = data.quadrantExternalBorderStrokeWidth
      ..style = PaintingStyle.stroke;
    final shades = [.18, .12, .08, .14];
    final themedFills = [
      data.theme.quadrant1Fill,
      data.theme.quadrant2Fill,
      data.theme.quadrant3Fill,
      data.theme.quadrant4Fill,
    ];
    final rects = [
      Rect.fromLTRB(center.dx, chart.top, chart.right, center.dy),
      Rect.fromLTRB(chart.left, chart.top, center.dx, center.dy),
      Rect.fromLTRB(chart.left, center.dy, center.dx, chart.bottom),
      Rect.fromLTRB(center.dx, center.dy, chart.right, chart.bottom),
    ];
    for (var index = 0; index < rects.length; index++) {
      canvas.drawRect(
        rects[index],
        Paint()
          ..color =
              _color(themedFills[index]) ??
              fill.withValues(alpha: shades[index]),
      );
    }
    canvas
      ..drawRect(chart, externalLine)
      ..drawLine(
        Offset(center.dx, chart.top),
        Offset(center.dx, chart.bottom),
        internalLine,
      )
      ..drawLine(
        Offset(chart.left, center.dy),
        Offset(chart.right, center.dy),
        internalLine,
      );

    if (data.title case final title?) {
      _centerLabel(
        canvas,
        title,
        Offset(size.width / 2, data.titlePadding),
        data.titleFontSize,
        _color(data.theme.titleFill),
      );
    }
    _quadrantLabel(
      canvas,
      data.quadrant1,
      rects[0],
      _color(data.theme.quadrant1TextFill),
    );
    _quadrantLabel(
      canvas,
      data.quadrant2,
      rects[1],
      _color(data.theme.quadrant2TextFill),
    );
    _quadrantLabel(
      canvas,
      data.quadrant3,
      rects[2],
      _color(data.theme.quadrant3TextFill),
    );
    _quadrantLabel(
      canvas,
      data.quadrant4,
      rects[3],
      _color(data.theme.quadrant4TextFill),
    );
    if (data.xLeft case final value?) {
      final y = data.xAxisPosition == 'top'
          ? chart.top - data.xAxisLabelPadding - data.xAxisLabelFontSize
          : chart.bottom + data.xAxisLabelPadding;
      final paired = data.xRight != null;
      final anchor = Offset(
        paired ? chart.left + chart.width / 4 : chart.left,
        y,
      );
      if (paired) {
        _centerLabel(
          canvas,
          value,
          anchor,
          data.xAxisLabelFontSize,
          _color(data.theme.xAxisTextFill),
        );
      } else {
        _label(
          canvas,
          value,
          anchor,
          data.xAxisLabelFontSize,
          _color(data.theme.xAxisTextFill),
        );
      }
    }
    if (data.xRight case final value?) {
      final y = data.xAxisPosition == 'top'
          ? chart.top - data.xAxisLabelPadding - data.xAxisLabelFontSize
          : chart.bottom + data.xAxisLabelPadding;
      _centerLabel(
        canvas,
        value,
        Offset(chart.left + chart.width * .75, y),
        data.xAxisLabelFontSize,
        _color(data.theme.xAxisTextFill),
      );
    }
    if (data.yTop case final value?) {
      final x = data.yAxisPosition == 'left'
          ? data.yAxisLabelPadding
          : chart.right + data.quadrantPadding + data.yAxisLabelPadding;
      _rotatedLabel(
        canvas,
        value,
        Offset(
          x,
          data.yBottom == null ? chart.top : chart.top + chart.height / 4,
        ),
        data.yAxisLabelFontSize,
        _color(data.theme.yAxisTextFill),
        centered: data.yBottom != null,
      );
    }
    if (data.yBottom case final value?) {
      final x = data.yAxisPosition == 'left'
          ? data.yAxisLabelPadding
          : chart.right + data.quadrantPadding + data.yAxisLabelPadding;
      _rotatedLabel(
        canvas,
        value,
        Offset(
          x,
          data.yTop == null ? chart.bottom : chart.bottom - chart.height / 4,
        ),
        data.yAxisLabelFontSize,
        _color(data.theme.yAxisTextFill),
        centered: data.yTop != null,
      );
    }

    for (final point in data.points) {
      final offset = Offset(
        chart.left + point.x * chart.width,
        chart.bottom - point.y * chart.height,
      );
      final radius = point.radius ?? data.pointRadius;
      final pointFill =
          _color(point.color) ?? _color(data.theme.pointFill) ?? primary;
      final pointStroke = _color(point.strokeColor);
      canvas.drawCircle(offset, radius, Paint()..color = pointFill);
      if (pointStroke != null || point.strokeWidth != null) {
        canvas.drawCircle(
          offset,
          radius,
          Paint()
            ..color = pointStroke ?? primary
            ..strokeWidth = point.strokeWidth ?? 1
            ..style = PaintingStyle.stroke,
        );
      }
      _label(
        canvas,
        point.label,
        offset +
            Offset(radius + data.pointTextPadding, -data.pointLabelFontSize),
        data.pointLabelFontSize,
        _color(data.theme.pointTextFill),
      );
    }
  }

  void _quadrantLabel(Canvas canvas, String? text, Rect rect, Color? color) {
    if (text == null) return;
    final y = data.points.isEmpty
        ? rect.center.dy - data.quadrantLabelFontSize / 2
        : rect.top + data.quadrantTextTopPadding;
    _centerLabel(
      canvas,
      text,
      Offset(rect.center.dx, y),
      data.quadrantLabelFontSize,
      color,
    );
  }

  void _centerLabel(
    Canvas canvas,
    String text,
    Offset anchor,
    double size,
    Color? color,
  ) {
    final painter = _painter(text, size, color)..layout(maxWidth: 220);
    painter.paint(canvas, Offset(anchor.dx - painter.width / 2, anchor.dy));
  }

  Color? _color(String? value) {
    if (value == null || !value.startsWith('#')) return null;
    final hex = value.substring(1);
    final expanded = hex.length == 3
        ? hex.split('').map((part) => '$part$part').join()
        : hex;
    final parsed = int.tryParse(expanded, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }

  void _rotatedLabel(
    Canvas canvas,
    String text,
    Offset anchor,
    double size,
    Color? color, {
    required bool centered,
  }) {
    final painter = _painter(text, size, color)..layout(maxWidth: 180);
    canvas
      ..save()
      ..translate(anchor.dx, anchor.dy)
      ..rotate(-math.pi / 2);
    painter.paint(
      canvas,
      Offset(centered ? -painter.width / 2 : 0, -painter.height / 2),
    );
    canvas.restore();
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    Color? color,
  ) {
    final painter = _painter(text, size, color)..layout(maxWidth: 180);
    painter.paint(canvas, offset);
  }

  TextPainter _painter(String text, double size, Color? color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color ?? Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
        fontSize: size,
        fontFamily: style.fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  );

  @override
  bool shouldRepaint(QuadrantChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}
