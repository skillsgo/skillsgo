/*
 * [INPUT]: Depends on Mermaid requirement kinds, SysML risk/verification enumerations, elements, relationships, directives, and styles.
 * [OUTPUT]: Defines the immutable lossless native representation plus complete Requirement renderer configuration and theme data.
 * [POS]: Serves as the chart-specific semantic model alongside the shared graph projection for requirement diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum RequirementKind {
  requirement,
  functionalRequirement,
  interfaceRequirement,
  performanceRequirement,
  physicalRequirement,
  designConstraint,
}

enum RequirementRisk { low, medium, high }

enum RequirementVerificationMethod { analysis, demonstration, inspection, test }

class RequirementData {
  const RequirementData({
    required this.name,
    required this.kind,
    required this.requirementId,
    required this.text,
    required this.risk,
    required this.verificationMethod,
    this.cssClasses = const ['default'],
    this.rawStyle,
  });

  final String name;
  final RequirementKind kind;
  final String requirementId;
  final String text;
  final RequirementRisk? risk;
  final RequirementVerificationMethod? verificationMethod;
  final List<String> cssClasses;
  final String? rawStyle;

  RequirementData copyWith({List<String>? cssClasses, String? rawStyle}) =>
      RequirementData(
        name: name,
        kind: kind,
        requirementId: requirementId,
        text: text,
        risk: risk,
        verificationMethod: verificationMethod,
        cssClasses: cssClasses ?? this.cssClasses,
        rawStyle: rawStyle ?? this.rawStyle,
      );
}

class RequirementElementData {
  const RequirementElementData({
    required this.name,
    required this.type,
    required this.documentReference,
    this.cssClasses = const ['default'],
    this.rawStyle,
  });

  final String name;
  final String type;
  final String documentReference;
  final List<String> cssClasses;
  final String? rawStyle;

  RequirementElementData copyWith({
    List<String>? cssClasses,
    String? rawStyle,
  }) => RequirementElementData(
    name: name,
    type: type,
    documentReference: documentReference,
    cssClasses: cssClasses ?? this.cssClasses,
    rawStyle: rawStyle ?? this.rawStyle,
  );
}

enum RequirementRelationshipKind {
  contains,
  copies,
  derives,
  satisfies,
  verifies,
  refines,
  traces,
}

class RequirementRelationshipData {
  const RequirementRelationshipData({
    required this.from,
    required this.to,
    required this.kind,
    required this.usedLeftArrowSyntax,
  });

  final String from;
  final String to;
  final RequirementRelationshipKind kind;
  final bool usedLeftArrowSyntax;
}

class RequirementThemeData {
  const RequirementThemeData({
    this.background,
    this.borderColor,
    this.borderSize,
    this.textColor,
    this.relationColor,
    this.relationLabelBackground,
    this.relationLabelColor,
    this.edgeLabelBackground,
    this.requirementEdgeLabelBackground,
    this.nodeBorder,
    this.backgroundColors = const [],
    this.borderColors = const [],
    this.strokeWidth = 1,
  });
  final String? background;
  final String? borderColor;
  final String? borderSize;
  final String? textColor;
  final String? relationColor;
  final String? relationLabelBackground;
  final String? relationLabelColor;
  final String? edgeLabelBackground;
  final String? requirementEdgeLabelBackground;
  final String? nodeBorder;
  final List<String> backgroundColors;
  final List<String> borderColors;
  final double strokeWidth;
}

class RequirementDiagramData {
  const RequirementDiagramData({
    required this.requirements,
    required this.elements,
    required this.relationships,
    required this.classDefinitions,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.rectFill = '#f9f9f9',
    this.textColor = '#333',
    this.rectBorderSize = '0.5px',
    this.rectBorderColor = '#bbb',
    this.rectMinWidth = 200,
    this.rectMinHeight = 200,
    this.fontSize = 14,
    this.rectPadding = 10,
    this.lineHeight = 20,
    this.useMaxWidth = true,
    this.look = 'classic',
    this.theme = const RequirementThemeData(),
  });

  final List<RequirementData> requirements;
  final List<RequirementElementData> elements;
  final List<RequirementRelationshipData> relationships;
  final Map<String, String> classDefinitions;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final String rectFill;
  final String textColor;
  final String rectBorderSize;
  final String rectBorderColor;
  final double rectMinWidth;
  final double rectMinHeight;
  final double fontSize;
  final double rectPadding;
  final double lineHeight;
  final bool useMaxWidth;
  final String look;
  final RequirementThemeData theme;

  RequirementDiagramData copyWith({
    String? title,
    String? rectFill,
    String? textColor,
    String? rectBorderSize,
    String? rectBorderColor,
    double? rectMinWidth,
    double? rectMinHeight,
    double? fontSize,
    double? rectPadding,
    double? lineHeight,
    bool? useMaxWidth,
    String? look,
    RequirementThemeData? theme,
  }) => RequirementDiagramData(
    requirements: requirements,
    elements: elements,
    relationships: relationships,
    classDefinitions: classDefinitions,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    rectFill: rectFill ?? this.rectFill,
    textColor: textColor ?? this.textColor,
    rectBorderSize: rectBorderSize ?? this.rectBorderSize,
    rectBorderColor: rectBorderColor ?? this.rectBorderColor,
    rectMinWidth: rectMinWidth ?? this.rectMinWidth,
    rectMinHeight: rectMinHeight ?? this.rectMinHeight,
    fontSize: fontSize ?? this.fontSize,
    rectPadding: rectPadding ?? this.rectPadding,
    lineHeight: lineHeight ?? this.lineHeight,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    look: look ?? this.look,
    theme: theme ?? this.theme,
  );
}
