/*
 * [INPUT]: Depends on laid-out Architecture services, groups, junctions, directional ports, boundary modifiers, arrows, configuration, the native icon-pack registry, and Mermaid styles.
 * [OUTPUT]: Paints complete architecture-beta diagrams natively with compound groups, icon identities, orthogonal edges, labels, and arrowheads.
 * [POS]: Serves as the dedicated Flutter Canvas presentation layer for Mermaid Architecture diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/icon_registry.dart';
import '../models/architecture.dart';
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/style.dart';

class ArchitecturePainter extends CustomPainter {
  const ArchitecturePainter({
    required this.diagram,
    required this.data,
    required this.style,
  });

  final MermaidDiagramData diagram;
  final ArchitectureChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(style.backgroundColor),
    );
    final nodes = {for (final node in diagram.nodes) node.id: node};
    final items = {for (final item in data.items) item.id: item};
    final groupRects = _groupRects(nodes, items);
    _drawGroups(canvas, groupRects);
    for (final edge in data.edges) {
      _drawEdge(canvas, edge, nodes, items, groupRects);
    }
    for (final item in data.items) {
      final node = nodes[item.id];
      if (node != null) _drawItem(canvas, node, item);
    }
    final title = data.title ?? diagram.title;
    if (title != null && title.isNotEmpty) {
      _text(
        canvas,
        title,
        Offset(size.width / 2, data.padding / 2),
        fontSize: math.max(18, data.fontSize * 1.2),
        bold: true,
      );
    }
  }

  Map<String, Rect> _groupRects(
    Map<String, MermaidNode> nodes,
    Map<String, ArchitectureItemData> items,
  ) {
    final result = <String, Rect>{};
    Rect resolve(ArchitectureGroupData group) {
      final cached = result[group.id];
      if (cached != null) return cached;
      final bounds = <Rect>[];
      for (final item in items.values) {
        if (item.parentId == group.id) {
          final node = nodes[item.id];
          if (node != null) {
            bounds.add(
              Rect.fromCenter(
                center: Offset(node.x, node.y),
                width: node.width,
                height: node.height,
              ),
            );
          }
        }
      }
      for (final child in data.groups.where(
        (candidate) => candidate.parentId == group.id,
      )) {
        bounds.add(resolve(child));
      }
      Rect rect;
      if (bounds.isEmpty) {
        final index = data.groups.indexOf(group);
        rect = Rect.fromLTWH(
          data.padding + index * (data.iconSize + data.padding),
          data.padding + 36,
          data.iconSize + data.padding * 2,
          data.iconSize + data.padding * 2,
        );
      } else {
        rect = bounds
            .reduce((a, b) => a.expandToInclude(b))
            .inflate(data.padding);
        rect = Rect.fromLTRB(
          rect.left,
          rect.top - data.fontSize * 1.5,
          rect.right,
          rect.bottom,
        );
      }
      result[group.id] = rect;
      return rect;
    }

    for (final group in data.groups.reversed) {
      resolve(group);
    }
    return result;
  }

  void _drawGroups(Canvas canvas, Map<String, Rect> rects) {
    final groups = [...data.groups]
      ..sort((a, b) => _depth(a).compareTo(_depth(b)));
    for (final group in groups) {
      final rect = rects[group.id]!;
      _dashedRect(
        canvas,
        rect,
        Paint()
          ..color = _color(
            data.groupBorderColor,
            style.defaultNodeStyle.strokeColor ??
                MermaidColors.defaultNodeStroke,
          )
          ..strokeWidth = data.groupBorderWidth
          ..style = PaintingStyle.stroke,
      );
      final label = [
        if (group.icon != null) _iconMark(group.icon!),
        group.label,
      ].join(' ');
      _text(
        canvas,
        label,
        Offset(rect.left + data.padding / 2, rect.top + data.fontSize * .8),
        fontSize: data.fontSize,
        anchorLeft: true,
        bold: true,
      );
    }
  }

  int _depth(ArchitectureGroupData group) {
    var depth = 0;
    var parent = group.parentId;
    while (parent != null) {
      depth++;
      ArchitectureGroupData? found;
      for (final candidate in data.groups) {
        if (candidate.id == parent) found = candidate;
      }
      parent = found?.parentId;
    }
    return depth;
  }

  void _drawItem(Canvas canvas, MermaidNode node, ArchitectureItemData item) {
    final center = Offset(node.x, node.y);
    if (item.isJunction) {
      canvas.drawCircle(
        center,
        node.width / 2,
        Paint()
          ..color = Color(
            style.defaultNodeStyle.strokeColor ??
                MermaidColors.defaultNodeStroke,
          ),
      );
      return;
    }
    final iconRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - data.fontSize * .45),
      width: data.iconSize,
      height: data.iconSize,
    );
    final fill = Paint()
      ..color = Color(
        style.defaultNodeStyle.fillColor ?? MermaidColors.defaultNodeFill,
      );
    final stroke = Paint()
      ..color = Color(
        style.defaultNodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke,
      )
      ..strokeWidth = style.defaultNodeStyle.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(iconRect, const Radius.circular(10)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(iconRect, const Radius.circular(10)),
      stroke,
    );
    _drawIcon(canvas, iconRect, item.icon ?? 'server', stroke.color);
    _text(
      canvas,
      node.label,
      Offset(center.dx, iconRect.bottom + data.fontSize * .8),
      fontSize: data.fontSize,
    );
  }

  void _drawIcon(Canvas canvas, Rect rect, String icon, Color color) {
    final registered = MermaidIconRegistry.resolve(icon);
    if (registered != null) {
      registered.paint(canvas, rect.deflate(rect.width * .16), color);
      return;
    }
    final key = icon.toLowerCase().split(':').last;
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(1.5, data.iconSize / 28)
      ..style = PaintingStyle.stroke;
    final inner = rect.deflate(rect.width * .22);
    if (key == 'database' || key == 'disk') {
      canvas.drawOval(
        Rect.fromLTWH(inner.left, inner.top, inner.width, inner.height * .3),
        paint,
      );
      canvas.drawLine(inner.topLeft, inner.bottomLeft, paint);
      canvas.drawLine(inner.topRight, inner.bottomRight, paint);
      canvas.drawArc(
        Rect.fromLTWH(
          inner.left,
          inner.bottom - inner.height * .3,
          inner.width,
          inner.height * .3,
        ),
        0,
        math.pi,
        false,
        paint,
      );
    } else if (key == 'cloud' || key == 'internet') {
      final path = Path()
        ..moveTo(inner.left, inner.bottom * .0 + inner.center.dy)
        ..cubicTo(
          inner.left,
          inner.top,
          inner.center.dx,
          inner.top,
          inner.center.dx,
          inner.center.dy,
        )
        ..cubicTo(
          inner.right,
          inner.top,
          inner.right,
          inner.bottom,
          inner.center.dx,
          inner.bottom,
        )
        ..lineTo(inner.left + inner.width * .2, inner.bottom)
        ..close();
      canvas.drawPath(path, paint);
    } else if (key == 'server') {
      for (var row = 0; row < 3; row++) {
        final slot = Rect.fromLTWH(
          inner.left,
          inner.top + row * inner.height / 3,
          inner.width,
          inner.height / 4,
        );
        canvas.drawRect(slot, paint);
        canvas.drawCircle(
          Offset(slot.right - slot.height * .35, slot.center.dy),
          slot.height * .1,
          paint,
        );
      }
    } else {
      _text(
        canvas,
        _iconMark(icon),
        inner.center,
        fontSize: math.min(data.fontSize * 1.25, inner.height * .45),
        bold: true,
      );
    }
  }

  void _drawEdge(
    Canvas canvas,
    ArchitectureEdgeData edge,
    Map<String, MermaidNode> nodes,
    Map<String, ArchitectureItemData> items,
    Map<String, Rect> groups,
  ) {
    Rect? endpointRect(String id, bool boundary) {
      if (groups.containsKey(id)) return groups[id];
      final item = items[id];
      if (boundary && item?.parentId != null) return groups[item!.parentId];
      final node = nodes[id];
      return node == null
          ? null
          : Rect.fromCenter(
              center: Offset(node.x, node.y),
              width: node.width,
              height: node.height,
            );
    }

    final fromRect = endpointRect(edge.from, edge.fromGroup);
    final toRect = endpointRect(edge.to, edge.toGroup);
    if (fromRect == null || toRect == null) return;
    final start = _portPoint(fromRect, edge.fromPort);
    final end = _portPoint(toRect, edge.toPort);
    final points = <Offset>[start];
    final fromHorizontal =
        edge.fromPort == ArchitecturePort.left ||
        edge.fromPort == ArchitecturePort.right;
    final toHorizontal =
        edge.toPort == ArchitecturePort.left ||
        edge.toPort == ArchitecturePort.right;
    if (fromHorizontal != toHorizontal) {
      points.add(
        fromHorizontal ? Offset(end.dx, start.dy) : Offset(start.dx, end.dy),
      );
    } else if (fromHorizontal && (start.dy - end.dy).abs() > 1) {
      final midX = (start.dx + end.dx) / 2;
      points.addAll([Offset(midX, start.dy), Offset(midX, end.dy)]);
    } else if (!fromHorizontal && (start.dx - end.dx).abs() > 1) {
      final midY = (start.dy + end.dy) / 2;
      points.addAll([Offset(start.dx, midY), Offset(end.dx, midY)]);
    }
    points.add(end);
    final paint = Paint()
      ..color = _color(
        data.edgeColor,
        style.defaultEdgeStyle.strokeColor ?? MermaidColors.defaultEdgeColor,
      )
      ..strokeWidth = data.edgeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    if (edge.arrowAtStart && points.length > 1) {
      _arrow(canvas, points.first, points[1], edge, paint.color);
    }
    if (edge.arrowAtEnd && points.length > 1) {
      _arrow(canvas, points.last, points[points.length - 2], edge, paint.color);
    }
    if (edge.label != null && edge.label!.isNotEmpty) {
      _text(
        canvas,
        edge.label!,
        points[points.length ~/ 2],
        fontSize: data.fontSize * .9,
        background: true,
      );
    }
  }

  Offset _portPoint(Rect rect, ArchitecturePort port) => switch (port) {
    ArchitecturePort.left => rect.centerLeft,
    ArchitecturePort.right => rect.centerRight,
    ArchitecturePort.top => rect.topCenter,
    ArchitecturePort.bottom => rect.bottomCenter,
  };

  void _arrow(
    Canvas canvas,
    Offset tip,
    Offset previous,
    ArchitectureEdgeData edge,
    Color fallback,
  ) {
    final angle = math.atan2(tip.dy - previous.dy, tip.dx - previous.dx);
    const length = 10.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - length * math.cos(angle - math.pi / 6),
        tip.dy - length * math.sin(angle - math.pi / 6),
      )
      ..lineTo(
        tip.dx - length * math.cos(angle + math.pi / 6),
        tip.dy - length * math.sin(angle + math.pi / 6),
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = _color(data.edgeArrowColor, fallback.toARGB32()),
    );
  }

  void _dashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    void line(Offset start, Offset end) {
      final vector = end - start;
      final length = vector.distance;
      if (length == 0) return;
      final unit = vector / length;
      for (var offset = 0.0; offset < length; offset += dash + gap) {
        canvas.drawLine(
          start + unit * offset,
          start + unit * math.min(length, offset + dash),
          paint,
        );
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.topRight, rect.bottomRight);
    line(rect.bottomRight, rect.bottomLeft);
    line(rect.bottomLeft, rect.topLeft);
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    required double fontSize,
    bool anchorLeft = false,
    bool bold = false,
    bool background = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
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
      textAlign: anchorLeft ? TextAlign.left : TextAlign.center,
    )..layout(maxWidth: 260);
    final offset = Offset(
      anchorLeft ? anchor.dx : anchor.dx - painter.width / 2,
      anchor.dy - painter.height / 2,
    );
    if (background) {
      canvas.drawRect(
        (offset & painter.size).inflate(3),
        Paint()..color = Color(style.backgroundColor),
      );
    }
    painter.paint(canvas, offset);
  }

  String _iconMark(String icon) {
    final leaf = icon.split(':').last.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (leaf.isEmpty) return '?';
    return leaf.substring(0, math.min(2, leaf.length)).toUpperCase();
  }

  Color _color(String? value, int fallback) {
    if (value == null) return Color(fallback);
    final hex = value.trim().replaceFirst('#', '');
    final normalized = hex.length == 3
        ? hex.split('').map((part) => '$part$part').join()
        : hex;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null || (normalized.length != 6 && normalized.length != 8)
        ? Color(fallback)
        : Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  @override
  bool shouldRepaint(covariant ArchitecturePainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.data != data ||
      oldDelegate.style != style;
}
