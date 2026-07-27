/*
 * [INPUT]: Depends on Flutter Canvas, shared graph geometry/style, and Event Modeling lane/entity metadata.
 * [OUTPUT]: Paints semantic swimlanes, inferred/explicit relations, typed frames, data labels, and reset markers.
 * [POS]: Serves as the dedicated native painter for Mermaid Event Modeling diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/event_modeling.dart';
import '../models/node.dart';
import 'css_color.dart';
import 'mermaid_painter.dart';

class EventModelingPainter extends MermaidPainter {
  const EventModelingPainter({
    required super.diagram,
    required super.style,
    required this.data,
  });

  final EventModelingChartData data;

  @override
  void paint(Canvas canvas, Size size) {
    const labelWidth = 160.0;
    final frameHeight = math.max(52.0, data.rowHeight);
    final laneHeight = math.max(data.rowHeight, frameHeight + data.padding * 2);
    final top = data.padding + (data.title == null ? 0 : 34);
    final border = Paint()
      ..color = _color(
        data.theme.swimlaneBackgroundStroke,
        Color(style.defaultNodeStyle.strokeColor ?? 0xFF607D8B),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < data.lanes.length; index++) {
      final rect = Rect.fromLTWH(
        data.padding,
        top + index * laneHeight,
        size.width - data.padding * 2,
        laneHeight,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = index.isEven
              ? _color(
                  data.theme.swimlaneBackgroundOdd,
                  const Color(0x0A607D8B),
                )
              : const Color(0x12607D8B)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(rect, border);
      drawText(
        canvas,
        data.lanes[index].label,
        Offset(rect.left + 14, rect.top + 18),
        TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: style.fontFamily,
        ),
        maxWidth: labelWidth - 24,
      );
    }
    if (data.title case final title?) {
      drawText(
        canvas,
        title,
        Offset(data.padding, data.padding),
        TextStyle(
          color: _textColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: style.fontFamily,
        ),
      );
    }
    final nodes = {for (final node in diagram.nodes) node.id: node};
    final edgePaint = Paint()
      ..color = _color(
        data.theme.relationStroke,
        Color(style.defaultEdgeStyle.strokeColor ?? 0xFF546E7A),
      )
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    for (final edge in diagram.edges) {
      final source = nodes[edge.from];
      final target = nodes[edge.to];
      if (source == null || target == null) continue;
      final start = Offset(source.x + source.width / 2, source.y);
      final end = Offset(target.x - target.width / 2, target.y);
      canvas.drawLine(start, end, edgePaint);
      final arrowPaint = Paint()
        ..color = _color(data.theme.arrowhead, edgePaint.color)
        ..strokeWidth = edgePaint.strokeWidth
        ..style = PaintingStyle.stroke;
      drawArrowHead(
        canvas,
        end,
        math.atan2(end.dy - start.dy, end.dx - start.dx),
        edge.arrowType,
        arrowPaint,
      );
    }
    for (final frame in data.frames) {
      final node = nodes[frame.id]!;
      final rect = Rect.fromCenter(
        center: Offset(node.x, node.y),
        width: node.width,
        height: node.height,
      );
      final fill = switch (frame.entityType) {
        EventModelingEntityType.ui => _color(
          data.theme.uiFill,
          const Color(0xFFFFFFFF),
        ),
        EventModelingEntityType.processor => _color(
          data.theme.processorFill,
          const Color(0xFFEDB3F6),
        ),
        EventModelingEntityType.command => _color(
          data.theme.commandFill,
          const Color(0xFFBCD6FE),
        ),
        EventModelingEntityType.readModel => _color(
          data.theme.readModelFill,
          const Color(0xFFD3F1A2),
        ),
        EventModelingEntityType.event => _color(
          data.theme.eventFill,
          const Color(0xFFFFB778),
        ),
      };
      final stroke = switch (frame.entityType) {
        EventModelingEntityType.ui => _color(
          data.theme.uiStroke,
          const Color(0xFFDBDADA),
        ),
        EventModelingEntityType.processor => _color(
          data.theme.processorStroke,
          const Color(0xFFB88CBF),
        ),
        EventModelingEntityType.command => _color(
          data.theme.commandStroke,
          const Color(0xFF679AC3),
        ),
        EventModelingEntityType.readModel => _color(
          data.theme.readModelStroke,
          const Color(0xFFA3B732),
        ),
        EventModelingEntityType.event => _color(
          data.theme.eventStroke,
          const Color(0xFFC19A0F),
        ),
      };
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = fill
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (frame.isReset) {
        canvas.drawCircle(
          Offset(rect.left + 7, rect.top + 7),
          4,
          Paint()..color = const Color(0xFFE53935),
        );
      }
      drawText(
        canvas,
        node.label,
        Offset(rect.left + 8, rect.top + 10),
        TextStyle(
          color: _textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: style.fontFamily,
        ),
        maxWidth: rect.width - 16,
      );
    }
    for (final note in data.notes) {
      final node = nodes[note.frameId];
      if (node != null) {
        _annotation(
          canvas,
          node,
          'Note: ${note.value}',
          const Color(0xfffff4bd),
        );
      }
    }
    for (final scenario in data.scenarios) {
      final node = nodes[scenario.frameId];
      if (node != null) {
        _annotation(
          canvas,
          node,
          scenario.source,
          const Color(0xffe9f5ff),
          offset: 18,
        );
      }
    }
  }

  void _annotation(
    Canvas canvas,
    MermaidNode node,
    String value,
    Color fill, {
    double offset = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: _textColor,
          fontSize: 9,
          fontFamily: style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 150);
    final rect = Rect.fromLTWH(
      node.x - node.width / 2,
      node.y + node.height / 2 - painter.height - 5 - offset,
      math.min(node.width, painter.width + 10),
      painter.height + 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = fill.withValues(alpha: .92),
    );
    painter.paint(canvas, Offset(rect.left + 5, rect.top + 2));
  }

  Color _color(String? value, Color fallback) =>
      parseMermaidCssColor(value) ?? fallback;
  Color get _textColor => _color(
    data.theme.textColor,
    Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
  );

  @override
  bool shouldRepaint(EventModelingPainter oldDelegate) =>
      super.shouldRepaint(oldDelegate) || oldDelegate.data != data;
}
