/*
 * [INPUT]: Depends on Flutter Canvas, semantic fallbacks, configured look/seed/theme/font/padding, and recursive Ishikawa data.
 * [OUTPUT]: Paints a deterministic fish head, descendant-weighted arrowed branches, seeded hand-drawn bones/hachures, and recursive sub-causes.
 * [POS]: Serves as the dedicated native painter for Mermaid Ishikawa diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ishikawa.dart';
import '../models/style.dart';

class IshikawaPainter extends CustomPainter {
  const IshikawaPainter({required this.data, required this.style});

  final IshikawaChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final color =
        _color(data.lineColor) ??
        Color(style.defaultNodeStyle.strokeColor ?? 0xFF455A64);
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke;
    final spineY = size.height / 2;
    final headWidth = math.min(170.0, size.width * .22);
    final padding = data.diagramPadding;
    final headLeft = size.width - padding - headWidth;
    _drawLine(canvas, Offset(padding, spineY), Offset(headLeft, spineY), line);
    final head = Path()
      ..moveTo(headLeft, spineY - 46)
      ..lineTo(headLeft, spineY + 46)
      ..quadraticBezierTo(size.width - padding, spineY, headLeft, spineY - 46)
      ..close();
    final fillColor =
        _color(data.fillColor) ??
        Color(style.defaultNodeStyle.fillColor ?? 0xFFE3F2FD);
    canvas.drawPath(
      head,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    if (data.handDrawn) {
      _drawHachure(canvas, head, head.getBounds(), color, 101);
    }
    canvas.drawPath(head, line);
    _centerText(
      canvas,
      data.effect.text,
      Rect.fromCenter(
        center: Offset(headLeft + headWidth * .42, spineY),
        width: headWidth * .72,
        height: 70,
      ),
      14,
      FontWeight.w600,
    );
    final causes = data.effect.children;
    final pairCount = math.max(1, (causes.length / 2).ceil());
    final usable = headLeft - padding - 30;
    final upperWeight = causes.indexed
        .where((entry) => entry.$1.isEven)
        .fold<int>(0, (sum, entry) => sum + entry.$2.descendantCount);
    final lowerWeight = causes.indexed
        .where((entry) => entry.$1.isOdd)
        .fold<int>(0, (sum, entry) => sum + entry.$2.descendantCount);
    final totalWeight = upperWeight + lowerWeight;
    final verticalPool = math.min(250.0, size.height * .68) * 2;
    final upperSpan = totalWeight == 0
        ? verticalPool / 2
        : math.max(
            verticalPool * .15,
            verticalPool * upperWeight / totalWeight,
          );
    final lowerSpan = totalWeight == 0
        ? verticalPool / 2
        : math.max(
            verticalPool * .15,
            verticalPool * lowerWeight / totalWeight,
          );
    for (var index = 0; index < causes.length; index++) {
      final pair = index ~/ 2;
      final direction = index.isEven ? -1.0 : 1.0;
      final attachX = headLeft - (pair + .55) * usable / pairCount;
      final branchEnd = Offset(
        attachX - usable / pairCount * .58,
        spineY +
            direction *
                (causes[index].children.isEmpty
                    ? 30
                    : math.min(130, direction < 0 ? upperSpan : lowerSpan)),
      );
      _drawBone(canvas, Offset(attachX, spineY), branchEnd, line);
      _label(canvas, causes[index].text, branchEnd, direction, true);
      _drawChildren(
        canvas,
        causes[index].children,
        Offset(attachX, spineY),
        branchEnd,
        direction,
        line,
        1,
      );
    }
  }

  void _drawChildren(
    Canvas canvas,
    List<IshikawaNodeData> children,
    Offset start,
    Offset end,
    double direction,
    Paint line,
    int depth,
  ) {
    for (var index = 0; index < children.length; index++) {
      final t = (index + 1) / (children.length + 1);
      final anchor = Offset.lerp(start, end, t)!;
      final length = math.max(32.0, 82.0 - depth * 9);
      final childEnd = depth.isOdd
          ? Offset(anchor.dx - length, anchor.dy)
          : Offset(
              anchor.dx - length * .65,
              anchor.dy + direction * length * .55,
            );
      _drawBone(canvas, anchor, childEnd, line);
      _label(canvas, children[index].text, childEnd, direction, false);
      _drawChildren(
        canvas,
        children[index].children,
        anchor,
        childEnd,
        direction,
        line,
        depth + 1,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset point,
    double direction,
    bool boxed,
  ) {
    final painter = _textPainter(
      text,
      data.fontSize,
      boxed ? FontWeight.w600 : FontWeight.w400,
    )..layout(maxWidth: boxed ? 130 : 105);
    final offset = Offset(
      point.dx - painter.width / 2,
      direction < 0 ? point.dy - painter.height - 7 : point.dy + 6,
    );
    if (boxed) {
      final rect = (offset & painter.size).inflate(6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color =
              _color(data.fillColor) ??
              Color(style.defaultNodeStyle.fillColor ?? 0xFFF5F5F5)
          ..style = PaintingStyle.fill,
      );
      if (data.handDrawn) {
        _drawHachure(
          canvas,
          Path()
            ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4))),
          rect,
          _color(data.lineColor) ??
              Color(style.defaultNodeStyle.strokeColor ?? 0xFF455A64),
          _textSeed(text),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color =
              _color(data.lineColor) ??
              Color(style.defaultNodeStyle.strokeColor ?? 0xFF455A64)
          ..style = PaintingStyle.stroke,
      );
    }
    painter.paint(canvas, offset);
  }

  void _centerText(
    Canvas canvas,
    String text,
    Rect rect,
    double size,
    FontWeight weight,
  ) {
    final painter = _textPainter(text, size, weight)
      ..layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  TextPainter _textPainter(String text, double size, FontWeight weight) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color:
                _color(data.textColor) ??
                Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
            fontSize: size,
            fontWeight: weight,
            fontFamily: style.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 4,
        ellipsis: '…',
      );

  void _drawLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    if (!data.handDrawn) {
      canvas.drawLine(start, end, paint);
      return;
    }
    final delta = end - start;
    final length = delta.distance;
    if (length == 0) return;
    final normal = Offset(-delta.dy / length, delta.dx / length);
    final seed =
        data.handDrawnSeed +
        start.dx.round() * 31 +
        start.dy.round() * 17 +
        end.dx.round() * 13 +
        end.dy.round() * 7;
    final midpoint = Offset.lerp(start, end, .5)!;
    final control = midpoint + normal * ((_random(seed) - .5) * 4);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy),
      paint,
    );
    final secondControl = midpoint + normal * ((_random(seed + 19) - .5) * 3);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(secondControl.dx, secondControl.dy, end.dx, end.dy),
      Paint()
        ..color = paint.color.withValues(alpha: .35)
        ..strokeWidth = math.max(.5, paint.strokeWidth * .55)
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawBone(Canvas canvas, Offset spine, Offset tip, Paint paint) {
    _drawLine(canvas, spine, tip, paint);
    final delta = spine - tip;
    final length = delta.distance;
    if (length == 0) return;
    final unit = delta / length;
    final normal = Offset(-unit.dy, unit.dx);
    final arrow = Path()
      ..moveTo(spine.dx, spine.dy)
      ..lineTo(
        spine.dx - unit.dx * 10 + normal.dx * 4,
        spine.dy - unit.dy * 10 + normal.dy * 4,
      )
      ..lineTo(
        spine.dx - unit.dx * 10 - normal.dx * 4,
        spine.dy - unit.dy * 10 - normal.dy * 4,
      )
      ..close();
    canvas.drawPath(arrow, Paint()..color = paint.color);
  }

  void _drawHachure(
    Canvas canvas,
    Path clip,
    Rect bounds,
    Color color,
    int salt,
  ) {
    canvas
      ..save()
      ..clipPath(clip);
    final paint = Paint()
      ..color = color.withValues(alpha: .24)
      ..strokeWidth = 1;
    const gap = 5.0;
    final span = bounds.width + bounds.height;
    var index = 0;
    for (var x = bounds.left - bounds.height; x < bounds.right; x += gap) {
      final jitter = (_random(data.handDrawnSeed + salt + index++) - .5) * 1.4;
      canvas.drawLine(
        Offset(x + jitter, bounds.bottom),
        Offset(x + span + jitter, bounds.top),
        paint,
      );
    }
    canvas.restore();
  }

  double _random(int seed) {
    var value = (seed + 0x6D2B79F5).toSigned(32);
    value = (value ^ (value >>> 15)) * (value | 1);
    value ^= value + ((value ^ (value >>> 7)) * (value | 61));
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  }

  int _textSeed(String text) => text.codeUnits.fold<int>(
    2166136261,
    (value, unit) => ((value ^ unit) * 16777619).toSigned(32),
  );

  Color? _color(String? source) {
    if (source == null) return null;
    final value = source.trim().toLowerCase();
    final named = switch (value) {
      'black' => const Color(0xFF000000),
      'white' => const Color(0xFFFFFFFF),
      'red' => const Color(0xFFFF0000),
      'green' => const Color(0xFF008000),
      'blue' => const Color(0xFF0000FF),
      'gray' || 'grey' => const Color(0xFF808080),
      _ => null,
    };
    if (named != null) return named;
    if (!value.startsWith('#')) return null;
    var hex = value.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((digit) => '$digit$digit').join();
    }
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null || hex.length != 6
        ? null
        : Color(0xFF000000 | parsed);
  }

  @override
  bool shouldRepaint(IshikawaPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}
