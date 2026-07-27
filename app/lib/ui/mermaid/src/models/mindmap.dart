/*
 * [INPUT]: Depends on Mermaid mindmap indentation, node delimiters, Markdown labels, icons, classes, and branch sections.
 * [OUTPUT]: Defines immutable lossless native mindmap nodes, hierarchy metadata, renderer configuration, and theme scales.
 * [POS]: Serves as the mindmap-specific semantic tree alongside the shared graph projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum MindmapNodeShape {
  noBorder,
  roundedRectangle,
  rectangle,
  circle,
  cloud,
  bang,
  hexagon,
}

class MindmapNodeData {
  const MindmapNodeData({
    required this.index,
    required this.sourceId,
    required this.label,
    required this.shape,
    required this.indentation,
    required this.level,
    required this.parentIndex,
    required this.section,
    this.icon,
    this.cssClass,
  });

  final int index;
  final String sourceId;
  final String label;
  final MindmapNodeShape shape;
  final int indentation;
  final int level;
  final int? parentIndex;
  final int? section;
  final String? icon;
  final String? cssClass;

  MindmapNodeData copyWith({String? icon, String? cssClass}) => MindmapNodeData(
    index: index,
    sourceId: sourceId,
    label: label,
    shape: shape,
    indentation: indentation,
    level: level,
    parentIndex: parentIndex,
    section: section,
    icon: icon ?? this.icon,
    cssClass: cssClass ?? this.cssClass,
  );
}

class MindmapThemeData {
  const MindmapThemeData({
    this.colors = const [],
    this.inverseColors = const [],
    this.labelColors = const [],
    this.lineColors = const [],
    this.rootColor,
    this.rootLabelColor,
    this.nodeBorder,
    this.mainBackground,
    this.gradientStart,
    this.gradientStop,
    this.useGradient = false,
    this.strokeWidth = 2,
  });
  final List<String?> colors;
  final List<String?> inverseColors;
  final List<String?> labelColors;
  final List<String?> lineColors;
  final String? rootColor;
  final String? rootLabelColor;
  final String? nodeBorder;
  final String? mainBackground;
  final String? gradientStart;
  final String? gradientStop;
  final bool useGradient;
  final double strokeWidth;
}

class MindmapChartData {
  const MindmapChartData({
    required this.nodes,
    required this.rootIndex,
    this.title,
    this.padding = 10,
    this.maxNodeWidth = 200,
    this.layoutAlgorithm = 'cose-bilkent',
    this.useMaxWidth = true,
    this.look = 'classic',
    this.theme = const MindmapThemeData(),
  });
  final List<MindmapNodeData> nodes;
  final int rootIndex;
  final String? title;
  final double padding;
  final double maxNodeWidth;
  final String layoutAlgorithm;
  final bool useMaxWidth;
  final String look;
  final MindmapThemeData theme;

  MindmapChartData copyWith({
    String? title,
    double? padding,
    double? maxNodeWidth,
    String? layoutAlgorithm,
    bool? useMaxWidth,
    String? look,
    MindmapThemeData? theme,
  }) => MindmapChartData(
    nodes: nodes,
    rootIndex: rootIndex,
    title: title ?? this.title,
    padding: padding ?? this.padding,
    maxNodeWidth: maxNodeWidth ?? this.maxNodeWidth,
    layoutAlgorithm: layoutAlgorithm ?? this.layoutAlgorithm,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    look: look ?? this.look,
    theme: theme ?? this.theme,
  );
}
