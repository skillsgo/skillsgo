/*
 * [INPUT]: Depends on Mermaid 11.16.0 Wardley DSL and native graph/Wardley models.
 * [OUTPUT]: Parses size, accessibility metadata, stages, anchors, components, offsets, decorators, inertia, links, evolution, pipelines, notes, annotations, accelerators, and deaccelerators.
 * [POS]: Serves as the dedicated native parser for wardley-beta strategic maps.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/wardley.dart';

class WardleyDiagramParser {
  const WardleyDiagramParser();

  (MermaidDiagramData, WardleyChartData)? parse(List<String> lines) {
    if (lines.isEmpty || lines.first.trim().toLowerCase() != 'wardley-beta') {
      return null;
    }
    final components = <WardleyComponentData>[];
    final links = <WardleyLinkData>[];
    final evolutions = <WardleyEvolutionData>[];
    var stages = const <WardleyStage>[
      WardleyStage(name: 'Genesis', boundary: .25),
      WardleyStage(name: 'Custom Built', boundary: .5),
      WardleyStage(name: 'Product', boundary: .75),
      WardleyStage(name: 'Commodity', boundary: 1),
    ];
    final notes = <WardleyNoteData>[];
    final annotations = <WardleyAnnotationData>[];
    final forces = <WardleyForceData>[];
    String? title;
    String? pipelineParent;
    var width = 900.0;
    var height = 600.0;
    var hasExplicitSize = false;
    double? annotationBoxX;
    double? annotationBoxY;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var readingDescription = false;
    final descriptionLines = <String>[];

    for (final raw in lines.skip(1)) {
      final line = _stripComment(raw).trim();
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
      if (line == '}') {
        if (pipelineParent == null) return null;
        pipelineParent = null;
        continue;
      }
      if (line.startsWith('title ')) {
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
      final size = RegExp(
        r'^size\s*\[\s*(\d+)\s*,\s*(\d+)\s*\]$',
      ).firstMatch(line);
      if (size != null) {
        width = double.parse(size.group(1)!);
        height = double.parse(size.group(2)!);
        hasExplicitSize = true;
        if (width <= 0 || height <= 0) return null;
        continue;
      }
      if (line.startsWith('evolution ')) {
        final parsed = line
            .substring(10)
            .split(RegExp(r'\s*->\s*'))
            .map(_stage)
            .toList();
        if (parsed.any((stage) => stage == null)) return null;
        stages = parsed.cast<WardleyStage>();
        continue;
      }
      final pipeline = RegExp(r'^pipeline\s+(.+?)\s*\{$').firstMatch(line);
      if (pipeline != null) {
        final parent = _name(pipeline.group(1)!);
        if (_resolveComponent(parent, components) == null) {
          return null;
        }
        pipelineParent = _resolveComponent(parent, components)!.id;
        continue;
      }
      if (line.startsWith('anchor ') || line.startsWith('component ')) {
        final anchor = line.startsWith('anchor ');
        final body = line.substring(anchor ? 7 : 10);
        final coordinate = RegExp(
          r'^(.*?)\s*\[\s*([0-9]+(?:\.[0-9]+)?)\s*,\s*([0-9]+(?:\.[0-9]+)?)\s*\](.*)$',
        ).firstMatch(body);
        final pipelineCoordinate = pipelineParent == null
            ? null
            : RegExp(
                r'^(.*?)\s*\[\s*([0-9]+(?:\.[0-9]+)?)\s*\](.*)$',
              ).firstMatch(body);
        if (coordinate == null && pipelineCoordinate == null) return null;
        final name = _name((coordinate ?? pipelineCoordinate)!.group(1)!);
        final id = pipelineParent == null ? name : '${pipelineParent}_$name';
        if (components.any((component) => component.id == id)) return null;
        final parent = pipelineParent == null
            ? null
            : components.firstWhere(
                (component) => component.id == pipelineParent,
              );
        final visibilitySource = coordinate == null
            ? parent!.visibility
            : double.parse(coordinate.group(2)!);
        final evolutionSource = double.parse(
          coordinate?.group(3) ?? pipelineCoordinate!.group(2)!,
        );
        final visibility = coordinate == null
            ? visibilitySource
            : _coordinate(visibilitySource);
        final evolution = _coordinate(evolutionSource);
        if (visibility == null || evolution == null) return null;
        final suffix = coordinate?.group(4) ?? pipelineCoordinate!.group(3)!;
        final label = RegExp(
          r'label\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*\]',
        ).firstMatch(suffix);
        final strategyMatch = RegExp(
          r'\((build|buy|outsource|market)\)',
        ).firstMatch(suffix);
        final inertia = RegExp(r'(?:\(|\b)inertia(?:\)|\b)').hasMatch(suffix);
        components.add(
          WardleyComponentData(
            id: id,
            name: name,
            visibility: visibility,
            evolution: evolution,
            isAnchor: anchor,
            labelOffsetX: double.tryParse(label?.group(1) ?? '') ?? 8,
            labelOffsetY: double.tryParse(label?.group(2) ?? '') ?? -12,
            hasLabelOffset: label != null,
            strategy: strategyMatch == null
                ? null
                : WardleyStrategy.values.byName(strategyMatch.group(1)!),
            inertia: inertia,
            pipelineParent: pipelineParent,
          ),
        );
        continue;
      }
      final evolve = RegExp(
        r'^evolve\s+(.+?)\s+([0-9]+(?:\.[0-9]+)?)$',
      ).firstMatch(line);
      if (evolve != null) {
        final name = _name(evolve.group(1)!);
        final target = _coordinate(double.parse(evolve.group(2)!));
        final component = _resolveComponent(name, components);
        if (component == null || target == null) {
          return null;
        }
        evolutions.add(
          WardleyEvolutionData(component: component.id, target: target),
        );
        continue;
      }
      final note = RegExp(
        r'^note\s+"((?:[^"\\]|\\.)*)"\s*\[\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\]$',
      ).firstMatch(line);
      if (note != null) {
        final visibility = _coordinate(double.parse(note.group(2)!));
        final evolution = _coordinate(double.parse(note.group(3)!));
        if (visibility == null || evolution == null) return null;
        notes.add(
          WardleyNoteData(
            text: note.group(1)!,
            visibility: visibility,
            evolution: evolution,
          ),
        );
        continue;
      }
      final annotationBox = RegExp(
        r'^annotations\s*\[\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\]$',
      ).firstMatch(line);
      if (annotationBox != null) {
        annotationBoxX = _coordinate(double.parse(annotationBox.group(1)!));
        annotationBoxY = _coordinate(double.parse(annotationBox.group(2)!));
        if (annotationBoxX == null || annotationBoxY == null) {
          return null;
        }
        continue;
      }
      final annotation = RegExp(
        r'^annotation\s+(\d+)\s*,\s*\[\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\]\s*"((?:[^"\\]|\\.)*)"$',
      ).firstMatch(line);
      if (annotation != null) {
        final x = _coordinate(double.parse(annotation.group(2)!));
        final y = _coordinate(double.parse(annotation.group(3)!));
        if (x == null || y == null) return null;
        annotations.add(
          WardleyAnnotationData(
            number: int.parse(annotation.group(1)!),
            x: x,
            y: y,
            text: annotation.group(4)!,
          ),
        );
        continue;
      }
      final force = RegExp(
        r'^(accelerator|deaccelerator)\s+(.+?)\s*\[\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\]$',
      ).firstMatch(line);
      if (force != null) {
        final x = _coordinate(double.parse(force.group(3)!));
        final y = _coordinate(double.parse(force.group(4)!));
        if (x == null || y == null) return null;
        forces.add(
          WardleyForceData(
            kind: force.group(1) == 'accelerator'
                ? WardleyForceKind.accelerator
                : WardleyForceKind.deaccelerator,
            name: _name(force.group(2)!),
            x: x,
            y: y,
          ),
        );
        continue;
      }
      final parsedLink = _link(line, components);
      if (parsedLink == null) return null;
      links.add(parsedLink);
    }
    if (pipelineParent != null || readingDescription) return null;
    final graphNodes = components
        .map(
          (component) => MermaidNode(id: component.id, label: component.name),
        )
        .toList();
    final graphEdges = links
        .map(
          (link) => MermaidEdge(
            from: link.from,
            to: link.to,
            label: link.label,
            bidirectional: link.kind == WardleyLinkKind.bidirectional,
            lineType: link.kind == WardleyLinkKind.dashed
                ? LineType.dotted
                : LineType.solid,
          ),
        )
        .toList();
    return (
      MermaidDiagramData(
        type: DiagramType.wardley,
        nodes: graphNodes,
        edges: graphEdges,
        title: title,
      ),
      WardleyChartData(
        components: components,
        links: links,
        evolutions: evolutions,
        stages: stages,
        notes: notes,
        annotations: annotations,
        forces: forces,
        width: width,
        height: height,
        annotationBoxX: annotationBoxX,
        annotationBoxY: annotationBoxY,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
        hasExplicitSize: hasExplicitSize,
      ),
    );
  }

  WardleyStage? _stage(String source) {
    final match = RegExp(
      r'^(.*?)(?:@([0-9.]+))?(?:\s*/\s*(.+))?$',
    ).firstMatch(source.trim());
    if (match == null) return null;
    final boundarySource = double.tryParse(match.group(2) ?? '');
    final boundary = boundarySource == null
        ? null
        : _coordinate(boundarySource);
    if (boundarySource != null && boundary == null) return null;
    return WardleyStage(
      name: _name(match.group(1)!),
      boundary: boundary,
      secondName: match.group(3) == null ? null : _name(match.group(3)!),
    );
  }

  WardleyLinkData? _link(String line, List<WardleyComponentData> components) {
    final labelSplit = _splitLinkLabel(line);
    final body = labelSplit.$1;
    final simplePort = RegExp(
      r'^(.*?)\s+(\+<>|\+>|\+<)\s+(.*?)$',
    ).firstMatch(body);
    if (simplePort != null) {
      final simpleFrom = _resolveComponent(
        _name(simplePort.group(1)!),
        components,
      );
      final simpleTo = _resolveComponent(
        _name(simplePort.group(3)!),
        components,
      );
      if (simpleFrom != null && simpleTo != null) {
        final port = simplePort.group(2)!;
        return WardleyLinkData(
          from: simpleFrom.id,
          to: simpleTo.id,
          kind: port == '+<>'
              ? WardleyLinkKind.bidirectional
              : port == '+<'
              ? WardleyLinkKind.reverse
              : WardleyLinkKind.forward,
          label: labelSplit.$2,
        );
      }
    }
    final full = RegExp(
      r'''^(.*?)\s*(?:(\+<>|\+>|\+<)\s+)?(-->|->|-\.->|>|\+'[^']*'(?:<>|<|>))\s*(.*?)\s*(\+<>|\+>|\+<)?$''',
    ).firstMatch(body);
    final portOnly = full == null
        ? RegExp(r'^(.*?)\s*(\+<>|\+>|\+<)\s*(.*?)$').firstMatch(body)
        : null;
    if (full == null && portOnly == null) return null;
    final fromName = full?.group(1) ?? portOnly!.group(1)!;
    final toName = full?.group(4) ?? portOnly!.group(3)!;
    final from = _resolveComponent(_name(fromName), components);
    final to = _resolveComponent(_name(toName), components);
    if (from == null || to == null) return null;
    final arrow = full?.group(3) ?? portOnly!.group(2)!;
    final flowPort = full?.group(2) ?? full?.group(5) ?? portOnly?.group(2);
    final flowLabel = RegExp(r"^\+'([^']*)").firstMatch(arrow)?.group(1);
    final flowSource = flowPort ?? arrow;
    final kind = arrow == '-.->'
        ? WardleyLinkKind.dashed
        : flowSource.contains('<>')
        ? WardleyLinkKind.bidirectional
        : flowSource.endsWith('<')
        ? WardleyLinkKind.reverse
        : flowSource.startsWith('+')
        ? WardleyLinkKind.forward
        : WardleyLinkKind.dependency;
    return WardleyLinkData(
      from: from.id,
      to: to.id,
      kind: kind,
      label: flowLabel ?? labelSplit.$2,
    );
  }

  (String, String?) _splitLinkLabel(String source) {
    var quote = '';
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if ((char == '"' || char == "'") && (quote.isEmpty || quote == char)) {
        quote = quote.isEmpty ? char : '';
      }
      if (quote.isEmpty && char == ';') {
        return (
          source.substring(0, index).trim(),
          source.substring(index + 1).trim(),
        );
      }
    }
    return (source.trim(), null);
  }

  String _name(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  WardleyComponentData? _resolveComponent(
    String name,
    List<WardleyComponentData> components,
  ) {
    for (final component in components) {
      if (component.id == name) return component;
    }
    for (final component in components) {
      if (component.name == name) return component;
    }
    return null;
  }

  double? _coordinate(double value) {
    if (!value.isFinite || value < 0 || value > 100) return null;
    return value <= 1 ? value : value / 100;
  }

  String _stripComment(String source) {
    var quoted = false;
    var escaped = false;
    for (var index = 0; index < source.length - 1; index++) {
      final char = source[index];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (char == '"') quoted = !quoted;
      if (!quoted && char == '%' && source[index + 1] == '%') {
        return source.substring(0, index);
      }
    }
    return source;
  }
}
