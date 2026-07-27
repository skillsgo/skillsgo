/*
 * [INPUT]: Depends on Mermaid ER entities, aliases, typed attributes, keys/comments, cardinalities, relationship identity, direction, and styles.
 * [OUTPUT]: Defines immutable lossless ER semantics plus complete renderer configuration and theme data.
 * [POS]: Serves as the chart-specific representation alongside the shared graph projection for erDiagram.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum ErAttributeKey { primary, foreign, unique }

class ErAttributeData {
  const ErAttributeData({
    required this.type,
    required this.name,
    this.keys = const [],
    this.comment,
  });
  final String type;
  final String name;
  final List<ErAttributeKey> keys;
  final String? comment;
}

class ErEntityData {
  const ErEntityData({
    required this.id,
    required this.label,
    required this.attributes,
    this.cssClasses = const [],
    this.rawStyle,
  });
  final String id;
  final String label;
  final List<ErAttributeData> attributes;
  final List<String> cssClasses;
  final String? rawStyle;

  ErEntityData copyWith({
    String? label,
    List<ErAttributeData>? attributes,
    List<String>? cssClasses,
    String? rawStyle,
  }) => ErEntityData(
    id: id,
    label: label ?? this.label,
    attributes: attributes ?? this.attributes,
    cssClasses: cssClasses ?? this.cssClasses,
    rawStyle: rawStyle ?? this.rawStyle,
  );
}

enum ErCardinality { zeroOrOne, exactlyOne, zeroOrMore, oneOrMore, unknown }

class ErRelationshipData {
  const ErRelationshipData({
    required this.from,
    required this.to,
    required this.fromCardinality,
    required this.toCardinality,
    required this.identifying,
    required this.label,
    required this.rawMarker,
  });
  final String from;
  final String to;
  final ErCardinality fromCardinality;
  final ErCardinality toCardinality;
  final bool identifying;
  final String label;
  final String rawMarker;
}

class ErDiagramData {
  const ErDiagramData({
    required this.entities,
    required this.relationships,
    required this.classDefinitions,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.titleTopMargin = 25,
    this.diagramPadding = 20,
    this.layoutDirection = 'TB',
    this.minEntityWidth = 100,
    this.minEntityHeight = 75,
    this.entityPadding = 15,
    this.nodeSpacing = 140,
    this.rankSpacing = 80,
    this.stroke = 'gray',
    this.fill = 'honeydew',
    this.fontSize = 12,
    this.useMaxWidth = true,
    this.look = 'classic',
    this.theme = const ErThemeData(),
  });
  final List<ErEntityData> entities;
  final List<ErRelationshipData> relationships;
  final Map<String, String> classDefinitions;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double titleTopMargin;
  final double diagramPadding;
  final String layoutDirection;
  final double minEntityWidth;
  final double minEntityHeight;
  final double entityPadding;
  final double nodeSpacing;
  final double rankSpacing;
  final String stroke;
  final String fill;
  final double fontSize;
  final bool useMaxWidth;
  final String look;
  final ErThemeData theme;

  ErDiagramData copyWith({
    String? title,
    double? titleTopMargin,
    double? diagramPadding,
    String? layoutDirection,
    double? minEntityWidth,
    double? minEntityHeight,
    double? entityPadding,
    double? nodeSpacing,
    double? rankSpacing,
    String? stroke,
    String? fill,
    double? fontSize,
    bool? useMaxWidth,
    String? look,
    ErThemeData? theme,
  }) => ErDiagramData(
    entities: entities,
    relationships: relationships,
    classDefinitions: classDefinitions,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    titleTopMargin: titleTopMargin ?? this.titleTopMargin,
    diagramPadding: diagramPadding ?? this.diagramPadding,
    layoutDirection: layoutDirection ?? this.layoutDirection,
    minEntityWidth: minEntityWidth ?? this.minEntityWidth,
    minEntityHeight: minEntityHeight ?? this.minEntityHeight,
    entityPadding: entityPadding ?? this.entityPadding,
    nodeSpacing: nodeSpacing ?? this.nodeSpacing,
    rankSpacing: rankSpacing ?? this.rankSpacing,
    stroke: stroke ?? this.stroke,
    fill: fill ?? this.fill,
    fontSize: fontSize ?? this.fontSize,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    look: look ?? this.look,
    theme: theme ?? this.theme,
  );
}

class ErThemeData {
  const ErThemeData({
    this.mainBackground,
    this.nodeBorder,
    this.nodeTextColor,
    this.textColor,
    this.lineColor,
    this.tertiaryColor,
    this.edgeLabelBackground,
    this.erEdgeLabelBackground,
    this.backgroundColors = const [],
    this.borderColors = const [],
    this.strokeWidth = 1,
  });
  final String? mainBackground;
  final String? nodeBorder;
  final String? nodeTextColor;
  final String? textColor;
  final String? lineColor;
  final String? tertiaryColor;
  final String? edgeLabelBackground;
  final String? erEdgeLabelBackground;
  final List<String> backgroundColors;
  final List<String> borderColors;
  final double strokeWidth;
}
