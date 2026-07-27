/*
 * [INPUT]: Depends on Mermaid XY axes, orientations, numeric series, accessibility, plot identity, renderer configuration, and theme variables.
 * [OUTPUT]: Defines immutable XY chart series, axis/configuration metadata, accessibility text, and complete chart theme data.
 * [POS]: Serves as the chart-specific intermediate representation for native XY layout and painting.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

/// Orientation of the XY chart
enum XYChartOrientation {
  /// Vertical bars (default)
  vertical,

  /// Horizontal bars
  horizontal,
}

/// Type of data series
enum XYSeriesType {
  /// Bar series
  bar,

  /// Line series
  line,
}

class XYChartAxisStyle {
  const XYChartAxisStyle({
    this.showLabel = true,
    this.labelFontSize = 14,
    this.labelPadding = 5,
    this.showTitle = true,
    this.titleFontSize = 16,
    this.titlePadding = 5,
    this.showTick = true,
    this.tickLength = 5,
    this.tickWidth = 2,
    this.showAxisLine = true,
    this.axisLineWidth = 2,
    this.labelRotation = 0,
  });
  final bool showLabel;
  final double labelFontSize;
  final double labelPadding;
  final bool showTitle;
  final double titleFontSize;
  final double titlePadding;
  final bool showTick;
  final double tickLength;
  final double tickWidth;
  final bool showAxisLine;
  final double axisLineWidth;
  final double labelRotation;
}

/// Represents a data series in the XY chart
class XYChartSeries {
  /// Creates an XY chart series
  const XYChartSeries({
    required this.type,
    required this.values,
    this.title = '',
    this.titleIsMarkdown = false,
    this.pointLabels = const [],
  });

  /// Series type (bar or line)
  final XYSeriesType type;

  /// Data values
  final List<double> values;

  /// Parsed plot title. Mermaid currently preserves but does not draw it.
  final String title;

  final bool titleIsMarkdown;

  /// Optional label paired with each value in Mermaid 11.16 syntax.
  final List<String?> pointLabels;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is XYChartSeries && other.type == type;
  }

  @override
  int get hashCode => Object.hash(type, values.length);
}

class XYChartThemeData {
  const XYChartThemeData({
    this.backgroundColor,
    this.titleColor,
    this.dataLabelColor,
    this.xAxisLabelColor,
    this.xAxisTitleColor,
    this.xAxisTickColor,
    this.xAxisLineColor,
    this.yAxisLabelColor,
    this.yAxisTitleColor,
    this.yAxisTickColor,
    this.yAxisLineColor,
    this.plotColorPalette = const [],
  });

  final String? backgroundColor;
  final String? titleColor;
  final String? dataLabelColor;
  final String? xAxisLabelColor;
  final String? xAxisTitleColor;
  final String? xAxisTickColor;
  final String? xAxisLineColor;
  final String? yAxisLabelColor;
  final String? yAxisTitleColor;
  final String? yAxisTickColor;
  final String? yAxisLineColor;
  final List<String> plotColorPalette;
}

/// Data for a complete XY chart
class XYChartData {
  /// Creates XY chart data
  const XYChartData({
    required this.series,
    this.title,
    this.xAxisTitle,
    this.yAxisTitle,
    this.xAxisCategories = const [],
    this.xAxisMin,
    this.xAxisMax,
    this.yAxisMin,
    this.yAxisMax,
    this.orientation = XYChartOrientation.vertical,
    this.width = 700,
    this.height = 500,
    this.titleFontSize = 20,
    this.titlePadding = 10,
    this.showDataLabel = false,
    this.showDataLabelOutsideBar = false,
    this.showTitle = true,
    this.xAxisStyle = const XYChartAxisStyle(),
    this.yAxisStyle = const XYChartAxisStyle(),
    this.plotReservedSpacePercent = 50,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.theme = const XYChartThemeData(),
  });

  /// Optional chart title
  final String? title;

  /// X-axis title
  final String? xAxisTitle;

  /// Y-axis title
  final String? yAxisTitle;

  /// X-axis category labels (for categorical axis)
  final List<String> xAxisCategories;

  /// X-axis numeric min (for numeric axis)
  final double? xAxisMin;

  /// X-axis numeric max (for numeric axis)
  final double? xAxisMax;

  /// Y-axis numeric min
  final double? yAxisMin;

  /// Y-axis numeric max
  final double? yAxisMax;

  /// Chart orientation
  final XYChartOrientation orientation;

  /// Data series (bar and/or line)
  final List<XYChartSeries> series;
  final double width;
  final double height;
  final double titleFontSize;
  final double titlePadding;
  final bool showDataLabel;
  final bool showDataLabelOutsideBar;
  final bool showTitle;
  final XYChartAxisStyle xAxisStyle;
  final XYChartAxisStyle yAxisStyle;
  final double plotReservedSpacePercent;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final XYChartThemeData theme;

  XYChartData copyWith({
    String? title,
    double? width,
    double? height,
    double? titleFontSize,
    double? titlePadding,
    bool? showDataLabel,
    bool? showDataLabelOutsideBar,
    bool? showTitle,
    XYChartAxisStyle? xAxisStyle,
    XYChartAxisStyle? yAxisStyle,
    XYChartOrientation? orientation,
    double? plotReservedSpacePercent,
    XYChartThemeData? theme,
  }) {
    return XYChartData(
      series: series,
      title: title ?? this.title,
      xAxisTitle: xAxisTitle,
      yAxisTitle: yAxisTitle,
      xAxisCategories: xAxisCategories,
      xAxisMin: xAxisMin,
      xAxisMax: xAxisMax,
      yAxisMin: yAxisMin,
      yAxisMax: yAxisMax,
      orientation: orientation ?? this.orientation,
      width: width ?? this.width,
      height: height ?? this.height,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      titlePadding: titlePadding ?? this.titlePadding,
      showDataLabel: showDataLabel ?? this.showDataLabel,
      showDataLabelOutsideBar:
          showDataLabelOutsideBar ?? this.showDataLabelOutsideBar,
      showTitle: showTitle ?? this.showTitle,
      xAxisStyle: xAxisStyle ?? this.xAxisStyle,
      yAxisStyle: yAxisStyle ?? this.yAxisStyle,
      plotReservedSpacePercent:
          plotReservedSpacePercent ?? this.plotReservedSpacePercent,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      theme: theme ?? this.theme,
    );
  }

  /// Whether x-axis is categorical
  bool get isCategorical => xAxisCategories.isNotEmpty;

  /// Gets the effective Y-axis min
  double get effectiveYMin {
    if (yAxisMin != null) return yAxisMin!;
    var minVal = double.infinity;
    for (final s in series) {
      for (final v in _visibleValues(s)) {
        if (v < minVal) minVal = v;
      }
    }
    return minVal.isFinite ? minVal : 0;
  }

  /// Gets the effective Y-axis max
  double get effectiveYMax {
    if (yAxisMax != null) return yAxisMax!;
    var maxVal = double.negativeInfinity;
    for (final s in series) {
      for (final v in _visibleValues(s)) {
        if (v > maxVal) maxVal = v;
      }
    }
    return maxVal.isFinite ? maxVal : 0;
  }

  /// Gets the number of data points
  int get dataPointCount {
    if (isCategorical) return xAxisCategories.length;
    var max = 0;
    for (final s in series) {
      if (s.values.length > max) max = s.values.length;
    }
    return max;
  }

  Iterable<double> _visibleValues(XYChartSeries series) => isCategorical
      ? series.values.take(xAxisCategories.length)
      : series.values;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is XYChartData &&
        other.title == title &&
        other.orientation == orientation;
  }

  @override
  int get hashCode => Object.hash(title, orientation);
}

/// Default color palette for XY charts
class XYChartColors {
  XYChartColors._();

  /// Series colors (cycling)
  static const List<int> seriesColors = [
    0xFF2196F3, // Blue
    0xFFFF9800, // Orange
    0xFF4CAF50, // Green
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFFC107, // Amber
    0xFF795548, // Brown
  ];

  /// Grid line color
  static const int gridColor = 0xFFE0E0E0;

  /// Axis line color
  static const int axisColor = 0xFF616161;

  /// Text color
  static const int textColor = 0xFF212121;

  /// Gets color for series by index
  static int getColorForSeries(int index) {
    return seriesColors[index % seriesColors.length];
  }
}
