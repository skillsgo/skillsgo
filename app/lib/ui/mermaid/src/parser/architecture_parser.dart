/*
 * [INPUT]: Depends on Mermaid 11.16.0 Architecture grammar and native graph/Architecture models.
 * [OUTPUT]: Parses titles, groups, services, icons, junctions, directional labeled edges, group-boundary modifiers, arrows, and row/column alignments.
 * [POS]: Serves as the dedicated native parser for architecture-beta diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/architecture.dart';
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';

class ArchitectureDiagramParser {
  const ArchitectureDiagramParser();

  (MermaidDiagramData, ArchitectureChartData)? parse(List<String> lines) {
    if (lines.isEmpty ||
        !lines.first.trim().toLowerCase().startsWith('architecture-beta')) {
      return null;
    }
    final nodes = <String, MermaidNode>{};
    final groups = <String, _Group>{};
    final items = <ArchitectureItemData>[];
    final graphEdges = <MermaidEdge>[];
    final architectureEdges = <ArchitectureEdgeData>[];
    final alignments = <ArchitectureAlignmentData>[];
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    final header = lines.first.trim();
    if (header.length > 'architecture-beta'.length) {
      final suffix = header.substring('architecture-beta'.length).trim();
      if (!suffix.startsWith('title ')) return null;
      title = suffix.substring(6).trim();
    }

    for (var lineIndex = 1; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex].trim();
      if (line.isEmpty) continue;
      if (line.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('accTitle:')) {
        accessibilityTitle = line.substring('accTitle:'.length).trim();
        continue;
      }
      if (line.startsWith('accDescr:')) {
        accessibilityDescription = line.substring('accDescr:'.length).trim();
        continue;
      }
      final inlineDescription = RegExp(
        r'^accDescr\s*\{(.*)\}$',
      ).firstMatch(line);
      if (inlineDescription != null) {
        accessibilityDescription = inlineDescription.group(1)!.trim();
        continue;
      }
      if (line == 'accDescr {') {
        final description = <String>[];
        var closed = false;
        while (++lineIndex < lines.length) {
          final part = lines[lineIndex].trim();
          if (part == '}') {
            closed = true;
            break;
          }
          if (part.isNotEmpty) description.add(part);
        }
        if (!closed) return null;
        accessibilityDescription = description.join('\n');
        continue;
      }
      final declaration = RegExp(
        r'^(group|service)\s+([A-Za-z_][\w-]*)(?:\(([^)]+)\)|\s+"([^"]+)")?(?:\[((?:[^\]\\]|\\.)*)\])?(?:\s+in\s+([A-Za-z_][\w-]*))?$',
      ).firstMatch(line);
      if (declaration != null) {
        final kind = declaration.group(1)!;
        final id = declaration.group(2)!;
        if (const {'align', 'row', 'column'}.contains(id)) return null;
        final icon = declaration.group(3) ?? declaration.group(4);
        final label = _unquote(declaration.group(5) ?? id);
        final parent = declaration.group(6);
        if (nodes.containsKey(id) || groups.containsKey(id)) return null;
        if (parent != null && !groups.containsKey(parent)) return null;
        if (kind == 'group') {
          groups[id] = _Group(id, label, icon, parent);
        } else {
          final shape = switch (icon?.toLowerCase()) {
            'database' => NodeShape.cylinder,
            'disk' => NodeShape.subroutine,
            'cloud' || 'internet' => NodeShape.roundedRect,
            _ => NodeShape.rectangle,
          };
          nodes[id] = MermaidNode(id: id, label: label, shape: shape);
          items.add(ArchitectureItemData(id: id, icon: icon, parentId: parent));
          _addToGroups(id, parent, groups);
        }
        continue;
      }
      final junction = RegExp(
        r'^junction\s+([A-Za-z_][\w-]*)(?:\s+in\s+([A-Za-z_][\w-]*))?$',
      ).firstMatch(line);
      if (junction != null) {
        final id = junction.group(1)!;
        if (const {'align', 'row', 'column'}.contains(id)) return null;
        final parent = junction.group(2);
        if (nodes.containsKey(id) || groups.containsKey(id)) return null;
        if (parent != null && !groups.containsKey(parent)) return null;
        nodes[id] = MermaidNode(id: id, label: '', shape: NodeShape.circle);
        items.add(
          ArchitectureItemData(id: id, parentId: parent, isJunction: true),
        );
        _addToGroups(id, parent, groups);
        continue;
      }
      final alignment = RegExp(
        r'^align\s+(row|column)\s+(.+)$',
      ).firstMatch(line);
      if (alignment != null) {
        final members = alignment.group(2)!.split(RegExp(r'\s+'));
        if (members.length < 2 ||
            members.toSet().length != members.length ||
            members.any((id) => !nodes.containsKey(id))) {
          return null;
        }
        alignments.add(
          ArchitectureAlignmentData(
            axis: alignment.group(1) == 'row'
                ? ArchitectureAlignmentAxis.row
                : ArchitectureAlignmentAxis.column,
            members: members,
          ),
        );
        continue;
      }
      final edge = RegExp(
        r'^([A-Za-z_][\w-]*)(\{group\})?:([LRBT])\s*(<)?-(?:\[([^\]]+)\])?-(>)?\s*([LRBT]):([A-Za-z_][\w-]*)(\{group\})?$',
      ).firstMatch(line);
      if (edge != null) {
        final from = edge.group(1)!;
        final to = edge.group(8)!;
        if ((!nodes.containsKey(from) && !groups.containsKey(from)) ||
            (!nodes.containsKey(to) && !groups.containsKey(to))) {
          return null;
        }
        String? parentOf(String id) {
          for (final item in items) {
            if (item.id == id) return item.parentId;
          }
          return groups[id]?.parentId;
        }

        final fromParent = parentOf(from);
        final toParent = parentOf(to);
        if ((edge.group(2) != null || edge.group(9) != null) &&
            fromParent != null &&
            fromParent == toParent) {
          return null;
        }
        final metadata = ArchitectureEdgeData(
          from: from,
          to: to,
          fromPort: _port(edge.group(3)!),
          toPort: _port(edge.group(7)!),
          fromGroup: edge.group(2) != null,
          toGroup: edge.group(9) != null,
          arrowAtStart: edge.group(4) != null,
          arrowAtEnd: edge.group(6) != null,
          label: edge.group(5),
        );
        architectureEdges.add(metadata);
        graphEdges.add(
          MermaidEdge(
            from: from,
            to: to,
            label: metadata.label,
            arrowType: metadata.arrowAtEnd ? ArrowType.arrow : ArrowType.none,
            bidirectional: metadata.arrowAtStart && metadata.arrowAtEnd,
          ),
        );
        continue;
      }
      return null;
    }
    return (
      MermaidDiagramData(
        type: DiagramType.architecture,
        nodes: nodes.values.toList(),
        edges: graphEdges,
        subgraphs: groups.values
            .map(
              (group) => Subgraph(
                id: group.id,
                label: group.label,
                nodeIds: group.nodeIds,
              ),
            )
            .toList(),
        title: title,
      ),
      ArchitectureChartData(
        items: items,
        groups: groups.values
            .map(
              (group) => ArchitectureGroupData(
                id: group.id,
                label: group.label,
                icon: group.icon,
                parentId: group.parentId,
              ),
            )
            .toList(),
        edges: architectureEdges,
        alignments: alignments,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  void _addToGroups(String id, String? parent, Map<String, _Group> groups) {
    var current = parent;
    while (current != null) {
      final group = groups[current]!;
      group.nodeIds.add(id);
      current = group.parentId;
    }
  }

  ArchitecturePort _port(String value) => switch (value) {
    'L' => ArchitecturePort.left,
    'R' => ArchitecturePort.right,
    'T' => ArchitecturePort.top,
    _ => ArchitecturePort.bottom,
  };

  String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}

class _Group {
  _Group(this.id, this.label, this.icon, this.parentId);
  final String id;
  final String label;
  final String? icon;
  final String? parentId;
  final List<String> nodeIds = [];
}
