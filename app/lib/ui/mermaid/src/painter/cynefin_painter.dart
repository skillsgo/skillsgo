/*
 * [INPUT]: Depends on Flutter Canvas, Mermaid style, and fully configured Cynefin domains and transitions.
 * [OUTPUT]: Paints deterministic wavy framework boundaries, domain descriptions, badges, and curved transition arrows.
 * [POS]: Serves as the dedicated native painter for cynefin-beta diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/cynefin.dart';
import '../models/style.dart';

class CynefinPainter extends CustomPainter {
  const CynefinPainter({required this.data, required this.style, this.title});

  final CynefinChartData data;
  final MermaidStyle style;
  final String? title;

  static const _domainMeta = <CynefinDomainName, (String, String)>{
    CynefinDomainName.complex: (
      'Probe → Sense → Respond',
      'Emergent Practices',
    ),
    CynefinDomainName.complicated: (
      'Sense → Analyse → Respond',
      'Good Practices',
    ),
    CynefinDomainName.clear: ('Sense → Categorise → Respond', 'Best Practices'),
    CynefinDomainName.chaotic: ('Act → Sense → Respond', 'Novel Practices'),
    CynefinDomainName.confusion: ('', 'Disorder'),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(data.padding, data.padding);
    final frame = origin & Size(data.width, data.height);
    final center = frame.center;
    final ink = Color(style.defaultNodeStyle.strokeColor ?? 0xFF455A64);
    final rects = <CynefinDomainName, Rect>{
      CynefinDomainName.complex: Rect.fromLTRB(
        frame.left,
        frame.top,
        center.dx,
        center.dy,
      ),
      CynefinDomainName.complicated: Rect.fromLTRB(
        center.dx,
        frame.top,
        frame.right,
        center.dy,
      ),
      CynefinDomainName.chaotic: Rect.fromLTRB(
        frame.left,
        center.dy,
        center.dx,
        frame.bottom,
      ),
      CynefinDomainName.clear: Rect.fromLTRB(
        center.dx,
        center.dy,
        frame.right,
        frame.bottom,
      ),
    };
    final colors = <CynefinDomainName, Color>{
      CynefinDomainName.complex: const Color(0x66E8F1FA),
      CynefinDomainName.complicated: const Color(0x66E9F5EC),
      CynefinDomainName.chaotic: const Color(0x66FBE9E7),
      CynefinDomainName.clear: const Color(0x66FFF4D8),
      CynefinDomainName.confusion: const Color(0x80F0EAF8),
    };
    for (final entry in rects.entries) {
      canvas.drawRect(entry.value, Paint()..color = colors[entry.key]!);
    }

    final boundaryPaint = Paint()
      ..color = ink
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final seed = _resolvedSeed();
    canvas.drawPath(_foldPath(frame, seed), boundaryPaint);
    canvas.drawPath(_horizontalPath(frame, seed + 100), boundaryPaint);
    canvas.drawPath(
      _cliffPath(frame),
      Paint()
        ..color = ink
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    final confusion = Rect.fromCenter(
      center: center,
      width: data.width * .3,
      height: data.height * .3,
    );
    canvas.drawOval(
      confusion,
      Paint()..color = colors[CynefinDomainName.confusion]!,
    );
    canvas.drawOval(confusion, boundaryPaint);

    for (final entry in rects.entries) {
      _domain(canvas, entry.key, entry.value, colors[entry.key]!);
    }
    _domain(
      canvas,
      CynefinDomainName.confusion,
      confusion,
      colors[CynefinDomainName.confusion]!,
    );

    final centers = {
      for (final entry in rects.entries) entry.key: entry.value.center,
      CynefinDomainName.confusion: center,
    };
    for (final transition in data.transitions) {
      final from = centers[transition.from]!;
      final to = centers[transition.to]!;
      final delta = to - from;
      final length = delta.distance;
      if (length == 0) continue;
      final midpoint = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      final control =
          midpoint +
          Offset(-delta.dy / length, delta.dx / length) * (length * .15);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
      canvas.drawPath(path, boundaryPaint);
      final tangent = to - control;
      _arrow(canvas, to - tangent, to, boundaryPaint);
      if (transition.label case final label?) {
        _center(
          canvas,
          label,
          Rect.fromCenter(
            center: control.translate(0, -10),
            width: 180,
            height: 22,
          ),
          10,
          FontWeight.w500,
        );
      }
    }

    if (title case final value?) {
      _center(
        canvas,
        value,
        Rect.fromLTWH(0, 0, size.width, data.padding),
        17,
        FontWeight.w600,
      );
    }
  }

  Path _foldPath(Rect frame, int seed) {
    const segments = 7;
    final amplitude = data.boundaryAmplitude;
    final points = <Offset>[];
    for (var index = 0; index <= segments; index++) {
      final jitter =
          _seededRandom(seed + index * 17) * amplitude * 2 - amplitude;
      points.add(
        Offset(
          frame.center.dx + jitter,
          frame.top + index * frame.height / segments,
        ),
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      final middleY = (start.dy + end.dy) / 2;
      final direction = index.isEven ? 1 : -1;
      final offset =
          amplitude * 1.5 * direction * _seededRandom(seed + index * 31 + 7);
      path.cubicTo(
        start.dx + offset,
        middleY,
        end.dx - offset,
        middleY,
        end.dx,
        end.dy,
      );
    }
    return path;
  }

  Path _horizontalPath(Rect frame, int seed) {
    const segments = 7;
    final amplitude = data.boundaryAmplitude;
    final points = <Offset>[];
    for (var index = 0; index <= segments; index++) {
      final jitter =
          _seededRandom(seed + index * 23) * amplitude * 2 - amplitude;
      points.add(
        Offset(
          frame.left + index * frame.width / segments,
          frame.center.dy + jitter,
        ),
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      final middleX = (start.dx + end.dx) / 2;
      final direction = index.isEven ? 1 : -1;
      final offset =
          amplitude * 1.5 * direction * _seededRandom(seed + index * 37 + 11);
      path.cubicTo(
        middleX,
        start.dy + offset,
        middleX,
        end.dy - offset,
        end.dx,
        end.dy,
      );
    }
    return path;
  }

  Path _cliffPath(Rect frame) {
    final centerX = frame.center.dx;
    final topY = frame.center.dy;
    final bottomY = frame.bottom;
    final amplitude = frame.width * .03;
    return Path()
      ..moveTo(centerX, topY)
      ..cubicTo(
        centerX + amplitude,
        topY + (bottomY - topY) * .2,
        centerX - amplitude * 1.5,
        topY + (bottomY - topY) * .55,
        centerX + amplitude * .5,
        topY + (bottomY - topY) * .75,
      )
      ..cubicTo(
        centerX - amplitude,
        topY + (bottomY - topY) * .85,
        centerX + amplitude * .3,
        topY + (bottomY - topY) * .95,
        centerX,
        bottomY,
      );
  }

  void _domain(
    Canvas canvas,
    CynefinDomainName name,
    Rect rect,
    Color background,
  ) {
    final center = rect.center;
    final isConfusion = name == CynefinDomainName.confusion;
    final labelY =
        center.dy - (data.showDomainDescriptions ? (isConfusion ? 10 : 30) : 0);
    _center(
      canvas,
      _label(name),
      Rect.fromCenter(
        center: Offset(center.dx, labelY),
        width: rect.width,
        height: 24,
      ),
      14,
      FontWeight.w700,
    );
    if (data.showDomainDescriptions) {
      final meta = _domainMeta[name]!;
      if (!isConfusion) {
        _center(
          canvas,
          meta.$1,
          Rect.fromCenter(
            center: Offset(center.dx, center.dy - 10),
            width: rect.width - 16,
            height: 18,
          ),
          10,
          FontWeight.w400,
        );
      }
      _center(
        canvas,
        meta.$2,
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + (isConfusion ? 8 : 5)),
          width: rect.width - 16,
          height: 18,
        ),
        10,
        FontWeight.w400,
      );
    }

    final domain = data.domains.firstWhere((item) => item.name == name);
    final visible = isConfusion ? domain.items.take(3).toList() : domain.items;
    final startY =
        center.dy +
        (isConfusion
            ? (data.showDomainDescriptions ? 22 : 14)
            : (data.showDomainDescriptions ? 25 : 15));
    for (var index = 0; index < visible.length; index++) {
      _badge(
        canvas,
        visible[index],
        Offset(center.dx, startY + index * 30),
        background,
      );
    }
    if (domain.items.length > visible.length) {
      _badge(
        canvas,
        '+${domain.items.length - visible.length} more',
        Offset(center.dx, startY + visible.length * 30),
        background.withValues(alpha: .6),
      );
    }
  }

  void _badge(Canvas canvas, String value, Offset topCenter, Color background) {
    final painter = _painter(value, 10, FontWeight.w400)..layout(maxWidth: 220);
    final rect = Rect.fromLTWH(
      topCenter.dx - (painter.width + 20) / 2,
      topCenter.dy,
      painter.width + 20,
      26,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = background.withValues(alpha: .95),
    );
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  int _resolvedSeed() {
    if (data.seed != 0) return data.seed.toInt();
    final signature = [
      title ?? '',
      for (final domain in data.domains)
        '${domain.name.name}:${domain.items.join('|')}',
      for (final transition in data.transitions)
        '${transition.from.name}>${transition.to.name}:${transition.label ?? ''}',
    ].join(';');
    var hash = 0;
    for (final codeUnit in signature.codeUnits) {
      hash = ((hash << 5) - hash + codeUnit).toSigned(32);
    }
    return hash;
  }

  double _seededRandom(int seed) {
    var value = (seed + 0x6D2B79F5).toSigned(32);
    value = ((value ^ (value >>> 15)) * (value | 1)).toSigned(32);
    value ^= (value + ((value ^ (value >>> 7)) * (value | 61)).toSigned(32))
        .toSigned(32);
    return ((value ^ (value >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  String _label(CynefinDomainName name) => name == CynefinDomainName.clear
      ? 'Clear'
      : name.name[0].toUpperCase() + name.name.substring(1);

  void _arrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    canvas.drawLine(
      to,
      to - Offset(math.cos(angle - .55), math.sin(angle - .55)) * 8,
      paint,
    );
    canvas.drawLine(
      to,
      to - Offset(math.cos(angle + .55), math.sin(angle + .55)) * 8,
      paint,
    );
  }

  void _center(
    Canvas canvas,
    String value,
    Rect rect,
    double fontSize,
    FontWeight weight,
  ) {
    final painter = _painter(value, fontSize, weight)
      ..layout(maxWidth: math.max(0, rect.width));
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  TextPainter _painter(String value, double fontSize, FontWeight weight) =>
      TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
            fontSize: fontSize,
            fontWeight: weight,
            fontFamily: style.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      );

  @override
  bool shouldRepaint(CynefinPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.style != style ||
      oldDelegate.title != title;
}
