/*
 * [INPUT]: Depends on dart:convert, native Mermaid graph models, and Mermaid 11.16.0 Sankey, Git Graph, Tree View, and Packet syntax conventions.
 * [OUTPUT]: Provides structural native parsers for weighted links, Git histories, trees, and contiguous Packet fields including empty diagrams and escaped labels.
 * [POS]: Serves as the parser family for official Mermaid types that normalize into nodes and directed edges.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';

import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/packet.dart';
import 'git_graph_parser.dart';
import 'sankey_parser.dart';
import 'tree_view_parser.dart';

class SankeyDiagramParser {
  const SankeyDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeSankeyDiagramParser().parse(lines)?.$1;
}

@Deprecated('Use SankeyDiagramParser; retained temporarily for compatibility.')
class LegacySankeyDiagramParser {
  const LegacySankeyDiagramParser();

  MermaidDiagramData? parse(List<String> lines) {
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    for (final rawLine in lines.skip(1)) {
      final fields = _csvFields(rawLine.trim());
      if (fields.length != 3 || double.tryParse(fields[2]) == null) continue;
      final from = fields[0];
      final to = fields[1];
      nodes.putIfAbsent(from, () => MermaidNode(id: from, label: from));
      nodes.putIfAbsent(to, () => MermaidNode(id: to, label: to));
      edges.add(MermaidEdge(from: from, to: to, label: fields[2]));
    }
    return _result(DiagramType.sankey, nodes, edges);
  }
}

class GitGraphDiagramParser {
  const GitGraphDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeGitGraphDiagramParser().parse(lines)?.$1;
}

@Deprecated(
  'Use GitGraphDiagramParser; retained temporarily for compatibility.',
)
class LegacyGitGraphDiagramParser {
  const LegacyGitGraphDiagramParser();

  MermaidDiagramData? parse(List<String> lines) {
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    final heads = <String, String?>{'main': null};
    var currentBranch = 'main';
    var generated = 0;

    for (final rawLine in lines.skip(1)) {
      final line = rawLine.trim();
      final branch = RegExp(r'^branch\s+("[^"]+"|\S+)').firstMatch(line);
      if (branch != null) {
        final name = _unquote(branch.group(1)!);
        heads[name] = heads[currentBranch];
        currentBranch = name;
        continue;
      }
      final checkout = RegExp(
        r'^(?:checkout|switch)\s+("[^"]+"|\S+)',
      ).firstMatch(line);
      if (checkout != null) {
        currentBranch = _unquote(checkout.group(1)!);
        heads.putIfAbsent(currentBranch, () => null);
        continue;
      }
      final commit = RegExp(r'^commit\b(.*)$').firstMatch(line);
      if (commit != null) {
        final tail = commit.group(1)!;
        final id = _attribute(tail, 'id') ?? 'commit_${generated++}';
        final message = _attribute(tail, 'msg');
        final tag = _attribute(tail, 'tag');
        nodes[id] = MermaidNode(
          id: id,
          label: [id, ?message, ?tag].join('\n'),
          shape: NodeShape.circle,
        );
        final parent = heads[currentBranch];
        if (parent != null) edges.add(MermaidEdge(from: parent, to: id));
        heads[currentBranch] = id;
        continue;
      }
      final merge = RegExp(r'^merge\s+("[^"]+"|\S+)(.*)$').firstMatch(line);
      if (merge != null) {
        final sourceBranch = _unquote(merge.group(1)!);
        final source = heads[sourceBranch];
        final target = heads[currentBranch];
        if (source == null || target == null) continue;
        final id = _attribute(merge.group(2)!, 'id') ?? 'merge_${generated++}';
        nodes[id] = MermaidNode(id: id, label: id, shape: NodeShape.circle);
        edges
          ..add(MermaidEdge(from: target, to: id))
          ..add(MermaidEdge(from: source, to: id));
        heads[currentBranch] = id;
      }
    }
    return _result(DiagramType.gitGraph, nodes, edges);
  }
}

class TreeViewDiagramParser {
  const TreeViewDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeTreeViewDiagramParser().parse(lines)?.$1;
}

@Deprecated(
  'Use TreeViewDiagramParser; retained temporarily for compatibility.',
)
class LegacyTreeViewDiagramParser {
  const LegacyTreeViewDiagramParser();

  MermaidDiagramData? parse(List<String> lines) {
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    final parents = <int, String>{};
    var generated = 0;
    for (final rawLine in lines.skip(1)) {
      if (rawLine.trim().isEmpty) continue;
      final expanded = rawLine.replaceFirst(RegExp(r'^[│ ]*[├└]──\s*'), '');
      final prefixLength = rawLine.length - rawLine.trimLeft().length;
      final boxDepth = RegExp(
        r'^[│ ]*[├└]──',
      ).firstMatch(rawLine)?.group(0)?.length;
      final level = boxDepth == null ? prefixLength ~/ 4 : boxDepth ~/ 4;
      final label = expanded.trim();
      final id = 'tree_${generated++}';
      nodes[id] = MermaidNode(
        id: id,
        label: label,
        shape: label.endsWith('/')
            ? NodeShape.roundedRect
            : NodeShape.rectangle,
      );
      final parent = parents[level - 1];
      if (parent != null) edges.add(MermaidEdge(from: parent, to: id));
      parents
        ..removeWhere((key, _) => key >= level)
        ..[level] = id;
    }
    return _result(DiagramType.treeView, nodes, edges);
  }
}

class PacketDiagramParser {
  const PacketDiagramParser();

  static const maxPacketBits = 10000;

  (MermaidDiagramData, PacketChartData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) {
      final value = line.trim().toLowerCase();
      return value == 'packet' || value == 'packet-beta';
    });
    if (header < 0) return null;
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    final fields = <PacketField>[];
    var nextBit = 0;
    String? previous;
    var index = 0;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var lineIndex = header + 1;
    while (lineIndex < lines.length) {
      final rawLine = lines[lineIndex++];
      final line = rawLine.trim();
      if (line.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (line.toLowerCase().startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (line.toLowerCase().startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
        final values = <String>[];
        var closed = false;
        while (lineIndex < lines.length) {
          final value = lines[lineIndex++].trim();
          if (value == '}') {
            closed = true;
            break;
          }
          values.add(value);
        }
        if (!closed) return null;
        accessibilityDescription = values.join('\n').trim();
        continue;
      }
      if (line == '---') continue;
      final field = RegExp(
        r'^(?:(\d+)(?:-(\d+))?|\+(\d+))\s*:\s*("(?:\\.|[^"\\])*")$',
      ).firstMatch(line);
      if (field == null) return null;
      late final int start;
      late final int end;
      final relative = field.group(3) != null;
      if (field.group(3) != null) {
        final count = int.parse(field.group(3)!);
        if (count <= 0) return null;
        start = nextBit;
        end = start + count - 1;
      } else {
        start = int.parse(field.group(1)!);
        end = int.parse(field.group(2) ?? field.group(1)!);
        if (end < start || start != nextBit) return null;
      }
      if (end >= maxPacketBits) return null;
      late final String label;
      try {
        final decoded = jsonDecode(field.group(4)!);
        if (decoded is! String) return null;
        label = decoded;
      } on FormatException {
        return null;
      }
      nextBit = end + 1;
      fields.add(
        PacketField(
          start: start,
          end: end,
          label: label,
          relative: relative,
          declaredStart: int.tryParse(field.group(1) ?? ''),
          declaredEnd: int.tryParse(field.group(2) ?? ''),
          declaredBits: int.tryParse(field.group(3) ?? ''),
        ),
      );
      final id = 'packet_${index++}';
      nodes[id] = MermaidNode(id: id, label: '$start–$end\n$label');
      if (previous != null) {
        edges.add(
          MermaidEdge(from: previous, to: id, arrowType: ArrowType.none),
        );
      }
      previous = id;
    }
    final diagram = MermaidDiagramData(
      type: DiagramType.packet,
      nodes: nodes.values.toList(),
      edges: edges,
      direction: DiagramDirection.leftToRight,
    );
    return (
      diagram.copyWith(title: title),
      PacketChartData(
        fields: fields,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }
}

MermaidDiagramData? _result(
  DiagramType type,
  Map<String, MermaidNode> nodes,
  List<MermaidEdge> edges,
) {
  if (nodes.isEmpty) return null;
  return MermaidDiagramData(
    type: type,
    nodes: nodes.values.toList(),
    edges: edges,
    direction: DiagramDirection.leftToRight,
  );
}

List<String> _csvFields(String input) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var index = 0; index < input.length; index++) {
    final char = input[index];
    if (char == '"') {
      if (quoted && index + 1 < input.length && input[index + 1] == '"') {
        buffer.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      fields.add(buffer.toString().trim());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString().trim());
  return fields;
}

String? _attribute(String input, String name) {
  return RegExp(
    '$name\\s*:\\s*"([^"]*)"',
    caseSensitive: false,
  ).firstMatch(input)?.group(1);
}

String _unquote(String value) => value.startsWith('"') && value.endsWith('"')
    ? value.substring(1, value.length - 1)
    : value;
