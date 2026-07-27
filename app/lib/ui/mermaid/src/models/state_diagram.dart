/*
 * [INPUT]: Depends on Mermaid state declarations, composite hierarchy, pseudostates, concurrent regions, notes, transitions, directions, and classes.
 * [OUTPUT]: Defines immutable lossless state semantics plus complete renderer configuration and theme data.
 * [POS]: Serves as the chart-specific representation alongside the shared graph projection for stateDiagram.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'diagram.dart';

enum StateNodeKind { simple, composite, choice, fork, join }

class StateNodeData {
  const StateNodeData({
    required this.id,
    required this.label,
    required this.kind,
    this.parent,
    this.cssClasses = const [],
    this.direction,
  });
  final String id;
  final String label;
  final StateNodeKind kind;
  final String? parent;
  final List<String> cssClasses;
  final DiagramDirection? direction;

  StateNodeData copyWith({
    String? label,
    StateNodeKind? kind,
    String? parent,
    List<String>? cssClasses,
    DiagramDirection? direction,
  }) => StateNodeData(
    id: id,
    label: label ?? this.label,
    kind: kind ?? this.kind,
    parent: parent ?? this.parent,
    cssClasses: cssClasses ?? this.cssClasses,
    direction: direction ?? this.direction,
  );
}

class StateTransitionData {
  const StateTransitionData({
    required this.from,
    required this.to,
    this.label,
    this.fromClasses = const [],
    this.toClasses = const [],
  });
  final String from;
  final String to;
  final String? label;
  final List<String> fromClasses;
  final List<String> toClasses;
}

enum StateNotePosition { left, right }

class StateNoteData {
  const StateNoteData({
    required this.stateId,
    required this.position,
    required this.text,
  });
  final String stateId;
  final StateNotePosition position;
  final String text;
}

class StateRegionData {
  const StateRegionData({required this.parent, required this.index});
  final String parent;
  final int index;
}

class StateDiagramData {
  const StateDiagramData({
    required this.states,
    required this.transitions,
    required this.notes,
    required this.regions,
    required this.classDefinitions,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.titleTopMargin = 25,
    this.arrowMarkerAbsolute = false,
    this.dividerMargin = 10,
    this.sizeUnit = 5,
    this.padding = 8,
    this.textHeight = 10,
    this.titleShift = -15,
    this.noteMargin = 10,
    this.nodeSpacing = 50,
    this.rankSpacing = 50,
    this.forkWidth = 70,
    this.forkHeight = 7,
    this.miniPadding = 2,
    this.fontSizeFactor = 5.02,
    this.fontSize = 24,
    this.labelHeight = 16,
    this.edgeLengthFactor = '20',
    this.compositeTitleSize = 35,
    this.radius = 5,
    this.defaultRenderer = 'dagre-wrapper',
    this.useMaxWidth = true,
    this.look = 'classic',
    this.theme = const StateThemeData(),
  });
  final List<StateNodeData> states;
  final List<StateTransitionData> transitions;
  final List<StateNoteData> notes;
  final List<StateRegionData> regions;
  final Map<String, String> classDefinitions;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double titleTopMargin;
  final bool arrowMarkerAbsolute;
  final double dividerMargin;
  final double sizeUnit;
  final double padding;
  final double textHeight;
  final double titleShift;
  final double noteMargin;
  final double nodeSpacing;
  final double rankSpacing;
  final double forkWidth;
  final double forkHeight;
  final double miniPadding;
  final double fontSizeFactor;
  final double fontSize;
  final double labelHeight;
  final String edgeLengthFactor;
  final double compositeTitleSize;
  final double radius;
  final String defaultRenderer;
  final bool useMaxWidth;
  final String look;
  final StateThemeData theme;

  StateDiagramData copyWith({
    String? title,
    double? titleTopMargin,
    bool? arrowMarkerAbsolute,
    double? dividerMargin,
    double? sizeUnit,
    double? padding,
    double? textHeight,
    double? titleShift,
    double? noteMargin,
    double? nodeSpacing,
    double? rankSpacing,
    double? forkWidth,
    double? forkHeight,
    double? miniPadding,
    double? fontSizeFactor,
    double? fontSize,
    double? labelHeight,
    String? edgeLengthFactor,
    double? compositeTitleSize,
    double? radius,
    String? defaultRenderer,
    bool? useMaxWidth,
    String? look,
    StateThemeData? theme,
  }) => StateDiagramData(
    states: states,
    transitions: transitions,
    notes: notes,
    regions: regions,
    classDefinitions: classDefinitions,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    titleTopMargin: titleTopMargin ?? this.titleTopMargin,
    arrowMarkerAbsolute: arrowMarkerAbsolute ?? this.arrowMarkerAbsolute,
    dividerMargin: dividerMargin ?? this.dividerMargin,
    sizeUnit: sizeUnit ?? this.sizeUnit,
    padding: padding ?? this.padding,
    textHeight: textHeight ?? this.textHeight,
    titleShift: titleShift ?? this.titleShift,
    noteMargin: noteMargin ?? this.noteMargin,
    nodeSpacing: nodeSpacing ?? this.nodeSpacing,
    rankSpacing: rankSpacing ?? this.rankSpacing,
    forkWidth: forkWidth ?? this.forkWidth,
    forkHeight: forkHeight ?? this.forkHeight,
    miniPadding: miniPadding ?? this.miniPadding,
    fontSizeFactor: fontSizeFactor ?? this.fontSizeFactor,
    fontSize: fontSize ?? this.fontSize,
    labelHeight: labelHeight ?? this.labelHeight,
    edgeLengthFactor: edgeLengthFactor ?? this.edgeLengthFactor,
    compositeTitleSize: compositeTitleSize ?? this.compositeTitleSize,
    radius: radius ?? this.radius,
    defaultRenderer: defaultRenderer ?? this.defaultRenderer,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    look: look ?? this.look,
    theme: theme ?? this.theme,
  );
}

class StateThemeData {
  const StateThemeData({
    this.stateBackground,
    this.stateBorder,
    this.stateLabelColor,
    this.compositeBackground,
    this.compositeTitleBackground,
    this.noteBackground,
    this.noteBorder,
    this.noteText,
    this.specialStateColor,
    this.innerEndBackground,
    this.transitionColor,
    this.transitionLabelColor,
    this.edgeLabelBackground,
    this.lineColor,
    this.textColor,
    this.strokeWidth = 1,
  });
  final String? stateBackground;
  final String? stateBorder;
  final String? stateLabelColor;
  final String? compositeBackground;
  final String? compositeTitleBackground;
  final String? noteBackground;
  final String? noteBorder;
  final String? noteText;
  final String? specialStateColor;
  final String? innerEndBackground;
  final String? transitionColor;
  final String? transitionLabelColor;
  final String? edgeLabelBackground;
  final String? lineColor;
  final String? textColor;
  final double strokeWidth;
}
