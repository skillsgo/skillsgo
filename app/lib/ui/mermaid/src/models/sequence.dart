/*
 * [INPUT]: Depends on Mermaid sequence participants, lifecycle, notes, activations, fragments, backgrounds, links, properties, details, and numbering semantics.
 * [OUTPUT]: Defines immutable sequence-specific participants with preserved attributes and ordered semantic events alongside the shared message graph.
 * [POS]: Serves as the lossless chart-specific representation for native sequenceDiagram rendering.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum SequenceParticipantKind {
  participant,
  actor,
  boundary,
  control,
  entity,
  database,
  collections,
  queue,
}

enum SequenceNotePosition { leftOf, rightOf, over }

enum SequenceFragmentKind {
  loop,
  optional,
  alternative,
  elseAlternative,
  parallel,
  parallelOver,
  parallelAnd,
  critical,
  option,
  breakBlock,
  rectangle,
  box,
}

enum SequenceLifecycleKind { create, destroy }

enum SequenceTextAlign { left, center, right }

/// Exact Mermaid sequence signal geometry, including the v11 half-arrow forms.
enum SequenceSignalKind {
  solidOpen,
  dottedOpen,
  solid,
  dotted,
  bidirectionalSolid,
  bidirectionalDotted,
  solidCross,
  dottedCross,
  solidPoint,
  dottedPoint,
  solidTop,
  solidBottom,
  stickTop,
  stickBottom,
  solidTopDotted,
  solidBottomDotted,
  stickTopDotted,
  stickBottomDotted,
  solidTopReverse,
  solidBottomReverse,
  stickTopReverse,
  stickBottomReverse,
  solidTopReverseDotted,
  solidBottomReverseDotted,
  stickTopReverseDotted,
  stickBottomReverseDotted,
}

class SequenceConfig {
  const SequenceConfig({
    this.arrowMarkerAbsolute,
    this.hideUnusedParticipants = false,
    this.activationWidth = 10,
    this.diagramMarginX = 50,
    this.diagramMarginY = 10,
    this.actorMargin = 50,
    this.width = 150,
    this.height = 65,
    this.boxMargin = 10,
    this.boxTextMargin = 5,
    this.noteMargin = 10,
    this.messageMargin = 35,
    this.messageAlign = SequenceTextAlign.center,
    this.mirrorActors = true,
    this.forceMenus = false,
    this.bottomMarginAdjustment = 1,
    this.useMaxWidth = true,
    this.rightAngles = false,
    this.showSequenceNumbers = false,
    this.actorFontSize = 14,
    this.actorFontFamily = 'Open Sans',
    this.actorFontWeight = '400',
    this.noteFontSize = 14,
    this.noteFontFamily = 'trebuchet ms',
    this.noteFontWeight = '400',
    this.noteAlign = SequenceTextAlign.center,
    this.messageFontSize = 16,
    this.messageFontFamily = 'trebuchet ms',
    this.messageFontWeight = '400',
    this.wrap = false,
    this.wrapPadding = 10,
    this.labelBoxWidth = 50,
    this.labelBoxHeight = 20,
    this.semanticRowCount,
  });

  final bool? arrowMarkerAbsolute;
  final bool hideUnusedParticipants;
  final double activationWidth;
  final double diagramMarginX;
  final double diagramMarginY;
  final double actorMargin;
  final double width;
  final double height;
  final double boxMargin;
  final double boxTextMargin;
  final double noteMargin;
  final double messageMargin;
  final SequenceTextAlign messageAlign;
  final bool mirrorActors;
  final bool forceMenus;
  final double bottomMarginAdjustment;
  final bool useMaxWidth;
  final bool rightAngles;
  final bool showSequenceNumbers;
  final double actorFontSize;
  final String actorFontFamily;
  final String actorFontWeight;
  final double noteFontSize;
  final String noteFontFamily;
  final String noteFontWeight;
  final SequenceTextAlign noteAlign;
  final double messageFontSize;
  final String messageFontFamily;
  final String messageFontWeight;
  final bool wrap;
  final double wrapPadding;
  final double labelBoxWidth;
  final double labelBoxHeight;
  final int? semanticRowCount;

  SequenceConfig copyWith({
    bool? arrowMarkerAbsolute,
    bool? hideUnusedParticipants,
    double? activationWidth,
    double? diagramMarginX,
    double? diagramMarginY,
    double? actorMargin,
    double? width,
    double? height,
    double? boxMargin,
    double? boxTextMargin,
    double? noteMargin,
    double? messageMargin,
    SequenceTextAlign? messageAlign,
    bool? mirrorActors,
    bool? forceMenus,
    double? bottomMarginAdjustment,
    bool? useMaxWidth,
    bool? rightAngles,
    bool? showSequenceNumbers,
    double? actorFontSize,
    String? actorFontFamily,
    String? actorFontWeight,
    double? noteFontSize,
    String? noteFontFamily,
    String? noteFontWeight,
    SequenceTextAlign? noteAlign,
    double? messageFontSize,
    String? messageFontFamily,
    String? messageFontWeight,
    bool? wrap,
    double? wrapPadding,
    double? labelBoxWidth,
    double? labelBoxHeight,
    int? semanticRowCount,
  }) => SequenceConfig(
    arrowMarkerAbsolute: arrowMarkerAbsolute ?? this.arrowMarkerAbsolute,
    hideUnusedParticipants:
        hideUnusedParticipants ?? this.hideUnusedParticipants,
    activationWidth: activationWidth ?? this.activationWidth,
    diagramMarginX: diagramMarginX ?? this.diagramMarginX,
    diagramMarginY: diagramMarginY ?? this.diagramMarginY,
    actorMargin: actorMargin ?? this.actorMargin,
    width: width ?? this.width,
    height: height ?? this.height,
    boxMargin: boxMargin ?? this.boxMargin,
    boxTextMargin: boxTextMargin ?? this.boxTextMargin,
    noteMargin: noteMargin ?? this.noteMargin,
    messageMargin: messageMargin ?? this.messageMargin,
    messageAlign: messageAlign ?? this.messageAlign,
    mirrorActors: mirrorActors ?? this.mirrorActors,
    forceMenus: forceMenus ?? this.forceMenus,
    bottomMarginAdjustment:
        bottomMarginAdjustment ?? this.bottomMarginAdjustment,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    rightAngles: rightAngles ?? this.rightAngles,
    showSequenceNumbers: showSequenceNumbers ?? this.showSequenceNumbers,
    actorFontSize: actorFontSize ?? this.actorFontSize,
    actorFontFamily: actorFontFamily ?? this.actorFontFamily,
    actorFontWeight: actorFontWeight ?? this.actorFontWeight,
    noteFontSize: noteFontSize ?? this.noteFontSize,
    noteFontFamily: noteFontFamily ?? this.noteFontFamily,
    noteFontWeight: noteFontWeight ?? this.noteFontWeight,
    noteAlign: noteAlign ?? this.noteAlign,
    messageFontSize: messageFontSize ?? this.messageFontSize,
    messageFontFamily: messageFontFamily ?? this.messageFontFamily,
    messageFontWeight: messageFontWeight ?? this.messageFontWeight,
    wrap: wrap ?? this.wrap,
    wrapPadding: wrapPadding ?? this.wrapPadding,
    labelBoxWidth: labelBoxWidth ?? this.labelBoxWidth,
    labelBoxHeight: labelBoxHeight ?? this.labelBoxHeight,
    semanticRowCount: semanticRowCount ?? this.semanticRowCount,
  );
}

sealed class SequenceEventData {
  const SequenceEventData({required this.depth});
  final int depth;
}

class SequenceMessageEventData extends SequenceEventData {
  const SequenceMessageEventData({
    required super.depth,
    required this.edgeIndex,
    required this.signalKind,
    this.number,
    this.centralAtSource = false,
    this.centralAtTarget = false,
    this.wrap,
  });
  final int edgeIndex;
  final SequenceSignalKind signalKind;
  final num? number;
  final bool centralAtSource;
  final bool centralAtTarget;
  final bool? wrap;
}

class SequenceNoteData extends SequenceEventData {
  const SequenceNoteData({
    required super.depth,
    required this.position,
    required this.actors,
    required this.text,
    this.wrap,
  });
  final SequenceNotePosition position;
  final List<String> actors;
  final String text;
  final bool? wrap;
}

class SequenceActivationData extends SequenceEventData {
  const SequenceActivationData({
    required super.depth,
    required this.actor,
    required this.active,
  });
  final String actor;
  final bool active;
}

class SequenceFragmentData extends SequenceEventData {
  const SequenceFragmentData({
    required super.depth,
    required this.kind,
    this.label,
    this.wrap,
    this.isEnd = false,
  });
  final SequenceFragmentKind kind;
  final String? label;
  final bool? wrap;
  final bool isEnd;
}

class SequenceLifecycleData extends SequenceEventData {
  const SequenceLifecycleData({
    required super.depth,
    required this.actor,
    required this.kind,
  });
  final String actor;
  final SequenceLifecycleKind kind;
}

class SequenceParticipantData {
  const SequenceParticipantData({
    required this.id,
    required this.label,
    required this.kind,
    this.links = const {},
    this.properties = const {},
    this.detailsReference,
    this.boxId,
  });
  final String id;
  final String label;
  final SequenceParticipantKind kind;
  final Map<String, String> links;
  final Map<String, Object?> properties;
  final String? detailsReference;
  final int? boxId;

  String? get cssClass => properties['class']?.toString();
  String? get icon => properties['icon']?.toString();

  SequenceParticipantData copyWith({
    String? label,
    SequenceParticipantKind? kind,
    Map<String, String>? links,
    Map<String, Object?>? properties,
    String? detailsReference,
    int? boxId,
  }) => SequenceParticipantData(
    id: id,
    label: label ?? this.label,
    kind: kind ?? this.kind,
    links: links ?? this.links,
    properties: properties ?? this.properties,
    detailsReference: detailsReference ?? this.detailsReference,
    boxId: boxId ?? this.boxId,
  );
}

class SequenceBoxData {
  const SequenceBoxData({required this.id, this.label, this.color});
  final int id;
  final String? label;
  final String? color;
}

class SequenceChartData {
  const SequenceChartData({
    required this.participants,
    required this.events,
    this.autoNumber = false,
    this.autoNumberStart = 1,
    this.autoNumberStep = 1,
    this.config = const SequenceConfig(),
    this.boxes = const [],
    this.accessibilityTitle,
    this.accessibilityDescription,
  });
  final List<SequenceParticipantData> participants;
  final List<SequenceEventData> events;
  final bool autoNumber;
  final num autoNumberStart;
  final num autoNumberStep;
  final SequenceConfig config;
  final List<SequenceBoxData> boxes;
  final String? accessibilityTitle;
  final String? accessibilityDescription;

  SequenceChartData copyWith({SequenceConfig? config}) => SequenceChartData(
    participants: participants,
    events: events,
    autoNumber: autoNumber,
    autoNumberStart: autoNumberStart,
    autoNumberStep: autoNumberStep,
    config: config ?? this.config,
    boxes: boxes,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
  );
}
