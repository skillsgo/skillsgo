/*
 * [INPUT]: Depends on Mermaid Architecture services, groups, junctions, directional ports, boundary modifiers, arrows, and alignment directives.
 * [OUTPUT]: Defines immutable Architecture metadata retained alongside the shared graph model.
 * [POS]: Serves as the chart-specific intermediate representation for native Architecture parsing, layout, and painting.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum ArchitecturePort { left, right, top, bottom }

enum ArchitectureAlignmentAxis { row, column }

class ArchitectureItemData {
  const ArchitectureItemData({
    required this.id,
    this.icon,
    this.parentId,
    this.isJunction = false,
  });

  final String id;
  final String? icon;
  final String? parentId;
  final bool isJunction;
}

class ArchitectureGroupData {
  const ArchitectureGroupData({
    required this.id,
    required this.label,
    this.icon,
    this.parentId,
  });

  final String id;
  final String label;
  final String? icon;
  final String? parentId;
}

class ArchitectureEdgeData {
  const ArchitectureEdgeData({
    required this.from,
    required this.to,
    required this.fromPort,
    required this.toPort,
    this.fromGroup = false,
    this.toGroup = false,
    this.arrowAtStart = false,
    this.arrowAtEnd = false,
    this.label,
  });

  final String from;
  final String to;
  final ArchitecturePort fromPort;
  final ArchitecturePort toPort;
  final bool fromGroup;
  final bool toGroup;
  final bool arrowAtStart;
  final bool arrowAtEnd;
  final String? label;
}

class ArchitectureAlignmentData {
  const ArchitectureAlignmentData({required this.axis, required this.members});

  final ArchitectureAlignmentAxis axis;
  final List<String> members;
}

class ArchitectureChartData {
  const ArchitectureChartData({
    required this.items,
    this.groups = const [],
    required this.edges,
    required this.alignments,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.useMaxWidth = true,
    this.padding = 40,
    this.iconSize = 80,
    this.fontSize = 16,
    this.randomize = false,
    this.nodeSeparation = 75,
    this.idealEdgeLengthMultiplier = 1.5,
    this.edgeElasticity = 0.45,
    this.numIter = 2500,
    this.seed = 1,
    this.edgeColor,
    this.edgeArrowColor,
    this.edgeWidth = 1,
    this.groupBorderColor,
    this.groupBorderWidth = 1,
  });

  final List<ArchitectureItemData> items;
  final List<ArchitectureGroupData> groups;
  final List<ArchitectureEdgeData> edges;
  final List<ArchitectureAlignmentData> alignments;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final bool useMaxWidth;
  final double padding;
  final double iconSize;
  final double fontSize;
  final bool randomize;
  final double nodeSeparation;
  final double idealEdgeLengthMultiplier;
  final double edgeElasticity;
  final int numIter;
  final int seed;
  final String? edgeColor;
  final String? edgeArrowColor;
  final double edgeWidth;
  final String? groupBorderColor;
  final double groupBorderWidth;

  ArchitectureChartData copyWith({
    String? title,
    bool replaceTitle = false,
    bool? useMaxWidth,
    double? padding,
    double? iconSize,
    double? fontSize,
    bool? randomize,
    double? nodeSeparation,
    double? idealEdgeLengthMultiplier,
    double? edgeElasticity,
    int? numIter,
    int? seed,
    String? edgeColor,
    String? edgeArrowColor,
    double? edgeWidth,
    String? groupBorderColor,
    double? groupBorderWidth,
  }) => ArchitectureChartData(
    items: items,
    groups: groups,
    edges: edges,
    alignments: alignments,
    title: replaceTitle ? title : (title ?? this.title),
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    padding: padding ?? this.padding,
    iconSize: iconSize ?? this.iconSize,
    fontSize: fontSize ?? this.fontSize,
    randomize: randomize ?? this.randomize,
    nodeSeparation: nodeSeparation ?? this.nodeSeparation,
    idealEdgeLengthMultiplier:
        idealEdgeLengthMultiplier ?? this.idealEdgeLengthMultiplier,
    edgeElasticity: edgeElasticity ?? this.edgeElasticity,
    numIter: numIter ?? this.numIter,
    seed: seed ?? this.seed,
    edgeColor: edgeColor ?? this.edgeColor,
    edgeArrowColor: edgeArrowColor ?? this.edgeArrowColor,
    edgeWidth: edgeWidth ?? this.edgeWidth,
    groupBorderColor: groupBorderColor ?? this.groupBorderColor,
    groupBorderWidth: groupBorderWidth ?? this.groupBorderWidth,
  );
}
