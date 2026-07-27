/*
 * [INPUT]: Depends on Flutter Canvas, complete Journey semantics/configuration, CSS colors, and Mermaid styles.
 * [OUTPUT]: Computes and paints native Journey legends, sections, tasks, score faces, actor attachments, activity axis, and configured typography.
 * [POS]: Serves as the chart-specific layout and rendering engine for Mermaid Journey diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/journey.dart';
import '../models/style.dart';
import 'css_color.dart';

class JourneyChartLayout {
  const JourneyChartLayout();

  Size computeLayout(JourneyChartData data, Size available) {
    final actorWidth = data.actors.isEmpty
        ? 0.0
        : math.min(data.maxLabelWidth, 28 + _widestActor(data));
    final taskSpan = data.tasks.isEmpty
        ? data.width
        : data.tasks.length * data.width +
              math.max(0, data.tasks.length - 1) * data.taskMargin;
    final intrinsicWidth =
        data.diagramMarginX * 2 + data.leftMargin + actorWidth + taskSpan;
    final titleHeight = data.title == null ? 0.0 : 48.0;
    final intrinsicHeight =
        data.diagramMarginY * 2 +
        titleHeight +
        data.height * 2 +
        data.noteMargin +
        data.messageMargin +
        30 * 6 +
        data.boxMargin * 2 +
        data.bottomMarginAdj;
    final width = data.useMaxWidth && available.width.isFinite
        ? math.max(320.0, available.width)
        : intrinsicWidth;
    return Size(
      math.max(width, intrinsicWidth),
      math.max(260, intrinsicHeight),
    );
  }

  double _widestActor(JourneyChartData data) {
    var width = 0.0;
    for (final actor in data.actors) {
      final painter = TextPainter(
        text: TextSpan(
          text: actor,
          style: TextStyle(
            fontSize: data.taskFontSize,
            fontFamily: data.taskFontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: data.maxLabelWidth);
      width = math.max(width, painter.width);
    }
    return width;
  }
}

class JourneyPainter extends CustomPainter {
  const JourneyPainter({required this.data, required this.style});

  final JourneyChartData data;
  final MermaidStyle style;

  static const _fills = <Color>[
    Color(0xffECECFF),
    Color(0xffffe0e0),
    Color(0xffe0ffe0),
    Color(0xfffff0d0),
    Color(0xffe0f4ff),
    Color(0xfff1e0ff),
    Color(0xffffe8c8),
    Color(0xffdff7f4),
  ];
  static const _actors = <Color>[
    Color(0xff8FBC8F),
    Color(0xff7C9FD4),
    Color(0xffD98C8C),
    Color(0xffC69BD3),
    Color(0xffE2B66B),
    Color(0xff68B7B2),
  ];

  Color get _text =>
      parseMermaidCssColor(data.theme.textColor) ??
      Color(style.defaultNodeStyle.textColor ?? 0xff333333);
  Color get _line => parseMermaidCssColor(data.theme.lineColor) ?? _text;

  @override
  void paint(Canvas canvas, Size size) {
    var top = data.diagramMarginY;
    if (data.title case final title?) {
      _textPainter(
        title,
        fontSize: _titleSize(),
        bold: true,
        color:
            parseMermaidCssColor(data.titleColor) ??
            parseMermaidCssColor(data.theme.titleColor) ??
            _text,
        family: data.titleFontFamily,
      ).paint(canvas, Offset(size.width / 2, top), centered: true);
      top += 48;
    }

    final actorLegendWidth = _paintLegend(canvas, top);
    final left = data.diagramMarginX + data.leftMargin + actorLegendWidth;
    final taskTop = top + data.height + data.noteMargin;
    final axisY = taskTop + data.height + data.messageMargin;
    _paintSections(canvas, left, top);
    _paintAxis(canvas, left, axisY);
    for (var index = 0; index < data.tasks.length; index++) {
      _paintTask(canvas, data.tasks[index], left, taskTop, axisY);
    }
  }

  double _paintLegend(Canvas canvas, double top) {
    if (data.actors.isEmpty) return 0;
    var widest = 0.0;
    for (var index = 0; index < data.actors.length; index++) {
      final y = top + 12 + index * (data.taskFontSize + data.boxTextMargin + 8);
      final color = _actorColor(index);
      canvas.drawCircle(
        Offset(data.diagramMarginX + 7, y + 7),
        7,
        Paint()..color = color,
      );
      final label = _textPainter(data.actors[index], color: _text);
      label.layout(maxWidth: data.maxLabelWidth);
      label.paint(canvas, Offset(data.diagramMarginX + 22, y));
      widest = math.max(widest, label.width + 30);
    }
    return math.min(data.maxLabelWidth, widest);
  }

  void _paintSections(Canvas canvas, double left, double top) {
    var task = 0;
    while (task < data.tasks.length) {
      final sectionIndex = data.tasks[task].sectionIndex;
      var end = task + 1;
      while (end < data.tasks.length &&
          data.tasks[end].sectionIndex == sectionIndex) {
        end++;
      }
      if (sectionIndex != null && sectionIndex < data.sections.length) {
        final x = left + task * (data.width + data.taskMargin);
        final width =
            (end - task) * data.width +
            math.max(0, end - task - 1) * data.taskMargin;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, width, data.height),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, Paint()..color = _fillColor(sectionIndex));
        canvas.drawRRect(
          rect,
          Paint()
            ..color = parseMermaidCssColor(data.theme.nodeBorder) ?? _line
            ..style = PaintingStyle.stroke,
        );
        final color = _sectionTextColor(sectionIndex);
        final label = _textPainter(
          data.sections[sectionIndex].title,
          color: color,
          bold: true,
        )..layout(maxWidth: math.max(1, width - data.boxTextMargin * 2));
        label.paint(
          canvas,
          Offset(x + width / 2, top + data.height / 2),
          centered: true,
        );
      }
      task = end;
    }
  }

  void _paintAxis(Canvas canvas, double left, double y) {
    final right = data.tasks.isEmpty
        ? left + data.width
        : left +
              data.tasks.length * data.width +
              math.max(0, data.tasks.length - 1) * data.taskMargin;
    final paint = Paint()
      ..color = _line
      ..strokeWidth = math.max(1, data.activationWidth / 5);
    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    canvas.drawPath(
      Path()
        ..moveTo(right, y)
        ..lineTo(right - 9, y - 5)
        ..lineTo(right - 9, y + 5)
        ..close(),
      paint,
    );
  }

  void _paintTask(
    Canvas canvas,
    JourneyTaskData task,
    double left,
    double taskTop,
    double axisY,
  ) {
    final x = left + task.index * (data.width + data.taskMargin);
    final center = x + data.width / 2;
    final fill = _fillColor(task.sectionIndex ?? task.index);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, taskTop, data.width, data.height),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = parseMermaidCssColor(data.theme.nodeBorder) ?? _line
        ..style = PaintingStyle.stroke,
    );
    final label = _textPainter(task.name, color: _text, bold: true)
      ..layout(maxWidth: math.max(1, data.width - data.boxTextMargin * 2));
    final labelX = switch (data.messageAlign) {
      JourneyMessageAlign.left => x + data.boxTextMargin,
      JourneyMessageAlign.center => center,
      JourneyMessageAlign.right => x + data.width - data.boxTextMargin,
    };
    label.paint(
      canvas,
      Offset(labelX, taskTop + data.height / 2),
      centered: data.messageAlign == JourneyMessageAlign.center,
      rightAligned: data.messageAlign == JourneyMessageAlign.right,
    );

    final dash = Paint()
      ..color = _line
      ..strokeWidth = 1;
    for (var y = taskTop + data.height; y < axisY + 180; y += 6) {
      canvas.drawLine(Offset(center, y), Offset(center, y + 4), dash);
    }
    final scoreY = axisY + (5 - task.score) * 30;
    _paintFace(canvas, Offset(center, scoreY), task.score);
    for (var index = 0; index < task.actors.length; index++) {
      final actorIndex = data.actors.indexOf(task.actors[index]);
      if (actorIndex < 0) continue;
      final markerX = x + 14 + index * 18;
      final color = _actorColor(actorIndex);
      final radius = math.max(4.0, math.min(9.0, data.activationWidth * .7));
      canvas.drawCircle(
        Offset(markerX, taskTop),
        radius,
        Paint()..color = color,
      );
      final target = Offset(center, axisY + 20 + actorIndex * 24);
      final path = Path()..moveTo(markerX, taskTop);
      if (data.rightAngles) {
        path
          ..lineTo(markerX, target.dy)
          ..lineTo(target.dx, target.dy);
      } else {
        path.quadraticBezierTo(markerX, target.dy, target.dx, target.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, data.activationWidth / 5),
      );
      canvas.drawCircle(target, radius, Paint()..color = color);
    }
  }

  void _paintFace(Canvas canvas, Offset center, double score) {
    final face =
        parseMermaidCssColor(data.theme.faceColor) ?? const Color(0xfffff8dc);
    canvas.drawCircle(center, 15, Paint()..color = face);
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..color = const Color(0xff999999)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final ink = Paint()
      ..color = const Color(0xff666666)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      center.translate(-5, -5),
      1.5,
      ink..style = PaintingStyle.fill,
    );
    canvas.drawCircle(center.translate(5, -5), 1.5, ink);
    ink.style = PaintingStyle.stroke;
    final mouth = Path();
    if (score > 3) {
      mouth.moveTo(center.dx - 6, center.dy + 2);
      mouth.quadraticBezierTo(
        center.dx,
        center.dy + 10,
        center.dx + 6,
        center.dy + 2,
      );
    } else if (score < 3) {
      mouth.moveTo(center.dx - 6, center.dy + 8);
      mouth.quadraticBezierTo(
        center.dx,
        center.dy,
        center.dx + 6,
        center.dy + 8,
      );
    } else {
      mouth.moveTo(center.dx - 5, center.dy + 7);
      mouth.lineTo(center.dx + 5, center.dy + 7);
    }
    canvas.drawPath(mouth, ink);
  }

  Color _fillColor(int index) =>
      _atColor(data.theme.fillColors, index) ??
      _atColor(data.sectionFills, index) ??
      _fills[index % _fills.length];
  Color _actorColor(int index) =>
      _atColor(data.theme.actorColors, index) ??
      _atColor(data.actorColors, index) ??
      _actors[index % _actors.length];
  Color _sectionTextColor(int index) =>
      _atColor(data.theme.sectionTextColors, index) ??
      _atColor(data.sectionColors, index) ??
      _text;

  Color? _atColor(List<Object?> colors, int index) => colors.isEmpty
      ? null
      : parseMermaidCssColor(colors[index % colors.length]?.toString());

  double _titleSize() {
    final match = RegExp(r'[\d.]+').firstMatch(data.titleFontSize);
    final value = double.tryParse(match?.group(0) ?? '');
    if (value == null) return 24;
    return data.titleFontSize.toLowerCase().contains('ex') ? value * 8 : value;
  }

  _JourneyText _textPainter(
    String value, {
    Color? color,
    double? fontSize,
    bool bold = false,
    String? family,
  }) => _JourneyText(
    value,
    TextStyle(
      color: color ?? _text,
      fontSize: fontSize ?? data.taskFontSize,
      fontFamily: family ?? data.taskFontFamily,
      fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
    ),
  );

  @override
  bool shouldRepaint(covariant JourneyPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}

class _JourneyText {
  _JourneyText(String text, TextStyle style)
    : _painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
  final TextPainter _painter;
  bool _laidOut = false;
  double get width => _painter.width;
  void layout({double maxWidth = double.infinity}) {
    _painter.layout(maxWidth: maxWidth);
    _laidOut = true;
  }

  void paint(
    Canvas canvas,
    Offset offset, {
    bool centered = false,
    bool rightAligned = false,
  }) {
    if (_laidOut) {
      final dx = centered
          ? offset.dx - _painter.width / 2
          : rightAligned
          ? offset.dx - _painter.width
          : offset.dx;
      final dy = centered ? offset.dy - _painter.height / 2 : offset.dy;
      _painter.paint(canvas, Offset(dx, dy));
      return;
    }
    layout();
    paint(canvas, offset, centered: centered, rightAligned: rightAligned);
  }
}
