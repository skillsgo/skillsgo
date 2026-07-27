/*
 * [INPUT]: Depends on native Mermaid parsing, responsive layout engines, chart painters, and Flutter interaction primitives.
 * [OUTPUT]: Provides static and interactive native Mermaid widgets with responsive layout, cross-platform horizontal overflow preservation, error fallback hooks, and Sequence, Kanban, plus Gantt interaction callbacks.
 * [POS]: Serves as the Flutter composition boundary for the vendored native Mermaid engine.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../layout/dagre_layout.dart';
import '../layout/dagre_d3_layout.dart';
import '../layout/elk_layout.dart';
import '../layout/layout_engine.dart';
import '../layout/sugiyama_layout.dart';
import '../models/diagram.dart';
import '../models/flowchart.dart';
import '../models/cynefin.dart';
import '../models/event_modeling.dart';
import '../models/ishikawa.dart';
import '../models/journey.dart';
import '../models/mindmap.dart';
import '../models/requirement_diagram.dart';
import '../models/er_diagram.dart';
import '../models/state_diagram.dart';
import '../models/class_diagram.dart';
import '../models/block.dart';
import '../models/architecture.dart';
import '../models/c4.dart';
import '../models/railroad.dart';
import '../models/sequence.dart';
import '../models/sankey.dart';
import '../models/wardley.dart';
import '../models/gantt.dart';
import '../models/git_graph.dart';
import '../models/kanban.dart';
import '../models/packet.dart';
import '../models/quadrant.dart';
import '../models/pie_chart.dart';
import '../models/radar.dart';
import '../models/timeline.dart';
import '../models/tree_view.dart';
import '../models/treemap.dart';
import '../models/venn.dart';
import '../models/style.dart';
import '../models/xy_chart.dart';
import '../models/zenuml.dart';
import '../models/swimlane.dart';
import '../painter/flowchart_painter.dart';
import '../painter/cynefin_painter.dart';
import '../painter/event_modeling_painter.dart';
import '../painter/ishikawa_painter.dart';
import '../painter/journey_painter.dart';
import '../painter/mindmap_painter.dart';
import '../painter/requirement_painter.dart';
import '../painter/er_painter.dart';
import '../painter/state_painter.dart';
import '../painter/class_painter.dart';
import '../painter/block_painter.dart';
import '../painter/architecture_painter.dart';
import '../painter/c4_painter.dart';
import '../painter/info_painter.dart';
import '../painter/railroad_painter.dart';
import '../painter/wardley_painter.dart';
import '../painter/gantt_painter.dart';
import '../painter/git_graph_painter.dart';
import '../painter/kanban_painter.dart';
import '../painter/packet_painter.dart';
import '../painter/quadrant_painter.dart';
import '../painter/pie_chart_painter.dart';
import '../painter/radar_painter.dart';
import '../painter/sequence_painter.dart';
import '../painter/sankey_painter.dart';
import '../painter/timeline_painter.dart';
import '../painter/tree_view_painter.dart';
import '../painter/treemap_painter.dart';
import '../painter/venn_painter.dart';
import '../painter/xy_chart_painter.dart';
import '../painter/zenuml_painter.dart';
import '../painter/swimlane_painter.dart';
import '../parser/mermaid_parser.dart';

/// A widget that renders Mermaid diagrams using pure Dart/Flutter
///
/// This widget parses Mermaid diagram syntax and renders it using
/// Flutter's CustomPainter, without any WebView or external dependencies.
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
///   style: MermaidStyle.dark(),
/// )
/// ```
class MermaidDiagram extends StatefulWidget {
  /// Creates a Mermaid diagram widget
  const MermaidDiagram({
    super.key,
    required this.code,
    this.style,
    this.width,
    this.height,
    this.onNodeTap,
    this.onParticipantLinkTap,
    this.onKanbanTicketTap,
    this.onGanttInteraction,
    this.onError,
    this.errorBuilder,
    this.loadingBuilder,
    this.responsiveConfig,
    this.enableResponsive = true,
  });

  /// The Mermaid diagram code
  final String code;

  /// Style configuration (defaults to light theme)
  final MermaidStyle? style;

  /// Fixed width (if not provided, uses available space)
  final double? width;

  /// Fixed height (if not provided, uses computed size)
  final double? height;

  /// Callback when a node is tapped
  final void Function(String nodeId)? onNodeTap;

  /// Callback when a Sequence participant menu link is selected.
  final MermaidParticipantLinkCallback? onParticipantLinkTap;

  /// Callback when a Kanban ticket badge is selected.
  final MermaidKanbanTicketCallback? onKanbanTicketTap;

  /// Callback when an interactive Gantt task is selected.
  final MermaidGanttInteractionCallback? onGanttInteraction;

  /// Callback when parsing fails
  final void Function(String error)? onError;

  /// Builder for error state
  final Widget Function(BuildContext context, String error)? errorBuilder;

  /// Builder for loading state
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Responsive configuration for different screen sizes
  final MermaidResponsiveConfig? responsiveConfig;

  /// Whether to enable responsive layout (defaults to true)
  final bool enableResponsive;

  @override
  State<MermaidDiagram> createState() => _MermaidDiagramState();
}

class _MermaidDiagramState extends State<MermaidDiagram> {
  MermaidDiagramData? _diagram;
  PieChartData? _pieChartData;
  GanttChartData? _ganttChartData;
  TimelineChartData? _timelineChartData;
  KanbanChartData? _kanbanChartData;
  RadarChartData? _radarChartData;
  XYChartData? _xyChartData;
  PacketChartData? _packetChartData;
  SankeyChartData? _sankeyChartData;
  GitGraphChartData? _gitGraphChartData;
  TreeViewChartData? _treeViewChartData;
  QuadrantChartData? _quadrantChartData;
  TreemapChartData? _treemapChartData;
  VennChartData? _vennChartData;
  EventModelingChartData? _eventModelingChartData;
  IshikawaChartData? _ishikawaChartData;
  JourneyChartData? _journeyChartData;
  MindmapChartData? _mindmapChartData;
  RequirementDiagramData? _requirementDiagramData;
  ErDiagramData? _erDiagramData;
  StateDiagramData? _stateDiagramData;
  ClassDiagramData? _classDiagramData;
  BlockChartData? _blockChartData;
  ArchitectureChartData? _architectureChartData;
  C4ChartData? _c4ChartData;
  RailroadChartData? _railroadChartData;
  WardleyChartData? _wardleyChartData;
  CynefinChartData? _cynefinChartData;
  ZenUmlChartData? _zenUmlChartData;
  SequenceChartData? _sequenceChartData;
  SwimlaneData? _swimlaneData;
  Size _computedSize = Size.zero;
  String? _error;
  bool _isLoading = true;
  MermaidDeviceConfig? _deviceConfig;
  double? _lastWidth;
  String? _hoveredPieSlice;

  late MermaidStyle _style;

  @override
  void initState() {
    super.initState();
    _style = widget.style ?? const MermaidStyle();
  }

  @override
  void didUpdateWidget(MermaidDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.style != widget.style) {
      _style = widget.style ?? const MermaidStyle();
      _lastWidth = null; // Force re-layout
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initial parse will happen in build when we have context
  }

  void _parseDiagram(double availableWidth) {
    // Get responsive config
    if (widget.enableResponsive) {
      final responsiveConfig =
          widget.responsiveConfig ?? const MermaidResponsiveConfig();
      _deviceConfig = responsiveConfig.getConfigForWidth(availableWidth);

      // Apply responsive settings to style
      _style = _applyResponsiveStyle(_style, _deviceConfig!);
    }

    try {
      final parser = const MermaidParser();
      final result = parser.parseWithData(widget.code);

      if (result == null) {
        throw Exception('Unable to parse diagram');
      }

      final diagram = result.diagram;
      Size size;

      // Compute layout based on diagram type
      if (diagram.type == DiagramType.pieChart && result.pieChartData != null) {
        // Use pie chart layout with responsive config
        final pieLayout = PieChartLayout(deviceConfig: _deviceConfig);
        size = pieLayout.computeLayout(
          result.pieChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.sequence &&
          result.sequenceChartData != null) {
        final sequenceSize = SequenceLayout(deviceConfig: _deviceConfig)
            .computeLayout(
              diagram,
              _style,
              Size(widget.width ?? availableWidth, widget.height ?? 600),
            );
        final sequenceConfig = result.sequenceChartData!.config;
        final semanticHeight =
            sequenceConfig.diagramMarginY * 2 +
            sequenceConfig.height * (sequenceConfig.mirrorActors ? 2 : 1) +
            sequenceConfig.boxMargin +
            result.sequenceChartData!.events.length *
                sequenceConfig.messageMargin +
            sequenceConfig.bottomMarginAdjustment;
        size = Size(
          sequenceSize.width,
          sequenceSize.height < semanticHeight
              ? semanticHeight
              : sequenceSize.height,
        );
      } else if (diagram.type == DiagramType.ganttChart &&
          result.ganttChartData != null) {
        // Use Gantt chart layout with responsive config
        final ganttLayout = GanttChartLayout(deviceConfig: _deviceConfig);
        size = ganttLayout.computeLayout(
          result.ganttChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.timeline &&
          result.timelineChartData != null) {
        // Use Timeline chart layout with responsive config
        final timelineLayout = TimelineChartLayout(deviceConfig: _deviceConfig);
        size = timelineLayout.computeLayout(
          result.timelineChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.kanban &&
          result.kanbanChartData != null) {
        // Use Kanban chart layout with responsive config
        final kanbanLayout = KanbanChartLayout(deviceConfig: _deviceConfig);
        size = kanbanLayout.computeLayout(
          result.kanbanChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.radar &&
          result.radarChartData != null) {
        // Use Radar chart layout with responsive config
        final radarLayout = RadarChartLayout(deviceConfig: _deviceConfig);
        size = radarLayout.computeLayout(
          result.radarChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.xyChart &&
          result.xyChartData != null) {
        // Use XY chart layout with responsive config
        final xyLayout = XYChartLayout(deviceConfig: _deviceConfig);
        size = xyLayout.computeLayout(
          result.xyChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.journey &&
          result.journeyChartData != null) {
        size = const JourneyChartLayout().computeLayout(
          result.journeyChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.mindmap &&
          result.mindmapChartData != null) {
        size = const MindmapChartLayout().computeLayout(
          result.mindmapChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.requirementDiagram &&
          result.requirementDiagramData != null) {
        size = const RequirementChartLayout().computeLayout(
          diagram,
          result.requirementDiagramData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.erDiagram &&
          result.erDiagramData != null) {
        size = const ErChartLayout().computeLayout(
          result.erDiagramData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.stateDiagram &&
          result.stateDiagramData != null) {
        size = const StateChartLayout().computeLayout(
          diagram,
          result.stateDiagramData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.classDiagram &&
          result.classDiagramData != null) {
        size = const ClassChartLayout().computeLayout(
          diagram,
          result.classDiagramData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.packet &&
          result.packetChartData != null) {
        size = const PacketChartLayout().computeLayout(
          result.packetChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.sankey &&
          result.sankeyChartData != null) {
        size = const SankeyChartLayout().computeLayout(
          result.sankeyChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.gitGraph &&
          result.gitGraphChartData != null) {
        size = const GitGraphChartLayout().computeLayout(
          result.gitGraphChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.treeView &&
          result.treeViewChartData != null) {
        size = const TreeViewChartLayout().computeLayout(
          result.treeViewChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.quadrantChart &&
          result.quadrantChartData != null) {
        size = const QuadrantChartLayout().computeLayout(
          result.quadrantChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.treemap &&
          result.treemapChartData != null) {
        size = const TreemapChartLayout().computeLayout(
          result.treemapChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.venn &&
          result.vennChartData != null) {
        size = const VennChartLayout().computeLayout(
          result.vennChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.block &&
          result.blockChartData != null) {
        size = const BlockChartLayout().computeLayout(
          diagram,
          result.blockChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.c4 && result.c4ChartData != null) {
        size = const C4ChartLayout().computeLayout(
          diagram,
          result.c4ChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.architecture &&
          result.architectureChartData != null) {
        size = const ArchitectureChartLayout().computeLayout(
          diagram,
          result.architectureChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.swimlanes &&
          result.swimlaneData != null) {
        size = const SwimlaneChartLayout().computeLayout(
          diagram,
          result.swimlaneData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.eventModeling &&
          result.eventModelingChartData != null) {
        size = const EventModelingChartLayout().computeLayout(
          diagram,
          result.eventModelingChartData!,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.ishikawa &&
          result.ishikawaChartData != null) {
        size = const IshikawaChartLayout().computeLayout(
          result.ishikawaChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.railroad &&
          result.railroadChartData != null) {
        size = const RailroadChartLayout().computeLayout(
          result.railroadChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.wardley &&
          result.wardleyChartData != null) {
        size = const WardleyChartLayout().computeLayout(
          result.wardleyChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.cynefin &&
          result.cynefinChartData != null) {
        size = const CynefinChartLayout().computeLayout(
          result.cynefinChartData!,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      } else if (diagram.type == DiagramType.info) {
        size = Size(
          widget.width ?? (availableWidth < 400 ? 400 : availableWidth),
          widget.height ?? 100,
        );
      } else if (diagram.type == DiagramType.zenuml &&
          result.zenUmlChartData != null) {
        final sequenceSize = SequenceLayout(deviceConfig: _deviceConfig)
            .computeLayout(
              diagram,
              _style,
              Size(widget.width ?? availableWidth, widget.height ?? 600),
            );
        final semanticHeight =
            120.0 + result.zenUmlChartData!.events.length * 52;
        final responsiveWidth = widget.width ?? availableWidth;
        size = Size(
          result.zenUmlChartData!.useMaxWidth &&
                  responsiveWidth > sequenceSize.width
              ? responsiveWidth
              : sequenceSize.width,
          sequenceSize.height < semanticHeight
              ? semanticHeight
              : sequenceSize.height,
        );
      } else {
        final layoutEngine = _getLayoutEngine(diagram);
        size = layoutEngine.computeLayout(
          diagram,
          _style,
          Size(widget.width ?? availableWidth, widget.height ?? 600),
        );
      }

      _diagram = diagram;
      _pieChartData = result.pieChartData;
      _ganttChartData = result.ganttChartData;
      _timelineChartData = result.timelineChartData;
      _kanbanChartData = result.kanbanChartData;
      _radarChartData = result.radarChartData;
      _xyChartData = result.xyChartData;
      _packetChartData = result.packetChartData;
      _sankeyChartData = result.sankeyChartData;
      _gitGraphChartData = result.gitGraphChartData;
      _treeViewChartData = result.treeViewChartData;
      _quadrantChartData = result.quadrantChartData;
      _treemapChartData = result.treemapChartData;
      _vennChartData = result.vennChartData;
      _eventModelingChartData = result.eventModelingChartData;
      _ishikawaChartData = result.ishikawaChartData;
      _journeyChartData = result.journeyChartData;
      _mindmapChartData = result.mindmapChartData;
      _requirementDiagramData = result.requirementDiagramData;
      _erDiagramData = result.erDiagramData;
      _stateDiagramData = result.stateDiagramData;
      _classDiagramData = result.classDiagramData;
      _blockChartData = result.blockChartData;
      _architectureChartData = result.architectureChartData;
      _c4ChartData = result.c4ChartData;
      _railroadChartData = result.railroadChartData;
      _wardleyChartData = result.wardleyChartData;
      _cynefinChartData = result.cynefinChartData;
      _zenUmlChartData = result.zenUmlChartData;
      _sequenceChartData = result.sequenceChartData;
      _swimlaneData = result.swimlaneData;
      _computedSize = size;
      _error = null;
      _isLoading = false;
    } catch (e) {
      final errorMsg = e.toString();
      _error = errorMsg;
      _isLoading = false;
      widget.onError?.call(errorMsg);
    }
  }

  MermaidStyle _applyResponsiveStyle(
    MermaidStyle style,
    MermaidDeviceConfig config,
  ) {
    return style.copyWith(
      padding: config.padding,
      nodeSpacingX: config.nodeSpacingX,
      nodeSpacingY: config.nodeSpacingY,
      defaultNodeStyle: style.defaultNodeStyle.copyWith(
        fontSize: config.fontSize,
      ),
    );
  }

  LayoutEngine _getLayoutEngine(MermaidDiagramData diagram) {
    switch (diagram.type) {
      case DiagramType.flowchart:
        return switch (diagram.flowchartConfig?.defaultRenderer ??
            FlowchartRenderer.dagreWrapper) {
          FlowchartRenderer.dagreD3 => DagreD3Layout(
            deviceConfig: _deviceConfig,
          ),
          FlowchartRenderer.dagreWrapper => DagreLayout(
            deviceConfig: _deviceConfig,
          ),
          FlowchartRenderer.elk => ElkLayout(deviceConfig: _deviceConfig),
        };
      case DiagramType.classDiagram:
      case DiagramType.stateDiagram:
      case DiagramType.erDiagram:
      case DiagramType.requirementDiagram:
      case DiagramType.journey:
      case DiagramType.mindmap:
      case DiagramType.sankey:
      case DiagramType.gitGraph:
      case DiagramType.treeView:
      case DiagramType.swimlanes:
      case DiagramType.packet:
        return DagreLayout(deviceConfig: _deviceConfig);
      case DiagramType.sequence:
      case DiagramType.zenuml:
        return SequenceLayout(deviceConfig: _deviceConfig);
      default:
        return const SimpleLayoutEngine();
    }
  }

  CustomPainter _getPainter(MermaidDiagramData diagram) {
    switch (diagram.type) {
      case DiagramType.flowchart:
        return FlowchartPainter(
          diagram: diagram,
          style: _style,
          deviceConfig: _deviceConfig,
        );
      case DiagramType.swimlanes:
        if (_swimlaneData != null) {
          return SwimlanePainter(
            diagram: diagram,
            data: _swimlaneData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.journey:
        if (_journeyChartData != null) {
          return JourneyPainter(data: _journeyChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.stateDiagram:
        if (_stateDiagramData != null) {
          return StatePainter(
            diagram: diagram,
            data: _stateDiagramData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.classDiagram:
        if (_classDiagramData != null) {
          return ClassPainter(
            diagram: diagram,
            data: _classDiagramData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.erDiagram:
        if (_erDiagramData != null) {
          return ErPainter(data: _erDiagramData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.requirementDiagram:
        if (_requirementDiagramData != null) {
          return RequirementPainter(
            diagram: diagram,
            data: _requirementDiagramData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.mindmap:
        if (_mindmapChartData != null) {
          return MindmapPainter(data: _mindmapChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.info:
        return InfoPainter(version: '11.16.0', style: _style);
      case DiagramType.sequence:
        return SequencePainter(
          diagram: diagram,
          style: _style,
          deviceConfig: _deviceConfig,
          sequenceData: _sequenceChartData,
        );
      case DiagramType.zenuml:
        if (_zenUmlChartData != null) {
          return ZenUmlPainter(
            diagram: diagram,
            data: _zenUmlChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return SequencePainter(diagram: diagram, style: _style);
      case DiagramType.pieChart:
        if (_pieChartData != null) {
          return PieChartPainter(
            pieData: _pieChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
            hoveredSlice: _hoveredPieSlice,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.treeView:
        if (_treeViewChartData != null) {
          return TreeViewPainter(data: _treeViewChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.gitGraph:
        if (_gitGraphChartData != null) {
          return GitGraphPainter(data: _gitGraphChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.sankey:
        if (_sankeyChartData != null) {
          return SankeyPainter(data: _sankeyChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.quadrantChart:
        if (_quadrantChartData != null) {
          return QuadrantChartPainter(data: _quadrantChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.treemap:
        if (_treemapChartData != null) {
          return TreemapPainter(data: _treemapChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.venn:
        if (_vennChartData != null) {
          return VennPainter(data: _vennChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.eventModeling:
        if (_eventModelingChartData != null) {
          return EventModelingPainter(
            diagram: diagram,
            data: _eventModelingChartData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.ishikawa:
        if (_ishikawaChartData != null) {
          return IshikawaPainter(data: _ishikawaChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.railroad:
        if (_railroadChartData != null) {
          return RailroadPainter(data: _railroadChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.wardley:
        if (_wardleyChartData != null) {
          return WardleyPainter(
            data: _wardleyChartData!,
            style: _style,
            title: diagram.title,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.cynefin:
        if (_cynefinChartData != null) {
          return CynefinPainter(
            data: _cynefinChartData!,
            style: _style,
            title: diagram.title,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.architecture:
        if (_architectureChartData != null) {
          return ArchitecturePainter(
            diagram: diagram,
            data: _architectureChartData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.c4:
        if (_c4ChartData != null) {
          return C4Painter(
            diagram: diagram,
            data: _c4ChartData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.ganttChart:
        if (_ganttChartData != null) {
          return GanttPainter(
            ganttData: _ganttChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.timeline:
        if (_timelineChartData != null) {
          return TimelinePainter(
            timelineData: _timelineChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.kanban:
        if (_kanbanChartData != null) {
          return KanbanPainter(
            kanbanData: _kanbanChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.radar:
        if (_radarChartData != null) {
          return RadarPainter(
            radarData: _radarChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.xyChart:
        if (_xyChartData != null) {
          return XYChartPainter(
            xyData: _xyChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.packet:
        if (_packetChartData != null) {
          return PacketPainter(data: _packetChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.block:
        if (_blockChartData != null) {
          return BlockPainter(
            diagram: diagram,
            data: _blockChartData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      default:
        return FlowchartPainter(diagram: diagram, style: _style);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // Re-parse if width changed significantly or first time
        if (_lastWidth == null ||
            (availableWidth - _lastWidth!).abs() > 50 ||
            _isLoading) {
          _lastWidth = availableWidth;
          _parseDiagram(availableWidth);
        }

        if (_isLoading) {
          return widget.loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        }

        if (_error != null) {
          return widget.errorBuilder?.call(context, _error!) ??
              _buildErrorWidget(_error!);
        }

        if (_diagram == null) {
          return const SizedBox.shrink();
        }

        final painter = _getPainter(_diagram!);

        // Calculate display size with responsive constraints
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _computedSize.width;

        final requiresHorizontalScroll = _computedSize.width > maxWidth;
        final displayWidth = requiresHorizontalScroll
            ? _computedSize.width
            : widget.width != null
            ? widget.width!
            : _computedSize.width.clamp(0.0, maxWidth);

        final displayHeight = widget.height != null
            ? (_computedSize.height > widget.height!
                  ? _computedSize.height
                  : widget.height!)
            : _computedSize.height;

        // For mobile, wrap in horizontal scroll if needed
        Widget diagramWidget = Container(
          width: displayWidth,
          height: displayHeight,
          color: Color(_style.backgroundColor),
          child: CustomPaint(painter: painter, size: _computedSize),
        );
        if (_pieChartData?.highlightSlice == 'hover') {
          diagramWidget = MouseRegion(
            onHover: (event) => _handlePieHover(event.localPosition),
            onExit: (_) => _clearPieHover(),
            child: diagramWidget,
          );
        }

        // Preserve every diagram edge on any platform when native layout is
        // wider than its host. Desktop diagrams need this just as much as
        // mobile diagrams when embedded in a narrow settings or Markdown pane.
        if (requiresHorizontalScroll) {
          diagramWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: diagramWidget,
          );
        }

        return GestureDetector(
          onTapDown:
              widget.onNodeTap != null ||
                  widget.onParticipantLinkTap != null ||
                  widget.onKanbanTicketTap != null ||
                  widget.onGanttInteraction != null
              ? _handleTap
              : null,
          child: diagramWidget,
        );
      },
    );
  }

  Future<void> _handleTap(TapDownDetails details) async {
    if (_diagram == null) return;

    final localPosition = details.localPosition;
    final gantt = _ganttChartData;
    if (gantt != null) {
      final interaction = GanttPainter(
        ganttData: gantt,
        style: _style,
        deviceConfig: _deviceConfig,
      ).interactionAt(localPosition, _computedSize);
      if (interaction != null) {
        widget.onGanttInteraction?.call(interaction);
        return;
      }
    }
    final kanban = _kanbanChartData;
    if (kanban != null) {
      final task = KanbanPainter(
        kanbanData: kanban,
        style: _style,
        deviceConfig: _deviceConfig,
      ).ticketAt(localPosition, _computedSize);
      final url = task == null ? null : kanban.ticketUrlFor(task);
      if (task != null && url != null) {
        widget.onKanbanTicketTap?.call(task.id, url);
        return;
      }
    }

    for (final node in _diagram!.nodes) {
      final nodeRect = Rect.fromLTWH(node.x, node.y, node.width, node.height);

      if (nodeRect.contains(localPosition)) {
        await _handleParticipantLinks(
          context,
          details.globalPosition,
          node.id,
          _sequenceChartData,
          widget.onParticipantLinkTap,
        );
        widget.onNodeTap?.call(node.id);
        break;
      }
    }
  }

  void _handlePieHover(Offset position) {
    final data = _pieChartData;
    if (data == null) return;
    final hovered = PieChartPainter(
      pieData: data,
      style: _style,
      deviceConfig: _deviceConfig,
    ).sliceAt(position, _computedSize);
    if (hovered != _hoveredPieSlice) setState(() => _hoveredPieSlice = hovered);
  }

  void _clearPieHover() {
    if (_hoveredPieSlice != null) setState(() => _hoveredPieSlice = null);
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Mermaid Parse Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// An interactive Mermaid diagram with pan and zoom support
class InteractiveMermaidDiagram extends StatefulWidget {
  /// Creates an interactive Mermaid diagram
  const InteractiveMermaidDiagram({
    super.key,
    required this.code,
    this.style,
    this.minScale = 0.5,
    this.maxScale = 3.0,
    this.onNodeTap,
    this.onParticipantLinkTap,
    this.onKanbanTicketTap,
    this.onGanttInteraction,
  });

  /// The Mermaid diagram code
  final String code;

  /// Style configuration
  final MermaidStyle? style;

  /// Minimum zoom scale
  final double minScale;

  /// Maximum zoom scale
  final double maxScale;

  /// Callback when a node is tapped
  final void Function(String nodeId)? onNodeTap;

  /// Callback when a Sequence participant menu link is selected.
  final MermaidParticipantLinkCallback? onParticipantLinkTap;

  /// Callback when a Kanban ticket badge is selected.
  final MermaidKanbanTicketCallback? onKanbanTicketTap;

  /// Callback when an interactive Gantt task is selected.
  final MermaidGanttInteractionCallback? onGanttInteraction;

  @override
  State<InteractiveMermaidDiagram> createState() =>
      _InteractiveMermaidDiagramState();
}

class _InteractiveMermaidDiagramState extends State<InteractiveMermaidDiagram> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _diagramKey = GlobalKey();
  Size? _lastDiagramSize;
  Size? _lastViewportSize;
  bool _hasCentered = false;

  @override
  void didUpdateWidget(InteractiveMermaidDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.style != widget.style) {
      // Reset centering when code changes
      _hasCentered = false;
      _lastDiagramSize = null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _centerDiagram(Size viewportSize, Size diagramSize) {
    // Only center if size changed or first time
    if (_hasCentered &&
        _lastDiagramSize == diagramSize &&
        _lastViewportSize == viewportSize) {
      return;
    }

    _lastDiagramSize = diagramSize;
    _lastViewportSize = viewportSize;
    _hasCentered = true;

    // Calculate scale to fit diagram in viewport with padding
    const padding = 40.0; // Padding around diagram
    final availableWidth = viewportSize.width - padding * 2;
    final availableHeight = viewportSize.height - padding * 2;

    // Calculate scale factors for width and height
    final scaleX = availableWidth / diagramSize.width;
    final scaleY = availableHeight / diagramSize.height;

    // Use the smaller scale to ensure the entire diagram fits
    // But don't scale up beyond 1.0 (100%)
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(
      widget.minScale,
      1.0,
    );

    // Calculate the scaled diagram size
    final scaledWidth = diagramSize.width * scale;
    final scaledHeight = diagramSize.height * scale;

    // Calculate offset to center the scaled diagram
    final offsetX = (viewportSize.width - scaledWidth) / 2;
    final offsetY = (viewportSize.height - scaledHeight) / 2;

    // Set the transformation matrix
    // Matrix4 applies transformations in reverse order when using cascade
    // So we build: translate then scale (which applies as scale first, then translate)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Create matrix that scales at origin then translates to center
        final matrix = Matrix4.identity();
        // Apply translation
        matrix.setEntry(0, 3, offsetX);
        matrix.setEntry(1, 3, offsetY);
        // Apply scale
        matrix.setEntry(0, 0, scale);
        matrix.setEntry(1, 1, scale);
        _transformationController.value = matrix;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 使用实际可用空间来计算布局
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800.0;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;

        final viewportSize = Size(availableWidth, availableHeight);

        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          constrained: false,
          child: _CenteringMermaidDiagram(
            key: _diagramKey,
            code: widget.code,
            style: widget.style,
            viewportSize: viewportSize,
            onNodeTap: widget.onNodeTap,
            onParticipantLinkTap: widget.onParticipantLinkTap,
            onKanbanTicketTap: widget.onKanbanTicketTap,
            onGanttInteraction: widget.onGanttInteraction,
            onSizeComputed: (diagramSize) {
              _centerDiagram(viewportSize, diagramSize);
            },
          ),
        );
      },
    );
  }
}

/// Internal widget that reports its computed size for centering
class _CenteringMermaidDiagram extends StatefulWidget {
  const _CenteringMermaidDiagram({
    super.key,
    required this.code,
    required this.viewportSize,
    required this.onSizeComputed,
    this.style,
    this.onNodeTap,
    this.onParticipantLinkTap,
    this.onKanbanTicketTap,
    this.onGanttInteraction,
  });

  final String code;
  final MermaidStyle? style;
  final Size viewportSize;
  final void Function(String nodeId)? onNodeTap;
  final MermaidParticipantLinkCallback? onParticipantLinkTap;
  final MermaidKanbanTicketCallback? onKanbanTicketTap;
  final MermaidGanttInteractionCallback? onGanttInteraction;
  final void Function(Size size) onSizeComputed;

  @override
  State<_CenteringMermaidDiagram> createState() =>
      _CenteringMermaidDiagramState();
}

class _CenteringMermaidDiagramState extends State<_CenteringMermaidDiagram> {
  MermaidDiagramData? _diagram;
  PieChartData? _pieChartData;
  GanttChartData? _ganttChartData;
  TimelineChartData? _timelineChartData;
  KanbanChartData? _kanbanChartData;
  RadarChartData? _radarChartData;
  XYChartData? _xyChartData;
  PacketChartData? _packetChartData;
  SankeyChartData? _sankeyChartData;
  GitGraphChartData? _gitGraphChartData;
  TreeViewChartData? _treeViewChartData;
  QuadrantChartData? _quadrantChartData;
  TreemapChartData? _treemapChartData;
  VennChartData? _vennChartData;
  EventModelingChartData? _eventModelingChartData;
  IshikawaChartData? _ishikawaChartData;
  JourneyChartData? _journeyChartData;
  MindmapChartData? _mindmapChartData;
  RequirementDiagramData? _requirementDiagramData;
  ErDiagramData? _erDiagramData;
  StateDiagramData? _stateDiagramData;
  ClassDiagramData? _classDiagramData;
  BlockChartData? _blockChartData;
  ArchitectureChartData? _architectureChartData;
  C4ChartData? _c4ChartData;
  RailroadChartData? _railroadChartData;
  WardleyChartData? _wardleyChartData;
  CynefinChartData? _cynefinChartData;
  ZenUmlChartData? _zenUmlChartData;
  SequenceChartData? _sequenceChartData;
  SwimlaneData? _swimlaneData;
  Size _computedSize = Size.zero;
  String? _error;
  bool _isLoading = true;
  MermaidDeviceConfig? _deviceConfig;
  String? _hoveredPieSlice;

  late MermaidStyle _style;

  @override
  void initState() {
    super.initState();
    _style = widget.style ?? const MermaidStyle();
    _parseDiagram();
  }

  @override
  void didUpdateWidget(_CenteringMermaidDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.style != widget.style) {
      _style = widget.style ?? const MermaidStyle();
      _parseDiagram();
    }
  }

  void _parseDiagram() {
    try {
      const parser = MermaidParser();
      final result = parser.parseWithData(widget.code);

      if (result == null) {
        throw Exception('Unable to parse diagram');
      }

      final diagram = result.diagram;
      Size size;

      // Compute layout based on diagram type
      if (diagram.type == DiagramType.pieChart && result.pieChartData != null) {
        final pieLayout = PieChartLayout(deviceConfig: _deviceConfig);
        size = pieLayout.computeLayout(
          result.pieChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.sequence &&
          result.sequenceChartData != null) {
        final sequenceSize = SequenceLayout(
          deviceConfig: _deviceConfig,
        ).computeLayout(diagram, _style, widget.viewportSize);
        final sequenceConfig = result.sequenceChartData!.config;
        final semanticHeight =
            sequenceConfig.diagramMarginY * 2 +
            sequenceConfig.height * (sequenceConfig.mirrorActors ? 2 : 1) +
            sequenceConfig.boxMargin +
            result.sequenceChartData!.events.length *
                sequenceConfig.messageMargin +
            sequenceConfig.bottomMarginAdjustment;
        size = Size(
          sequenceSize.width,
          sequenceSize.height < semanticHeight
              ? semanticHeight
              : sequenceSize.height,
        );
      } else if (diagram.type == DiagramType.ganttChart &&
          result.ganttChartData != null) {
        final ganttLayout = GanttChartLayout(deviceConfig: _deviceConfig);
        size = ganttLayout.computeLayout(
          result.ganttChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.timeline &&
          result.timelineChartData != null) {
        final timelineLayout = TimelineChartLayout(deviceConfig: _deviceConfig);
        size = timelineLayout.computeLayout(
          result.timelineChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.kanban &&
          result.kanbanChartData != null) {
        final kanbanLayout = KanbanChartLayout(deviceConfig: _deviceConfig);
        size = kanbanLayout.computeLayout(
          result.kanbanChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.radar &&
          result.radarChartData != null) {
        final radarLayout = RadarChartLayout(deviceConfig: _deviceConfig);
        size = radarLayout.computeLayout(
          result.radarChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.xyChart &&
          result.xyChartData != null) {
        final xyLayout = XYChartLayout(deviceConfig: _deviceConfig);
        size = xyLayout.computeLayout(
          result.xyChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.journey &&
          result.journeyChartData != null) {
        size = const JourneyChartLayout().computeLayout(
          result.journeyChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.mindmap &&
          result.mindmapChartData != null) {
        size = const MindmapChartLayout().computeLayout(
          result.mindmapChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.requirementDiagram &&
          result.requirementDiagramData != null) {
        size = const RequirementChartLayout().computeLayout(
          diagram,
          result.requirementDiagramData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.erDiagram &&
          result.erDiagramData != null) {
        size = const ErChartLayout().computeLayout(
          result.erDiagramData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.stateDiagram &&
          result.stateDiagramData != null) {
        size = const StateChartLayout().computeLayout(
          diagram,
          result.stateDiagramData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.classDiagram &&
          result.classDiagramData != null) {
        size = const ClassChartLayout().computeLayout(
          diagram,
          result.classDiagramData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.packet &&
          result.packetChartData != null) {
        size = const PacketChartLayout().computeLayout(
          result.packetChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.sankey &&
          result.sankeyChartData != null) {
        size = const SankeyChartLayout().computeLayout(
          result.sankeyChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.gitGraph &&
          result.gitGraphChartData != null) {
        size = const GitGraphChartLayout().computeLayout(
          result.gitGraphChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.treeView &&
          result.treeViewChartData != null) {
        size = const TreeViewChartLayout().computeLayout(
          result.treeViewChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.quadrantChart &&
          result.quadrantChartData != null) {
        size = const QuadrantChartLayout().computeLayout(
          result.quadrantChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.treemap &&
          result.treemapChartData != null) {
        size = const TreemapChartLayout().computeLayout(
          result.treemapChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.venn &&
          result.vennChartData != null) {
        size = const VennChartLayout().computeLayout(
          result.vennChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.block &&
          result.blockChartData != null) {
        size = const BlockChartLayout().computeLayout(
          diagram,
          result.blockChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.c4 && result.c4ChartData != null) {
        size = const C4ChartLayout().computeLayout(
          diagram,
          result.c4ChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.architecture &&
          result.architectureChartData != null) {
        size = const ArchitectureChartLayout().computeLayout(
          diagram,
          result.architectureChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.swimlanes &&
          result.swimlaneData != null) {
        size = const SwimlaneChartLayout().computeLayout(
          diagram,
          result.swimlaneData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.eventModeling &&
          result.eventModelingChartData != null) {
        size = const EventModelingChartLayout().computeLayout(
          diagram,
          result.eventModelingChartData!,
          _style,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.ishikawa &&
          result.ishikawaChartData != null) {
        size = const IshikawaChartLayout().computeLayout(
          result.ishikawaChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.railroad &&
          result.railroadChartData != null) {
        size = const RailroadChartLayout().computeLayout(
          result.railroadChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.wardley &&
          result.wardleyChartData != null) {
        size = const WardleyChartLayout().computeLayout(
          result.wardleyChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.cynefin &&
          result.cynefinChartData != null) {
        size = const CynefinChartLayout().computeLayout(
          result.cynefinChartData!,
          widget.viewportSize,
        );
      } else if (diagram.type == DiagramType.info) {
        size = Size(
          widget.viewportSize.width < 400 ? 400 : widget.viewportSize.width,
          100,
        );
      } else if (diagram.type == DiagramType.zenuml &&
          result.zenUmlChartData != null) {
        final sequenceSize = SequenceLayout(
          deviceConfig: _deviceConfig,
        ).computeLayout(diagram, _style, widget.viewportSize);
        final semanticHeight =
            120.0 + result.zenUmlChartData!.events.length * 52;
        size = Size(
          result.zenUmlChartData!.useMaxWidth &&
                  widget.viewportSize.width > sequenceSize.width
              ? widget.viewportSize.width
              : sequenceSize.width,
          sequenceSize.height < semanticHeight
              ? semanticHeight
              : sequenceSize.height,
        );
      } else {
        final layoutEngine = _getLayoutEngine(diagram);
        size = layoutEngine.computeLayout(diagram, _style, widget.viewportSize);
      }

      setState(() {
        _diagram = diagram;
        _pieChartData = result.pieChartData;
        _ganttChartData = result.ganttChartData;
        _timelineChartData = result.timelineChartData;
        _kanbanChartData = result.kanbanChartData;
        _radarChartData = result.radarChartData;
        _xyChartData = result.xyChartData;
        _packetChartData = result.packetChartData;
        _sankeyChartData = result.sankeyChartData;
        _gitGraphChartData = result.gitGraphChartData;
        _treeViewChartData = result.treeViewChartData;
        _quadrantChartData = result.quadrantChartData;
        _treemapChartData = result.treemapChartData;
        _vennChartData = result.vennChartData;
        _eventModelingChartData = result.eventModelingChartData;
        _ishikawaChartData = result.ishikawaChartData;
        _journeyChartData = result.journeyChartData;
        _mindmapChartData = result.mindmapChartData;
        _requirementDiagramData = result.requirementDiagramData;
        _erDiagramData = result.erDiagramData;
        _stateDiagramData = result.stateDiagramData;
        _classDiagramData = result.classDiagramData;
        _blockChartData = result.blockChartData;
        _architectureChartData = result.architectureChartData;
        _c4ChartData = result.c4ChartData;
        _railroadChartData = result.railroadChartData;
        _wardleyChartData = result.wardleyChartData;
        _cynefinChartData = result.cynefinChartData;
        _zenUmlChartData = result.zenUmlChartData;
        _sequenceChartData = result.sequenceChartData;
        _swimlaneData = result.swimlaneData;
        _computedSize = size;
        _error = null;
        _isLoading = false;
      });

      // Notify parent of computed size for centering
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSizeComputed(size);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  LayoutEngine _getLayoutEngine(MermaidDiagramData diagram) {
    switch (diagram.type) {
      case DiagramType.flowchart:
        return switch (diagram.flowchartConfig?.defaultRenderer ??
            FlowchartRenderer.dagreWrapper) {
          FlowchartRenderer.dagreD3 => DagreD3Layout(
            deviceConfig: _deviceConfig,
          ),
          FlowchartRenderer.dagreWrapper => DagreLayout(
            deviceConfig: _deviceConfig,
          ),
          FlowchartRenderer.elk => ElkLayout(deviceConfig: _deviceConfig),
        };
      case DiagramType.classDiagram:
      case DiagramType.stateDiagram:
      case DiagramType.erDiagram:
      case DiagramType.requirementDiagram:
      case DiagramType.journey:
      case DiagramType.mindmap:
      case DiagramType.sankey:
      case DiagramType.gitGraph:
      case DiagramType.treeView:
      case DiagramType.swimlanes:
      case DiagramType.packet:
        return DagreLayout(deviceConfig: _deviceConfig);
      case DiagramType.sequence:
      case DiagramType.zenuml:
        return SequenceLayout(deviceConfig: _deviceConfig);
      default:
        return const SimpleLayoutEngine();
    }
  }

  CustomPainter _getPainter(MermaidDiagramData diagram) {
    switch (diagram.type) {
      case DiagramType.flowchart:
        return FlowchartPainter(
          diagram: diagram,
          style: _style,
          deviceConfig: _deviceConfig,
        );
      case DiagramType.swimlanes:
        if (_swimlaneData != null) {
          return SwimlanePainter(
            diagram: diagram,
            data: _swimlaneData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.journey:
        if (_journeyChartData != null) {
          return JourneyPainter(data: _journeyChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.stateDiagram:
        if (_stateDiagramData != null) {
          return StatePainter(
            diagram: diagram,
            data: _stateDiagramData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.classDiagram:
        if (_classDiagramData != null) {
          return ClassPainter(
            diagram: diagram,
            data: _classDiagramData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.erDiagram:
        if (_erDiagramData != null) {
          return ErPainter(data: _erDiagramData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.requirementDiagram:
        if (_requirementDiagramData != null) {
          return RequirementPainter(
            diagram: diagram,
            data: _requirementDiagramData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.mindmap:
        if (_mindmapChartData != null) {
          return MindmapPainter(data: _mindmapChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.info:
        return InfoPainter(version: '11.16.0', style: _style);
      case DiagramType.sequence:
        return SequencePainter(
          diagram: diagram,
          style: _style,
          deviceConfig: _deviceConfig,
          sequenceData: _sequenceChartData,
        );
      case DiagramType.zenuml:
        if (_zenUmlChartData != null) {
          return ZenUmlPainter(
            diagram: diagram,
            data: _zenUmlChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return SequencePainter(diagram: diagram, style: _style);
      case DiagramType.pieChart:
        if (_pieChartData != null) {
          return PieChartPainter(
            pieData: _pieChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
            hoveredSlice: _hoveredPieSlice,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.treeView:
        if (_treeViewChartData != null) {
          return TreeViewPainter(data: _treeViewChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.gitGraph:
        if (_gitGraphChartData != null) {
          return GitGraphPainter(data: _gitGraphChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.sankey:
        if (_sankeyChartData != null) {
          return SankeyPainter(data: _sankeyChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.quadrantChart:
        if (_quadrantChartData != null) {
          return QuadrantChartPainter(data: _quadrantChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.treemap:
        if (_treemapChartData != null) {
          return TreemapPainter(data: _treemapChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.venn:
        if (_vennChartData != null) {
          return VennPainter(data: _vennChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.eventModeling:
        if (_eventModelingChartData != null) {
          return EventModelingPainter(
            diagram: diagram,
            data: _eventModelingChartData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.ishikawa:
        if (_ishikawaChartData != null) {
          return IshikawaPainter(data: _ishikawaChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.railroad:
        if (_railroadChartData != null) {
          return RailroadPainter(data: _railroadChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.wardley:
        if (_wardleyChartData != null) {
          return WardleyPainter(
            data: _wardleyChartData!,
            style: _style,
            title: diagram.title,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.cynefin:
        if (_cynefinChartData != null) {
          return CynefinPainter(
            data: _cynefinChartData!,
            style: _style,
            title: diagram.title,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.architecture:
        if (_architectureChartData != null) {
          return ArchitecturePainter(
            diagram: diagram,
            data: _architectureChartData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.c4:
        if (_c4ChartData != null) {
          return C4Painter(
            diagram: diagram,
            data: _c4ChartData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.ganttChart:
        if (_ganttChartData != null) {
          return GanttPainter(
            ganttData: _ganttChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.timeline:
        if (_timelineChartData != null) {
          return TimelinePainter(
            timelineData: _timelineChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.kanban:
        if (_kanbanChartData != null) {
          return KanbanPainter(
            kanbanData: _kanbanChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.radar:
        if (_radarChartData != null) {
          return RadarPainter(
            radarData: _radarChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.xyChart:
        if (_xyChartData != null) {
          return XYChartPainter(
            xyData: _xyChartData!,
            style: _style,
            deviceConfig: _deviceConfig,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.packet:
        if (_packetChartData != null) {
          return PacketPainter(data: _packetChartData!, style: _style);
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      case DiagramType.block:
        if (_blockChartData != null) {
          return BlockPainter(
            diagram: diagram,
            data: _blockChartData!,
            style: _style,
          );
        }
        return FlowchartPainter(diagram: diagram, style: _style);
      default:
        return FlowchartPainter(diagram: diagram, style: _style);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorWidget(_error!);
    }

    if (_diagram == null) {
      return const SizedBox.shrink();
    }

    final painter = _getPainter(_diagram!);

    Widget diagram = Container(
      width: _computedSize.width,
      height: _computedSize.height,
      color: Color(_style.backgroundColor),
      child: GestureDetector(
        onTapDown:
            widget.onNodeTap != null ||
                widget.onParticipantLinkTap != null ||
                widget.onKanbanTicketTap != null ||
                widget.onGanttInteraction != null
            ? _handleTap
            : null,
        child: CustomPaint(painter: painter, size: _computedSize),
      ),
    );
    if (_pieChartData?.highlightSlice == 'hover') {
      diagram = MouseRegion(
        onHover: (event) => _handlePieHover(event.localPosition),
        onExit: (_) => _clearPieHover(),
        child: diagram,
      );
    }
    return diagram;
  }

  Future<void> _handleTap(TapDownDetails details) async {
    if (_diagram == null) return;

    final localPosition = details.localPosition;
    final gantt = _ganttChartData;
    if (gantt != null) {
      final interaction = GanttPainter(
        ganttData: gantt,
        style: _style,
        deviceConfig: _deviceConfig,
      ).interactionAt(localPosition, _computedSize);
      if (interaction != null) {
        widget.onGanttInteraction?.call(interaction);
        return;
      }
    }
    final kanban = _kanbanChartData;
    if (kanban != null) {
      final task = KanbanPainter(
        kanbanData: kanban,
        style: _style,
        deviceConfig: _deviceConfig,
      ).ticketAt(localPosition, _computedSize);
      final url = task == null ? null : kanban.ticketUrlFor(task);
      if (task != null && url != null) {
        widget.onKanbanTicketTap?.call(task.id, url);
        return;
      }
    }

    for (final node in _diagram!.nodes) {
      final nodeRect = Rect.fromLTWH(node.x, node.y, node.width, node.height);

      if (nodeRect.contains(localPosition)) {
        await _handleParticipantLinks(
          context,
          details.globalPosition,
          node.id,
          _sequenceChartData,
          widget.onParticipantLinkTap,
        );
        widget.onNodeTap?.call(node.id);
        break;
      }
    }
  }

  void _handlePieHover(Offset position) {
    final data = _pieChartData;
    if (data == null) return;
    final hovered = PieChartPainter(
      pieData: data,
      style: _style,
      deviceConfig: _deviceConfig,
    ).sliceAt(position, _computedSize);
    if (hovered != _hoveredPieSlice) setState(() => _hoveredPieSlice = hovered);
  }

  void _clearPieHover() {
    if (_hoveredPieSlice != null) setState(() => _hoveredPieSlice = null);
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Mermaid Parse Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

Future<void> _handleParticipantLinks(
  BuildContext context,
  Offset globalPosition,
  String participantId,
  SequenceChartData? sequenceData,
  MermaidParticipantLinkCallback? callback,
) async {
  if (callback == null || sequenceData == null) return;
  SequenceParticipantData? participant;
  for (final candidate in sequenceData.participants) {
    if (candidate.id == participantId) {
      participant = candidate;
      break;
    }
  }
  final links = participant?.links.entries.toList(growable: false) ?? const [];
  if (links.isEmpty) return;
  if (links.length == 1 && !sequenceData.config.forceMenus) {
    final link = links.single;
    callback(participantId, link.key, link.value);
    return;
  }
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final selected = await showMenu<MapEntry<String, String>>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    ),
    items: [
      for (final link in links)
        PopupMenuItem<MapEntry<String, String>>(
          value: link,
          child: Text(link.key),
        ),
    ],
  );
  if (selected != null) {
    callback(participantId, selected.key, selected.value);
  }
}

/// Handles selection of a named Sequence participant link.
typedef MermaidParticipantLinkCallback =
    void Function(String participantId, String label, String url);

/// Handles activation of a Kanban task's ticket badge.
typedef MermaidKanbanTicketCallback = void Function(String taskId, String url);

/// Handles activation of a Gantt task's parsed href/callback declaration.
typedef MermaidGanttInteractionCallback =
    void Function(GanttTaskInteraction interaction);
