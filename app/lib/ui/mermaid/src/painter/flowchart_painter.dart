/*
 * [INPUT]: Depends on laid-out flowchart nodes/edges/subgraphs, Mermaid styles, responsive settings, and typed flowchart renderer configuration.
 * [OUTPUT]: Paints native flowchart titles, containers, shapes, labels, configured edge curves, markers, and interactions on Canvas.
 * [POS]: Serves as the flowchart-specific renderer over the shared Mermaid painter primitives.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../config/icon_registry.dart';
import '../config/image_registry.dart';
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/flowchart.dart';
import '../models/node.dart';
import '../models/style.dart';
import 'mermaid_painter.dart';

/// Painter for flowchart diagrams
class FlowchartPainter extends MermaidPainter {
  /// Creates a flowchart painter
  const FlowchartPainter({
    required super.diagram,
    required super.style,
    this.deviceConfig,
  });

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (diagram.title case final title? when title.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(
            color: Color(
              style.defaultNodeStyle.textColor ??
                  MermaidColors.defaultTextColor,
            ),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      painter.paint(
        canvas,
        Offset(
          (size.width - painter.width) / 2,
          diagram.flowchartConfig?.titleTopMargin ?? 25,
        ),
      );
    }
    // Draw subgraphs first (background)
    Map<String, Rect>? subgraphBounds;
    if (diagram.subgraphs.isNotEmpty) {
      subgraphBounds = _drawSubgraphs(canvas);
    }

    // Draw edges (behind nodes)
    for (final edge in diagram.edges) {
      if (edge.invisible) continue;
      if (edge.isSubgraphEdge && subgraphBounds != null) {
        _drawSubgraphEdge(canvas, edge, subgraphBounds);
      } else {
        _drawEdge(canvas, edge);
      }
    }

    // Draw nodes on top
    for (final node in diagram.nodes) {
      _drawNode(canvas, node);
    }
  }

  /// Draws all subgraphs with their bounds and labels
  /// Returns a map of subgraph ID to its bounds
  Map<String, Rect> _drawSubgraphs(Canvas canvas) {
    final subgraphBounds = <String, Rect>{};

    // Calculate bounds for each subgraph
    for (final sg in diagram.subgraphs) {
      final bounds = _calculateSubgraphBounds(sg);
      if (bounds != null) {
        subgraphBounds[sg.id] = bounds;
        _drawSubgraphBox(canvas, sg, bounds);
      }
    }

    return subgraphBounds;
  }

  /// Draws an edge between subgraphs
  void _drawSubgraphEdge(
    Canvas canvas,
    MermaidEdge edge,
    Map<String, Rect> subgraphBounds,
  ) {
    if (edge.invisible) return;
    final fromBounds = subgraphBounds[edge.from];
    final toBounds = subgraphBounds[edge.to];

    if (fromBounds == null || toBounds == null) return;

    final paint = createEdgePaint(edge);

    // Calculate connection points based on relative positions
    Offset fromPoint;
    Offset toPoint;

    final dx = toBounds.center.dx - fromBounds.center.dx;
    final dy = toBounds.center.dy - fromBounds.center.dy;

    if (dx.abs() > dy.abs()) {
      // Horizontal connection
      if (dx > 0) {
        // To is to the right
        fromPoint = Offset(fromBounds.right, fromBounds.center.dy);
        toPoint = Offset(toBounds.left, toBounds.center.dy);
      } else {
        // To is to the left
        fromPoint = Offset(fromBounds.left, fromBounds.center.dy);
        toPoint = Offset(toBounds.right, toBounds.center.dy);
      }
    } else {
      // Vertical connection
      if (dy > 0) {
        // To is below
        fromPoint = Offset(fromBounds.center.dx, fromBounds.bottom);
        toPoint = Offset(toBounds.center.dx, toBounds.top);
      } else {
        // To is above
        fromPoint = Offset(fromBounds.center.dx, fromBounds.top);
        toPoint = Offset(toBounds.center.dx, toBounds.bottom);
      }
    }

    // Draw line
    final path = Path()
      ..moveTo(fromPoint.dx, fromPoint.dy)
      ..lineTo(toPoint.dx, toPoint.dy);

    if (edge.lineType == LineType.dotted) {
      _drawDashedPath(canvas, path, paint, edge.style?.dashPattern);
    } else {
      canvas.drawPath(path, paint);
    }

    // Draw arrow head
    if (edge.arrowType != ArrowType.none) {
      final angle = math.atan2(
        toPoint.dy - fromPoint.dy,
        toPoint.dx - fromPoint.dx,
      );
      drawArrowHead(canvas, toPoint, angle, edge.arrowType, paint);
    }
    if (edge.sourceArrowType case final sourceType?) {
      final angle = math.atan2(
        fromPoint.dy - toPoint.dy,
        fromPoint.dx - toPoint.dx,
      );
      drawArrowHead(canvas, fromPoint, angle, sourceType, paint);
    }

    // Draw label
    if (edge.label != null && edge.label!.isNotEmpty) {
      final midPoint = Offset(
        (fromPoint.dx + toPoint.dx) / 2,
        (fromPoint.dy + toPoint.dy) / 2,
      );

      final edgeStyle = edge.style ?? style.defaultEdgeStyle;
      final textStyle = TextStyle(
        color: Color(edgeStyle.labelColor ?? MermaidColors.defaultTextColor),
        fontSize: edgeStyle.labelFontSize,
      );

      drawText(
        canvas,
        edge.label!,
        midPoint + const Offset(0, -12),
        textStyle,
        backgroundColor: Color(
          edgeStyle.labelBackgroundColor ?? style.backgroundColor,
        ),
      );
    }
  }

  /// Calculate the bounding box for a subgraph
  Rect? _calculateSubgraphBounds(Subgraph sg) {
    if (sg.nodeIds.isEmpty) return null;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final nodeId in sg.nodeIds) {
      final node = diagram.getNode(nodeId);
      if (node != null) {
        minX = math.min(minX, node.x);
        minY = math.min(minY, node.y);
        maxX = math.max(maxX, node.x + node.width);
        maxY = math.max(maxY, node.y + node.height);
      }
    }

    if (minX == double.infinity) return null;

    // Add padding around nodes
    final config = diagram.flowchartConfig;
    final padding = config?.padding ?? 15;
    final titleHeight =
        30.0 +
        (config?.subgraphTitleMarginTop ?? 0) +
        (config?.subgraphTitleMarginBottom ?? 0);

    return Rect.fromLTRB(
      minX - padding,
      minY - padding - titleHeight,
      maxX + padding,
      maxY + padding,
    );
  }

  /// Draw a subgraph box with label
  void _drawSubgraphBox(Canvas canvas, Subgraph sg, Rect bounds) {
    final sgStyle = sg.style;

    // Background fill
    final fillPaint = Paint()
      ..color = Color(sgStyle?.backgroundColor ?? 0xFFF5F5F5)
      ..style = PaintingStyle.fill;

    // Border
    final strokePaint = Paint()
      ..color = Color(sgStyle?.borderColor ?? 0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sgStyle?.borderWidth ?? 1.5;

    // Draw rounded rectangle
    final rrect = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(sgStyle?.borderRadius ?? 8.0),
    );

    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, strokePaint);

    // Draw title/label
    final textStyle = TextStyle(
      color: Color(
        style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor,
      ),
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
    );

    final textSpan = TextSpan(text: sg.label, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position title at top center of subgraph
    final titleX = bounds.left + (bounds.width - textPainter.width) / 2;
    final titleY =
        bounds.top + 8 + (diagram.flowchartConfig?.subgraphTitleMarginTop ?? 0);

    textPainter.paint(canvas, Offset(titleX, titleY));
  }

  /// Check if layout is horizontal
  bool get _isHorizontal =>
      diagram.direction == DiagramDirection.leftToRight ||
      diagram.direction == DiagramDirection.rightToLeft;

  void _drawNode(Canvas canvas, MermaidNode node) {
    final nodeStyle = node.style ?? style.getNodeStyle(node.className);

    final fillPaint = Paint()
      ..color = Color(nodeStyle.fillColor ?? MermaidColors.defaultNodeFill)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Color(nodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke)
      ..style = PaintingStyle.stroke
      ..strokeWidth = nodeStyle.strokeWidth;

    final fullRect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
    var rect = fullRect;
    if (node.shape == NodeShape.icon || node.shape == NodeShape.image) {
      final visualHeight = _nodeAttributeNumber(node, 'h') ?? 48;
      final visualWidth = node.shape == NodeShape.icon
          ? visualHeight
          : _nodeAttributeNumber(node, 'w') ?? visualHeight;
      final topLabel = node.attributes['pos']?.toString().toLowerCase() == 't';
      rect = Rect.fromCenter(
        center: Offset(
          fullRect.center.dx,
          topLabel
              ? fullRect.bottom - visualHeight / 2
              : fullRect.top + visualHeight / 2,
        ),
        width: math.min(visualWidth, fullRect.width),
        height: math.min(visualHeight, fullRect.height),
      );
    }
    final center = rect.center;

    // Draw shape based on type
    switch (node.shape) {
      case NodeShape.rectangle:
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(nodeStyle.borderRadius),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;

      case NodeShape.roundedRect:
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;

      case NodeShape.stadium:
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(rect.height / 2),
        );
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;

      case NodeShape.circle:
        final radius = math.min(rect.width, rect.height) / 2;
        canvas.drawCircle(center, radius, fillPaint);
        canvas.drawCircle(center, radius, strokePaint);
        break;

      case NodeShape.doubleCircle:
        final radius = math.min(rect.width, rect.height) / 2;
        canvas.drawCircle(center, radius, fillPaint);
        canvas.drawCircle(center, radius, strokePaint);
        canvas.drawCircle(center, radius - 5, strokePaint);
        break;

      case NodeShape.diamond:
        final path = Path()
          ..moveTo(center.dx, rect.top)
          ..lineTo(rect.right, center.dy)
          ..lineTo(center.dx, rect.bottom)
          ..lineTo(rect.left, center.dy)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case NodeShape.hexagon:
        final inset = rect.width * 0.15;
        final path = Path()
          ..moveTo(rect.left + inset, rect.top)
          ..lineTo(rect.right - inset, rect.top)
          ..lineTo(rect.right, center.dy)
          ..lineTo(rect.right - inset, rect.bottom)
          ..lineTo(rect.left + inset, rect.bottom)
          ..lineTo(rect.left, center.dy)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case NodeShape.parallelogram:
        final skew = rect.width * 0.15;
        final path = Path()
          ..moveTo(rect.left + skew, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right - skew, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case NodeShape.parallelogramAlt:
        final skew = rect.width * 0.15;
        final path = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right - skew, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left + skew, rect.bottom)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case NodeShape.trapezoid:
        final inset = rect.width * 0.1;
        final path = Path()
          ..moveTo(rect.left + inset, rect.top)
          ..lineTo(rect.right - inset, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case NodeShape.trapezoidAlt:
        final inset = rect.width * 0.1;
        final path = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right - inset, rect.bottom)
          ..lineTo(rect.left + inset, rect.bottom)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case NodeShape.cylinder:
        _drawCylinder(canvas, rect, fillPaint, strokePaint);
        break;

      case NodeShape.subroutine:
        // Rectangle with double vertical lines on sides
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
        const lineOffset = 8.0;
        canvas.drawLine(
          Offset(rect.left + lineOffset, rect.top),
          Offset(rect.left + lineOffset, rect.bottom),
          strokePaint,
        );
        canvas.drawLine(
          Offset(rect.right - lineOffset, rect.top),
          Offset(rect.right - lineOffset, rect.bottom),
          strokePaint,
        );
        break;

      case NodeShape.asymmetric:
        final path = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right - 10, rect.top)
          ..lineTo(rect.right, center.dy)
          ..lineTo(rect.right - 10, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case NodeShape.textBlock ||
          NodeShape.notchedRectangle ||
          NodeShape.linedRectangle ||
          NodeShape.smallCircle ||
          NodeShape.framedCircle ||
          NodeShape.forkJoin ||
          NodeShape.hourglass ||
          NodeShape.braceLeft ||
          NodeShape.braceRight ||
          NodeShape.braces ||
          NodeShape.lightningBolt ||
          NodeShape.document ||
          NodeShape.delay ||
          NodeShape.horizontalCylinder ||
          NodeShape.linedCylinder ||
          NodeShape.curvedTrapezoid ||
          NodeShape.dividedRectangle ||
          NodeShape.triangle ||
          NodeShape.windowPane ||
          NodeShape.filledCircle ||
          NodeShape.notchedPentagon ||
          NodeShape.flippedTriangle ||
          NodeShape.slopedRectangle ||
          NodeShape.multiDocument ||
          NodeShape.multiProcess ||
          NodeShape.bowTieRectangle ||
          NodeShape.crossedCircle ||
          NodeShape.taggedDocument ||
          NodeShape.taggedRectangle ||
          NodeShape.paperTape ||
          NodeShape.odd ||
          NodeShape.linedDocument ||
          NodeShape.datastore ||
          NodeShape.bang ||
          NodeShape.cloud ||
          NodeShape.icon ||
          NodeShape.image:
        _drawExtendedShape(canvas, node, rect, fillPaint, strokePaint);
        break;
    }

    // Draw label
    final textStyle = TextStyle(
      color: Color(nodeStyle.textColor ?? MermaidColors.defaultTextColor),
      fontSize: nodeStyle.fontSize,
      fontWeight: nodeStyle.fontWeight,
    );
    final labelCenter =
        (node.shape == NodeShape.icon || node.shape == NodeShape.image)
        ? Offset(
            fullRect.center.dx,
            node.attributes['pos']?.toString().toLowerCase() == 't'
                ? fullRect.top + (rect.top - fullRect.top) / 2
                : rect.bottom + (fullRect.bottom - rect.bottom) / 2,
          )
        : center;
    drawText(
      canvas,
      node.label,
      labelCenter,
      textStyle,
      maxWidth: diagram.flowchartConfig?.wrappingWidth,
    );
  }

  double? _nodeAttributeNumber(MermaidNode node, String key) {
    final value = node.attributes[key];
    return value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
  }

  void _drawExtendedShape(
    Canvas canvas,
    MermaidNode node,
    Rect rect,
    Paint fill,
    Paint stroke,
  ) {
    final center = rect.center;
    Path polygon(List<Offset> points) => Path()..addPolygon(points, true);
    switch (node.shape) {
      case NodeShape.textBlock:
        return;
      case NodeShape.smallCircle || NodeShape.filledCircle:
        canvas.drawCircle(
          center,
          math.min(rect.width, rect.height) * .22,
          fill,
        );
        canvas.drawCircle(
          center,
          math.min(rect.width, rect.height) * .22,
          stroke,
        );
      case NodeShape.framedCircle:
        final radius = math.min(rect.width, rect.height) / 2;
        canvas.drawCircle(center, radius, fill);
        canvas.drawCircle(center, radius, stroke);
        canvas.drawCircle(center, radius - 5, stroke);
      case NodeShape.forkJoin:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: rect.width, height: 12),
            const Radius.circular(3),
          ),
          fill,
        );
        canvas.drawRect(
          Rect.fromCenter(center: center, width: rect.width, height: 12),
          stroke,
        );
      case NodeShape.hourglass:
        final path = polygon([
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
        ]);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case NodeShape.triangle:
        final path = polygon([
          Offset(center.dx, rect.top),
          rect.bottomRight,
          rect.bottomLeft,
        ]);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case NodeShape.flippedTriangle:
        final path = polygon([
          rect.topLeft,
          rect.topRight,
          Offset(center.dx, rect.bottom),
        ]);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case NodeShape.lightningBolt:
        final path = polygon([
          Offset(center.dx + 2, rect.top),
          Offset(rect.left + rect.width * .28, center.dy + 2),
          center,
          Offset(center.dx - 2, rect.bottom),
          Offset(rect.right - rect.width * .28, center.dy - 2),
          center,
        ]);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case NodeShape.cloud:
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
        for (final offset in const [-.25, 0.0, .25]) {
          canvas.drawCircle(
            Offset(
              center.dx + rect.width * offset,
              center.dy - rect.height * .18,
            ),
            rect.height * .25,
            fill,
          );
        }
      case NodeShape.horizontalCylinder:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.elliptical(rect.width * .18, rect.height / 2),
          ),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.elliptical(rect.width * .18, rect.height / 2),
          ),
          stroke,
        );
        canvas.drawOval(
          Rect.fromLTWH(rect.left, rect.top, rect.width * .28, rect.height),
          stroke,
        );
      case NodeShape.linedCylinder:
        _drawCylinder(canvas, rect, fill, stroke);
        canvas.drawLine(
          Offset(rect.left, rect.top + 9),
          Offset(rect.right, rect.top + 9),
          stroke,
        );
      case NodeShape.document ||
          NodeShape.linedDocument ||
          NodeShape.taggedDocument ||
          NodeShape.multiDocument ||
          NodeShape.paperTape:
        final path = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.bottom - 7)
          ..quadraticBezierTo(
            center.dx,
            rect.bottom + 5,
            rect.left,
            rect.bottom - 7,
          )
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        if (node.shape == NodeShape.linedDocument) {
          canvas.drawLine(
            Offset(rect.left + 5, rect.top + 7),
            Offset(rect.right - 5, rect.top + 7),
            stroke,
          );
        }
      case NodeShape.icon:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          stroke,
        );
        final identity = node.attributes['icon']?.toString();
        final glyph = identity == null
            ? null
            : MermaidIconRegistry.resolve(identity);
        glyph?.paint(
          canvas,
          rect.deflate(rect.shortestSide * .18),
          stroke.color,
        );
      case NodeShape.image:
        final source = node.attributes['img']?.toString();
        final image = source == null
            ? null
            : MermaidImageRegistry.resolve(source);
        if (image != null) {
          paintImage(
            canvas: canvas,
            rect: rect,
            image: image,
            fit: BoxFit.contain,
          );
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            fill,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)),
            stroke,
          );
          canvas.drawLine(rect.topLeft, rect.bottomRight, stroke);
          canvas.drawLine(rect.bottomLeft, rect.topRight, stroke);
        }
      default:
        final path = _extendedPolygon(node.shape, rect);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        _drawExtendedDecorations(canvas, node.shape, rect, stroke);
    }
  }

  Path _extendedPolygon(NodeShape shape, Rect rect) {
    final c = rect.center;
    final notch = math.min(12.0, rect.width * .14);
    final points = switch (shape) {
      NodeShape.notchedRectangle => [
        Offset(rect.left + notch, rect.top),
        rect.topRight,
        rect.bottomRight,
        rect.bottomLeft,
        rect.topLeft,
        Offset(rect.left + notch, rect.top + notch),
      ],
      NodeShape.curvedTrapezoid || NodeShape.slopedRectangle => [
        Offset(rect.left + notch, rect.top),
        rect.topRight,
        Offset(rect.right - notch, rect.bottom),
        rect.bottomLeft,
      ],
      NodeShape.notchedPentagon => [
        rect.topLeft,
        rect.topRight,
        Offset(rect.right, rect.bottom - notch),
        Offset(c.dx, rect.bottom),
        Offset(rect.left, rect.bottom - notch),
      ],
      NodeShape.bowTieRectangle => [
        rect.topLeft,
        rect.topRight,
        Offset(rect.right - notch, c.dy),
        rect.bottomRight,
        rect.bottomLeft,
        Offset(rect.left + notch, c.dy),
      ],
      NodeShape.odd => [
        Offset(rect.left + notch, rect.top),
        rect.topRight,
        rect.bottomRight,
        Offset(rect.left + notch, rect.bottom),
        Offset(rect.left, c.dy),
      ],
      _ => [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft],
    };
    return Path()..addPolygon(points, true);
  }

  void _drawExtendedDecorations(
    Canvas canvas,
    NodeShape shape,
    Rect rect,
    Paint stroke,
  ) {
    if ({
      NodeShape.linedRectangle,
      NodeShape.dividedRectangle,
      NodeShape.datastore,
    }.contains(shape)) {
      canvas.drawLine(
        Offset(rect.left, rect.top + 9),
        Offset(rect.right, rect.top + 9),
        stroke,
      );
    }
    if (shape == NodeShape.windowPane) {
      canvas.drawLine(
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom),
        stroke,
      );
      canvas.drawLine(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        stroke,
      );
    }
    if (shape == NodeShape.multiProcess) {
      canvas.drawRect(rect.shift(const Offset(-4, -4)), stroke);
    }
    if (shape == NodeShape.crossedCircle) {
      canvas.drawOval(rect, stroke);
      canvas.drawLine(rect.topLeft, rect.bottomRight, stroke);
      canvas.drawLine(rect.bottomLeft, rect.topRight, stroke);
    }
    if (shape == NodeShape.bang) {
      canvas.drawCircle(
        rect.center,
        math.min(rect.width, rect.height) / 2,
        stroke,
      );
      canvas.drawLine(
        Offset(rect.center.dx, rect.top + 8),
        Offset(rect.center.dx, rect.bottom - 15),
        stroke,
      );
    }
  }

  void _drawCylinder(
    Canvas canvas,
    Rect rect,
    Paint fillPaint,
    Paint strokePaint,
  ) {
    final ellipseHeight = rect.height * 0.15;

    // Body
    canvas.drawRect(
      Rect.fromLTRB(
        rect.left,
        rect.top + ellipseHeight / 2,
        rect.right,
        rect.bottom - ellipseHeight / 2,
      ),
      fillPaint,
    );

    // Bottom ellipse
    final bottomEllipse = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.bottom - ellipseHeight / 2),
      width: rect.width,
      height: ellipseHeight,
    );
    canvas.drawOval(bottomEllipse, fillPaint);
    canvas.drawOval(bottomEllipse, strokePaint);

    // Top ellipse (on top)
    final topEllipse = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + ellipseHeight / 2),
      width: rect.width,
      height: ellipseHeight,
    );
    canvas.drawOval(topEllipse, fillPaint);
    canvas.drawOval(topEllipse, strokePaint);

    // Side lines
    canvas.drawLine(
      Offset(rect.left, rect.top + ellipseHeight / 2),
      Offset(rect.left, rect.bottom - ellipseHeight / 2),
      strokePaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top + ellipseHeight / 2),
      Offset(rect.right, rect.bottom - ellipseHeight / 2),
      strokePaint,
    );
  }

  void _drawEdge(Canvas canvas, MermaidEdge edge) {
    if (edge.invisible) return;
    final fromNode = diagram.getNode(edge.from);
    final toNode = diagram.getNode(edge.to);

    if (fromNode == null || toNode == null) return;

    final paint = createEdgePaint(edge);

    // Get node centers
    final fromCenter = Offset(
      fromNode.x + fromNode.width / 2,
      fromNode.y + fromNode.height / 2,
    );
    final toCenter = Offset(
      toNode.x + toNode.width / 2,
      toNode.y + toNode.height / 2,
    );

    // Determine connection points based on layout direction and node positions
    final (fromPoint, toPoint) = _getConnectionPoints(fromNode, toNode);

    // Check if this is a back-edge (going backwards in the flow)
    final isBackEdge = _isBackEdge(fromNode, toNode);

    // Draw edge with appropriate curve
    if (isBackEdge) {
      _drawBackEdge(canvas, fromNode, toNode, fromPoint, toPoint, edge, paint);
    } else {
      _drawForwardEdge(
        canvas,
        fromPoint,
        toPoint,
        edge,
        paint,
        fromCenter,
        toCenter,
      );
    }
  }

  /// Check if edge goes backward (against the flow direction)
  bool _isBackEdge(MermaidNode from, MermaidNode to) {
    switch (diagram.direction) {
      case DiagramDirection.topToBottom:
        // Forward: from.y < to.y (going down)
        return from.y > to.y;
      case DiagramDirection.bottomToTop:
        // Forward: from.y > to.y (going up)
        return from.y < to.y;
      case DiagramDirection.leftToRight:
        // Forward: from.x < to.x (going right)
        return from.x > to.x;
      case DiagramDirection.rightToLeft:
        // Forward: from.x > to.x (going left)
        return from.x < to.x;
    }
  }

  /// Get connection points for edge
  (Offset, Offset) _getConnectionPoints(
    MermaidNode fromNode,
    MermaidNode toNode,
  ) {
    final fromCenter = Offset(
      fromNode.x + fromNode.width / 2,
      fromNode.y + fromNode.height / 2,
    );
    final toCenter = Offset(
      toNode.x + toNode.width / 2,
      toNode.y + toNode.height / 2,
    );

    // Calculate relative positions
    final dx = toCenter.dx - fromCenter.dx;
    final dy = toCenter.dy - fromCenter.dy;

    Offset fromPoint;
    Offset toPoint;

    if (_isHorizontal) {
      // Horizontal layout: connect left/right for forward edges
      if (dx > 0) {
        fromPoint = _getNodeEdgePoint(fromNode, _EdgeSide.right);
        toPoint = _getNodeEdgePoint(toNode, _EdgeSide.left);
      } else if (dx < 0) {
        fromPoint = _getNodeEdgePoint(fromNode, _EdgeSide.left);
        toPoint = _getNodeEdgePoint(toNode, _EdgeSide.right);
      } else {
        // Same x, connect top/bottom
        if (dy > 0) {
          fromPoint = _getNodeEdgePoint(fromNode, _EdgeSide.bottom);
          toPoint = _getNodeEdgePoint(toNode, _EdgeSide.top);
        } else {
          fromPoint = _getNodeEdgePoint(fromNode, _EdgeSide.top);
          toPoint = _getNodeEdgePoint(toNode, _EdgeSide.bottom);
        }
      }
    } else {
      // Vertical layout: connect top/bottom for forward edges
      if (dy > 0) {
        fromPoint = _getNodeEdgePoint(fromNode, _EdgeSide.bottom);
        toPoint = _getNodeEdgePoint(toNode, _EdgeSide.top);
      } else if (dy < 0) {
        fromPoint = _getNodeEdgePoint(fromNode, _EdgeSide.top);
        toPoint = _getNodeEdgePoint(toNode, _EdgeSide.bottom);
      } else {
        // Same y, connect left/right
        if (dx > 0) {
          fromPoint = _getNodeEdgePoint(fromNode, _EdgeSide.right);
          toPoint = _getNodeEdgePoint(toNode, _EdgeSide.left);
        } else {
          fromPoint = _getNodeEdgePoint(fromNode, _EdgeSide.left);
          toPoint = _getNodeEdgePoint(toNode, _EdgeSide.right);
        }
      }
    }

    return (fromPoint, toPoint);
  }

  /// Draw forward edge with straight line (standard Mermaid style)
  void _drawForwardEdge(
    Canvas canvas,
    Offset from,
    Offset to,
    MermaidEdge edge,
    Paint paint,
    Offset fromCenter,
    Offset toCenter,
  ) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;

    final path = _configuredEdgePath(from, to, edge);

    // Draw the path
    if (edge.lineType == LineType.dotted || edge.animated) {
      _drawDashedPath(canvas, path, paint, edge.style?.dashPattern);
    } else {
      canvas.drawPath(path, paint);
    }

    // Draw arrow head
    if (edge.arrowType != ArrowType.none) {
      final angle = math.atan2(dy, dx);
      drawArrowHead(canvas, to, angle, edge.arrowType, paint);

      if (edge.sourceArrowType case final sourceType?) {
        final reverseAngle = angle + math.pi;
        drawArrowHead(canvas, from, reverseAngle, sourceType, paint);
      }
    }

    // Draw label
    _drawEdgeLabel(canvas, edge, from, to);
  }

  Path _configuredEdgePath(Offset from, Offset to, MermaidEdge edge) {
    var curve = diagram.flowchartConfig?.curve ?? FlowchartCurve.basis;
    if (edge.interpolate case final name?) {
      curve =
          FlowchartCurve.values
              .where((value) => value.name.toLowerCase() == name.toLowerCase())
              .firstOrNull ??
          curve;
    }
    final path = Path()..moveTo(from.dx, from.dy);
    final middleX = (from.dx + to.dx) / 2;
    final middleY = (from.dy + to.dy) / 2;
    switch (curve) {
      case FlowchartCurve.linear:
        path.lineTo(to.dx, to.dy);
        break;
      case FlowchartCurve.step:
        if (_isHorizontal) {
          path
            ..lineTo(middleX, from.dy)
            ..lineTo(middleX, to.dy);
        } else {
          path
            ..lineTo(from.dx, middleY)
            ..lineTo(to.dx, middleY);
        }
        path.lineTo(to.dx, to.dy);
        break;
      case FlowchartCurve.stepAfter:
        path
          ..lineTo(to.dx, from.dy)
          ..lineTo(to.dx, to.dy);
        break;
      case FlowchartCurve.stepBefore:
        path
          ..lineTo(from.dx, to.dy)
          ..lineTo(to.dx, to.dy);
        break;
      case FlowchartCurve.rounded:
        if (_isHorizontal) {
          path
            ..lineTo(middleX - 6, from.dy)
            ..quadraticBezierTo(middleX, from.dy, middleX, from.dy + 6)
            ..lineTo(middleX, to.dy - 6)
            ..quadraticBezierTo(middleX, to.dy, middleX + 6, to.dy)
            ..lineTo(to.dx, to.dy);
        } else {
          path
            ..lineTo(from.dx, middleY - 6)
            ..quadraticBezierTo(from.dx, middleY, from.dx + 6, middleY)
            ..lineTo(to.dx - 6, middleY)
            ..quadraticBezierTo(to.dx, middleY, to.dx, middleY + 6)
            ..lineTo(to.dx, to.dy);
        }
        break;
      case FlowchartCurve.bumpX:
      case FlowchartCurve.monotoneX:
        path.cubicTo(middleX, from.dy, middleX, to.dy, to.dx, to.dy);
        break;
      case FlowchartCurve.bumpY:
      case FlowchartCurve.monotoneY:
        path.cubicTo(from.dx, middleY, to.dx, middleY, to.dx, to.dy);
        break;
      case FlowchartCurve.basis:
      case FlowchartCurve.cardinal:
      case FlowchartCurve.catmullRom:
      case FlowchartCurve.natural:
        final tension = switch (curve) {
          FlowchartCurve.cardinal => 0.35,
          FlowchartCurve.catmullRom => 0.45,
          FlowchartCurve.natural => 0.55,
          _ => 0.5,
        };
        if (_isHorizontal) {
          final delta = (to.dx - from.dx) * tension;
          path.cubicTo(
            from.dx + delta,
            from.dy,
            to.dx - delta,
            to.dy,
            to.dx,
            to.dy,
          );
        } else {
          final delta = (to.dy - from.dy) * tension;
          path.cubicTo(
            from.dx,
            from.dy + delta,
            to.dx,
            to.dy - delta,
            to.dx,
            to.dy,
          );
        }
        break;
    }
    return path;
  }

  /// Draw back edge (loops back) with curved path around nodes
  /// Routes around the outside to avoid crossing other nodes
  void _drawBackEdge(
    Canvas canvas,
    MermaidNode fromNode,
    MermaidNode toNode,
    Offset from,
    Offset to,
    MermaidEdge edge,
    Paint paint,
  ) {
    final path = Path();
    final loopOffset = 40.0;

    if (!_isHorizontal) {
      // Vertical layout (TD/BT)
      // Find the Y range between the two nodes
      final minY = math.min(fromNode.y, toNode.y);
      final maxY = math.max(
        fromNode.y + fromNode.height,
        toNode.y + toNode.height,
      );

      // Find nodes that are in the vertical range between from and to
      // to determine if we should go left or right
      double leftMostX = double.infinity;
      double rightMostX = double.negativeInfinity;

      for (final node in diagram.nodes) {
        // Check if this node is in the Y range
        final nodeTop = node.y;
        final nodeBottom = node.y + node.height;
        if (nodeBottom >= minY && nodeTop <= maxY) {
          leftMostX = math.min(leftMostX, node.x);
          rightMostX = math.max(rightMostX, node.x + node.width);
        }
      }

      // Calculate distances to left and right edges
      final fromCenterX = fromNode.x + fromNode.width / 2;
      final toCenterX = toNode.x + toNode.width / 2;
      final edgeCenterX = (fromCenterX + toCenterX) / 2;

      final distToLeft = edgeCenterX - leftMostX;
      final distToRight = rightMostX - edgeCenterX;

      // Choose the side with more space (less likely to overlap)
      final goRight = distToRight <= distToLeft;

      double startX, startY, endX, endY, routeX;

      if (goRight) {
        // Route on the right side - outside all nodes in this range
        routeX = rightMostX + loopOffset;
        startX = fromNode.x + fromNode.width;
        startY = fromNode.y + fromNode.height / 2;
        endX = toNode.x + toNode.width;
        endY = toNode.y + toNode.height / 2;
      } else {
        // Route on the left side - outside all nodes in this range
        routeX = leftMostX - loopOffset;
        startX = fromNode.x;
        startY = fromNode.y + fromNode.height / 2;
        endX = toNode.x;
        endY = toNode.y + toNode.height / 2;
      }

      path.moveTo(startX, startY);

      // Draw smooth curved path
      final midY = (startY + endY) / 2;

      path.cubicTo(routeX, startY, routeX, midY, routeX, midY);
      path.cubicTo(routeX, midY, routeX, endY, endX, endY);

      // Draw the path
      if (edge.lineType == LineType.dotted || edge.animated) {
        _drawDashedPath(canvas, path, paint, edge.style?.dashPattern);
      } else {
        canvas.drawPath(path, paint);
      }

      // Draw arrow head pointing into the node
      if (edge.arrowType != ArrowType.none) {
        final arrowPoint = Offset(endX, endY);
        final arrowAngle = goRight ? math.pi : 0.0;
        drawArrowHead(canvas, arrowPoint, arrowAngle, edge.arrowType, paint);
      }
      if (edge.sourceArrowType case final sourceType?) {
        drawArrowHead(
          canvas,
          Offset(startX, startY),
          goRight ? 0 : math.pi,
          sourceType,
          paint,
        );
      }
    } else {
      // Horizontal layout (LR/RL)
      final minX = math.min(fromNode.x, toNode.x);
      final maxX = math.max(
        fromNode.x + fromNode.width,
        toNode.x + toNode.width,
      );

      // Find nodes that are in the X range between from and to
      double topMostY = double.infinity;
      double bottomMostY = double.negativeInfinity;

      for (final node in diagram.nodes) {
        final nodeLeft = node.x;
        final nodeRight = node.x + node.width;
        if (nodeRight >= minX && nodeLeft <= maxX) {
          topMostY = math.min(topMostY, node.y);
          bottomMostY = math.max(bottomMostY, node.y + node.height);
        }
      }

      final fromCenterY = fromNode.y + fromNode.height / 2;
      final toCenterY = toNode.y + toNode.height / 2;
      final edgeCenterY = (fromCenterY + toCenterY) / 2;

      final distToTop = edgeCenterY - topMostY;
      final distToBottom = bottomMostY - edgeCenterY;

      final goTop = distToTop <= distToBottom;

      double startX, startY, endX, endY, routeY;

      if (goTop) {
        routeY = topMostY - loopOffset;
        startX = fromNode.x + fromNode.width / 2;
        startY = fromNode.y;
        endX = toNode.x + toNode.width / 2;
        endY = toNode.y;
      } else {
        routeY = bottomMostY + loopOffset;
        startX = fromNode.x + fromNode.width / 2;
        startY = fromNode.y + fromNode.height;
        endX = toNode.x + toNode.width / 2;
        endY = toNode.y + toNode.height;
      }

      path.moveTo(startX, startY);

      final midX = (startX + endX) / 2;

      path.cubicTo(startX, routeY, midX, routeY, midX, routeY);
      path.cubicTo(midX, routeY, endX, routeY, endX, endY);

      // Draw the path
      if (edge.lineType == LineType.dotted || edge.animated) {
        _drawDashedPath(canvas, path, paint, edge.style?.dashPattern);
      } else {
        canvas.drawPath(path, paint);
      }

      // Draw arrow head
      if (edge.arrowType != ArrowType.none) {
        final arrowPoint = Offset(endX, endY);
        final arrowAngle = goTop ? math.pi / 2 : -math.pi / 2;
        drawArrowHead(canvas, arrowPoint, arrowAngle, edge.arrowType, paint);
      }
      if (edge.sourceArrowType case final sourceType?) {
        drawArrowHead(
          canvas,
          Offset(startX, startY),
          goTop ? -math.pi / 2 : math.pi / 2,
          sourceType,
          paint,
        );
      }
    }

    // Draw label at midpoint of the curve
    _drawEdgeLabel(canvas, edge, from, to);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, [
    List<double>? pattern,
  ]) {
    final metrics = path.computeMetrics();
    final dashLength = pattern?.firstOrNull ?? 5.0;
    final gapLength = pattern != null && pattern.length > 1 ? pattern[1] : 3.0;

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segmentLength = math.min(dashLength, metric.length - distance);
        final extractedPath = metric.extractPath(
          distance,
          distance + segmentLength,
        );
        canvas.drawPath(extractedPath, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  void _drawEdgeLabel(Canvas canvas, MermaidEdge edge, Offset from, Offset to) {
    if (edge.label == null || edge.label!.isEmpty) return;

    // Position label at the midpoint, slightly offset
    final midPoint = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);

    // Offset label to avoid overlapping with the line
    final labelOffset = _isHorizontal
        ? const Offset(0, -12)
        : const Offset(12, 0);

    final edgeStyle = edge.style ?? style.defaultEdgeStyle;
    final textStyle = TextStyle(
      color: Color(edgeStyle.labelColor ?? MermaidColors.defaultTextColor),
      fontSize: edgeStyle.labelFontSize,
    );

    drawText(
      canvas,
      edge.label!,
      midPoint + labelOffset,
      textStyle,
      backgroundColor: Color(
        edgeStyle.labelBackgroundColor ?? style.backgroundColor,
      ),
    );
  }

  /// Get connection point on a specific edge of the node
  Offset _getNodeEdgePoint(MermaidNode node, _EdgeSide side) {
    final centerX = node.x + node.width / 2;
    final centerY = node.y + node.height / 2;

    switch (node.shape) {
      case NodeShape.diamond:
        // Diamond connects at the corners
        switch (side) {
          case _EdgeSide.top:
            return Offset(centerX, node.y);
          case _EdgeSide.bottom:
            return Offset(centerX, node.y + node.height);
          case _EdgeSide.left:
            return Offset(node.x, centerY);
          case _EdgeSide.right:
            return Offset(node.x + node.width, centerY);
        }

      case NodeShape.circle:
      case NodeShape.doubleCircle:
        final radius = math.min(node.width, node.height) / 2;
        switch (side) {
          case _EdgeSide.top:
            return Offset(centerX, centerY - radius);
          case _EdgeSide.bottom:
            return Offset(centerX, centerY + radius);
          case _EdgeSide.left:
            return Offset(centerX - radius, centerY);
          case _EdgeSide.right:
            return Offset(centerX + radius, centerY);
        }

      default:
        // Rectangle and other shapes
        switch (side) {
          case _EdgeSide.top:
            return Offset(centerX, node.y);
          case _EdgeSide.bottom:
            return Offset(centerX, node.y + node.height);
          case _EdgeSide.left:
            return Offset(node.x, centerY);
          case _EdgeSide.right:
            return Offset(node.x + node.width, centerY);
        }
    }
  }
}

/// Edge side for connection points
enum _EdgeSide { top, bottom, left, right }
