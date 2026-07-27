/*
 * [INPUT]: Depends on Mermaid C4 diagram variants, element stereotypes, and layout configuration.
 * [OUTPUT]: Defines C4 variant identity, element metadata, and row configuration for native layout and painting.
 * [POS]: Serves as the chart-specific intermediate representation for all five Mermaid C4 diagram variants.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum C4DiagramKind { context, container, component, dynamic, deployment }

enum C4RelationDirection { automatic, up, down, left, right, back }

class C4StyleData {
  const C4StyleData({
    this.backgroundColor,
    this.fontColor,
    this.borderColor,
    this.shadowing,
    this.shape,
    this.sprite,
    this.technology,
    this.legendText,
    this.legendSprite,
  });

  final String? backgroundColor;
  final String? fontColor;
  final String? borderColor;
  final bool? shadowing;
  final String? shape;
  final String? sprite;
  final String? technology;
  final String? legendText;
  final String? legendSprite;
}

class C4ElementData {
  const C4ElementData({
    required this.id,
    required this.stereotype,
    required this.label,
    this.technology,
    this.description,
    this.sprite,
    this.tags,
    this.link,
    this.parentBoundaryId,
    this.style = const C4StyleData(),
  });

  final String id;
  final String stereotype;
  final String label;
  final String? technology;
  final String? description;
  final String? sprite;
  final String? tags;
  final String? link;
  final String? parentBoundaryId;
  final C4StyleData style;

  C4ElementData copyWith({C4StyleData? style}) => C4ElementData(
    id: id,
    stereotype: stereotype,
    label: label,
    technology: technology,
    description: description,
    sprite: sprite,
    tags: tags,
    link: link,
    parentBoundaryId: parentBoundaryId,
    style: style ?? this.style,
  );
}

class C4BoundaryData {
  const C4BoundaryData({
    required this.id,
    required this.label,
    required this.stereotype,
    this.description,
    this.tags,
    this.link,
    this.parentBoundaryId,
    this.nodeType,
    this.style = const C4StyleData(),
  });

  final String id;
  final String label;
  final String stereotype;
  final String? description;
  final String? tags;
  final String? link;
  final String? parentBoundaryId;
  final String? nodeType;
  final C4StyleData style;

  C4BoundaryData copyWith({C4StyleData? style}) => C4BoundaryData(
    id: id,
    label: label,
    stereotype: stereotype,
    description: description,
    tags: tags,
    link: link,
    parentBoundaryId: parentBoundaryId,
    nodeType: nodeType,
    style: style ?? this.style,
  );
}

class C4RelationData {
  const C4RelationData({
    required this.from,
    required this.to,
    required this.label,
    this.technology,
    this.description,
    this.sprite,
    this.tags,
    this.link,
    this.direction = C4RelationDirection.automatic,
    this.bidirectional = false,
    this.index,
    this.textColor,
    this.lineColor,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final String from;
  final String to;
  final String label;
  final String? technology;
  final String? description;
  final String? sprite;
  final String? tags;
  final String? link;
  final C4RelationDirection direction;
  final bool bidirectional;
  final int? index;
  final String? textColor;
  final String? lineColor;
  final double offsetX;
  final double offsetY;
}

class C4ChartData {
  const C4ChartData({
    required this.kind,
    required this.elements,
    this.boundaries = const [],
    this.relations = const [],
    this.layoutHints = const [],
    this.direction = 'TB',
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.shapesPerRow = 4,
    this.boundariesPerRow = 2,
    this.layoutConfigured = false,
    this.config = const {},
  });

  final C4DiagramKind kind;
  final List<C4ElementData> elements;
  final List<C4BoundaryData> boundaries;
  final List<C4RelationData> relations;
  final List<String> layoutHints;
  final String direction;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final int shapesPerRow;
  final int boundariesPerRow;
  final bool layoutConfigured;
  final Map<String, Object?> config;

  Object? setting(String key) => config[key];

  C4ChartData copyWith({
    String? title,
    Map<String, Object?>? config,
    int? shapesPerRow,
    int? boundariesPerRow,
  }) => C4ChartData(
    kind: kind,
    elements: elements,
    boundaries: boundaries,
    relations: relations,
    layoutHints: layoutHints,
    direction: direction,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    shapesPerRow: shapesPerRow ?? this.shapesPerRow,
    boundariesPerRow: boundariesPerRow ?? this.boundariesPerRow,
    layoutConfigured: layoutConfigured,
    config: config ?? this.config,
  );
}
