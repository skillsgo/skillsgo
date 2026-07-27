/*
 * [INPUT]: Depends on Flutter Canvas, shared sequence graph geometry, typed sequence semantic events, responsive configuration, and Mermaid style.
 * [OUTPUT]: Paints all native participant shapes and icon markers, lifelines, messages, notes, activations, lifecycle markers, numbering, and nested control fragments.
 * [POS]: Serves as the complete native painter for sequenceDiagram and the base interaction painter for ZenUML.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/sequence.dart';
import '../models/style.dart';
import 'mermaid_painter.dart';

/// Helper class for participant colors
class _ParticipantColors {
  const _ParticipantColors(this.fill, this.stroke);
  final int fill;
  final int stroke;
}

/// Painter for sequence diagrams
class SequencePainter extends MermaidPainter {
  /// Creates a sequence painter
  const SequencePainter({
    required super.diagram,
    required super.style,
    this.deviceConfig,
    this.sequenceData,
  });

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Typed semantic events. ZenUML omits this and uses the graph projection.
  final SequenceChartData? sequenceData;

  @override
  void paint(Canvas canvas, Size size) {
    if (diagram.nodes.isEmpty) return;

    // Get responsive values
    final config = sequenceData?.config ?? diagram.sequenceConfig;
    final messageSpacing =
        config?.messageMargin ?? deviceConfig?.messageSpacing ?? 50.0;
    final messageStartOffset = config?.boxMargin ?? messageSpacing * 0.8;

    final firstNode = diagram.nodes.first;
    final messageStartY = firstNode.y + firstNode.height + messageStartOffset;
    final rowCount = sequenceData?.events.length ?? diagram.edges.length;
    final totalMessagesHeight = rowCount * messageSpacing;
    final bottomY =
        messageStartY +
        totalMessagesHeight +
        (config?.bottomMarginAdjustment ?? 1) +
        (config?.diagramMarginY ?? 20);

    _drawParticipantBoxes(canvas, messageStartY, bottomY);

    // Draw participant lifelines (dashed vertical lines)
    for (final node in diagram.nodes) {
      _drawLifeline(canvas, node, messageStartY - 10, bottomY);
    }

    // Draw participant boxes at top
    for (final node in diagram.nodes) {
      _drawParticipant(canvas, node);
    }

    if (sequenceData == null) {
      var messageY = messageStartY;
      for (final edge in diagram.edges) {
        _drawMessage(canvas, edge, messageY);
        messageY += messageSpacing;
      }
    } else {
      _drawSemanticEvents(canvas, messageStartY, messageSpacing, size.width);
    }

    // Draw participant boxes at bottom
    if (config?.mirrorActors ?? true) {
      for (final node in diagram.nodes) {
        _drawParticipantBottom(canvas, node, bottomY);
      }
    }
  }

  void _drawSemanticEvents(
    Canvas canvas,
    double startY,
    double spacing,
    double width,
  ) {
    var messageNumber = sequenceData!.autoNumberStart;
    for (var index = 0; index < sequenceData!.events.length; index++) {
      final event = sequenceData!.events[index];
      final y = startY + index * spacing;
      switch (event) {
        case SequenceMessageEventData():
          _drawMessage(canvas, diagram.edges[event.edgeIndex], y, event: event);
          final configuredNumber =
              event.number ??
              (sequenceData!.config.showSequenceNumbers ? messageNumber : null);
          if (configuredNumber case final number?) {
            _smallText(canvas, '$number', Offset(8, y - 8), FontWeight.w600);
          }
          messageNumber += sequenceData!.autoNumberStep;
        case SequenceNoteData():
          _drawNote(canvas, event, y);
        case SequenceActivationData():
          _drawActivation(canvas, event, y, spacing);
        case SequenceFragmentData():
          _drawFragment(canvas, event, index, y, spacing, width);
        case SequenceLifecycleData():
          _drawLifecycle(canvas, event, y);
      }
    }
  }

  void _drawParticipantBoxes(Canvas canvas, double top, double bottom) {
    final data = sequenceData;
    if (data == null || data.boxes.isEmpty) return;
    for (final box in data.boxes) {
      final nodes = data.participants
          .where((participant) => participant.boxId == box.id)
          .map((participant) => diagram.getNode(participant.id))
          .whereType<MermaidNode>()
          .toList();
      if (nodes.isEmpty) continue;
      final left = nodes.map((node) => node.x).reduce(math.min) - 8;
      final right =
          nodes.map((node) => node.x + node.width).reduce(math.max) + 8;
      final rect = Rect.fromLTRB(left, 4, right, bottom + 8);
      final color = _parseSequenceColor(box.color) ?? const Color(0x0F607D8B);
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.10));
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke,
      );
      if (box.label case final label?) {
        _smallText(canvas, label, Offset(left + 6, top - 20), FontWeight.w600);
      }
    }
  }

  Color? _parseSequenceColor(String? value) {
    if (value == null) return null;
    final hex = value.replaceFirst('#', '');
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return switch (value.toLowerCase()) {
      'red' => Colors.red,
      'blue' => Colors.blue,
      'green' => Colors.green,
      'yellow' => Colors.yellow,
      'gray' || 'grey' => Colors.grey,
      'transparent' => Colors.transparent,
      _ => null,
    };
  }

  void _drawNote(Canvas canvas, SequenceNoteData note, double y) {
    final config = sequenceData?.config ?? const SequenceConfig();
    final actorNodes = note.actors
        .map(diagram.getNode)
        .whereType<MermaidNode>()
        .toList();
    if (actorNodes.isEmpty) return;
    final first = actorNodes.first;
    final last = actorNodes.last;
    final centerX = switch (note.position) {
      SequenceNotePosition.leftOf =>
        first.x - config.width / 2 - config.noteMargin,
      SequenceNotePosition.rightOf =>
        first.x + first.width + config.width / 2 + config.noteMargin,
      SequenceNotePosition.over =>
        (first.x + first.width / 2 + last.x + last.width / 2) / 2,
    };
    final rect = Rect.fromCenter(
      center: Offset(centerX, y),
      width: math.max(config.width, (last.x - first.x).abs() + config.width),
      height: math.max(36, config.noteFontSize * 2 + config.noteMargin),
    );
    canvas.drawRect(rect, Paint()..color = const Color(0xFFFFF7C7));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFB49A37)
        ..style = PaintingStyle.stroke,
    );
    final labelRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      math.min(config.labelBoxWidth, rect.width),
      math.min(config.labelBoxHeight, rect.height),
    );
    canvas.drawRect(
      labelRect,
      Paint()
        ..color = const Color(0x1F607D8B)
        ..style = PaintingStyle.fill,
    );
    _centerText(
      canvas,
      note.text,
      rect,
      _fontWeight(config.noteFontWeight),
      fontSize: config.noteFontSize,
      fontFamily: config.noteFontFamily,
      align: config.noteAlign,
      wrap: note.wrap ?? config.wrap,
      padding: config.wrapPadding,
    );
  }

  void _drawActivation(
    Canvas canvas,
    SequenceActivationData activation,
    double y,
    double spacing,
  ) {
    final node = diagram.getNode(activation.actor);
    if (node == null) return;
    final centerX = node.x + node.width / 2;
    final rect = Rect.fromCenter(
      center: Offset(centerX, y + spacing / 2),
      width: sequenceData?.config.activationWidth ?? 10,
      height: spacing,
    );
    if (activation.active) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFFE8EEF5));
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF607D8B)
          ..style = PaintingStyle.stroke,
      );
    } else {
      canvas.drawLine(
        rect.topLeft,
        rect.bottomRight,
        Paint()
          ..color = const Color(0xFF607D8B)
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawFragment(
    Canvas canvas,
    SequenceFragmentData fragment,
    int eventIndex,
    double y,
    double spacing,
    double width,
  ) {
    if (fragment.isEnd) return;
    final left = 8.0 + fragment.depth * 10;
    final config = sequenceData?.config ?? const SequenceConfig();
    final boxHeight = math.max(
      36.0,
      config.labelBoxHeight + config.boxMargin * 2,
    );
    var endIndex = eventIndex;
    for (
      var index = eventIndex + 1;
      index < sequenceData!.events.length;
      index++
    ) {
      final candidate = sequenceData!.events[index];
      if (candidate is SequenceFragmentData &&
          candidate.isEnd &&
          candidate.kind == fragment.kind &&
          candidate.depth == fragment.depth) {
        endIndex = index;
        break;
      }
    }
    final rect = Rect.fromLTWH(
      left,
      y - boxHeight / 2,
      width - left - config.boxMargin,
      math.max(boxHeight, (endIndex - eventIndex) * spacing + boxHeight / 2),
    );
    final isBackground =
        fragment.kind == SequenceFragmentKind.rectangle ||
        fragment.kind == SequenceFragmentKind.box;
    canvas.drawRect(
      rect,
      Paint()
        ..color = isBackground
            ? const Color(0x143F51B5)
            : const Color(0x0F607D8B),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0x99607D8B)
        ..style = PaintingStyle.stroke,
    );
    _smallText(
      canvas,
      '${fragment.kind.name}${fragment.label == null ? '' : ' ${fragment.label}'}',
      Offset(left + config.boxTextMargin, y - config.labelBoxHeight / 2),
      FontWeight.w600,
    );
  }

  void _drawLifecycle(Canvas canvas, SequenceLifecycleData event, double y) {
    final node = diagram.getNode(event.actor);
    if (node == null) return;
    final point = Offset(node.x + node.width / 2, y);
    final paint = Paint()
      ..color = event.kind == SequenceLifecycleKind.create
          ? const Color(0xFF2E7D32)
          : const Color(0xFFC62828)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (event.kind == SequenceLifecycleKind.create) {
      canvas.drawCircle(point, 7, paint);
      canvas.drawLine(
        point - const Offset(4, 0),
        point + const Offset(4, 0),
        paint,
      );
      canvas.drawLine(
        point - const Offset(0, 4),
        point + const Offset(0, 4),
        paint,
      );
    } else {
      canvas.drawLine(
        point - const Offset(6, 6),
        point + const Offset(6, 6),
        paint,
      );
      canvas.drawLine(
        point + const Offset(-6, 6),
        point + const Offset(6, -6),
        paint,
      );
    }
  }

  void _smallText(
    Canvas canvas,
    String text,
    Offset offset,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
          fontSize: 10,
          fontWeight: weight,
          fontFamily: style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 260);
    painter.paint(canvas, offset);
  }

  void _centerText(
    Canvas canvas,
    String text,
    Rect rect,
    FontWeight weight, {
    double fontSize = 10,
    String? fontFamily,
    SequenceTextAlign align = SequenceTextAlign.center,
    bool wrap = true,
    double padding = 4,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
          fontSize: fontSize,
          fontWeight: weight,
          fontFamily: fontFamily ?? style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: switch (align) {
        SequenceTextAlign.left => TextAlign.left,
        SequenceTextAlign.center => TextAlign.center,
        SequenceTextAlign.right => TextAlign.right,
      },
      maxLines: wrap ? null : 1,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - padding * 2);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  FontWeight _fontWeight(String value) {
    final numeric = int.tryParse(value);
    if (numeric != null) {
      return FontWeight.values[((numeric.clamp(100, 900) - 100) ~/ 100)];
    }
    return switch (value.toLowerCase()) {
      'bold' => FontWeight.bold,
      'w500' => FontWeight.w500,
      'w600' => FontWeight.w600,
      'w700' => FontWeight.w700,
      _ => FontWeight.normal,
    };
  }

  void _drawLifeline(
    Canvas canvas,
    MermaidNode node,
    double startY,
    double endY,
  ) {
    final centerX = node.x + node.width / 2;

    final paint = Paint()
      ..color = Color(
        style.defaultEdgeStyle.strokeColor ?? MermaidColors.defaultEdgeColor,
      )
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw dashed lifeline
    const dashLength = 8.0;
    const gapLength = 5.0;
    var currentY = startY;

    while (currentY < endY) {
      final segmentEnd = math.min(currentY + dashLength, endY);
      canvas.drawLine(
        Offset(centerX, currentY),
        Offset(centerX, segmentEnd),
        paint,
      );
      currentY = segmentEnd + gapLength;
    }
  }

  // Predefined colors for participants (similar to reference image)
  static const List<_ParticipantColors> _participantColorPalette = [
    _ParticipantColors(0xFFF3E5F5, 0xFFCE93D8), // Purple/Lavender
    _ParticipantColors(0xFFE0F2F1, 0xFF80CBC4), // Teal/Mint
    _ParticipantColors(0xFFFFF3E0, 0xFFFFCC80), // Orange/Peach
    _ParticipantColors(0xFFE8F5E9, 0xFFA5D6A7), // Green
    _ParticipantColors(0xFFE3F2FD, 0xFF90CAF9), // Blue
    _ParticipantColors(0xFFFCE4EC, 0xFFF48FB1), // Pink
  ];

  _ParticipantColors _getParticipantColors(int index) {
    return _participantColorPalette[index % _participantColorPalette.length];
  }

  void _drawParticipant(Canvas canvas, MermaidNode node) {
    final config = sequenceData?.config ?? const SequenceConfig();
    final nodeIndex = diagram.nodes.indexOf(node);
    final colors = _getParticipantColors(nodeIndex);
    final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);

    final fillPaint = Paint()
      ..color = Color(colors.fill)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Color(colors.stroke)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    _drawParticipantShape(canvas, node, rect, fillPaint, strokePaint);
    _drawParticipantIcon(canvas, node.id, rect);

    // Draw label
    final textStyle = TextStyle(
      color: const Color(0xFF37474F), // Dark blue-gray text
      fontSize: config.actorFontSize,
      fontFamily: config.actorFontFamily,
      fontWeight: _fontWeight(config.actorFontWeight),
    );
    drawText(canvas, node.label, rect.center, textStyle);
  }

  void _drawParticipantBottom(Canvas canvas, MermaidNode node, double y) {
    final config = sequenceData?.config ?? const SequenceConfig();
    final nodeIndex = diagram.nodes.indexOf(node);
    final colors = _getParticipantColors(nodeIndex);
    final rect = Rect.fromLTWH(node.x, y, node.width, node.height);

    final fillPaint = Paint()
      ..color = Color(colors.fill)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Color(colors.stroke)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    _drawParticipantShape(canvas, node, rect, fillPaint, strokePaint);
    _drawParticipantIcon(canvas, node.id, rect);

    final textStyle = TextStyle(
      color: const Color(0xFF37474F),
      fontSize: config.actorFontSize,
      fontFamily: config.actorFontFamily,
      fontWeight: _fontWeight(config.actorFontWeight),
    );
    drawText(canvas, node.label, rect.center, textStyle);
  }

  void _drawParticipantShape(
    Canvas canvas,
    MermaidNode node,
    Rect rect,
    Paint fillPaint,
    Paint strokePaint,
  ) {
    final kind = node is SequenceParticipant
        ? node.participantType
        : ParticipantType.participant;
    switch (kind) {
      case ParticipantType.participant:
        final shape = RRect.fromRectAndRadius(rect, const Radius.circular(8));
        canvas
          ..drawRRect(shape, fillPaint)
          ..drawRRect(shape, strokePaint);
        break;
      case ParticipantType.actor:
        _drawActor(canvas, rect.center, style.getNodeStyle(node.className));
        break;
      case ParticipantType.boundary:
        _drawBoundary(canvas, rect, fillPaint, strokePaint);
        break;
      case ParticipantType.control:
        _drawControl(canvas, rect, fillPaint, strokePaint);
        break;
      case ParticipantType.entity:
        _drawEntity(canvas, rect, fillPaint, strokePaint);
        break;
      case ParticipantType.database:
        _drawDatabase(canvas, rect, fillPaint, strokePaint);
        break;
      case ParticipantType.collections:
        _drawCollections(canvas, rect, fillPaint, strokePaint);
        break;
      case ParticipantType.queue:
        _drawQueue(canvas, rect, fillPaint, strokePaint);
        break;
    }
  }

  void _drawParticipantIcon(Canvas canvas, String participantId, Rect rect) {
    SequenceParticipantData? participant;
    for (final candidate in sequenceData?.participants ?? const []) {
      if (candidate.id == participantId) {
        participant = candidate;
        break;
      }
    }
    final icon = participant?.icon?.trim();
    if (icon == null || icon.isEmpty) return;
    final glyph = switch (icon.toLowerCase()) {
      '@clock' => '◷',
      '@computer' => '▣',
      '@database' => '◫',
      '@cloud' => '☁',
      _ when icon.startsWith('@') => '◆',
      _ => '▧',
    };
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          color: Color(style.defaultNodeStyle.textColor ?? 0xFF37474F),
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(rect.right - painter.width - 6, rect.top + 5));
  }

  void _drawBoundary(Canvas canvas, Rect rect, Paint fill, Paint stroke) {
    final radius = math.min(rect.width, rect.height) * 0.28;
    final center = rect.center;
    canvas
      ..drawCircle(center, radius, fill)
      ..drawCircle(center, radius, stroke)
      ..drawLine(
        Offset(center.dx - radius, center.dy - radius),
        Offset(center.dx - radius, center.dy + radius),
        stroke,
      )
      ..drawLine(
        Offset(center.dx - radius * 1.55, center.dy),
        Offset(center.dx - radius, center.dy),
        stroke,
      );
  }

  void _drawControl(Canvas canvas, Rect rect, Paint fill, Paint stroke) {
    final radius = math.min(rect.width, rect.height) * 0.28;
    final center = rect.center;
    canvas
      ..drawCircle(center, radius, fill)
      ..drawCircle(center, radius, stroke);
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.65);
    canvas.drawArc(arcRect, -math.pi * 0.2, math.pi * 1.45, false, stroke);
    final tip = Offset(center.dx + radius * 0.58, center.dy - radius * 0.25);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - 7, tip.dy - 2)
        ..lineTo(tip.dx - 3, tip.dy + 5)
        ..close(),
      stroke,
    );
  }

  void _drawEntity(Canvas canvas, Rect rect, Paint fill, Paint stroke) {
    final radius = math.min(rect.width, rect.height) * 0.28;
    final center = rect.center;
    canvas
      ..drawCircle(center, radius, fill)
      ..drawCircle(center, radius, stroke)
      ..drawLine(
        Offset(center.dx - radius, center.dy + radius + 4),
        Offset(center.dx + radius, center.dy + radius + 4),
        stroke,
      );
  }

  void _drawDatabase(Canvas canvas, Rect rect, Paint fill, Paint stroke) {
    final body = Rect.fromCenter(
      center: rect.center,
      width: rect.width * 0.58,
      height: rect.height * 0.72,
    );
    final capHeight = math.max(8.0, body.height * 0.2);
    canvas
      ..drawRect(
        Rect.fromLTRB(
          body.left,
          body.top + capHeight / 2,
          body.right,
          body.bottom - capHeight / 2,
        ),
        fill,
      )
      ..drawOval(
        Rect.fromLTWH(body.left, body.top, body.width, capHeight),
        fill,
      )
      ..drawOval(
        Rect.fromLTWH(
          body.left,
          body.bottom - capHeight,
          body.width,
          capHeight,
        ),
        fill,
      )
      ..drawOval(
        Rect.fromLTWH(body.left, body.top, body.width, capHeight),
        stroke,
      )
      ..drawOval(
        Rect.fromLTWH(
          body.left,
          body.bottom - capHeight,
          body.width,
          capHeight,
        ),
        stroke,
      )
      ..drawLine(
        Offset(body.left, body.top + capHeight / 2),
        Offset(body.left, body.bottom - capHeight / 2),
        stroke,
      )
      ..drawLine(
        Offset(body.right, body.top + capHeight / 2),
        Offset(body.right, body.bottom - capHeight / 2),
        stroke,
      );
  }

  void _drawCollections(Canvas canvas, Rect rect, Paint fill, Paint stroke) {
    for (var index = 2; index >= 0; index--) {
      final shifted = rect.shift(Offset(index * -4, index * -4));
      final shape = RRect.fromRectAndRadius(
        shifted.deflate(4),
        const Radius.circular(5),
      );
      canvas
        ..drawRRect(shape, fill)
        ..drawRRect(shape, stroke);
    }
  }

  void _drawQueue(Canvas canvas, Rect rect, Paint fill, Paint stroke) {
    final body = rect.deflate(5);
    final radiusX = math.max(6.0, body.height * 0.12);
    final shape = RRect.fromRectAndRadius(body, Radius.circular(radiusX));
    canvas
      ..drawRRect(shape, fill)
      ..drawRRect(shape, stroke)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(body.right - radiusX, body.center.dy),
          width: radiusX * 2,
          height: body.height,
        ),
        stroke,
      );
  }

  void _drawActor(Canvas canvas, Offset center, NodeStyle nodeStyle) {
    final strokePaint = Paint()
      ..color = Color(nodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const headRadius = 10.0;
    const bodyHeight = 20.0;
    const armSpan = 15.0;
    const legSpan = 12.0;

    // Head
    canvas.drawCircle(
      Offset(center.dx, center.dy - bodyHeight - headRadius),
      headRadius,
      strokePaint,
    );

    // Body
    canvas.drawLine(
      Offset(center.dx, center.dy - bodyHeight),
      Offset(center.dx, center.dy),
      strokePaint,
    );

    // Arms
    canvas.drawLine(
      Offset(center.dx - armSpan, center.dy - bodyHeight + 5),
      Offset(center.dx + armSpan, center.dy - bodyHeight + 5),
      strokePaint,
    );

    // Legs
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx - legSpan, center.dy + 15),
      strokePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + legSpan, center.dy + 15),
      strokePaint,
    );
  }

  void _drawMessage(
    Canvas canvas,
    MermaidEdge edge,
    double y, {
    SequenceMessageEventData? event,
  }) {
    final fromNode = diagram.getNode(edge.from);
    final toNode = diagram.getNode(edge.to);

    if (fromNode == null || toNode == null) return;

    final fromX = fromNode.x + fromNode.width / 2;
    final toX = toNode.x + toNode.width / 2;

    final paint = createEdgePaint(edge);

    // Self-referential message
    if (edge.from == edge.to) {
      _drawSelfMessage(canvas, fromX, y, edge, paint, wrap: event?.wrap);
      return;
    }

    // Draw the line
    drawLine(canvas, Offset(fromX, y), Offset(toX, y), paint, edge.lineType);

    if (event?.centralAtSource ?? false) {
      canvas.drawCircle(
        Offset(fromX, y),
        5,
        paint..style = PaintingStyle.stroke,
      );
    }
    if (event?.centralAtTarget ?? false) {
      canvas.drawCircle(Offset(toX, y), 5, paint..style = PaintingStyle.stroke);
    }

    // Draw arrow head
    if (event != null && _isHalfArrow(event.signalKind)) {
      _drawHalfArrow(
        canvas,
        Offset(toX, y),
        toX > fromX ? 1 : -1,
        event.signalKind,
        paint,
      );
    } else if (edge.arrowType != ArrowType.none) {
      final angle = toX > fromX ? 0.0 : math.pi;
      drawArrowHead(canvas, Offset(toX, y), angle, edge.arrowType, paint);
    }
    if (edge.bidirectional) {
      drawArrowHead(
        canvas,
        Offset(fromX, y),
        toX > fromX ? math.pi : 0,
        edge.arrowType,
        paint,
      );
    }

    // Draw label
    if (edge.label != null && edge.label!.isNotEmpty) {
      final config = sequenceData?.config ?? const SequenceConfig();
      final left = math.min(fromX, toX);
      final right = math.max(fromX, toX);
      final labelX = switch (config.messageAlign) {
        SequenceTextAlign.left => left + config.wrapPadding,
        SequenceTextAlign.center => (fromX + toX) / 2,
        SequenceTextAlign.right => right - config.wrapPadding,
      };
      final edgeStyle = edge.style ?? style.defaultEdgeStyle;
      final textStyle = TextStyle(
        color: Color(edgeStyle.labelColor ?? MermaidColors.defaultTextColor),
        fontSize: config.messageFontSize,
        fontFamily: config.messageFontFamily,
        fontWeight: _fontWeight(config.messageFontWeight),
      );
      drawText(
        canvas,
        edge.label!,
        Offset(labelX, y - config.messageFontSize),
        textStyle,
        align: switch (config.messageAlign) {
          SequenceTextAlign.left => TextAlign.left,
          SequenceTextAlign.center => TextAlign.center,
          SequenceTextAlign.right => TextAlign.right,
        },
        backgroundColor: Color(
          edgeStyle.labelBackgroundColor ?? style.backgroundColor,
        ),
        maxWidth: (event?.wrap ?? config.wrap)
            ? (right - left - config.wrapPadding * 2)
            : null,
      );
    }
  }

  bool _isHalfArrow(SequenceSignalKind kind) =>
      kind.index >= SequenceSignalKind.solidTop.index;

  void _drawHalfArrow(
    Canvas canvas,
    Offset tip,
    int direction,
    SequenceSignalKind kind,
    Paint paint,
  ) {
    final top = {
      SequenceSignalKind.solidTop,
      SequenceSignalKind.stickTop,
      SequenceSignalKind.solidTopDotted,
      SequenceSignalKind.stickTopDotted,
      SequenceSignalKind.solidTopReverse,
      SequenceSignalKind.stickTopReverse,
      SequenceSignalKind.solidTopReverseDotted,
      SequenceSignalKind.stickTopReverseDotted,
    }.contains(kind);
    final reverse = kind.name.contains('Reverse');
    final endpoint = reverse ? tip - Offset(direction * 12, 0) : tip;
    final wing = endpoint - Offset(direction * 10, top ? -7 : 7);
    canvas.drawLine(endpoint, wing, paint);
  }

  void _drawSelfMessage(
    Canvas canvas,
    double x,
    double y,
    MermaidEdge edge,
    Paint paint, {
    bool? wrap,
  }) {
    const loopWidth = 30.0;
    const loopHeight = 20.0;

    final rightAngles = sequenceData?.config.rightAngles ?? false;
    final path = Path()..moveTo(x, y);
    if (rightAngles) {
      path
        ..lineTo(x + loopWidth, y)
        ..lineTo(x + loopWidth, y + loopHeight)
        ..lineTo(x, y + loopHeight);
    } else {
      path.cubicTo(
        x + loopWidth * 2,
        y - 10,
        x + loopWidth * 2,
        y + loopHeight + 10,
        x,
        y + loopHeight,
      );
    }

    if (edge.lineType == LineType.dotted) {
      // Draw dashed path
      final metrics = path.computeMetrics();
      for (final metric in metrics) {
        var distance = 0.0;
        while (distance < metric.length) {
          final segmentLength = math.min(5.0, metric.length - distance);
          final extractedPath = metric.extractPath(
            distance,
            distance + segmentLength,
          );
          canvas.drawPath(extractedPath, paint);
          distance += 10.0; // 5 dash + 5 gap
        }
      }
    } else {
      canvas.drawPath(path, paint);
    }

    // Arrow head pointing down-left
    if (edge.arrowType != ArrowType.none) {
      drawArrowHead(
        canvas,
        Offset(x, y + loopHeight),
        math.pi, // Pointing left
        edge.arrowType,
        paint,
      );
    }

    // Label
    if (edge.label != null && edge.label!.isNotEmpty) {
      final config = sequenceData?.config ?? const SequenceConfig();
      final edgeStyle = edge.style ?? style.defaultEdgeStyle;
      final textStyle = TextStyle(
        color: Color(edgeStyle.labelColor ?? MermaidColors.defaultTextColor),
        fontSize: config.messageFontSize,
        fontFamily: config.messageFontFamily,
        fontWeight: _fontWeight(config.messageFontWeight),
      );
      drawText(
        canvas,
        edge.label!,
        Offset(x + loopWidth + 5, y + loopHeight / 2),
        textStyle,
        align: TextAlign.left,
        maxWidth: (wrap ?? config.wrap)
            ? config.width - config.wrapPadding * 2
            : null,
      );
    }
  }
}
