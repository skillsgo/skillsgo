/*
 * [INPUT]: Depends on the shared native sequence painter, ZenUML semantic events, Mermaid graph geometry, and style.
 * [OUTPUT]: Paints ZenUML lifelines/messages plus visible nested fragment bands and source comments.
 * [POS]: Serves as the dedicated native painter that retains ZenUML semantics beyond its sequence projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/style.dart';
import '../models/zenuml.dart';
import 'sequence_painter.dart';

class ZenUmlPainter extends CustomPainter {
  const ZenUmlPainter({
    required this.diagram,
    required this.data,
    required this.style,
    this.deviceConfig,
  });

  final MermaidDiagramData diagram;
  final ZenUmlChartData data;
  final MermaidStyle style;
  final MermaidDeviceConfig? deviceConfig;

  @override
  void paint(Canvas canvas, Size size) {
    SequencePainter(
      diagram: diagram,
      style: style,
      deviceConfig: deviceConfig,
    ).paint(canvas, size);
    final ink = Color(style.defaultNodeStyle.strokeColor ?? 0xFF455A64);
    var row = 0;
    for (final event in data.events) {
      if (event is ZenMessageData) {
        row++;
        continue;
      }
      final y = 78.0 + row * 52;
      if (event is ZenFragmentData) {
        final left = 12.0 + event.depth * 10;
        final rect = Rect.fromLTWH(left, y, size.width - left - 12, 30);
        canvas.drawRect(
          rect,
          Paint()
            ..color = ink.withValues(alpha: .05)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = ink.withValues(alpha: .65)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
        _text(
          canvas,
          '${_fragmentLabel(event.kind)}${event.condition == null ? '' : ' (${event.condition})'}',
          Offset(left + 7, y + 6),
          10,
          FontWeight.w600,
        );
      } else if (event is ZenCommentData) {
        _text(
          canvas,
          '// ${event.text}',
          Offset(18 + event.depth * 10, y + 4),
          10,
          FontWeight.w400,
          italic: true,
        );
      }
      row++;
    }
  }

  String _fragmentLabel(ZenFragmentKind kind) => switch (kind) {
    ZenFragmentKind.whileLoop => 'while',
    ZenFragmentKind.forLoop => 'for',
    ZenFragmentKind.forEachLoop => 'forEach',
    ZenFragmentKind.loop => 'loop',
    ZenFragmentKind.alternative => 'if',
    ZenFragmentKind.elseAlternative => 'else',
    ZenFragmentKind.optional => 'opt',
    ZenFragmentKind.parallel => 'par',
    ZenFragmentKind.tryBlock => 'try',
    ZenFragmentKind.catchBlock => 'catch',
    ZenFragmentKind.finallyBlock => 'finally',
  };

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double fontSize,
    FontWeight fontWeight, {
    bool italic = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Color(style.defaultNodeStyle.textColor ?? 0xFF212121),
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontFamily: style.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 260);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(ZenUmlPainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.data != data ||
      oldDelegate.style != style ||
      oldDelegate.deviceConfig != deviceConfig;
}
