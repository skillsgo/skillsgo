/*
 * [INPUT]: Depends on Mermaid 11.16.0 Event Modeling compact/relaxed grammar and native timeline/swimlane graph models.
 * [OUTPUT]: Parses frames, resets, inferred/explicit relations, entity namespaces, inline/referenced data, data blocks, notes, entities, and GWT scenarios.
 * [POS]: Serves as the dedicated native parser for eventmodeling diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/event_modeling.dart';
import '../models/node.dart';

class EventModelingDiagramParser {
  const EventModelingDiagramParser();

  (MermaidDiagramData, EventModelingChartData)? parse(List<String> lines) {
    if (lines.isEmpty || lines.first.trim().toLowerCase() != 'eventmodeling') {
      return null;
    }
    final frames = <EventModelingFrame>[];
    final lanes = <String, EventModelingLane>{};
    final data = <EventModelingData>[];
    final notes = <EventModelingNote>[];
    final scenarios = <EventModelingScenario>[];
    final entities = <String>[];
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;

    for (var index = 1; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.startsWith('%%') || line.startsWith('//')) continue;
      if (line.startsWith('/*')) {
        while (!lines[index].contains('*/') && ++index < lines.length) {}
        if (index >= lines.length) return null;
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
      if (line.startsWith('accDescr')) {
        if (line.contains('{') && !line.contains('}')) {
          final values = <String>[];
          while (++index < lines.length && !lines[index].contains('}')) {
            values.add(lines[index].trim());
          }
          if (index >= lines.length) return null;
          accessibilityDescription = values.join('\n').trim();
        } else if (line.contains('{') && line.contains('}')) {
          accessibilityDescription = line
              .substring(line.indexOf('{') + 1, line.lastIndexOf('}'))
              .trim();
        } else if (line.contains(':')) {
          accessibilityDescription = line
              .substring(line.indexOf(':') + 1)
              .trim();
        }
        continue;
      }
      final frameMatch = RegExp(
        r'^(tf|timeframe|rf|resetframe)\s+(\d{1,3})\s+(ui|pcr|processor|cmd|command|rmo|readmodel|evt|event)\s+([A-Za-z_][\w]*(?:\.[A-Za-z_][\w]*)*)(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (frameMatch != null) {
        final id = frameMatch.group(2)!;
        if (frames.any((frame) => frame.id == id)) return null;
        final type = _type(frameMatch.group(3)!);
        final identifier = frameMatch.group(4)!;
        final suffix = frameMatch.group(5)!.trim();
        final sourceIds = RegExp(
          r'->>\s*(\d{1,3})',
        ).allMatches(suffix).map((match) => match.group(1)!).toList();
        final reference = RegExp(
          r'\[\[([A-Za-z_][\w]*)\]\]',
        ).firstMatch(suffix)?.group(1);
        final inline = RegExp(
          r'''(?:`(json|jsobj|figma|salt|uri|md|html|text)`)?\s*(\{.*\}|".*"|'.*')\s*$''',
        ).firstMatch(suffix);
        final lane = _lane(type, identifier);
        lanes.putIfAbsent(lane.id, () => lane);
        frames.add(
          EventModelingFrame(
            id: id,
            entityType: type,
            entityIdentifier: identifier,
            laneId: lane.id,
            isReset: frameMatch.group(1)!.toLowerCase().startsWith('r'),
            sourceFrameIds: sourceIds,
            dataReference: reference,
            dataType: inline?.group(1),
            inlineData: inline?.group(2),
          ),
        );
        continue;
      }
      final entity = RegExp(
        r'^entity\s+([A-Za-z_][\w]*(?:\.[A-Za-z_][\w]*)*)$',
      ).firstMatch(line);
      if (entity != null) {
        final id = entity.group(1)!;
        if (!entities.contains(id)) entities.add(id);
        continue;
      }
      final block = RegExp(
        r'^(data\s+([A-Za-z_][\w]*)|note\s+(\d{1,3}))(?:\s+`(json|jsobj|figma|salt|uri|md|html|text)`)?\s*(.*)$',
      ).firstMatch(line);
      if (block != null) {
        final collected = _collectBlock(lines, index, block.group(5)!);
        if (collected == null) return null;
        index = collected.$2;
        if (block.group(2) case final dataId?) {
          data.add(
            EventModelingData(
              id: dataId,
              value: collected.$1,
              type: block.group(4),
            ),
          );
        } else {
          notes.add(
            EventModelingNote(
              frameId: block.group(3)!,
              value: collected.$1,
              type: block.group(4),
            ),
          );
        }
        continue;
      }
      if (line.startsWith('gwt ')) {
        final match = RegExp(r'^gwt\s+(\d{1,3})(?:\s+(.+))?$').firstMatch(line);
        if (match == null) return null;
        final source = StringBuffer(match.group(2) ?? '');
        while (index + 1 < lines.length &&
            !_isTopLevel(lines[index + 1].trim())) {
          if (source.isNotEmpty) source.write(' ');
          source.write(lines[++index].trim());
        }
        final value = source.toString().trim();
        if (!value.contains(RegExp(r'\bgiven\b')) ||
            !value.contains(RegExp(r'\bthen\b'))) {
          return null;
        }
        scenarios.add(
          EventModelingScenario(frameId: match.group(1)!, source: value),
        );
        continue;
      }
      if (line == '{' || line == '}') return null;
      return null;
    }
    final ids = frames.map((frame) => frame.id).toSet();
    if (frames.any(
      (frame) => frame.sourceFrameIds.any((source) => !ids.contains(source)),
    )) {
      return null;
    }
    if (notes.any((note) => !ids.contains(note.frameId)) ||
        scenarios.any((scenario) => !ids.contains(scenario.frameId))) {
      return null;
    }
    final dataIds = data.map((item) => item.id).toSet();
    if (frames.any(
      (frame) =>
          frame.dataReference != null && !dataIds.contains(frame.dataReference),
    )) {
      return null;
    }
    final nodes = frames
        .map(
          (frame) => MermaidNode(
            id: frame.id,
            label: _label(frame, data),
            shape: _shape(frame.entityType),
          ),
        )
        .toList();
    final edges = <MermaidEdge>[];
    EventModelingFrame? previous;
    for (final frame in frames) {
      final sources = frame.sourceFrameIds.isNotEmpty
          ? frame.sourceFrameIds
          : (!frame.isReset && previous != null
                ? [previous.id]
                : const <String>[]);
      edges.addAll(
        sources.map((source) => MermaidEdge(from: source, to: frame.id)),
      );
      previous = frame;
    }
    return (
      MermaidDiagramData(
        type: DiagramType.eventModeling,
        nodes: nodes,
        edges: edges,
        title: title,
      ),
      EventModelingChartData(
        frames: frames,
        lanes: lanes.values.toList(),
        data: data,
        notes: notes,
        scenarios: scenarios,
        entities: entities,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  (String, int)? _collectBlock(List<String> lines, int index, String suffix) {
    final buffer = StringBuffer();
    var opened = false;
    var depth = 0;
    var current = suffix.trim();
    while (true) {
      if (current.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write(current);
        depth += '{'.allMatches(current).length;
        depth -= '}'.allMatches(current).length;
        opened = opened || current.contains('{');
      }
      if (opened && depth == 0) return (buffer.toString(), index);
      index++;
      if (index >= lines.length) return null;
      current = lines[index].trim();
    }
  }

  bool _isTopLevel(String line) => RegExp(
    r'^(?:tf|timeframe|rf|resetframe|data|note|gwt|entity|title|accTitle|accDescr)\b',
    caseSensitive: false,
  ).hasMatch(line);

  EventModelingEntityType _type(String value) => switch (value.toLowerCase()) {
    'ui' => EventModelingEntityType.ui,
    'pcr' || 'processor' => EventModelingEntityType.processor,
    'cmd' || 'command' => EventModelingEntityType.command,
    'rmo' || 'readmodel' => EventModelingEntityType.readModel,
    _ => EventModelingEntityType.event,
  };

  EventModelingLane _lane(EventModelingEntityType type, String identifier) {
    final separator = identifier.indexOf('.');
    final namespace = separator < 0 ? null : identifier.substring(0, separator);
    final category = switch (type) {
      EventModelingEntityType.ui || EventModelingEntityType.processor => 'ui',
      EventModelingEntityType.command ||
      EventModelingEntityType.readModel => 'command',
      EventModelingEntityType.event => 'event',
    };
    final defaultLabel = switch (category) {
      'ui' => 'UI/Automation',
      'command' => 'Command/Read Model',
      _ => 'Events',
    };
    return EventModelingLane(
      id: namespace == null ? category : '$category:$namespace',
      label: namespace ?? defaultLabel,
    );
  }

  String _label(EventModelingFrame frame, List<EventModelingData> data) {
    final name = frame.entityIdentifier.split('.').last;
    final value =
        frame.inlineData ??
        (frame.dataReference == null
            ? null
            : data.firstWhere((item) => item.id == frame.dataReference).value);
    return value == null ? name : '$name\n$value';
  }

  NodeShape _shape(EventModelingEntityType type) => switch (type) {
    EventModelingEntityType.ui => NodeShape.roundedRect,
    EventModelingEntityType.processor => NodeShape.hexagon,
    EventModelingEntityType.command => NodeShape.rectangle,
    EventModelingEntityType.readModel => NodeShape.subroutine,
    EventModelingEntityType.event => NodeShape.stadium,
  };
}
