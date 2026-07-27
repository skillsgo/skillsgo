/*
 * [INPUT]: Depends on Mermaid Event Modeling frames, entity types, namespaces, data examples, reset/source relations, notes, and GWT scenarios.
 * [OUTPUT]: Defines immutable timeline, swimlane, data, note, and scenario metadata for native layout and painting.
 * [POS]: Serves as the chart-specific intermediate representation for eventmodeling diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum EventModelingEntityType { ui, processor, command, readModel, event }

class EventModelingFrame {
  const EventModelingFrame({
    required this.id,
    required this.entityType,
    required this.entityIdentifier,
    required this.laneId,
    required this.isReset,
    this.sourceFrameIds = const [],
    this.dataReference,
    this.inlineData,
    this.dataType,
  });

  final String id;
  final EventModelingEntityType entityType;
  final String entityIdentifier;
  final String laneId;
  final bool isReset;
  final List<String> sourceFrameIds;
  final String? dataReference;
  final String? inlineData;
  final String? dataType;
}

class EventModelingLane {
  const EventModelingLane({required this.id, required this.label});
  final String id;
  final String label;
}

class EventModelingData {
  const EventModelingData({required this.id, required this.value, this.type});
  final String id;
  final String value;
  final String? type;
}

class EventModelingNote {
  const EventModelingNote({
    required this.frameId,
    required this.value,
    this.type,
  });
  final String frameId;
  final String value;
  final String? type;
}

class EventModelingScenario {
  const EventModelingScenario({required this.frameId, required this.source});
  final String frameId;
  final String source;
}

class EventModelingChartData {
  const EventModelingChartData({
    required this.frames,
    required this.lanes,
    required this.data,
    required this.notes,
    required this.scenarios,
    this.entities = const [],
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.padding = 30,
    this.rowHeight = 32,
    this.useMaxWidth = true,
    this.theme = const EventModelingThemeData(),
  });
  final List<EventModelingFrame> frames;
  final List<EventModelingLane> lanes;
  final List<EventModelingData> data;
  final List<EventModelingNote> notes;
  final List<EventModelingScenario> scenarios;
  final List<String> entities;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double padding;
  final double rowHeight;
  final bool useMaxWidth;
  final EventModelingThemeData theme;

  EventModelingChartData copyWith({
    String? title,
    String? accessibilityTitle,
    String? accessibilityDescription,
    double? padding,
    double? rowHeight,
    bool? useMaxWidth,
    EventModelingThemeData? theme,
  }) => EventModelingChartData(
    frames: frames,
    lanes: lanes,
    data: data,
    notes: notes,
    scenarios: scenarios,
    entities: entities,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle ?? this.accessibilityTitle,
    accessibilityDescription:
        accessibilityDescription ?? this.accessibilityDescription,
    padding: padding ?? this.padding,
    rowHeight: rowHeight ?? this.rowHeight,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    theme: theme ?? this.theme,
  );
}

class EventModelingThemeData {
  const EventModelingThemeData({
    this.uiFill,
    this.uiStroke,
    this.processorFill,
    this.processorStroke,
    this.readModelFill,
    this.readModelStroke,
    this.commandFill,
    this.commandStroke,
    this.eventFill,
    this.eventStroke,
    this.relationStroke,
    this.swimlaneBackgroundOdd,
    this.swimlaneBackgroundStroke,
    this.arrowhead,
    this.textColor,
  });
  final String? uiFill;
  final String? uiStroke;
  final String? processorFill;
  final String? processorStroke;
  final String? readModelFill;
  final String? readModelStroke;
  final String? commandFill;
  final String? commandStroke;
  final String? eventFill;
  final String? eventStroke;
  final String? relationStroke;
  final String? swimlaneBackgroundOdd;
  final String? swimlaneBackgroundStroke;
  final String? arrowhead;
  final String? textColor;
}
