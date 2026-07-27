/*
 * [INPUT]: Depends on parsed Mermaid quadrant axes, labels, normalized points, point styles, renderer configuration, and theme variables.
 * [OUTPUT]: Defines immutable Quadrant chart data, configured geometry, styled points, and all official theme-variable overrides.
 * [POS]: Serves as the semantic model shared by the Quadrant parser, layout, and painter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
class QuadrantPoint {
  const QuadrantPoint({
    required this.label,
    required this.x,
    required this.y,
    this.className,
    this.radius,
    this.color,
    this.strokeColor,
    this.strokeWidth,
  });

  final String label;
  final double x;
  final double y;
  final String? className;
  final double? radius;
  final String? color;
  final String? strokeColor;
  final double? strokeWidth;
}

class QuadrantChartData {
  const QuadrantChartData({
    required this.points,
    this.title,
    this.xLeft,
    this.xRight,
    this.yBottom,
    this.yTop,
    this.quadrant1,
    this.quadrant2,
    this.quadrant3,
    this.quadrant4,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.chartWidth = 500,
    this.chartHeight = 500,
    this.titleFontSize = 20,
    this.titlePadding = 10,
    this.quadrantPadding = 5,
    this.xAxisLabelPadding = 5,
    this.yAxisLabelPadding = 5,
    this.xAxisLabelFontSize = 16,
    this.yAxisLabelFontSize = 16,
    this.quadrantLabelFontSize = 16,
    this.quadrantTextTopPadding = 5,
    this.pointTextPadding = 5,
    this.pointLabelFontSize = 12,
    this.pointRadius = 5,
    this.xAxisPosition = 'top',
    this.yAxisPosition = 'left',
    this.quadrantInternalBorderStrokeWidth = 1,
    this.quadrantExternalBorderStrokeWidth = 2,
    this.useMaxWidth = true,
    this.theme = const QuadrantThemeData(),
  });

  final List<QuadrantPoint> points;
  final String? title;
  final String? xLeft;
  final String? xRight;
  final String? yBottom;
  final String? yTop;
  final String? quadrant1;
  final String? quadrant2;
  final String? quadrant3;
  final String? quadrant4;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double chartWidth;
  final double chartHeight;
  final double titleFontSize;
  final double titlePadding;
  final double quadrantPadding;
  final double xAxisLabelPadding;
  final double yAxisLabelPadding;
  final double xAxisLabelFontSize;
  final double yAxisLabelFontSize;
  final double quadrantLabelFontSize;
  final double quadrantTextTopPadding;
  final double pointTextPadding;
  final double pointLabelFontSize;
  final double pointRadius;
  final String xAxisPosition;
  final String yAxisPosition;
  final double quadrantInternalBorderStrokeWidth;
  final double quadrantExternalBorderStrokeWidth;
  final bool useMaxWidth;
  final QuadrantThemeData theme;

  QuadrantChartData copyWith({
    String? title,
    double? chartWidth,
    double? chartHeight,
    double? titleFontSize,
    double? titlePadding,
    double? quadrantPadding,
    double? xAxisLabelPadding,
    double? yAxisLabelPadding,
    double? xAxisLabelFontSize,
    double? yAxisLabelFontSize,
    double? quadrantLabelFontSize,
    double? quadrantTextTopPadding,
    double? pointTextPadding,
    double? pointLabelFontSize,
    double? pointRadius,
    String? xAxisPosition,
    String? yAxisPosition,
    double? quadrantInternalBorderStrokeWidth,
    double? quadrantExternalBorderStrokeWidth,
    bool? useMaxWidth,
    QuadrantThemeData? theme,
  }) => QuadrantChartData(
    points: points,
    title: title ?? this.title,
    xLeft: xLeft,
    xRight: xRight,
    yBottom: yBottom,
    yTop: yTop,
    quadrant1: quadrant1,
    quadrant2: quadrant2,
    quadrant3: quadrant3,
    quadrant4: quadrant4,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    chartWidth: chartWidth ?? this.chartWidth,
    chartHeight: chartHeight ?? this.chartHeight,
    titleFontSize: titleFontSize ?? this.titleFontSize,
    titlePadding: titlePadding ?? this.titlePadding,
    quadrantPadding: quadrantPadding ?? this.quadrantPadding,
    xAxisLabelPadding: xAxisLabelPadding ?? this.xAxisLabelPadding,
    yAxisLabelPadding: yAxisLabelPadding ?? this.yAxisLabelPadding,
    xAxisLabelFontSize: xAxisLabelFontSize ?? this.xAxisLabelFontSize,
    yAxisLabelFontSize: yAxisLabelFontSize ?? this.yAxisLabelFontSize,
    quadrantLabelFontSize: quadrantLabelFontSize ?? this.quadrantLabelFontSize,
    quadrantTextTopPadding:
        quadrantTextTopPadding ?? this.quadrantTextTopPadding,
    pointTextPadding: pointTextPadding ?? this.pointTextPadding,
    pointLabelFontSize: pointLabelFontSize ?? this.pointLabelFontSize,
    pointRadius: pointRadius ?? this.pointRadius,
    xAxisPosition: xAxisPosition ?? this.xAxisPosition,
    yAxisPosition: yAxisPosition ?? this.yAxisPosition,
    quadrantInternalBorderStrokeWidth:
        quadrantInternalBorderStrokeWidth ??
        this.quadrantInternalBorderStrokeWidth,
    quadrantExternalBorderStrokeWidth:
        quadrantExternalBorderStrokeWidth ??
        this.quadrantExternalBorderStrokeWidth,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    theme: theme ?? this.theme,
  );
}

/// Optional Mermaid theme variables consumed by the Quadrant builder.
class QuadrantThemeData {
  const QuadrantThemeData({
    this.titleFill,
    this.quadrant1Fill,
    this.quadrant2Fill,
    this.quadrant3Fill,
    this.quadrant4Fill,
    this.quadrant1TextFill,
    this.quadrant2TextFill,
    this.quadrant3TextFill,
    this.quadrant4TextFill,
    this.pointFill,
    this.pointTextFill,
    this.xAxisTextFill,
    this.yAxisTextFill,
    this.internalBorderStrokeFill,
    this.externalBorderStrokeFill,
  });

  final String? titleFill;
  final String? quadrant1Fill;
  final String? quadrant2Fill;
  final String? quadrant3Fill;
  final String? quadrant4Fill;
  final String? quadrant1TextFill;
  final String? quadrant2TextFill;
  final String? quadrant3TextFill;
  final String? quadrant4TextFill;
  final String? pointFill;
  final String? pointTextFill;
  final String? xAxisTextFill;
  final String? yAxisTextFill;
  final String? internalBorderStrokeFill;
  final String? externalBorderStrokeFill;
}
