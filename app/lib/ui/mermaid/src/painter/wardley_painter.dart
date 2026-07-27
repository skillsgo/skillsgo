/*
 * [INPUT]: Depends on Flutter Canvas, Mermaid style, configured Wardley geometry, and normalized map entities.
 * [OUTPUT]: Paints configured Wardley axes/grid, evolution stages, sized components/labels, dependencies, pipelines, annotations, notes, and strategic forces.
 * [POS]: Serves as the dedicated native painter for wardley-beta diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/style.dart';
import '../models/wardley.dart';
import 'css_color.dart';

class WardleyPainter extends CustomPainter {
  const WardleyPainter({required this.data, required this.style, this.title});

  final WardleyChartData data;
  final MermaidStyle style;
  final String? title;

  @override
  void paint(Canvas canvas, Size size) {
    final fallbackInk = Color(style.defaultNodeStyle.strokeColor ?? 0xFF455A64);
    final fallbackFill = Color(style.defaultNodeStyle.fillColor ?? 0xFFF5F7FA);
    final background =
        parseMermaidCssColor(data.theme.backgroundColor) ??
        Color(style.backgroundColor);
    final axisInk = parseMermaidCssColor(data.theme.axisColor) ?? fallbackInk;
    final axisText =
        parseMermaidCssColor(data.theme.axisTextColor) ??
        Color(style.defaultNodeStyle.textColor ?? 0xff212121);
    final componentFill =
        parseMermaidCssColor(data.theme.componentFill) ?? fallbackFill;
    final componentStroke =
        parseMermaidCssColor(data.theme.componentStroke) ?? fallbackInk;
    final componentText =
        parseMermaidCssColor(data.theme.componentLabelColor) ?? axisText;
    final linkInk = parseMermaidCssColor(data.theme.linkStroke) ?? fallbackInk;
    final evolutionInk =
        parseMermaidCssColor(data.theme.evolutionStroke) ?? Colors.red.shade600;
    final annotationStroke =
        parseMermaidCssColor(data.theme.annotationStroke) ?? fallbackInk;
    final annotationFill =
        parseMermaidCssColor(data.theme.annotationFill) ?? background;
    final annotationText =
        parseMermaidCssColor(data.theme.annotationTextColor) ?? axisText;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final padding = data.padding;
    final plot = Rect.fromLTRB(
      padding,
      padding,
      size.width - padding,
      size.height - padding,
    );
    final line = Paint()
      ..color = axisInk
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(plot.bottomLeft, plot.topLeft, line);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, line);
    _center(
      canvas,
      'Evolution',
      Rect.fromLTWH(
        plot.left,
        size.height - padding / 2,
        plot.width,
        padding / 2,
      ),
      data.axisFontSize,
      FontWeight.w600,
      axisText,
    );
    canvas.save();
    canvas.translate(padding / 3, plot.center.dy);
    canvas.rotate(-math.pi / 2);
    _center(
      canvas,
      'Visibility',
      Rect.fromCenter(
        center: Offset.zero,
        width: plot.height,
        height: padding / 2,
      ),
      data.axisFontSize,
      FontWeight.w600,
      axisText,
    );
    canvas.restore();
    if (title case final value?) {
      _center(
        canvas,
        value,
        Rect.fromLTWH(plot.left, 8, plot.width, 30),
        17,
        FontWeight.w600,
        axisText,
      );
    }
    if (data.showGrid) {
      _drawGrid(
        canvas,
        plot,
        parseMermaidCssColor(data.theme.gridColor) ??
            fallbackInk.withValues(alpha: .2),
      );
    }
    _drawStages(canvas, plot, axisInk, axisText);
    final points = {
      for (final component in data.components)
        component.id: _point(plot, component.visibility, component.evolution),
    };
    _drawPipelines(canvas, points, axisInk, linkInk);
    for (final link in data.links) {
      _drawLink(canvas, points[link.from]!, points[link.to]!, link, linkInk);
    }
    for (final evolution in data.evolutions) {
      final component = data.components.firstWhere(
        (item) => item.id == evolution.component,
      );
      final from = points[component.id]!;
      final target = _point(plot, component.visibility, evolution.target);
      final distance = (target - from).distance;
      final to = distance > data.nodeRadius + 2
          ? target - (target - from) / distance * (data.nodeRadius + 2)
          : target;
      final trendPaint = Paint()
        ..color = evolutionInk
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      _dashed(canvas, from, to, trendPaint);
      _arrow(canvas, from, to, trendPaint);
    }
    for (final component in data.components) {
      _drawComponent(
        canvas,
        points[component.id]!,
        component,
        componentStroke,
        componentFill,
        componentText,
      );
    }
    for (final note in data.notes) {
      _text(
        canvas,
        note.text,
        _point(plot, note.visibility, note.evolution),
        data.labelFontSize,
        FontWeight.w400,
        componentText,
      );
    }
    for (final annotation in data.annotations) {
      final point = _point(plot, annotation.y, annotation.x);
      canvas.drawCircle(point, 10, Paint()..color = annotationFill);
      canvas.drawCircle(
        point,
        10,
        Paint()
          ..color = annotationStroke
          ..style = PaintingStyle.stroke,
      );
      _center(
        canvas,
        '${annotation.number}',
        Rect.fromCircle(center: point, radius: 10),
        data.labelFontSize,
        FontWeight.w600,
        annotationText,
      );
    }
    _drawAnnotationList(
      canvas,
      plot,
      annotationStroke,
      annotationFill,
      annotationText,
    );
    for (final force in data.forces) {
      _drawForce(
        canvas,
        _point(plot, force.y, force.x),
        force,
        componentStroke,
      );
    }
  }

  void _drawGrid(Canvas canvas, Rect plot, Color ink) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth = .75;
    for (var step = 1; step < 4; step++) {
      final fraction = step / 4;
      canvas.drawLine(
        Offset(plot.left, plot.top + plot.height * fraction),
        Offset(plot.right, plot.top + plot.height * fraction),
        paint,
      );
      canvas.drawLine(
        Offset(plot.left + plot.width * fraction, plot.top),
        Offset(plot.left + plot.width * fraction, plot.bottom),
        paint,
      );
    }
  }

  Offset _point(Rect plot, double visibility, double evolution) => Offset(
    plot.left + evolution * plot.width,
    plot.bottom - visibility * plot.height,
  );

  void _drawStages(Canvas canvas, Rect plot, Color ink, Color textColor) {
    final hasCompleteBoundaries =
        data.stages.isNotEmpty &&
        data.stages.every((stage) => stage.boundary != null);
    for (var index = 0; index < data.stages.length; index++) {
      final stage = data.stages[index];
      final start = hasCompleteBoundaries
          ? (index == 0 ? 0.0 : data.stages[index - 1].boundary!)
          : index / data.stages.length;
      final end = hasCompleteBoundaries
          ? stage.boundary!
          : (index + 1) / data.stages.length;
      if (index > 0) {
        final x = plot.left + start.clamp(0, 1) * plot.width;
        _dashed(
          canvas,
          Offset(x, plot.top),
          Offset(x, plot.bottom),
          Paint()
            ..color = ink.withValues(alpha: .8)
            ..strokeWidth = 1,
        );
      }
      final centerX = plot.left + (start + end) / 2 * plot.width;
      _center(
        canvas,
        stage.secondName == null
            ? stage.name
            : '${stage.name}\n${stage.secondName}',
        Rect.fromCenter(
          center: Offset(centerX, plot.bottom + 27),
          width: math.max(70, (end - start) * plot.width),
          height: 44,
        ),
        data.axisFontSize,
        FontWeight.w500,
        textColor,
      );
    }
  }

  void _drawLink(
    Canvas canvas,
    Offset from,
    Offset to,
    WardleyLinkData link,
    Color ink,
  ) {
    final delta = to - from;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    double edgeRadius(String name) {
      final pipelineParent = data.components.any(
        (item) => item.pipelineParent == name,
      );
      return pipelineParent
          ? data.nodeRadius * 1.6 / math.sqrt(2)
          : data.nodeRadius;
    }

    final start = from + direction * edgeRadius(link.from);
    final end = to - direction * edgeRadius(link.to);
    final paint = Paint()
      ..color = ink.withValues(alpha: .75)
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke;
    if (link.kind == WardleyLinkKind.dashed) {
      _dashed(canvas, start, end, paint);
    } else {
      canvas.drawLine(start, end, paint);
    }
    if (link.kind != WardleyLinkKind.dependency &&
        link.kind != WardleyLinkKind.dashed) {
      if (link.kind != WardleyLinkKind.reverse) {
        _arrow(canvas, start, end, paint);
      }
      if (link.kind == WardleyLinkKind.reverse ||
          link.kind == WardleyLinkKind.bidirectional) {
        _arrow(canvas, end, start, paint);
      }
    }
    if (link.label case final label?) {
      final center = (from + to) / 2 + Offset(direction.dy, -direction.dx) * 8;
      var angle = math.atan2(delta.dy, delta.dx);
      if (angle > math.pi / 2 || angle < -math.pi / 2) angle += math.pi;
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle);
      _center(
        canvas,
        label,
        Rect.fromCenter(center: Offset.zero, width: 180, height: 22),
        data.labelFontSize,
        FontWeight.w400,
      );
      canvas.restore();
    }
  }

  void _drawComponent(
    Canvas canvas,
    Offset point,
    WardleyComponentData component,
    Color ink,
    Color fill,
    Color textColor,
  ) {
    final radius = data.nodeRadius;
    final isPipelineParent = data.components.any(
      (item) => item.pipelineParent == component.id,
    );
    final stroke = Paint()
      ..color = ink
      ..strokeWidth = component.isAnchor ? 2.2 : 1.5
      ..style = PaintingStyle.stroke;
    final brush = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    if (!component.isAnchor) {
      if (isPipelineParent) {
        final side = radius * 1.6;
        canvas
          ..drawRect(
            Rect.fromCenter(center: point, width: side, height: side),
            brush,
          )
          ..drawRect(
            Rect.fromCenter(center: point, width: side, height: side),
            stroke,
          );
      } else if (component.strategy == WardleyStrategy.market) {
        _drawMarket(canvas, point, radius, stroke, brush);
      } else {
        if (component.strategy case final strategy?) {
          final overlay = switch (strategy) {
            WardleyStrategy.build => const Color(0xffeeeeee),
            WardleyStrategy.buy => const Color(0xffcccccc),
            WardleyStrategy.outsource => const Color(0xff666666),
            WardleyStrategy.market => fill,
          };
          canvas
            ..drawCircle(point, radius * 2, Paint()..color = overlay)
            ..drawCircle(point, radius * 2, stroke);
        }
        canvas
          ..drawCircle(point, radius, brush)
          ..drawCircle(point, radius, stroke);
      }
    }
    if (component.inertia) {
      final offset =
          radius + 15 + (component.strategy == null ? 0 : radius + 10);
      canvas.drawLine(
        point + Offset(offset, -radius),
        point + Offset(offset, radius),
        Paint()
          ..color = ink
          ..strokeWidth = 6,
      );
    }
    final labelOffset = component.hasLabelOffset
        ? Offset(component.labelOffsetX, component.labelOffsetY)
        : Offset(data.nodeLabelOffset, -data.nodeLabelOffset);
    _text(
      canvas,
      component.name,
      point + labelOffset,
      data.labelFontSize,
      component.isAnchor ? FontWeight.w700 : FontWeight.w500,
      textColor,
    );
  }

  void _drawPipelines(
    Canvas canvas,
    Map<String, Offset> points,
    Color axisInk,
    Color linkInk,
  ) {
    final parents = data.components
        .map((item) => item.pipelineParent)
        .whereType<String>()
        .toSet();
    for (final parent in parents) {
      final children = data.components
          .where((item) => item.pipelineParent == parent)
          .map((item) => (component: item, point: points[item.id]!))
          .toList();
      if (children.isEmpty) continue;
      children.sort(
        (a, b) => a.component.evolution.compareTo(b.component.evolution),
      );
      final minX = children.map((item) => item.point.dx).reduce(math.min);
      final maxX = children.map((item) => item.point.dx).reduce(math.max);
      final y = children.first.point.dy;
      final boxHeight = data.nodeRadius * 4;
      final boxTop = y - boxHeight / 2;
      for (var index = 0; index < children.length - 1; index++) {
        _dashed(
          canvas,
          children[index].point,
          children[index + 1].point,
          Paint()
            ..color = linkInk
            ..strokeWidth = 1,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(minX - 15, boxTop, maxX - minX + 30, boxHeight),
          const Radius.circular(4),
        ),
        Paint()
          ..color = axisInk
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      points[parent] = Offset(
        (minX + maxX) / 2,
        boxTop - data.nodeRadius * 1.6 / 6,
      );
    }
  }

  void _drawMarket(
    Canvas canvas,
    Offset point,
    double radius,
    Paint stroke,
    Paint brush,
  ) {
    canvas
      ..drawCircle(point, radius * 2, brush)
      ..drawCircle(point, radius * 2, stroke);
    final triangleRadius = radius * 1.2;
    final dotRadius = radius * .7;
    final dots = [
      point + Offset(0, -triangleRadius),
      point +
          Offset(-triangleRadius * math.cos(math.pi / 6), triangleRadius * .5),
      point +
          Offset(triangleRadius * math.cos(math.pi / 6), triangleRadius * .5),
    ];
    final triangle = Path()
      ..moveTo(dots[0].dx, dots[0].dy)
      ..lineTo(dots[1].dx, dots[1].dy)
      ..lineTo(dots[2].dx, dots[2].dy)
      ..close();
    canvas.drawPath(triangle, stroke);
    for (final dot in dots) {
      canvas
        ..drawCircle(dot, dotRadius, brush)
        ..drawCircle(
          dot,
          dotRadius,
          Paint()
            ..color = stroke.color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
    }
  }

  void _drawAnnotationList(
    Canvas canvas,
    Rect plot,
    Color ink,
    Color fill,
    Color textColor,
  ) {
    if (data.annotations.isEmpty) return;
    final origin = _point(
      plot,
      data.annotationBoxY ?? .9,
      data.annotationBoxX ?? .05,
    );
    final box = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      210,
      data.annotations.length * 24 + 12,
    );
    canvas.drawRect(box, Paint()..color = fill.withValues(alpha: .92));
    canvas.drawRect(
      box,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke,
    );
    for (var index = 0; index < data.annotations.length; index++) {
      final item = data.annotations[index];
      _text(
        canvas,
        '${item.number}. ${item.text}',
        Offset(box.left + 8, box.top + 7 + index * 24),
        10,
        FontWeight.w400,
        textColor,
      );
    }
  }

  void _drawForce(
    Canvas canvas,
    Offset point,
    WardleyForceData force,
    Color ink,
  ) {
    final stroke = Paint()
      ..color = ink
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const width = 60.0;
    const height = 30.0;
    const head = 20.0;
    final path = Path();
    if (force.kind == WardleyForceKind.accelerator) {
      path
        ..moveTo(point.dx, point.dy - height / 2)
        ..lineTo(point.dx + width - head, point.dy - height / 2)
        ..lineTo(point.dx + width - head, point.dy - height / 2 - 8)
        ..lineTo(point.dx + width, point.dy)
        ..lineTo(point.dx + width - head, point.dy + height / 2 + 8)
        ..lineTo(point.dx + width - head, point.dy + height / 2)
        ..lineTo(point.dx, point.dy + height / 2)
        ..close();
    } else {
      path
        ..moveTo(point.dx + width, point.dy - height / 2)
        ..lineTo(point.dx + head, point.dy - height / 2)
        ..lineTo(point.dx + head, point.dy - height / 2 - 8)
        ..lineTo(point.dx, point.dy)
        ..lineTo(point.dx + head, point.dy + height / 2 + 8)
        ..lineTo(point.dx + head, point.dy + height / 2)
        ..lineTo(point.dx + width, point.dy + height / 2)
        ..close();
    }
    canvas
      ..drawPath(path, Paint()..color = Colors.white)
      ..drawPath(path, stroke);
    _center(
      canvas,
      force.name,
      Rect.fromLTWH(point.dx, point.dy + height / 2 + 3, width, 18),
      10,
      FontWeight.w600,
    );
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    final distance = (to - from).distance;
    if (distance == 0) return;
    final direction = (to - from) / distance;
    for (var offset = 0.0; offset < distance; offset += 10) {
      canvas.drawLine(
        from + direction * offset,
        from + direction * math.min(offset + 6, distance),
        paint,
      );
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const length = 8.0;
    canvas.drawLine(
      to,
      to - Offset(math.cos(angle - .55), math.sin(angle - .55)) * length,
      paint,
    );
    canvas.drawLine(
      to,
      to - Offset(math.cos(angle + .55), math.sin(angle + .55)) * length,
      paint,
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double size,
    FontWeight weight, [
    Color? color,
  ]) {
    final painter = _painter(value, size, weight, color)..layout(maxWidth: 190);
    painter.paint(canvas, offset);
  }

  void _center(
    Canvas canvas,
    String value,
    Rect rect,
    double size,
    FontWeight weight, [
    Color? color,
  ]) {
    final painter = _painter(value, size, weight, color)
      ..layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  TextPainter _painter(
    String value,
    double size,
    FontWeight weight, [
    Color? color,
  ]) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color ?? Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
        fontSize: size,
        fontWeight: weight,
        fontFamily: style.fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 3,
    ellipsis: '…',
  );

  @override
  bool shouldRepaint(WardleyPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.style != style ||
      oldDelegate.title != title;
}
