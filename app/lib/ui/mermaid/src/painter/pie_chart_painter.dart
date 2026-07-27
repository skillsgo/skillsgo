/*
 * [INPUT]: Depends on Flutter Canvas, responsive configuration, Mermaid Pie/Donut data, and semantic styles.
 * [OUTPUT]: Paints native Pie and Donut charts with configurable labels, highlighting, titles, and legends.
 * [POS]: Serves as the chart-specific renderer and size calculator for Mermaid Pie diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/pie_chart.dart';
import '../models/style.dart';

/// Painter for pie chart diagrams
class PieChartPainter extends CustomPainter {
  /// Creates a pie chart painter
  const PieChartPainter({
    required this.pieData,
    required this.style,
    this.deviceConfig,
    this.hoveredSlice,
  });

  /// The pie chart data to render
  final PieChartData pieData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Slice currently under the pointer when `highlightSlice` is `hover`.
  final String? hoveredSlice;

  @override
  void paint(Canvas canvas, Size size) {
    if (pieData.slices.isEmpty) return;

    final padding = style.padding;
    final minPieRadius = deviceConfig?.pieMinRadius ?? 90.0;
    final legendFontSize =
        pieData.theme.legendTextSize ?? deviceConfig?.legendFontSize ?? 11.0;
    final titleHeight = pieData.title != null
        ? (pieData.theme.titleTextSize ?? 25) + 15
        : 0.0;
    final legendMetrics = _measureLegend(legendFontSize);
    final legendWidth = legendMetrics.$1;
    final legendHeight = legendMetrics.$2;
    final vertical =
        pieData.legendPosition == PieLegendPosition.top ||
        pieData.legendPosition == PieLegendPosition.bottom;
    final centered = pieData.legendPosition == PieLegendPosition.center;
    final pieAreaWidth = vertical || centered
        ? size.width - padding * 2
        : size.width - legendWidth - padding * 4;
    final pieAreaHeight = vertical
        ? size.height - titleHeight - legendHeight - padding * 4
        : size.height - titleHeight - padding * 2;
    final pieRadius = math.max(
      minPieRadius * .6,
      math.min(pieAreaWidth, pieAreaHeight) / 2 - 10,
    );
    late final Offset pieCenter;
    late final Offset legendOrigin;
    switch (pieData.legendPosition) {
      case PieLegendPosition.top:
        legendOrigin = Offset((size.width - legendWidth) / 2, titleHeight);
        pieCenter = Offset(
          size.width / 2,
          titleHeight + legendHeight + padding * 2 + pieRadius,
        );
      case PieLegendPosition.bottom:
        pieCenter = Offset(size.width / 2, titleHeight + padding + pieRadius);
        legendOrigin = Offset(
          (size.width - legendWidth) / 2,
          pieCenter.dy + pieRadius + padding,
        );
      case PieLegendPosition.left:
        legendOrigin = Offset(
          padding,
          titleHeight + (pieAreaHeight - legendHeight) / 2,
        );
        pieCenter = Offset(
          padding * 3 + legendWidth + pieRadius,
          titleHeight + pieAreaHeight / 2,
        );
      case PieLegendPosition.right:
        pieCenter = Offset(
          padding + pieRadius,
          titleHeight + pieAreaHeight / 2,
        );
        legendOrigin = Offset(
          pieCenter.dx + pieRadius + padding * 2,
          titleHeight + (pieAreaHeight - legendHeight) / 2,
        );
      case PieLegendPosition.center:
        pieCenter = Offset(size.width / 2, titleHeight + pieAreaHeight / 2);
        legendOrigin = Offset(
          pieCenter.dx - legendWidth / 2,
          pieCenter.dy - legendHeight / 2,
        );
    }
    if (pieData.title case final title?) {
      _drawTitle(canvas, title, pieCenter.dx);
    }
    if (pieRadius > 20) _drawPieSlices(canvas, pieCenter, pieRadius);
    _drawLegend(canvas, legendOrigin, legendWidth, legendFontSize);
  }

  /// Measures the legend to get its required dimensions
  (double width, double height) _measureLegend(double fontSize) {
    final itemHeight = fontSize * 2;
    final colorBoxSize = fontSize * 1.1;
    const spacing = 6.0;

    var maxWidth = 0.0;

    for (var i = 0; i < pieData.slices.length; i++) {
      final slice = pieData.slices[i];
      var labelText = slice.label;
      if (pieData.showValuesInLegend) {
        labelText += ' [${_formatValue(slice.value)}]';
      }

      // Estimate text width based on font size (roughly 0.6 * fontSize per character)
      final textWidth = labelText.length * fontSize * 0.6;
      final totalWidth = colorBoxSize + spacing + textWidth;

      if (totalWidth > maxWidth) {
        maxWidth = totalWidth;
      }
    }

    final height = pieData.slices.length * itemHeight;
    return (maxWidth + 10, height);
  }

  /// Draws the title centered above the pie chart
  void _drawTitle(Canvas canvas, String title, double pieCenterX) {
    final textStyle = TextStyle(
      color:
          _color(pieData.theme.titleTextColor) ??
          Color(
            style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor,
          ),
      fontSize: pieData.theme.titleTextSize ?? 25,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
    );

    final textSpan = TextSpan(text: title, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    // Center the title horizontally on the pie center
    final offset = Offset(pieCenterX - textPainter.width / 2, style.padding);
    textPainter.paint(canvas, offset);
  }

  void _drawPieSlices(Canvas canvas, Offset center, double radius) {
    final total = pieData.totalValue;
    if (total == 0) return;

    final visibleSlices = pieData.slices
        .where((slice) => slice.value / total * 100 >= 1)
        .toList();
    if (visibleSlices.isEmpty) return;
    final visibleTotal = visibleSlices.fold<double>(
      0,
      (sum, slice) => sum + slice.value,
    );

    final outerWidth = pieData.theme.outerStrokeWidth ?? 2;
    canvas.drawCircle(
      center,
      radius + outerWidth / 2,
      Paint()
        ..color =
            _color(pieData.theme.outerStrokeColor) ??
            Color(
              style.defaultEdgeStyle.strokeColor ??
                  MermaidColors.defaultEdgeColor,
            )
        ..strokeWidth = outerWidth
        ..style = PaintingStyle.stroke,
    );

    var startAngle = -math.pi / 2; // Start from top

    for (final slice in visibleSlices) {
      final sourceIndex = pieData.slices.indexOf(slice);
      final sweepAngle = (slice.value / visibleTotal) * 2 * math.pi;
      final color = slice.color ?? _sliceColor(sourceIndex);

      // Draw slice
      final paint = Paint()
        ..color = Color(color).withValues(alpha: pieData.theme.opacity ?? .7)
        ..style = PaintingStyle.fill;

      final highlighted =
          pieData.highlightSlice == slice.label ||
          (pieData.highlightSlice == 'hover' && hoveredSlice == slice.label);
      final middleAngle = startAngle + sweepAngle / 2;
      final sliceCenter = highlighted
          ? center + Offset(math.cos(middleAngle), math.sin(middleAngle)) * 8
          : center;
      final innerRadius = radius * pieData.donutHole.clamp(0.0, 0.9);
      final path = Path()
        ..moveTo(
          sliceCenter.dx + innerRadius * math.cos(startAngle),
          sliceCenter.dy + innerRadius * math.sin(startAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: sliceCenter, radius: radius),
          startAngle,
          sweepAngle,
          false,
        )
        ..lineTo(
          sliceCenter.dx + innerRadius * math.cos(startAngle + sweepAngle),
          sliceCenter.dy + innerRadius * math.sin(startAngle + sweepAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: sliceCenter, radius: innerRadius),
          startAngle + sweepAngle,
          -sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);

      // Draw slice border
      final borderPaint = Paint()
        ..color =
            _color(pieData.theme.strokeColor) ?? Color(style.backgroundColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pieData.theme.strokeWidth ?? 2;

      canvas.drawPath(path, borderPaint);

      _drawSliceLabel(
        canvas,
        sliceCenter,
        radius,
        startAngle,
        sweepAngle,
        slice,
      );

      startAngle += sweepAngle;
    }
  }

  void _drawSliceLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    PieSlice slice,
  ) {
    final percentage = pieData.getPercentage(slice);
    final labelAngle = startAngle + sweepAngle / 2;
    final labelRadius = radius * pieData.textPosition.clamp(0.0, 1.0);

    final labelX = center.dx + labelRadius * math.cos(labelAngle);
    final labelY = center.dy + labelRadius * math.sin(labelAngle);

    final textStyle = TextStyle(
      color: _color(pieData.theme.sectionTextColor) ?? Colors.white,
      fontSize: pieData.theme.sectionTextSize ?? 17,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
      shadows: const [
        Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1)),
      ],
    );

    final text = '${percentage.toStringAsFixed(0)}%';
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    final offset = Offset(
      labelX - textPainter.width / 2,
      labelY - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  void _drawLegend(
    Canvas canvas,
    Offset topLeft,
    double maxWidth,
    double fontSize,
  ) {
    final itemHeight = fontSize * 2;
    final colorBoxSize = fontSize * 1.1;
    const spacing = 6.0;

    var y = topLeft.dy;

    for (var i = 0; i < pieData.slices.length; i++) {
      final slice = pieData.slices[i];
      final color = slice.color ?? _sliceColor(i);

      // Draw color box
      final colorRect = Rect.fromLTWH(
        topLeft.dx,
        y + (itemHeight - colorBoxSize) / 2,
        colorBoxSize,
        colorBoxSize,
      );

      final colorPaint = Paint()
        ..color = Color(color)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(colorRect, const Radius.circular(2)),
        colorPaint,
      );

      // Draw border for color box
      final borderPaint = Paint()
        ..color = Color(
          style.defaultEdgeStyle.strokeColor ?? MermaidColors.defaultEdgeColor,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(colorRect, const Radius.circular(2)),
        borderPaint,
      );

      // Draw label - single line, no wrap
      var labelText = slice.label;

      if (pieData.showValuesInLegend) {
        labelText += ' [${_formatValue(slice.value)}]';
      }

      final textStyle = TextStyle(
        color:
            _color(pieData.theme.legendTextColor) ??
            Color(
              style.defaultNodeStyle.textColor ??
                  MermaidColors.defaultTextColor,
            ),
        fontSize: fontSize,
        fontFamily: style.fontFamily,
      );

      final textSpan = TextSpan(text: labelText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      // Don't limit width to allow single line
      textPainter.layout();

      final textOffset = Offset(
        topLeft.dx + colorBoxSize + spacing,
        y + (itemHeight - textPainter.height) / 2,
      );
      textPainter.paint(canvas, textOffset);

      y += itemHeight;
    }
  }

  String _formatValue(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();

  int _sliceColor(int index) {
    if (pieData.theme.colors[index] case final source?) {
      final parsed = _color(source);
      if (parsed != null) return parsed.toARGB32();
    }
    return PieChartColors.getColor(index);
  }

  Color? _color(String? source) {
    if (source == null) return null;
    final value = source.trim().toLowerCase();
    const named = <String, int>{
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
      'red': 0xFFFF0000,
      'green': 0xFF008000,
      'blue': 0xFF0000FF,
      'yellow': 0xFFFFFF00,
      'gray': 0xFF808080,
      'grey': 0xFF808080,
      'transparent': 0x00000000,
    };
    if (named[value] case final color?) return Color(color);
    if (value.startsWith('#')) {
      final hex = value.substring(1);
      if (hex.length == 3) {
        final expanded = hex.split('').map((part) => '$part$part').join();
        final parsed = int.tryParse(expanded, radix: 16);
        return parsed == null ? null : Color(0xFF000000 | parsed);
      }
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed == null || (hex.length != 6 && hex.length != 8)) return null;
      return Color(hex.length == 8 ? parsed : 0xFF000000 | parsed);
    }
    final rgb = RegExp(
      r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)$',
    ).firstMatch(value);
    if (rgb == null) return null;
    final red = int.parse(rgb.group(1)!).clamp(0, 255);
    final green = int.parse(rgb.group(2)!).clamp(0, 255);
    final blue = int.parse(rgb.group(3)!).clamp(0, 255);
    final alpha =
        ((double.tryParse(rgb.group(4) ?? '1') ?? 1).clamp(0, 1) * 255).round();
    return Color.fromARGB(alpha, red, green, blue);
  }

  /// Returns the visible slice under [position] using the painted geometry.
  String? sliceAt(Offset position, Size size) {
    if (pieData.totalValue <= 0) return null;
    final padding = style.padding;
    final minPieRadius = deviceConfig?.pieMinRadius ?? 90.0;
    final legendFontSize =
        pieData.theme.legendTextSize ?? deviceConfig?.legendFontSize ?? 11.0;
    final titleHeight = pieData.title != null
        ? (pieData.theme.titleTextSize ?? 25) + 15
        : 0.0;
    final legendMetrics = _measureLegend(legendFontSize);
    final legendWidth = legendMetrics.$1;
    final legendHeight = legendMetrics.$2;
    final vertical =
        pieData.legendPosition == PieLegendPosition.top ||
        pieData.legendPosition == PieLegendPosition.bottom;
    final centered = pieData.legendPosition == PieLegendPosition.center;
    final pieAreaWidth = vertical || centered
        ? size.width - padding * 2
        : size.width - legendWidth - padding * 4;
    final pieAreaHeight = vertical
        ? size.height - titleHeight - legendHeight - padding * 4
        : size.height - titleHeight - padding * 2;
    final radius = math.max(
      minPieRadius * .6,
      math.min(pieAreaWidth, pieAreaHeight) / 2 - 10,
    );
    late final Offset center;
    switch (pieData.legendPosition) {
      case PieLegendPosition.top:
        center = Offset(
          size.width / 2,
          titleHeight + legendHeight + padding * 2 + radius,
        );
      case PieLegendPosition.bottom:
        center = Offset(size.width / 2, titleHeight + padding + radius);
      case PieLegendPosition.left:
        center = Offset(
          padding * 3 + legendWidth + radius,
          titleHeight + pieAreaHeight / 2,
        );
      case PieLegendPosition.right:
        center = Offset(padding + radius, titleHeight + pieAreaHeight / 2);
      case PieLegendPosition.center:
        center = Offset(size.width / 2, titleHeight + pieAreaHeight / 2);
    }
    final delta = position - center;
    final distance = delta.distance;
    if (distance > radius || distance < radius * pieData.donutHole) {
      return null;
    }
    final visible = pieData.slices
        .where((slice) => slice.value / pieData.totalValue * 100 >= 1)
        .toList();
    final visibleTotal = visible.fold<double>(
      0,
      (sum, slice) => sum + slice.value,
    );
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    var cursor = 0.0;
    for (final slice in visible) {
      cursor += slice.value / visibleTotal * math.pi * 2;
      if (angle <= cursor) return slice.label;
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return pieData != oldDelegate.pieData ||
        style != oldDelegate.style ||
        hoveredSlice != oldDelegate.hoveredSlice;
  }
}

/// Layout engine for pie charts
class PieChartLayout {
  /// Creates a pie chart layout
  const PieChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes the size needed to render the pie chart
  Size computeLayout(
    PieChartData pieData,
    MermaidStyle style,
    Size availableSize,
  ) {
    // Get responsive values
    final minPieRadius = deviceConfig?.pieMinRadius ?? 90.0;
    final legendFontSize =
        pieData.theme.legendTextSize ?? deviceConfig?.legendFontSize ?? 11.0;

    // Calculate legend dimensions
    final legendMetrics = _measureLegend(pieData, legendFontSize);
    final legendWidth = legendMetrics.$1;
    final legendHeight = legendMetrics.$2;

    final titleHeight = pieData.title != null
        ? (pieData.theme.titleTextSize ?? 25) + 15
        : 0.0;

    // Minimum pie diameter based on device
    final minPieDiameter = minPieRadius * 2;

    final vertical =
        pieData.legendPosition == PieLegendPosition.top ||
        pieData.legendPosition == PieLegendPosition.bottom;
    final centered = pieData.legendPosition == PieLegendPosition.center;
    late final double intrinsicWidth;
    late final double intrinsicHeight;
    if (vertical) {
      // Mobile layout: pie on top, legend below
      final minWidth =
          math.max(minPieDiameter, legendWidth) + style.padding * 2;
      final minHeight =
          titleHeight + minPieDiameter + legendHeight + style.padding * 4;

      intrinsicWidth = minWidth;
      intrinsicHeight = minHeight;
    } else if (centered) {
      intrinsicWidth =
          math.max(minPieDiameter, legendWidth) + style.padding * 2;
      intrinsicHeight =
          titleHeight +
          math.max(minPieDiameter, legendHeight) +
          style.padding * 3;
    } else {
      // Desktop/tablet layout: pie on left, legend on right
      final minWidth = minPieDiameter + legendWidth + style.padding * 5;
      final contentHeight = math.max(minPieDiameter, legendHeight);
      final minHeight = titleHeight + contentHeight + style.padding * 3;

      intrinsicWidth = minWidth;
      intrinsicHeight = minHeight;
    }
    return Size(
      pieData.useMaxWidth
          ? math.max(intrinsicWidth, availableSize.width)
          : intrinsicWidth,
      intrinsicHeight,
    );
  }

  /// Measures the legend to get its required dimensions
  (double width, double height) _measureLegend(
    PieChartData pieData,
    double fontSize,
  ) {
    final itemHeight = fontSize * 2;
    final colorBoxSize = fontSize * 1.1;
    const spacing = 6.0;

    var maxWidth = 0.0;

    for (var i = 0; i < pieData.slices.length; i++) {
      final slice = pieData.slices[i];
      var labelText = slice.label;
      if (pieData.showValuesInLegend) {
        labelText += ' [${slice.value}]';
      }

      // Estimate text width based on font size (roughly 0.6 * fontSize per character)
      final textWidth = labelText.length * fontSize * 0.6;
      final totalWidth = colorBoxSize + spacing + textWidth;

      if (totalWidth > maxWidth) {
        maxWidth = totalWidth;
      }
    }

    final height = pieData.slices.length * itemHeight;
    return (maxWidth + 20, height);
  }
}
