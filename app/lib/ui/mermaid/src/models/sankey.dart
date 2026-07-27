/*
 * [INPUT]: Depends on Mermaid Sankey CSV ordering, weighted links, alignment, label, color, and sizing configuration.
 * [OUTPUT]: Defines immutable native Sankey nodes, links, and complete renderer configuration without reducing weights to labels.
 * [POS]: Serves as the lossless Sankey representation shared by parsing, native layout, and Canvas painting.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
class SankeyNodeData {
  const SankeyNodeData({required this.index, required this.id});
  final int index;
  final String id;
}

class SankeyLinkData {
  const SankeyLinkData({
    required this.index,
    required this.source,
    required this.target,
    required this.value,
  });
  final int index;
  final String source;
  final String target;
  final double value;
}

enum SankeyNodeAlignment { left, right, center, justify }

enum SankeyLabelStyle { legacy, outlined }

class SankeyChartData {
  const SankeyChartData({
    required this.nodes,
    required this.links,
    this.width = 600,
    this.height = 400,
    this.linkColor = 'gradient',
    this.nodeAlignment = SankeyNodeAlignment.justify,
    this.useMaxWidth = false,
    this.showValues = true,
    this.prefix = '',
    this.suffix = '',
    this.nodeWidth = 10,
    this.nodePadding = 12,
    this.labelStyle = SankeyLabelStyle.legacy,
    this.nodeColors = const {},
  });
  final List<SankeyNodeData> nodes;
  final List<SankeyLinkData> links;
  final double width;
  final double height;
  final String linkColor;
  final SankeyNodeAlignment nodeAlignment;
  final bool useMaxWidth;
  final bool showValues;
  final String prefix;
  final String suffix;
  final double nodeWidth;
  final double nodePadding;
  final SankeyLabelStyle labelStyle;
  final Map<String, String> nodeColors;

  SankeyChartData copyWith({
    double? width,
    double? height,
    String? linkColor,
    SankeyNodeAlignment? nodeAlignment,
    bool? useMaxWidth,
    bool? showValues,
    String? prefix,
    String? suffix,
    double? nodeWidth,
    double? nodePadding,
    SankeyLabelStyle? labelStyle,
    Map<String, String>? nodeColors,
  }) {
    return SankeyChartData(
      nodes: nodes,
      links: links,
      width: width ?? this.width,
      height: height ?? this.height,
      linkColor: linkColor ?? this.linkColor,
      nodeAlignment: nodeAlignment ?? this.nodeAlignment,
      useMaxWidth: useMaxWidth ?? this.useMaxWidth,
      showValues: showValues ?? this.showValues,
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
      nodeWidth: nodeWidth ?? this.nodeWidth,
      nodePadding: nodePadding ?? this.nodePadding,
      labelStyle: labelStyle ?? this.labelStyle,
      nodeColors: nodeColors ?? this.nodeColors,
    );
  }
}
