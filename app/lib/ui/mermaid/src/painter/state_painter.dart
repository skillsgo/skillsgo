/*
 * [INPUT]: Depends on Flutter Canvas, complete State semantics/configuration/theme data, diagram direction, CSS colors, and Mermaid styles.
 * [OUTPUT]: Computes directional State geometry and paints composite containers, concurrent dividers, simple/choice/fork/join/start/end states, notes, transitions, labels, and arrows.
 * [POS]: Serves as the dedicated native layout and renderer for Mermaid State diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/diagram.dart';
import '../models/state_diagram.dart';
import '../models/style.dart';
import 'css_color.dart';

class StateChartLayout {
  const StateChartLayout();
  Size computeLayout(
    MermaidDiagramData diagram,
    StateDiagramData data,
    Size available,
  ) {
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    final count = math.max(
      1,
      data.states
          .where((state) => state.kind != StateNodeKind.composite)
          .length,
    );
    final span = count * (120 + data.nodeSpacing);
    final cross =
        180 +
        data.rankSpacing *
            math.max(1, data.states.map((s) => s.parent).toSet().length);
    final width = data.padding * 4 + (horizontal ? span : cross);
    final height =
        data.padding * 4 +
        (data.title == null ? 0 : 48) +
        (horizontal ? cross : span);
    return Size(
      data.useMaxWidth && available.width.isFinite
          ? math.max(width, available.width)
          : width,
      math.max(260, height),
    );
  }
}

class StatePainter extends CustomPainter {
  const StatePainter({
    required this.diagram,
    required this.data,
    required this.style,
  });
  final MermaidDiagramData diagram;
  final StateDiagramData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    var top = data.padding;
    if (data.title case final title?) {
      final p = _text(
        title,
        math.max(16, data.fontSize * .8),
        _textColor,
        bold: true,
      )..layout();
      p.paint(canvas, Offset((size.width - p.width) / 2, data.titleTopMargin));
      top += 48;
    }
    final rects = _rects(size, top);
    _composites(canvas, rects);
    for (final transition in data.transitions) {
      _transition(canvas, transition, rects);
    }
    for (final state in data.states.where(
      (state) => state.kind != StateNodeKind.composite,
    )) {
      _state(canvas, state, rects[state.id]!);
    }
    for (final note in data.notes) {
      _note(canvas, note, rects);
    }
  }

  Map<String, Rect> _rects(Size size, double top) {
    final drawable = data.states
        .where((state) => state.kind != StateNodeKind.composite)
        .toList();
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    final result = <String, Rect>{};
    for (var i = 0; i < drawable.length; i++) {
      var index = i;
      if (diagram.direction == DiagramDirection.rightToLeft ||
          diagram.direction == DiagramDirection.bottomToTop) {
        index = drawable.length - i - 1;
      }
      final fraction = (index + 1) / (drawable.length + 1);
      final center = horizontal
          ? Offset(size.width * fraction, top + (size.height - top) / 2)
          : Offset(size.width / 2, top + (size.height - top) * fraction);
      final state = drawable[i];
      final label = _text(state.label, data.fontSize * .6, _textColor)
        ..layout(maxWidth: 180);
      final width =
          state.kind == StateNodeKind.fork || state.kind == StateNodeKind.join
          ? (horizontal ? data.forkHeight : data.forkWidth)
          : math.max(70.0, label.width + data.padding * 2);
      final height =
          state.kind == StateNodeKind.fork || state.kind == StateNodeKind.join
          ? (horizontal ? data.forkWidth : data.forkHeight)
          : math.max(38.0, label.height + data.padding * 2);
      result[state.id] = Rect.fromCenter(
        center: center,
        width: width,
        height: height,
      );
    }
    for (final transition in data.transitions) {
      if (transition.from == '[*]') {
        result.putIfAbsent(
          '__start_${transition.to}',
          () => Rect.fromCircle(
            center: _outside(rects: result, id: transition.to, before: true),
            radius: 8,
          ),
        );
      }
      if (transition.to == '[*]') {
        result.putIfAbsent(
          '__end_${transition.from}',
          () => Rect.fromCircle(
            center: _outside(rects: result, id: transition.from, before: false),
            radius: 10,
          ),
        );
      }
    }
    for (final composite in data.states.where(
      (state) => state.kind == StateNodeKind.composite,
    )) {
      final children = data.states
          .where((state) => state.parent == composite.id)
          .map((state) => result[state.id])
          .whereType<Rect>()
          .toList();
      if (children.isNotEmpty) {
        result[composite.id] = children
            .reduce((a, b) => a.expandToInclude(b))
            .inflate(data.compositeTitleSize + data.padding);
      }
    }
    return result;
  }

  Offset _outside({
    required Map<String, Rect> rects,
    required String id,
    required bool before,
  }) {
    final rect = rects[id] ?? Rect.zero;
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    final sign = before ? -1.0 : 1.0;
    return horizontal
        ? rect.center.translate(sign * (data.rankSpacing + 25), 0)
        : rect.center.translate(0, sign * (data.rankSpacing + 25));
  }

  void _composites(Canvas canvas, Map<String, Rect> rects) {
    for (final state in data.states.where(
      (state) => state.kind == StateNodeKind.composite,
    )) {
      final rect = rects[state.id];
      if (rect == null) continue;
      final fill =
          parseMermaidCssColor(data.theme.compositeBackground) ??
          Color(style.backgroundColor);
      final border = parseMermaidCssColor(data.theme.stateBorder) ?? _lineColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(data.radius)),
        Paint()..color = fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(data.radius)),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke,
      );
      final titleRect = Rect.fromLTWH(
        rect.left,
        rect.top,
        rect.width,
        data.compositeTitleSize,
      );
      canvas.drawRect(
        titleRect,
        Paint()
          ..color =
              parseMermaidCssColor(data.theme.compositeTitleBackground) ?? fill,
      );
      final label = _text(
        state.label,
        data.fontSize * .6,
        _labelColor,
        bold: true,
      )..layout();
      label.paint(
        canvas,
        Offset(
          rect.center.dx - label.width / 2,
          rect.top +
              (data.compositeTitleSize - label.height) / 2 +
              data.titleShift / 5,
        ),
      );
      final regions = data.regions.where((r) => r.parent == state.id).length;
      for (var i = 1; i <= regions; i++) {
        final y =
            rect.top +
            data.compositeTitleSize +
            (rect.height - data.compositeTitleSize) * i / (regions + 1);
        canvas.drawLine(
          Offset(rect.left + data.dividerMargin, y),
          Offset(rect.right - data.dividerMargin, y),
          Paint()
            ..color = border
            ..strokeWidth = _stroke,
        );
      }
    }
  }

  void _state(Canvas canvas, StateNodeData state, Rect rect) {
    final fill =
        parseMermaidCssColor(data.theme.stateBackground) ??
        const Color(0xffececff);
    final border = parseMermaidCssColor(data.theme.stateBorder) ?? _lineColor;
    if (state.kind == StateNodeKind.choice) {
      canvas.drawPath(
        Path()..addPolygon([
          Offset(rect.center.dx, rect.top),
          Offset(rect.right, rect.center.dy),
          Offset(rect.center.dx, rect.bottom),
          Offset(rect.left, rect.center.dy),
        ], true),
        Paint()..color = fill,
      );
    } else if (state.kind == StateNodeKind.fork ||
        state.kind == StateNodeKind.join) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(data.miniPadding)),
        Paint()..color = border,
      );
      return;
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(data.radius)),
        Paint()..color = fill,
      );
    }
    final path = state.kind == StateNodeKind.choice
        ? (Path()..addPolygon([
            Offset(rect.center.dx, rect.top),
            Offset(rect.right, rect.center.dy),
            Offset(rect.center.dx, rect.bottom),
            Offset(rect.left, rect.center.dy),
          ], true))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(data.radius)),
          ));
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );
    final label = _text(state.label, data.fontSize * .6, _labelColor)
      ..layout(maxWidth: rect.width - data.padding * 2);
    label.paint(
      canvas,
      Offset(
        rect.center.dx - label.width / 2,
        rect.center.dy - label.height / 2,
      ),
    );
  }

  void _transition(
    Canvas canvas,
    StateTransitionData transition,
    Map<String, Rect> rects,
  ) {
    final fromKey = transition.from == '[*]'
        ? '__start_${transition.to}'
        : transition.from;
    final toKey = transition.to == '[*]'
        ? '__end_${transition.from}'
        : transition.to;
    final from = rects[fromKey];
    final to = rects[toKey];
    if (from == null || to == null) return;
    if (transition.from == '[*]') {
      canvas.drawCircle(
        from.center,
        from.width / 2,
        Paint()..color = _specialColor,
      );
    }
    if (transition.to == '[*]') {
      canvas.drawCircle(
        to.center,
        to.width / 2,
        Paint()..color = _specialColor,
      );
      canvas.drawCircle(
        to.center,
        to.width / 4,
        Paint()
          ..color =
              parseMermaidCssColor(data.theme.innerEndBackground) ??
              Color(style.backgroundColor),
      );
    }
    final start = _boundary(from, to.center), end = _boundary(to, from.center);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = _transitionColor
        ..strokeWidth = _stroke,
    );
    _arrow(canvas, end, start);
    if (transition.label case final text?) {
      final label = _text(
        text,
        math.max(10, data.fontSize * .5),
        parseMermaidCssColor(data.theme.transitionLabelColor) ?? _labelColor,
      )..layout();
      final center = (start + end) / 2;
      canvas.drawRect(
        Rect.fromCenter(
          center: center,
          width: label.width + 8,
          height: label.height + 4,
        ),
        Paint()
          ..color =
              parseMermaidCssColor(data.theme.edgeLabelBackground) ??
              Color(style.backgroundColor),
      );
      label.paint(
        canvas,
        Offset(center.dx - label.width / 2, center.dy - label.height / 2),
      );
    }
  }

  void _note(Canvas canvas, StateNoteData note, Map<String, Rect> rects) {
    final state = rects[note.stateId];
    if (state == null) return;
    final width = math.max(
      90.0,
      data.fontSizeFactor * note.text.length.clamp(8, 30),
    );
    final left = note.position == StateNotePosition.left
        ? state.left - data.noteMargin - width
        : state.right + data.noteMargin;
    final rect = Rect.fromLTWH(left, state.center.dy - 30, width, 60);
    canvas.drawRect(
      rect,
      Paint()
        ..color =
            parseMermaidCssColor(data.theme.noteBackground) ??
            const Color(0xfffff5ad),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = parseMermaidCssColor(data.theme.noteBorder) ?? _lineColor
        ..style = PaintingStyle.stroke,
    );
    final label = _text(
      note.text,
      data.fontSize * .5,
      parseMermaidCssColor(data.theme.noteText) ?? _textColor,
    )..layout(maxWidth: rect.width - data.padding * 2);
    label.paint(
      canvas,
      Offset(rect.left + data.padding, rect.top + data.padding),
    );
  }

  Offset _boundary(Rect r, Offset toward) {
    final v = toward - r.center;
    if (v.dx.abs() * r.height > v.dy.abs() * r.width) {
      final x = v.dx >= 0 ? r.right : r.left;
      return Offset(
        x,
        r.center.dy + v.dy * r.width / 2 / math.max(1, v.dx.abs()),
      );
    }
    final y = v.dy >= 0 ? r.bottom : r.top;
    return Offset(
      r.center.dx + v.dx * r.height / 2 / math.max(1, v.dy.abs()),
      y,
    );
  }

  void _arrow(Canvas c, Offset tip, Offset from) {
    final a = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    c.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tip.dx - 10 * math.cos(a - .45),
          tip.dy - 10 * math.sin(a - .45),
        )
        ..lineTo(
          tip.dx - 10 * math.cos(a + .45),
          tip.dy - 10 * math.sin(a + .45),
        )
        ..close(),
      Paint()..color = _transitionColor,
    );
  }

  double get _stroke => data.look == 'neo' ? data.theme.strokeWidth : 1;
  Color get _textColor => Color(style.defaultNodeStyle.textColor ?? 0xff333333);
  Color get _labelColor =>
      parseMermaidCssColor(data.theme.stateLabelColor) ?? _textColor;
  Color get _lineColor =>
      parseMermaidCssColor(data.theme.lineColor) ?? const Color(0xff333333);
  Color get _transitionColor =>
      parseMermaidCssColor(data.theme.transitionColor) ?? _lineColor;
  Color get _specialColor =>
      parseMermaidCssColor(data.theme.specialStateColor) ?? _lineColor;
  TextPainter _text(String t, double s, Color c, {bool bold = false}) =>
      TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            color: c,
            fontSize: s,
            fontFamily: style.fontFamily,
            fontWeight: bold ? FontWeight.w600 : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
  @override
  bool shouldRepaint(covariant StatePainter old) =>
      old.data != data || old.diagram != diagram || old.style != style;
}
