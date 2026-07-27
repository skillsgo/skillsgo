/*
 * [INPUT]: Depends on Flutter Canvas, complete Mindmap hierarchy/configuration/theme data, CSS colors, and Mermaid styles.
 * [OUTPUT]: Computes deterministic radial or layered mindmap geometry and paints all node shapes, section edges, labels, and native icon badges.
 * [POS]: Serves as the dedicated pure-Flutter layout and renderer for Mermaid Mindmap diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mindmap.dart';
import '../models/style.dart';
import 'css_color.dart';

class MindmapChartLayout {
  const MindmapChartLayout();

  Size computeLayout(MindmapChartData data, Size available) {
    final levels = data.nodes.fold<int>(
      0,
      (value, node) => math.max(value, node.level),
    );
    final leaves = data.nodes
        .where(
          (node) => !data.nodes.any((child) => child.parentIndex == node.index),
        )
        .length;
    final intrinsic = Size(
      data.padding * 2 + math.max(1, levels + 1) * (data.maxNodeWidth + 80),
      data.padding * 2 +
          math.max(1, leaves) * 90 +
          (data.title == null ? 0 : 44),
    );
    return Size(
      data.useMaxWidth && available.width.isFinite
          ? math.max(available.width, intrinsic.width)
          : intrinsic.width,
      math.max(240, intrinsic.height),
    );
  }
}

class MindmapPainter extends CustomPainter {
  const MindmapPainter({required this.data, required this.style});
  final MindmapChartData data;
  final MermaidStyle style;

  static const _palette = <Color>[
    Color(0xff4c78a8),
    Color(0xfff58518),
    Color(0xff54a24b),
    Color(0xffe45756),
    Color(0xff72b7b2),
    Color(0xffb279a2),
    Color(0xffff9da6),
    Color(0xff9d755d),
    Color(0xffbab0ac),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (data.nodes.isEmpty) return;
    final titleOffset = data.title == null ? 0.0 : 44.0;
    if (data.title case final title?) {
      final painter = _label(title, 20, _textColor, bold: true)
        ..layout(maxWidth: size.width - data.padding * 2);
      painter.paint(
        canvas,
        Offset((size.width - painter.width) / 2, data.padding),
      );
    }
    final positions = _positions(size, titleOffset);
    final boxes = <int, Rect>{};
    for (final node in data.nodes) {
      boxes[node.index] = _nodeRect(node, positions[node.index]!);
    }
    for (final node in data.nodes) {
      if (node.parentIndex case final parent?) {
        _edge(canvas, boxes[parent]!, boxes[node.index]!, node);
      }
    }
    for (final node in data.nodes) {
      _node(canvas, node, boxes[node.index]!);
    }
  }

  Map<int, Offset> _positions(Size size, double titleOffset) {
    final result = <int, Offset>{};
    if (data.layoutAlgorithm.toLowerCase().contains('cose')) {
      final center = Offset(
        size.width / 2,
        titleOffset + (size.height - titleOffset) / 2,
      );
      result[data.rootIndex] = center;
      final branches = data.nodes
          .where((node) => node.parentIndex == data.rootIndex)
          .toList();
      for (var branchIndex = 0; branchIndex < branches.length; branchIndex++) {
        final branch = branches[branchIndex];
        final branchAngle = branches.length == 1
            ? 0.0
            : math.pi * 2 * branchIndex / branches.length;
        final members = data.nodes
            .where((node) => node.section == branch.section)
            .toList();
        for (final node in members) {
          final spreadIndex = members.indexOf(node);
          final spread = (spreadIndex - (members.length - 1) / 2) * .18;
          final radius = node.level * (data.maxNodeWidth * .72 + 70);
          result[node.index] =
              center +
              Offset(
                    math.cos(branchAngle + spread),
                    math.sin(branchAngle + spread),
                  ) *
                  radius;
        }
      }
    } else {
      final maxLevel = data.nodes.fold<int>(
        0,
        (value, node) => math.max(value, node.level),
      );
      for (var level = 0; level <= maxLevel; level++) {
        final nodes = data.nodes.where((node) => node.level == level).toList();
        for (var row = 0; row < nodes.length; row++) {
          result[nodes[row].index] = Offset(
            data.padding +
                data.maxNodeWidth / 2 +
                level * (data.maxNodeWidth + 80),
            titleOffset +
                (row + 1) * (size.height - titleOffset) / (nodes.length + 1),
          );
        }
      }
    }
    result.putIfAbsent(
      data.rootIndex,
      () => Offset(size.width / 2, size.height / 2),
    );
    return result;
  }

  Rect _nodeRect(MindmapNodeData node, Offset center) {
    final iconExtra = node.icon == null ? 0.0 : 42.0;
    final painter = _label(
      node.label,
      14,
      _labelColor(node),
      bold: node.level == 0,
    )..layout(maxWidth: math.max(20, data.maxNodeWidth - 20 - iconExtra));
    var width = math.min(data.maxNodeWidth, painter.width + 28 + iconExtra);
    var height = math.max(42.0, painter.height + 22);
    if (node.shape == MindmapNodeShape.circle) {
      width = height = math.max(width, height);
    }
    if (node.shape == MindmapNodeShape.cloud ||
        node.shape == MindmapNodeShape.bang) {
      width += 24;
      height += 18;
    }
    return Rect.fromCenter(center: center, width: width, height: height);
  }

  void _edge(Canvas canvas, Rect parent, Rect child, MindmapNodeData node) {
    final color = _sectionColor(node);
    final depthWidth =
        (data.look == 'neo'
                ? math.max(2.0, 10 - (node.level - 1) * 2)
                : math.max(2.0, 17 - 3 * (node.level - 1)))
            .toDouble();
    final path = Path()..moveTo(parent.center.dx, parent.center.dy);
    final middleX = (parent.center.dx + child.center.dx) / 2;
    path.cubicTo(
      middleX,
      parent.center.dy,
      middleX,
      child.center.dy,
      child.center.dx,
      child.center.dy,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = depthWidth,
    );
  }

  void _node(Canvas canvas, MindmapNodeData node, Rect rect) {
    final fill = _fillColor(node);
    final border = data.look == 'neo'
        ? parseMermaidCssColor(data.theme.nodeBorder) ?? _sectionColor(node)
        : _sectionColor(node);
    final paint = Paint()..color = fill;
    final outline = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = data.look == 'neo' ? data.theme.strokeWidth : 1;
    final path = _shape(node.shape, rect);
    if (data.theme.useGradient &&
        data.theme.gradientStart != null &&
        data.theme.gradientStop != null) {
      paint.shader = LinearGradient(
        colors: [
          parseMermaidCssColor(data.theme.gradientStart) ?? fill,
          parseMermaidCssColor(data.theme.gradientStop) ?? fill,
        ],
      ).createShader(rect);
    }
    if (node.shape != MindmapNodeShape.noBorder) {
      canvas.drawPath(path, paint);
      canvas.drawPath(path, outline);
    } else {
      canvas.drawLine(
        rect.bottomLeft,
        rect.bottomRight,
        outline..strokeWidth = 3,
      );
    }
    var textLeft = rect.left + 12;
    if (node.icon case final icon?) {
      final iconRect = Rect.fromCenter(
        center: Offset(rect.left + 24, rect.center.dy),
        width: 26,
        height: 26,
      );
      canvas.drawCircle(
        iconRect.center,
        13,
        Paint()..color = _labelColor(node).withValues(alpha: .16),
      );
      final glyph = _label(_iconGlyph(icon), 16, _labelColor(node), bold: true)
        ..layout();
      glyph.paint(
        canvas,
        Offset(
          iconRect.center.dx - glyph.width / 2,
          iconRect.center.dy - glyph.height / 2,
        ),
      );
      textLeft += 36;
    }
    final label = _label(
      node.label,
      14,
      _labelColor(node),
      bold: node.level == 0,
    )..layout(maxWidth: math.max(20, rect.right - textLeft - 10));
    label.paint(canvas, Offset(textLeft, rect.center.dy - label.height / 2));
  }

  Path _shape(MindmapNodeShape shape, Rect rect) => switch (shape) {
    MindmapNodeShape.noBorder ||
    MindmapNodeShape.rectangle => Path()..addRect(rect),
    MindmapNodeShape.roundedRectangle =>
      Path()
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(15))),
    MindmapNodeShape.circle => Path()..addOval(rect),
    MindmapNodeShape.hexagon =>
      Path()..addPolygon([
        Offset(rect.left + rect.height / 4, rect.top),
        Offset(rect.right - rect.height / 4, rect.top),
        Offset(rect.right, rect.center.dy),
        Offset(rect.right - rect.height / 4, rect.bottom),
        Offset(rect.left + rect.height / 4, rect.bottom),
        Offset(rect.left, rect.center.dy),
      ], true),
    MindmapNodeShape.cloud => _burst(rect, 12, .12),
    MindmapNodeShape.bang => _burst(rect, 16, .24),
  };

  Path _burst(Rect rect, int points, double variation) {
    final path = Path();
    for (var index = 0; index < points; index++) {
      final angle = math.pi * 2 * index / points;
      final factor = index.isEven ? 1.0 : 1 - variation;
      final point = Offset(
        rect.center.dx + math.cos(angle) * rect.width / 2 * factor,
        rect.center.dy + math.sin(angle) * rect.height / 2 * factor,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  Color get _textColor => Color(style.defaultNodeStyle.textColor ?? 0xff333333);
  Color _sectionColor(MindmapNodeData node) =>
      _color(data.theme.lineColors, node.section ?? 0) ??
      _color(data.theme.colors, node.section ?? 0) ??
      _palette[(node.section ?? 0) % _palette.length];
  Color _fillColor(MindmapNodeData node) {
    if (node.level == 0) {
      return parseMermaidCssColor(data.theme.rootColor) ?? _palette.first;
    }
    if (data.look == 'neo' && data.theme.mainBackground != null) {
      return parseMermaidCssColor(data.theme.mainBackground) ??
          _sectionColor(node);
    }
    return _color(data.theme.colors, node.section ?? 0) ??
        _sectionColor(node).withValues(alpha: .2);
  }

  Color _labelColor(MindmapNodeData node) {
    if (node.level == 0) {
      return parseMermaidCssColor(data.theme.rootLabelColor) ?? Colors.white;
    }
    return _color(data.theme.labelColors, node.section ?? 0) ?? _textColor;
  }

  Color? _color(List<String?> values, int index) => values.isEmpty
      ? null
      : parseMermaidCssColor(values[index % values.length]);
  String _iconGlyph(String icon) {
    final lower = icon.toLowerCase();
    if (lower.contains('book')) return '▤';
    if (lower.contains('star')) return '★';
    if (lower.contains('user')) return '●';
    if (lower.contains('database')) return '◫';
    return '◆';
  }

  TextPainter _label(
    String text,
    double size,
    Color color, {
    bool bold = false,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: style.fontFamily,
        fontWeight: bold ? FontWeight.w600 : null,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );

  @override
  bool shouldRepaint(covariant MindmapPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}
