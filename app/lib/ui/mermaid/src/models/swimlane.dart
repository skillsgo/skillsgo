/*
 * [INPUT]: Depends on Mermaid swimlane-beta top-level lane semantics and dedicated layout configuration.
 * [OUTPUT]: Defines immutable lane membership, accessibility, line-hop, ranking, and ordering configuration for native rendering.
 * [POS]: Serves as the chart-specific intermediate representation between Flowchart-compatible parsing and native Swimlane layout/painting.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum SwimlaneLineHops { none, arc, gap }

class SwimlaneData {
  const SwimlaneData({
    required this.laneIds,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.lineHops = SwimlaneLineHops.arc,
    this.ignoreCrossLaneEdges = true,
    this.optimizeRanksByCrossings = true,
    this.automaticLaneOrdering = false,
    this.useMaxWidth = true,
  });

  final List<String> laneIds;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final SwimlaneLineHops lineHops;
  final bool ignoreCrossLaneEdges;
  final bool optimizeRanksByCrossings;
  final bool automaticLaneOrdering;
  final bool useMaxWidth;

  SwimlaneData copyWith({
    String? title,
    SwimlaneLineHops? lineHops,
    bool? ignoreCrossLaneEdges,
    bool? optimizeRanksByCrossings,
    bool? automaticLaneOrdering,
    bool? useMaxWidth,
  }) => SwimlaneData(
    laneIds: laneIds,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    lineHops: lineHops ?? this.lineHops,
    ignoreCrossLaneEdges: ignoreCrossLaneEdges ?? this.ignoreCrossLaneEdges,
    optimizeRanksByCrossings:
        optimizeRanksByCrossings ?? this.optimizeRanksByCrossings,
    automaticLaneOrdering: automaticLaneOrdering ?? this.automaticLaneOrdering,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
  );
}
