/*
 * [INPUT]: Depends on Flutter Canvas, Requirement semantics/configuration, shared diagram direction, CSS colors, and Mermaid styles.
 * [OUTPUT]: Computes directional Requirement geometry and paints SysML-style cards, fields, class/direct styles, typed dashed relationships, labels, diamonds, and arrows.
 * [POS]: Serves as the dedicated native layout and renderer for Mermaid Requirement diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/diagram.dart';
import '../models/requirement_diagram.dart';
import '../models/style.dart';
import 'css_color.dart';

class RequirementChartLayout {
  const RequirementChartLayout();
  Size computeLayout(
    MermaidDiagramData diagram,
    RequirementDiagramData data,
    Size available,
  ) {
    final count = data.requirements.length + data.elements.length;
    final columns = math.max(1, math.sqrt(math.max(1, count)).ceil());
    final rows = math.max(1, (count / columns).ceil());
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    final width = 40 + (horizontal ? columns : rows) * (data.rectMinWidth + 70);
    final height =
        60 +
        (horizontal ? rows : columns) * (data.rectMinHeight + 70) +
        (data.title == null ? 0 : 42);
    return Size(
      data.useMaxWidth && available.width.isFinite
          ? math.max(available.width, width)
          : width,
      math.max(260, height),
    );
  }
}

class RequirementPainter extends CustomPainter {
  const RequirementPainter({
    required this.diagram,
    required this.data,
    required this.style,
  });
  final MermaidDiagramData diagram;
  final RequirementDiagramData data;
  final MermaidStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final items = <Object>[...data.requirements, ...data.elements];
    if (items.isEmpty) return;
    var titleOffset = 20.0;
    if (data.title case final title?) {
      final label = _text(title, data.fontSize + 5, _textColor, bold: true)
        ..layout(maxWidth: size.width - 30);
      label.paint(canvas, Offset((size.width - label.width) / 2, 14));
      titleOffset = 56;
    }
    final rects = _rects(items, size, titleOffset);
    for (final relation in data.relationships) {
      final from = rects[relation.from];
      final to = rects[relation.to];
      if (from != null && to != null) _relationship(canvas, from, to, relation);
    }
    for (var index = 0; index < items.length; index++) {
      _card(canvas, items[index], rects[_name(items[index])]!, index);
    }
  }

  Map<String, Rect> _rects(List<Object> items, Size size, double top) {
    final columns = math.max(1, math.sqrt(items.length).ceil());
    final rows = math.max(1, (items.length / columns).ceil());
    final horizontal =
        diagram.direction == DiagramDirection.leftToRight ||
        diagram.direction == DiagramDirection.rightToLeft;
    final logicalColumns = horizontal ? columns : rows;
    final logicalRows = horizontal ? rows : columns;
    final cellWidth = size.width / logicalColumns;
    final cellHeight = (size.height - top) / logicalRows;
    final result = <String, Rect>{};
    for (var index = 0; index < items.length; index++) {
      var column = horizontal ? index % columns : index ~/ columns;
      var row = horizontal ? index ~/ columns : index % columns;
      if (diagram.direction == DiagramDirection.rightToLeft) {
        column = logicalColumns - column - 1;
      }
      if (diagram.direction == DiagramDirection.bottomToTop) {
        row = logicalRows - row - 1;
      }
      result[_name(items[index])] = Rect.fromCenter(
        center: Offset(
          (column + .5) * cellWidth,
          top + (row + .5) * cellHeight,
        ),
        width: math.min(data.rectMinWidth, cellWidth - 24),
        height: math.min(data.rectMinHeight, cellHeight - 24),
      );
    }
    return result;
  }

  void _relationship(
    Canvas canvas,
    Rect from,
    Rect to,
    RequirementRelationshipData relation,
  ) {
    final start = _boundary(from, to.center);
    final end = _boundary(to, from.center);
    final color =
        parseMermaidCssColor(data.theme.relationColor) ??
        const Color(0xff666666);
    final strokeWidth = data.look == 'neo' ? data.theme.strokeWidth : 1.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (relation.kind == RequirementRelationshipKind.contains) {
      canvas.drawLine(start, end, paint);
      _diamond(canvas, start, end, color);
    } else {
      final distance = (end - start).distance;
      final unit = (end - start) / math.max(1, distance);
      for (var offset = 0.0; offset < distance - 8; offset += 17) {
        canvas.drawLine(
          start + unit * offset,
          start + unit * math.min(offset + 10, distance),
          paint,
        );
      }
      _arrow(canvas, end, start, color);
    }
    final labelText = '<<${relation.kind.name}>>';
    final label = _text(
      labelText,
      math.max(10, data.fontSize - 1),
      parseMermaidCssColor(data.theme.relationLabelColor) ?? _textColor,
    )..layout();
    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final box = Rect.fromCenter(
      center: center,
      width: label.width + 8,
      height: label.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(3)),
      Paint()
        ..color =
            parseMermaidCssColor(data.theme.requirementEdgeLabelBackground) ??
            parseMermaidCssColor(data.theme.relationLabelBackground) ??
            parseMermaidCssColor(data.theme.edgeLabelBackground) ??
            Color(style.backgroundColor),
    );
    label.paint(
      canvas,
      Offset(center.dx - label.width / 2, center.dy - label.height / 2),
    );
  }

  void _card(Canvas canvas, Object item, Rect rect, int index) {
    final custom = _customStyle(item);
    final fill = custom['fill'] != null
        ? parseMermaidCssColor(custom['fill'])
        : _arrayColor(data.theme.backgroundColors, index) ??
              parseMermaidCssColor(data.theme.background) ??
              parseMermaidCssColor(data.rectFill);
    final border = custom['stroke'] != null
        ? parseMermaidCssColor(custom['stroke'])
        : _arrayColor(data.theme.borderColors, index) ??
              parseMermaidCssColor(data.theme.borderColor) ??
              parseMermaidCssColor(data.rectBorderColor);
    final textColor = custom['color'] != null
        ? parseMermaidCssColor(custom['color'])
        : parseMermaidCssColor(data.theme.textColor) ??
              parseMermaidCssColor(data.textColor) ??
              _textColor;
    final effectiveTextColor = textColor ?? _textColor;
    final borderWidth =
        _pixels(custom['stroke-width']) ??
        _pixels(data.theme.borderSize) ??
        _pixels(data.rectBorderSize) ??
        .5;
    final rounded = item is RequirementElementData || data.look == 'neo';
    final shape = rounded
        ? RRect.fromRectAndRadius(rect, const Radius.circular(8))
        : RRect.fromRectAndRadius(rect, Radius.zero);
    canvas.drawRRect(shape, Paint()..color = fill ?? Colors.white);
    canvas.drawRRect(
      shape,
      Paint()
        ..color = border ?? const Color(0xffbbbbbb)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
    final titleLines = item is RequirementData
        ? [_kind(item.kind), item.name]
        : ['Element', (item as RequirementElementData).name];
    final title = _text(
      titleLines.join('\n'),
      data.fontSize,
      effectiveTextColor,
      bold: true,
    )..layout(maxWidth: rect.width - data.rectPadding * 2);
    title.paint(
      canvas,
      Offset(rect.center.dx - title.width / 2, rect.top + data.rectPadding),
    );
    final dividerY =
        rect.top + data.rectPadding + title.height + data.lineHeight / 2;
    canvas.drawLine(
      Offset(rect.left, dividerY),
      Offset(rect.right, dividerY),
      Paint()
        ..color = border ?? const Color(0xffbbbbbb)
        ..strokeWidth = borderWidth,
    );
    final fields = item is RequirementData
        ? <String>[
            if (item.requirementId.isNotEmpty) 'id: ${item.requirementId}',
            if (item.text.isNotEmpty) 'text: ${item.text}',
            if (item.risk != null) 'risk: ${item.risk!.name}',
            if (item.verificationMethod != null)
              'verifyMethod: ${item.verificationMethod!.name}',
          ]
        : <String>[
            if ((item as RequirementElementData).type.isNotEmpty)
              'type: ${item.type}',
            if (item.documentReference.isNotEmpty)
              'docRef: ${item.documentReference}',
          ];
    var y = dividerY + data.lineHeight / 2;
    for (final field in fields) {
      final label = _text(field, data.fontSize, effectiveTextColor)
        ..layout(maxWidth: rect.width - data.rectPadding * 2);
      label.paint(canvas, Offset(rect.left + data.rectPadding, y));
      y += math.max(data.lineHeight, label.height);
      if (y > rect.bottom - data.rectPadding) break;
    }
  }

  Map<String, String> _customStyle(Object item) {
    final classes = item is RequirementData
        ? item.cssClasses
        : (item as RequirementElementData).cssClasses;
    final raw = item is RequirementData
        ? item.rawStyle
        : (item as RequirementElementData).rawStyle;
    final sources = [
      for (final name in classes) ?data.classDefinitions[name],
      ?raw,
    ];
    final result = <String, String>{};
    for (final source in sources) {
      for (final part in source.split(',')) {
        final separator = part.indexOf(':');
        if (separator > 0) {
          result[part.substring(0, separator).trim()] = part
              .substring(separator + 1)
              .trim();
        }
      }
    }
    return result;
  }

  Offset _boundary(Rect rect, Offset toward) {
    final vector = toward - rect.center;
    if (vector.dx.abs() * rect.height > vector.dy.abs() * rect.width) {
      final x = vector.dx >= 0 ? rect.right : rect.left;
      return Offset(
        x,
        rect.center.dy +
            vector.dy * (rect.width / 2 / math.max(1, vector.dx.abs())),
      );
    }
    final y = vector.dy >= 0 ? rect.bottom : rect.top;
    return Offset(
      rect.center.dx +
          vector.dx * (rect.height / 2 / math.max(1, vector.dy.abs())),
      y,
    );
  }

  void _arrow(Canvas canvas, Offset tip, Offset from, Color color) {
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - 11 * math.cos(angle - .45),
        tip.dy - 11 * math.sin(angle - .45),
      )
      ..lineTo(
        tip.dx - 11 * math.cos(angle + .45),
        tip.dy - 11 * math.sin(angle + .45),
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _diamond(Canvas canvas, Offset tip, Offset toward, Color color) {
    final angle = math.atan2(toward.dy - tip.dy, toward.dx - tip.dx);
    final forward = Offset(math.cos(angle), math.sin(angle));
    final side = Offset(-forward.dy, forward.dx);
    canvas.drawPath(
      Path()..addPolygon([
        tip,
        tip + forward * 14 + side * 7,
        tip + forward * 28,
        tip + forward * 14 - side * 7,
      ], true),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke,
    );
  }

  String _name(Object item) => item is RequirementData
      ? item.name
      : (item as RequirementElementData).name;
  String _kind(RequirementKind kind) => switch (kind) {
    RequirementKind.requirement => 'Requirement',
    RequirementKind.functionalRequirement => 'Functional Requirement',
    RequirementKind.interfaceRequirement => 'Interface Requirement',
    RequirementKind.performanceRequirement => 'Performance Requirement',
    RequirementKind.physicalRequirement => 'Physical Requirement',
    RequirementKind.designConstraint => 'Design Constraint',
  };
  Color? _arrayColor(List<String> values, int index) => values.isEmpty
      ? null
      : parseMermaidCssColor(values[index % values.length]);
  double? _pixels(String? value) => value == null
      ? null
      : double.tryParse(RegExp(r'[\d.]+').firstMatch(value)?.group(0) ?? '');
  Color get _textColor => Color(style.defaultNodeStyle.textColor ?? 0xff333333);
  TextPainter _text(
    String value,
    double size,
    Color color, {
    bool bold = false,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: style.fontFamily,
        fontWeight: bold ? FontWeight.w600 : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  @override
  bool shouldRepaint(covariant RequirementPainter oldDelegate) =>
      oldDelegate.diagram != diagram ||
      oldDelegate.data != data ||
      oldDelegate.style != style;
}
