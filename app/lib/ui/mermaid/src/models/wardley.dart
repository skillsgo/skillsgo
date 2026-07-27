/*
 * [INPUT]: Depends on Mermaid Wardley coordinates, value-chain links, evolution stages, sourcing decorators, pipelines, notes, annotations, strategic forces, accessibility metadata, renderer configuration, and theme variables.
 * [OUTPUT]: Defines immutable configured Wardley map entities, theme data, and presentation metadata for native coordinate layout and painting.
 * [POS]: Serves as the chart-specific intermediate representation for wardley-beta diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum WardleyStrategy { build, buy, outsource, market }

enum WardleyLinkKind { dependency, dashed, forward, reverse, bidirectional }

enum WardleyForceKind { accelerator, deaccelerator }

class WardleyStage {
  const WardleyStage({required this.name, this.boundary, this.secondName});
  final String name;
  final double? boundary;
  final String? secondName;
}

class WardleyComponentData {
  const WardleyComponentData({
    required this.name,
    String? id,
    required this.visibility,
    required this.evolution,
    this.isAnchor = false,
    this.labelOffsetX = 8,
    this.labelOffsetY = -12,
    this.hasLabelOffset = false,
    this.strategy,
    this.inertia = false,
    this.pipelineParent,
  }) : id = id ?? name;
  final String id;
  final String name;
  final double visibility;
  final double evolution;
  final bool isAnchor;
  final double labelOffsetX;
  final double labelOffsetY;
  final bool hasLabelOffset;
  final WardleyStrategy? strategy;
  final bool inertia;
  final String? pipelineParent;
}

class WardleyLinkData {
  const WardleyLinkData({
    required this.from,
    required this.to,
    required this.kind,
    this.label,
  });
  final String from;
  final String to;
  final WardleyLinkKind kind;
  final String? label;
}

class WardleyEvolutionData {
  const WardleyEvolutionData({required this.component, required this.target});
  final String component;
  final double target;
}

class WardleyNoteData {
  const WardleyNoteData({
    required this.text,
    required this.visibility,
    required this.evolution,
  });
  final String text;
  final double visibility;
  final double evolution;
}

class WardleyAnnotationData {
  const WardleyAnnotationData({
    required this.number,
    required this.x,
    required this.y,
    required this.text,
  });
  final int number;
  final double x;
  final double y;
  final String text;
}

class WardleyForceData {
  const WardleyForceData({
    required this.kind,
    required this.name,
    required this.x,
    required this.y,
  });
  final WardleyForceKind kind;
  final String name;
  final double x;
  final double y;
}

class WardleyThemeData {
  const WardleyThemeData({
    this.backgroundColor,
    this.axisColor,
    this.axisTextColor,
    this.gridColor,
    this.componentFill,
    this.componentStroke,
    this.componentLabelColor,
    this.linkStroke,
    this.evolutionStroke,
    this.annotationStroke,
    this.annotationTextColor,
    this.annotationFill,
  });

  final String? backgroundColor;
  final String? axisColor;
  final String? axisTextColor;
  final String? gridColor;
  final String? componentFill;
  final String? componentStroke;
  final String? componentLabelColor;
  final String? linkStroke;
  final String? evolutionStroke;
  final String? annotationStroke;
  final String? annotationTextColor;
  final String? annotationFill;
}

class WardleyChartData {
  const WardleyChartData({
    required this.components,
    required this.links,
    required this.evolutions,
    required this.stages,
    required this.notes,
    required this.annotations,
    required this.forces,
    this.width = 900,
    this.height = 600,
    this.annotationBoxX,
    this.annotationBoxY,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.hasExplicitSize = false,
    this.padding = 48,
    this.nodeRadius = 6,
    this.nodeLabelOffset = 8,
    this.axisFontSize = 12,
    this.labelFontSize = 10,
    this.showGrid = false,
    this.useMaxWidth = true,
    this.theme = const WardleyThemeData(),
  });
  final List<WardleyComponentData> components;
  final List<WardleyLinkData> links;
  final List<WardleyEvolutionData> evolutions;
  final List<WardleyStage> stages;
  final List<WardleyNoteData> notes;
  final List<WardleyAnnotationData> annotations;
  final List<WardleyForceData> forces;
  final double width;
  final double height;
  final double? annotationBoxX;
  final double? annotationBoxY;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final bool hasExplicitSize;
  final double padding;
  final double nodeRadius;
  final double nodeLabelOffset;
  final double axisFontSize;
  final double labelFontSize;
  final bool showGrid;
  final bool useMaxWidth;
  final WardleyThemeData theme;

  WardleyChartData copyWith({
    double? width,
    double? height,
    double? padding,
    double? nodeRadius,
    double? nodeLabelOffset,
    double? axisFontSize,
    double? labelFontSize,
    bool? showGrid,
    bool? useMaxWidth,
    WardleyThemeData? theme,
  }) => WardleyChartData(
    components: components,
    links: links,
    evolutions: evolutions,
    stages: stages,
    notes: notes,
    annotations: annotations,
    forces: forces,
    width: hasExplicitSize ? this.width : width ?? this.width,
    height: hasExplicitSize ? this.height : height ?? this.height,
    annotationBoxX: annotationBoxX,
    annotationBoxY: annotationBoxY,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    hasExplicitSize: hasExplicitSize,
    padding: padding ?? this.padding,
    nodeRadius: nodeRadius ?? this.nodeRadius,
    nodeLabelOffset: nodeLabelOffset ?? this.nodeLabelOffset,
    axisFontSize: axisFontSize ?? this.axisFontSize,
    labelFontSize: labelFontSize ?? this.labelFontSize,
    showGrid: showGrid ?? this.showGrid,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    theme: theme ?? this.theme,
  );
}
