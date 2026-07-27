/*
 * [INPUT]: Depends on Mermaid 11.16.0 Pie Langium grammar and native Pie plus shared diagram models.
 * [OUTPUT]: Strictly parses quoted escaped labels, finite non-negative values, first-wins duplicate labels, showData, title, and accessibility directives.
 * [POS]: Serves as the lossless native parser for Pie and rejects unknown statements instead of dropping them.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';

import '../models/diagram.dart';
import '../models/pie_chart.dart';

/// Parser for Mermaid pie chart diagrams
///
/// Parses pie chart syntax like:
/// ```
/// pie
///     title My Pie Chart
///     "Dogs" : 386
///     "Cats" : 85
///     "Rats" : 15
/// ```
///
/// Or with showData:
/// ```
/// pie showData
///     title My Pie Chart
///     "Dogs" : 386
///     "Cats" : 85
/// ```
class PieChartParser {
  /// Creates a pie chart parser
  const PieChartParser();

  /// Parses pie chart diagram from cleaned lines
  ///
  /// Returns a tuple of (MermaidDiagramData, PieChartData) or null if parsing fails
  (MermaidDiagramData, PieChartData)? parse(List<String> lines) {
    final header = lines.indexWhere(
      (line) => RegExp(
        r'^\s*pie(?:\s+showData)?(?:\s+title\s+.+)?\s*$',
        caseSensitive: false,
      ).hasMatch(line),
    );
    if (header < 0) return null;

    String? title;
    final slices = <PieSlice>[];
    var showValuesInLegend = false;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var readingDescription = false;
    final descriptionLines = <String>[];

    // Parse the first line for options
    final firstLine = lines[header].trim().toLowerCase();
    if (firstLine.contains('showdata')) {
      showValuesInLegend = true;
    }
    final inlineTitle = RegExp(
      r'^\s*pie(?:\s+showData)?\s+title\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(lines[header]);
    title = inlineTitle?.group(1)?.trim();

    // Parse remaining lines
    for (var i = header + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (readingDescription) {
        if (line == '}') {
          readingDescription = false;
          accessibilityDescription = descriptionLines.join('\n').trim();
        } else {
          descriptionLines.add(line);
        }
        continue;
      }
      if (line.isEmpty) continue;

      // Parse title
      if (line.toLowerCase().startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (line.toLowerCase().startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
        readingDescription = true;
        descriptionLines.clear();
        continue;
      }
      if (line.toLowerCase().startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }

      // Parse slice: "Label" : value
      final slice = _parseSlice(line);
      if (slice != null) {
        if (!slices.any((item) => item.label == slice.label)) slices.add(slice);
      } else if (line != '---') {
        return null;
      }
    }

    if (readingDescription) return null;

    if (slices.isEmpty) return null;

    final pieData = PieChartData(
      title: title,
      slices: slices,
      showValuesInLegend: showValuesInLegend,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
    );

    // Create a minimal diagram data for compatibility
    final diagramData = MermaidDiagramData(
      type: DiagramType.pieChart,
      nodes: const [],
      edges: const [],
      title: title,
    );

    return (diagramData, pieData);
  }

  /// Parses a single slice line
  ///
  /// Format: "Label" : value
  /// or: "Label": value
  /// or: Label : value
  PieSlice? _parseSlice(String line) {
    final match = RegExp(
      r'''^("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')\s*:\s*(-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?)$''',
    ).firstMatch(line);
    if (match == null) return null;
    final value = double.tryParse(match.group(2)!);
    if (value == null || !value.isFinite || value < 0) return null;
    final source = match.group(1)!;
    final label = source.startsWith('"')
        ? jsonDecode(source) as String
        : source
              .substring(1, source.length - 1)
              .replaceAll(r"\'", "'")
              .replaceAll('\\\\', '\\');
    return PieSlice(label: label, value: value);
  }
}
