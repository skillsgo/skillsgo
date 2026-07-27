/*
 * [INPUT]: Depends on Mermaid 11.16.0 mindmap lexer semantics, relative indentation, shapes, Markdown strings, icons, and classes.
 * [OUTPUT]: Strictly parses one rooted native mindmap while preserving source identifiers, indentation, hierarchy, decoration, and shape identity.
 * [POS]: Serves as the lossless native parser for mindmap and rejects malformed hierarchy or unknown directives.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/mindmap.dart';
import '../models/node.dart';

class NativeMindmapDiagramParser {
  const NativeMindmapDiagramParser();

  (MermaidDiagramData, MindmapChartData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (header < 0 || lines[header].trim().toLowerCase() != 'mindmap') {
      return null;
    }
    final nodes = <MindmapNodeData>[];
    int? baseIndentation;
    var index = header + 1;
    while (index < lines.length) {
      final raw = lines[index++];
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.startsWith('%%') || trimmed == '---') {
        continue;
      }
      if (trimmed.startsWith('::icon(')) {
        if (nodes.isEmpty || !trimmed.endsWith(')')) return null;
        final icon = trimmed.substring(7, trimmed.length - 1);
        if (icon.isEmpty) return null;
        nodes[nodes.length - 1] = nodes.last.copyWith(icon: icon);
        continue;
      }
      if (trimmed.startsWith(':::')) {
        if (nodes.isEmpty) return null;
        final cssClass = trimmed.substring(3).trim();
        if (cssClass.isEmpty) return null;
        nodes[nodes.length - 1] = nodes.last.copyWith(cssClass: cssClass);
        continue;
      }
      var token = trimmed;
      if (_startsMultilineMarkdown(token) && !_endsMultilineMarkdown(token)) {
        final parts = [token];
        var closed = false;
        while (index < lines.length) {
          final continuation = lines[index++].trim();
          parts.add(continuation);
          if (_endsMultilineMarkdown(continuation)) {
            closed = true;
            break;
          }
        }
        if (!closed) return null;
        token = parts.join('\n');
      }
      final parsed = _node(token);
      if (parsed == null) return null;
      final indentation = raw.length - raw.trimLeft().length;
      baseIndentation ??= indentation;
      final relativeIndentation = indentation - baseIndentation;
      if (relativeIndentation < 0) return null;
      int? parentIndex;
      if (nodes.isNotEmpty) {
        for (var candidate = nodes.length - 1; candidate >= 0; candidate--) {
          if (nodes[candidate].indentation < relativeIndentation) {
            parentIndex = candidate;
            break;
          }
        }
        if (parentIndex == null) return null;
      }
      final level = parentIndex == null ? 0 : nodes[parentIndex].level + 1;
      final section = parentIndex == null
          ? null
          : nodes[parentIndex].parentIndex == null
          ? nodes.where((node) => node.parentIndex == parentIndex).length
          : nodes[parentIndex].section;
      nodes.add(
        MindmapNodeData(
          index: nodes.length,
          sourceId: parsed.$1,
          label: parsed.$2,
          shape: parsed.$3,
          indentation: relativeIndentation,
          level: level,
          parentIndex: parentIndex,
          section: section,
        ),
      );
    }
    if (nodes.isEmpty) return null;
    final graphNodes = [
      for (final node in nodes)
        MermaidNode(
          id: 'mindmap_${node.index}',
          label: node.label,
          shape: _graphShape(node.shape),
          className: node.cssClass,
        ),
    ];
    return (
      MermaidDiagramData(
        type: DiagramType.mindmap,
        nodes: graphNodes,
        edges: [
          for (final node in nodes)
            if (node.parentIndex case final int parent)
              MermaidEdge(from: 'mindmap_$parent', to: 'mindmap_${node.index}'),
        ],
        direction: DiagramDirection.leftToRight,
      ),
      MindmapChartData(nodes: nodes, rootIndex: 0),
    );
  }

  bool _startsMultilineMarkdown(String value) => value.contains('["`');
  bool _endsMultilineMarkdown(String value) => value.endsWith('`"]');

  (String, String, MindmapNodeShape)? _node(String value) {
    final patterns = <(RegExp, MindmapNodeShape)>[
      (RegExp(r'^(.*?)\(\((.*)\)\)$', dotAll: true), MindmapNodeShape.circle),
      (RegExp(r'^(.*?)\)\)(.*)\(\($', dotAll: true), MindmapNodeShape.bang),
      (RegExp(r'^(.*?)\)(.*)\($', dotAll: true), MindmapNodeShape.cloud),
      (RegExp(r'^(.*?)\{\{(.*)\}\}$', dotAll: true), MindmapNodeShape.hexagon),
      (RegExp(r'^(.*?)\[(.*)\]$', dotAll: true), MindmapNodeShape.rectangle),
      (
        RegExp(r'^(.*?)\((.*)\)$', dotAll: true),
        MindmapNodeShape.roundedRectangle,
      ),
    ];
    for (final (pattern, shape) in patterns) {
      final match = pattern.firstMatch(value);
      if (match == null) continue;
      var label = match.group(2)!;
      if (label.startsWith('"`') && label.endsWith('`"')) {
        label = label.substring(2, label.length - 2);
      }
      if (label.startsWith('"') && label.endsWith('"')) {
        label = label.substring(1, label.length - 1);
      }
      final sourceId = match.group(1)!.trim().isEmpty
          ? label
          : match.group(1)!.trim();
      return (sourceId, label, shape);
    }
    if (value.contains(RegExp(r'[\[\](){}]'))) return null;
    return (value, value, MindmapNodeShape.noBorder);
  }

  NodeShape _graphShape(MindmapNodeShape shape) => switch (shape) {
    MindmapNodeShape.noBorder => NodeShape.rectangle,
    MindmapNodeShape.roundedRectangle => NodeShape.roundedRect,
    MindmapNodeShape.rectangle => NodeShape.rectangle,
    MindmapNodeShape.circle => NodeShape.circle,
    MindmapNodeShape.cloud => NodeShape.roundedRect,
    MindmapNodeShape.bang => NodeShape.circle,
    MindmapNodeShape.hexagon => NodeShape.hexagon,
  };
}
