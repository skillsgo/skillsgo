/*
 * [INPUT]: Depends on Mermaid 11.16.0 Sankey grammar and its three-column RFC 4180-compatible CSV dialect.
 * [OUTPUT]: Strictly parses ordered nodes, escaped or multiline CSV fields, doubled quotes, and finite numeric link weights.
 * [POS]: Serves as the lossless native parser for sankey and sankey-beta instead of silently dropping invalid records.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/sankey.dart';

class NativeSankeyDiagramParser {
  const NativeSankeyDiagramParser();

  (MermaidDiagramData, SankeyChartData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) {
      final value = line.trim().toLowerCase();
      return value == 'sankey' || value == 'sankey-beta';
    });
    if (header < 0) return null;
    final records = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (final sourceLine in lines.skip(header + 1)) {
      final line = sourceLine.trim();
      if (!quoted && (line.isEmpty || line == '---' || line.startsWith('%%'))) {
        continue;
      }
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(sourceLine.trim());
      quoted = _quoteState(sourceLine, quoted);
      if (!quoted) {
        records.add(buffer.toString());
        buffer.clear();
      }
    }
    if (quoted || buffer.isNotEmpty) return null;
    final nodeIds = <String>[];
    final links = <SankeyLinkData>[];
    for (final record in records) {
      final fields = _fields(record);
      if (fields == null || fields.length != 3) return null;
      final source = fields[0].trim();
      final target = fields[1].trim();
      final value = double.tryParse(fields[2].trim());
      if (source.isEmpty ||
          target.isEmpty ||
          value == null ||
          !value.isFinite) {
        return null;
      }
      if (!nodeIds.contains(source)) nodeIds.add(source);
      if (!nodeIds.contains(target)) nodeIds.add(target);
      links.add(
        SankeyLinkData(
          index: links.length,
          source: source,
          target: target,
          value: value,
        ),
      );
    }
    if (links.isEmpty) return null;
    final nodes = [
      for (var index = 0; index < nodeIds.length; index++)
        SankeyNodeData(index: index, id: nodeIds[index]),
    ];
    return (
      MermaidDiagramData(
        type: DiagramType.sankey,
        nodes: [
          for (final node in nodes) MermaidNode(id: node.id, label: node.id),
        ],
        edges: [
          for (final link in links)
            MermaidEdge(
              from: link.source,
              to: link.target,
              label: _number(link.value),
            ),
        ],
        direction: DiagramDirection.leftToRight,
      ),
      SankeyChartData(nodes: nodes, links: links),
    );
  }

  bool _quoteState(String input, bool initial) {
    var quoted = initial;
    for (var index = 0; index < input.length; index++) {
      if (input[index] != '"') continue;
      if (quoted && index + 1 < input.length && input[index + 1] == '"') {
        index++;
      } else {
        quoted = !quoted;
      }
    }
    return quoted;
  }

  List<String>? _fields(String input) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    var fieldStarted = false;
    for (var index = 0; index < input.length; index++) {
      final char = input[index];
      if (char == '"') {
        if (quoted && index + 1 < input.length && input[index + 1] == '"') {
          buffer.write('"');
          index++;
        } else if (!fieldStarted || quoted) {
          quoted = !quoted;
          fieldStarted = true;
        } else {
          return null;
        }
      } else if (char == ',' && !quoted) {
        fields.add(buffer.toString());
        buffer.clear();
        fieldStarted = false;
      } else {
        buffer.write(char);
        if (char.trim().isNotEmpty) fieldStarted = true;
      }
    }
    if (quoted) return null;
    fields.add(buffer.toString());
    return fields;
  }

  String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}
