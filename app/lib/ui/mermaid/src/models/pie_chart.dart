/*
 * [INPUT]: Depends on Mermaid Pie ordered unique slices, showData, title, accessibility, and chart configuration semantics.
 * [OUTPUT]: Defines immutable native Pie slices and chart metadata used by layout and painting.
 * [POS]: Serves as the chart-specific representation for Pie and Donut diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

/// Represents a single slice in a pie chart
class PieSlice {
  /// Creates a pie slice
  const PieSlice({required this.label, required this.value, this.color});

  /// Label for this slice
  final String label;

  /// Value (determines the size of the slice)
  final double value;

  /// Optional custom color (ARGB int)
  final int? color;

  /// Creates a copy with modified properties
  PieSlice copyWith({String? label, double? value, int? color}) {
    return PieSlice(
      label: label ?? this.label,
      value: value ?? this.value,
      color: color ?? this.color,
    );
  }
}

/// Data for a complete pie chart
class PieChartData {
  /// Creates pie chart data
  const PieChartData({
    this.title,
    required this.slices,
    this.showValuesInLegend = true,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.textPosition = 0.75,
    this.donutHole = 0,
    this.legendPosition = PieLegendPosition.right,
    this.highlightSlice,
    this.useMaxWidth = true,
    this.theme = const PieThemeData(),
  });

  /// Optional title for the pie chart
  final String? title;

  /// All slices in the pie chart
  final List<PieSlice> slices;

  /// Whether to show values in the legend
  final bool showValuesInLegend;
  final String? accessibilityTitle;
  final String? accessibilityDescription;

  /// Radial label position from the center (0) to the outer edge (1).
  final double textPosition;

  /// Inner radius ratio, constrained to Mermaid's supported 0...0.9 range.
  final double donutHole;

  /// Requested legend placement.
  final PieLegendPosition legendPosition;

  /// Slice label to emphasize, or `hover` for interactive highlighting.
  final String? highlightSlice;

  /// Whether the chart expands to the available width.
  final bool useMaxWidth;

  /// Mermaid `themeVariables` that are specific to Pie rendering.
  final PieThemeData theme;

  /// Gets the total value of all slices
  double get totalValue {
    if (slices.isEmpty) return 0;
    return slices.fold(0.0, (sum, slice) => sum + slice.value);
  }

  /// Gets the percentage for a slice
  double getPercentage(PieSlice slice) {
    final total = totalValue;
    if (total == 0) return 0;
    return (slice.value / total) * 100;
  }

  /// Creates a copy with modified properties
  PieChartData copyWith({
    String? title,
    List<PieSlice>? slices,
    bool? showValuesInLegend,
    double? textPosition,
    double? donutHole,
    PieLegendPosition? legendPosition,
    String? highlightSlice,
    bool? useMaxWidth,
    PieThemeData? theme,
  }) {
    return PieChartData(
      title: title ?? this.title,
      slices: slices ?? this.slices,
      showValuesInLegend: showValuesInLegend ?? this.showValuesInLegend,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      textPosition: textPosition ?? this.textPosition,
      donutHole: donutHole ?? this.donutHole,
      legendPosition: legendPosition ?? this.legendPosition,
      highlightSlice: highlightSlice ?? this.highlightSlice,
      useMaxWidth: useMaxWidth ?? this.useMaxWidth,
      theme: theme ?? this.theme,
    );
  }
}

/// Optional Mermaid Pie theme-variable overrides.
class PieThemeData {
  const PieThemeData({
    this.colors = const {},
    this.titleTextSize,
    this.titleTextColor,
    this.sectionTextSize,
    this.sectionTextColor,
    this.legendTextSize,
    this.legendTextColor,
    this.strokeColor,
    this.strokeWidth,
    this.outerStrokeColor,
    this.outerStrokeWidth,
    this.opacity,
  });

  final Map<int, String> colors;
  final double? titleTextSize;
  final String? titleTextColor;
  final double? sectionTextSize;
  final String? sectionTextColor;
  final double? legendTextSize;
  final String? legendTextColor;
  final String? strokeColor;
  final double? strokeWidth;
  final String? outerStrokeColor;
  final double? outerStrokeWidth;
  final double? opacity;
}

/// Mermaid-supported legend locations.
enum PieLegendPosition { top, bottom, left, right, center }

/// Default color palette for pie charts
class PieChartColors {
  PieChartColors._();

  /// Default color palette (Material Design colors)
  static const List<int> defaultPalette = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFFEB3B, // Yellow
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
    0xFFF44336, // Red
    0xFF3F51B5, // Indigo
    0xFF009688, // Teal
  ];

  /// Gets a color from the palette by index
  static int getColor(int index) {
    return defaultPalette[index % defaultPalette.length];
  }
}
