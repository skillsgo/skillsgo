/*
 * [INPUT]: Depends only on parsed Mermaid Treemap hierarchy, leaf weights, class styles, labels, accessibility metadata, renderer configuration, and color scales.
 * [OUTPUT]: Defines configured native hierarchical Treemap chart, complete color-scale theme data, and styled node models with aggregate weights.
 * [POS]: Serves as the semantic model shared by the Treemap parser, layout, and painter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
class TreemapNode {
  TreemapNode({
    required this.label,
    this.value,
    this.className,
    this.fillColor,
    this.textColor,
    this.strokeColor,
    this.strokeWidth,
    this.styles = const {},
    List<TreemapNode>? children,
  }) : children = children ?? [];

  final String label;
  final double? value;
  final String? className;
  final String? fillColor;
  final String? textColor;
  final String? strokeColor;
  final double? strokeWidth;
  final Map<String, String> styles;
  final List<TreemapNode> children;

  double get weight {
    if (value case final value?) return value;
    return children.fold<double>(0, (sum, child) => sum + child.weight);
  }
}

class TreemapThemeData {
  const TreemapThemeData({
    this.colors = const [],
    this.peerColors = const [],
    this.labelColors = const [],
    this.titleColor,
  });

  final List<String?> colors;
  final List<String?> peerColors;
  final List<String?> labelColors;
  final String? titleColor;
}

class TreemapChartData {
  const TreemapChartData({
    required this.roots,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.padding = 1,
    this.diagramPadding = 8,
    this.showValues = true,
    this.nodeWidth = 100,
    this.nodeHeight = 40,
    this.borderWidth = 1,
    this.valueFontSize = 10,
    this.labelFontSize = 11,
    this.valueFormat = ',',
    this.useMaxWidth = true,
    this.theme = const TreemapThemeData(),
  });

  final List<TreemapNode> roots;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double padding;
  final double diagramPadding;
  final bool showValues;
  final double nodeWidth;
  final double nodeHeight;
  final double borderWidth;
  final double valueFontSize;
  final double labelFontSize;
  final String valueFormat;
  final bool useMaxWidth;
  final TreemapThemeData theme;

  TreemapChartData copyWith({
    String? title,
    double? padding,
    double? diagramPadding,
    bool? showValues,
    double? nodeWidth,
    double? nodeHeight,
    double? borderWidth,
    double? valueFontSize,
    double? labelFontSize,
    String? valueFormat,
    bool? useMaxWidth,
    TreemapThemeData? theme,
  }) => TreemapChartData(
    roots: roots,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    padding: padding ?? this.padding,
    diagramPadding: diagramPadding ?? this.diagramPadding,
    showValues: showValues ?? this.showValues,
    nodeWidth: nodeWidth ?? this.nodeWidth,
    nodeHeight: nodeHeight ?? this.nodeHeight,
    borderWidth: borderWidth ?? this.borderWidth,
    valueFontSize: valueFontSize ?? this.valueFontSize,
    labelFontSize: labelFontSize ?? this.labelFontSize,
    valueFormat: valueFormat ?? this.valueFormat,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    theme: theme ?? this.theme,
  );
}
