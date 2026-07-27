/*
 * [INPUT]: Depends on Mermaid 11.16.0 Gantt grammar, raw task declarations, calendar controls, interactions, and native diagram/Gantt models.
 * [OUTPUT]: Strictly parses every Gantt directive, merges include/exclude calendars, and resolves exclusion-aware multi-task after/until timing with millisecond-through-year duration units in two phases.
 * [POS]: Serves as the lossless native parser and temporal resolver for Gantt charts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/gantt.dart';

class GanttParser {
  const GanttParser();

  (MermaidDiagramData, GanttChartData)? parse(List<String> lines) {
    if (lines.isEmpty || lines.first.trim().toLowerCase() != 'gantt') {
      return null;
    }
    String? title;
    var dateFormat = 'YYYY-MM-DD';
    String? axisFormat;
    final excludes = <String>[];
    final includes = <String>[];
    var todayMarker = true;
    String? todayMarkerStyle;
    String? tickInterval;
    String? weekday;
    String? weekend;
    var inclusiveEndDates = false;
    var topAxis = false;
    String? accessibilityTitle;
    String? accessibilityDescription;
    String? currentSection;
    final declarations = <_TaskDeclaration>[];
    final sectionOrder = <String>[];
    final interactions = <GanttTaskInteraction>[];
    var index = 1;
    while (index < lines.length) {
      final line = lines[index++].trim();
      if (line.isEmpty || line == '---') continue;
      final lower = line.toLowerCase();
      if (lower.startsWith('title ')) {
        title = line.substring(6).trim();
      } else if (lower.startsWith('dateformat ')) {
        dateFormat = line.substring(11).trim();
      } else if (lower.startsWith('axisformat ')) {
        axisFormat = line.substring(11).trim();
      } else if (lower.startsWith('tickinterval ')) {
        tickInterval = line.substring(13).trim();
      } else if (lower.startsWith('excludes ')) {
        _mergeCalendarTokens(excludes, line.substring(9));
      } else if (lower.startsWith('includes ')) {
        _mergeCalendarTokens(includes, line.substring(9));
      } else if (lower.startsWith('todaymarker ')) {
        todayMarkerStyle = line.substring(12).trim();
        todayMarker = todayMarkerStyle.toLowerCase() != 'off';
      } else if (lower.startsWith('weekday ')) {
        weekday = line.substring(8).trim().toLowerCase();
        if (!_weekdays.contains(weekday)) return null;
      } else if (lower.startsWith('weekend ')) {
        weekend = line.substring(8).trim().toLowerCase();
        if (weekend != 'friday' && weekend != 'saturday') return null;
      } else if (lower == 'inclusiveenddates') {
        inclusiveEndDates = true;
      } else if (lower == 'topaxis') {
        topAxis = true;
      } else if (lower.startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
      } else if (lower.startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
      } else if (RegExp(
        r'^accDescr\s*\{.*\}\s*$',
        caseSensitive: false,
      ).hasMatch(line)) {
        accessibilityDescription = line
            .substring(line.indexOf('{') + 1, line.lastIndexOf('}'))
            .trim();
      } else if (RegExp(
        r'^accDescr\s*\{$',
        caseSensitive: false,
      ).hasMatch(line)) {
        final values = <String>[];
        var closed = false;
        while (index < lines.length) {
          final value = lines[index++].trim();
          if (value == '}') {
            closed = true;
            break;
          }
          values.add(value);
        }
        if (!closed) return null;
        accessibilityDescription = values.join('\n').trim();
      } else if (lower.startsWith('section ')) {
        currentSection = line.substring(8).trim();
        if (currentSection.isEmpty) return null;
        if (!sectionOrder.contains(currentSection)) {
          sectionOrder.add(currentSection);
        }
      } else if (lower.startsWith('click ')) {
        final interaction = _interaction(line);
        if (interaction == null) return null;
        interactions.add(interaction);
      } else {
        final declaration = _declaration(
          line,
          currentSection,
          declarations.length,
        );
        if (declaration == null) return null;
        declarations.add(declaration);
      }
    }

    final resolved = _resolve(
      declarations,
      dateFormat,
      inclusiveEndDates,
      excludes,
      includes,
      weekend ?? 'saturday',
    );
    if (resolved == null) return null;
    final ids = resolved.map((task) => task.id).toSet();
    if (ids.length != resolved.length ||
        interactions.any((item) => !ids.contains(item.taskId))) {
      return null;
    }
    final sections = [
      for (final name in sectionOrder)
        GanttSection(
          name: name,
          tasks: resolved.where((task) => task.section == name).toList(),
        ),
    ];
    final data = GanttChartData(
      title: title,
      tasks: resolved,
      sections: sections,
      dateFormat: dateFormat,
      axisFormat: axisFormat,
      excludes: excludes.isEmpty ? null : excludes.join(','),
      todayMarker: todayMarker,
      tickInterval: tickInterval,
      weekday: weekday,
      weekend: weekend,
      includes: includes.isEmpty ? null : includes.join(','),
      inclusiveEndDates: inclusiveEndDates,
      topAxis: topAxis,
      interactions: interactions,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      todayMarkerStyle: todayMarkerStyle,
    );
    return (
      MermaidDiagramData(
        type: DiagramType.ganttChart,
        nodes: const [],
        edges: const [],
        title: title,
      ),
      data,
    );
  }

  _TaskDeclaration? _declaration(String line, String? section, int index) {
    final separator = line.indexOf(':');
    if (separator < 1) return null;
    final name = line.substring(0, separator).trim();
    final raw = line.substring(separator + 1).trim();
    if (name.isEmpty || raw.isEmpty) return null;
    final parts = raw.split(',').map((part) => part.trim()).toList();
    final tags = <GanttTaskTag>[];
    while (parts.isNotEmpty) {
      final tag = _tag(parts.first);
      if (tag == null) break;
      tags.add(tag);
      parts.removeAt(0);
    }
    if (parts.isEmpty || parts.length > 3) return null;
    late final String id;
    String? start;
    late final String end;
    if (parts.length == 1) {
      id = 'task${index + 1}';
      end = parts[0];
    } else if (parts.length == 2) {
      id = 'task${index + 1}';
      start = parts[0];
      end = parts[1];
    } else {
      id = parts[0];
      start = parts[1];
      end = parts[2];
    }
    if (id.isEmpty || start?.isEmpty == true || end.isEmpty) return null;
    return _TaskDeclaration(
      index: index,
      id: id,
      name: name,
      section: section,
      tags: tags,
      raw: raw,
      start: start,
      end: end,
    );
  }

  List<GanttTask>? _resolve(
    List<_TaskDeclaration> declarations,
    String dateFormat,
    bool inclusiveEndDates,
    List<String> excludes,
    List<String> includes,
    String weekend,
  ) {
    if (declarations.isEmpty) return const [];
    final resolved = <String, GanttTask>{};
    final epoch = _defaultStart(dateFormat);
    for (var pass = 0; pass <= declarations.length; pass++) {
      var progress = false;
      for (final declaration in declarations) {
        if (resolved.containsKey(declaration.id)) continue;
        final previous = declaration.index == 0
            ? null
            : resolved[declarations[declaration.index - 1].id];
        if (declaration.index > 0 &&
            declaration.start == null &&
            previous == null) {
          continue;
        }
        final startResult = _start(
          declaration.start,
          previous,
          resolved,
          dateFormat,
          epoch,
        );
        if (startResult == null) continue;
        final endResult = _end(
          declaration.end,
          startResult.date,
          resolved,
          dateFormat,
          inclusiveEndDates,
        );
        if (endResult == null) continue;
        var end = endResult.date;
        if (endResult.kind == GanttTimingKind.duration && excludes.isNotEmpty) {
          final adjustedEnd = _extendForExcludedDates(
            startResult.date,
            end,
            excludes,
            includes,
            weekend,
          );
          if (adjustedEnd == null) return null;
          end = adjustedEnd;
        }
        if (declaration.tags.contains(GanttTaskTag.milestone)) {
          end = startResult.date;
        }
        resolved[declaration.id] = GanttTask(
          id: declaration.id,
          name: declaration.name,
          startDate: startResult.date,
          endDate: end,
          section: declaration.section,
          status: _status(declaration.tags),
          dependencies: startResult.dependencies,
          tags: declaration.tags,
          rawDefinition: declaration.raw,
          startSpecification: declaration.start,
          endSpecification: declaration.end,
          startKind: startResult.kind,
          endKind: endResult.kind,
          untilDependencies: endResult.dependencies,
        );
        progress = true;
      }
      if (resolved.length == declarations.length) break;
      if (!progress) return null;
    }
    return [for (final declaration in declarations) resolved[declaration.id]!];
  }

  void _mergeCalendarTokens(List<String> target, String source) {
    for (final token in source.toLowerCase().split(RegExp(r'[\s,]+'))) {
      if (token.isNotEmpty && !target.contains(token)) target.add(token);
    }
  }

  DateTime? _extendForExcludedDates(
    DateTime start,
    DateTime end,
    List<String> excludes,
    List<String> includes,
    String weekend,
  ) {
    var cursor = start.add(const Duration(days: 1));
    var adjustedEnd = end;
    var iterations = 0;
    while (!cursor.isAfter(adjustedEnd)) {
      if (_isExcluded(cursor, excludes, includes, weekend)) {
        adjustedEnd = adjustedEnd.add(const Duration(days: 1));
        if (++iterations > 10000) return null;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return adjustedEnd;
  }

  bool _isExcluded(
    DateTime date,
    List<String> excludes,
    List<String> includes,
    String weekend,
  ) {
    final iso = _isoDate(date);
    if (includes.contains(iso)) return false;
    final dayName = _weekdayName(date.weekday);
    if (includes.contains(dayName)) return false;
    if (excludes.contains(dayName) || excludes.contains(iso)) return true;
    if (!excludes.contains('weekends')) return false;
    final firstWeekendDay = weekend == 'friday'
        ? DateTime.friday
        : DateTime.saturday;
    final secondWeekendDay = firstWeekendDay == DateTime.saturday
        ? DateTime.sunday
        : DateTime.saturday;
    return date.weekday == firstWeekendDay || date.weekday == secondWeekendDay;
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _weekdayName(int weekday) => const {
    DateTime.monday: 'monday',
    DateTime.tuesday: 'tuesday',
    DateTime.wednesday: 'wednesday',
    DateTime.thursday: 'thursday',
    DateTime.friday: 'friday',
    DateTime.saturday: 'saturday',
    DateTime.sunday: 'sunday',
  }[weekday]!;

  _TimeResult? _start(
    String? source,
    GanttTask? previous,
    Map<String, GanttTask> resolved,
    String format,
    DateTime epoch,
  ) {
    if (source == null) {
      return _TimeResult(
        date: previous?.endDate ?? epoch,
        kind: GanttTimingKind.implicit,
      );
    }
    if (source.toLowerCase().startsWith('after ')) {
      final ids = source.substring(6).trim().split(RegExp(r'\s+'));
      final tasks = ids.map((id) => resolved[id]).toList();
      if (tasks.any((task) => task == null)) return null;
      final date = tasks
          .cast<GanttTask>()
          .map((task) => task.endDate)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      return _TimeResult(
        date: date,
        kind: GanttTimingKind.after,
        dependencies: ids,
      );
    }
    final date = _date(source, format);
    return date == null
        ? null
        : _TimeResult(date: date, kind: GanttTimingKind.date);
  }

  _TimeResult? _end(
    String source,
    DateTime start,
    Map<String, GanttTask> resolved,
    String format,
    bool inclusive,
  ) {
    if (source.toLowerCase().startsWith('until ')) {
      final ids = source.substring(6).trim().split(RegExp(r'\s+'));
      final tasks = ids.map((id) => resolved[id]).toList();
      if (tasks.any((task) => task == null)) return null;
      final date = tasks
          .cast<GanttTask>()
          .map((task) => task.startDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      return _TimeResult(
        date: date,
        kind: GanttTimingKind.until,
        dependencies: ids,
      );
    }
    final duration = _duration(source);
    if (duration != null) {
      return _TimeResult(
        date: duration.addTo(start),
        kind: GanttTimingKind.duration,
      );
    }
    final date = _date(source, format);
    if (date == null) return null;
    return _TimeResult(
      date: inclusive ? date.add(const Duration(days: 1)) : date,
      kind: GanttTimingKind.date,
    );
  }

  DateTime _defaultStart(String format) {
    final now = DateTime.now();
    if (format.trim() == 'HH:mm') {
      return DateTime(1970, 1, 1, now.hour, now.minute);
    }
    if (format.trim() == 'x' || format.trim() == 'X') {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _date(String source, String format) {
    final value = source.trim();
    try {
      if (format.trim() == 'x') {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(value));
      }
      if (format.trim() == 'X') {
        return DateTime.fromMillisecondsSinceEpoch(
          (double.parse(value) * 1000).round(),
        );
      }
      if (format.trim() == 'HH:mm') {
        final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
        if (match == null) return null;
        return DateTime(
          1970,
          1,
          1,
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
        );
      }
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        return DateTime.parse(value);
      }
      return DateTime.tryParse(value);
    } on FormatException {
      return null;
    }
  }

  _GanttDuration? _duration(String source) {
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)(ms|[Mdhmswy])$',
    ).firstMatch(source.trim());
    return match == null
        ? null
        : _GanttDuration(double.parse(match.group(1)!), match.group(2)!);
  }

  GanttTaskInteraction? _interaction(String line) {
    final match = RegExp(
      r'^click\s+(\S+)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return null;
    final tail = match.group(2)!;
    final hrefMatch = RegExp(
      r'href\s+"([^"]*)"',
      caseSensitive: false,
    ).firstMatch(tail);
    final callMatch = RegExp(
      r'call\s+([\w.]+)\s*\(([^)]*)\)',
      caseSensitive: false,
    ).firstMatch(tail);
    if (hrefMatch == null && callMatch == null) return null;
    final remainder = tail
        .replaceAll(RegExp(r'href\s+"[^"]*"', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'call\s+[\w.]+\s*\([^)]*\)', caseSensitive: false),
          '',
        )
        .trim();
    if (remainder.isNotEmpty) return null;
    return GanttTaskInteraction(
      taskId: match.group(1)!,
      href: hrefMatch?.group(1),
      callback: callMatch?.group(1),
      callbackArguments: callMatch?.group(2),
    );
  }

  GanttTaskTag? _tag(String value) => switch (value.toLowerCase()) {
    'active' => GanttTaskTag.active,
    'done' => GanttTaskTag.done,
    'crit' || 'critical' => GanttTaskTag.critical,
    'milestone' => GanttTaskTag.milestone,
    'vert' => GanttTaskTag.vertical,
    _ => null,
  };
  GanttTaskStatus _status(List<GanttTaskTag> tags) =>
      tags.contains(GanttTaskTag.critical)
      ? GanttTaskStatus.critical
      : tags.contains(GanttTaskTag.done)
      ? GanttTaskStatus.done
      : tags.contains(GanttTaskTag.active)
      ? GanttTaskStatus.active
      : tags.contains(GanttTaskTag.milestone)
      ? GanttTaskStatus.milestone
      : GanttTaskStatus.normal;
  static const _weekdays = {
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  };
}

class _TaskDeclaration {
  const _TaskDeclaration({
    required this.index,
    required this.id,
    required this.name,
    required this.section,
    required this.tags,
    required this.raw,
    required this.start,
    required this.end,
  });
  final int index;
  final String id;
  final String name;
  final String? section;
  final List<GanttTaskTag> tags;
  final String raw;
  final String? start;
  final String end;
}

class _TimeResult {
  const _TimeResult({
    required this.date,
    required this.kind,
    this.dependencies = const [],
  });
  final DateTime date;
  final GanttTimingKind kind;
  final List<String> dependencies;
}

class _GanttDuration {
  const _GanttDuration(this.value, this.unit);
  final double value;
  final String unit;

  DateTime addTo(DateTime start) {
    if (unit == 'M') {
      return DateTime(
        start.year,
        start.month + value.round(),
        start.day,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
        start.microsecond,
      );
    }
    if (unit == 'y') {
      return DateTime(
        start.year + value.round(),
        start.month,
        start.day,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
        start.microsecond,
      );
    }
    final milliseconds = switch (unit) {
      'ms' => value,
      's' => value * 1000,
      'm' => value * 60000,
      'h' => value * 3600000,
      'd' => value * 86400000,
      'w' => value * 604800000,
      _ => 0,
    };
    return start.add(Duration(milliseconds: milliseconds.round()));
  }
}
