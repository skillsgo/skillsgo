/*
 * [INPUT]: Depends on native Mermaid graph and Quadrant models plus Mermaid 11.16.0 Quadrant Chart syntax.
 * [OUTPUT]: Strictly parses empty charts, comments, titles, axes including trailing arrows, quadrant labels, styles, and normalized points.
 * [POS]: Serves as the dedicated parser for official Mermaid Quadrant Chart diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/quadrant.dart';

class QuadrantChartParser {
  const QuadrantChartParser();

  (MermaidDiagramData, QuadrantChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final pointDeclarations = <_PointDeclaration>[];
    final classes = <String, _PointStyle>{};
    String? title;
    String? xLeft;
    String? xRight;
    String? yBottom;
    String? yTop;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var readingAccessibilityDescription = false;
    final accessibilityLines = <String>[];
    final quadrants = <int, String>{};

    for (final rawLine in _statements(lines.skip(1))) {
      final line = _stripComment(rawLine).trim();
      if (readingAccessibilityDescription) {
        if (line == '}') {
          readingAccessibilityDescription = false;
          accessibilityDescription = accessibilityLines.join('\n').trim();
        } else {
          accessibilityLines.add(line);
        }
        continue;
      }
      if (line.isEmpty || line.startsWith('%%')) continue;
      if (line.toLowerCase().startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
        readingAccessibilityDescription = true;
        accessibilityLines.clear();
        continue;
      }
      if (line.toLowerCase().startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (line.startsWith('title ')) {
        title = _text(line.substring(6));
        continue;
      }
      final axis = RegExp(
        r'^(x-axis|y-axis)\s+(.+?)(?:\s*-->\s*(.+))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (axis != null) {
        var first = _text(axis.group(2)!);
        final second = axis.group(3) == null ? null : _text(axis.group(3)!);
        if (second == null && first.endsWith('-->')) {
          first = '${first.substring(0, first.length - 3).trimRight()} ⟶ ';
        }
        if (axis.group(1)!.toLowerCase() == 'x-axis') {
          xLeft = first;
          xRight = second;
        } else {
          yBottom = first;
          yTop = second;
        }
        continue;
      }
      final quadrant = RegExp(
        r'^quadrant-([1-4])\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (quadrant != null) {
        quadrants[int.parse(quadrant.group(1)!)] = _text(quadrant.group(2)!);
        continue;
      }
      final classDef = RegExp(
        r'^classDef\s+(\w+)\s+(.+?);?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (classDef != null) {
        final parsed = _style(classDef.group(2)!);
        if (parsed == null) return null;
        classes[classDef.group(1)!] = parsed;
        continue;
      }
      final point = RegExp(
        r'^(.+?)(?:::([A-Za-z_]\w*))?\s*:\s*\[\s*(1|0(?:\.\d+)?)\s*,\s*(1|0(?:\.\d+)?)\s*\]\s*(.*?)\s*;?$',
      ).firstMatch(line);
      if (point == null) return null;
      final x = double.parse(point.group(3)!);
      final y = double.parse(point.group(4)!);
      if (x < 0 || x > 1 || y < 0 || y > 1) return null;
      final directStyle = _style(point.group(5)!);
      if (directStyle == null) return null;
      pointDeclarations.add(
        _PointDeclaration(
          label: _text(point.group(1)!),
          className: point.group(2),
          x: x,
          y: y,
          style: directStyle,
        ),
      );
    }

    if (readingAccessibilityDescription) return null;
    final points = <QuadrantPoint>[];
    for (final declaration in pointDeclarations) {
      final classStyle = declaration.className == null
          ? const _PointStyle()
          : classes[declaration.className];
      if (classStyle == null) return null;
      final resolved = classStyle.merge(declaration.style);
      points.add(
        QuadrantPoint(
          label: declaration.label,
          className: declaration.className,
          x: declaration.x,
          y: declaration.y,
          radius: resolved.radius,
          color: resolved.color,
          strokeColor: resolved.strokeColor,
          strokeWidth: resolved.strokeWidth,
        ),
      );
    }
    final nodes = [
      for (var index = 0; index < points.length; index++)
        MermaidNode(id: 'quadrant_$index', label: points[index].label),
    ];
    return (
      MermaidDiagramData(
        type: DiagramType.quadrantChart,
        nodes: nodes,
        edges: const [],
      ),
      QuadrantChartData(
        points: points,
        title: title,
        xLeft: xLeft,
        xRight: xRight,
        yBottom: yBottom,
        yTop: yTop,
        quadrant1: quadrants[1],
        quadrant2: quadrants[2],
        quadrant3: quadrants[3],
        quadrant4: quadrants[4],
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }
}

String _stripComment(String line) {
  var quoted = false;
  var markdown = false;
  for (var index = 0; index < line.length - 1; index++) {
    if (line[index] == '"' && (index == 0 || line[index - 1] != '\\')) {
      quoted = !quoted;
    } else if (quoted && line[index] == '`') {
      markdown = !markdown;
    } else if (!quoted && !markdown && line.startsWith('%%', index)) {
      return line.substring(0, index);
    }
  }
  return line;
}

Iterable<String> _statements(Iterable<String> lines) sync* {
  for (final line in lines) {
    var quoted = false;
    var start = 0;
    for (var index = 0; index < line.length; index++) {
      if (line[index] == '"' && (index == 0 || line[index - 1] != '\\')) {
        quoted = !quoted;
      } else if (line[index] == ';' && !quoted) {
        yield line.substring(start, index);
        start = index + 1;
      }
    }
    yield line.substring(start);
  }
}

_PointStyle? _style(String source) {
  final trimmed = source.trim().replaceFirst(RegExp(r';$'), '').trim();
  if (trimmed.isEmpty) return const _PointStyle();
  double? radius;
  String? color;
  String? strokeColor;
  double? strokeWidth;
  for (final declaration in trimmed.split(',')) {
    final separator = declaration.indexOf(':');
    if (separator <= 0) return null;
    final key = declaration.substring(0, separator).trim().toLowerCase();
    final value = declaration.substring(separator + 1).trim();
    switch (key) {
      case 'radius':
        radius = double.tryParse(value);
        if (radius == null || radius < 0) return null;
      case 'color':
        if (!_hex.hasMatch(value)) return null;
        color = value;
      case 'stroke-color':
        if (!_hex.hasMatch(value)) return null;
        strokeColor = value;
      case 'stroke-width':
        final match = RegExp(r'^(\d+(?:\.\d+)?)px$').firstMatch(value);
        if (match == null) return null;
        strokeWidth = double.parse(match.group(1)!);
      default:
        return null;
    }
  }
  return _PointStyle(
    radius: radius,
    color: color,
    strokeColor: strokeColor,
    strokeWidth: strokeWidth,
  );
}

final _hex = RegExp(r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

class _PointDeclaration {
  const _PointDeclaration({
    required this.label,
    required this.className,
    required this.x,
    required this.y,
    required this.style,
  });
  final String label;
  final String? className;
  final double x;
  final double y;
  final _PointStyle style;
}

class _PointStyle {
  const _PointStyle({
    this.radius,
    this.color,
    this.strokeColor,
    this.strokeWidth,
  });
  final double? radius;
  final String? color;
  final String? strokeColor;
  final double? strokeWidth;

  _PointStyle merge(_PointStyle direct) => _PointStyle(
    radius: direct.radius ?? radius,
    color: direct.color ?? color,
    strokeColor: direct.strokeColor ?? strokeColor,
    strokeWidth: direct.strokeWidth ?? strokeWidth,
  );
}

String _text(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 4 &&
      trimmed.startsWith('"`') &&
      trimmed.endsWith('`"')) {
    return trimmed.substring(2, trimmed.length - 2);
  }
  return trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')
      ? trimmed.substring(1, trimmed.length - 1).replaceAll(r'\"', '"')
      : trimmed;
}
