/*
 * [INPUT]: Depends on Mermaid user-journey titles, accessibility directives, ordered sections, scored tasks, and actors.
 * [OUTPUT]: Defines immutable lossless native data plus complete Journey layout, typography, palette, and theme configuration.
 * [POS]: Serves as the journey-specific semantic model alongside the shared graph projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
class JourneySectionData {
  const JourneySectionData({required this.index, required this.title});
  final int index;
  final String title;
}

class JourneyTaskData {
  const JourneyTaskData({
    required this.index,
    required this.name,
    required this.score,
    required this.actors,
    required this.sectionIndex,
    required this.rawTaskData,
  });
  final int index;
  final String name;
  final double score;
  final List<String> actors;
  final int? sectionIndex;
  final String rawTaskData;
}

enum JourneyMessageAlign { left, center, right }

class JourneyThemeData {
  const JourneyThemeData({
    this.fillColors = const [],
    this.actorColors = const [],
    this.sectionTextColors = const [],
    this.faceColor,
    this.textColor,
    this.lineColor,
    this.titleColor,
    this.nodeBorder,
  });

  final List<String?> fillColors;
  final List<String?> actorColors;
  final List<String?> sectionTextColors;
  final String? faceColor;
  final String? textColor;
  final String? lineColor;
  final String? titleColor;
  final String? nodeBorder;
}

class JourneyChartData {
  const JourneyChartData({
    required this.sections,
    required this.tasks,
    required this.actors,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.diagramMarginX = 50,
    this.diagramMarginY = 10,
    this.leftMargin = 150,
    this.maxLabelWidth = 360,
    this.width = 150,
    this.height = 50,
    this.boxMargin = 10,
    this.boxTextMargin = 5,
    this.noteMargin = 10,
    this.messageMargin = 35,
    this.messageAlign = JourneyMessageAlign.center,
    this.bottomMarginAdj = 1,
    this.rightAngles = false,
    this.taskFontSize = 14,
    this.taskFontFamily = 'Open Sans',
    this.taskMargin = 50,
    this.activationWidth = 10,
    this.textPlacement = 'fo',
    this.actorColors = const [],
    this.sectionFills = const [],
    this.sectionColors = const [],
    this.titleColor,
    this.titleFontFamily = 'trebuchet ms',
    this.titleFontSize = '4ex',
    this.useMaxWidth = true,
    this.theme = const JourneyThemeData(),
  });
  final List<JourneySectionData> sections;
  final List<JourneyTaskData> tasks;
  final List<String> actors;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final double diagramMarginX;
  final double diagramMarginY;
  final double leftMargin;
  final double maxLabelWidth;
  final double width;
  final double height;
  final double boxMargin;
  final double boxTextMargin;
  final double noteMargin;
  final double messageMargin;
  final JourneyMessageAlign messageAlign;
  final double bottomMarginAdj;
  final bool rightAngles;
  final double taskFontSize;
  final String taskFontFamily;
  final double taskMargin;
  final double activationWidth;
  final String textPlacement;
  final List<String> actorColors;
  final List<String> sectionFills;
  final List<String> sectionColors;
  final String? titleColor;
  final String titleFontFamily;
  final String titleFontSize;
  final bool useMaxWidth;
  final JourneyThemeData theme;

  JourneyChartData copyWith({
    String? title,
    double? diagramMarginX,
    double? diagramMarginY,
    double? leftMargin,
    double? maxLabelWidth,
    double? width,
    double? height,
    double? boxMargin,
    double? boxTextMargin,
    double? noteMargin,
    double? messageMargin,
    JourneyMessageAlign? messageAlign,
    double? bottomMarginAdj,
    bool? rightAngles,
    double? taskFontSize,
    String? taskFontFamily,
    double? taskMargin,
    double? activationWidth,
    String? textPlacement,
    List<String>? actorColors,
    List<String>? sectionFills,
    List<String>? sectionColors,
    String? titleColor,
    String? titleFontFamily,
    String? titleFontSize,
    bool? useMaxWidth,
    JourneyThemeData? theme,
  }) => JourneyChartData(
    sections: sections,
    tasks: tasks,
    actors: actors,
    title: title ?? this.title,
    accessibilityTitle: accessibilityTitle,
    accessibilityDescription: accessibilityDescription,
    diagramMarginX: diagramMarginX ?? this.diagramMarginX,
    diagramMarginY: diagramMarginY ?? this.diagramMarginY,
    leftMargin: leftMargin ?? this.leftMargin,
    maxLabelWidth: maxLabelWidth ?? this.maxLabelWidth,
    width: width ?? this.width,
    height: height ?? this.height,
    boxMargin: boxMargin ?? this.boxMargin,
    boxTextMargin: boxTextMargin ?? this.boxTextMargin,
    noteMargin: noteMargin ?? this.noteMargin,
    messageMargin: messageMargin ?? this.messageMargin,
    messageAlign: messageAlign ?? this.messageAlign,
    bottomMarginAdj: bottomMarginAdj ?? this.bottomMarginAdj,
    rightAngles: rightAngles ?? this.rightAngles,
    taskFontSize: taskFontSize ?? this.taskFontSize,
    taskFontFamily: taskFontFamily ?? this.taskFontFamily,
    taskMargin: taskMargin ?? this.taskMargin,
    activationWidth: activationWidth ?? this.activationWidth,
    textPlacement: textPlacement ?? this.textPlacement,
    actorColors: actorColors ?? this.actorColors,
    sectionFills: sectionFills ?? this.sectionFills,
    sectionColors: sectionColors ?? this.sectionColors,
    titleColor: titleColor ?? this.titleColor,
    titleFontFamily: titleFontFamily ?? this.titleFontFamily,
    titleFontSize: titleFontSize ?? this.titleFontSize,
    useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    theme: theme ?? this.theme,
  );
}
