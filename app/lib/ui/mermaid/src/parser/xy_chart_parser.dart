/*
 * [INPUT]: Depends on Mermaid XY chart syntax and native diagram/XY models.
 * [OUTPUT]: Strictly parses orientation, titles/accessibility, categorical/numeric axes, titled bar/line series, and labeled points.
 * [POS]: Serves as the dedicated native parser for XY charts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

import '../models/diagram.dart';
import '../models/xy_chart.dart';

/// Parser for Mermaid XY Charts
class XYChartParser {
  /// Creates an XY chart parser
  const XYChartParser();

  /// Parses XY chart from cleaned lines
  /// Returns tuple of (MermaidDiagramData, XYChartData) or null if invalid
  (MermaidDiagramData, XYChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final statements = _splitStatements(lines);

    String? title;
    String? xAxisTitle;
    String? yAxisTitle;
    String? accessibilityTitle;
    String? accessibilityDescription;
    final xAxisCategories = <String>[];
    double? xAxisMin;
    double? xAxisMax;
    double? yAxisMin;
    double? yAxisMax;
    var orientation = XYChartOrientation.vertical;
    var headerSeen = false;
    final seriesList = <XYChartSeries>[];

    for (var i = 0; i < statements.length; i++) {
      final line = statements[i];
      final trimmedLine = line.trim();

      if (trimmedLine.isEmpty) continue;

      final lowerLine = trimmedLine.toLowerCase();

      // Skip 'xychart-beta' or 'xychart' keyword
      if (lowerLine.startsWith('xychart')) {
        final header = RegExp(
          r'^xychart(?:-beta)?(?:\s+(vertical|horizontal))?$',
          caseSensitive: false,
        ).firstMatch(trimmedLine);
        if (header == null || headerSeen) return null;
        headerSeen = true;
        orientation = header.group(1)?.toLowerCase() == 'horizontal'
            ? XYChartOrientation.horizontal
            : XYChartOrientation.vertical;
        continue;
      }

      // Parse title
      if (RegExp(
        r'^title(?=\s|"|`)',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        title = _parseText(trimmedLine.substring(5).trim());
        if (title == null) return null;
        continue;
      }

      if (RegExp(
        r'^acctitle\s*:',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        accessibilityTitle = trimmedLine
            .substring(trimmedLine.indexOf(':') + 1)
            .trim();
        continue;
      }

      if (RegExp(
        r'^accdescr\s*:',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        accessibilityDescription = trimmedLine
            .substring(trimmedLine.indexOf(':') + 1)
            .trim();
        continue;
      }

      if (RegExp(
        r'^accdescr\s*\{',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        final description = StringBuffer();
        var remainder = trimmedLine.substring(trimmedLine.indexOf('{') + 1);
        while (true) {
          final closing = remainder.indexOf('}');
          if (closing >= 0) {
            if (description.isNotEmpty) description.write('\n');
            description.write(remainder.substring(0, closing));
            break;
          }
          if (description.isNotEmpty) description.write('\n');
          description.write(remainder);
          i++;
          if (i >= statements.length) return null;
          remainder = statements[i];
        }
        accessibilityDescription = description.toString().trim();
        continue;
      }

      // Parse x-axis
      if (RegExp(
        r'^x-axis(?=\s|\[|"|`)',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        final content = trimmedLine.substring(6).trim();
        final parsed = _parseAxis(content, categoriesAllowed: true);
        if (parsed == null) return null;
        xAxisTitle = parsed.title;
        xAxisCategories.clear();
        if (parsed.categories != null) {
          xAxisCategories.addAll(parsed.categories!);
        }
        xAxisMin = parsed.min;
        xAxisMax = parsed.max;
        continue;
      }

      // Parse y-axis
      if (RegExp(
        r'^y-axis(?=\s|"|`|[+\-.\d])',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        final content = trimmedLine.substring(6).trim();
        final parsed = _parseAxis(content, categoriesAllowed: false);
        if (parsed == null) return null;
        yAxisTitle = parsed.title;
        yAxisMin = parsed.min;
        yAxisMax = parsed.max;
        continue;
      }

      // Parse bar series
      if (RegExp(
        r'^bar(?=\s|\[|"|`)',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        final input = trimmedLine.substring(3).trim();
        final values = _parseValues(input);
        final seriesTitle = _parseSeriesTitle(input);
        if (values == null || seriesTitle == null) return null;
        if (values.$1.isNotEmpty) {
          seriesList.add(
            XYChartSeries(
              type: XYSeriesType.bar,
              values: values.$1,
              title: seriesTitle.$1,
              titleIsMarkdown: seriesTitle.$2,
              pointLabels: values.$2,
            ),
          );
        }
        continue;
      }

      // Parse line series
      if (RegExp(
        r'^line(?=\s|\[|"|`)',
        caseSensitive: false,
      ).hasMatch(trimmedLine)) {
        final input = trimmedLine.substring(4).trim();
        final values = _parseValues(input);
        final seriesTitle = _parseSeriesTitle(input);
        if (values == null || seriesTitle == null) return null;
        if (values.$1.isNotEmpty) {
          seriesList.add(
            XYChartSeries(
              type: XYSeriesType.line,
              values: values.$1,
              title: seriesTitle.$1,
              titleIsMarkdown: seriesTitle.$2,
              pointLabels: values.$2,
            ),
          );
        }
        continue;
      }
      return null;
    }

    if (!headerSeen || seriesList.isEmpty) return null;

    final xyData = XYChartData(
      series: seriesList,
      title: title,
      xAxisTitle: xAxisTitle,
      yAxisTitle: yAxisTitle,
      xAxisCategories: xAxisCategories,
      xAxisMin: xAxisMin,
      xAxisMax: xAxisMax,
      yAxisMin: yAxisMin,
      yAxisMax: yAxisMax,
      orientation: orientation,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
    );

    final diagramData = MermaidDiagramData(
      type: DiagramType.xyChart,
      nodes: const [],
      edges: const [],
      title: title,
    );

    return (diagramData, xyData);
  }

  List<String> _splitStatements(List<String> lines) {
    final statements = <String>[];
    var accessibilityBlock = false;
    for (final line in lines) {
      final buffer = StringBuffer();
      var quoted = false;
      var escaped = false;
      for (final rune in line.runes) {
        final character = String.fromCharCode(rune);
        if (escaped) {
          escaped = false;
        } else if (quoted && character == r'\') {
          escaped = true;
        } else if (character == '"') {
          quoted = !quoted;
        }
        if (!quoted && character == '{') accessibilityBlock = true;
        if (!quoted && character == '}') accessibilityBlock = false;
        if (character == ';' && !quoted && !accessibilityBlock) {
          statements.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(character);
        }
      }
      statements.add(buffer.toString());
    }
    return statements;
  }

  (String, bool)? _parseSeriesTitle(String input) {
    final brackets = _brackets(input);
    if (brackets == null) return null;
    if (brackets.$1 == 0) return ('', false);
    final raw = input.substring(0, brackets.$1).trim();
    if (raw.length >= 4 && raw.startsWith('"`') && raw.endsWith('`"')) {
      return (raw.substring(2, raw.length - 2), true);
    }
    final text = _parseText(raw);
    return text == null ? null : (text, false);
  }

  /// Parses axis definition
  /// Supports: "Title" [cat1, cat2] or "Title" min --> max or just [cat1, cat2]
  _AxisParseResult? _parseAxis(
    String content, {
    required bool categoriesAllowed,
  }) {
    String? title;
    List<String>? categories;
    double? min;
    double? max;

    final brackets = _brackets(content);
    final categoryStart = brackets?.$1 ?? -1;
    final range = RegExp(
      r'([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*-->\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*$',
    ).firstMatch(content);
    String titleSource;
    if (categoryStart >= 0) {
      if (!categoriesAllowed || brackets == null) return null;
      titleSource = content.substring(0, categoryStart).trim();
      final parsed = _parseCategories(
        content.substring(categoryStart + 1, brackets.$2),
      );
      if (content.substring(brackets.$2 + 1).trim().isNotEmpty) return null;
      if (parsed == null || parsed.isEmpty) return null;
      categories = parsed;
    } else if (range != null) {
      titleSource = content.substring(0, range.start).trim();
      min = double.tryParse(range.group(1)!);
      max = double.tryParse(range.group(2)!);
    } else {
      titleSource = content.trim();
    }
    if (titleSource.isNotEmpty) {
      title = _parseText(titleSource);
      if (title == null) return null;
    } else if (categories == null && range == null) {
      return null;
    }

    return _AxisParseResult(
      title: title,
      categories: categories,
      min: min,
      max: max,
    );
  }

  /// Parses category list from bracket content
  List<String>? _parseCategories(String input) {
    final values = <String>[];
    for (final part in _splitCommaSeparated(input)) {
      final text = _parseText(part.trim());
      if (text == null) return null;
      values.add(text);
    }
    return values;
  }

  /// Parses values from bracket notation: [1, 2, 3.5, -4]
  (List<double>, List<String?>)? _parseValues(String input) {
    final values = <double>[];
    final labels = <String?>[];

    // Mermaid permits an optional quoted series title before the data array.
    final brackets = _brackets(input);
    if (brackets == null) return null;
    final openBracket = brackets.$1;
    final closeBracket = brackets.$2;
    if (input.substring(closeBracket + 1).trim().isNotEmpty) return null;
    final content = input.substring(openBracket + 1, closeBracket);

    final parts = _splitCommaSeparated(content);
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) return null;
      final labeled = RegExp(
        r'^([+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?)(?:\s*"((?:[^"\\]|\\.)*)")?$',
      ).firstMatch(trimmed);
      if (labeled == null) return null;
      final value = double.tryParse(labeled.group(1)!);
      if (value == null || !value.isFinite) return null;
      values.add(value);
      labels.add(
        labeled.group(2) == null
            ? null
            : _unescapeQuoted(labeled.group(2)!).trim(),
      );
    }

    return (values, labels);
  }

  (int, int)? _brackets(String input) {
    var quoted = false;
    var escaped = false;
    int? open;
    int? close;
    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (quoted && character == r'\') {
        escaped = true;
        continue;
      }
      if (character == '"') {
        quoted = !quoted;
        continue;
      }
      if (quoted) continue;
      if (character == '[') {
        if (open != null || close != null) return null;
        open = index;
      } else if (character == ']') {
        if (open == null || close != null) return null;
        close = index;
      }
    }
    if (quoted || open == null || close == null || close <= open) return null;
    return (open, close);
  }

  String? _parseText(String input) {
    if (input.length >= 4 && input.startsWith('"`') && input.endsWith('`"')) {
      return input.substring(2, input.length - 2).trim();
    }
    if (input.length >= 2 && input.startsWith('"') && input.endsWith('"')) {
      return input.substring(1, input.length - 1).trim();
    }
    if (input.isEmpty ||
        !RegExp(r'^[A-Za-z0-9&+*=.#_\-\s]+$').hasMatch(input)) {
      return null;
    }
    return input.replaceAll(RegExp(r'\s+'), '');
  }

  String _unescapeQuoted(String value) => value.replaceAllMapped(
    RegExp(r'\\(.)'),
    (match) => switch (match.group(1)) {
      'n' => '\n',
      'r' => '\r',
      't' => '\t',
      final character => character!,
    },
  );

  List<String> _splitCommaSeparated(String input) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    var escaped = false;
    for (final codePoint in input.runes) {
      final character = String.fromCharCode(codePoint);
      if (escaped) {
        current.write(character);
        escaped = false;
        continue;
      }
      if (character == r'\' && inQuotes) {
        current.write(character);
        escaped = true;
        continue;
      }
      if (character == '"') {
        inQuotes = !inQuotes;
        current.write(character);
        continue;
      }
      if (character == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
        continue;
      }
      current.write(character);
    }
    result.add(current.toString());
    return result;
  }
}

/// Internal result of axis parsing
class _AxisParseResult {
  const _AxisParseResult({this.title, this.categories, this.min, this.max});
  final String? title;
  final List<String>? categories;
  final double? min;
  final double? max;
}
