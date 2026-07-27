/*
 * [INPUT]: Depends on the native flowchart parser because Mermaid swimlanes share flowchart nodes, edges, classes, and subgraph grammar.
 * [OUTPUT]: Parses swimlane-beta diagrams while preserving swimlane type identity and lane subgraphs.
 * [POS]: Serves as the native Mermaid swimlane grammar adapter ahead of lane-specific layout refinements.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/swimlane.dart';
import 'flowchart_parser.dart';

/// Parses Mermaid's experimental swimlane syntax.
///
/// Mermaid 11.16 routes this syntax through the flowchart database and renderer;
/// the top-level subgraphs are the lanes. The native implementation follows the
/// same model while retaining [DiagramType.swimlanes] for layout selection.
class SwimlaneDiagramParser {
  const SwimlaneDiagramParser();

  (MermaidDiagramData, SwimlaneData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final header = lines.first.trim();
    final headerMatch = RegExp(
      r'^swimlane-beta(?:\s+(TB|TD|BT|LR|RL))?\s*;?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(header);
    if (headerMatch == null) return null;
    final direction = headerMatch.group(1);
    final remainder = headerMatch.group(2)!.trim();

    final flowchartLines = <String>[
      'flowchart ${direction ?? 'TB'}',
      if (remainder.isNotEmpty) ..._inlineStatements(remainder),
      ...lines.skip(1),
    ];
    final graph = FlowchartParser().parse(flowchartLines);
    if (graph == null) return null;
    String? accessibilityTitle;
    String? accessibilityDescription;
    for (var index = 1; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.startsWith('accTitle:')) {
        accessibilityTitle = line.substring('accTitle:'.length).trim();
      } else if (line.startsWith('accDescr:')) {
        accessibilityDescription = line.substring('accDescr:'.length).trim();
      } else if (line == 'accDescr {') {
        final parts = <String>[];
        while (++index < lines.length && lines[index].trim() != '}') {
          if (lines[index].trim().isNotEmpty) parts.add(lines[index].trim());
        }
        accessibilityDescription = parts.join('\n');
      }
    }
    final diagram = graph.copyWith(type: DiagramType.swimlanes);
    return (
      diagram,
      SwimlaneData(
        laneIds: diagram.subgraphs.map((lane) => lane.id).toList(),
        title: diagram.title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  List<String> _inlineStatements(String source) {
    final result = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    var bracketDepth = 0;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (char == '"' && (index == 0 || source[index - 1] != r'\')) {
        quoted = !quoted;
      }
      if (!quoted && '([{'.contains(char)) bracketDepth++;
      if (!quoted && ')]}'.contains(char)) bracketDepth--;
      if (char == ';' && !quoted && bracketDepth == 0) {
        if (buffer.toString().trim().isNotEmpty) {
          result.add(buffer.toString().trim());
        }
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    if (buffer.toString().trim().isNotEmpty) {
      result.add(buffer.toString().trim());
    }
    return result;
  }
}
