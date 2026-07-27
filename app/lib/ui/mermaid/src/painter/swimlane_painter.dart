/*
 * [INPUT]: Depends on laid-out Flowchart-compatible Swimlane nodes/edges/lanes, dedicated line-hop configuration, Mermaid styles, and shared node-shape painting.
 * [OUTPUT]: Paints native LR/RL/TB/BT swimlanes with title bands, orthogonal handoffs, labels, arrows, and arc/gap crossing treatments.
 * [POS]: Serves as the dedicated Flutter Canvas presentation layer for swimlane-beta diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/style.dart';
import '../models/swimlane.dart';
import 'flowchart_painter.dart';

class SwimlanePainter extends CustomPainter {
  const SwimlanePainter({
    required this.diagram,
    required this.data,
    required this.style,
  });

  final MermaidDiagramData diagram;
  final SwimlaneData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(style.backgroundColor),
    );
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    for (var index = 0; index < diagram.subgraphs.length; index++) {
      _drawLane(canvas, diagram.subgraphs[index], index, size, horizontal);
    }
    final routes = <_Route>[];
    for (final edge in diagram.edges) {
      final route = _route(edge, horizontal);
      if (route != null) routes.add(route);
    }
    for (var index = 0; index < routes.length; index++) {
      _drawRoute(canvas, routes[index], routes.take(index).toList());
    }
    final transparentStyle = style.copyWith(backgroundColor: 0x00000000);
    FlowchartPainter(
      diagram: diagram.copyWith(edges: const [], subgraphs: const []),
      style: transparentStyle,
    ).paint(canvas, size);
    final title = data.title ?? diagram.title;
    if (title != null && title.isNotEmpty) {
      _text(canvas, title, Offset(size.width / 2, 18), 20, bold: true);
    }
  }

  void _drawLane(
    Canvas canvas,
    Subgraph lane,
    int index,
    Size size,
    bool horizontal,
  ) {
    final members = lane.nodeIds
        .map((id) => diagram.getNode(id))
        .whereType<MermaidNode>()
        .toList();
    if (members.isEmpty) return;
    final body = members
        .map(
          (node) => Rect.fromCenter(
            center: Offset(node.x, node.y),
            width: node.width,
            height: node.height,
          ),
        )
        .reduce((a, b) => a.expandToInclude(b));
    final laneRect = horizontal
        ? Rect.fromLTRB(12, body.top - 42, size.width - 12, body.bottom + 28)
        : Rect.fromLTRB(body.left - 34, 42, body.right + 34, size.height - 12);
    final borderColor = Color(
      style.defaultNodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke,
    );
    final background = Color(
      index.isEven
          ? (style.defaultNodeStyle.fillColor ?? MermaidColors.defaultNodeFill)
          : style.backgroundColor,
    ).withValues(alpha: .22);
    canvas.drawRect(laneRect, Paint()..color = background);
    canvas.drawRect(
      laneRect,
      Paint()
        ..color = borderColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    if (horizontal) {
      const bandWidth = 44.0;
      final band = Rect.fromLTWH(
        laneRect.left,
        laneRect.top,
        bandWidth,
        laneRect.height,
      );
      canvas.drawRect(band, Paint()..color = background.withValues(alpha: .85));
      canvas.save();
      canvas.translate(band.center.dx, band.center.dy);
      canvas.rotate(-math.pi / 2);
      _text(canvas, lane.label, Offset.zero, 14, bold: true);
      canvas.restore();
    } else {
      const bandHeight = 32.0;
      final band = Rect.fromLTWH(
        laneRect.left,
        laneRect.top,
        laneRect.width,
        bandHeight,
      );
      canvas.drawRect(band, Paint()..color = background.withValues(alpha: .85));
      _text(canvas, lane.label, band.center, 14, bold: true);
    }
  }

  _Route? _route(MermaidEdge edge, bool horizontal) {
    final from = diagram.getNode(edge.from);
    final to = diagram.getNode(edge.to);
    if (from == null || to == null) return null;
    final start = _edgePoint(from, Offset(to.x, to.y));
    final end = _edgePoint(to, Offset(from.x, from.y));
    final points = <Offset>[start];
    if (horizontal) {
      final midX = (start.dx + end.dx) / 2;
      points.addAll([Offset(midX, start.dy), Offset(midX, end.dy)]);
    } else {
      final midY = (start.dy + end.dy) / 2;
      points.addAll([Offset(start.dx, midY), Offset(end.dx, midY)]);
    }
    points.add(end);
    return _Route(edge, points);
  }

  Offset _edgePoint(MermaidNode node, Offset toward) {
    final center = Offset(node.x, node.y);
    final dx = toward.dx - center.dx;
    final dy = toward.dy - center.dy;
    final scale = math.min(
      dx == 0 ? double.infinity : node.width / 2 / dx.abs(),
      dy == 0 ? double.infinity : node.height / 2 / dy.abs(),
    );
    return Offset(center.dx + dx * scale, center.dy + dy * scale);
  }

  void _drawRoute(Canvas canvas, _Route route, List<_Route> previous) {
    final color = Color(
      route.edge.style?.strokeColor ??
          style.defaultEdgeStyle.strokeColor ??
          MermaidColors.defaultEdgeColor,
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth =
          route.edge.style?.strokeWidth ?? style.defaultEdgeStyle.strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(route.points.first.dx, route.points.first.dy);
    for (final point in route.points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    if (data.lineHops != SwimlaneLineHops.none) {
      for (final segment in route.segments) {
        for (final old in previous.expand((item) => item.segments)) {
          final crossing = _intersection(
            segment.$1,
            segment.$2,
            old.$1,
            old.$2,
          );
          if (crossing == null) continue;
          canvas.drawCircle(
            crossing,
            5,
            Paint()..color = Color(style.backgroundColor),
          );
          if (data.lineHops == SwimlaneLineHops.arc) {
            final horizontal = (segment.$1.dy - segment.$2.dy).abs() < 1;
            final arc = Rect.fromCenter(
              center: crossing,
              width: 10,
              height: 10,
            );
            canvas.drawArc(
              arc,
              horizontal ? math.pi : -math.pi / 2,
              math.pi,
              false,
              paint,
            );
          }
        }
      }
    }
    if (route.edge.arrowType != ArrowType.none) {
      _arrow(
        canvas,
        route.points.last,
        route.points[route.points.length - 2],
        color,
      );
    }
    if (route.edge.bidirectional) {
      _arrow(canvas, route.points.first, route.points[1], color);
    }
    final label = route.edge.label;
    if (label != null && label.isNotEmpty) {
      _text(
        canvas,
        label,
        route.points[route.points.length ~/ 2],
        12,
        background: true,
      );
    }
  }

  Offset? _intersection(Offset a, Offset b, Offset c, Offset d) {
    final abHorizontal = (a.dy - b.dy).abs() < .1;
    final cdHorizontal = (c.dy - d.dy).abs() < .1;
    if (abHorizontal == cdHorizontal) return null;
    final horizontalA = abHorizontal ? a : c;
    final horizontalB = abHorizontal ? b : d;
    final verticalA = abHorizontal ? c : a;
    final verticalB = abHorizontal ? d : b;
    final x = verticalA.dx;
    final y = horizontalA.dy;
    if (x <= math.min(horizontalA.dx, horizontalB.dx) + 2 ||
        x >= math.max(horizontalA.dx, horizontalB.dx) - 2 ||
        y <= math.min(verticalA.dy, verticalB.dy) + 2 ||
        y >= math.max(verticalA.dy, verticalB.dy) - 2) {
      return null;
    }
    return Offset(x, y);
  }

  void _arrow(Canvas canvas, Offset tip, Offset previous, Color color) {
    final angle = math.atan2(tip.dy - previous.dy, tip.dx - previous.dx);
    const length = 9.0;
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

  void _text(
    Canvas canvas,
    String value,
    Offset anchor,
    double fontSize, {
    bool bold = false,
    bool background = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Color(
            style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor,
          ),
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          fontFamily: style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 260);
    final origin = Offset(
      anchor.dx - painter.width / 2,
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

  @override
  bool shouldRepaint(covariant SwimlanePainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.data != data ||
      oldDelegate.style != style;
}

class _Route {
  const _Route(this.edge, this.points);
  final MermaidEdge edge;
  final List<Offset> points;
  Iterable<(Offset, Offset)> get segments sync* {
    for (var index = 1; index < points.length; index++) {
      yield (points[index - 1], points[index]);
    }
  }
}
