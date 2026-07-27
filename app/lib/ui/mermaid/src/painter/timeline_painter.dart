/*
 * [INPUT]: Depends on Flutter Canvas, responsive configuration, complete Timeline semantics/configuration, CSS colors, and Mermaid styles.
 * [OUTPUT]: Paints native LR/TD timelines with section bands, task/event cards, configured typography, alignment, margins, colors, markers, and connectors.
 * [POS]: Serves as the chart-specific renderer for Mermaid Timeline diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/style.dart';
import '../models/timeline.dart';
import 'css_color.dart';

class TimelinePainter extends CustomPainter {
  const TimelinePainter({
    required this.timelineData,
    required this.style,
    this.deviceConfig,
  });

  final TimelineChartData timelineData;
  final MermaidStyle style;
  final MermaidDeviceConfig? deviceConfig;

  Color get _textColor =>
      Color(style.defaultNodeStyle.textColor ?? TimelineChartColors.textColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (timelineData.sections.isEmpty) return;
    var top = timelineData.diagramMarginY + timelineData.padding;
    if (timelineData.title case final title?) {
      _paintText(
        canvas,
        title,
        Offset(size.width / 2, top),
        maxWidth: math.max(1, size.width - timelineData.diagramMarginX * 2),
        centered: true,
        fontSize: math.max(18, timelineData.taskFontSize + 4),
        bold: true,
      );
      top += 44;
    }
    if (timelineData.direction == TimelineDirection.topDown) {
      _paintTopDown(canvas, size, top);
    } else {
      _paintLeftToRight(canvas, size, top);
    }
  }

  void _paintLeftToRight(Canvas canvas, Size size, double top) {
    final tasks = timelineData.allEvents;
    if (tasks.isEmpty) {
      _paintEmptySections(canvas, size, top);
      return;
    }
    final left = timelineData.diagramMarginX + timelineData.leftMargin;
    final right = size.width - timelineData.diagramMarginX;
    final slotWidth = math.max(1.0, (right - left) / tasks.length);
    final sectionTop = top;
    final sectionHeight = math.max(28.0, timelineData.height * .6);
    final taskTop = sectionTop + sectionHeight + timelineData.noteMargin;
    final taskHeight = math.max(36.0, timelineData.height.toDouble());
    final axisY = taskTop + taskHeight + timelineData.taskMargin;

    _drawAxis(
      canvas,
      Offset(left - slotWidth * .35, axisY),
      Offset(right, axisY),
    );

    var taskIndex = 0;
    for (
      var sectionIndex = 0;
      sectionIndex < timelineData.sections.length;
      sectionIndex++
    ) {
      final section = timelineData.sections[sectionIndex];
      final count = section.events.length;
      final span = math.max(1, count);
      final sectionLeft = left + taskIndex * slotWidth;
      final sectionWidth = slotWidth * span;
      if (section.title.isNotEmpty) {
        _drawSectionBand(
          canvas,
          Rect.fromLTWH(
            sectionLeft - slotWidth * .42,
            sectionTop,
            sectionWidth * .84,
            sectionHeight,
          ),
          section.title,
          sectionIndex,
        );
      }
      for (final task in section.events) {
        final x = left + (taskIndex + .5) * slotWidth;
        final color = _taskColor(taskIndex, sectionIndex);
        final cardWidth = math
            .min(
              timelineData.width.toDouble(),
              math.max(30, slotWidth - timelineData.boxMargin * 2),
            )
            .toDouble();
        _drawCard(
          canvas,
          Rect.fromCenter(
            center: Offset(x, taskTop + taskHeight / 2),
            width: cardWidth,
            height: taskHeight,
          ),
          task.title,
          color,
          bold: true,
        );
        _drawMarker(canvas, Offset(x, axisY), color);
        _drawConnector(
          canvas,
          Offset(x, taskTop + taskHeight),
          Offset(x, axisY),
          color,
        );
        _drawEventStack(
          canvas,
          task.periods,
          Offset(x, axisY + timelineData.taskMargin),
          cardWidth,
          color,
          vertical: true,
        );
        taskIndex++;
      }
    }
  }

  void _paintTopDown(Canvas canvas, Size size, double top) {
    final axisX = timelineData.diagramMarginX + timelineData.leftMargin;
    final taskWidth = math.max(40.0, timelineData.width.toDouble());
    final taskHeight = math.max(36.0, timelineData.height.toDouble());
    final rowGap = math.max(taskHeight + 20, timelineData.taskMargin);
    final totalRows = math.max(1, timelineData.allEvents.length);
    final bottom = math.min(
      size.height - timelineData.diagramMarginY,
      top +
          timelineData.sections.length * taskHeight +
          totalRows * rowGap +
          timelineData.bottomMarginAdj,
    );
    _drawAxis(canvas, Offset(axisX, top), Offset(axisX, bottom));

    var y = top;
    var taskIndex = 0;
    for (
      var sectionIndex = 0;
      sectionIndex < timelineData.sections.length;
      sectionIndex++
    ) {
      final section = timelineData.sections[sectionIndex];
      if (section.title.isNotEmpty) {
        _drawSectionBand(
          canvas,
          Rect.fromLTWH(
            timelineData.diagramMarginX,
            y,
            math.max(40, axisX - timelineData.diagramMarginX - 16),
            taskHeight * .72,
          ),
          section.title,
          sectionIndex,
        );
        y += taskHeight;
      }
      for (final task in section.events) {
        final color = _taskColor(taskIndex, sectionIndex);
        final center = Offset(axisX, y + taskHeight / 2);
        _drawMarker(canvas, center, color);
        final taskRect = Rect.fromLTWH(
          math.max(
            timelineData.diagramMarginX,
            axisX - timelineData.noteMargin - taskWidth,
          ),
          y,
          taskWidth,
          taskHeight,
        );
        _drawCard(canvas, taskRect, task.title, color, bold: true);
        _drawConnector(
          canvas,
          Offset(taskRect.right, taskRect.center.dy),
          center,
          color,
        );
        _drawEventStack(
          canvas,
          task.periods,
          Offset(axisX + timelineData.noteMargin, y),
          math.max(
            40,
            size.width -
                axisX -
                timelineData.noteMargin -
                timelineData.diagramMarginX,
          ),
          color,
          vertical: false,
        );
        y +=
            rowGap +
            math.max(0, task.periods.length - 1) *
                (taskHeight + timelineData.messageMargin);
        taskIndex++;
      }
    }
  }

  void _paintEmptySections(Canvas canvas, Size size, double top) {
    final width = math.max(
      1.0,
      (size.width - timelineData.diagramMarginX * 2) /
          timelineData.sections.length,
    );
    for (var index = 0; index < timelineData.sections.length; index++) {
      _drawSectionBand(
        canvas,
        Rect.fromLTWH(
          timelineData.diagramMarginX + index * width,
          top,
          width - timelineData.boxMargin,
          math.max(30, timelineData.height.toDouble()),
        ),
        timelineData.sections[index].title,
        index,
      );
    }
  }

  void _drawAxis(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..color = _textColor.withValues(alpha: .7)
      ..strokeWidth = math.max(2, timelineData.activationWidth / 3)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
    final vector = end - start;
    if (vector.distance == 0) return;
    final unit = vector / vector.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final tip = end;
    final back = end - unit * 12;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((back + normal * 6).dx, (back + normal * 6).dy)
      ..lineTo((back - normal * 6).dx, (back - normal * 6).dy)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  void _drawSectionBand(Canvas canvas, Rect rect, String label, int index) {
    final fill = _sectionColor(index);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(timelineData.boxMargin.toDouble().clamp(0, 12)),
      ),
      Paint()..color = fill,
    );
    final textColor = _sectionTextColor(index);
    _paintText(
      canvas,
      label,
      rect.center,
      maxWidth: math.max(1, rect.width - timelineData.boxTextMargin * 2),
      centered: true,
      bold: true,
      color: textColor,
    );
  }

  void _drawCard(
    Canvas canvas,
    Rect rect,
    String label,
    Color color, {
    bool bold = false,
  }) {
    final radius = Radius.circular(
      timelineData.boxMargin.toDouble().clamp(0, 12),
    );
    final shape = RRect.fromRectAndRadius(rect, radius);
    canvas
      ..drawRRect(shape, Paint()..color = color.withValues(alpha: .18))
      ..drawRRect(
        shape,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    _paintText(
      canvas,
      label,
      rect.center,
      maxWidth: math.max(1, rect.width - timelineData.boxTextMargin * 2),
      centered: true,
      bold: bold,
      color: _textColor,
    );
  }

  void _drawEventStack(
    Canvas canvas,
    List<String> events,
    Offset origin,
    double width,
    Color color, {
    required bool vertical,
  }) {
    if (events.isEmpty) return;
    final eventHeight = math.max(36.0, timelineData.height.toDouble());
    for (var index = 0; index < events.length; index++) {
      final rect = vertical
          ? Rect.fromLTWH(
              origin.dx - width / 2,
              origin.dy + index * (eventHeight + timelineData.messageMargin),
              width,
              eventHeight,
            )
          : Rect.fromLTWH(
              origin.dx,
              origin.dy + index * (eventHeight + timelineData.messageMargin),
              width,
              eventHeight,
            );
      _drawCard(canvas, rect, events[index], color);
      final target = vertical
          ? Offset(rect.center.dx, rect.top)
          : Offset(rect.left, rect.center.dy);
      _drawConnector(canvas, origin, target, color);
    }
  }

  void _drawMarker(Canvas canvas, Offset center, Color color) {
    final radius = math.max(4.0, timelineData.activationWidth / 2);
    canvas
      ..drawCircle(center, radius, Paint()..color = color)
      ..drawCircle(
        center,
        radius * .45,
        Paint()..color = Color(style.backgroundColor),
      );
  }

  void _drawConnector(Canvas canvas, Offset start, Offset end, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: .72)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (timelineData.rightAngles) {
      final path = Path()..moveTo(start.dx, start.dy);
      if (timelineData.direction == TimelineDirection.leftToRight) {
        path
          ..lineTo(start.dx, end.dy)
          ..lineTo(end.dx, end.dy);
      } else {
        path
          ..lineTo(end.dx, start.dy)
          ..lineTo(end.dx, end.dy);
      }
      canvas.drawPath(path, paint);
    } else {
      final path = Path()..moveTo(start.dx, start.dy);
      if (timelineData.direction == TimelineDirection.leftToRight) {
        final middle = (start.dy + end.dy) / 2;
        path.cubicTo(start.dx, middle, end.dx, middle, end.dx, end.dy);
      } else {
        final middle = (start.dx + end.dx) / 2;
        path.cubicTo(middle, start.dy, middle, end.dy, end.dx, end.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset anchor, {
    required double maxWidth,
    bool centered = false,
    bool bold = false,
    double? fontSize,
    Color? color,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? _textColor,
          fontSize: fontSize ?? timelineData.taskFontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          fontFamily: timelineData.taskFontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: switch (timelineData.messageAlign) {
        TimelineMessageAlign.left => TextAlign.left,
        TimelineMessageAlign.center => TextAlign.center,
        TimelineMessageAlign.right => TextAlign.right,
      },
      maxLines: timelineData.textPlacement == 'old' ? 1 : 4,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final offset = centered
        ? anchor - Offset(painter.width / 2, painter.height / 2)
        : anchor;
    painter.paint(canvas, offset);
  }

  Color _sectionColor(int index) {
    final values = timelineData.sectionFills;
    if (values.isEmpty) {
      return Color(TimelineChartColors.getColorForSection(index));
    }
    final selected = timelineData.disableMulticolor
        ? values.first
        : values[index % values.length];
    return parseMermaidCssColor(selected) ??
        Color(TimelineChartColors.getColorForSection(index));
  }

  Color _sectionTextColor(int index) {
    final values = timelineData.sectionColours;
    if (values.isEmpty) return _textColor;
    return parseMermaidCssColor(values[index % values.length]) ?? _textColor;
  }

  Color _taskColor(int taskIndex, int sectionIndex) {
    final values = timelineData.actorColours;
    if (values.isEmpty) return _sectionColor(sectionIndex);
    final index = timelineData.disableMulticolor
        ? 0
        : taskIndex % values.length;
    return parseMermaidCssColor(values[index]) ?? _sectionColor(sectionIndex);
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) =>
      oldDelegate.timelineData != timelineData ||
      oldDelegate.style != style ||
      oldDelegate.deviceConfig != deviceConfig;
}
