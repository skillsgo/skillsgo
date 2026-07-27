/*
 * [INPUT]: Depends on Mermaid Gantt raw task specifications, multi-tag state, dependency timing, interactions, calendar controls, axes, and accessibility semantics.
 * [OUTPUT]: Defines immutable lossless Gantt declarations plus resolved tasks, sections, interactions, and complete chart configuration.
 * [POS]: Serves as the chart-specific intermediate representation for Gantt diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

/// Represents the status of a task
enum GanttTaskStatus {
  /// Task is done
  done,

  /// Task is active/in progress
  active,

  /// Task is critical
  critical,

  /// Task is a milestone
  milestone,

  /// Normal task
  normal,
}

enum GanttTaskTag { active, done, critical, milestone, vertical }

enum GanttTimingKind { implicit, date, duration, after, until }

class GanttThemeData {
  const GanttThemeData({
    this.sectionBackground,
    this.alternateSectionBackground,
    this.sectionBackground2,
    this.excludeBackground,
    this.taskBorder,
    this.taskBackground,
    this.taskText,
    this.taskTextDark,
    this.taskTextOutside,
    this.taskTextClickable,
    this.activeTaskBorder,
    this.activeTaskBackground,
    this.grid,
    this.doneTaskBackground,
    this.doneTaskBorder,
    this.criticalBorder,
    this.criticalBackground,
    this.todayLine,
    this.verticalLine,
    this.title,
    this.text,
  });

  final String? sectionBackground;
  final String? alternateSectionBackground;
  final String? sectionBackground2;
  final String? excludeBackground;
  final String? taskBorder;
  final String? taskBackground;
  final String? taskText;
  final String? taskTextDark;
  final String? taskTextOutside;
  final String? taskTextClickable;
  final String? activeTaskBorder;
  final String? activeTaskBackground;
  final String? grid;
  final String? doneTaskBackground;
  final String? doneTaskBorder;
  final String? criticalBorder;
  final String? criticalBackground;
  final String? todayLine;
  final String? verticalLine;
  final String? title;
  final String? text;
}

/// Represents a single task in a Gantt chart
class GanttTask {
  /// Creates a Gantt task
  const GanttTask({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.section,
    this.status = GanttTaskStatus.normal,
    this.dependencies = const [],
    this.progress = 0,
    this.tags = const [],
    this.rawDefinition = '',
    this.startSpecification,
    this.endSpecification,
    this.startKind = GanttTimingKind.implicit,
    this.endKind = GanttTimingKind.implicit,
    this.untilDependencies = const [],
  });

  /// Unique identifier for this task
  final String id;

  /// Display name of the task
  final String name;

  /// Start date of the task
  final DateTime startDate;

  /// End date of the task
  final DateTime endDate;

  /// Optional section this task belongs to
  final String? section;

  /// Status of the task
  final GanttTaskStatus status;

  /// List of task IDs this task depends on
  final List<String> dependencies;

  /// Progress percentage (0-100)
  final int progress;

  final List<GanttTaskTag> tags;
  final String rawDefinition;
  final String? startSpecification;
  final String? endSpecification;
  final GanttTimingKind startKind;
  final GanttTimingKind endKind;
  final List<String> untilDependencies;

  /// Gets the duration in days
  int get durationDays {
    final days = endDate.difference(startDate).inDays;
    return days < 1 ? 1 : days;
  }

  /// Creates a copy with modified properties
  GanttTask copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? section,
    GanttTaskStatus? status,
    List<String>? dependencies,
    int? progress,
  }) {
    return GanttTask(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      section: section ?? this.section,
      status: status ?? this.status,
      dependencies: dependencies ?? this.dependencies,
      progress: progress ?? this.progress,
      tags: tags,
      rawDefinition: rawDefinition,
      startSpecification: startSpecification,
      endSpecification: endSpecification,
      startKind: startKind,
      endKind: endKind,
      untilDependencies: untilDependencies,
    );
  }
}

class GanttTaskInteraction {
  const GanttTaskInteraction({
    required this.taskId,
    this.href,
    this.callback,
    this.callbackArguments,
  });

  final String taskId;
  final String? href;
  final String? callback;
  final String? callbackArguments;
}

/// Represents a section in a Gantt chart
class GanttSection {
  /// Creates a Gantt section
  const GanttSection({required this.name, required this.tasks});

  /// Name of the section
  final String name;

  /// Tasks in this section
  final List<GanttTask> tasks;

  /// Creates a copy with modified properties
  GanttSection copyWith({String? name, List<GanttTask>? tasks}) {
    return GanttSection(name: name ?? this.name, tasks: tasks ?? this.tasks);
  }
}

/// Data for a complete Gantt chart
class GanttChartData {
  /// Creates Gantt chart data
  const GanttChartData({
    this.title,
    required this.tasks,
    this.sections = const [],
    this.dateFormat = 'YYYY-MM-DD',
    this.axisFormat,
    this.excludes,
    this.todayMarker = true,
    this.tickInterval,
    this.weekday,
    this.weekend,
    this.includes,
    this.inclusiveEndDates = false,
    this.topAxis = false,
    this.interactions = const [],
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.todayMarkerStyle,
    this.titleTopMargin = 25,
    this.barHeight = 20,
    this.barGap = 4,
    this.topPadding = 50,
    this.rightPadding = 75,
    this.leftPadding = 75,
    this.gridLineStartPadding = 35,
    this.fontSize = 11,
    this.sectionFontSize = 11,
    this.numberSectionStyles = 4,
    this.useMaxWidth = true,
    this.displayMode = '',
    this.theme = const GanttThemeData(),
  });

  /// Optional title for the Gantt chart
  final String? title;

  /// All tasks in the Gantt chart
  final List<GanttTask> tasks;

  /// Sections organizing tasks
  final List<GanttSection> sections;

  /// Date format string
  final String dateFormat;

  /// Axis display format
  final String? axisFormat;

  /// Days to exclude (weekends, holidays)
  final String? excludes;

  /// Whether to show today marker
  final bool todayMarker;

  /// Requested calendar tick interval, for example `1week`.
  final String? tickInterval;

  /// Weekday used to align weekly ticks.
  final String? weekday;

  final String? weekend;
  final String? includes;
  final bool inclusiveEndDates;
  final bool topAxis;
  final List<GanttTaskInteraction> interactions;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final String? todayMarkerStyle;
  final int titleTopMargin;
  final int barHeight;
  final int barGap;
  final int topPadding;
  final int rightPadding;
  final int leftPadding;
  final int gridLineStartPadding;
  final int fontSize;
  final double sectionFontSize;
  final int numberSectionStyles;
  final bool useMaxWidth;
  final String displayMode;
  final GanttThemeData theme;

  List<int> get taskLanes {
    if (displayMode != 'compact') {
      return List<int>.generate(tasks.length, (index) => index);
    }
    final laneEnds = <DateTime>[];
    return [for (final task in tasks) _placeTaskInLane(task, laneEnds)];
  }

  int _placeTaskInLane(GanttTask task, List<DateTime> laneEnds) {
    for (var index = 0; index < laneEnds.length; index++) {
      if (!task.startDate.isBefore(laneEnds[index])) {
        laneEnds[index] = task.endDate;
        return index;
      }
    }
    laneEnds.add(task.endDate);
    return laneEnds.length - 1;
  }

  int get laneCount => taskLanes.isEmpty
      ? 0
      : taskLanes.reduce((left, right) => left > right ? left : right) + 1;

  /// Gets the earliest start date among all tasks
  DateTime? get minDate {
    if (tasks.isEmpty) return null;
    return tasks
        .map((t) => t.startDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Gets the latest end date among all tasks
  DateTime? get maxDate {
    if (tasks.isEmpty) return null;
    return tasks.map((t) => t.endDate).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Gets the total duration in days
  int get totalDays {
    final min = minDate;
    final max = maxDate;
    if (min == null || max == null) return 0;
    return max.difference(min).inDays + 1;
  }

  /// Gets a task by its ID
  GanttTask? getTask(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// Creates a copy with modified properties
  GanttChartData copyWith({
    String? title,
    List<GanttTask>? tasks,
    List<GanttSection>? sections,
    String? dateFormat,
    String? axisFormat,
    String? excludes,
    bool? todayMarker,
    String? tickInterval,
    String? weekday,
    bool? topAxis,
    int? titleTopMargin,
    int? barHeight,
    int? barGap,
    int? topPadding,
    int? rightPadding,
    int? leftPadding,
    int? gridLineStartPadding,
    int? fontSize,
    double? sectionFontSize,
    int? numberSectionStyles,
    bool? useMaxWidth,
    String? displayMode,
    GanttThemeData? theme,
  }) {
    return GanttChartData(
      title: title ?? this.title,
      tasks: tasks ?? this.tasks,
      sections: sections ?? this.sections,
      dateFormat: dateFormat ?? this.dateFormat,
      axisFormat: axisFormat ?? this.axisFormat,
      excludes: excludes ?? this.excludes,
      todayMarker: todayMarker ?? this.todayMarker,
      tickInterval: tickInterval ?? this.tickInterval,
      weekday: weekday ?? this.weekday,
      weekend: weekend,
      includes: includes,
      inclusiveEndDates: inclusiveEndDates,
      topAxis: topAxis ?? this.topAxis,
      interactions: interactions,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      todayMarkerStyle: todayMarkerStyle,
      titleTopMargin: titleTopMargin ?? this.titleTopMargin,
      barHeight: barHeight ?? this.barHeight,
      barGap: barGap ?? this.barGap,
      topPadding: topPadding ?? this.topPadding,
      rightPadding: rightPadding ?? this.rightPadding,
      leftPadding: leftPadding ?? this.leftPadding,
      gridLineStartPadding: gridLineStartPadding ?? this.gridLineStartPadding,
      fontSize: fontSize ?? this.fontSize,
      sectionFontSize: sectionFontSize ?? this.sectionFontSize,
      numberSectionStyles: numberSectionStyles ?? this.numberSectionStyles,
      useMaxWidth: useMaxWidth ?? this.useMaxWidth,
      displayMode: displayMode ?? this.displayMode,
      theme: theme ?? this.theme,
    );
  }
}

/// Default color palette for Gantt charts
class GanttChartColors {
  GanttChartColors._();

  /// Color for done tasks
  static const int doneColor = 0xFF4CAF50; // Green

  /// Color for active tasks
  static const int activeColor = 0xFF2196F3; // Blue

  /// Color for critical tasks
  static const int criticalColor = 0xFFF44336; // Red

  /// Color for milestones
  static const int milestoneColor = 0xFFFF9800; // Orange

  /// Color for normal tasks
  static const int normalColor = 0xFF9E9E9E; // Grey

  /// Today marker color
  static const int todayMarkerColor = 0xFFE91E63; // Pink

  /// Grid line color
  static const int gridLineColor = 0xFFE0E0E0; // Light grey

  /// Section background colors (alternating)
  static const List<int> sectionColors = [
    0xFFF5F5F5, // Grey 100
    0xFFFFFFFF, // White
  ];

  /// Gets color for a task status
  static int getColorForStatus(GanttTaskStatus status) {
    switch (status) {
      case GanttTaskStatus.done:
        return doneColor;
      case GanttTaskStatus.active:
        return activeColor;
      case GanttTaskStatus.critical:
        return criticalColor;
      case GanttTaskStatus.milestone:
        return milestoneColor;
      case GanttTaskStatus.normal:
        return normalColor;
    }
  }
}
