/*
 * [INPUT]: Depends on Flutter Canvas and the native Mermaid style palette.
 * [OUTPUT]: Paints Mermaid's pinned version label with the official 400x100 geometry in Light or Dark themes.
 * [POS]: Serves as the dedicated native renderer for info and info showInfo diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

import '../models/style.dart';

class InfoPainter extends CustomPainter {
  const InfoPainter({required this.version, required this.style});

  final String version;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'v$version',
        style: TextStyle(
          color: Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
          fontSize: 32,
          fontFamily: style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 200);
    painter.paint(canvas, Offset(100 - painter.width / 2, 40 - painter.height));
  }

  @override
  bool shouldRepaint(InfoPainter oldDelegate) =>
      oldDelegate.version != version || oldDelegate.style != style;
}
