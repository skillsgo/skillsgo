/*
 * [INPUT]: Depends on native Mermaid node, edge, style, and subgraph value objects.
 * [OUTPUT]: Defines shared diagram direction, complete Mermaid 11.16.0 type identity, graph data, and subgraph models.
 * [POS]: Serves as the common intermediate representation for native parsers, layouts, painters, and widgets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'node.dart';
import 'edge.dart';
import 'style.dart';
import 'flowchart.dart';
import 'sequence.dart';

/// Direction of the diagram flow
enum DiagramDirection {
  /// Top to Bottom
  topToBottom,

  /// Bottom to Top
  bottomToTop,

  /// Left to Right
  leftToRight,

  /// Right to Left
  rightToLeft,
}

/// Type of diagram
enum DiagramType {
  /// Flowchart diagram
  flowchart,

  /// Sequence diagram
  sequence,

  /// ZenUML interaction diagram
  zenuml,

  /// Class diagram
  classDiagram,

  /// State diagram
  stateDiagram,

  /// Entity relationship diagram
  erDiagram,

  /// Requirement diagram
  requirementDiagram,

  /// User journey diagram
  journey,

  /// Mindmap diagram
  mindmap,

  /// Pie chart diagram
  pieChart,

  /// Gantt chart diagram
  ganttChart,

  /// Timeline diagram
  timeline,

  /// Kanban board diagram
  kanban,

  /// Radar chart diagram
  radar,

  /// XY chart diagram
  xyChart,

  /// C4 architecture diagram
  c4,

  /// Swimlanes diagram
  swimlanes,

  /// Informational diagram
  info,

  /// Git graph
  gitGraph,

  /// Quadrant chart
  quadrantChart,

  /// Sankey chart
  sankey,

  /// Packet diagram
  packet,

  /// Block diagram
  block,

  /// Event modeling diagram
  eventModeling,

  /// Tree view diagram
  treeView,

  /// Ishikawa diagram
  ishikawa,

  /// Treemap diagram
  treemap,

  /// Railroad grammar diagram
  railroad,

  /// Venn diagram
  venn,

  /// Wardley map
  wardley,

  /// Cynefin diagram
  cynefin,

  /// Architecture diagram
  architecture,

  /// Unknown/unsupported type
  unknown,
}

/// Represents a parsed Mermaid diagram
class MermaidDiagramData {
  /// Creates a new diagram data
  const MermaidDiagramData({
    required this.type,
    required this.nodes,
    required this.edges,
    this.direction = DiagramDirection.topToBottom,
    this.subgraphs = const [],
    this.style = const MermaidStyle(),
    this.title,
    this.flowchartConfig,
    this.sequenceConfig,
    this.accessibilityTitle,
    this.accessibilityDescription,
  });

  /// Type of this diagram
  final DiagramType type;

  /// All nodes in the diagram
  final List<MermaidNode> nodes;

  /// All edges connecting nodes
  final List<MermaidEdge> edges;

  /// Direction of the diagram flow
  final DiagramDirection direction;

  /// Subgraphs (nested containers)
  final List<Subgraph> subgraphs;

  /// Style configuration
  final MermaidStyle style;

  /// Optional title
  final String? title;

  /// Flowchart-specific renderer configuration.
  final FlowchartConfig? flowchartConfig;

  /// Sequence-specific renderer configuration.
  final SequenceConfig? sequenceConfig;
  final String? accessibilityTitle;
  final String? accessibilityDescription;

  /// Gets a node by its ID
  MermaidNode? getNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// Creates a copy with modified properties
  MermaidDiagramData copyWith({
    DiagramType? type,
    List<MermaidNode>? nodes,
    List<MermaidEdge>? edges,
    DiagramDirection? direction,
    List<Subgraph>? subgraphs,
    MermaidStyle? style,
    String? title,
    FlowchartConfig? flowchartConfig,
    SequenceConfig? sequenceConfig,
    String? accessibilityTitle,
    String? accessibilityDescription,
  }) {
    return MermaidDiagramData(
      type: type ?? this.type,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      direction: direction ?? this.direction,
      subgraphs: subgraphs ?? this.subgraphs,
      style: style ?? this.style,
      title: title ?? this.title,
      flowchartConfig: flowchartConfig ?? this.flowchartConfig,
      sequenceConfig: sequenceConfig ?? this.sequenceConfig,
      accessibilityTitle: accessibilityTitle ?? this.accessibilityTitle,
      accessibilityDescription:
          accessibilityDescription ?? this.accessibilityDescription,
    );
  }
}

/// Represents a subgraph container
class Subgraph {
  /// Creates a new subgraph
  const Subgraph({
    required this.id,
    required this.label,
    required this.nodeIds,
    this.style,
    this.direction,
    this.parentId,
  });

  /// Unique identifier
  final String id;

  /// Display label
  final String label;

  /// IDs of nodes contained in this subgraph
  final List<String> nodeIds;

  /// Optional custom style
  final SubgraphStyle? style;
  final DiagramDirection? direction;
  final String? parentId;
}

/// Style for subgraphs
class SubgraphStyle {
  /// Creates a subgraph style
  const SubgraphStyle({
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 4.0,
    this.padding = 16.0,
  });

  /// Background color
  final int? backgroundColor;

  /// Border color
  final int? borderColor;

  /// Border width
  final double borderWidth;

  /// Border radius
  final double borderRadius;

  /// Padding inside the subgraph
  final double padding;
}
