/*
 * [INPUT]: Depends on dart:convert, Mermaid 11.16.0 Radar Langium grammar, and native Radar/diagram models.
 * [OUTPUT]: Strictly parses headers, metadata, axes, curves with positional or referenced multiline entries, and comma-separated options.
 * [POS]: Serves as the complete native parser for Mermaid radar-beta diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';

import '../models/diagram.dart';
import '../models/radar.dart';

class RadarParser {
  const RadarParser();

  (MermaidDiagramData, RadarChartData)? parse(List<String> sourceLines) {
    final lines = sourceLines
        .map(_stripComment)
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty ||
        !RegExp(
          r'^radar-beta\s*:\s*$|^radar-beta\s*$',
          caseSensitive: false,
        ).hasMatch(lines.first.trim())) {
      return null;
    }

    final axes = <RadarAxis>[];
    final curves = <RadarCurve>[];
    final curveSources = <String>[];
    var showLegend = true;
    var ticks = 5.0;
    double? max;
    var min = 0.0;
    var graticule = RadarGraticule.circle;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;

    final statements = _logicalStatements(lines.skip(1).toList());
    if (statements == null) return null;
    for (final source in statements) {
      final statement = source.trim();
      if (statement.isEmpty) continue;
      final lower = statement.toLowerCase();
      if (lower.startsWith('title') &&
          (statement.length == 5 || _space(statement[5]))) {
        title = statement.length == 5 ? '' : statement.substring(5).trim();
        continue;
      }
      if (lower.startsWith('acctitle:')) {
        accessibilityTitle = statement
            .substring(statement.indexOf(':') + 1)
            .trim();
        continue;
      }
      if (lower.startsWith('accdescr:')) {
        accessibilityDescription = statement
            .substring(statement.indexOf(':') + 1)
            .trim();
        continue;
      }
      final multilineAcc = RegExp(
        r'^accDescr\s*\{([\s\S]*)\}$',
        caseSensitive: false,
      ).firstMatch(statement);
      if (multilineAcc != null) {
        accessibilityDescription = multilineAcc.group(1)!.trim();
        continue;
      }
      if (lower.startsWith('axis ')) {
        final parsed = _parseAxes(statement.substring(5));
        if (parsed == null) return null;
        axes.addAll(parsed);
        continue;
      }
      if (lower.startsWith('curve ')) {
        curveSources.add(statement.substring(6));
        continue;
      }

      final options = _splitTopLevel(statement, ',');
      if (options == null) return null;
      for (final option in options) {
        final match = RegExp(
          r'^(showLegend|ticks|max|min|graticule)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(option.trim());
        if (match == null) return null;
        final name = match.group(1)!.toLowerCase();
        final value = match.group(2)!.trim();
        switch (name) {
          case 'showlegend':
            if (value != 'true' && value != 'false') return null;
            showLegend = value == 'true';
          case 'ticks':
            final number = _number(value);
            if (number == null) return null;
            ticks = number;
          case 'max':
            max = _number(value);
            if (max == null) return null;
          case 'min':
            final number = _number(value);
            if (number == null) return null;
            min = number;
          case 'graticule':
            if (value != 'circle' && value != 'polygon') return null;
            graticule = value == 'circle'
                ? RadarGraticule.circle
                : RadarGraticule.polygon;
        }
      }
    }

    for (final source in curveSources) {
      final parsed = _parseCurves(source, axes);
      if (parsed == null) return null;
      curves.addAll(parsed);
    }

    final data = RadarChartData(
      axes: axes,
      curves: curves,
      title: title,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      showLegend: showLegend,
      max: max,
      min: min,
      graticule: graticule,
      ticks: ticks,
    );
    return (
      MermaidDiagramData(
        type: DiagramType.radar,
        nodes: const [],
        edges: const [],
        title: title,
      ),
      data,
    );
  }

  List<RadarAxis>? _parseAxes(String source) {
    final parts = _splitTopLevel(source, ',');
    if (parts == null || parts.isEmpty) return null;
    final result = <RadarAxis>[];
    for (final part in parts) {
      final match = RegExp(
        r'''^([A-Za-z0-9_](?:[-A-Za-z0-9_]*[A-Za-z0-9_])?)(?:\s*\[\s*((?:"(?:\\.|[^"\\])*")|(?:'(?:\\.|[^'\\])*')|(?:[^\]\r\n]+))\s*\])?$''',
      ).firstMatch(part.trim());
      if (match == null) return null;
      final label = _label(match.group(2), match.group(1)!);
      if (label == null) return null;
      result.add(RadarAxis(id: match.group(1)!, label: label));
    }
    return result;
  }

  List<RadarCurve>? _parseCurves(String source, List<RadarAxis> axes) {
    final chunks = <String>[];
    var start = 0;
    var depth = 0;
    var quoted = false;
    String? quote;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if ((char == '"' || char == "'") &&
          (index == 0 || source[index - 1] != '\\')) {
        if (!quoted) {
          quoted = true;
          quote = char;
        } else if (quote == char) {
          quoted = false;
        }
      } else if (!quoted && char == '{') {
        depth++;
      } else if (!quoted && char == '}') {
        depth--;
        if (depth < 0) return null;
      } else if (!quoted && depth == 0 && char == ',') {
        chunks.add(source.substring(start, index));
        start = index + 1;
      }
    }
    if (quoted || depth != 0) return null;
    chunks.add(source.substring(start));

    final result = <RadarCurve>[];
    for (final chunk in chunks) {
      final match = RegExp(
        r'''^\s*([A-Za-z0-9_](?:[-A-Za-z0-9_]*[A-Za-z0-9_])?)(?:\s*\[\s*((?:"(?:\\.|[^"\\])*")|(?:'(?:\\.|[^'\\])*')|(?:[^\]\r\n]+))\s*\])?\s*\{([\s\S]*)\}\s*$''',
      ).firstMatch(chunk);
      if (match == null) return null;
      final label = _label(match.group(2), match.group(1)!);
      if (label == null) return null;
      final entries = _splitTopLevel(match.group(3)!, ',');
      if (entries == null || entries.isEmpty) return null;
      final positional = <double>[];
      final referenced = <String, double>{};
      bool? detailed;
      for (final entry in entries) {
        final value = entry.trim();
        final detail = RegExp(
          r'^([A-Za-z0-9_](?:[-A-Za-z0-9_]*[A-Za-z0-9_])?)\s*:?\s*(\d+(?:\.\d+)?)$',
        ).firstMatch(value);
        if (detail != null) {
          if (detailed == false || referenced.containsKey(detail.group(1))) {
            return null;
          }
          detailed = true;
          referenced[detail.group(1)!] = double.parse(detail.group(2)!);
        } else {
          final number = _number(value);
          if (number == null || detailed == true) return null;
          detailed = false;
          positional.add(number);
        }
      }
      final values = <double>[];
      if (detailed == true) {
        if (referenced.length != axes.length) return null;
        for (final axis in axes) {
          final value = referenced[axis.id];
          if (value == null) return null;
          values.add(value);
        }
      } else {
        values.addAll(positional);
      }
      result.add(RadarCurve(id: match.group(1)!, label: label, values: values));
    }
    return result;
  }
}

List<String>? _logicalStatements(List<String> lines) {
  final result = <String>[];
  var buffer = StringBuffer();
  var depth = 0;
  for (final line in lines) {
    if (buffer.isNotEmpty) buffer.write('\n');
    buffer.write(line);
    depth += '{'.allMatches(line).length - '}'.allMatches(line).length;
    if (depth < 0) return null;
    if (depth == 0) {
      result.add(buffer.toString());
      buffer = StringBuffer();
    }
  }
  return depth == 0 && buffer.isEmpty ? result : null;
}

List<String>? _splitTopLevel(String source, String delimiter) {
  final result = <String>[];
  var start = 0;
  var square = 0;
  var curly = 0;
  String? quote;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if ((char == '"' || char == "'") &&
        (index == 0 || source[index - 1] != '\\')) {
      quote = quote == null ? char : (quote == char ? null : quote);
    } else if (quote == null) {
      if (char == '[') square++;
      if (char == ']') square--;
      if (char == '{') curly++;
      if (char == '}') curly--;
      if (square < 0 || curly < 0) return null;
      if (char == delimiter && square == 0 && curly == 0) {
        final value = source.substring(start, index).trim();
        if (value.isEmpty) return null;
        result.add(value);
        start = index + 1;
      }
    }
  }
  if (quote != null || square != 0 || curly != 0) return null;
  final value = source.substring(start).trim();
  if (value.isEmpty) return null;
  return [...result, value];
}

String _stripComment(String line) {
  String? quote;
  for (var index = 0; index < line.length - 1; index++) {
    final char = line[index];
    if ((char == '"' || char == "'") &&
        (index == 0 || line[index - 1] != '\\')) {
      quote = quote == null ? char : (quote == char ? null : quote);
    } else if (quote == null && line.startsWith('%%', index)) {
      return line.substring(0, index);
    }
  }
  return line;
}

String? _string(String source) {
  if (source.startsWith('"')) {
    try {
      final value = jsonDecode(source);
      return value is String ? value : null;
    } on FormatException {
      return null;
    }
  }
  if (!source.startsWith("'") || !source.endsWith("'")) return null;
  return source
      .substring(1, source.length - 1)
      .replaceAll(r"\'", "'")
      .replaceAll(r'\\', r'\');
}

String? _label(String? source, String fallback) {
  if (source == null) return fallback;
  final value = source.trim();
  if (value.startsWith('"') || value.startsWith("'")) return _string(value);
  return value.isEmpty ? null : value;
}

double? _number(String source) =>
    RegExp(r'^(?:0|[1-9]\d*)(?:\.\d+)?$').hasMatch(source)
    ? double.parse(source)
    : null;

bool _space(String value) => value == ' ' || value == '\t';
