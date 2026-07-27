/*
 * [INPUT]: Depends on Mermaid Block column, span, space, and composite placement semantics.
 * [OUTPUT]: Defines immutable grid placement data used by the native Block layout.
 * [POS]: Serves as the chart-specific intermediate representation for Mermaid Block diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
class BlockPlacement {
  const BlockPlacement({this.nodeId, this.groupId, this.parent, this.span = 1});

  final String? nodeId;
  final String? groupId;
  final String? parent;
  final int span;
  bool get isSpace => nodeId == null && groupId == null;
  bool get isGroup => groupId != null;
}

class BlockGroupData {
  const BlockGroupData({
    required this.id,
    required this.label,
    this.parent,
    this.columns = -1,
  });
  final String id;
  final String label;
  final String? parent;
  final int columns;

  BlockGroupData copyWith({int? columns}) => BlockGroupData(
    id: id,
    label: label,
    parent: parent,
    columns: columns ?? this.columns,
  );
}

class BlockArrowData {
  const BlockArrowData({required this.nodeId, required this.directions});
  final String nodeId;
  final List<String> directions;
}

class BlockChartData {
  const BlockChartData({
    required this.columns,
    required this.placements,
    this.groups = const [],
    this.arrows = const [],
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.padding = 8,
    this.useMaxWidth = true,
  });

  final int columns;
  final List<BlockPlacement> placements;
  final List<BlockGroupData> groups;
  final List<BlockArrowData> arrows;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double padding;
  final bool useMaxWidth;

  BlockChartData copyWith({
    String? title,
    String? accessibilityTitle,
    String? accessibilityDescription,
    double? padding,
    bool? useMaxWidth,
  }) => BlockChartData(
    columns: columns,
    placements: placements,
    groups: groups,
    arrows: arrows,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle ?? this.accessibilityTitle,
    accessibilityDescription:
        accessibilityDescription ?? this.accessibilityDescription,
    padding: padding ?? this.padding,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
  );
}
