/*
 * [INPUT]: Depends on Flutter Canvas, Packet chart data, Mermaid semantic fallbacks, and official Packet theme variables.
 * [OUTPUT]: Paints Mermaid 11.16-compatible Packet geometry, cross-row fields, bit indices, labels, and bottom titles.
 * [POS]: Serves as the dedicated native painter for Mermaid Packet diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/packet.dart';
import '../models/style.dart';

class PacketPainter extends CustomPainter {
  const PacketPainter({required this.data, required this.style});

  final PacketChartData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final bitsPerRow = data.bitsPerRow;
    final bitWidth = data.bitWidth;
    final totalRowHeight = data.rowHeight + data.effectivePaddingY;
    final stroke = Paint()
      ..color =
          _color(data.theme.blockStrokeColor) ??
          Color(style.defaultNodeStyle.strokeColor ?? 0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          data.theme.blockStrokeWidth ?? style.defaultNodeStyle.strokeWidth;
    final fill = Paint()
      ..color =
          _color(data.theme.blockFillColor) ??
          Color(style.defaultNodeStyle.fillColor ?? 0xFFEFEFEF)
      ..style = PaintingStyle.fill;

    for (final field in data.fields) {
      var segmentStart = field.start;
      while (segmentStart <= field.end) {
        final row = segmentStart ~/ bitsPerRow;
        final rowEnd = math.min(field.end, (row + 1) * bitsPerRow - 1);
        final startInRow = segmentStart % bitsPerRow;
        final bits = rowEnd - segmentStart + 1;
        final left = startInRow * bitWidth + 1;
        final top = row * totalRowHeight + data.effectivePaddingY;
        final rect = Rect.fromLTWH(
          left,
          top,
          math.max(0, bits * bitWidth - data.paddingX),
          data.rowHeight,
        );
        canvas
          ..drawRect(rect, fill)
          ..drawRect(rect, stroke);
        if (data.showBits) {
          _text(
            canvas,
            '$segmentStart',
            Offset(left, top - 2),
            data.theme.byteFontSize ?? 10,
            FontWeight.w400,
            color:
                _color(data.theme.startByteColor) ??
                Color(style.defaultNodeStyle.textColor ?? 0xFF000000),
            baselineBottom: true,
            centered: segmentStart == rowEnd,
            availableWidth: rect.width,
          );
          if (segmentStart != rowEnd) {
            _text(
              canvas,
              '$rowEnd',
              Offset(rect.right, top - 2),
              data.theme.byteFontSize ?? 10,
              FontWeight.w400,
              color:
                  _color(data.theme.endByteColor) ??
                  Color(style.defaultNodeStyle.textColor ?? 0xFF000000),
              baselineBottom: true,
              alignRight: true,
            );
          }
        }
        _centerText(
          canvas,
          field.label,
          rect,
          data.theme.labelFontSize ?? 12,
          _color(data.theme.labelColor),
        );
        segmentStart = rowEnd + 1;
      }
    }

    if (data.title case final title?) {
      final center = Offset(size.width / 2, size.height - totalRowHeight / 2);
      final painter = _textPainter(
        title,
        data.theme.titleFontSize ?? 14,
        FontWeight.w400,
        color: _color(data.theme.titleColor),
      )..layout(maxWidth: size.width);
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    }
  }

  void _centerText(
    Canvas canvas,
    String text,
    Rect rect,
    double fontSize,
    Color? color,
  ) {
    final painter = _textPainter(text, fontSize, FontWeight.w400, color: color);
    painter.layout(maxWidth: math.max(1, rect.width - 8));
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    FontWeight weight, {
    Color? color,
    bool baselineBottom = false,
    bool alignRight = false,
    bool centered = false,
    double? availableWidth,
  }) {
    final painter = _textPainter(text, fontSize, weight, color: color)
      ..layout();
    var dx = offset.dx;
    if (alignRight) dx -= painter.width;
    if (centered) dx += ((availableWidth ?? 0) - painter.width) / 2;
    painter.paint(
      canvas,
      Offset(dx, baselineBottom ? offset.dy - painter.height : offset.dy),
    );
  }

  TextPainter _textPainter(
    String text,
    double size,
    FontWeight weight, {
    Color? color,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
          fontSize: size,
          fontWeight: weight,
          fontFamily: style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    );
  }

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
      'transparent' => const Color(0x00000000),
      _ => null,
    };
    if (named != null) return named;
    if (value.startsWith('#')) {
      var hex = value.substring(1);
      if (hex.length == 3) {
        hex = hex.split('').map((digit) => '$digit$digit').join();
      }
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null && hex.length == 6) return Color(0xFF000000 | parsed);
      if (parsed != null && hex.length == 8) return Color(parsed);
    }
    final rgb = RegExp(
      r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)$',
    ).firstMatch(value);
    if (rgb == null) return null;
    final red = int.parse(rgb.group(1)!).clamp(0, 255);
    final green = int.parse(rgb.group(2)!).clamp(0, 255);
    final blue = int.parse(rgb.group(3)!).clamp(0, 255);
    final alpha = (double.tryParse(rgb.group(4) ?? '1') ?? 1)
        .clamp(0, 1)
        .toDouble();
    return Color.fromRGBO(red, green, blue, alpha);
  }

  @override
  bool shouldRepaint(PacketPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.style != style;
}
