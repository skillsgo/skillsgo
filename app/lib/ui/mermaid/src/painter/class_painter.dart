/*
 * [INPUT]: Depends on Flutter Canvas, complete Class semantics/configuration/theme data, diagram direction, CSS colors, and Mermaid styles.
 * [OUTPUT]: Computes directional UML geometry and paints namespace clusters, compartmented classes, notes, relations, cardinalities, labels, and all UML relation terminals.
 * [POS]: Serves as the dedicated native layout and renderer for Mermaid Class diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/class_diagram.dart';
import '../models/diagram.dart';
import '../models/style.dart';
import 'css_color.dart';

class ClassChartLayout {
  const ClassChartLayout();

  Size computeLayout(
    MermaidDiagramData diagram,
    ClassDiagramData data,
    Size available,
  ) {
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    final count = math.max(1, data.classes.length);
    final columns = horizontal
        ? count
        : data.defaultRenderer == 'elk'
        ? math.max(1, math.sqrt(count).ceil())
        : math.min(3, count);
    final rows = (count / columns).ceil();
    final width =
        data.diagramPadding * 2 +
        columns * 190 +
        math.max(0, columns - 1) * data.nodeSpacing;
    final height =
        data.diagramPadding * 2 +
        (data.title == null ? 0 : 50) +
        rows * 150 +
        math.max(0, rows - 1) * data.rankSpacing +
        data.notes.where((note) => note.classId == null).length * 55;
    return Size(
      data.useMaxWidth && available.width.isFinite
          ? math.max(width, available.width)
          : width,
      math.max(240, height),
    );
  }
}

class ClassPainter extends CustomPainter {
  const ClassPainter({
    required this.diagram,
    required this.data,
    required this.style,
  });

  final MermaidDiagramData diagram;
  final ClassDiagramData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    var top = data.diagramPadding;
    if (data.title case final title?) {
      final painter = _text(title, 18, _titleColor, bold: true)..layout();
      painter.paint(
        canvas,
        Offset((size.width - painter.width) / 2, data.titleTopMargin),
      );
      top += 50;
    }
    final rects = _classRects(size, top);
    final namespaces = _namespaceRects(rects);
    _paintNamespaces(canvas, namespaces);
    for (final relation in data.relations) {
      final from = rects[relation.from];
      final to = rects[relation.to];
      if (from != null && to != null) {
        _paintRelation(canvas, relation, from, to);
      }
    }
    for (final entity in data.classes) {
      _paintClass(canvas, entity, rects[entity.id]!);
    }
    _paintNotes(canvas, rects, size, top);
  }

  Map<String, Rect> _classRects(Size size, double top) {
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    final count = math.max(1, data.classes.length);
    final columns = horizontal
        ? count
        : data.defaultRenderer == 'elk'
        ? math.max(1, math.sqrt(count).ceil())
        : math.min(3, count);
    final rows = math.max(1, (count / columns).ceil());
    final availableHeight = size.height - top - data.diagramPadding;
    final cellWidth = size.width / columns;
    final cellHeight = availableHeight / rows;
    final result = <String, Rect>{};
    for (var index = 0; index < data.classes.length; index++) {
      var column = index % columns;
      var row = index ~/ columns;
      if (diagram.direction == DiagramDirection.rightToLeft) {
        column = columns - column - 1;
      }
      if (diagram.direction == DiagramDirection.bottomToTop) {
        row = rows - row - 1;
      }
      final entity = data.classes[index];
      final titleLines = entity.annotations.length + 1;
      final hasMembers = entity.members.isNotEmpty || !data.hideEmptyMembersBox;
      final memberHeight = hasMembers
          ? data.dividerMargin * 2 +
                math.max(1, entity.members.length) *
                    math.max(16, data.textHeight + 6)
          : 0.0;
      final height =
          data.padding * 2 + titleLines * 19 + memberHeight.toDouble();
      final labels = [
        entity.label,
        if (entity.genericType != null) entity.genericType!,
        ...entity.annotations,
        ...entity.members.map((member) => member.text),
      ];
      final widest = labels.fold<double>(0, (value, label) {
        final painter = _text(label, 13, _textColor)..layout();
        return math.max(value, painter.width);
      });
      result[entity.id] = Rect.fromCenter(
        center: Offset(
          (column + .5) * cellWidth,
          top + (row + .5) * cellHeight,
        ),
        width: math.min(cellWidth - 24, math.max(130, widest + 28)),
        height: math.min(cellHeight - 20, math.max(55, height)),
      );
    }
    return result;
  }

  Map<String, Rect> _namespaceRects(Map<String, Rect> classes) {
    final result = <String, Rect>{};
    for (final namespace in data.namespaces.reversed) {
      final members = <Rect>[
        for (final entity in data.classes)
          if (_namespaceContains(namespace.id, entity.namespace) &&
              classes[entity.id] != null)
            classes[entity.id]!,
      ];
      if (members.isEmpty) continue;
      var bounds = members.first;
      for (final member in members.skip(1)) {
        bounds = bounds.expandToInclude(member);
      }
      result[namespace.id] = Rect.fromLTRB(
        bounds.left - data.padding * 2,
        bounds.top - 28 - data.padding,
        bounds.right + data.padding * 2,
        bounds.bottom + data.padding * 2,
      );
    }
    return result;
  }

  bool _namespaceContains(String namespace, String? candidate) {
    if (candidate == null) return false;
    if (!data.hierarchicalNamespaces) return namespace == candidate;
    return candidate == namespace || candidate.startsWith('$namespace.');
  }

  void _paintNamespaces(Canvas canvas, Map<String, Rect> rects) {
    for (final namespace in data.namespaces) {
      final rect = rects[namespace.id];
      if (rect == null) continue;
      final label = data.hierarchicalNamespaces
          ? namespace.label
          : namespace.id;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()
          ..color = _clusterBackground
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()
          ..color = _clusterBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final painter = _text(label, 12, _titleColor, bold: true)..layout();
      painter.paint(canvas, Offset(rect.left + data.padding, rect.top + 5));
    }
  }

  void _paintClass(Canvas canvas, ClassEntityData entity, Rect rect) {
    final custom = _styleMap(entity);
    final fill =
        parseMermaidCssColor(custom['fill']) ??
        parseMermaidCssColor(data.theme.mainBackground) ??
        Color(
          style.defaultNodeStyle.fillColor ?? MermaidColors.defaultNodeFill,
        );
    final border =
        parseMermaidCssColor(custom['stroke']) ??
        parseMermaidCssColor(data.theme.nodeBorder) ??
        Color(
          style.defaultNodeStyle.strokeColor ?? MermaidColors.defaultNodeStroke,
        );
    final textColor =
        parseMermaidCssColor(custom['color']) ??
        parseMermaidCssColor(data.theme.classText) ??
        _textColor;
    final strokeWidth =
        _number(custom['stroke-width']) ?? data.theme.strokeWidth;
    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(
      rect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    var y = rect.top + data.padding;
    for (final annotation in entity.annotations) {
      y = _line(canvas, '«$annotation»', rect, y, textColor, centered: true);
    }
    final title =
        '${entity.label}${entity.genericType == null ? '' : '<${entity.genericType}>'}';
    y = _line(canvas, title, rect, y, textColor, centered: true, bold: true);
    final hasMembers = entity.members.isNotEmpty || !data.hideEmptyMembersBox;
    if (hasMembers) {
      y += data.dividerMargin;
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        Paint()
          ..color = border
          ..strokeWidth = math.max(1, strokeWidth),
      );
      y += data.dividerMargin;
      for (final member in entity.members) {
        _line(
          canvas,
          _memberLabel(member),
          rect,
          y,
          textColor,
          italic: member.isAbstract,
          underline: member.isStatic,
        );
        y += math.max(16, data.textHeight + 6);
      }
    }
  }

  String _memberLabel(ClassMemberData member) {
    final suffix = member.isStatic || member.isAbstract
        ? member.text.substring(0, member.text.length - 1)
        : member.text;
    return suffix;
  }

  double _line(
    Canvas canvas,
    String text,
    Rect rect,
    double y,
    Color color, {
    bool centered = false,
    bool bold = false,
    bool italic = false,
    bool underline = false,
  }) {
    final painter = _text(
      text,
      13,
      color,
      bold: bold,
      italic: italic,
      underline: underline,
    )..layout(maxWidth: math.max(1, rect.width - data.padding * 2));
    painter.paint(
      canvas,
      Offset(
        centered
            ? rect.center.dx - painter.width / 2
            : rect.left + data.padding,
        y,
      ),
    );
    return y + painter.height;
  }

  void _paintRelation(
    Canvas canvas,
    ClassRelationData relation,
    Rect from,
    Rect to,
  ) {
    final start = _boundary(from, to.center);
    final end = _boundary(to, from.center);
    final paint = Paint()
      ..color = _lineColor
      ..strokeWidth = data.theme.strokeWidth
      ..style = PaintingStyle.stroke;
    if (relation.dashed) {
      _dashedLine(canvas, start, end, paint);
    } else {
      canvas.drawLine(start, end, paint);
    }
    _terminal(canvas, start, end, relation.leftEnd);
    _terminal(canvas, end, start, relation.rightEnd);
    final delta = end - start;
    final length = delta.distance;
    if (length > 0) {
      final unit = delta / length;
      if (relation.leftCardinality case final value?) {
        _edgeText(canvas, value, start + unit * 18);
      }
      if (relation.rightCardinality case final value?) {
        _edgeText(canvas, value, end - unit * 18);
      }
      if (relation.label case final value?) {
        _edgeText(canvas, value, Offset.lerp(start, end, .5)!);
      }
    }
  }

  Offset _boundary(Rect rect, Offset target) {
    final vector = target - rect.center;
    if (vector.dx == 0 && vector.dy == 0) return rect.center;
    final scale = math.min(
      vector.dx == 0 ? double.infinity : rect.width / 2 / vector.dx.abs(),
      vector.dy == 0 ? double.infinity : rect.height / 2 / vector.dy.abs(),
    );
    return rect.center + vector * scale;
  }

  void _terminal(
    Canvas canvas,
    Offset point,
    Offset toward,
    ClassRelationEnd end,
  ) {
    if (end == ClassRelationEnd.none) return;
    final vector = toward - point;
    if (vector.distance == 0) return;
    final unit = vector / vector.distance;
    final normal = Offset(-unit.dy, unit.dx);
    const length = 14.0;
    const half = 7.0;
    final inner = point + unit * length;
    final paint = Paint()
      ..color = _lineColor
      ..strokeWidth = data.theme.strokeWidth
      ..style = PaintingStyle.stroke;
    switch (end) {
      case ClassRelationEnd.inheritance:
      case ClassRelationEnd.realization:
        final path = Path()
          ..moveTo(point.dx, point.dy)
          ..lineTo((inner + normal * half).dx, (inner + normal * half).dy)
          ..lineTo((inner - normal * half).dx, (inner - normal * half).dy)
          ..close();
        canvas.drawPath(path, paint);
      case ClassRelationEnd.composition:
      case ClassRelationEnd.aggregation:
        final far = point + unit * (length * 1.35);
        final path = Path()
          ..moveTo(point.dx, point.dy)
          ..lineTo((inner + normal * half).dx, (inner + normal * half).dy)
          ..lineTo(far.dx, far.dy)
          ..lineTo((inner - normal * half).dx, (inner - normal * half).dy)
          ..close();
        canvas.drawPath(
          path,
          end == ClassRelationEnd.composition
              ? (Paint()..color = _lineColor)
              : paint,
        );
      case ClassRelationEnd.association:
        canvas.drawLine(inner + normal * half, point, paint);
        canvas.drawLine(inner - normal * half, point, paint);
      case ClassRelationEnd.lollipop:
        canvas.drawCircle(
          point + unit * half,
          half,
          Paint()
            ..color = _classBackground
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(point + unit * half, half, paint);
      case ClassRelationEnd.none:
        break;
    }
  }

  void _paintNotes(
    Canvas canvas,
    Map<String, Rect> rects,
    Size size,
    double top,
  ) {
    var looseIndex = 0;
    for (final note in data.notes) {
      final anchor = note.classId == null ? null : rects[note.classId];
      final painter = _text(note.text, 12, _noteText)..layout(maxWidth: 180);
      final width = math.max(90.0, painter.width + data.padding * 2);
      final height = painter.height + data.padding * 2;
      final rect = anchor == null
          ? Rect.fromLTWH(
              data.diagramPadding,
              math.min(size.height - height, top + looseIndex++ * (height + 8)),
              width,
              height,
            )
          : Rect.fromLTWH(
              math.min(
                size.width - width - data.diagramPadding,
                anchor.right + 10,
              ),
              anchor.top,
              width,
              height,
            );
      canvas.drawRect(rect, Paint()..color = _noteBackground);
      canvas.drawRect(
        rect,
        Paint()
          ..color = _noteBorder
          ..style = PaintingStyle.stroke,
      );
      painter.paint(
        canvas,
        Offset(rect.left + data.padding, rect.top + data.padding),
      );
      if (anchor != null) {
        canvas.drawLine(
          anchor.centerRight,
          rect.centerLeft,
          Paint()
            ..color = _lineColor
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _edgeText(Canvas canvas, String value, Offset center) {
    final painter = _text(value, 11, _textColor)..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 6,
      height: painter.height + 3,
    );
    canvas.drawRect(rect, Paint()..color = _edgeLabelBackground);
    painter.paint(canvas, Offset(rect.left + 3, rect.top + 1.5));
  }

  void _dashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final length = delta.distance;
    if (length == 0) return;
    final unit = delta / length;
    for (var distance = 0.0; distance < length; distance += 8) {
      canvas.drawLine(
        start + unit * distance,
        start + unit * math.min(distance + 4, length),
        paint,
      );
    }
  }

  Map<String, String> _styleMap(ClassEntityData entity) {
    final sources = <String>[];
    final defaultStyle = data.classDefinitions['default'];
    if (defaultStyle != null) sources.add(defaultStyle);
    for (final name in entity.cssClass?.split(',') ?? const <String>[]) {
      final classStyle = data.classDefinitions[name];
      if (classStyle != null) sources.add(classStyle);
    }
    if (entity.rawStyle != null) sources.add(entity.rawStyle!);
    final result = <String, String>{};
    for (final source in sources) {
      for (final declaration in source.split(',')) {
        final separator = declaration.indexOf(':');
        if (separator > 0) {
          result[declaration.substring(0, separator).trim().toLowerCase()] =
              declaration.substring(separator + 1).trim();
        }
      }
    }
    return result;
  }

  double? _number(String? value) =>
      double.tryParse(value?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '');

  TextPainter _text(
    String value,
    double size,
    Color color, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: style.fontFamily,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: underline ? TextDecoration.underline : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  Color get _classBackground =>
      parseMermaidCssColor(data.theme.mainBackground) ??
      Color(style.defaultNodeStyle.fillColor ?? MermaidColors.defaultNodeFill);
  Color get _textColor =>
      parseMermaidCssColor(data.theme.classText) ??
      parseMermaidCssColor(data.theme.textColor) ??
      Color(style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor);
  Color get _titleColor =>
      parseMermaidCssColor(data.theme.titleColor) ?? _textColor;
  Color get _lineColor =>
      parseMermaidCssColor(data.theme.lineColor) ??
      Color(
        style.defaultEdgeStyle.strokeColor ?? MermaidColors.defaultEdgeColor,
      );
  Color get _edgeLabelBackground =>
      parseMermaidCssColor(data.theme.edgeLabelBackground) ??
      Color(style.backgroundColor);
  Color get _clusterBackground =>
      parseMermaidCssColor(
        data.theme.clusterBackground,
      )?.withValues(alpha: .3) ??
      _classBackground.withValues(alpha: .2);
  Color get _clusterBorder =>
      parseMermaidCssColor(data.theme.clusterBorder) ?? _lineColor;
  Color get _noteBackground =>
      parseMermaidCssColor(data.theme.noteBackground) ??
      const Color(0xfffff5ad);
  Color get _noteBorder =>
      parseMermaidCssColor(data.theme.noteBorder) ?? const Color(0xffaaaa33);
  Color get _noteText =>
      parseMermaidCssColor(data.theme.noteText) ?? _textColor;

  @override
  bool shouldRepaint(covariant ClassPainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.data != data ||
      oldDelegate.style != style;
}
