/*
 * [INPUT]: Depends on laid-out C4 elements, compound boundaries, relationships, style overrides, renderer configuration, and Mermaid styles.
 * [OUTPUT]: Paints all five C4 variants natively with stereotypes, people/databases/queues, nested boundaries, directed relationships, and configured typography/colors.
 * [POS]: Serves as the dedicated Flutter Canvas presentation layer for Mermaid C4 diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/c4.dart';
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/style.dart';

class C4Painter extends CustomPainter {
  const C4Painter({
    required this.diagram,
    required this.data,
    required this.style,
  });

  final MermaidDiagramData diagram;
  final C4ChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(style.backgroundColor),
    );
    final nodes = {for (final node in diagram.nodes) node.id: node};
    final boundaryRects = _boundaryRects(nodes);
    _drawBoundaries(canvas, boundaryRects);
    for (final relation in data.relations) {
      _drawRelation(canvas, relation, nodes);
    }
    for (final element in data.elements) {
      final node = nodes[element.id];
      if (node != null) _drawElement(canvas, node, element);
    }
    final title = data.title ?? diagram.title;
    if (title != null && title.isNotEmpty) {
      _text(canvas, title, Offset(size.width / 2, 18), 20, bold: true);
    }
  }

  Map<String, Rect> _boundaryRects(Map<String, MermaidNode> nodes) {
    final result = <String, Rect>{};
    for (final subgraph in diagram.subgraphs.reversed) {
      final members = subgraph.nodeIds
          .map((id) => nodes[id])
          .whereType<MermaidNode>()
          .map(
            (node) => Rect.fromCenter(
              center: Offset(node.x, node.y),
              width: node.width,
              height: node.height,
            ),
          )
          .toList();
      if (members.isEmpty) continue;
      final margin =
          _number('boxMargin', 10) + _number('c4ShapeMargin', 50) / 2;
      result[subgraph.id] = members
          .reduce((a, b) => a.expandToInclude(b))
          .inflate(margin);
    }
    return result;
  }

  void _drawBoundaries(Canvas canvas, Map<String, Rect> rects) {
    for (final boundary in data.boundaries) {
      final rect = rects[boundary.id];
      if (rect == null) continue;
      final paint = Paint()
        ..color = _css(
          boundary.style.borderColor,
          style.defaultNodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke,
        )
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final background = boundary.style.backgroundColor;
      if (background != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          Paint()..color = _css(background, 0x00000000),
        );
      }
      if (boundary.nodeType == null) {
        _dashedRect(canvas, rect, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          paint,
        );
      }
      _text(
        canvas,
        '${boundary.label} [${boundary.stereotype}]',
        Offset(rect.left + 8, rect.top + 12),
        _fontSize('boundary', 14),
        left: true,
        weight: _fontWeight('boundary'),
        fontFamily: _fontFamily('boundary'),
      );
    }
  }

  void _drawElement(Canvas canvas, MermaidNode node, C4ElementData element) {
    final rect = Rect.fromCenter(
      center: Offset(node.x, node.y),
      width: node.width,
      height: node.height,
    );
    final type = element.stereotype;
    final external = type.startsWith('external_');
    final fill = _css(
      element.style.backgroundColor ?? _string('${type}_bg_color'),
      external
          ? 0xFF777777
          : style.defaultNodeStyle.fillColor ?? MermaidColors.defaultNodeFill,
    );
    final border = _css(
      element.style.borderColor ?? _string('${type}_border_color'),
      style.defaultNodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke,
    );
    if (element.style.shadowing == true) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.shift(const Offset(4, 4)),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0x33000000),
      );
    }
    final shape = element.style.shape ?? type;
    final fillPaint = Paint()..color = fill;
    final strokePaint = Paint()
      ..color = border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (shape.contains('db')) {
      _cylinder(canvas, rect, fillPaint, strokePaint);
    } else if (shape.contains('queue')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
        strokePaint,
      );
    } else if (shape.contains('person')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        strokePaint,
      );
      final head = Offset(rect.center.dx, rect.top + 19);
      canvas.drawCircle(head, 8, strokePaint);
      canvas.drawLine(
        Offset(head.dx, head.dy + 8),
        Offset(head.dx, head.dy + 29),
        strokePaint,
      );
      canvas.drawLine(
        Offset(head.dx - 12, head.dy + 17),
        Offset(head.dx + 12, head.dy + 17),
        strokePaint,
      );
    } else {
      final radius = shape == 'rounded' ? 16.0 : 5.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        strokePaint,
      );
    }
    final textColor = _css(
      element.style.fontColor,
      external
          ? 0xFFFFFFFF
          : style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor,
    );
    final lines = <String>[
      '«${element.stereotype}»',
      if (element.sprite != null) '[${element.sprite}]',
      element.label,
      if ((element.style.technology ?? element.technology)?.isNotEmpty == true)
        '[${element.style.technology ?? element.technology}]',
      if (element.description?.isNotEmpty == true) element.description!,
      if (element.tags?.isNotEmpty == true) element.tags!,
    ];
    _text(
      canvas,
      lines.join('\n'),
      rect.center,
      _fontSize(type, 14),
      color: textColor,
      weight: _fontWeight(type),
      fontFamily: _fontFamily(type),
      maxWidth: data.setting('wrap') == true
          ? rect.width -
                _number('c4ShapePadding', 20) * 2 -
                _number('wrapPadding', 10) * 2
          : 1000,
    );
  }

  void _drawRelation(
    Canvas canvas,
    C4RelationData relation,
    Map<String, MermaidNode> nodes,
  ) {
    final from = nodes[relation.from];
    final to = nodes[relation.to];
    if (from == null || to == null) return;
    final startCenter = Offset(from.x, from.y);
    final endCenter = Offset(to.x, to.y);
    final start = _rectEdge(from, endCenter);
    final end = _rectEdge(to, startCenter);
    final paint = Paint()
      ..color = _css(
        relation.lineColor,
        style.defaultEdgeStyle.strokeColor ?? MermaidColors.defaultEdgeColor,
      )
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(start.dx, start.dy);
    if (relation.direction == C4RelationDirection.left ||
        relation.direction == C4RelationDirection.right) {
      path.lineTo(end.dx, start.dy);
    } else if (relation.direction == C4RelationDirection.up ||
        relation.direction == C4RelationDirection.down) {
      path.lineTo(start.dx, end.dy);
    }
    path.lineTo(end.dx, end.dy);
    canvas.drawPath(path, paint);
    _arrow(canvas, end, start, paint.color);
    if (relation.bidirectional) _arrow(canvas, start, end, paint.color);
    final label = [
      if (relation.index != null) '${relation.index}.',
      relation.label,
      if (relation.technology?.isNotEmpty == true) '[${relation.technology}]',
      if (relation.description?.isNotEmpty == true) relation.description!,
    ].join(' ');
    _text(
      canvas,
      label,
      Offset(
        (start.dx + end.dx) / 2 + relation.offsetX,
        (start.dy + end.dy) / 2 + relation.offsetY,
      ),
      _fontSize('message', 14),
      color: _css(relation.textColor, MermaidColors.defaultTextColor),
      weight: _fontWeight('message'),
      fontFamily: _fontFamily('message'),
      background: true,
    );
  }

  Offset _rectEdge(MermaidNode node, Offset toward) {
    final center = Offset(node.x, node.y);
    final dx = toward.dx - center.dx;
    final dy = toward.dy - center.dy;
    if (dx == 0 && dy == 0) return center;
    final scale = math.min(
      dx == 0 ? double.infinity : node.width / 2 / dx.abs(),
      dy == 0 ? double.infinity : node.height / 2 / dy.abs(),
    );
    return Offset(center.dx + dx * scale, center.dy + dy * scale);
  }

  void _arrow(Canvas canvas, Offset tip, Offset previous, Color color) {
    final angle = math.atan2(tip.dy - previous.dy, tip.dx - previous.dx);
    const length = 10.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - length * math.cos(angle - .5),
        tip.dy - length * math.sin(angle - .5),
      )
      ..lineTo(
        tip.dx - length * math.cos(angle + .5),
        tip.dy - length * math.sin(angle + .5),
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _cylinder(Canvas canvas, Rect rect, Paint fill, Paint stroke) {
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.top + 8, rect.right, rect.bottom - 8),
      fill,
    );
    canvas.drawOval(Rect.fromLTWH(rect.left, rect.top, rect.width, 16), fill);
    canvas.drawOval(
      Rect.fromLTWH(rect.left, rect.bottom - 16, rect.width, 16),
      fill,
    );
    canvas.drawOval(Rect.fromLTWH(rect.left, rect.top, rect.width, 16), stroke);
    canvas.drawLine(
      Offset(rect.left, rect.top + 8),
      Offset(rect.left, rect.bottom - 8),
      stroke,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top + 8),
      Offset(rect.right, rect.bottom - 8),
      stroke,
    );
    canvas.drawArc(
      Rect.fromLTWH(rect.left, rect.bottom - 16, rect.width, 16),
      0,
      math.pi,
      false,
      stroke,
    );
  }

  void _dashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    void segment(Offset start, Offset end) {
      final vector = end - start;
      final length = vector.distance;
      final unit = vector / length;
      for (var offset = 0.0; offset < length; offset += dash + gap) {
        canvas.drawLine(
          start + unit * offset,
          start + unit * math.min(length, offset + dash),
          paint,
        );
      }
    }

    segment(rect.topLeft, rect.topRight);
    segment(rect.topRight, rect.bottomRight);
    segment(rect.bottomRight, rect.bottomLeft);
    segment(rect.bottomLeft, rect.topLeft);
  }

  void _text(
    Canvas canvas,
    String value,
    Offset anchor,
    double fontSize, {
    Color? color,
    bool bold = false,
    FontWeight? weight,
    String? fontFamily,
    bool left = false,
    bool background = false,
    double maxWidth = 300,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color:
              color ??
              Color(
                style.defaultNodeStyle.textColor ??
                    MermaidColors.defaultTextColor,
              ),
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : weight ?? FontWeight.normal,
          fontFamily: fontFamily ?? style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: left ? TextAlign.left : TextAlign.center,
    )..layout(maxWidth: math.max(1, maxWidth));
    final origin = Offset(
      left ? anchor.dx : anchor.dx - painter.width / 2,
      anchor.dy - painter.height / 2,
    );
    if (background) {
      canvas.drawRect(
        (origin & painter.size).inflate(3),
        Paint()..color = Color(style.backgroundColor),
      );
    }
    painter.paint(canvas, origin);
  }

  FontWeight _fontWeight(String type) {
    final value = data.setting('${type}FontWeight');
    final numeric = value is num ? value.toInt() : int.tryParse('$value');
    if (numeric != null) {
      return FontWeight.values[((numeric / 100).round() - 1).clamp(0, 8)];
    }
    return '$value'.toLowerCase() == 'bold'
        ? FontWeight.bold
        : FontWeight.normal;
  }

  double _fontSize(String type, double fallback) {
    final value = data.setting('${type}FontSize');
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse('$value'.replaceAll('px', ''));
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  String? _fontFamily(String type) {
    final value = data.setting('${type}FontFamily');
    return value == null
        ? style.fontFamily
        : '$value'.replaceAll('"', '').split(',').first.trim();
  }

  double _number(String key, double fallback) {
    final value = data.setting(key);
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed != null && parsed >= 0 ? parsed : fallback;
  }

  String? _string(String key) {
    final value = data.setting(key);
    return value == null ? null : '$value';
  }

  Color _css(String? value, int fallback) {
    if (value == null) return Color(fallback);
    final hex = value.trim().replaceFirst('#', '');
    final normalized = hex.length == 3
        ? hex.split('').map((c) => '$c$c').join()
        : hex;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null || (normalized.length != 6 && normalized.length != 8)
        ? Color(fallback)
        : Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  @override
  bool shouldRepaint(covariant C4Painter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.data != data ||
      oldDelegate.style != style;
}
