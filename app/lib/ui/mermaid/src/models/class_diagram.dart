/*
 * [INPUT]: Depends on Mermaid class declarations, members, namespaces, UML relations, notes, styles, and interaction metadata.
 * [OUTPUT]: Defines immutable lossless class-diagram entities for native layout, painting, and interaction.
 * [POS]: Serves as the chart-specific representation alongside the shared graph projection for classDiagram.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum ClassMemberVisibility { public, private, protected, package, unspecified }

enum ClassMemberKind { attribute, method }

class ClassMemberData {
  const ClassMemberData({
    required this.text,
    required this.kind,
    required this.visibility,
    this.isStatic = false,
    this.isAbstract = false,
  });
  final String text;
  final ClassMemberKind kind;
  final ClassMemberVisibility visibility;
  final bool isStatic;
  final bool isAbstract;
}

enum ClassRelationEnd {
  none,
  inheritance,
  composition,
  aggregation,
  association,
  realization,
  lollipop,
}

class ClassRelationData {
  const ClassRelationData({
    required this.from,
    required this.to,
    required this.leftEnd,
    required this.rightEnd,
    required this.dashed,
    this.leftCardinality,
    this.rightCardinality,
    this.label,
  });
  final String from;
  final String to;
  final ClassRelationEnd leftEnd;
  final ClassRelationEnd rightEnd;
  final bool dashed;
  final String? leftCardinality;
  final String? rightCardinality;
  final String? label;
}

class ClassEntityData {
  const ClassEntityData({
    required this.id,
    required this.label,
    required this.members,
    required this.annotations,
    this.genericType,
    this.namespace,
    this.cssClass,
    this.rawStyle,
    this.link,
    this.callback,
    this.tooltip,
  });
  final String id;
  final String label;
  final String? genericType;
  final String? namespace;
  final List<ClassMemberData> members;
  final List<String> annotations;
  final String? cssClass;
  final String? rawStyle;
  final String? link;
  final String? callback;
  final String? tooltip;

  ClassEntityData copyWith({
    String? label,
    String? genericType,
    String? namespace,
    List<ClassMemberData>? members,
    List<String>? annotations,
    String? cssClass,
    String? rawStyle,
    String? link,
    String? callback,
    String? tooltip,
  }) => ClassEntityData(
    id: id,
    label: label ?? this.label,
    genericType: genericType ?? this.genericType,
    namespace: namespace ?? this.namespace,
    members: members ?? this.members,
    annotations: annotations ?? this.annotations,
    cssClass: cssClass ?? this.cssClass,
    rawStyle: rawStyle ?? this.rawStyle,
    link: link ?? this.link,
    callback: callback ?? this.callback,
    tooltip: tooltip ?? this.tooltip,
  );
}

class ClassNamespaceData {
  const ClassNamespaceData({
    required this.id,
    required this.label,
    this.parent,
  });
  final String id;
  final String label;
  final String? parent;
}

class ClassNoteData {
  const ClassNoteData({required this.text, this.classId});
  final String text;
  final String? classId;
}

class ClassDiagramData {
  const ClassDiagramData({
    required this.classes,
    required this.namespaces,
    required this.relations,
    required this.notes,
    required this.classDefinitions,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.titleTopMargin = 25,
    this.arrowMarkerAbsolute = false,
    this.dividerMargin = 10,
    this.padding = 5,
    this.textHeight = 10,
    this.defaultRenderer = 'dagre-wrapper',
    this.nodeSpacing = 50,
    this.rankSpacing = 50,
    this.diagramPadding = 8,
    this.htmlLabels = false,
    this.hideEmptyMembersBox = false,
    this.hierarchicalNamespaces = true,
    this.useMaxWidth = true,
    this.look = 'classic',
    this.theme = const ClassThemeData(),
  });
  final List<ClassEntityData> classes;
  final List<ClassNamespaceData> namespaces;
  final List<ClassRelationData> relations;
  final List<ClassNoteData> notes;
  final Map<String, String> classDefinitions;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double titleTopMargin;
  final bool arrowMarkerAbsolute;
  final double dividerMargin;
  final double padding;
  final double textHeight;
  final String defaultRenderer;
  final double nodeSpacing;
  final double rankSpacing;
  final double diagramPadding;
  final bool htmlLabels;
  final bool hideEmptyMembersBox;
  final bool hierarchicalNamespaces;
  final bool useMaxWidth;
  final String look;
  final ClassThemeData theme;

  ClassDiagramData copyWith({
    String? title,
    String? accessibilityTitle,
    String? accessibilityDescription,
    double? titleTopMargin,
    bool? arrowMarkerAbsolute,
    double? dividerMargin,
    double? padding,
    double? textHeight,
    String? defaultRenderer,
    double? nodeSpacing,
    double? rankSpacing,
    double? diagramPadding,
    bool? htmlLabels,
    bool? hideEmptyMembersBox,
    bool? hierarchicalNamespaces,
    bool? useMaxWidth,
    String? look,
    ClassThemeData? theme,
  }) => ClassDiagramData(
    classes: classes,
    namespaces: namespaces,
    relations: relations,
    notes: notes,
    classDefinitions: classDefinitions,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle ?? this.accessibilityTitle,
    accessibilityDescription:
        accessibilityDescription ?? this.accessibilityDescription,
    titleTopMargin: titleTopMargin ?? this.titleTopMargin,
    arrowMarkerAbsolute: arrowMarkerAbsolute ?? this.arrowMarkerAbsolute,
    dividerMargin: dividerMargin ?? this.dividerMargin,
    padding: padding ?? this.padding,
    textHeight: textHeight ?? this.textHeight,
    defaultRenderer: defaultRenderer ?? this.defaultRenderer,
    nodeSpacing: nodeSpacing ?? this.nodeSpacing,
    rankSpacing: rankSpacing ?? this.rankSpacing,
    diagramPadding: diagramPadding ?? this.diagramPadding,
    htmlLabels: htmlLabels ?? this.htmlLabels,
    hideEmptyMembersBox: hideEmptyMembersBox ?? this.hideEmptyMembersBox,
    hierarchicalNamespaces:
        hierarchicalNamespaces ?? this.hierarchicalNamespaces,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    look: look ?? this.look,
    theme: theme ?? this.theme,
  );
}

class ClassThemeData {
  const ClassThemeData({
    this.mainBackground,
    this.nodeBorder,
    this.classText,
    this.textColor,
    this.lineColor,
    this.edgeLabelBackground,
    this.clusterBackground,
    this.clusterBorder,
    this.titleColor,
    this.noteBackground,
    this.noteBorder,
    this.noteText,
    this.strokeWidth = 1,
  });
  final String? mainBackground;
  final String? nodeBorder;
  final String? classText;
  final String? textColor;
  final String? lineColor;
  final String? edgeLabelBackground;
  final String? clusterBackground;
  final String? clusterBorder;
  final String? titleColor;
  final String? noteBackground;
  final String? noteBorder;
  final String? noteText;
  final double strokeWidth;
}
