/*
 * [INPUT]: Depends only on parsed Mermaid Venn set identifiers, subset sizes, labels, annotations, target styles, accessibility metadata, renderer configuration, and theme variables.
 * [OUTPUT]: Defines configured immutable Venn chart, subset, annotation, target-style, and theme models.
 * [POS]: Serves as the semantic model shared by the Venn parser, layout, and painter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
class VennSubset {
  const VennSubset({required this.sets, required this.size, this.label});

  final List<String> sets;
  final double size;
  final String? label;
}

class VennAnnotation {
  const VennAnnotation({required this.sets, required this.id, this.label});

  final List<String> sets;
  final String id;
  final String? label;
}

class VennThemeData {
  const VennThemeData({
    this.colors = const [],
    this.titleTextColor,
    this.setTextColor,
  });

  final List<String?> colors;
  final String? titleTextColor;
  final String? setTextColor;
}

class VennChartData {
  const VennChartData({
    required this.subsets,
    this.annotations = const [],
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.styles = const {},
    this.width = 800,
    this.height = 450,
    this.padding = 8,
    this.useDebugLayout = false,
    this.useMaxWidth = true,
    this.theme = const VennThemeData(),
    this.handDrawn = false,
    this.handDrawnSeed = 0,
  });

  final List<VennSubset> subsets;
  final List<VennAnnotation> annotations;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final Map<String, Map<String, String>> styles;
  final double width;
  final double height;
  final double padding;
  final bool useDebugLayout;
  final bool useMaxWidth;
  final VennThemeData theme;
  final bool handDrawn;
  final int handDrawnSeed;

  List<VennSubset> get individualSets =>
      subsets.where((subset) => subset.sets.length == 1).toList();

  Map<String, String> styleForSets(Iterable<String> sets) =>
      styles[(sets.toList()..sort()).join(',')] ?? const {};

  Map<String, String> styleForAnnotation(String id) => styles[id] ?? const {};

  VennChartData copyWith({
    String? title,
    double? width,
    double? height,
    double? padding,
    bool? useDebugLayout,
    bool? useMaxWidth,
    VennThemeData? theme,
    bool? handDrawn,
    int? handDrawnSeed,
  }) => VennChartData(
    subsets: subsets,
    annotations: annotations,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    styles: styles,
    width: width ?? this.width,
    height: height ?? this.height,
    padding: padding ?? this.padding,
    useDebugLayout: useDebugLayout ?? this.useDebugLayout,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    theme: theme ?? this.theme,
    handDrawn: handDrawn ?? this.handDrawn,
    handDrawnSeed: handDrawnSeed ?? this.handDrawnSeed,
  );
}
