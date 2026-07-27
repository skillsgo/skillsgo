/*
 * [INPUT]: Depends on Mermaid Timeline sections/events and the complete legacy-compatible renderer configuration schema.
 * [OUTPUT]: Defines immutable native Timeline content, sizing, typography, alignment, color, and spacing configuration.
 * [POS]: Serves as the chart-specific representation shared by Timeline parsing, layout, and Canvas painting.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

enum TimelineDirection { leftToRight, topDown }

enum TimelineMessageAlign { left, center, right }

/// Represents a single event in a timeline
class TimelineEvent {
  /// Creates a timeline event
  const TimelineEvent({
    required this.title,
    required this.periods,
    this.description,
  });

  /// Title/name of the event
  final String title;

  /// List of time periods or dates associated with this event
  final List<String> periods;

  /// Optional description
  final String? description;

  /// Creates a copy with modified properties
  TimelineEvent copyWith({
    String? title,
    List<String>? periods,
    String? description,
  }) {
    return TimelineEvent(
      title: title ?? this.title,
      periods: periods ?? this.periods,
      description: description ?? this.description,
    );
  }
}

/// Represents a section in a timeline
class TimelineSection {
  /// Creates a timeline section
  const TimelineSection({required this.title, required this.events});

  /// Title of the section
  final String title;

  /// Events in this section
  final List<TimelineEvent> events;

  /// Creates a copy with modified properties
  TimelineSection copyWith({String? title, List<TimelineEvent>? events}) {
    return TimelineSection(
      title: title ?? this.title,
      events: events ?? this.events,
    );
  }
}

/// Data for a complete timeline chart
class TimelineChartData {
  /// Creates timeline chart data
  const TimelineChartData({
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.direction = TimelineDirection.leftToRight,
    required this.sections,
    this.diagramMarginX = 50,
    this.diagramMarginY = 10,
    this.leftMargin = 150,
    this.width = 150,
    this.height = 50,
    this.padding = 50,
    this.boxMargin = 10,
    this.boxTextMargin = 5,
    this.noteMargin = 10,
    this.messageMargin = 35,
    this.messageAlign = TimelineMessageAlign.center,
    this.bottomMarginAdj = 1,
    this.rightAngles = false,
    this.taskFontSize = 14,
    this.taskFontFamily = 'Open Sans',
    this.taskMargin = 50,
    this.activationWidth = 10,
    this.textPlacement = 'fo',
    this.actorColours = const [
      '#8FBC8F',
      '#7CFC00',
      '#00FFFF',
      '#20B2AA',
      '#B0E0E6',
      '#FFFFE0',
    ],
    this.sectionFills = const [
      '#191970',
      '#8B008B',
      '#4B0082',
      '#2F4F4F',
      '#800000',
      '#8B4513',
      '#00008B',
    ],
    this.sectionColours = const ['#fff'],
    this.disableMulticolor = false,
    this.useMaxWidth = true,
  });

  /// Optional title for the timeline
  final String? title;

  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final TimelineDirection direction;

  /// Sections organizing events
  final List<TimelineSection> sections;
  final double diagramMarginX;
  final double diagramMarginY;
  final int leftMargin;
  final int width;
  final int height;
  final double padding;
  final int boxMargin;
  final int boxTextMargin;
  final int noteMargin;
  final int messageMargin;
  final TimelineMessageAlign messageAlign;
  final int bottomMarginAdj;
  final bool rightAngles;
  final double taskFontSize;
  final String taskFontFamily;
  final double taskMargin;
  final double activationWidth;
  final String textPlacement;
  final List<String> actorColours;
  final List<String> sectionFills;
  final List<String> sectionColours;
  final bool disableMulticolor;
  final bool useMaxWidth;

  /// Gets all events across all sections
  List<TimelineEvent> get allEvents {
    return sections.expand((section) => section.events).toList();
  }

  /// Creates a copy with modified properties
  TimelineChartData copyWith({
    String? title,
    String? accessibilityTitle,
    String? accessibilityDescription,
    TimelineDirection? direction,
    List<TimelineSection>? sections,
    double? diagramMarginX,
    double? diagramMarginY,
    int? leftMargin,
    int? width,
    int? height,
    double? padding,
    int? boxMargin,
    int? boxTextMargin,
    int? noteMargin,
    int? messageMargin,
    TimelineMessageAlign? messageAlign,
    int? bottomMarginAdj,
    bool? rightAngles,
    double? taskFontSize,
    String? taskFontFamily,
    double? taskMargin,
    double? activationWidth,
    String? textPlacement,
    List<String>? actorColours,
    List<String>? sectionFills,
    List<String>? sectionColours,
    bool? disableMulticolor,
    bool? useMaxWidth,
  }) {
    return TimelineChartData(
      title: title ?? this.title,
      accessibilityTitle: accessibilityTitle ?? this.accessibilityTitle,
      accessibilityDescription:
          accessibilityDescription ?? this.accessibilityDescription,
      direction: direction ?? this.direction,
      sections: sections ?? this.sections,
      diagramMarginX: diagramMarginX ?? this.diagramMarginX,
      diagramMarginY: diagramMarginY ?? this.diagramMarginY,
      leftMargin: leftMargin ?? this.leftMargin,
      width: width ?? this.width,
      height: height ?? this.height,
      padding: padding ?? this.padding,
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
      actorColours: actorColours ?? this.actorColours,
      sectionFills: sectionFills ?? this.sectionFills,
      sectionColours: sectionColours ?? this.sectionColours,
      disableMulticolor: disableMulticolor ?? this.disableMulticolor,
      useMaxWidth: useMaxWidth ?? this.useMaxWidth,
    );
  }
}

/// Default color palette for timeline charts
class TimelineChartColors {
  TimelineChartColors._();

  /// Primary timeline color
  static const int primaryColor = 0xFF2196F3; // Blue

  /// Secondary timeline color
  static const int secondaryColor = 0xFF4CAF50; // Green

  /// Accent color for events
  static const int accentColor = 0xFFFF9800; // Orange

  /// Text color
  static const int textColor = 0xFF212121; // Dark grey

  /// Grid line color
  static const int gridLineColor = 0xFFE0E0E0; // Light grey

  /// Section colors (alternating)
  static const List<int> sectionColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFFF44336, // Red
    0xFF00BCD4, // Cyan
    0xFFFFEB3B, // Yellow
    0xFF795548, // Brown
  ];

  /// Gets color for a section by index
  static int getColorForSection(int index) {
    return sectionColors[index % sectionColors.length];
  }
}
