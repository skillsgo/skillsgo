/*
 * [INPUT]: Depends on Flutter Canvas, complete ER semantics/configuration/theme data, CSS colors, and Mermaid styles.
 * [OUTPUT]: Computes directional ER geometry and paints entity tables, typed attributes, keys/comments, relationship labels, dashed identity, and crow-foot cardinalities.
 * [POS]: Serves as the dedicated native layout and renderer for Mermaid ER diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/er_diagram.dart';
import '../models/style.dart';
import 'css_color.dart';

class ErChartLayout {
  const ErChartLayout();
  Size computeLayout(ErDiagramData data, Size available) {
    final horizontal =
        data.layoutDirection == 'LR' || data.layoutDirection == 'RL';
    final count = math.max(1, data.entities.length);
    final width =
        data.diagramPadding * 2 +
        (horizontal ? count : math.min(3, count)) *
            (data.minEntityWidth + data.nodeSpacing);
    final height =
        data.diagramPadding * 2 +
        (data.title == null ? 0 : 45) +
        (horizontal ? 1 : (count / 3).ceil()) *
            (data.minEntityHeight + data.rankSpacing + 80);
    return Size(
      data.useMaxWidth && available.width.isFinite
          ? math.max(width, available.width)
          : width,
      math.max(220, height),
    );
  }
}

class ErPainter extends CustomPainter {
  const ErPainter({required this.data, required this.style});
  final ErDiagramData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    var top = data.diagramPadding;
    if (data.title case final title?) {
      final label = _text(title, data.fontSize + 5, _textColor, bold: true)
        ..layout();
      label.paint(
        canvas,
        Offset((size.width - label.width) / 2, data.titleTopMargin),
      );
      top += 45;
    }
    final rects = _rects(size, top);
    for (final relation in data.relationships) {
      final from = rects[relation.from];
      final to = rects[relation.to];
      if (from != null && to != null) _relation(canvas, from, to, relation);
    }
    for (var index = 0; index < data.entities.length; index++) {
      _entity(
        canvas,
        data.entities[index],
        rects[data.entities[index].id]!,
        index,
      );
    }
  }

  Map<String, Rect> _rects(Size size, double top) {
    final horizontal =
        data.layoutDirection == 'LR' || data.layoutDirection == 'RL';
    final columns = horizontal
        ? math.max(1, data.entities.length)
        : math.min(3, math.max(1, data.entities.length));
    final rows = math.max(1, (data.entities.length / columns).ceil());
    final cellW = size.width / columns;
    final cellH = (size.height - top) / rows;
    final result = <String, Rect>{};
    for (var i = 0; i < data.entities.length; i++) {
      var col = i % columns;
      var row = i ~/ columns;
      if (data.layoutDirection == 'RL') col = columns - col - 1;
      if (data.layoutDirection == 'BT') row = rows - row - 1;
      final entity = data.entities[i];
      final contentHeight =
          36 + entity.attributes.length * math.max(22, data.fontSize + 9);
      result[entity.id] = Rect.fromCenter(
        center: Offset((col + .5) * cellW, top + (row + .5) * cellH),
        width: math.min(cellW - 24, math.max(data.minEntityWidth, 160)),
        height: math.min(
          cellH - 24,
          math.max(data.minEntityHeight, contentHeight).toDouble(),
        ),
      );
    }
    return result;
  }

  void _entity(Canvas canvas, ErEntityData entity, Rect rect, int index) {
    final custom = _styleMap(entity);
    final fill =
        parseMermaidCssColor(custom['fill']) ??
        _array(data.theme.backgroundColors, index) ??
        parseMermaidCssColor(data.theme.mainBackground) ??
        parseMermaidCssColor(data.fill) ??
        const Color(0xfff0fff0);
    final border =
        parseMermaidCssColor(custom['stroke']) ??
        _array(data.theme.borderColors, index) ??
        parseMermaidCssColor(data.theme.nodeBorder) ??
        parseMermaidCssColor(data.stroke) ??
        Colors.grey;
    final textColor =
        parseMermaidCssColor(custom['color']) ??
        parseMermaidCssColor(data.theme.nodeTextColor) ??
        parseMermaidCssColor(data.theme.textColor) ??
        _textColor;
    final width = data.look == 'neo'
        ? data.theme.strokeWidth
        : _pixels(custom['stroke-width']) ?? 1;
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(data.look == 'neo' ? 8 : 2),
    );
    canvas.drawRRect(shape, Paint()..color = fill);
    canvas.drawRRect(
      shape,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
    final title = _text(entity.label, data.fontSize + 1, textColor, bold: true)
      ..layout(maxWidth: rect.width - data.entityPadding * 2);
    title.paint(
      canvas,
      Offset(rect.center.dx - title.width / 2, rect.top + data.entityPadding),
    );
    final divider = rect.top + data.entityPadding + title.height + 7;
    canvas.drawLine(
      Offset(rect.left, divider),
      Offset(rect.right, divider),
      Paint()..color = border,
    );
    var y = divider + 6;
    for (final attr in entity.attributes) {
      final keys = attr.keys
          .map(
            (key) => switch (key) {
              ErAttributeKey.primary => 'PK',
              ErAttributeKey.foreign => 'FK',
              ErAttributeKey.unique => 'UK',
            },
          )
          .join(',');
      final left = _text('${attr.type} ${attr.name}', data.fontSize, textColor)
        ..layout(maxWidth: rect.width * .55);
      left.paint(canvas, Offset(rect.left + data.entityPadding, y));
      final rightText = [
        if (keys.isNotEmpty) keys,
        if (attr.comment != null) attr.comment!,
      ].join(' · ');
      if (rightText.isNotEmpty) {
        final right = _text(
          rightText,
          math.max(9, data.fontSize - 1),
          textColor.withValues(alpha: .75),
        )..layout(maxWidth: rect.width * .35);
        right.paint(
          canvas,
          Offset(rect.right - data.entityPadding - right.width, y),
        );
      }
      y += math.max(22, data.fontSize + 9);
    }
  }

  void _relation(
    Canvas canvas,
    Rect from,
    Rect to,
    ErRelationshipData relation,
  ) {
    final start = _boundary(from, to.center);
    final end = _boundary(to, from.center);
    final color =
        parseMermaidCssColor(data.theme.lineColor) ??
        parseMermaidCssColor(data.stroke) ??
        Colors.grey;
    final paint = Paint()
      ..color = color
      ..strokeWidth = data.look == 'neo' ? data.theme.strokeWidth : 1;
    if (relation.identifying) {
      canvas.drawLine(start, end, paint);
    } else {
      final distance = (end - start).distance;
      final unit = (end - start) / math.max(1, distance);
      for (var d = 0.0; d < distance; d += 16) {
        canvas.drawLine(
          start + unit * d,
          start + unit * math.min(d + 8, distance),
          paint,
        );
      }
    }
    _cardinality(canvas, start, end, relation.fromCardinality, color);
    _cardinality(canvas, end, start, relation.toCardinality, color);
    final label = _text(relation.label, data.fontSize, _textColor)..layout();
    final center = (start + end) / 2;
    final background =
        parseMermaidCssColor(data.theme.erEdgeLabelBackground) ??
        parseMermaidCssColor(data.theme.edgeLabelBackground) ??
        parseMermaidCssColor(data.theme.tertiaryColor) ??
        Color(style.backgroundColor);
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: label.width + 8,
        height: label.height + 4,
      ),
      Paint()..color = background.withValues(alpha: .85),
    );
    label.paint(
      canvas,
      Offset(center.dx - label.width / 2, center.dy - label.height / 2),
    );
  }

  void _cardinality(
    Canvas canvas,
    Offset at,
    Offset toward,
    ErCardinality cardinality,
    Color color,
  ) {
    final angle = math.atan2(toward.dy - at.dy, toward.dx - at.dx);
    final f = Offset(math.cos(angle), math.sin(angle));
    final side = Offset(-f.dy, f.dx);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    final p = at + f * 8;
    if (cardinality == ErCardinality.zeroOrOne ||
        cardinality == ErCardinality.zeroOrMore) {
      canvas.drawCircle(p, 4, paint);
    }
    if (cardinality == ErCardinality.exactlyOne ||
        cardinality == ErCardinality.zeroOrOne) {
      canvas.drawLine(p + f * 7 + side * 6, p + f * 7 - side * 6, paint);
    } else if (cardinality == ErCardinality.oneOrMore ||
        cardinality == ErCardinality.zeroOrMore) {
      final base = p + f * 9;
      canvas.drawLine(base, base + f * 11, paint);
      canvas.drawLine(base, base + f * 11 + side * 8, paint);
      canvas.drawLine(base, base + f * 11 - side * 8, paint);
    }
  }

  Offset _boundary(Rect rect, Offset toward) {
    final v = toward - rect.center;
    if (v.dx.abs() * rect.height > v.dy.abs() * rect.width) {
      final x = v.dx >= 0 ? rect.right : rect.left;
      return Offset(
        x,
        rect.center.dy + v.dy * rect.width / 2 / math.max(1, v.dx.abs()),
      );
    }
    final y = v.dy >= 0 ? rect.bottom : rect.top;
    return Offset(
      rect.center.dx + v.dx * rect.height / 2 / math.max(1, v.dy.abs()),
      y,
    );
  }

  Map<String, String> _styleMap(ErEntityData entity) {
    final result = <String, String>{};
    for (final source in [
      for (final c in entity.cssClasses) ?data.classDefinitions[c],
      ?entity.rawStyle,
    ]) {
      for (final part in source.split(',')) {
        final i = part.indexOf(':');
        if (i > 0) {
          result[part.substring(0, i).trim()] = part.substring(i + 1).trim();
        }
      }
    }
    return result;
  }

  Color? _array(List<String> values, int index) => values.isEmpty
      ? null
      : parseMermaidCssColor(values[index % values.length]);
  double? _pixels(String? value) => double.tryParse(
    RegExp(r'[\d.]+').firstMatch(value ?? '')?.group(0) ?? '',
  );
  Color get _textColor => Color(style.defaultNodeStyle.textColor ?? 0xff333333);
  TextPainter _text(
    String value,
    double size,
    Color color, {
    bool bold = false,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: style.fontFamily,
        fontWeight: bold ? FontWeight.w600 : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  @override
  bool shouldRepaint(covariant ErPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}
