/*
 * [INPUT]: Depends on native Mermaid graph models and Mermaid 11.16.0 ER, requirement, journey, and mindmap syntax conventions.
 * [OUTPUT]: Provides compatibility facades for strict ER and requirement parsers plus native journey and mindmap parsers.
 * [POS]: Serves as the shared parser family for structured official Mermaid diagram types represented by the native graph IR.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import 'er_diagram_parser.dart';
import 'journey_parser.dart';
import 'mindmap_parser.dart';
import 'requirement_diagram_parser.dart';

class ErDiagramParser {
  const ErDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeErDiagramParser().parse(lines)?.$1;
}

@Deprecated(
  'Use ErDiagramParser; retained temporarily for source compatibility.',
)
class LegacyErDiagramParser {
  const LegacyErDiagramParser();

  MermaidDiagramData? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    var direction = DiagramDirection.topToBottom;
    String? entity;

    for (final rawLine in lines.skip(1)) {
      final line = rawLine.trim();
      if (line.startsWith('direction ')) {
        direction = parseNativeDirection(line.substring(10));
        continue;
      }
      if (entity != null) {
        if (line == '}') entity = null;
        continue;
      }
      final declaration = RegExp(
        r'^("[^"]+"|[\w.-]+)(?:\s*:::[\w-]+)?(?:\s*\[([^\]]+)\])?\s*\{$',
      ).firstMatch(line);
      if (declaration != null) {
        final id = _unquote(declaration.group(1)!);
        nodes[id] = MermaidNode(
          id: id,
          label: _unquote(declaration.group(2) ?? id),
          shape: NodeShape.rectangle,
        );
        entity = id;
        continue;
      }
      if (line.startsWith('style ') || line.startsWith('classDef ')) {
        continue;
      }
      final compactRelation = RegExp(
        r'^("[^"]+"|[\w.-]+)([^\s]+(?:--|\.\.)[^\s]+?)("[^"]+"|[\w.-]+)\s*:\s*(.+)$',
      ).firstMatch(line);
      if (compactRelation != null) {
        final from = _unquote(compactRelation.group(1)!);
        final marker = compactRelation.group(2)!;
        final to = _unquote(compactRelation.group(3)!);
        nodes.putIfAbsent(from, () => MermaidNode(id: from, label: from));
        nodes.putIfAbsent(to, () => MermaidNode(id: to, label: to));
        edges.add(
          MermaidEdge(
            from: from,
            to: to,
            label: compactRelation.group(4)!.trim(),
            arrowType: ArrowType.none,
            lineType: marker.contains('..') ? LineType.dotted : LineType.solid,
          ),
        );
        continue;
      }
      final naturalRelation = RegExp(
        r'^("[^"]+"|[\w.-]+)\s+(.+?)\s+(?:optionally\s+)?to\s+(.+?)\s+("[^"]+"|[\w.-]+)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (naturalRelation != null) {
        final from = _unquote(naturalRelation.group(1)!);
        final to = _unquote(naturalRelation.group(4)!);
        nodes.putIfAbsent(from, () => MermaidNode(id: from, label: from));
        nodes.putIfAbsent(to, () => MermaidNode(id: to, label: to));
        edges.add(
          MermaidEdge(
            from: from,
            to: to,
            label: naturalRelation.group(5)!.trim(),
            arrowType: ArrowType.none,
          ),
        );
        continue;
      }
      final relation = RegExp(
        r'^("[^"]+"|[\w.-]+)\s+([^\s]+(?:--|\.\.)[^\s]+)\s+("[^"]+"|[\w.-]+)\s*:\s*(.+)$',
      ).firstMatch(line);
      if (relation != null) {
        final from = _unquote(relation.group(1)!);
        final marker = relation.group(2)!;
        final to = _unquote(relation.group(3)!);
        nodes.putIfAbsent(from, () => MermaidNode(id: from, label: from));
        nodes.putIfAbsent(to, () => MermaidNode(id: to, label: to));
        edges.add(
          MermaidEdge(
            from: from,
            to: to,
            label: _unquote(relation.group(4)!.trim()),
            arrowType: ArrowType.none,
            lineType: marker.contains('..') ? LineType.dotted : LineType.solid,
          ),
        );
        continue;
      }
      final single = RegExp(
        r'^("[^"]+"|[\w.-]+)(?:\s*:::[\w-]+)?$',
      ).firstMatch(line);
      if (single != null) {
        final id = _unquote(single.group(1)!);
        nodes.putIfAbsent(id, () => MermaidNode(id: id, label: id));
      }
    }
    return _graphResult(DiagramType.erDiagram, nodes, edges, direction);
  }
}

class RequirementDiagramParser {
  const RequirementDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeRequirementDiagramParser().parse(lines)?.$1;
}

@Deprecated(
  'Use RequirementDiagramParser; retained temporarily for source compatibility.',
)
class LegacyRequirementDiagramParser {
  const LegacyRequirementDiagramParser();

  MermaidDiagramData? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    var direction = DiagramDirection.topToBottom;
    String? openId;

    for (final rawLine in lines.skip(1)) {
      final line = rawLine.trim();
      if (line.startsWith('direction ')) {
        direction = parseNativeDirection(line.substring(10));
        continue;
      }
      if (openId != null) {
        final activeId = openId;
        if (line == '}') {
          openId = null;
        } else if (line.startsWith('text:')) {
          final text = _unquote(line.substring(5).trim());
          nodes[activeId] = MermaidNode(
            id: activeId,
            label: '${nodes[activeId]!.label}\n$text',
          );
        }
        continue;
      }
      final declaration = RegExp(
        r'^(requirement|functionalRequirement|interfaceRequirement|performanceRequirement|physicalRequirement|designConstraint|element)\s+([^\s{]+)\s*\{$',
      ).firstMatch(line);
      if (declaration != null) {
        final kind = declaration.group(1)!;
        final id = _unquote(declaration.group(2)!);
        openId = id;
        nodes[id] = MermaidNode(
          id: id,
          label: '$kind\n$id',
          shape: kind == 'element'
              ? NodeShape.roundedRect
              : NodeShape.rectangle,
        );
        continue;
      }
      final relation = RegExp(
        r'^([^\s]+)\s+-\s+(contains|copies|derives|satisfies|verifies|refines|traces)\s+->\s+([^\s]+)$',
      ).firstMatch(line);
      if (relation != null) {
        final from = _unquote(relation.group(1)!);
        final to = _unquote(relation.group(3)!);
        nodes.putIfAbsent(from, () => MermaidNode(id: from, label: from));
        nodes.putIfAbsent(to, () => MermaidNode(id: to, label: to));
        edges.add(MermaidEdge(from: from, to: to, label: relation.group(2)));
      }
    }
    return _graphResult(
      DiagramType.requirementDiagram,
      nodes,
      edges,
      direction,
    );
  }
}

class JourneyDiagramParser {
  const JourneyDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeJourneyDiagramParser().parse(lines)?.$1;
}

@Deprecated('Use JourneyDiagramParser; retained temporarily for compatibility.')
class LegacyJourneyDiagramParser {
  const LegacyJourneyDiagramParser();

  MermaidDiagramData? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    String? previous;
    var index = 0;
    var section = '';

    for (final rawLine in lines.skip(1)) {
      final line = rawLine.trim();
      if (line.startsWith('section ')) {
        section = line.substring(8).trim();
        continue;
      }
      if (line.startsWith('title ') || line.startsWith('acc')) continue;
      final task = RegExp(
        r'^(.+?)\s*:\s*([0-9]+)(?:\s*:\s*(.+))?$',
      ).firstMatch(line);
      if (task == null) continue;
      final id = 'journey_${index++}';
      final actors = task.group(3)?.trim();
      nodes[id] = MermaidNode(
        id: id,
        label: [
          if (section.isNotEmpty) section,
          task.group(1)!.trim(),
          '${task.group(2)}/5',
          if (actors != null && actors.isNotEmpty) actors,
        ].join('\n'),
        shape: NodeShape.roundedRect,
      );
      if (previous != null) edges.add(MermaidEdge(from: previous, to: id));
      previous = id;
    }
    return _graphResult(
      DiagramType.journey,
      nodes,
      edges,
      DiagramDirection.leftToRight,
    );
  }
}

class MindmapDiagramParser {
  const MindmapDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeMindmapDiagramParser().parse(lines)?.$1;
}

@Deprecated('Use MindmapDiagramParser; retained temporarily for compatibility.')
class LegacyMindmapDiagramParser {
  const LegacyMindmapDiagramParser();

  MermaidDiagramData? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    final parents = <int, String>{};
    var index = 0;

    for (final rawLine in lines.skip(1)) {
      if (rawLine.trim().isEmpty || rawLine.trimLeft().startsWith('::icon')) {
        continue;
      }
      final indent = rawLine.length - rawLine.trimLeft().length;
      final level = indent ~/ 2;
      final token = rawLine.trim();
      final parsed = _parseMindmapNode(token);
      final id = parsed.$1.isEmpty ? 'mindmap_${index++}' : parsed.$1;
      final uniqueId = nodes.containsKey(id) ? '${id}_${index++}' : id;
      nodes[uniqueId] = MermaidNode(
        id: uniqueId,
        label: parsed.$2,
        shape: parsed.$3,
      );
      final parent = parents[level - 1];
      if (parent != null) edges.add(MermaidEdge(from: parent, to: uniqueId));
      parents
        ..removeWhere((key, _) => key >= level)
        ..[level] = uniqueId;
    }
    return _graphResult(
      DiagramType.mindmap,
      nodes,
      edges,
      DiagramDirection.leftToRight,
    );
  }
}

(String, String, NodeShape) _parseMindmapNode(String token) {
  final shaped = <(RegExp, NodeShape)>[
    (RegExp(r'^([\w.-]*)\(\((.*)\)\)$'), NodeShape.circle),
    (RegExp(r'^([\w.-]*)\((.*)\)$'), NodeShape.roundedRect),
    (RegExp(r'^([\w.-]*)\[(.*)\]$'), NodeShape.rectangle),
    (RegExp(r'^([\w.-]*)\{(.*)\}$'), NodeShape.diamond),
  ];
  for (final candidate in shaped) {
    final match = candidate.$1.firstMatch(token);
    if (match != null) {
      return (match.group(1)!, _unquote(match.group(2)!.trim()), candidate.$2);
    }
  }
  return (
    token.replaceAll(RegExp(r'\W+'), '_'),
    _unquote(token),
    NodeShape.rectangle,
  );
}

MermaidDiagramData? _graphResult(
  DiagramType type,
  Map<String, MermaidNode> nodes,
  List<MermaidEdge> edges,
  DiagramDirection direction,
) {
  if (nodes.isEmpty) return null;
  return MermaidDiagramData(
    type: type,
    nodes: nodes.values.toList(),
    edges: edges,
    direction: direction,
  );
}

DiagramDirection parseNativeDirection(String value) {
  switch (value.trim().toUpperCase()) {
    case 'BT':
      return DiagramDirection.bottomToTop;
    case 'LR':
      return DiagramDirection.leftToRight;
    case 'RL':
      return DiagramDirection.rightToLeft;
    default:
      return DiagramDirection.topToBottom;
  }
}

String _unquote(String value) {
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    return value.substring(1, value.length - 1);
  }
  return value;
}
