/*
 * [INPUT]: Depends on the native layered Dagre geometry engine and Mermaid Dagre D3 renderer selection.
 * [OUTPUT]: Provides a dedicated pure-Dart Dagre D3 layout entry honoring flowchart spacing, direction, subgraphs, and edge constraints.
 * [POS]: Serves as the native renderer-selection target for `flowchart.defaultRenderer: dagre-d3`.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/style.dart';
import 'dagre_layout.dart';
import 'layout_engine.dart';

class DagreD3Layout extends LayoutEngine {
  const DagreD3Layout({this.deviceConfig});

  final MermaidDeviceConfig? deviceConfig;

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) => DagreLayout(
    deviceConfig: deviceConfig,
  ).computeLayout(diagram, style, availableSize);
}
