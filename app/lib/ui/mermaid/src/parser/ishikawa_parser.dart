/*
 * [INPUT]: Depends on Mermaid 11.16.0 ishikawa/ishikawa-beta indentation and comment grammar plus native graph/tree models.
 * [OUTPUT]: Parses the effect root and arbitrarily deep relative-indentation cause hierarchy while ignoring official %% comment lines.
 * [POS]: Serves as the dedicated native parser for Mermaid Ishikawa diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/ishikawa.dart';
import '../models/node.dart';

class IshikawaDiagramParser {
  const IshikawaDiagramParser();

  (MermaidDiagramData, IshikawaChartData)? parse(List<String> lines) {
    if (lines.isEmpty ||
        !RegExp(
          r'^ishikawa(?:-beta)?$',
          caseSensitive: false,
        ).hasMatch(lines.first.trim())) {
      return null;
    }
    final entries = lines
        .skip(1)
        .where(
          (line) => line.trim().isNotEmpty && !line.trimLeft().startsWith('%%'),
        )
        .map((line) => (_indent(line), line.trim()))
        .toList();
    if (entries.isEmpty) return null;
    final root = _MutableIshikawaNode('cause-0', entries.first.$2);
    final stack = <(int, _MutableIshikawaNode)>[(0, root)];
    int? baseIndent;
    var id = 1;
    for (final entry in entries.skip(1)) {
      baseIndent ??= entry.$1;
      final level = (entry.$1 - baseIndent + 1).clamp(1, 1000000);
      while (stack.length > 1 && stack.last.$1 >= level) {
        stack.removeLast();
      }
      final node = _MutableIshikawaNode('cause-${id++}', entry.$2);
      stack.last.$2.children.add(node);
      stack.add((level, node));
    }
    final frozen = root.freeze();
    final nodes = <MermaidNode>[];
    final edges = <MermaidEdge>[];
    void flatten(IshikawaNodeData node) {
      nodes.add(MermaidNode(id: node.id, label: node.text));
      for (final child in node.children) {
        edges.add(MermaidEdge(from: child.id, to: node.id));
        flatten(child);
      }
    }

    flatten(frozen);
    return (
      MermaidDiagramData(
        type: DiagramType.ishikawa,
        nodes: nodes,
        edges: edges,
        title: frozen.text,
      ),
      IshikawaChartData(effect: frozen),
    );
  }

  int _indent(String line) {
    var width = 0;
    for (final unit in line.codeUnits) {
      if (unit == 32) {
        width++;
      } else if (unit == 9) {
        width += 2;
      } else {
        break;
      }
    }
    return width;
  }
}

class _MutableIshikawaNode {
  _MutableIshikawaNode(this.id, this.text);
  final String id;
  final String text;
  final List<_MutableIshikawaNode> children = [];

  IshikawaNodeData freeze() => IshikawaNodeData(
    id: id,
    text: text,
    children: children.map((child) => child.freeze()).toList(),
  );
}
