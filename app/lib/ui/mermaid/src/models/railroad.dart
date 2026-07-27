/*
 * [INPUT]: Depends on Mermaid Railroad explicit DSL plus EBNF, ABNF, and PEG grammar constructs.
 * [OUTPUT]: Defines a unified recursive grammar AST, rule list, dialect identity, and repetition/predicate metadata.
 * [POS]: Serves as the shared intermediate representation for all four native Railroad diagram variants.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum RailroadDialect { railroad, ebnf, abnf, peg }

enum RailroadExpressionKind {
  terminal,
  nonTerminal,
  sequence,
  choice,
  optional,
  repetition,
  special,
  predicate,
}

class RailroadExpression {
  const RailroadExpression({
    required this.kind,
    this.text,
    this.children = const [],
    this.min,
    this.max,
  });

  final RailroadExpressionKind kind;
  final String? text;
  final List<RailroadExpression> children;
  final int? min;
  final int? max;

  double get estimatedWidth => switch (kind) {
    RailroadExpressionKind.terminal ||
    RailroadExpressionKind.nonTerminal ||
    RailroadExpressionKind.special => ((text?.length ?? 1) * 8.0 + 30).clamp(
      54,
      220,
    ),
    RailroadExpressionKind.sequence =>
      children.fold(0.0, (width, child) => width + child.estimatedWidth) +
          (children.length - 1).clamp(0, 1000) * 24,
    RailroadExpressionKind.choice =>
      children.fold(
            0.0,
            (width, child) =>
                child.estimatedWidth > width ? child.estimatedWidth : width,
          ) +
          54,
    RailroadExpressionKind.optional ||
    RailroadExpressionKind.repetition ||
    RailroadExpressionKind.predicate => children.first.estimatedWidth + 48,
  };

  double get estimatedHeight => switch (kind) {
    RailroadExpressionKind.terminal ||
    RailroadExpressionKind.nonTerminal ||
    RailroadExpressionKind.special => 34,
    RailroadExpressionKind.sequence => children.fold(
      34.0,
      (height, child) =>
          child.estimatedHeight > height ? child.estimatedHeight : height,
    ),
    RailroadExpressionKind.choice =>
      children.fold(0.0, (height, child) => height + child.estimatedHeight) +
          (children.length - 1).clamp(0, 1000) * 14,
    RailroadExpressionKind.optional ||
    RailroadExpressionKind.repetition => children.first.estimatedHeight + 34,
    RailroadExpressionKind.predicate => children.first.estimatedHeight,
  };
}

class RailroadRuleData {
  const RailroadRuleData({required this.name, required this.definition});
  final String name;
  final RailroadExpression definition;
}

class RailroadChartData {
  const RailroadChartData({
    required this.dialect,
    required this.rules,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.compactMode = false,
    this.padding = 10,
    this.verticalSeparation = 8,
    this.horizontalSeparation = 10,
    this.arcRadius = 10,
    this.fontSize = 14,
    this.fontFamily = 'monospace',
    this.terminalFill = '#FFFFC0',
    this.terminalStroke = '#000000',
    this.terminalTextColor = '#000000',
    this.nonTerminalFill = '#FFFFFF',
    this.nonTerminalStroke = '#000000',
    this.nonTerminalTextColor = '#000000',
    this.lineColor = '#000000',
    this.strokeWidth = 2,
    this.markerFill = '#000000',
    this.commentFill = '#E8E8E8',
    this.commentStroke = '#888888',
    this.commentTextColor = '#666666',
    this.specialFill = '#F0E0FF',
    this.specialStroke = '#8800CC',
    this.ruleNameColor = '#000066',
    this.showMarkers = true,
    this.markerRadius = 5,
    this.useMaxWidth = true,
  });
  final RailroadDialect dialect;
  final List<RailroadRuleData> rules;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final bool compactMode;
  final double padding;
  final double verticalSeparation;
  final double horizontalSeparation;
  final double arcRadius;
  final double fontSize;
  final String fontFamily;
  final String terminalFill;
  final String terminalStroke;
  final String terminalTextColor;
  final String nonTerminalFill;
  final String nonTerminalStroke;
  final String nonTerminalTextColor;
  final String lineColor;
  final double strokeWidth;
  final String markerFill;
  final String commentFill;
  final String commentStroke;
  final String commentTextColor;
  final String specialFill;
  final String specialStroke;
  final String ruleNameColor;
  final bool showMarkers;
  final double markerRadius;
  final bool useMaxWidth;

  RailroadChartData copyWith({
    String? title,
    String? accessibilityTitle,
    String? accessibilityDescription,
    bool? compactMode,
    double? padding,
    double? verticalSeparation,
    double? horizontalSeparation,
    double? arcRadius,
    double? fontSize,
    String? fontFamily,
    String? terminalFill,
    String? terminalStroke,
    String? terminalTextColor,
    String? nonTerminalFill,
    String? nonTerminalStroke,
    String? nonTerminalTextColor,
    String? lineColor,
    double? strokeWidth,
    String? markerFill,
    String? commentFill,
    String? commentStroke,
    String? commentTextColor,
    String? specialFill,
    String? specialStroke,
    String? ruleNameColor,
    bool? showMarkers,
    double? markerRadius,
    bool? useMaxWidth,
  }) => RailroadChartData(
    dialect: dialect,
    rules: rules,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle ?? this.accessibilityTitle,
    accessibilityDescription:
        accessibilityDescription ?? this.accessibilityDescription,
    compactMode: compactMode ?? this.compactMode,
    padding: padding ?? this.padding,
    verticalSeparation: verticalSeparation ?? this.verticalSeparation,
    horizontalSeparation: horizontalSeparation ?? this.horizontalSeparation,
    arcRadius: arcRadius ?? this.arcRadius,
    fontSize: fontSize ?? this.fontSize,
    fontFamily: fontFamily ?? this.fontFamily,
    terminalFill: terminalFill ?? this.terminalFill,
    terminalStroke: terminalStroke ?? this.terminalStroke,
    terminalTextColor: terminalTextColor ?? this.terminalTextColor,
    nonTerminalFill: nonTerminalFill ?? this.nonTerminalFill,
    nonTerminalStroke: nonTerminalStroke ?? this.nonTerminalStroke,
    nonTerminalTextColor: nonTerminalTextColor ?? this.nonTerminalTextColor,
    lineColor: lineColor ?? this.lineColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    markerFill: markerFill ?? this.markerFill,
    commentFill: commentFill ?? this.commentFill,
    commentStroke: commentStroke ?? this.commentStroke,
    commentTextColor: commentTextColor ?? this.commentTextColor,
    specialFill: specialFill ?? this.specialFill,
    specialStroke: specialStroke ?? this.specialStroke,
    ruleNameColor: ruleNameColor ?? this.ruleNameColor,
    showMarkers: showMarkers ?? this.showMarkers,
    markerRadius: markerRadius ?? this.markerRadius,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
  );
}
