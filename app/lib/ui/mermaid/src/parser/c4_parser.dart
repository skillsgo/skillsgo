/*
 * [INPUT]: Depends on Mermaid 11.16.0 C4 call syntax and shared native diagram, node, edge, style, subgraph, and C4 models.
 * [OUTPUT]: Parses five C4 variants, elements, nested boundaries, relationships, titles, element/relationship styles, and layout row configuration.
 * [POS]: Serves as the dedicated native parser for Mermaid's C4-PlantUML-compatible diagram family.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/c4.dart';
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';

class C4DiagramParser {
  const C4DiagramParser();

  (MermaidDiagramData, C4ChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final kind = _kind(lines.first.trim());
    if (kind == null) return null;
    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];
    final elements = <C4ElementData>[];
    final boundaryData = <C4BoundaryData>[];
    final relationData = <C4RelationData>[];
    final layoutHints = <String>[];
    final boundaries = <Subgraph>[];
    final stack = <_Boundary>[];
    var shapesPerRow = 4;
    var boundariesPerRow = 2;
    var layoutConfigured = false;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var direction = 'TB';
    var expectingBrace = false;

    for (var lineIndex = 1; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex].trim();
      if (line.isEmpty) continue;
      if (expectingBrace) {
        if (line != '{') return null;
        expectingBrace = false;
        continue;
      }
      if (line.startsWith('%%')) continue;
      final directionMatch = RegExp(
        r'^direction\s+(TB|BT|LR|RL)$',
      ).firstMatch(line);
      if (directionMatch != null) {
        direction = directionMatch.group(1)!;
        continue;
      }
      if (line.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('accTitle:')) {
        accessibilityTitle = line.substring('accTitle:'.length).trim();
        continue;
      }
      if (line.startsWith('accDescription ')) {
        accessibilityDescription = line
            .substring('accDescription '.length)
            .trim();
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
        final parts = <String>[];
        var closed = false;
        while (++lineIndex < lines.length) {
          final part = lines[lineIndex].trim();
          if (part == '}') {
            closed = true;
            break;
          }
          if (part.isNotEmpty) parts.add(part);
        }
        if (!closed) return null;
        accessibilityDescription = parts.join('\n');
        continue;
      }
      if (line == '}') {
        if (stack.isEmpty) return null;
        final boundary = stack.removeLast();
        boundaries.add(
          Subgraph(
            id: boundary.id,
            label: boundary.label,
            nodeIds: List.unmodifiable(boundary.nodeIds),
          ),
        );
        continue;
      }
      final call = _call(line);
      if (call == null) return null;
      final name = call.$1;
      final args = call.$2;
      if (_boundaryNames.contains(name)) {
        if (args.length < 2) return null;
        final parent = stack.isEmpty ? null : stack.last.id;
        final stereotype = _boundaryStereotype(name, args);
        final boundary = _Boundary(args[0].value, args[1].value, parent);
        stack.add(boundary);
        boundaryData.add(
          C4BoundaryData(
            id: boundary.id,
            label: boundary.label,
            stereotype: stereotype,
            description: name.startsWith('Node') || name == 'Deployment_Node'
                ? _argument(args, 3, 'descr')
                : null,
            tags: _argument(args, name.startsWith('Node') ? 5 : 3, 'tags'),
            link: _argument(args, name.startsWith('Node') ? 6 : 4, 'link'),
            parentBoundaryId: parent,
            nodeType: name == 'Node_L'
                ? 'nodeL'
                : name == 'Node_R'
                ? 'nodeR'
                : name == 'Node' || name == 'Deployment_Node'
                ? 'node'
                : null,
          ),
        );
        expectingBrace = !line.endsWith('{');
        continue;
      }
      if (_elementNames.contains(name)) {
        if (args.isEmpty || args[0].value.isEmpty) return null;
        final id = args[0].value;
        final label = args.length > 1 && args[1].value.isNotEmpty
            ? args[1].value
            : id;
        final containerLike =
            name.startsWith('Container') || name.startsWith('Component');
        final technology = containerLike ? _argument(args, 2, 'techn') : null;
        final description = _argument(args, containerLike ? 3 : 2, 'descr');
        final sprite = _argument(args, containerLike ? 4 : 3, 'sprite');
        final tags = _argument(args, containerLike ? 5 : 4, 'tags');
        final link = _argument(args, containerLike ? 6 : 5, 'link');
        final details = [
          if (technology != null && technology.isNotEmpty) '[$technology]',
          if (description != null && description.isNotEmpty) description,
        ].join('\n');
        nodes[id] = MermaidNode(
          id: id,
          label: details.isEmpty ? label : '$label\n$details',
          shape: _shape(name),
          link: link,
        );
        elements.removeWhere((element) => element.id == id);
        elements.add(
          C4ElementData(
            id: id,
            stereotype: _elementStereotype(name),
            label: label,
            technology: technology,
            description: description,
            sprite: sprite,
            tags: tags,
            link: link,
            parentBoundaryId: stack.isEmpty ? null : stack.last.id,
          ),
        );
        for (final boundary in stack) {
          if (!boundary.nodeIds.contains(id)) boundary.nodeIds.add(id);
        }
        continue;
      }
      if (_relationNames.contains(name)) {
        final offset = name == 'RelIndex' ? 1 : 0;
        if (args.length < offset + 3) return null;
        final technology = _argument(args, offset + 3, 'techn') ?? '';
        final relation = C4RelationData(
          from: args[offset].value,
          to: args[offset + 1].value,
          label: args[offset + 2].value,
          technology: technology,
          description: _argument(args, offset + 4, 'descr'),
          sprite: _argument(args, offset + 5, 'sprite'),
          tags: _argument(args, offset + 6, 'tags'),
          link: _argument(args, offset + 7, 'link'),
          direction: _relationDirection(name),
          bidirectional: name == 'BiRel',
          index: name == 'RelIndex' ? int.tryParse(args.first.value) : null,
        );
        relationData.removeWhere(
          (candidate) =>
              candidate.from == relation.from && candidate.to == relation.to,
        );
        relationData.add(relation);
        edges.add(
          MermaidEdge(
            from: args[offset].value,
            to: args[offset + 1].value,
            label: technology.isEmpty
                ? args[offset + 2].value
                : '${args[offset + 2].value}\n[$technology]',
            bidirectional: name == 'BiRel',
          ),
        );
        continue;
      }
      if (name == 'UpdateElementStyle') {
        if (args.isEmpty) return null;
        final node = nodes[args[0].value];
        if (node != null) {
          nodes[args[0].value] = node.copyWith(
            style: NodeStyle(
              fillColor: _color(_argument(args, 1, 'bgColor')),
              strokeColor: _color(_argument(args, 3, 'borderColor')),
              textColor: _color(_argument(args, 2, 'fontColor')),
            ),
          );
        }
        final index = elements.indexWhere(
          (element) => element.id == args[0].value,
        );
        if (index >= 0) {
          elements[index] = elements[index].copyWith(
            style: C4StyleData(
              backgroundColor: _argument(args, 1, 'bgColor'),
              fontColor: _argument(args, 2, 'fontColor'),
              borderColor: _argument(args, 3, 'borderColor'),
              shadowing: _boolean(_argument(args, 4, 'shadowing')),
              shape: _argument(args, 5, 'shape'),
              sprite: _argument(args, 6, 'sprite'),
              technology: _argument(args, 7, 'techn'),
              legendText: _argument(args, 8, 'legendText'),
              legendSprite: _argument(args, 9, 'legendSprite'),
            ),
          );
        }
        final boundaryIndex = boundaryData.indexWhere(
          (boundary) => boundary.id == args[0].value,
        );
        if (boundaryIndex >= 0) {
          boundaryData[boundaryIndex] = boundaryData[boundaryIndex].copyWith(
            style: C4StyleData(
              backgroundColor: _argument(args, 1, 'bgColor'),
              fontColor: _argument(args, 2, 'fontColor'),
              borderColor: _argument(args, 3, 'borderColor'),
              shadowing: _boolean(_argument(args, 4, 'shadowing')),
              shape: _argument(args, 5, 'shape'),
              sprite: _argument(args, 6, 'sprite'),
              technology: _argument(args, 7, 'techn'),
              legendText: _argument(args, 8, 'legendText'),
              legendSprite: _argument(args, 9, 'legendSprite'),
            ),
          );
        }
        continue;
      }
      if (name == 'UpdateRelStyle') {
        if (args.length < 2) return null;
        final index = relationData.indexWhere(
          (relation) =>
              relation.from == args[0].value && relation.to == args[1].value,
        );
        if (index >= 0) {
          final old = relationData[index];
          relationData[index] = C4RelationData(
            from: old.from,
            to: old.to,
            label: old.label,
            technology: old.technology,
            description: old.description,
            sprite: old.sprite,
            tags: old.tags,
            link: old.link,
            direction: old.direction,
            bidirectional: old.bidirectional,
            index: old.index,
            textColor: _argument(args, 2, 'textColor'),
            lineColor: _argument(args, 3, 'lineColor'),
            offsetX: double.tryParse(_argument(args, 4, 'offsetX') ?? '') ?? 0,
            offsetY: double.tryParse(_argument(args, 5, 'offsetY') ?? '') ?? 0,
          );
        }
        continue;
      }
      if (name == 'UpdateLayoutConfig') {
        layoutConfigured = true;
        shapesPerRow =
            int.tryParse(_argument(args, 0, 'c4ShapeInRow') ?? '') ??
            shapesPerRow;
        boundariesPerRow =
            int.tryParse(_argument(args, 1, 'c4BoundaryInRow') ?? '') ??
            boundariesPerRow;
        continue;
      }
      if (name.startsWith('Lay_')) {
        layoutHints.add(line);
        continue;
      }
      return null;
    }
    if (stack.isNotEmpty || expectingBrace || nodes.isEmpty) return null;
    return (
      MermaidDiagramData(
        type: DiagramType.c4,
        nodes: nodes.values.toList(),
        edges: edges,
        subgraphs: boundaries,
        title: title,
      ),
      C4ChartData(
        kind: kind,
        elements: elements,
        boundaries: boundaryData,
        relations: relationData,
        layoutHints: layoutHints,
        direction: direction,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
        shapesPerRow: shapesPerRow.clamp(1, 12),
        boundariesPerRow: boundariesPerRow.clamp(1, 8),
        layoutConfigured: layoutConfigured,
      ),
    );
  }

  C4DiagramKind? _kind(String value) => switch (value.toLowerCase()) {
    'c4context' => C4DiagramKind.context,
    'c4container' => C4DiagramKind.container,
    'c4component' => C4DiagramKind.component,
    'c4dynamic' => C4DiagramKind.dynamic,
    'c4deployment' => C4DiagramKind.deployment,
    _ => null,
  };

  (String, List<_Argument>)? _call(String line) {
    final match = RegExp(
      r'^([A-Za-z_][\w]*)\s*\((.*)\)\s*\{?\s*$',
    ).firstMatch(line);
    if (match == null) return null;
    return (match.group(1)!, _arguments(match.group(2)!));
  }

  List<_Argument> _arguments(String source) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == '"' && (i == 0 || source[i - 1] != r'\')) quoted = !quoted;
      if (char == ',' && !quoted) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString());
    return values.map((raw) {
      final match = RegExp(r'^\s*\$([\w]+)\s*=\s*(.*)$').firstMatch(raw);
      final value = match?.group(2) ?? raw;
      return _Argument(match?.group(1), _unquote(value.trim()));
    }).toList();
  }

  String _unquote(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1).replaceAll(r'\"', '"');
    }
    return value;
  }

  String? _named(List<_Argument> args, String name) {
    for (final arg in args) {
      if (arg.name?.toLowerCase() == name.toLowerCase()) return arg.value;
    }
    return null;
  }

  String? _argument(List<_Argument> args, int index, String name) {
    final named = _named(args, name);
    if (named != null) return named;
    if (index >= args.length || args[index].name != null) return null;
    return args[index].value;
  }

  bool? _boolean(String? value) => switch (value?.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  String _elementStereotype(String name) {
    final external = name.endsWith('_Ext');
    final base = name.replaceFirst('_Ext', '');
    final snake = base
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => '_')
        .toLowerCase();
    return external ? 'external_$snake' : snake;
  }

  String _boundaryStereotype(String name, List<_Argument> args) =>
      switch (name) {
        'Enterprise_Boundary' => 'enterprise',
        'System_Boundary' => 'system',
        'Container_Boundary' => 'container',
        'Node' ||
        'Node_L' ||
        'Node_R' ||
        'Deployment_Node' => _argument(args, 2, 'type') ?? 'node',
        _ => _argument(args, 2, 'type') ?? 'system',
      };

  C4RelationDirection _relationDirection(String name) => switch (name) {
    'Rel_U' || 'Rel_Up' => C4RelationDirection.up,
    'Rel_D' || 'Rel_Down' => C4RelationDirection.down,
    'Rel_L' || 'Rel_Left' => C4RelationDirection.left,
    'Rel_R' || 'Rel_Right' => C4RelationDirection.right,
    'Rel_Back' => C4RelationDirection.back,
    _ => C4RelationDirection.automatic,
  };

  NodeShape _shape(String name) {
    if (name.toLowerCase().contains('db')) return NodeShape.cylinder;
    if (name.toLowerCase().contains('queue')) return NodeShape.roundedRect;
    if (name.toLowerCase().startsWith('person')) return NodeShape.stadium;
    if (name.toLowerCase().startsWith('node')) return NodeShape.hexagon;
    return NodeShape.rectangle;
  }

  int? _color(String? value) {
    if (value == null) return null;
    final named = <String, int>{
      'red': 0xFFF44336,
      'blue': 0xFF2196F3,
      'green': 0xFF4CAF50,
      'grey': 0xFF9E9E9E,
      'gray': 0xFF9E9E9E,
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
    }[value.toLowerCase()];
    if (named != null) return named;
    final hex = value.replaceFirst('#', '');
    if (hex.length == 6) return int.tryParse('FF$hex', radix: 16);
    return null;
  }

  static const _boundaryNames = {
    'Boundary',
    'Enterprise_Boundary',
    'System_Boundary',
    'Container_Boundary',
    'Deployment_Node',
    'Node',
    'Node_L',
    'Node_R',
  };
  static const _elementNames = {
    'Person',
    'Person_Ext',
    'System',
    'SystemDb',
    'SystemQueue',
    'System_Ext',
    'SystemDb_Ext',
    'SystemQueue_Ext',
    'Container',
    'ContainerDb',
    'ContainerQueue',
    'Container_Ext',
    'ContainerDb_Ext',
    'ContainerQueue_Ext',
    'Component',
    'ComponentDb',
    'ComponentQueue',
    'Component_Ext',
    'ComponentDb_Ext',
    'ComponentQueue_Ext',
  };
  static const _relationNames = {
    'Rel',
    'BiRel',
    'Rel_U',
    'Rel_Up',
    'Rel_D',
    'Rel_Down',
    'Rel_L',
    'Rel_Left',
    'Rel_R',
    'Rel_Right',
    'Rel_Back',
    'RelIndex',
  };
}

class _Argument {
  const _Argument(this.name, this.value);
  final String? name;
  final String value;
}

class _Boundary {
  _Boundary(this.id, this.label, this.parentId);
  final String id;
  final String label;
  final String? parentId;
  final List<String> nodeIds = [];
}
