/*
 * [INPUT]: Depends on Flutter Canvas, responsive configuration, complete XY chart content/configuration, and Mermaid semantic styles.
 * [OUTPUT]: Paints native axes, configurable ticks/labels/titles, grouped bars, value labels, and line series.
 * [POS]: Serves as the chart-specific renderer for Mermaid XY charts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/xy_chart.dart';
import '../models/style.dart';

/// Painter for XY Charts (bar + line)
class XYChartPainter extends CustomPainter {
  /// Creates an XY chart painter
  const XYChartPainter({
    required this.xyData,
    required this.style,
    this.deviceConfig,
  });

  /// The XY chart data to render
  final XYChartData xyData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  static const _defaultPlotPalette = <Color>[
    Color(0xffececff),
    Color(0xff8493a6),
    Color(0xffffc3a0),
    Color(0xffdcdde1),
    Color(0xffb8e994),
    Color(0xffd1a36f),
    Color(0xffc3cde6),
    Color(0xffffb6c1),
    Color(0xff496078),
    Color(0xfff8f3e3),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (xyData.series.isEmpty) return;
    final scale = math.min(
      size.width / xyData.width,
      size.height / xyData.height,
    );
    final paintSize = Size(xyData.width, xyData.height);
    canvas.save();
    canvas.scale(scale, scale);
    try {
      canvas.drawRect(
        Offset.zero & paintSize,
        Paint()
          ..color = _color(xyData.theme.backgroundColor, style.backgroundColor),
      );

      if (xyData.orientation == XYChartOrientation.horizontal) {
        _paintHorizontal(canvas, paintSize);
        return;
      }

      final padding = style.padding;
      final isMobile = deviceConfig?.deviceType == DeviceType.mobile;
      final reserveFactor = 1 - xyData.plotReservedSpacePercent / 100;

      // Layout areas
      var currentY = padding;
      final yAxisLabelWidth = math.min(
        50.0,
        math.max(0, paintSize.width * reserveFactor - padding),
      );
      final xAxisLabelHeight = math.min(
        isMobile ? 40.0 : 50.0,
        math.max(0, paintSize.height * reserveFactor - padding),
      );

      // Draw title
      if (xyData.showTitle && xyData.title != null) {
        _drawTitle(canvas, xyData.title!, paintSize.width / 2, currentY);
        currentY += xyData.titleFontSize + xyData.titlePadding * 2;
      }

      // Chart plot area
      final plotLeft = padding + yAxisLabelWidth;
      final plotRight = paintSize.width - padding;
      final plotTop = currentY;
      final plotBottom = paintSize.height - padding - xAxisLabelHeight;
      final plotWidth = plotRight - plotLeft;
      final plotHeight = plotBottom - plotTop;

      if (plotWidth <= 0 || plotHeight <= 0) return;

      final yMin = xyData.effectiveYMin;
      final yMax = xyData.effectiveYMax;
      final yRange = yMax - yMin;

      final dataCount = xyData.dataPointCount;
      if (dataCount == 0) return;

      // Draw grid lines and Y-axis labels
      _drawYAxis(canvas, plotLeft, plotRight, plotTop, plotBottom, yMin, yMax);

      // Draw X-axis labels
      _drawXAxis(canvas, plotLeft, plotRight, plotBottom, dataCount);

      // Draw axis lines
      final axisPaint = Paint()
        ..color = _color(xyData.theme.yAxisLineColor, _defaultTextColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = xyData.yAxisStyle.axisLineWidth;
      if (xyData.yAxisStyle.showAxisLine) {
        canvas.drawLine(
          Offset(plotLeft, plotTop),
          Offset(plotLeft, plotBottom),
          axisPaint,
        );
      }
      if (xyData.xAxisStyle.showAxisLine) {
        canvas.drawLine(
          Offset(plotLeft, plotBottom),
          Offset(plotRight, plotBottom),
          Paint()
            ..color = _color(xyData.theme.xAxisLineColor, _defaultTextColor)
            ..strokeWidth = xyData.xAxisStyle.axisLineWidth,
        );
      }

      // Count bar series for grouped bar layout
      final barSeriesCount = xyData.series
          .where((s) => s.type == XYSeriesType.bar)
          .length;
      var barSeriesIndex = 0;

      // Draw each series
      for (var si = 0; si < xyData.series.length; si++) {
        final series = xyData.series[si];
        final color = _seriesColor(si);

        if (series.type == XYSeriesType.bar) {
          _drawBarSeries(
            canvas,
            series,
            color,
            plotLeft,
            plotTop,
            plotBottom,
            plotWidth,
            plotHeight,
            dataCount,
            yMin,
            yRange,
            barSeriesIndex,
            barSeriesCount,
          );
          barSeriesIndex++;
        } else {
          _drawLineSeries(
            canvas,
            series,
            color,
            plotLeft,
            plotTop,
            plotBottom,
            plotWidth,
            plotHeight,
            dataCount,
            yMin,
            yRange,
          );
        }
      }
    } finally {
      canvas.restore();
    }
  }

  /// Draws the chart title
  void _drawTitle(Canvas canvas, String title, double centerX, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontFamily: style.fontFamily,
          fontSize: xyData.titleFontSize,
          color: _color(xyData.theme.titleColor, _defaultTextColor),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, y));
  }

  /// Draws Y-axis grid lines and labels
  void _drawYAxis(
    Canvas canvas,
    double plotLeft,
    double plotRight,
    double plotTop,
    double plotBottom,
    double yMin,
    double yMax,
  ) {
    final tickPaint = Paint()
      ..color = _color(xyData.theme.yAxisTickColor, _defaultTextColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final yRange = yMax - yMin;

    for (final value in _ticks(yMin, yMax)) {
      final ratio = _normalized(value, yMin, yRange);
      final y = plotBottom - (plotBottom - plotTop) * ratio;

      // Grid line (horizontal across plot area)
      if (xyData.yAxisStyle.showTick) {
        canvas.drawLine(
          Offset(plotLeft, y),
          Offset(plotLeft - xyData.yAxisStyle.tickLength, y),
          Paint()
            ..color = tickPaint.color
            ..strokeWidth = xyData.yAxisStyle.tickWidth,
        );
      }

      // Label
      if (!xyData.yAxisStyle.showLabel) continue;
      final label = _formatTick(value);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: style.fontFamily,
            fontSize: xyData.yAxisStyle.labelFontSize,
            color: _color(xyData.theme.yAxisLabelColor, _defaultTextColor),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          plotLeft - textPainter.width - xyData.yAxisStyle.labelPadding,
          y - textPainter.height / 2,
        ),
      );
    }

    // Y-axis title
    if (xyData.yAxisStyle.showTitle && xyData.yAxisTitle != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: xyData.yAxisTitle!,
          style: TextStyle(
            fontFamily: style.fontFamily,
            fontSize: xyData.yAxisStyle.titleFontSize,
            color: _color(xyData.theme.yAxisTitleColor, _defaultTextColor),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      final centerY = (plotTop + plotBottom) / 2;
      canvas
        ..translate(style.padding - 5, centerY)
        ..rotate(-math.pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
      canvas.restore();
    }
  }

  /// Draws X-axis labels
  void _drawXAxis(
    Canvas canvas,
    double plotLeft,
    double plotRight,
    double plotBottom,
    int dataCount,
  ) {
    final plotWidth = plotRight - plotLeft;

    final ticks = xyData.isCategorical
        ? <(double, String)>[
            for (var i = 0; i < dataCount; i++)
              (
                _plotPosition(i, dataCount, plotLeft, plotWidth),
                xyData.xAxisCategories[i],
              ),
          ]
        : <(double, String)>[
            for (final value in _ticks(_effectiveXMin, _effectiveXMax))
              (
                plotLeft +
                    plotWidth *
                        _normalized(
                          value,
                          _effectiveXMin,
                          _effectiveXMax - _effectiveXMin,
                        ),
                _formatTick(value),
              ),
          ];

    for (final tick in ticks) {
      final x = tick.$1;
      final label = tick.$2;

      if (xyData.xAxisStyle.showTick) {
        canvas.drawLine(
          Offset(x, plotBottom),
          Offset(x, plotBottom + xyData.xAxisStyle.tickLength),
          Paint()
            ..color = _color(xyData.theme.xAxisTickColor, _defaultTextColor)
            ..strokeWidth = xyData.xAxisStyle.tickWidth,
        );
      }

      if (!xyData.xAxisStyle.showLabel) continue;
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: style.fontFamily,
            fontSize: xyData.xAxisStyle.labelFontSize,
            color: _color(xyData.theme.xAxisLabelColor, _defaultTextColor),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      canvas.save();
      canvas.translate(
        x,
        plotBottom +
            (xyData.xAxisStyle.showTick ? xyData.xAxisStyle.tickLength : 0) +
            xyData.xAxisStyle.labelPadding,
      );
      canvas.rotate(xyData.xAxisStyle.labelRotation * math.pi / 180);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
      canvas.restore();
    }

    // X-axis title
    if (xyData.xAxisStyle.showTitle && xyData.xAxisTitle != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: xyData.xAxisTitle!,
          style: TextStyle(
            fontFamily: style.fontFamily,
            fontSize: xyData.xAxisStyle.titleFontSize,
            color: _color(xyData.theme.xAxisTitleColor, _defaultTextColor),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (plotLeft + plotRight) / 2 - textPainter.width / 2,
          plotBottom + 30,
        ),
      );
    }
  }

  void _paintHorizontal(Canvas canvas, Size size) {
    final padding = style.padding;
    final reserveFactor = 1 - xyData.plotReservedSpacePercent / 100;
    var currentY = padding;
    if (xyData.showTitle && xyData.title != null) {
      _drawTitle(canvas, xyData.title!, size.width / 2, currentY);
      currentY += xyData.titleFontSize + xyData.titlePadding * 2;
    }

    final categoryArea = math.min(
      90.0,
      math.max(0, size.width * reserveFactor - padding),
    );
    final valueAxisArea = math.min(
      55.0,
      math.max(0, size.height * reserveFactor - padding),
    );
    final plotLeft = padding + categoryArea;
    final plotRight = size.width - padding;
    final plotTop = currentY + valueAxisArea;
    final plotBottom = size.height - padding;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;
    final dataCount = xyData.dataPointCount;
    final valueMin = xyData.effectiveYMin;
    final valueMax = xyData.effectiveYMax;
    final valueRange = valueMax - valueMin;
    if (plotWidth <= 0 || plotHeight <= 0 || dataCount == 0) {
      return;
    }

    _drawHorizontalAxes(
      canvas,
      plotLeft,
      plotRight,
      plotTop,
      plotBottom,
      dataCount,
      valueMin,
      valueMax,
    );

    final barSeriesCount = xyData.series
        .where((series) => series.type == XYSeriesType.bar)
        .length;
    var barSeriesIndex = 0;
    for (
      var seriesIndex = 0;
      seriesIndex < xyData.series.length;
      seriesIndex++
    ) {
      final series = xyData.series[seriesIndex];
      final color = _seriesColor(seriesIndex);
      if (series.type == XYSeriesType.bar) {
        _drawHorizontalBarSeries(
          canvas,
          series,
          color,
          plotLeft,
          plotTop,
          plotWidth,
          plotHeight,
          dataCount,
          valueMin,
          valueRange,
          barSeriesIndex++,
          barSeriesCount,
        );
      } else {
        _drawHorizontalLineSeries(
          canvas,
          series,
          color,
          plotLeft,
          plotTop,
          plotWidth,
          plotHeight,
          dataCount,
          valueMin,
          valueRange,
        );
      }
    }
  }

  void _drawHorizontalAxes(
    Canvas canvas,
    double plotLeft,
    double plotRight,
    double plotTop,
    double plotBottom,
    int dataCount,
    double valueMin,
    double valueMax,
  ) {
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;
    final yAxisColor = _color(xyData.theme.yAxisLineColor, _defaultTextColor);
    final xAxisColor = _color(xyData.theme.xAxisLineColor, _defaultTextColor);
    for (final value in _ticks(valueMin, valueMax)) {
      final ratio = _normalized(value, valueMin, valueMax - valueMin);
      final x = plotLeft + plotWidth * ratio;
      if (xyData.yAxisStyle.showTick) {
        canvas.drawLine(
          Offset(x, plotTop),
          Offset(x, plotTop - xyData.yAxisStyle.tickLength),
          Paint()
            ..color = _color(xyData.theme.yAxisTickColor, _defaultTextColor)
            ..strokeWidth = xyData.yAxisStyle.tickWidth,
        );
      }
      if (xyData.yAxisStyle.showLabel) {
        final label = _formatTick(value);
        final painter = _labelPainter(
          label,
          xyData.yAxisStyle.labelFontSize,
          _color(xyData.theme.yAxisLabelColor, _defaultTextColor),
        );
        canvas.save();
        canvas.translate(x, plotTop - xyData.yAxisStyle.labelPadding);
        canvas.rotate(xyData.yAxisStyle.labelRotation * math.pi / 180);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height));
        canvas.restore();
      }
    }

    final categoryTicks = xyData.isCategorical
        ? <(double, String)>[
            for (var i = 0; i < dataCount; i++)
              (
                _plotPosition(i, dataCount, plotTop, plotHeight),
                xyData.xAxisCategories[i],
              ),
          ]
        : <(double, String)>[
            for (final value in _ticks(_effectiveXMin, _effectiveXMax))
              (
                _plotCoordinate(
                  _normalized(
                    value,
                    _effectiveXMin,
                    _effectiveXMax - _effectiveXMin,
                  ),
                  dataCount,
                  plotTop,
                  plotHeight,
                  reverse: true,
                ),
                _formatTick(value),
              ),
          ];
    for (final tick in categoryTicks) {
      final y = tick.$1;
      if (xyData.xAxisStyle.showTick) {
        canvas.drawLine(
          Offset(plotLeft, y),
          Offset(plotLeft - xyData.xAxisStyle.tickLength, y),
          Paint()
            ..color = _color(xyData.theme.xAxisTickColor, _defaultTextColor)
            ..strokeWidth = xyData.xAxisStyle.tickWidth,
        );
      }
      if (xyData.xAxisStyle.showLabel) {
        final label = tick.$2;
        final painter = _labelPainter(
          label,
          xyData.xAxisStyle.labelFontSize,
          _color(xyData.theme.xAxisLabelColor, _defaultTextColor),
        );
        canvas.save();
        canvas.translate(plotLeft - xyData.xAxisStyle.labelPadding, y);
        canvas.rotate(xyData.xAxisStyle.labelRotation * math.pi / 180);
        painter.paint(canvas, Offset(-painter.width, -painter.height / 2));
        canvas.restore();
      }
    }

    if (xyData.yAxisStyle.showAxisLine) {
      canvas.drawLine(
        Offset(plotLeft, plotTop),
        Offset(plotRight, plotTop),
        Paint()
          ..color = yAxisColor
          ..strokeWidth = xyData.yAxisStyle.axisLineWidth,
      );
    }
    if (xyData.xAxisStyle.showAxisLine) {
      canvas.drawLine(
        Offset(plotLeft, plotTop),
        Offset(plotLeft, plotBottom),
        Paint()
          ..color = xAxisColor
          ..strokeWidth = xyData.xAxisStyle.axisLineWidth,
      );
    }
    _drawHorizontalAxisTitles(canvas, plotLeft, plotRight, plotTop, plotBottom);
  }

  void _drawHorizontalAxisTitles(
    Canvas canvas,
    double plotLeft,
    double plotRight,
    double plotTop,
    double plotBottom,
  ) {
    if (xyData.yAxisStyle.showTitle && xyData.yAxisTitle != null) {
      final painter = _titlePainter(
        xyData.yAxisTitle!,
        xyData.yAxisStyle.titleFontSize,
        _color(xyData.theme.yAxisTitleColor, _defaultTextColor),
      );
      painter.paint(
        canvas,
        Offset(
          (plotLeft + plotRight - painter.width) / 2,
          plotTop -
              xyData.yAxisStyle.titlePadding -
              xyData.yAxisStyle.labelFontSize -
              painter.height,
        ),
      );
    }
    if (xyData.xAxisStyle.showTitle && xyData.xAxisTitle != null) {
      final painter = _titlePainter(
        xyData.xAxisTitle!,
        xyData.xAxisStyle.titleFontSize,
        _color(xyData.theme.xAxisTitleColor, _defaultTextColor),
      );
      canvas.save();
      canvas
        ..translate(style.padding, (plotTop + plotBottom + painter.width) / 2)
        ..rotate(-math.pi / 2);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  TextPainter _labelPainter(String text, double fontSize, [Color? color]) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: style.fontFamily,
            fontSize: fontSize,
            color: color ?? Color(_defaultTextColor),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  TextPainter _titlePainter(String text, double fontSize, [Color? color]) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: style.fontFamily,
            fontSize: fontSize,
            color: color ?? Color(_defaultTextColor),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Draws a bar series
  void _drawBarSeries(
    Canvas canvas,
    XYChartSeries series,
    Color color,
    double plotLeft,
    double plotTop,
    double plotBottom,
    double plotWidth,
    double plotHeight,
    int dataCount,
    double yMin,
    double yRange,
    int barIndex,
    int totalBars,
  ) {
    final groupWidth = plotWidth / dataCount;
    final barWidth = groupWidth * 0.665;
    final barOffset = -barWidth / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    var labelFontSize = double.infinity;
    if (xyData.showDataLabel) {
      for (var i = 0; i < series.values.length && i < dataCount; i++) {
        final value = series.values[i];
        final valueY =
            plotBottom - plotHeight * _normalized(value, yMin, yRange);
        final height = plotBottom - valueY;
        if (barWidth <= 0 || height <= 0) continue;
        final label = value.toString();
        var candidate = barWidth / math.max(1, label.length * .7);
        while (candidate > 0 &&
            (candidate * label.length * .7 > barWidth ||
                10 + candidate > height)) {
          candidate--;
        }
        labelFontSize = math.min(labelFontSize, candidate.floorToDouble());
      }
    }

    for (var i = 0; i < series.values.length && i < dataCount; i++) {
      final value = series.values[i];
      final normalizedValue = _normalized(value, yMin, yRange);
      final valueY = plotBottom - plotHeight * normalizedValue.clamp(0.0, 1.0);
      final barHeight = plotBottom - valueY;

      final x = _plotPosition(i, dataCount, plotLeft, plotWidth) + barOffset;
      final y = valueY;

      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      canvas.drawRect(rect, paint);
      if (xyData.showDataLabel && labelFontSize.isFinite && labelFontSize > 0) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: value.toString(),
            style: TextStyle(
              fontFamily: style.fontFamily,
              fontSize: labelFontSize,
              color: _color(xyData.theme.dataLabelColor, _defaultTextColor),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelY = xyData.showDataLabelOutsideBar
            ? y - labelPainter.height - 2
            : y + 2;
        labelPainter.paint(
          canvas,
          Offset(x + (barWidth - labelPainter.width) / 2, labelY),
        );
      }
    }
  }

  void _drawHorizontalBarSeries(
    Canvas canvas,
    XYChartSeries series,
    Color color,
    double plotLeft,
    double plotTop,
    double plotWidth,
    double plotHeight,
    int dataCount,
    double valueMin,
    double valueRange,
    int barIndex,
    int totalBars,
  ) {
    final groupHeight = plotHeight / dataCount;
    final barHeight = groupHeight * 0.665;
    final barOffset = -barHeight / 2;
    final fill = Paint()..color = color;
    var labelFontSize = double.infinity;
    if (xyData.showDataLabel) {
      for (var i = 0; i < series.values.length && i < dataCount; i++) {
        final valueX =
            plotLeft +
            plotWidth * _normalized(series.values[i], valueMin, valueRange);
        final width = valueX - plotLeft;
        if (width <= 0 || barHeight <= 0) continue;
        final label = series.values[i].toString();
        var candidate = barHeight * .7;
        while (candidate > 0 && candidate * label.length * .7 > width - 10) {
          candidate--;
        }
        labelFontSize = math.min(labelFontSize, candidate.floorToDouble());
      }
    }
    for (var i = 0; i < series.values.length && i < dataCount; i++) {
      final value = series.values[i];
      final valueRatio = _normalized(value, valueMin, valueRange);
      final valueX = plotLeft + plotWidth * valueRatio;
      final left = plotLeft;
      final width = valueX - plotLeft;
      final y =
          _plotPosition(
            i,
            dataCount,
            plotTop,
            plotHeight,
            reverse: !xyData.isCategorical,
          ) +
          barOffset;
      final rect = Rect.fromLTWH(left, y, width, barHeight);
      canvas.drawRect(rect, fill);
      if (xyData.showDataLabel && labelFontSize.isFinite && labelFontSize > 0) {
        final painter = _labelPainter(
          value.toString(),
          labelFontSize,
          _color(xyData.theme.dataLabelColor, _defaultTextColor),
        );
        final outside = xyData.showDataLabelOutsideBar;
        final labelX = outside ? valueX + 3 : valueX - painter.width - 3;
        painter.paint(
          canvas,
          Offset(labelX, y + (barHeight - painter.height) / 2),
        );
      }
    }
  }

  void _drawHorizontalLineSeries(
    Canvas canvas,
    XYChartSeries series,
    Color color,
    double plotLeft,
    double plotTop,
    double plotWidth,
    double plotHeight,
    int dataCount,
    double valueMin,
    double valueRange,
  ) {
    if (series.values.isEmpty) return;
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < series.values.length && i < dataCount; i++) {
      final ratio = _normalized(series.values[i], valueMin, valueRange);
      final point = Offset(
        plotLeft + plotWidth * ratio,
        _plotPosition(
          i,
          dataCount,
          plotTop,
          plotHeight,
          reverse: !xyData.isCategorical,
        ),
      );
      points.add(point);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final label = i < series.pointLabels.length
          ? series.pointLabels[i]
          : null;
      if (label != null && label.isNotEmpty) {
        final painter = _labelPainter(label, 12, color);
        painter.paint(
          canvas,
          Offset(point.dx + 10, point.dy - painter.height / 2),
        );
      }
    }
  }

  /// Draws a line series
  void _drawLineSeries(
    Canvas canvas,
    XYChartSeries series,
    Color color,
    double plotLeft,
    double plotTop,
    double plotBottom,
    double plotWidth,
    double plotHeight,
    int dataCount,
    double yMin,
    double yRange,
  ) {
    if (series.values.isEmpty) return;

    final path = Path();
    final points = <Offset>[];

    for (var i = 0; i < series.values.length && i < dataCount; i++) {
      final value = series.values[i];
      final normalizedValue = _normalized(value, yMin, yRange);
      final x = _plotPosition(i, dataCount, plotLeft, plotWidth);
      final y = plotBottom - plotHeight * normalizedValue.clamp(0.0, 1.0);
      final point = Offset(x, y);
      points.add(point);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final label = i < series.pointLabels.length
          ? series.pointLabels[i]
          : null;
      if (label != null && label.isNotEmpty) {
        final painter = _labelPainter(label, 12, color);
        painter.paint(
          canvas,
          Offset(
            point.dx - painter.width / 2,
            point.dy - 10 - painter.height / 2,
          ),
        );
      }
    }
  }

  int get _defaultTextColor =>
      style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor;

  double get _effectiveXMin => xyData.xAxisMin ?? 1;

  double get _effectiveXMax =>
      xyData.xAxisMax ?? xyData.dataPointCount.toDouble();

  bool get _hasBar =>
      xyData.series.any((series) => series.type == XYSeriesType.bar);

  double _plotPosition(
    int index,
    int count,
    double origin,
    double extent, {
    bool reverse = false,
  }) {
    if (count <= 1) return origin + extent / 2;
    return _plotCoordinate(
      index / (count - 1),
      count,
      origin,
      extent,
      reverse: reverse,
    );
  }

  double _plotCoordinate(
    double ratio,
    int count,
    double origin,
    double extent, {
    bool reverse = false,
  }) {
    final labelLengths = xyData.isCategorical
        ? xyData.xAxisCategories.map((label) => label.length)
        : _ticks(
            _effectiveXMin,
            _effectiveXMax,
          ).map((tick) => _formatTick(tick).length);
    final maxLabelLength = labelLengths.fold<int>(0, math.max);
    final labelOuter = math.min(
      maxLabelLength * xyData.xAxisStyle.labelFontSize * .3,
      extent * .2,
    );
    final outer = _hasBar
        ? math.max(labelOuter, extent / count * .3325).floorToDouble()
        : labelOuter;
    final directed = reverse ? 1 - ratio : ratio;
    return origin + outer + (extent - outer * 2) * directed;
  }

  double _normalized(double value, double minimum, double range) =>
      range == 0 ? .5 : ((value - minimum) / range).clamp(0, 1);

  List<double> _ticks(double start, double stop, [double count = 10]) {
    if (!(count > 0) || !start.isFinite || !stop.isFinite) return const [];
    if (start == stop) return [start];
    final reverse = stop < start;
    final spec = _tickSpec(
      reverse ? stop : start,
      reverse ? start : stop,
      count,
    );
    var first = spec.$1;
    final last = spec.$2;
    final increment = spec.$3;
    if (last < first) return const [];
    final values = <double>[];
    while (first <= last) {
      values.add(increment < 0 ? first / -increment : first * increment);
      first++;
    }
    return reverse ? values.reversed.toList(growable: false) : values;
  }

  (int, int, double) _tickSpec(double start, double stop, double count) {
    final step = (stop - start) / math.max(0, count);
    final power = (math.log(step) / math.ln10).floor();
    final magnitude = math.pow(10, power).toDouble();
    final error = step / magnitude;
    final factor = error >= math.sqrt(50)
        ? 10
        : error >= math.sqrt(10)
        ? 5
        : error >= math.sqrt(2)
        ? 2
        : 1;
    int first;
    int last;
    double increment;
    if (power < 0) {
      increment = math.pow(10, -power) / factor;
      first = (start * increment).round();
      last = (stop * increment).round();
      if (first / increment < start) first++;
      if (last / increment > stop) last--;
      increment = -increment;
    } else {
      increment = magnitude * factor;
      first = (start / increment).round();
      last = (stop / increment).round();
      if (first * increment < start) first++;
      if (last * increment > stop) last--;
    }
    if (last < first && .5 <= count && count < 2) {
      return _tickSpec(start, stop, count * 2);
    }
    return (first, last, increment);
  }

  String _formatTick(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Color _seriesColor(int index) {
    final palette = xyData.theme.plotColorPalette;
    if (palette.isNotEmpty) {
      final parsed = _tryColor(
        palette[index == 0 ? 0 : index % palette.length],
      );
      if (parsed != null) return parsed;
    }
    return _defaultPlotPalette[index % _defaultPlotPalette.length];
  }

  Color _color(String? source, int fallback) =>
      _tryColor(source) ?? Color(fallback);

  Color? _tryColor(String? source) {
    if (source == null) return null;
    final value = source.trim().toLowerCase();
    final hex = RegExp(r'^#([0-9a-f]{3,8})$').firstMatch(value)?.group(1);
    if (hex != null && const {3, 4, 6, 8}.contains(hex.length)) {
      final expanded = hex.length <= 4
          ? hex.split('').map((digit) => '$digit$digit').join()
          : hex;
      final rgba = expanded.length == 6 ? '${expanded}ff' : expanded;
      return Color(
        int.parse('${rgba.substring(6, 8)}${rgba.substring(0, 6)}', radix: 16),
      );
    }
    return const <String, Color>{
      'black': Colors.black,
      'white': Colors.white,
      'red': Colors.red,
      'green': Colors.green,
      'blue': Colors.blue,
      'gray': Colors.grey,
      'grey': Colors.grey,
      'transparent': Color(0x00000000),
    }[value];
  }

  @override
  bool shouldRepaint(XYChartPainter oldDelegate) {
    return oldDelegate.xyData != xyData ||
        oldDelegate.style != style ||
        oldDelegate.deviceConfig != deviceConfig;
  }
}
