/*
 * [INPUT]: Depends on Flutter Canvas, lossless Tree View hierarchy/configuration, the native icon-pack registry, and Mermaid semantic styles.
 * [OUTPUT]: Computes and paints native indented tree rows, connectors, labels, descriptions, and registered or fallback icon identities.
 * [POS]: Serves as the dedicated layout and renderer for Mermaid Tree View diagrams instead of generic graph projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/icon_registry.dart';
import '../models/style.dart';
import '../models/tree_view.dart';

class TreeViewChartLayout {
  const TreeViewChartLayout();

  Size computeLayout(TreeViewChartData data, Size availableSize) {
    final titleHeight = data.title == null ? 0.0 : 36.0;
    final rowHeight = 20.0 + data.paddingY * 2;
    final maxWidth = data.nodes.fold<double>(0, (width, node) {
      final iconWidth = data.iconFor(node) == null ? 0.0 : 24.0;
      final labelWidth =
          (node.name.length + (node.description?.length ?? 0)) * 7.0;
      return math.max(
        width,
        node.indentation * data.rowIndent +
            data.paddingX * 2 +
            iconWidth +
            labelWidth,
      );
    });
    return Size(
      math.max(availableSize.width, maxWidth + 32),
      titleHeight + data.nodes.length * rowHeight + 20,
    );
  }
}

class TreeViewPainter extends CustomPainter {
  const TreeViewPainter({required this.data, required this.style});

  final TreeViewChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rowHeight = 20.0 + data.paddingY * 2;
    final titleHeight = data.title == null ? 0.0 : 36.0;
    if (data.title case final title?) {
      _text(canvas, title, Offset(data.paddingX, 8), bold: true, size: 16);
    }
    final centers = <int, Offset>{};
    for (final node in data.nodes) {
      final depth = _depth(node);
      final y = titleHeight + node.index * rowHeight + rowHeight / 2;
      final x = 16 + depth * data.rowIndent;
      centers[node.index] = Offset(x, y);
      if (node.parentIndex case final parentIndex) {
        final parentNode = data.nodes
            .where((candidate) => candidate.index == parentIndex)
            .firstOrNull;
        if (parentNode == null) continue;
        final parent =
            centers[parentIndex] ??
            Offset(
              16 + _depth(parentNode) * data.rowIndent,
              titleHeight + parentNode.index * rowHeight + rowHeight / 2,
            );
        final elbowX = parent.dx + data.rowIndent / 2;
        final line = Paint()
          ..color = Color(
            style.defaultEdgeStyle.strokeColor ??
                MermaidColors.defaultEdgeColor,
          )
          ..strokeWidth = data.lineThickness
          ..style = PaintingStyle.stroke;
        if (data.lineThickness > 0) {
          canvas.drawPath(
            Path()
              ..moveTo(parent.dx, parent.dy + rowHeight / 3)
              ..lineTo(elbowX, parent.dy + rowHeight / 3)
              ..lineTo(elbowX, y)
              ..lineTo(x, y),
            line,
          );
        }
      }
      var labelX = x + data.paddingX;
      final icon = data.iconFor(node);
      if (icon != null && icon != 'none') {
        _drawIcon(canvas, icon, node.kind, Offset(labelX, y));
        labelX += 22;
      }
      _text(
        canvas,
        node.name,
        Offset(labelX, y),
        bold: node.kind == TreeViewNodeKind.directory,
        centeredY: true,
      );
      if (node.description case final description?) {
        final nameWidth = node.name.length * 7.0 + 10;
        _text(
          canvas,
          description,
          Offset(labelX + nameWidth, y),
          centeredY: true,
          color: Color(
            style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor,
          ).withValues(alpha: .65),
          size: 11,
        );
      }
    }
  }

  int _depth(TreeViewNodeData node) {
    var depth = 0;
    var parent = node.parentIndex;
    while (parent != null) {
      depth++;
      parent = data.nodes[parent].parentIndex;
    }
    return depth;
  }

  void _drawIcon(
    Canvas canvas,
    String icon,
    TreeViewNodeKind kind,
    Offset center,
  ) {
    final color = kind == TreeViewNodeKind.directory
        ? const Color(0xffffb300)
        : const Color(0xff78909c);
    final rect = Rect.fromCenter(
      center: center.translate(8, 0),
      width: 14,
      height: 12,
    );
    final glyph = MermaidIconRegistry.resolve(
      icon,
      defaultPack: data.defaultIconPack,
    );
    if (glyph != null) {
      glyph.paint(canvas, rect, color);
      return;
    }
    final fallback = icon.split(':').last;
    _text(
      canvas,
      fallback.isEmpty ? '?' : fallback.substring(0, 1).toUpperCase(),
      rect.center,
      centeredY: true,
      bold: true,
      size: 11,
      color: color,
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset anchor, {
    bool bold = false,
    bool centeredY = false,
    double size = 13,
    Color? color,
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
          fontSize: size,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          fontFamily: style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout();
    painter.paint(
      canvas,
      centeredY ? anchor.translate(0, -painter.height / 2) : anchor,
    );
  }

  @override
  bool shouldRepaint(TreeViewPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}
