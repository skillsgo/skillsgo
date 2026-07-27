/*
 * [INPUT]: Depends on shared YAML frontmatter preprocessing, each admitted native diagram parser, and its chart-specific model.
 * [OUTPUT]: Detects Mermaid diagram types and returns normalized native parse results with lossless frontmatter configuration.
 * [POS]: Serves as the central parser dispatcher for the vendored native Mermaid engine.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/architecture.dart';
import '../models/diagram.dart';
import '../models/flowchart.dart';
import '../models/event_modeling.dart';
import '../models/er_diagram.dart';
import '../models/ishikawa.dart';
import '../models/journey.dart';
import '../models/mindmap.dart';
import '../models/railroad.dart';
import '../models/requirement_diagram.dart';
import '../models/sequence.dart';
import '../models/sankey.dart';
import '../models/state_diagram.dart';
import '../models/wardley.dart';
import '../models/block.dart';
import '../models/c4.dart';
import '../models/cynefin.dart';
import '../models/class_diagram.dart';
import '../models/gantt.dart';
import '../models/git_graph.dart';
import '../models/kanban.dart';
import '../models/packet.dart';
import '../models/pie_chart.dart';
import '../models/radar.dart';
import '../models/quadrant.dart';
import '../models/timeline.dart';
import '../models/treemap.dart';
import '../models/tree_view.dart';
import '../models/venn.dart';
import '../models/xy_chart.dart';
import '../models/zenuml.dart';
import '../models/swimlane.dart';
import '../config/frontmatter.dart';
import 'architecture_parser.dart';
import 'flowchart_parser.dart';
import 'event_modeling_parser.dart';
import 'er_diagram_parser.dart';
import 'ishikawa_parser.dart';
import 'journey_parser.dart';
import 'mindmap_parser.dart';
import 'railroad_parser.dart';
import 'requirement_diagram_parser.dart';
import 'wardley_parser.dart';
import 'class_diagram_parser.dart';
import 'block_parser.dart';
import 'c4_parser.dart';
import 'cynefin_parser.dart';
import 'gantt_parser.dart';
import 'git_graph_parser.dart';
import 'graph_family_parser.dart';
import 'info_parser.dart';
import 'kanban_parser.dart';
import 'pie_chart_parser.dart';
import 'quadrant_parser.dart';
import 'radar_parser.dart';
import 'sequence_parser.dart';
import 'sankey_parser.dart';
import 'state_diagram_parser.dart';
import 'swimlane_parser.dart';
import 'timeline_parser.dart';
import 'treemap_parser.dart';
import 'tree_view_parser.dart';
import 'venn_parser.dart';
import 'xy_chart_parser.dart';
import 'zenuml_parser.dart';

/// Result of parsing a Mermaid diagram
class MermaidParseResult {
  /// Creates a parse result
  const MermaidParseResult({
    required this.diagram,
    this.pieChartData,
    this.ganttChartData,
    this.timelineChartData,
    this.kanbanChartData,
    this.packetChartData,
    this.quadrantChartData,
    this.treemapChartData,
    this.vennChartData,
    this.blockChartData,
    this.c4ChartData,
    this.architectureChartData,
    this.eventModelingChartData,
    this.ishikawaChartData,
    this.railroadChartData,
    this.wardleyChartData,
    this.cynefinChartData,
    this.zenUmlChartData,
    this.sequenceChartData,
    this.swimlaneData,
    this.classDiagramData,
    this.stateDiagramData,
    this.erDiagramData,
    this.requirementDiagramData,
    this.journeyChartData,
    this.mindmapChartData,
    this.sankeyChartData,
    this.gitGraphChartData,
    this.treeViewChartData,
    this.radarChartData,
    this.xyChartData,
    this.frontmatter = MermaidFrontmatter.empty,
  });

  /// The parsed diagram data
  final MermaidDiagramData diagram;

  /// Pie chart specific data (only set for pie charts)
  final PieChartData? pieChartData;

  /// Gantt chart specific data (only set for Gantt charts)
  final GanttChartData? ganttChartData;

  /// Timeline chart specific data (only set for timeline charts)
  final TimelineChartData? timelineChartData;

  /// Kanban chart specific data (only set for Kanban charts)
  final KanbanChartData? kanbanChartData;

  /// Packet-specific fields and title.
  final PacketChartData? packetChartData;

  /// Quadrant axes, quadrant labels, and normalized points.
  final QuadrantChartData? quadrantChartData;

  /// Treemap hierarchy and weights.
  final TreemapChartData? treemapChartData;

  /// Venn subsets, sizes, labels, and annotations.
  final VennChartData? vennChartData;

  /// Block grid columns, spans, spaces, and source order.
  final BlockChartData? blockChartData;

  /// C4 variant, stereotypes, and row layout configuration.
  final C4ChartData? c4ChartData;

  /// Architecture services, icons, ports, groups, and alignments.
  final ArchitectureChartData? architectureChartData;

  /// Event Modeling frames, lanes, data, notes, and scenarios.
  final EventModelingChartData? eventModelingChartData;

  /// Ishikawa effect and recursive cause hierarchy.
  final IshikawaChartData? ishikawaChartData;

  /// Unified Railroad/EBNF/ABNF/PEG rules and recursive expressions.
  final RailroadChartData? railroadChartData;

  /// Wardley coordinates, stages, dependencies, annotations, and forces.
  final WardleyChartData? wardleyChartData;

  /// Cynefin domains, items, and transitions.
  final CynefinChartData? cynefinChartData;

  /// ZenUML participants, calls, comments, and nested fragments.
  final ZenUmlChartData? zenUmlChartData;

  /// Sequence participants, notes, activations, fragments, links, and lifecycle.
  final SequenceChartData? sequenceChartData;

  /// Top-level lanes and dedicated swimlane layout configuration.
  final SwimlaneData? swimlaneData;

  /// Class members, namespaces, UML relations, notes, styles, and interactions.
  final ClassDiagramData? classDiagramData;

  /// State hierarchy, pseudostates, regions, notes, transitions, and classes.
  final StateDiagramData? stateDiagramData;

  /// ER entities, attributes, keys, cardinalities, identity, and styles.
  final ErDiagramData? erDiagramData;

  /// Requirements, elements, SysML fields, relationships, and styles.
  final RequirementDiagramData? requirementDiagramData;

  /// Journey sections, tasks, scores, actors, titles, and accessibility text.
  final JourneyChartData? journeyChartData;

  /// Mindmap hierarchy, relative indentation, shapes, icons, and classes.
  final MindmapChartData? mindmapChartData;

  /// Ordered Sankey nodes and finite numeric weighted links.
  final SankeyChartData? sankeyChartData;

  /// GitGraph branches, commit DAG, commands, direction, and directives.
  final GitGraphChartData? gitGraphChartData;

  /// Tree View hierarchy, file types, annotations, and metadata.
  final TreeViewChartData? treeViewChartData;

  /// Radar chart specific data (only set for Radar charts)
  final RadarChartData? radarChartData;

  /// XY chart specific data (only set for XY charts)
  final XYChartData? xyChartData;

  /// Supported leading YAML metadata and the complete diagram config tree.
  final MermaidFrontmatter frontmatter;
}

/// Main parser for Mermaid diagrams
///
/// This parser detects the diagram type and delegates to the
/// appropriate specialized parser.
class MermaidParser {
  /// Creates a new Mermaid parser
  const MermaidParser();

  /// Parses a Mermaid diagram string
  ///
  /// Returns null if the diagram cannot be parsed
  MermaidDiagramData? parse(String source) {
    final result = parseWithData(source);
    return result?.diagram;
  }

  /// Parses a Mermaid diagram string and returns additional data
  ///
  /// Returns a [MermaidParseResult] containing the diagram and any
  /// type-specific data (like [PieChartData] for pie charts)
  MermaidParseResult? parseWithData(String source) {
    final preprocessed = const MermaidFrontmatterParser().parse(source);
    if (preprocessed == null) return null;
    final result = _parseWithoutFrontmatter(
      preprocessed.source,
      preprocessed.metadata,
    );
    if (result == null) return null;
    final metadata = preprocessed.metadata;
    final title = metadata.title;
    final pieData = _configurePie(result.pieChartData, metadata, title);
    final kanbanData = _configureKanban(
      result.kanbanChartData,
      metadata,
      title,
    );
    final packetData = _configurePacket(
      result.packetChartData,
      metadata,
      title,
    );
    final sankeyData = _configureSankey(result.sankeyChartData, metadata);
    final gitGraphData = _configureGitGraph(
      result.gitGraphChartData,
      metadata,
      title,
    );
    final treeViewData = _configureTreeView(
      result.treeViewChartData,
      metadata,
      title,
    );
    final radarData = _configureRadar(result.radarChartData, metadata, title);
    final timelineData = _configureTimeline(
      result.timelineChartData,
      metadata,
      title,
    );
    final ganttData = _configureGantt(result.ganttChartData, metadata, title);
    final journeyData = _configureJourney(
      result.journeyChartData,
      metadata,
      title,
    );
    final mindmapData = _configureMindmap(
      result.mindmapChartData,
      metadata,
      title,
    );
    final requirementData = _configureRequirement(
      result.requirementDiagramData,
      metadata,
      title,
    );
    final erData = _configureEr(result.erDiagramData, metadata, title);
    final stateData = _configureState(result.stateDiagramData, metadata, title);
    final classData = _configureClass(result.classDiagramData, metadata, title);
    final xyData = _configureXY(result.xyChartData, metadata, title);
    final quadrantData = _configureQuadrant(
      result.quadrantChartData,
      metadata,
      title,
    );
    final treemapData = _configureTreemap(
      result.treemapChartData,
      metadata,
      title,
    );
    final vennData = _configureVenn(result.vennChartData, metadata, title);
    final wardleyData = _configureWardley(result.wardleyChartData, metadata);
    final cynefinData = _configureCynefin(result.cynefinChartData, metadata);
    final ishikawaData = _configureIshikawa(result.ishikawaChartData, metadata);
    final railroadData = _configureRailroad(
      result.railroadChartData,
      metadata,
      title,
    );
    final blockData = _configureBlock(result.blockChartData, metadata, title);
    final eventModelingData = _configureEventModeling(
      result.eventModelingChartData,
      metadata,
      title,
    );
    final architectureData = _configureArchitecture(
      result.architectureChartData,
      metadata,
      title,
    );
    final c4Data = _configureC4(result.c4ChartData, metadata, title);
    final swimlaneData = _configureSwimlane(
      result.swimlaneData,
      metadata,
      title,
    );
    final zenUmlData = result.zenUmlChartData?.copyWith(
      title: title,
      useMaxWidth: metadata.boolAt(['sequence', 'useMaxWidth']),
    );
    final flowchartDiagram = _configureFlowchartDiagram(
      result.diagram,
      metadata,
      title,
    );
    final sequence = _configureSequence(
      flowchartDiagram,
      result.sequenceChartData,
      metadata,
      title,
    );
    return MermaidParseResult(
      diagram: sequence.$1,
      pieChartData: pieData,
      ganttChartData: ganttData,
      timelineChartData: timelineData,
      kanbanChartData: kanbanData,
      packetChartData: packetData,
      quadrantChartData: quadrantData,
      treemapChartData: treemapData,
      vennChartData: vennData,
      blockChartData: blockData,
      c4ChartData: c4Data,
      architectureChartData: architectureData,
      eventModelingChartData: eventModelingData,
      ishikawaChartData: ishikawaData,
      railroadChartData: railroadData,
      wardleyChartData: wardleyData,
      cynefinChartData: cynefinData,
      zenUmlChartData: zenUmlData,
      sequenceChartData: sequence.$2,
      swimlaneData: swimlaneData,
      classDiagramData: classData,
      stateDiagramData: stateData,
      erDiagramData: erData,
      requirementDiagramData: requirementData,
      journeyChartData: journeyData,
      mindmapChartData: mindmapData,
      sankeyChartData: sankeyData,
      gitGraphChartData: gitGraphData,
      treeViewChartData: treeViewData,
      radarChartData: radarData,
      xyChartData: xyData,
      frontmatter: metadata,
    );
  }

  ArchitectureChartData? _configureArchitecture(
    ArchitectureChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    double? finite(String key) {
      final value = metadata.numberAt(['architecture', key]);
      return value?.toDouble();
    }

    double? nonNegative(String key) {
      final value = finite(key);
      return value != null && value >= 0 ? value : null;
    }

    double? positive(String key) {
      final value = finite(key);
      return value != null && value > 0 ? value : null;
    }

    final elasticity = finite('edgeElasticity');
    final iterations = metadata.numberAt(['architecture', 'numIter']);
    final seed = metadata.numberAt(['architecture', 'seed']);
    return data.copyWith(
      title: title,
      useMaxWidth: metadata.boolAt(['architecture', 'useMaxWidth']),
      padding: nonNegative('padding'),
      iconSize: positive('iconSize'),
      fontSize: positive('fontSize'),
      randomize: metadata.boolAt(['architecture', 'randomize']),
      nodeSeparation: nonNegative('nodeSeparation'),
      idealEdgeLengthMultiplier: positive('idealEdgeLengthMultiplier'),
      edgeElasticity: elasticity != null && elasticity >= 0 && elasticity <= 1
          ? elasticity
          : null,
      numIter: iterations != null && iterations >= 0
          ? iterations.round()
          : null,
      seed: seed?.round(),
      edgeColor: metadata.stringAt(['themeVariables', 'archEdgeColor']),
      edgeArrowColor: metadata.stringAt([
        'themeVariables',
        'archEdgeArrowColor',
      ]),
      edgeWidth: nonNegativeThemeNumber(metadata, 'archEdgeWidth'),
      groupBorderColor: metadata.stringAt([
        'themeVariables',
        'archGroupBorderColor',
      ]),
      groupBorderWidth: nonNegativeThemeNumber(
        metadata,
        'archGroupBorderWidth',
      ),
    );
  }

  C4ChartData? _configureC4(
    C4ChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final raw = metadata.valueAt(['c4']);
    final config = raw is Map<String, Object?>
        ? Map<String, Object?>.unmodifiable(raw)
        : const <String, Object?>{};
    int? positiveInt(String key) {
      final value = metadata.numberAt(['c4', key]);
      return value != null && value >= 1 ? value.round() : null;
    }

    return data.copyWith(
      title: title,
      config: config,
      shapesPerRow: data.layoutConfigured ? null : positiveInt('c4ShapeInRow'),
      boundariesPerRow: data.layoutConfigured
          ? null
          : positiveInt('c4BoundaryInRow'),
    );
  }

  SwimlaneData? _configureSwimlane(
    SwimlaneData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final lineHops = metadata.valueAt(['swimlane', 'lineHops']);
    return data.copyWith(
      title: title,
      lineHops: switch (lineHops) {
        false => SwimlaneLineHops.none,
        'gap' => SwimlaneLineHops.gap,
        true || 'arc' => SwimlaneLineHops.arc,
        _ => null,
      },
      ignoreCrossLaneEdges: metadata.boolAt([
        'swimlane',
        'ignoreCrossLaneEdges',
      ]),
      optimizeRanksByCrossings: metadata.boolAt([
        'swimlane',
        'optimizeRanksByCrossings',
      ]),
      automaticLaneOrdering: metadata.boolAt([
        'swimlane',
        'automaticLaneOrdering',
      ]),
      useMaxWidth: metadata.boolAt(['swimlane', 'useMaxWidth']),
    );
  }

  double? nonNegativeThemeNumber(MermaidFrontmatter metadata, String key) {
    final raw = metadata.stringAt(['themeVariables', key]);
    if (raw == null) return null;
    final match = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(raw);
    return match == null ? null : double.parse(match.group(1)!);
  }

  JourneyChartData? _configureJourney(
    JourneyChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    List<String>? strings(String key) {
      final value = metadata.valueAt(['journey', key]);
      if (value is! List) return null;
      return value.whereType<Object>().map((item) => '$item').toList();
    }

    List<String?> themeScale(String prefix, int count) => List.generate(
      count,
      (index) => metadata.stringAt(['themeVariables', '$prefix$index']),
      growable: false,
    );
    final alignment = metadata.stringAt(['journey', 'messageAlign']);
    return data.copyWith(
      title: title ?? data.title,
      diagramMarginX: _nonNegativeDouble(metadata, [
        'journey',
        'diagramMarginX',
      ]),
      diagramMarginY: _nonNegativeDouble(metadata, [
        'journey',
        'diagramMarginY',
      ]),
      leftMargin: _nonNegativeDouble(metadata, ['journey', 'leftMargin']),
      maxLabelWidth: _positiveDouble(metadata, ['journey', 'maxLabelWidth']),
      width: _positiveDouble(metadata, ['journey', 'width']),
      height: _positiveDouble(metadata, ['journey', 'height']),
      boxMargin: _nonNegativeDouble(metadata, ['journey', 'boxMargin']),
      boxTextMargin: _nonNegativeDouble(metadata, ['journey', 'boxTextMargin']),
      noteMargin: _nonNegativeDouble(metadata, ['journey', 'noteMargin']),
      messageMargin: _nonNegativeDouble(metadata, ['journey', 'messageMargin']),
      messageAlign: switch (alignment) {
        'left' => JourneyMessageAlign.left,
        'right' => JourneyMessageAlign.right,
        'center' => JourneyMessageAlign.center,
        _ => null,
      },
      bottomMarginAdj: _nonNegativeDouble(metadata, [
        'journey',
        'bottomMarginAdj',
      ]),
      rightAngles: metadata.boolAt(['journey', 'rightAngles']),
      taskFontSize: _positiveDouble(metadata, ['journey', 'taskFontSize']),
      taskFontFamily: metadata.stringAt(['journey', 'taskFontFamily']),
      taskMargin: _nonNegativeDouble(metadata, ['journey', 'taskMargin']),
      activationWidth: _nonNegativeDouble(metadata, [
        'journey',
        'activationWidth',
      ]),
      textPlacement: metadata.stringAt(['journey', 'textPlacement']),
      actorColors: strings('actorColours') ?? strings('actorColors'),
      sectionFills: strings('sectionFills'),
      sectionColors: strings('sectionColours') ?? strings('sectionColors'),
      titleColor: metadata.stringAt(['journey', 'titleColor']),
      titleFontFamily: metadata.stringAt(['journey', 'titleFontFamily']),
      titleFontSize: metadata.stringAt(['journey', 'titleFontSize']),
      useMaxWidth: metadata.boolAt(['journey', 'useMaxWidth']),
      theme: JourneyThemeData(
        fillColors: themeScale('fillType', 8),
        actorColors: themeScale('actor', 6),
        sectionTextColors: themeScale('section', 8),
        faceColor: metadata.stringAt(['themeVariables', 'faceColor']),
        textColor: metadata.stringAt(['themeVariables', 'textColor']),
        lineColor: metadata.stringAt(['themeVariables', 'lineColor']),
        titleColor: metadata.stringAt(['themeVariables', 'titleColor']),
        nodeBorder: metadata.stringAt(['themeVariables', 'nodeBorder']),
      ),
    );
  }

  MindmapChartData? _configureMindmap(
    MindmapChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    List<String?> scale(String prefix) => List.generate(
      12,
      (index) => metadata.stringAt(['themeVariables', '$prefix$index']),
      growable: false,
    );
    return data.copyWith(
      title: title ?? data.title,
      padding: _nonNegativeDouble(metadata, ['mindmap', 'padding']),
      maxNodeWidth: _positiveDouble(metadata, ['mindmap', 'maxNodeWidth']),
      layoutAlgorithm: metadata.stringAt(['mindmap', 'layoutAlgorithm']),
      useMaxWidth: metadata.boolAt(['mindmap', 'useMaxWidth']),
      look: metadata.stringAt(['look']),
      theme: MindmapThemeData(
        colors: scale('cScale'),
        inverseColors: scale('cScaleInv'),
        labelColors: scale('cScaleLabel'),
        lineColors: scale('lineColor'),
        rootColor: metadata.stringAt(['themeVariables', 'git0']),
        rootLabelColor: metadata.stringAt([
          'themeVariables',
          'gitBranchLabel0',
        ]),
        nodeBorder: metadata.stringAt(['themeVariables', 'nodeBorder']),
        mainBackground: metadata.stringAt(['themeVariables', 'mainBkg']),
        gradientStart: metadata.stringAt(['themeVariables', 'gradientStart']),
        gradientStop: metadata.stringAt(['themeVariables', 'gradientStop']),
        useGradient:
            metadata.boolAt(['themeVariables', 'useGradient']) ?? false,
        strokeWidth:
            _nonNegativeDouble(metadata, ['themeVariables', 'strokeWidth']) ??
            2,
      ),
    );
  }

  RequirementDiagramData? _configureRequirement(
    RequirementDiagramData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    List<String> colors(String key) {
      final raw = metadata.valueAt(['themeVariables', key]);
      return raw is List
          ? raw.whereType<Object>().map((value) => '$value').toList()
          : const [];
    }

    return data.copyWith(
      title: title ?? data.title,
      rectFill: metadata.stringAt(['requirement', 'rect_fill']),
      textColor: metadata.stringAt(['requirement', 'text_color']),
      rectBorderSize: metadata.stringAt(['requirement', 'rect_border_size']),
      rectBorderColor: metadata.stringAt(['requirement', 'rect_border_color']),
      rectMinWidth: _positiveDouble(metadata, [
        'requirement',
        'rect_min_width',
      ]),
      rectMinHeight: _positiveDouble(metadata, [
        'requirement',
        'rect_min_height',
      ]),
      fontSize: _positiveDouble(metadata, ['requirement', 'fontSize']),
      rectPadding: _nonNegativeDouble(metadata, [
        'requirement',
        'rect_padding',
      ]),
      lineHeight: _positiveDouble(metadata, ['requirement', 'line_height']),
      useMaxWidth: metadata.boolAt(['requirement', 'useMaxWidth']),
      look: metadata.stringAt(['look']),
      theme: RequirementThemeData(
        background: metadata.stringAt([
          'themeVariables',
          'requirementBackground',
        ]),
        borderColor: metadata.stringAt([
          'themeVariables',
          'requirementBorderColor',
        ]),
        borderSize: metadata.stringAt([
          'themeVariables',
          'requirementBorderSize',
        ]),
        textColor: metadata.stringAt([
          'themeVariables',
          'requirementTextColor',
        ]),
        relationColor: metadata.stringAt(['themeVariables', 'relationColor']),
        relationLabelBackground: metadata.stringAt([
          'themeVariables',
          'relationLabelBackground',
        ]),
        relationLabelColor: metadata.stringAt([
          'themeVariables',
          'relationLabelColor',
        ]),
        edgeLabelBackground: metadata.stringAt([
          'themeVariables',
          'edgeLabelBackground',
        ]),
        requirementEdgeLabelBackground: metadata.stringAt([
          'themeVariables',
          'requirementEdgeLabelBackground',
        ]),
        nodeBorder: metadata.stringAt(['themeVariables', 'nodeBorder']),
        backgroundColors: colors('bkgColorArray'),
        borderColors: colors('borderColorArray'),
        strokeWidth:
            _nonNegativeDouble(metadata, ['themeVariables', 'strokeWidth']) ??
            1,
      ),
    );
  }

  ErDiagramData? _configureEr(
    ErDiagramData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    List<String> colors(String key) {
      final value = metadata.valueAt(['themeVariables', key]);
      return value is List
          ? value.whereType<Object>().map((item) => '$item').toList()
          : const [];
    }

    final direction = metadata.stringAt(['er', 'layoutDirection']);
    return data.copyWith(
      title: title ?? data.title,
      titleTopMargin: _nonNegativeDouble(metadata, ['er', 'titleTopMargin']),
      diagramPadding: _nonNegativeDouble(metadata, ['er', 'diagramPadding']),
      layoutDirection: const {'TB', 'BT', 'LR', 'RL'}.contains(direction)
          ? direction
          : null,
      minEntityWidth: _nonNegativeDouble(metadata, ['er', 'minEntityWidth']),
      minEntityHeight: _nonNegativeDouble(metadata, ['er', 'minEntityHeight']),
      entityPadding: _nonNegativeDouble(metadata, ['er', 'entityPadding']),
      nodeSpacing: _nonNegativeDouble(metadata, ['er', 'nodeSpacing']),
      rankSpacing: _nonNegativeDouble(metadata, ['er', 'rankSpacing']),
      stroke: metadata.stringAt(['er', 'stroke']),
      fill: metadata.stringAt(['er', 'fill']),
      fontSize: _nonNegativeDouble(metadata, ['er', 'fontSize']),
      useMaxWidth: metadata.boolAt(['er', 'useMaxWidth']),
      look: metadata.stringAt(['look']),
      theme: ErThemeData(
        mainBackground: metadata.stringAt(['themeVariables', 'mainBkg']),
        nodeBorder: metadata.stringAt(['themeVariables', 'nodeBorder']),
        nodeTextColor: metadata.stringAt(['themeVariables', 'nodeTextColor']),
        textColor: metadata.stringAt(['themeVariables', 'textColor']),
        lineColor: metadata.stringAt(['themeVariables', 'lineColor']),
        tertiaryColor: metadata.stringAt(['themeVariables', 'tertiaryColor']),
        edgeLabelBackground: metadata.stringAt([
          'themeVariables',
          'edgeLabelBackground',
        ]),
        erEdgeLabelBackground: metadata.stringAt([
          'themeVariables',
          'erEdgeLabelBackground',
        ]),
        backgroundColors: colors('bkgColorArray'),
        borderColors: colors('borderColorArray'),
        strokeWidth:
            _nonNegativeDouble(metadata, ['themeVariables', 'strokeWidth']) ??
            1,
      ),
    );
  }

  StateDiagramData? _configureState(
    StateDiagramData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    double? number(String key) => _nonNegativeDouble(metadata, ['state', key]);
    return data.copyWith(
      title: title ?? data.title,
      titleTopMargin: number('titleTopMargin'),
      arrowMarkerAbsolute: metadata.boolAt(['state', 'arrowMarkerAbsolute']),
      dividerMargin: number('dividerMargin'),
      sizeUnit: number('sizeUnit'),
      padding: number('padding'),
      textHeight: number('textHeight'),
      titleShift: metadata.numberAt(['state', 'titleShift'])?.toDouble(),
      noteMargin: number('noteMargin'),
      nodeSpacing: number('nodeSpacing'),
      rankSpacing: number('rankSpacing'),
      forkWidth: number('forkWidth'),
      forkHeight: number('forkHeight'),
      miniPadding: number('miniPadding'),
      fontSizeFactor: number('fontSizeFactor'),
      fontSize: number('fontSize'),
      labelHeight: number('labelHeight'),
      edgeLengthFactor: metadata.stringAt(['state', 'edgeLengthFactor']),
      compositeTitleSize: number('compositTitleSize'),
      radius: number('radius'),
      defaultRenderer: metadata.stringAt(['state', 'defaultRenderer']),
      useMaxWidth: metadata.boolAt(['state', 'useMaxWidth']),
      look: metadata.stringAt(['look']),
      theme: StateThemeData(
        stateBackground: metadata.stringAt(['themeVariables', 'stateBkg']),
        stateBorder: metadata.stringAt(['themeVariables', 'stateBorder']),
        stateLabelColor: metadata.stringAt([
          'themeVariables',
          'stateLabelColor',
        ]),
        compositeBackground: metadata.stringAt([
          'themeVariables',
          'compositeBackground',
        ]),
        compositeTitleBackground: metadata.stringAt([
          'themeVariables',
          'compositeTitleBackground',
        ]),
        noteBackground: metadata.stringAt(['themeVariables', 'noteBkgColor']),
        noteBorder: metadata.stringAt(['themeVariables', 'noteBorderColor']),
        noteText: metadata.stringAt(['themeVariables', 'noteTextColor']),
        specialStateColor: metadata.stringAt([
          'themeVariables',
          'specialStateColor',
        ]),
        innerEndBackground: metadata.stringAt([
          'themeVariables',
          'innerEndBackground',
        ]),
        transitionColor: metadata.stringAt([
          'themeVariables',
          'transitionColor',
        ]),
        transitionLabelColor: metadata.stringAt([
          'themeVariables',
          'transitionLabelColor',
        ]),
        edgeLabelBackground: metadata.stringAt([
          'themeVariables',
          'edgeLabelBackground',
        ]),
        lineColor: metadata.stringAt(['themeVariables', 'lineColor']),
        textColor: metadata.stringAt(['themeVariables', 'textColor']),
        strokeWidth:
            number('strokeWidth') ??
            _nonNegativeDouble(metadata, ['themeVariables', 'strokeWidth']) ??
            1,
      ),
    );
  }

  ClassDiagramData? _configureClass(
    ClassDiagramData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    double? number(String key) => _nonNegativeDouble(metadata, ['class', key]);
    return data.copyWith(
      title: title ?? data.title,
      titleTopMargin: number('titleTopMargin'),
      arrowMarkerAbsolute: metadata.boolAt(['class', 'arrowMarkerAbsolute']),
      dividerMargin: number('dividerMargin'),
      padding: number('padding'),
      textHeight: number('textHeight'),
      defaultRenderer: metadata.stringAt(['class', 'defaultRenderer']),
      nodeSpacing: number('nodeSpacing'),
      rankSpacing: number('rankSpacing'),
      diagramPadding: number('diagramPadding'),
      htmlLabels: metadata.boolAt(['class', 'htmlLabels']),
      hideEmptyMembersBox: metadata.boolAt(['class', 'hideEmptyMembersBox']),
      hierarchicalNamespaces: metadata.boolAt([
        'class',
        'hierarchicalNamespaces',
      ]),
      useMaxWidth: metadata.boolAt(['class', 'useMaxWidth']),
      look: metadata.stringAt(['look']),
      theme: ClassThemeData(
        mainBackground: metadata.stringAt(['themeVariables', 'mainBkg']),
        nodeBorder: metadata.stringAt(['themeVariables', 'nodeBorder']),
        classText: metadata.stringAt(['themeVariables', 'classText']),
        textColor: metadata.stringAt(['themeVariables', 'textColor']),
        lineColor: metadata.stringAt(['themeVariables', 'lineColor']),
        edgeLabelBackground: metadata.stringAt([
          'themeVariables',
          'edgeLabelBackground',
        ]),
        clusterBackground: metadata.stringAt(['themeVariables', 'clusterBkg']),
        clusterBorder: metadata.stringAt(['themeVariables', 'clusterBorder']),
        titleColor: metadata.stringAt(['themeVariables', 'titleColor']),
        noteBackground: metadata.stringAt(['themeVariables', 'noteBkgColor']),
        noteBorder: metadata.stringAt(['themeVariables', 'noteBorderColor']),
        noteText: metadata.stringAt(['themeVariables', 'noteTextColor']),
        strokeWidth:
            _nonNegativeDouble(metadata, ['themeVariables', 'strokeWidth']) ??
            1,
      ),
    );
  }

  RailroadChartData? _configureRailroad(
    RailroadChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    double? number(String key) =>
        _nonNegativeDouble(metadata, ['railroad', key]);
    String? themed(String key, List<String> fallbacks) {
      final configured = metadata.stringAt(['railroad', key]);
      if (configured != null) return configured;
      for (final fallback in fallbacks) {
        final value = metadata.stringAt(['themeVariables', fallback]);
        if (value != null) return value;
      }
      return null;
    }

    final rawThemeFontSize = metadata.valueAt(['themeVariables', 'fontSize']);
    final themeFontSize = rawThemeFontSize is num
        ? rawThemeFontSize.toDouble()
        : double.tryParse(
            '$rawThemeFontSize'.replaceAll(RegExp(r'[^0-9.]'), ''),
          );
    return data.copyWith(
      title: title ?? data.title,
      compactMode: metadata.boolAt(['railroad', 'compactMode']),
      padding: number('padding'),
      verticalSeparation: number('verticalSeparation'),
      horizontalSeparation: number('horizontalSeparation'),
      arcRadius: number('arcRadius'),
      fontSize: number('fontSize') ?? themeFontSize,
      fontFamily:
          metadata.stringAt(['railroad', 'fontFamily']) ??
          metadata.stringAt(['themeVariables', 'fontFamily']),
      terminalFill: themed('terminalFill', ['secondBkg', 'secondaryColor']),
      terminalStroke: themed('terminalStroke', [
        'secondaryBorderColor',
        'lineColor',
      ]),
      terminalTextColor: themed('terminalTextColor', [
        'secondaryTextColor',
        'textColor',
      ]),
      nonTerminalFill: themed('nonTerminalFill', ['mainBkg', 'background']),
      nonTerminalStroke: themed('nonTerminalStroke', [
        'primaryBorderColor',
        'lineColor',
      ]),
      nonTerminalTextColor: themed('nonTerminalTextColor', [
        'primaryTextColor',
        'textColor',
      ]),
      lineColor: themed('lineColor', ['lineColor']),
      strokeWidth: number('strokeWidth'),
      markerFill: themed('markerFill', ['lineColor']),
      commentFill: themed('commentFill', ['labelBackground', 'tertiaryColor']),
      commentStroke: themed('commentStroke', [
        'tertiaryBorderColor',
        'lineColor',
      ]),
      commentTextColor: themed('commentTextColor', [
        'tertiaryTextColor',
        'textColor',
      ]),
      specialFill: themed('specialFill', ['tertiaryColor', 'secondaryColor']),
      specialStroke: themed('specialStroke', [
        'tertiaryBorderColor',
        'secondaryBorderColor',
      ]),
      ruleNameColor: themed('ruleNameColor', ['titleColor', 'textColor']),
      showMarkers: metadata.boolAt(['railroad', 'showMarkers']),
      markerRadius: number('markerRadius'),
      useMaxWidth: metadata.boolAt(['railroad', 'useMaxWidth']),
    );
  }

  BlockChartData? _configureBlock(
    BlockChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    return data.copyWith(
      title: title ?? data.title,
      padding: _nonNegativeDouble(metadata, ['block', 'padding']),
      useMaxWidth: metadata.boolAt(['block', 'useMaxWidth']),
    );
  }

  EventModelingChartData? _configureEventModeling(
    EventModelingChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    String? theme(String key) => metadata.stringAt(['themeVariables', key]);
    return data.copyWith(
      title: title ?? data.title,
      padding: _nonNegativeDouble(metadata, ['eventmodeling', 'padding']),
      rowHeight: _positiveDouble(metadata, ['eventmodeling', 'rowHeight']),
      useMaxWidth: metadata.boolAt(['eventmodeling', 'useMaxWidth']),
      theme: EventModelingThemeData(
        uiFill: theme('emUiFill'),
        uiStroke: theme('emUiStroke'),
        processorFill: theme('emProcessorFill'),
        processorStroke: theme('emProcessorStroke'),
        readModelFill: theme('emReadModelFill'),
        readModelStroke: theme('emReadModelStroke'),
        commandFill: theme('emCommandFill'),
        commandStroke: theme('emCommandStroke'),
        eventFill: theme('emEventFill'),
        eventStroke: theme('emEventStroke'),
        relationStroke: theme('emRelationStroke'),
        swimlaneBackgroundOdd: theme('emSwimlaneBackgroundOdd'),
        swimlaneBackgroundStroke: theme('emSwimlaneBackgroundStroke'),
        arrowhead: theme('emArrowhead'),
        textColor: theme('textColor'),
      ),
    );
  }

  (MermaidDiagramData, SequenceChartData?) _configureSequence(
    MermaidDiagramData diagram,
    SequenceChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null || diagram.type != DiagramType.sequence) {
      return (diagram, data);
    }
    final fallback = data.config;
    SequenceTextAlign alignment(String key, SequenceTextAlign fallbackValue) {
      return switch (metadata.stringAt(['sequence', key])) {
        'left' => SequenceTextAlign.left,
        'right' => SequenceTextAlign.right,
        'center' => SequenceTextAlign.center,
        _ => fallbackValue,
      };
    }

    double fontSize(String key, double fallbackValue) {
      final raw = metadata.stringAt(['sequence', key]);
      if (raw == null) return fallbackValue;
      final match = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(raw);
      final value = double.tryParse(match?.group(1) ?? '');
      return value != null && value > 0 ? value : fallbackValue;
    }

    final config = fallback.copyWith(
      arrowMarkerAbsolute: metadata.boolAt(['sequence', 'arrowMarkerAbsolute']),
      hideUnusedParticipants: metadata.boolAt([
        'sequence',
        'hideUnusedParticipants',
      ]),
      activationWidth: _nonNegativeDouble(metadata, [
        'sequence',
        'activationWidth',
      ]),
      diagramMarginX: _nonNegativeDouble(metadata, [
        'sequence',
        'diagramMarginX',
      ]),
      diagramMarginY: _nonNegativeDouble(metadata, [
        'sequence',
        'diagramMarginY',
      ]),
      actorMargin: _nonNegativeDouble(metadata, ['sequence', 'actorMargin']),
      width: _positiveDouble(metadata, ['sequence', 'width']),
      height: _positiveDouble(metadata, ['sequence', 'height']),
      boxMargin: _nonNegativeDouble(metadata, ['sequence', 'boxMargin']),
      boxTextMargin: _nonNegativeDouble(metadata, [
        'sequence',
        'boxTextMargin',
      ]),
      noteMargin: _nonNegativeDouble(metadata, ['sequence', 'noteMargin']),
      messageMargin: _nonNegativeDouble(metadata, [
        'sequence',
        'messageMargin',
      ]),
      messageAlign: alignment('messageAlign', fallback.messageAlign),
      mirrorActors: metadata.boolAt(['sequence', 'mirrorActors']),
      forceMenus: metadata.boolAt(['sequence', 'forceMenus']),
      bottomMarginAdjustment: _nonNegativeDouble(metadata, [
        'sequence',
        'bottomMarginAdj',
      ]),
      useMaxWidth: metadata.boolAt(['sequence', 'useMaxWidth']),
      rightAngles: metadata.boolAt(['sequence', 'rightAngles']),
      showSequenceNumbers: metadata.boolAt(['sequence', 'showSequenceNumbers']),
      actorFontSize: fontSize('actorFontSize', fallback.actorFontSize),
      actorFontFamily: metadata.stringAt(['sequence', 'actorFontFamily']),
      actorFontWeight: metadata.stringAt(['sequence', 'actorFontWeight']),
      noteFontSize: fontSize('noteFontSize', fallback.noteFontSize),
      noteFontFamily: metadata.stringAt(['sequence', 'noteFontFamily']),
      noteFontWeight: metadata.stringAt(['sequence', 'noteFontWeight']),
      noteAlign: alignment('noteAlign', fallback.noteAlign),
      messageFontSize: fontSize('messageFontSize', fallback.messageFontSize),
      messageFontFamily: metadata.stringAt(['sequence', 'messageFontFamily']),
      messageFontWeight: metadata.stringAt(['sequence', 'messageFontWeight']),
      wrap: metadata.boolAt(['sequence', 'wrap']),
      wrapPadding: _nonNegativeDouble(metadata, ['sequence', 'wrapPadding']),
      labelBoxWidth: _positiveDouble(metadata, ['sequence', 'labelBoxWidth']),
      labelBoxHeight: _positiveDouble(metadata, ['sequence', 'labelBoxHeight']),
      semanticRowCount: data.events.length,
    );
    var configuredData = data.copyWith(config: config);
    var configuredDiagram = diagram.copyWith(
      title: title,
      sequenceConfig: config,
    );
    if (config.hideUnusedParticipants) {
      final used = <String>{};
      for (final edge in diagram.edges) {
        used
          ..add(edge.from)
          ..add(edge.to);
      }
      for (final event in data.events) {
        switch (event) {
          case SequenceNoteData():
            used.addAll(event.actors);
          case SequenceActivationData():
            used.add(event.actor);
          case SequenceLifecycleData():
            used.add(event.actor);
          case SequenceMessageEventData() || SequenceFragmentData():
            break;
        }
      }
      configuredData = SequenceChartData(
        participants: data.participants
            .where((participant) => used.contains(participant.id))
            .toList(growable: false),
        events: data.events,
        autoNumber: data.autoNumber,
        autoNumberStart: data.autoNumberStart,
        autoNumberStep: data.autoNumberStep,
        config: config,
        boxes: data.boxes,
        accessibilityTitle: data.accessibilityTitle,
        accessibilityDescription: data.accessibilityDescription,
      );
      configuredDiagram = configuredDiagram.copyWith(
        nodes: diagram.nodes
            .where((node) => used.contains(node.id))
            .toList(growable: false),
      );
    }
    return (configuredDiagram, configuredData);
  }

  MermaidDiagramData _configureFlowchartDiagram(
    MermaidDiagramData diagram,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (diagram.type != DiagramType.flowchart &&
        diagram.type != DiagramType.swimlanes) {
      return title == null ? diagram : diagram.copyWith(title: title);
    }
    final fallback = diagram.flowchartConfig ?? const FlowchartConfig();
    final curveName = metadata.stringAt(['flowchart', 'curve']);
    final rendererName = metadata.stringAt(['flowchart', 'defaultRenderer']);
    final curve = FlowchartCurve.values
        .where((value) => value.name == curveName)
        .firstOrNull;
    final renderer = switch (rendererName) {
      'dagre-d3' => FlowchartRenderer.dagreD3,
      'dagre-wrapper' => FlowchartRenderer.dagreWrapper,
      'elk' => FlowchartRenderer.elk,
      _ => null,
    };
    final globalHtmlLabels = metadata.boolAt(['htmlLabels']);
    final config = fallback.copyWith(
      titleTopMargin: _nonNegativeDouble(metadata, [
        'flowchart',
        'titleTopMargin',
      ]),
      subgraphTitleMarginTop: _nonNegativeDouble(metadata, [
        'flowchart',
        'subGraphTitleMargin',
        'top',
      ]),
      subgraphTitleMarginBottom: _nonNegativeDouble(metadata, [
        'flowchart',
        'subGraphTitleMargin',
        'bottom',
      ]),
      arrowMarkerAbsolute: metadata.boolAt([
        'flowchart',
        'arrowMarkerAbsolute',
      ]),
      diagramPadding: _nonNegativeDouble(metadata, [
        'flowchart',
        'diagramPadding',
      ]),
      htmlLabels:
          globalHtmlLabels ?? metadata.boolAt(['flowchart', 'htmlLabels']),
      nodeSpacing: _nonNegativeDouble(metadata, ['flowchart', 'nodeSpacing']),
      rankSpacing: _nonNegativeDouble(metadata, ['flowchart', 'rankSpacing']),
      curve: curve,
      padding: _nonNegativeDouble(metadata, ['flowchart', 'padding']),
      useMaxWidth: metadata.boolAt(['flowchart', 'useMaxWidth']),
      defaultRenderer: renderer,
      wrappingWidth: _positiveDouble(metadata, ['flowchart', 'wrappingWidth']),
      inheritDirection: metadata.boolAt(['flowchart', 'inheritDir']),
    );
    return diagram.copyWith(
      title: title,
      flowchartConfig: config,
      style: diagram.style.copyWith(padding: config.diagramPadding),
    );
  }

  PieChartData? _configurePie(
    PieChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final donutHole = metadata.numberAt(['pie', 'donutHole'])?.toDouble();
    final textPosition = metadata.numberAt(['pie', 'textPosition'])?.toDouble();
    final legendName = metadata.stringAt(['pie', 'legendPosition']);
    PieLegendPosition? legendPosition;
    for (final value in PieLegendPosition.values) {
      if (value.name == legendName) legendPosition = value;
    }
    double? themeNumber(String key) {
      final raw = metadata.stringAt(['themeVariables', key]);
      if (raw == null) return null;
      return double.tryParse(raw.trim().replaceFirst(RegExp(r'px$'), ''));
    }

    final colors = <int, String>{};
    for (var index = 1; index <= 12; index++) {
      final color = metadata.stringAt(['themeVariables', 'pie$index']);
      if (color != null) colors[index - 1] = color;
    }
    final opacity = themeNumber('pieOpacity');
    final theme = PieThemeData(
      colors: colors,
      titleTextSize: themeNumber('pieTitleTextSize'),
      titleTextColor: metadata.stringAt([
        'themeVariables',
        'pieTitleTextColor',
      ]),
      sectionTextSize: themeNumber('pieSectionTextSize'),
      sectionTextColor: metadata.stringAt([
        'themeVariables',
        'pieSectionTextColor',
      ]),
      legendTextSize: themeNumber('pieLegendTextSize'),
      legendTextColor: metadata.stringAt([
        'themeVariables',
        'pieLegendTextColor',
      ]),
      strokeColor: metadata.stringAt(['themeVariables', 'pieStrokeColor']),
      strokeWidth: themeNumber('pieStrokeWidth'),
      outerStrokeColor: metadata.stringAt([
        'themeVariables',
        'pieOuterStrokeColor',
      ]),
      outerStrokeWidth: themeNumber('pieOuterStrokeWidth'),
      opacity: opacity?.clamp(0, 1),
    );
    return PieChartData(
      title: title ?? data.title,
      slices: data.slices,
      showValuesInLegend: data.showValuesInLegend,
      accessibilityTitle: data.accessibilityTitle,
      accessibilityDescription: data.accessibilityDescription,
      donutHole: donutHole != null && donutHole >= 0 && donutHole <= 0.9
          ? donutHole
          : data.donutHole,
      textPosition:
          textPosition != null && textPosition >= 0 && textPosition <= 1
          ? textPosition
          : data.textPosition,
      legendPosition: legendPosition ?? data.legendPosition,
      highlightSlice:
          metadata.stringAt(['pie', 'highlightSlice']) ?? data.highlightSlice,
      useMaxWidth: metadata.boolAt(['pie', 'useMaxWidth']) ?? data.useMaxWidth,
      theme: theme,
    );
  }

  KanbanChartData? _configureKanban(
    KanbanChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    return data.copyWith(
      title: title ?? data.title,
      ticketBaseUrl:
          metadata.stringAt(['kanban', 'ticketBaseUrl']) ?? data.ticketBaseUrl,
      padding: _nonNegativeDouble(metadata, ['kanban', 'padding']),
      sectionWidth: _positiveDouble(metadata, ['kanban', 'sectionWidth']),
      useMaxWidth: metadata.boolAt(['kanban', 'useMaxWidth']),
    );
  }

  PacketChartData? _configurePacket(
    PacketChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final rowHeight = _positiveDouble(metadata, ['packet', 'rowHeight']);
    final bitWidth = _positiveDouble(metadata, ['packet', 'bitWidth']);
    final bitsValue = metadata.numberAt(['packet', 'bitsPerRow']);
    final bitsPerRow =
        bitsValue != null &&
            bitsValue > 0 &&
            bitsValue == bitsValue.roundToDouble()
        ? bitsValue.toInt()
        : null;
    final paddingX = _nonNegativeDouble(metadata, ['packet', 'paddingX']);
    final paddingY = _nonNegativeDouble(metadata, ['packet', 'paddingY']);
    double? themeNumber(String key) {
      final raw = metadata.stringAt(['themeVariables', 'packet', key]);
      if (raw == null) return null;
      return double.tryParse(raw.trim().replaceFirst(RegExp(r'px$'), ''));
    }

    final theme = PacketThemeData(
      byteFontSize: themeNumber('byteFontSize'),
      startByteColor: metadata.stringAt([
        'themeVariables',
        'packet',
        'startByteColor',
      ]),
      endByteColor: metadata.stringAt([
        'themeVariables',
        'packet',
        'endByteColor',
      ]),
      labelColor: metadata.stringAt(['themeVariables', 'packet', 'labelColor']),
      labelFontSize: themeNumber('labelFontSize'),
      titleColor: metadata.stringAt(['themeVariables', 'packet', 'titleColor']),
      titleFontSize: themeNumber('titleFontSize'),
      blockStrokeColor: metadata.stringAt([
        'themeVariables',
        'packet',
        'blockStrokeColor',
      ]),
      blockStrokeWidth: themeNumber('blockStrokeWidth'),
      blockFillColor: metadata.stringAt([
        'themeVariables',
        'packet',
        'blockFillColor',
      ]),
    );
    return data.copyWith(
      title: title ?? data.title,
      rowHeight: rowHeight,
      bitWidth: bitWidth,
      bitsPerRow: bitsPerRow,
      showBits: metadata.boolAt(['packet', 'showBits']),
      paddingX: paddingX,
      paddingY: paddingY,
      useMaxWidth: metadata.boolAt(['packet', 'useMaxWidth']),
      theme: theme,
    );
  }

  IshikawaChartData? _configureIshikawa(
    IshikawaChartData? data,
    MermaidFrontmatter metadata,
  ) {
    if (data == null) return null;
    final fontSizeSource = metadata.stringAt(['fontSize']);
    final fontSize = fontSizeSource == null
        ? null
        : double.tryParse(
            fontSizeSource.trim().replaceFirst(RegExp(r'px$'), ''),
          );
    final seed = metadata.numberAt(['handDrawnSeed']);
    return data.copyWith(
      diagramPadding: _nonNegativeDouble(metadata, [
        'ishikawa',
        'diagramPadding',
      ]),
      useMaxWidth: metadata.boolAt(['ishikawa', 'useMaxWidth']),
      handDrawn: metadata.stringAt(['look']) == 'handDrawn' ? true : null,
      handDrawnSeed: seed != null && seed.isFinite ? seed.toInt() : null,
      fontSize: fontSize != null && fontSize > 0 ? fontSize : null,
      lineColor: metadata.stringAt(['themeVariables', 'lineColor']),
      fillColor: metadata.stringAt(['themeVariables', 'mainBkg']),
      textColor: metadata.stringAt(['themeVariables', 'textColor']),
    );
  }

  double? _positiveDouble(MermaidFrontmatter metadata, List<String> path) {
    final value = metadata.numberAt(path)?.toDouble();
    return value != null && value > 0 ? value : null;
  }

  double? _nonNegativeDouble(MermaidFrontmatter metadata, List<String> path) {
    final value = metadata.numberAt(path)?.toDouble();
    return value != null && value >= 0 ? value : null;
  }

  SankeyChartData? _configureSankey(
    SankeyChartData? data,
    MermaidFrontmatter metadata,
  ) {
    if (data == null) return null;
    final alignmentName = metadata.stringAt(['sankey', 'nodeAlignment']);
    SankeyNodeAlignment? alignment;
    for (final value in SankeyNodeAlignment.values) {
      if (value.name == alignmentName) alignment = value;
    }
    final labelName = metadata.stringAt(['sankey', 'labelStyle']);
    SankeyLabelStyle? labelStyle;
    for (final value in SankeyLabelStyle.values) {
      if (value.name == labelName) labelStyle = value;
    }
    final rawColors = metadata.valueAt(['sankey', 'nodeColors']);
    final nodeColors = rawColors is Map<String, Object?>
        ? <String, String>{
            for (final entry in rawColors.entries)
              if (entry.value is String) entry.key: entry.value! as String,
          }
        : null;
    return data.copyWith(
      width: _positiveDouble(metadata, ['sankey', 'width']),
      height: _positiveDouble(metadata, ['sankey', 'height']),
      linkColor: metadata.stringAt(['sankey', 'linkColor']),
      nodeAlignment: alignment,
      useMaxWidth: metadata.boolAt(['sankey', 'useMaxWidth']),
      showValues: metadata.boolAt(['sankey', 'showValues']),
      prefix: metadata.stringAt(['sankey', 'prefix']),
      suffix: metadata.stringAt(['sankey', 'suffix']),
      nodeWidth: _positiveDouble(metadata, ['sankey', 'nodeWidth']),
      nodePadding: _nonNegativeDouble(metadata, ['sankey', 'nodePadding']),
      labelStyle: labelStyle,
      nodeColors: nodeColors,
    );
  }

  GitGraphChartData? _configureGitGraph(
    GitGraphChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final topMargin = metadata.numberAt(['gitGraph', 'titleTopMargin']);
    final nodeLabel = metadata.valueAt(['gitGraph', 'nodeLabel']);
    double? labelNumber(String key) {
      final value = nodeLabel is Map<String, Object?> ? nodeLabel[key] : null;
      return value is num && value.isFinite ? value.toDouble() : null;
    }

    double? themeFont(String key) {
      final source = metadata.stringAt(['themeVariables', key]);
      return source == null
          ? null
          : double.tryParse(source.trim().replaceFirst(RegExp(r'px$'), ''));
    }

    List<String?> scale(String prefix) => List<String?>.generate(
      8,
      (index) => metadata.stringAt(['themeVariables', '$prefix$index']),
      growable: false,
    );

    return data.copyWith(
      title: title ?? data.title,
      titleTopMargin:
          topMargin != null &&
              topMargin >= 0 &&
              topMargin == topMargin.roundToDouble()
          ? topMargin.toInt()
          : null,
      diagramPadding: _nonNegativeDouble(metadata, [
        'gitGraph',
        'diagramPadding',
      ]),
      nodeLabelWidth: labelNumber('width'),
      nodeLabelHeight: labelNumber('height'),
      nodeLabelX: labelNumber('x'),
      nodeLabelY: labelNumber('y'),
      mainBranchName: metadata.stringAt(['gitGraph', 'mainBranchName']),
      mainBranchOrder: metadata.numberAt([
        'gitGraph',
        'mainBranchOrder',
      ])?.toDouble(),
      showCommitLabel: metadata.boolAt(['gitGraph', 'showCommitLabel']),
      showBranches: metadata.boolAt(['gitGraph', 'showBranches']),
      rotateCommitLabel: metadata.boolAt(['gitGraph', 'rotateCommitLabel']),
      parallelCommits: metadata.boolAt(['gitGraph', 'parallelCommits']),
      arrowMarkerAbsolute: metadata.boolAt(['gitGraph', 'arrowMarkerAbsolute']),
      useMaxWidth: metadata.boolAt(['gitGraph', 'useMaxWidth']),
      theme: GitGraphThemeData(
        branchColors: scale('git'),
        inverseColors: scale('gitInv'),
        branchLabelColors: scale('gitBranchLabel'),
        lineColor:
            metadata.stringAt(['themeVariables', 'commitLineColor']) ??
            metadata.stringAt(['themeVariables', 'lineColor']),
        titleColor: metadata.stringAt(['themeVariables', 'textColor']),
        tagLabelColor: metadata.stringAt(['themeVariables', 'tagLabelColor']),
        tagLabelBackground: metadata.stringAt([
          'themeVariables',
          'tagLabelBackground',
        ]),
        tagLabelBorder: metadata.stringAt(['themeVariables', 'tagLabelBorder']),
        tagLabelFontSize: themeFont('tagLabelFontSize'),
        commitLabelColor: metadata.stringAt([
          'themeVariables',
          'commitLabelColor',
        ]),
        commitLabelBackground: metadata.stringAt([
          'themeVariables',
          'commitLabelBackground',
        ]),
        commitLabelFontSize: themeFont('commitLabelFontSize'),
        mergeColor: metadata.stringAt(['themeVariables', 'primaryColor']),
      ),
    );
  }

  TreeViewChartData? _configureTreeView(
    TreeViewChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    return data.copyWith(
      title: title ?? data.title,
      rowIndent: _nonNegativeDouble(metadata, ['treeView', 'rowIndent']),
      paddingX: _nonNegativeDouble(metadata, ['treeView', 'paddingX']),
      paddingY: _nonNegativeDouble(metadata, ['treeView', 'paddingY']),
      lineThickness: _nonNegativeDouble(metadata, [
        'treeView',
        'lineThickness',
      ]),
      showIcons: metadata.boolAt(['treeView', 'showIcons']),
      defaultIconPack: metadata.stringAt(['treeView', 'defaultIconPack']),
      filenameIcons: _stringMapAt(metadata, ['treeView', 'filenameIcons']),
      extensionIcons: _stringMapAt(metadata, ['treeView', 'extensionIcons']),
    );
  }

  Map<String, String>? _stringMapAt(
    MermaidFrontmatter metadata,
    List<String> path,
  ) {
    final raw = metadata.valueAt(path);
    if (raw is! Map<String, Object?>) return null;
    return <String, String>{
      for (final entry in raw.entries)
        if (entry.value is String) entry.key: entry.value! as String,
    };
  }

  RadarChartData? _configureRadar(
    RadarChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final tension = metadata.numberAt(['radar', 'curveTension'])?.toDouble();
    double? radarNumber(String key) =>
        metadata.numberAt(['themeVariables', 'radar', key])?.toDouble();
    double? cssNumber(List<String> path) {
      final raw = metadata.stringAt(path);
      return raw == null
          ? null
          : double.tryParse(raw.trim().replaceFirst(RegExp(r'px$'), ''));
    }

    final curveColors = <int, String>{};
    for (var index = 0; index < 12; index++) {
      final value = metadata.stringAt(['themeVariables', 'cScale$index']);
      if (value != null) curveColors[index] = value;
    }
    final radarTheme = RadarThemeData(
      axisColor: metadata.stringAt(['themeVariables', 'radar', 'axisColor']),
      axisStrokeWidth: radarNumber('axisStrokeWidth'),
      axisLabelFontSize: radarNumber('axisLabelFontSize'),
      curveOpacity: radarNumber('curveOpacity'),
      curveStrokeWidth: radarNumber('curveStrokeWidth'),
      graticuleColor: metadata.stringAt([
        'themeVariables',
        'radar',
        'graticuleColor',
      ]),
      graticuleOpacity: radarNumber('graticuleOpacity'),
      graticuleStrokeWidth: radarNumber('graticuleStrokeWidth'),
      legendBoxSize: radarNumber('legendBoxSize'),
      legendFontSize: radarNumber('legendFontSize'),
      titleColor: metadata.stringAt(['themeVariables', 'titleColor']),
      titleFontSize: cssNumber(['themeVariables', 'fontSize']),
      curveColors: curveColors,
    );
    return data.copyWith(
      title: title ?? data.title,
      width: _positiveDouble(metadata, ['radar', 'width']),
      height: _positiveDouble(metadata, ['radar', 'height']),
      marginTop: _nonNegativeDouble(metadata, ['radar', 'marginTop']),
      marginRight: _nonNegativeDouble(metadata, ['radar', 'marginRight']),
      marginBottom: _nonNegativeDouble(metadata, ['radar', 'marginBottom']),
      marginLeft: _nonNegativeDouble(metadata, ['radar', 'marginLeft']),
      axisScaleFactor: _nonNegativeDouble(metadata, [
        'radar',
        'axisScaleFactor',
      ]),
      axisLabelFactor: _nonNegativeDouble(metadata, [
        'radar',
        'axisLabelFactor',
      ]),
      curveTension: tension != null && tension >= 0 && tension <= 1
          ? tension
          : null,
      useMaxWidth: metadata.boolAt(['radar', 'useMaxWidth']),
      theme: radarTheme,
    );
  }

  TimelineChartData? _configureTimeline(
    TimelineChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final alignName = metadata.stringAt(['timeline', 'messageAlign']);
    TimelineMessageAlign? align;
    for (final value in TimelineMessageAlign.values) {
      if (value.name == alignName) align = value;
    }
    return data.copyWith(
      title: title ?? data.title,
      diagramMarginX: _nonNegativeDouble(metadata, [
        'timeline',
        'diagramMarginX',
      ]),
      diagramMarginY: _nonNegativeDouble(metadata, [
        'timeline',
        'diagramMarginY',
      ]),
      leftMargin: _nonNegativeInt(metadata, ['timeline', 'leftMargin']),
      width: _nonNegativeInt(metadata, ['timeline', 'width']),
      height: _nonNegativeInt(metadata, ['timeline', 'height']),
      padding: _nonNegativeDouble(metadata, ['timeline', 'padding']),
      boxMargin: _nonNegativeInt(metadata, ['timeline', 'boxMargin']),
      boxTextMargin: _nonNegativeInt(metadata, ['timeline', 'boxTextMargin']),
      noteMargin: _nonNegativeInt(metadata, ['timeline', 'noteMargin']),
      messageMargin: _nonNegativeInt(metadata, ['timeline', 'messageMargin']),
      messageAlign: align,
      bottomMarginAdj: _nonNegativeInt(metadata, [
        'timeline',
        'bottomMarginAdj',
      ]),
      rightAngles: metadata.boolAt(['timeline', 'rightAngles']),
      taskFontSize: _nonNegativeDouble(metadata, ['timeline', 'taskFontSize']),
      taskFontFamily: metadata.stringAt(['timeline', 'taskFontFamily']),
      taskMargin: _nonNegativeDouble(metadata, ['timeline', 'taskMargin']),
      activationWidth: _nonNegativeDouble(metadata, [
        'timeline',
        'activationWidth',
      ]),
      textPlacement: metadata.stringAt(['timeline', 'textPlacement']),
      actorColours: _stringListAt(metadata, ['timeline', 'actorColours']),
      sectionFills: _stringListAt(metadata, ['timeline', 'sectionFills']),
      sectionColours: _stringListAt(metadata, ['timeline', 'sectionColours']),
      disableMulticolor: metadata.boolAt(['timeline', 'disableMulticolor']),
      useMaxWidth: metadata.boolAt(['timeline', 'useMaxWidth']),
    );
  }

  int? _nonNegativeInt(MermaidFrontmatter metadata, List<String> path) {
    final value = metadata.numberAt(path);
    return value != null && value >= 0 && value == value.roundToDouble()
        ? value.toInt()
        : null;
  }

  List<String>? _stringListAt(MermaidFrontmatter metadata, List<String> path) {
    final raw = metadata.valueAt(path);
    if (raw is! List || raw.any((value) => value is! String)) return null;
    return raw.cast<String>();
  }

  GanttChartData? _configureGantt(
    GanttChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    String? theme(String key) => metadata.stringAt(['themeVariables', key]);
    final sectionFontSize = metadata.numberAt([
      'gantt',
      'sectionFontSize',
    ])?.toDouble();
    final displayMode =
        metadata.displayMode ?? metadata.stringAt(['gantt', 'displayMode']);
    return data.copyWith(
      title: title ?? data.title,
      axisFormat: metadata.stringAt(['gantt', 'axisFormat']),
      tickInterval: metadata.stringAt(['gantt', 'tickInterval']),
      weekday: metadata.stringAt(['gantt', 'weekday']),
      topAxis: metadata.boolAt(['gantt', 'topAxis']),
      titleTopMargin: _nonNegativeInt(metadata, ['gantt', 'titleTopMargin']),
      barHeight: _nonNegativeInt(metadata, ['gantt', 'barHeight']),
      barGap: _nonNegativeInt(metadata, ['gantt', 'barGap']),
      topPadding: _nonNegativeInt(metadata, ['gantt', 'topPadding']),
      rightPadding: _nonNegativeInt(metadata, ['gantt', 'rightPadding']),
      leftPadding: _nonNegativeInt(metadata, ['gantt', 'leftPadding']),
      gridLineStartPadding: _nonNegativeInt(metadata, [
        'gantt',
        'gridLineStartPadding',
      ]),
      fontSize: _nonNegativeInt(metadata, ['gantt', 'fontSize']),
      sectionFontSize: sectionFontSize != null && sectionFontSize >= 0
          ? sectionFontSize
          : null,
      numberSectionStyles: _nonNegativeInt(metadata, [
        'gantt',
        'numberSectionStyles',
      ]),
      useMaxWidth: metadata.boolAt(['gantt', 'useMaxWidth']),
      displayMode: displayMode == 'compact' ? 'compact' : null,
      theme: GanttThemeData(
        sectionBackground: theme('sectionBkgColor'),
        alternateSectionBackground: theme('altSectionBkgColor'),
        sectionBackground2: theme('sectionBkgColor2'),
        excludeBackground: theme('excludeBkgColor'),
        taskBorder: theme('taskBorderColor'),
        taskBackground: theme('taskBkgColor'),
        taskText: theme('taskTextColor'),
        taskTextDark: theme('taskTextDarkColor'),
        taskTextOutside: theme('taskTextOutsideColor'),
        taskTextClickable: theme('taskTextClickableColor'),
        activeTaskBorder: theme('activeTaskBorderColor'),
        activeTaskBackground: theme('activeTaskBkgColor'),
        grid: theme('gridColor'),
        doneTaskBackground: theme('doneTaskBkgColor'),
        doneTaskBorder: theme('doneTaskBorderColor'),
        criticalBorder: theme('critBorderColor'),
        criticalBackground: theme('critBkgColor'),
        todayLine: theme('todayLineColor'),
        verticalLine: theme('vertLineColor'),
        title: theme('titleColor') ?? theme('textColor'),
        text: theme('textColor'),
      ),
    );
  }

  QuadrantChartData? _configureQuadrant(
    QuadrantChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final xPosition = metadata.stringAt(['quadrantChart', 'xAxisPosition']);
    final yPosition = metadata.stringAt(['quadrantChart', 'yAxisPosition']);
    String? theme(String key) => metadata.stringAt(['themeVariables', key]);
    final quadrantTheme = QuadrantThemeData(
      titleFill: theme('quadrantTitleFill'),
      quadrant1Fill: theme('quadrant1Fill'),
      quadrant2Fill: theme('quadrant2Fill'),
      quadrant3Fill: theme('quadrant3Fill'),
      quadrant4Fill: theme('quadrant4Fill'),
      quadrant1TextFill: theme('quadrant1TextFill'),
      quadrant2TextFill: theme('quadrant2TextFill'),
      quadrant3TextFill: theme('quadrant3TextFill'),
      quadrant4TextFill: theme('quadrant4TextFill'),
      pointFill: theme('quadrantPointFill'),
      pointTextFill: theme('quadrantPointTextFill'),
      xAxisTextFill: theme('quadrantXAxisTextFill'),
      yAxisTextFill: theme('quadrantYAxisTextFill'),
      internalBorderStrokeFill: theme('quadrantInternalBorderStrokeFill'),
      externalBorderStrokeFill: theme('quadrantExternalBorderStrokeFill'),
    );
    return data.copyWith(
      title: title ?? data.title,
      chartWidth: _positiveDouble(metadata, ['quadrantChart', 'chartWidth']),
      chartHeight: _positiveDouble(metadata, ['quadrantChart', 'chartHeight']),
      titleFontSize: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'titleFontSize',
      ]),
      titlePadding: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'titlePadding',
      ]),
      quadrantPadding: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'quadrantPadding',
      ]),
      xAxisLabelPadding: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'xAxisLabelPadding',
      ]),
      yAxisLabelPadding: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'yAxisLabelPadding',
      ]),
      xAxisLabelFontSize: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'xAxisLabelFontSize',
      ]),
      yAxisLabelFontSize: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'yAxisLabelFontSize',
      ]),
      quadrantLabelFontSize: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'quadrantLabelFontSize',
      ]),
      quadrantTextTopPadding: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'quadrantTextTopPadding',
      ]),
      pointTextPadding: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'pointTextPadding',
      ]),
      pointLabelFontSize: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'pointLabelFontSize',
      ]),
      pointRadius: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'pointRadius',
      ]),
      xAxisPosition: xPosition == 'top' || xPosition == 'bottom'
          ? xPosition
          : null,
      yAxisPosition: yPosition == 'left' || yPosition == 'right'
          ? yPosition
          : null,
      quadrantInternalBorderStrokeWidth: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'quadrantInternalBorderStrokeWidth',
      ]),
      quadrantExternalBorderStrokeWidth: _nonNegativeDouble(metadata, [
        'quadrantChart',
        'quadrantExternalBorderStrokeWidth',
      ]),
      useMaxWidth: metadata.boolAt(['quadrantChart', 'useMaxWidth']),
      theme: quadrantTheme,
    );
  }

  TreemapChartData? _configureTreemap(
    TreemapChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    List<String?> scale(String prefix) => List<String?>.generate(
      12,
      (index) => metadata.stringAt(['themeVariables', '$prefix$index']),
      growable: false,
    );
    return data.copyWith(
      title: title ?? data.title,
      padding: _nonNegativeDouble(metadata, ['treemap', 'padding']),
      diagramPadding: _nonNegativeDouble(metadata, [
        'treemap',
        'diagramPadding',
      ]),
      showValues: metadata.boolAt(['treemap', 'showValues']),
      nodeWidth: _positiveDouble(metadata, ['treemap', 'nodeWidth']),
      nodeHeight: _positiveDouble(metadata, ['treemap', 'nodeHeight']),
      borderWidth: _nonNegativeDouble(metadata, ['treemap', 'borderWidth']),
      valueFontSize: _nonNegativeDouble(metadata, ['treemap', 'valueFontSize']),
      labelFontSize: _nonNegativeDouble(metadata, ['treemap', 'labelFontSize']),
      valueFormat: metadata.stringAt(['treemap', 'valueFormat']),
      useMaxWidth: metadata.boolAt(['treemap', 'useMaxWidth']),
      theme: TreemapThemeData(
        colors: scale('cScale'),
        peerColors: scale('cScalePeer'),
        labelColors: scale('cScaleLabel'),
        titleColor: metadata.stringAt(['themeVariables', 'titleColor']),
      ),
    );
  }

  VennChartData? _configureVenn(
    VennChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final seed = metadata.numberAt(['handDrawnSeed']);
    return data.copyWith(
      title: title ?? data.title,
      width: _positiveDouble(metadata, ['venn', 'width']),
      height: _positiveDouble(metadata, ['venn', 'height']),
      padding: _nonNegativeDouble(metadata, ['venn', 'padding']),
      useDebugLayout: metadata.boolAt(['venn', 'useDebugLayout']),
      useMaxWidth: metadata.boolAt(['venn', 'useMaxWidth']),
      handDrawn: metadata.stringAt(['look']) == 'handDrawn' ? true : null,
      handDrawnSeed: seed != null && seed.isFinite ? seed.toInt() : null,
      theme: VennThemeData(
        colors: List<String?>.generate(
          8,
          (index) => metadata.stringAt(['themeVariables', 'venn${index + 1}']),
          growable: false,
        ),
        titleTextColor:
            metadata.stringAt(['themeVariables', 'vennTitleTextColor']) ??
            metadata.stringAt(['themeVariables', 'titleColor']),
        setTextColor:
            metadata.stringAt(['themeVariables', 'vennSetTextColor']) ??
            metadata.stringAt(['themeVariables', 'primaryTextColor']) ??
            metadata.stringAt(['themeVariables', 'textColor']),
      ),
    );
  }

  WardleyChartData? _configureWardley(
    WardleyChartData? data,
    MermaidFrontmatter metadata,
  ) {
    if (data == null) return null;
    double? value(String key) =>
        _nonNegativeDouble(metadata, ['wardley', key]) ??
        _nonNegativeDouble(metadata, ['wardley-beta', key]);
    bool? flag(String key) =>
        metadata.boolAt(['wardley', key]) ??
        metadata.boolAt(['wardley-beta', key]);
    return data.copyWith(
      width: value('width'),
      height: value('height'),
      padding: value('padding'),
      nodeRadius: value('nodeRadius'),
      nodeLabelOffset: value('nodeLabelOffset'),
      axisFontSize: value('axisFontSize'),
      labelFontSize: value('labelFontSize'),
      showGrid: flag('showGrid'),
      useMaxWidth: flag('useMaxWidth'),
      theme: WardleyThemeData(
        backgroundColor:
            metadata.stringAt([
              'themeVariables',
              'wardley',
              'backgroundColor',
            ]) ??
            metadata.stringAt(['themeVariables', 'background']),
        axisColor: metadata.stringAt([
          'themeVariables',
          'wardley',
          'axisColor',
        ]),
        axisTextColor:
            metadata.stringAt(['themeVariables', 'wardley', 'axisTextColor']) ??
            metadata.stringAt(['themeVariables', 'primaryTextColor']),
        gridColor: metadata.stringAt([
          'themeVariables',
          'wardley',
          'gridColor',
        ]),
        componentFill: metadata.stringAt([
          'themeVariables',
          'wardley',
          'componentFill',
        ]),
        componentStroke: metadata.stringAt([
          'themeVariables',
          'wardley',
          'componentStroke',
        ]),
        componentLabelColor:
            metadata.stringAt([
              'themeVariables',
              'wardley',
              'componentLabelColor',
            ]) ??
            metadata.stringAt(['themeVariables', 'primaryTextColor']),
        linkStroke: metadata.stringAt([
          'themeVariables',
          'wardley',
          'linkStroke',
        ]),
        evolutionStroke: metadata.stringAt([
          'themeVariables',
          'wardley',
          'evolutionStroke',
        ]),
        annotationStroke: metadata.stringAt([
          'themeVariables',
          'wardley',
          'annotationStroke',
        ]),
        annotationTextColor:
            metadata.stringAt([
              'themeVariables',
              'wardley',
              'annotationTextColor',
            ]) ??
            metadata.stringAt(['themeVariables', 'primaryTextColor']),
        annotationFill:
            metadata.stringAt([
              'themeVariables',
              'wardley',
              'annotationFill',
            ]) ??
            metadata.stringAt(['themeVariables', 'background']),
      ),
    );
  }

  CynefinChartData? _configureCynefin(
    CynefinChartData? data,
    MermaidFrontmatter metadata,
  ) {
    if (data == null) return null;
    final amplitude = _nonNegativeDouble(metadata, [
      'cynefin',
      'boundaryAmplitude',
    ]);
    final seed = metadata.numberAt(['cynefin', 'seed'])?.toDouble();
    return data.copyWith(
      width: _positiveDouble(metadata, ['cynefin', 'width']),
      height: _positiveDouble(metadata, ['cynefin', 'height']),
      padding: _nonNegativeDouble(metadata, ['cynefin', 'padding']),
      showDomainDescriptions: metadata.boolAt([
        'cynefin',
        'showDomainDescriptions',
      ]),
      boundaryAmplitude: amplitude?.clamp(0, 50),
      seed: seed?.isFinite == true ? seed : null,
      useMaxWidth: metadata.boolAt(['cynefin', 'useMaxWidth']),
    );
  }

  XYChartData? _configureXY(
    XYChartData? data,
    MermaidFrontmatter metadata,
    String? title,
  ) {
    if (data == null) return null;
    final orientationName = metadata.stringAt(['xyChart', 'chartOrientation']);
    final reserved = metadata.numberAt([
      'xyChart',
      'plotReservedSpacePercent',
    ])?.toDouble();
    String? themeValue(String key) =>
        metadata.stringAt(['themeVariables', 'xyChart', key]);
    final palette = themeValue('plotColorPalette')
        ?.split(',')
        .map((color) => color.trim())
        .where((color) => color.isNotEmpty)
        .toList(growable: false);
    return data.copyWith(
      title: title ?? data.title,
      width: _positiveDouble(metadata, ['xyChart', 'width']),
      height: _positiveDouble(metadata, ['xyChart', 'height']),
      titleFontSize: _positiveDouble(metadata, ['xyChart', 'titleFontSize']),
      titlePadding: _nonNegativeDouble(metadata, ['xyChart', 'titlePadding']),
      showDataLabel: metadata.boolAt(['xyChart', 'showDataLabel']),
      showDataLabelOutsideBar: metadata.boolAt([
        'xyChart',
        'showDataLabelOutsideBar',
      ]),
      showTitle: metadata.boolAt(['xyChart', 'showTitle']),
      xAxisStyle: _xyAxisStyle(metadata, 'xAxis', data.xAxisStyle),
      yAxisStyle: _xyAxisStyle(metadata, 'yAxis', data.yAxisStyle),
      orientation: switch (orientationName) {
        'horizontal' => XYChartOrientation.horizontal,
        'vertical' => XYChartOrientation.vertical,
        _ => null,
      },
      plotReservedSpacePercent: reserved != null && reserved >= 30
          ? reserved
          : null,
      theme: XYChartThemeData(
        backgroundColor: themeValue('backgroundColor'),
        titleColor: themeValue('titleColor'),
        dataLabelColor: themeValue('dataLabelColor'),
        xAxisLabelColor: themeValue('xAxisLabelColor'),
        xAxisTitleColor: themeValue('xAxisTitleColor'),
        xAxisTickColor: themeValue('xAxisTickColor'),
        xAxisLineColor: themeValue('xAxisLineColor'),
        yAxisLabelColor: themeValue('yAxisLabelColor'),
        yAxisTitleColor: themeValue('yAxisTitleColor'),
        yAxisTickColor: themeValue('yAxisTickColor'),
        yAxisLineColor: themeValue('yAxisLineColor'),
        plotColorPalette: palette ?? const [],
      ),
    );
  }

  XYChartAxisStyle _xyAxisStyle(
    MermaidFrontmatter metadata,
    String axis,
    XYChartAxisStyle fallback,
  ) {
    double positive(String key, double value) =>
        _positiveDouble(metadata, ['xyChart', axis, key]) ?? value;
    double nonNegative(String key, double value) =>
        _nonNegativeDouble(metadata, ['xyChart', axis, key]) ?? value;
    final rotation = metadata.numberAt([
      'xyChart',
      axis,
      'labelRotation',
    ])?.toDouble();
    return XYChartAxisStyle(
      showLabel:
          metadata.boolAt(['xyChart', axis, 'showLabel']) ?? fallback.showLabel,
      labelFontSize: positive('labelFontSize', fallback.labelFontSize),
      labelPadding: nonNegative('labelPadding', fallback.labelPadding),
      showTitle:
          metadata.boolAt(['xyChart', axis, 'showTitle']) ?? fallback.showTitle,
      titleFontSize: positive('titleFontSize', fallback.titleFontSize),
      titlePadding: nonNegative('titlePadding', fallback.titlePadding),
      showTick:
          metadata.boolAt(['xyChart', axis, 'showTick']) ?? fallback.showTick,
      tickLength: positive('tickLength', fallback.tickLength),
      tickWidth: positive('tickWidth', fallback.tickWidth),
      showAxisLine:
          metadata.boolAt(['xyChart', axis, 'showAxisLine']) ??
          fallback.showAxisLine,
      axisLineWidth: positive('axisLineWidth', fallback.axisLineWidth),
      labelRotation: rotation != null && rotation >= -90 && rotation <= 90
          ? rotation
          : fallback.labelRotation,
    );
  }

  MermaidParseResult? _parseWithoutFrontmatter(
    String source,
    MermaidFrontmatter metadata,
  ) {
    if (source.trim().isEmpty) return null;

    final lines = source.split('\n');
    final cleanedLines = _cleanLines(lines);

    if (cleanedLines.isEmpty) return null;

    final firstLine = cleanedLines.first.trim().toLowerCase();

    // Detect diagram type
    final type = _detectDiagramType(firstLine);

    switch (type) {
      case DiagramType.flowchart:
        final diagram = FlowchartParser().parse(cleanedLines);
        if (diagram != null) {
          return MermaidParseResult(diagram: diagram);
        }
        return null;
      case DiagramType.sequence:
        final result = const SequenceParser().parseWithData(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                sequenceChartData: result.$2,
              );
      case DiagramType.zenuml:
        final result = const ZenUmlDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                zenUmlChartData: result.$2,
              );
      case DiagramType.pieChart:
        final result = const PieChartParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            pieChartData: result.$2,
          );
        }
        return null;
      case DiagramType.ganttChart:
        final result = const GanttParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            ganttChartData: result.$2,
          );
        }
        return null;
      case DiagramType.timeline:
        final result = const TimelineParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            timelineChartData: result.$2,
          );
        }
        return null;
      case DiagramType.kanban:
        final result = const KanbanParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            kanbanChartData: result.$2,
          );
        }
        return null;
      case DiagramType.radar:
        final result = const RadarParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(
            diagram: result.$1,
            radarChartData: result.$2,
          );
        }
        return null;
      case DiagramType.xyChart:
        final result = const XYChartParser().parse(cleanedLines);
        if (result != null) {
          return MermaidParseResult(diagram: result.$1, xyChartData: result.$2);
        }
        return null;
      case DiagramType.classDiagram:
        final result = const NativeClassDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                classDiagramData: result.$2,
              );
      case DiagramType.stateDiagram:
        final result = const NativeStateDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                stateDiagramData: result.$2,
              );
      case DiagramType.erDiagram:
        final result = const NativeErDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(diagram: result.$1, erDiagramData: result.$2);
      case DiagramType.requirementDiagram:
        final result = const NativeRequirementDiagramParser().parse(
          cleanedLines,
        );
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                requirementDiagramData: result.$2,
              );
      case DiagramType.journey:
        final result = const NativeJourneyDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                journeyChartData: result.$2,
              );
      case DiagramType.mindmap:
        final result = const NativeMindmapDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                mindmapChartData: result.$2,
              );
      case DiagramType.sankey:
        final result = const NativeSankeyDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                sankeyChartData: result.$2,
              );
      case DiagramType.gitGraph:
        final result = const NativeGitGraphDiagramParser().parse(
          cleanedLines,
          mainBranchName:
              metadata.stringAt(['gitGraph', 'mainBranchName']) ?? 'main',
          mainBranchOrder:
              metadata.numberAt(['gitGraph', 'mainBranchOrder'])?.toDouble() ??
              0,
        );
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                gitGraphChartData: result.$2,
              );
      case DiagramType.treeView:
        final result = const NativeTreeViewDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                treeViewChartData: result.$2,
              );
      case DiagramType.packet:
        final result = const PacketDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                packetChartData: result.$2,
              );
      case DiagramType.quadrantChart:
        final result = const QuadrantChartParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                quadrantChartData: result.$2,
              );
      case DiagramType.treemap:
        final result = const TreemapDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                treemapChartData: result.$2,
              );
      case DiagramType.venn:
        final result = const VennDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(diagram: result.$1, vennChartData: result.$2);
      case DiagramType.swimlanes:
        final result = const SwimlaneDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(diagram: result.$1, swimlaneData: result.$2);
      case DiagramType.info:
        final diagram = const InfoDiagramParser().parse(cleanedLines);
        return diagram == null ? null : MermaidParseResult(diagram: diagram);
      case DiagramType.block:
        final result = const BlockDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(diagram: result.$1, blockChartData: result.$2);
      case DiagramType.c4:
        final result = const C4DiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(diagram: result.$1, c4ChartData: result.$2);
      case DiagramType.eventModeling:
        final result = const EventModelingDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                eventModelingChartData: result.$2,
              );
      case DiagramType.ishikawa:
        final result = const IshikawaDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                ishikawaChartData: result.$2,
              );
      case DiagramType.railroad:
        final result = const RailroadDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                railroadChartData: result.$2,
              );
      case DiagramType.wardley:
        final result = const WardleyDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                wardleyChartData: result.$2,
              );
      case DiagramType.cynefin:
        final result = const CynefinDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                cynefinChartData: result.$2,
              );
      case DiagramType.architecture:
        final result = const ArchitectureDiagramParser().parse(cleanedLines);
        return result == null
            ? null
            : MermaidParseResult(
                diagram: result.$1,
                architectureChartData: result.$2,
              );
      case DiagramType.unknown:
        return null;
    }
  }

  /// Detects the diagram type from the first line
  DiagramType _detectDiagramType(String firstLine) {
    // Flowchart patterns
    if (firstLine.startsWith('graph ') || firstLine.startsWith('flowchart ')) {
      return DiagramType.flowchart;
    }

    // Sequence diagram
    if (firstLine.startsWith('sequencediagram')) {
      return DiagramType.sequence;
    }
    if (firstLine == 'zenuml') return DiagramType.zenuml;

    // Pie chart
    if (firstLine.startsWith('pie')) {
      return DiagramType.pieChart;
    }

    // Gantt chart
    if (firstLine.startsWith('gantt')) {
      return DiagramType.ganttChart;
    }

    // Timeline
    if (firstLine.startsWith('timeline')) {
      return DiagramType.timeline;
    }

    // Kanban
    if (firstLine.startsWith('kanban')) {
      return DiagramType.kanban;
    }

    // Radar chart
    if (firstLine.startsWith('radar-beta')) {
      return DiagramType.radar;
    }

    // XY chart
    if (firstLine.startsWith('xychart')) {
      return DiagramType.xyChart;
    }

    // Class diagram
    if (firstLine.startsWith('classdiagram')) {
      return DiagramType.classDiagram;
    }

    // State diagram
    if (firstLine.startsWith('statediagram') ||
        firstLine.startsWith('statediagram-v2')) {
      return DiagramType.stateDiagram;
    }

    if (firstLine.startsWith('erdiagram')) return DiagramType.erDiagram;
    if (firstLine.startsWith('requirementdiagram')) {
      return DiagramType.requirementDiagram;
    }
    if (firstLine.startsWith('journey')) return DiagramType.journey;
    if (firstLine.startsWith('mindmap')) return DiagramType.mindmap;
    if (firstLine.startsWith('sankey')) return DiagramType.sankey;
    if (firstLine.startsWith('gitgraph')) return DiagramType.gitGraph;
    if (firstLine.startsWith('treeview-beta')) return DiagramType.treeView;
    if (firstLine.startsWith('packet')) return DiagramType.packet;
    if (firstLine.startsWith('quadrantchart')) {
      return DiagramType.quadrantChart;
    }
    if (firstLine.startsWith('treemap')) return DiagramType.treemap;
    if (firstLine.startsWith('venn-beta')) return DiagramType.venn;
    if (firstLine.startsWith('swimlane-beta')) return DiagramType.swimlanes;
    if (firstLine == 'info' || firstLine == 'info showinfo') {
      return DiagramType.info;
    }
    if (firstLine == 'block' || firstLine == 'block-beta') {
      return DiagramType.block;
    }
    if (RegExp(
      r'^c4(context|container|component|dynamic|deployment)$',
    ).hasMatch(firstLine)) {
      return DiagramType.c4;
    }
    if (firstLine.startsWith('architecture-beta')) {
      return DiagramType.architecture;
    }
    if (firstLine == 'eventmodeling') return DiagramType.eventModeling;
    if (firstLine == 'ishikawa' || firstLine == 'ishikawa-beta') {
      return DiagramType.ishikawa;
    }
    if (RegExp(r'^railroad(?:-(?:ebnf|abnf|peg))?-beta$').hasMatch(firstLine)) {
      return DiagramType.railroad;
    }
    if (firstLine == 'wardley-beta') return DiagramType.wardley;
    if (firstLine == 'cynefin-beta' || firstLine == 'cynefin-beta:') {
      return DiagramType.cynefin;
    }

    return DiagramType.unknown;
  }

  /// Cleans and filters input lines
  List<String> _cleanLines(List<String> lines) {
    final result = <String>[];

    for (var line in lines) {
      line = _stripLineComment(line);

      // Skip empty lines
      if (line.trim().isNotEmpty) {
        result.add(line);
      }
    }

    return result;
  }

  String _stripLineComment(String source) {
    var quote = '';
    var escaped = false;
    for (var index = 0; index < source.length - 1; index++) {
      final char = source[index];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if ((char == '"' || char == "'" || char == '`') &&
          (quote.isEmpty || quote == char)) {
        quote = quote.isEmpty ? char : '';
        continue;
      }
      if (quote.isEmpty && char == '%' && source[index + 1] == '%') {
        return source.substring(0, index);
      }
    }
    return source;
  }
}

/// Result of parsing a token
class ParseToken {
  /// Creates a parse token
  const ParseToken({
    required this.type,
    required this.value,
    this.start = 0,
    this.end = 0,
  });

  /// Type of token
  final TokenType type;

  /// Token value
  final String value;

  /// Start position in source
  final int start;

  /// End position in source
  final int end;
}

/// Token types for lexical analysis
enum TokenType {
  /// Node identifier
  nodeId,

  /// Node label
  nodeLabel,

  /// Arrow/edge
  arrow,

  /// Edge label
  edgeLabel,

  /// Keyword (graph, subgraph, etc)
  keyword,

  /// Style definition
  style,

  /// Class definition
  classDef,

  /// Subgraph start
  subgraphStart,

  /// Subgraph end
  subgraphEnd,

  /// End of input
  eof,
}
