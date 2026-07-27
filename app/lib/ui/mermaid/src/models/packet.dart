/*
 * [INPUT]: Depends on parsed Mermaid packet declarations, official renderer configuration, theme variables, titles, and accessibility directives.
 * [OUTPUT]: Defines immutable packet diagram data with declared/resolved ranges and typed Mermaid 11.16 renderer styling.
 * [POS]: Serves as the semantic model shared by the Packet parser, layout, and painter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
class PacketField {
  const PacketField({
    required this.start,
    required this.end,
    required this.label,
    required this.relative,
    this.declaredStart,
    this.declaredEnd,
    this.declaredBits,
  });

  final int start;
  final int end;
  final String label;
  final bool relative;
  final int? declaredStart;
  final int? declaredEnd;
  final int? declaredBits;

  int get bits => end - start + 1;
}

class PacketChartData {
  const PacketChartData({
    required this.fields,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.rowHeight = 32,
    this.bitWidth = 32,
    this.bitsPerRow = 32,
    this.showBits = true,
    this.paddingX = 5,
    this.paddingY = 5,
    this.useMaxWidth = true,
    this.theme = const PacketThemeData(),
  });

  final List<PacketField> fields;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double rowHeight;
  final double bitWidth;
  final int bitsPerRow;
  final bool showBits;
  final double paddingX;
  final double paddingY;
  final bool useMaxWidth;
  final PacketThemeData theme;

  int get bitLength => fields.isEmpty ? 0 : fields.last.end + 1;

  double get effectivePaddingY => paddingY + (showBits ? 10 : 0);

  PacketChartData copyWith({
    String? title,
    double? rowHeight,
    double? bitWidth,
    int? bitsPerRow,
    bool? showBits,
    double? paddingX,
    double? paddingY,
    bool? useMaxWidth,
    PacketThemeData? theme,
  }) {
    return PacketChartData(
      fields: fields,
      title: title ?? this.title,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      rowHeight: rowHeight ?? this.rowHeight,
      bitWidth: bitWidth ?? this.bitWidth,
      bitsPerRow: bitsPerRow ?? this.bitsPerRow,
      showBits: showBits ?? this.showBits,
      paddingX: paddingX ?? this.paddingX,
      paddingY: paddingY ?? this.paddingY,
      useMaxWidth: useMaxWidth ?? this.useMaxWidth,
      theme: theme ?? this.theme,
    );
  }
}

/// Optional values from Mermaid's `themeVariables.packet` object.
class PacketThemeData {
  const PacketThemeData({
    this.byteFontSize,
    this.startByteColor,
    this.endByteColor,
    this.labelColor,
    this.labelFontSize,
    this.titleColor,
    this.titleFontSize,
    this.blockStrokeColor,
    this.blockStrokeWidth,
    this.blockFillColor,
  });

  final double? byteFontSize;
  final String? startByteColor;
  final String? endByteColor;
  final String? labelColor;
  final double? labelFontSize;
  final String? titleColor;
  final double? titleFontSize;
  final String? blockStrokeColor;
  final double? blockStrokeWidth;
  final String? blockFillColor;
}
