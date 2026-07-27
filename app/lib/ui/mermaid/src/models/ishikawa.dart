/*
 * [INPUT]: Depends on Mermaid Ishikawa hierarchy plus diagram, global look/font, seed, and theme configuration.
 * [OUTPUT]: Defines immutable recursive cause nodes, aggregate measurements, responsive geometry, and native visual configuration.
 * [POS]: Serves as the chart-specific intermediate representation for native fishbone layout and painting.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
class IshikawaNodeData {
  const IshikawaNodeData({
    required this.id,
    required this.text,
    this.children = const [],
  });

  final String id;
  final String text;
  final List<IshikawaNodeData> children;

  int get descendantCount =>
      children.fold(0, (count, child) => count + 1 + child.descendantCount);

  int get depth => children.isEmpty
      ? 1
      : 1 +
            children
                .map((child) => child.depth)
                .reduce((a, b) => a > b ? a : b);
}

class IshikawaChartData {
  const IshikawaChartData({
    required this.effect,
    this.diagramPadding = 20,
    this.useMaxWidth = false,
    this.handDrawn = false,
    this.handDrawnSeed = 0,
    this.fontSize = 14,
    this.lineColor,
    this.fillColor,
    this.textColor,
  });

  final IshikawaNodeData effect;
  final double diagramPadding;
  final bool useMaxWidth;
  final bool handDrawn;
  final int handDrawnSeed;
  final double fontSize;
  final String? lineColor;
  final String? fillColor;
  final String? textColor;

  IshikawaChartData copyWith({
    double? diagramPadding,
    bool? useMaxWidth,
    bool? handDrawn,
    int? handDrawnSeed,
    double? fontSize,
    String? lineColor,
    String? fillColor,
    String? textColor,
  }) => IshikawaChartData(
    effect: effect,
    diagramPadding: diagramPadding ?? this.diagramPadding,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    handDrawn: handDrawn ?? this.handDrawn,
    handDrawnSeed: handDrawnSeed ?? this.handDrawnSeed,
    fontSize: fontSize ?? this.fontSize,
    lineColor: lineColor ?? this.lineColor,
    fillColor: fillColor ?? this.fillColor,
    textColor: textColor ?? this.textColor,
  );
}
