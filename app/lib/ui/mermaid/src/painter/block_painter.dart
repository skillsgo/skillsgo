/*
 * [INPUT]: Depends on Flutter Canvas, laid-out Block nodes/edges/groups, Block arrow directions, Mermaid styles, and the shared Flowchart shape renderer.
 * [OUTPUT]: Paints native Block diagrams with shared shapes/edges plus multi-direction block-arrow glyphs over recursively laid-out composite grids.
 * [POS]: Serves as the dedicated native presentation layer for Mermaid Block diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/block.dart';
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/style.dart';
import 'flowchart_painter.dart';

class BlockPainter extends CustomPainter {
  const BlockPainter({
    required this.diagram,
    required this.data,
    required this.style,
  });

  final MermaidDiagramData diagram;
  final BlockChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    FlowchartPainter(diagram: diagram, style: style).paint(canvas, size);
    for (final arrow in data.arrows) {
      final node = diagram.getNode(arrow.nodeId);
      if (node == null) continue;
      _drawArrowBlock(canvas, node, arrow);
    }
  }

  void _drawArrowBlock(Canvas canvas, MermaidNode node, BlockArrowData arrow) {
    final rect = Rect.fromCenter(
      center: Offset(node.x, node.y),
      width: node.width,
      height: node.height,
    );
    final directions = <String>{};
    for (final direction in arrow.directions) {
      if (direction == 'x') directions.addAll(const ['left', 'right']);
      if (direction == 'y') directions.addAll(const ['up', 'down']);
      if (direction != 'x' && direction != 'y') directions.add(direction);
    }
    final tip = math.min(18.0, math.min(rect.width, rect.height) * .28);
    final body = Rect.fromLTRB(
      rect.left + (directions.contains('left') ? tip : 0),
      rect.top + (directions.contains('up') ? tip : 0),
      rect.right - (directions.contains('right') ? tip : 0),
      rect.bottom - (directions.contains('down') ? tip : 0),
    );
    final nodeStyle = node.style ?? style.getNodeStyle(node.className);
    final fill = Paint()
      ..color = Color(nodeStyle.fillColor ?? MermaidColors.defaultNodeFill);
    final stroke = Paint()
      ..color = Color(nodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke)
      ..strokeWidth = nodeStyle.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRect(body, fill);
    canvas.drawRect(body, stroke);
    for (final direction in directions) {
      final triangle = switch (direction) {
        'left' =>
          Path()
            ..moveTo(rect.left, rect.center.dy)
            ..lineTo(body.left, body.top)
            ..lineTo(body.left, body.bottom)
            ..close(),
        'right' =>
          Path()
            ..moveTo(rect.right, rect.center.dy)
            ..lineTo(body.right, body.top)
            ..lineTo(body.right, body.bottom)
            ..close(),
        'up' =>
          Path()
            ..moveTo(rect.center.dx, rect.top)
            ..lineTo(body.left, body.top)
            ..lineTo(body.right, body.top)
            ..close(),
        _ =>
          Path()
            ..moveTo(rect.center.dx, rect.bottom)
            ..lineTo(body.left, body.bottom)
            ..lineTo(body.right, body.bottom)
            ..close(),
      };
      canvas.drawPath(triangle, fill);
      canvas.drawPath(triangle, stroke);
    }
    final label = node.label
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    if (label.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Color(nodeStyle.textColor ?? MermaidColors.defaultTextColor),
            fontSize: nodeStyle.fontSize,
            fontFamily: style.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: math.max(1, body.width - data.padding * 2));
      painter.paint(
        canvas,
        Offset(
          body.center.dx - painter.width / 2,
          body.center.dy - painter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BlockPainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.data != data ||
      oldDelegate.style != style;
}
