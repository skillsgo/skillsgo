/*
 * [INPUT]: Depends on the native layered Dagre-compatible geometry engine and Mermaid ELK flowchart configuration.
 * [OUTPUT]: Provides a dedicated pure-Dart ELK-style layered layout entry with configured spacing, direction, subgraphs, and edge constraints.
 * [POS]: Serves as the native renderer-selection target for `flowchart.defaultRenderer: elk` without JavaScript or WebView.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:ui';

import '../config/responsive_config.dart';
import '../models/diagram.dart';
import '../models/style.dart';
import 'dagre_layout.dart';
import 'layout_engine.dart';

class ElkLayout extends LayoutEngine {
  const ElkLayout({this.deviceConfig});

  final MermaidDeviceConfig? deviceConfig;

  @override
  Size computeLayout(
    MermaidDiagramData diagram,
    MermaidStyle style,
    Size availableSize,
  ) {
    // Mermaid's ELK renderer is layered as well. The native implementation
    // shares measurement and crossing reduction while honoring ELK's explicit
    // edge min-length and compound-subgraph constraints in DagreLayout.
    return DagreLayout(
      deviceConfig: deviceConfig,
    ).computeLayout(diagram, style, availableSize);
  }
}
