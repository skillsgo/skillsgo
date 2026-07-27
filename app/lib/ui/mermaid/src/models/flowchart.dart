/*
 * [INPUT]: Depends on Mermaid 11.16 flowchart renderer configuration semantics.
 * [OUTPUT]: Defines typed flowchart curve, renderer, spacing, padding, wrapping, and subgraph-title configuration.
 * [POS]: Serves as the flowchart-specific configuration model shared by parser, layout, and painter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

enum FlowchartCurve {
  basis,
  bumpX,
  bumpY,
  cardinal,
  catmullRom,
  linear,
  monotoneX,
  monotoneY,
  natural,
  step,
  stepAfter,
  stepBefore,
  rounded,
}

enum FlowchartRenderer { dagreD3, dagreWrapper, elk }

class FlowchartConfig {
  const FlowchartConfig({
    this.titleTopMargin = 25,
    this.subgraphTitleMarginTop = 0,
    this.subgraphTitleMarginBottom = 0,
    this.arrowMarkerAbsolute,
    this.diagramPadding = 8,
    this.htmlLabels,
    this.nodeSpacing = 50,
    this.rankSpacing = 50,
    this.curve = FlowchartCurve.basis,
    this.padding = 15,
    this.useMaxWidth = true,
    this.defaultRenderer = FlowchartRenderer.dagreWrapper,
    this.wrappingWidth = 200,
    this.inheritDirection = false,
  });

  final double titleTopMargin;
  final double subgraphTitleMarginTop;
  final double subgraphTitleMarginBottom;
  final bool? arrowMarkerAbsolute;
  final double diagramPadding;
  final bool? htmlLabels;
  final double nodeSpacing;
  final double rankSpacing;
  final FlowchartCurve curve;
  final double padding;
  final bool useMaxWidth;
  final FlowchartRenderer defaultRenderer;
  final double wrappingWidth;
  final bool inheritDirection;

  FlowchartConfig copyWith({
    double? titleTopMargin,
    double? subgraphTitleMarginTop,
    double? subgraphTitleMarginBottom,
    bool? arrowMarkerAbsolute,
    double? diagramPadding,
    bool? htmlLabels,
    double? nodeSpacing,
    double? rankSpacing,
    FlowchartCurve? curve,
    double? padding,
    bool? useMaxWidth,
    FlowchartRenderer? defaultRenderer,
    double? wrappingWidth,
    bool? inheritDirection,
  }) {
    return FlowchartConfig(
      titleTopMargin: titleTopMargin ?? this.titleTopMargin,
      subgraphTitleMarginTop:
          subgraphTitleMarginTop ?? this.subgraphTitleMarginTop,
      subgraphTitleMarginBottom:
          subgraphTitleMarginBottom ?? this.subgraphTitleMarginBottom,
      arrowMarkerAbsolute: arrowMarkerAbsolute ?? this.arrowMarkerAbsolute,
      diagramPadding: diagramPadding ?? this.diagramPadding,
      htmlLabels: htmlLabels ?? this.htmlLabels,
      nodeSpacing: nodeSpacing ?? this.nodeSpacing,
      rankSpacing: rankSpacing ?? this.rankSpacing,
      curve: curve ?? this.curve,
      padding: padding ?? this.padding,
      useMaxWidth: useMaxWidth ?? this.useMaxWidth,
      defaultRenderer: defaultRenderer ?? this.defaultRenderer,
      wrappingWidth: wrappingWidth ?? this.wrappingWidth,
      inheritDirection: inheritDirection ?? this.inheritDirection,
    );
  }
}
