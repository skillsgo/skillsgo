/*
 * [INPUT]: Depends on the vendored native Mermaid parsers, models, layouts, painters, widgets, and responsive configuration.
 * [OUTPUT]: Exports the supported pure-Dart Mermaid rendering API consumed by SkillsGo UI and compatibility tests.
 * [POS]: Serves as the public barrel for the App-owned native Mermaid engine.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
/// Pure Dart Mermaid diagram renderer for Flutter
///
/// This library provides a complete implementation of Mermaid diagram
/// rendering using only Dart and Flutter's CustomPainter, without
/// any WebView or external API dependencies.
///
/// Supported diagram types:
/// - Flowchart (graph TD/LR/BT/RL)
/// - Sequence diagram
/// - Pie chart
/// - Gantt chart
/// - Timeline
/// - Kanban board
/// - Radar chart
/// - XY chart
/// - Class diagram (basic)
/// - State diagram (basic)
///
/// Example usage:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   graph TD
///     A[Start] --> B{Decision}
///     B -->|Yes| C[OK]
///     B -->|No| D[Cancel]
///   ''',
/// )
/// ```
///
/// Pie chart example:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   pie
///     title Favorite Pets
///     "Dogs" : 386
///     "Cats" : 85
///     "Birds" : 15
///   ''',
/// )
/// ```
///
/// Timeline example:
/// ```dart
/// MermaidDiagram(
///   code: '''
///   timeline
///     title History of Social Media Platform
///     2002 : LinkedIn
///     2004 : Facebook
///          : Google
///     2005 : Youtube
///     2006 : Twitter
///   ''',
/// )
/// ```
library;

export 'src/config/responsive_config.dart';
export 'src/config/frontmatter.dart';
export 'src/config/icon_registry.dart';
export 'src/config/image_registry.dart';
export 'src/layout/layout_engine.dart';
export 'src/layout/sugiyama_layout.dart';
export 'src/layout/dagre_layout.dart';
export 'src/layout/dagre_d3_layout.dart';
export 'src/layout/elk_layout.dart';
export 'src/models/diagram.dart';
export 'src/models/flowchart.dart';
export 'src/models/event_modeling.dart';
export 'src/models/er_diagram.dart';
export 'src/models/ishikawa.dart';
export 'src/models/journey.dart';
export 'src/models/mindmap.dart';
export 'src/models/railroad.dart';
export 'src/models/requirement_diagram.dart';
export 'src/models/sequence.dart';
export 'src/models/sankey.dart';
export 'src/models/state_diagram.dart';
export 'src/models/wardley.dart';
export 'src/models/block.dart';
export 'src/models/architecture.dart';
export 'src/models/c4.dart';
export 'src/models/cynefin.dart';
export 'src/models/class_diagram.dart';
export 'src/models/edge.dart';
export 'src/models/gantt.dart';
export 'src/models/git_graph.dart';
export 'src/models/kanban.dart';
export 'src/models/packet.dart';
export 'src/models/quadrant.dart';
export 'src/models/treemap.dart';
export 'src/models/tree_view.dart';
export 'src/models/venn.dart';
export 'src/models/node.dart';
export 'src/models/pie_chart.dart';
export 'src/models/timeline.dart';
export 'src/models/style.dart';
export 'src/models/radar.dart';
export 'src/models/xy_chart.dart';
export 'src/models/zenuml.dart';
export 'src/models/swimlane.dart';
export 'src/painter/flowchart_painter.dart';
export 'src/painter/block_painter.dart';
export 'src/painter/architecture_painter.dart';
export 'src/painter/c4_painter.dart';
export 'src/painter/cynefin_painter.dart';
export 'src/painter/event_modeling_painter.dart';
export 'src/painter/ishikawa_painter.dart';
export 'src/painter/journey_painter.dart';
export 'src/painter/mindmap_painter.dart';
export 'src/painter/requirement_painter.dart';
export 'src/painter/er_painter.dart';
export 'src/painter/state_painter.dart';
export 'src/painter/class_painter.dart';
export 'src/painter/info_painter.dart';
export 'src/painter/railroad_painter.dart';
export 'src/painter/wardley_painter.dart';
export 'src/painter/gantt_painter.dart';
export 'src/painter/git_graph_painter.dart';
export 'src/painter/kanban_painter.dart';
export 'src/painter/packet_painter.dart';
export 'src/painter/quadrant_painter.dart';
export 'src/painter/treemap_painter.dart';
export 'src/painter/venn_painter.dart';
export 'src/painter/mermaid_painter.dart';
export 'src/painter/pie_chart_painter.dart';
export 'src/painter/sequence_painter.dart';
export 'src/painter/sankey_painter.dart';
export 'src/painter/timeline_painter.dart';
export 'src/painter/tree_view_painter.dart';
export 'src/painter/radar_painter.dart';
export 'src/painter/xy_chart_painter.dart';
export 'src/painter/zenuml_painter.dart';
export 'src/painter/swimlane_painter.dart';
export 'src/parser/flowchart_parser.dart';
export 'src/parser/event_modeling_parser.dart';
export 'src/parser/er_diagram_parser.dart';
export 'src/parser/ishikawa_parser.dart';
export 'src/parser/journey_parser.dart';
export 'src/parser/mindmap_parser.dart';
export 'src/parser/railroad_parser.dart';
export 'src/parser/requirement_diagram_parser.dart';
export 'src/parser/wardley_parser.dart';
export 'src/parser/block_parser.dart';
export 'src/parser/architecture_parser.dart';
export 'src/parser/c4_parser.dart';
export 'src/parser/cynefin_parser.dart';
export 'src/parser/class_state_parser.dart';
export 'src/parser/class_diagram_parser.dart';
export 'src/parser/gantt_parser.dart';
export 'src/parser/git_graph_parser.dart';
export 'src/parser/graph_family_parser.dart';
export 'src/parser/info_parser.dart';
export 'src/parser/kanban_parser.dart';
export 'src/parser/mermaid_parser.dart';
export 'src/parser/pie_chart_parser.dart';
export 'src/parser/quadrant_parser.dart';
export 'src/parser/treemap_parser.dart';
export 'src/parser/tree_view_parser.dart';
export 'src/parser/venn_parser.dart';
export 'src/parser/sequence_parser.dart';
export 'src/parser/sankey_parser.dart';
export 'src/parser/state_diagram_parser.dart';
export 'src/parser/structured_diagram_parser.dart';
export 'src/parser/swimlane_parser.dart';
export 'src/parser/timeline_parser.dart';
export 'src/parser/radar_parser.dart';
export 'src/parser/xy_chart_parser.dart';
export 'src/parser/zenuml_parser.dart';
export 'src/widgets/mermaid_diagram.dart';
