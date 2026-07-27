/*
 * [INPUT]: Depends on Flutter Canvas, Mermaid semantic style, and the unified Railroad/EBNF/ABNF/PEG AST.
 * [OUTPUT]: Paints named rules with markers, tracks, terminals, nonterminals, choices, optionals, repetitions, specials, and PEG predicates.
 * [POS]: Serves as the shared native painter for all four Mermaid Railroad variants.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/railroad.dart';
import '../models/style.dart';
import 'css_color.dart';

class RailroadPainter extends CustomPainter {
  const RailroadPainter({required this.data, required this.style});
  final RailroadChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    var y = data.padding + (data.title == null ? 20.0 : 50.0);
    if (data.title case final title?) {
      final titlePainter = _textPainter(
        title,
        data.fontSize + 4,
        FontWeight.w700,
      )..layout();
      titlePainter.paint(
        canvas,
        Offset((size.width - titlePainter.width) / 2, data.padding),
      );
    }
    for (final rule in data.rules) {
      final rowHeight = _height(rule.definition) + (data.compactMode ? 25 : 46);
      _text(
        canvas,
        rule.name,
        Offset(data.padding, y),
        data.fontSize,
        FontWeight.w700,
        color: _color(data.ruleNameColor, _textColor),
      );
      final centerY =
          y + (data.compactMode ? 18 : 28) + _height(rule.definition) / 2;
      final startX = data.padding + (data.compactMode ? 100 : 132);
      final endX =
          startX + _width(rule.definition) + data.horizontalSeparation * 2;
      final track = _trackPaint();
      if (data.showMarkers) {
        canvas.drawCircle(
          Offset(startX - data.markerRadius * 3, centerY),
          data.markerRadius,
          Paint()..color = _color(data.markerFill, track.color),
        );
      }
      canvas.drawLine(
        Offset(
          startX - (data.showMarkers ? data.markerRadius * 2 : 0),
          centerY,
        ),
        Offset(startX, centerY),
        track,
      );
      _drawExpression(canvas, rule.definition, Offset(startX, centerY));
      canvas.drawLine(
        Offset(startX + _width(rule.definition), centerY),
        Offset(endX, centerY),
        track,
      );
      if (data.showMarkers) {
        canvas.drawCircle(
          Offset(endX + 5, centerY),
          data.markerRadius + 1,
          Paint()
            ..color = _color(data.markerFill, track.color)
            ..style = PaintingStyle.stroke
            ..strokeWidth = data.strokeWidth,
        );
      }
      y += rowHeight;
    }
  }

  void _drawExpression(
    Canvas canvas,
    RailroadExpression expression,
    Offset origin,
  ) {
    switch (expression.kind) {
      case RailroadExpressionKind.terminal:
      case RailroadExpressionKind.nonTerminal:
      case RailroadExpressionKind.special:
        _drawLeaf(canvas, expression, origin);
      case RailroadExpressionKind.sequence:
        var x = origin.dx;
        for (var index = 0; index < expression.children.length; index++) {
          final child = expression.children[index];
          _drawExpression(canvas, child, Offset(x, origin.dy));
          x += _width(child);
          if (index < expression.children.length - 1) {
            canvas.drawLine(
              Offset(x, origin.dy),
              Offset(x + data.horizontalSeparation, origin.dy),
              _trackPaint(),
            );
            x += data.horizontalSeparation;
          }
        }
      case RailroadExpressionKind.choice:
        _drawChoice(canvas, expression, origin);
      case RailroadExpressionKind.optional:
        _drawWrapped(canvas, expression, origin, bypass: true, loop: false);
      case RailroadExpressionKind.repetition:
        _drawWrapped(
          canvas,
          expression,
          origin,
          bypass: expression.min == 0,
          loop: true,
        );
      case RailroadExpressionKind.predicate:
        _drawExpression(
          canvas,
          expression.children.single,
          Offset(origin.dx + data.horizontalSeparation * 2, origin.dy),
        );
        _text(
          canvas,
          expression.text == '!' ? 'not' : 'and',
          Offset(origin.dx, origin.dy - 8),
          9,
          FontWeight.w600,
        );
    }
  }

  void _drawLeaf(Canvas canvas, RailroadExpression expression, Offset origin) {
    final rect = Rect.fromCenter(
      center: Offset(origin.dx + _width(expression) / 2, origin.dy),
      width: _width(expression),
      height: data.fontSize + data.padding * 2,
    );
    final terminal = expression.kind == RailroadExpressionKind.terminal;
    final special = expression.kind == RailroadExpressionKind.special;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(
          terminal
              ? data.arcRadius
              : special
              ? 3
              : 6,
        ),
      ),
      Paint()
        ..color = special
            ? _color(data.specialFill, const Color(0xfff0e0ff))
            : terminal
            ? _color(data.terminalFill, const Color(0xffffffc0))
            : _color(data.nonTerminalFill, _nodeFill)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(terminal ? data.arcRadius : 5),
      ),
      Paint()
        ..color = special
            ? _color(data.specialStroke, _lineColor)
            : terminal
            ? _color(data.terminalStroke, _lineColor)
            : _color(data.nonTerminalStroke, _lineColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = data.strokeWidth,
    );
    _centerText(
      canvas,
      expression.text ?? '',
      rect,
      color: terminal
          ? _color(data.terminalTextColor, _textColor)
          : special
          ? _color(data.commentTextColor, _textColor)
          : _color(data.nonTerminalTextColor, _textColor),
    );
  }

  void _drawChoice(
    Canvas canvas,
    RailroadExpression expression,
    Offset origin,
  ) {
    final track = _trackPaint();
    var top = origin.dy - _height(expression) / 2;
    for (final child in expression.children) {
      final y = top + _height(child) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..cubicTo(
            origin.dx + data.arcRadius,
            origin.dy,
            origin.dx + data.arcRadius,
            y,
            origin.dx + data.arcRadius * 2,
            y,
          ),
        track,
      );
      _drawExpression(canvas, child, Offset(origin.dx + data.arcRadius * 2, y));
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx + data.arcRadius * 2 + _width(child), y)
          ..cubicTo(
            origin.dx + _width(expression) - data.arcRadius,
            y,
            origin.dx + _width(expression) - data.arcRadius,
            origin.dy,
            origin.dx + _width(expression),
            origin.dy,
          ),
        track,
      );
      top += _height(child) + data.verticalSeparation;
    }
  }

  void _drawWrapped(
    Canvas canvas,
    RailroadExpression expression,
    Offset origin, {
    required bool bypass,
    required bool loop,
  }) {
    final child = expression.children.single;
    final childOrigin = Offset(
      origin.dx + data.horizontalSeparation,
      origin.dy,
    );
    canvas.drawLine(origin, childOrigin, _trackPaint());
    _drawExpression(canvas, child, childOrigin);
    canvas.drawLine(
      Offset(childOrigin.dx + _width(child), origin.dy),
      Offset(origin.dx + _width(expression), origin.dy),
      _trackPaint(),
    );
    if (bypass) {
      final y = origin.dy - _height(child) / 2 - data.verticalSeparation;
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..quadraticBezierTo(
            origin.dx + data.arcRadius,
            y,
            origin.dx + data.arcRadius * 2,
            y,
          )
          ..lineTo(origin.dx + _width(expression) - data.arcRadius * 2, y)
          ..quadraticBezierTo(
            origin.dx + _width(expression) - data.arcRadius,
            y,
            origin.dx + _width(expression),
            origin.dy,
          ),
        _trackPaint(),
      );
    }
    if (loop) {
      final y = origin.dy + _height(child) / 2 + data.verticalSeparation;
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx + _width(expression) - data.arcRadius, origin.dy)
          ..quadraticBezierTo(
            origin.dx + _width(expression) - data.arcRadius,
            y,
            origin.dx + _width(expression) - data.arcRadius * 2,
            y,
          )
          ..lineTo(origin.dx + data.arcRadius * 2, y)
          ..quadraticBezierTo(
            origin.dx + data.arcRadius,
            y,
            origin.dx + data.arcRadius,
            origin.dy,
          ),
        _trackPaint(),
      );
      final range = expression.max == null
          ? '${expression.min ?? 0}..∞'
          : '${expression.min ?? 0}..${expression.max}';
      _text(
        canvas,
        range,
        Offset(origin.dx + _width(expression) / 2 - 14, y - 12),
        9,
        FontWeight.w400,
      );
    }
  }

  Paint _trackPaint() => Paint()
    ..color = _lineColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = data.strokeWidth;

  void _centerText(
    Canvas canvas,
    String text,
    Rect rect, {
    required Color color,
  }) {
    final painter = _textPainter(
      text,
      data.fontSize,
      FontWeight.w500,
      color: color,
    )..layout(maxWidth: rect.width - 12);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    FontWeight weight, {
    Color? color,
  }) {
    final painter = _textPainter(text, size, weight, color: color)..layout();
    painter.paint(canvas, offset);
  }

  TextPainter _textPainter(
    String text,
    double size,
    FontWeight weight, {
    Color? color,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color ?? _textColor,
        fontSize: size,
        fontWeight: weight,
        fontFamily: data.fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  );

  double _width(RailroadExpression expression) {
    final scale = data.fontSize / 14;
    return switch (expression.kind) {
      RailroadExpressionKind.terminal ||
      RailroadExpressionKind.nonTerminal ||
      RailroadExpressionKind.special =>
        expression.estimatedWidth * scale + data.padding * 2,
      RailroadExpressionKind.sequence =>
        expression.children.fold<double>(
              0,
              (sum, child) => sum + _width(child),
            ) +
            math.max(0, expression.children.length - 1) *
                data.horizontalSeparation,
      RailroadExpressionKind.choice =>
        expression.children.fold<double>(
              0,
              (largest, child) => math.max(largest, _width(child)),
            ) +
            data.arcRadius * 4,
      RailroadExpressionKind.optional ||
      RailroadExpressionKind.repetition ||
      RailroadExpressionKind.predicate =>
        _width(expression.children.single) + data.horizontalSeparation * 2,
    };
  }

  double _height(RailroadExpression expression) {
    final scale = data.fontSize / 14;
    return switch (expression.kind) {
      RailroadExpressionKind.terminal ||
      RailroadExpressionKind.nonTerminal ||
      RailroadExpressionKind.special => 34 * scale + data.padding,
      RailroadExpressionKind.sequence => expression.children.fold<double>(
        34 * scale,
        (largest, child) => math.max(largest, _height(child)),
      ),
      RailroadExpressionKind.choice =>
        expression.children.fold<double>(
              0,
              (sum, child) => sum + _height(child),
            ) +
            math.max(0, expression.children.length - 1) *
                data.verticalSeparation,
      RailroadExpressionKind.optional || RailroadExpressionKind.repetition =>
        _height(expression.children.single) + data.verticalSeparation * 2,
      RailroadExpressionKind.predicate => _height(expression.children.single),
    };
  }

  Color _color(String value, Color fallback) =>
      parseMermaidCssColor(value) ?? fallback;
  Color get _nodeFill =>
      Color(style.defaultNodeStyle.fillColor ?? MermaidColors.defaultNodeFill);
  Color get _textColor =>
      Color(style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor);
  Color get _lineColor => _color(
    data.lineColor,
    Color(style.defaultEdgeStyle.strokeColor ?? MermaidColors.defaultEdgeColor),
  );

  @override
  bool shouldRepaint(RailroadPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}
