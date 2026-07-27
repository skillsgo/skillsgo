/*
 * [INPUT]: Depends on Flutter Canvas, responsive configuration, resolved Gantt tasks/directives/configuration, and Mermaid semantic styles.
 * [OUTPUT]: Paints native Gantt axes with configured intervals/formats/top duplication, compact lanes, configured bars/gaps/padding/fonts, excluded calendar bands, milestones, sections, grids, and today marker.
 * [POS]: Serves as the chart-specific renderer and size calculator for Mermaid Gantt diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/responsive_config.dart';
import '../models/gantt.dart';
import '../models/style.dart';
import 'css_color.dart';

/// Painter for Gantt chart diagrams
class GanttPainter extends CustomPainter {
  /// Creates a Gantt chart painter
  const GanttPainter({
    required this.ganttData,
    required this.style,
    this.deviceConfig,
  });

  /// The Gantt chart data to render
  final GanttChartData ganttData;

  /// Style configuration
  final MermaidStyle style;

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  Color _themeColor(String? value, int fallback) =>
      parseMermaidCssColor(value) ?? Color(fallback);

  Color get _gridColor =>
      _themeColor(ganttData.theme.grid, GanttChartColors.gridLineColor);
  Color get _defaultTextColor => _themeColor(
    ganttData.theme.text,
    style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor,
  );

  GanttTaskInteraction? interactionAt(Offset position, Size size) {
    if (ganttData.tasks.isEmpty || ganttData.interactions.isEmpty) return null;
    final padding = ganttData.leftPadding.toDouble();
    final labelWidth = _calculateLabelWidth(size.width);
    final timelineWidth =
        size.width - labelWidth - padding - ganttData.rightPadding;
    var currentY = ganttData.titleTopMargin.toDouble();
    if (ganttData.title != null) {
      currentY += 40 + ganttData.topPadding;
    }
    if (ganttData.topAxis) currentY += 50;
    final rowHeight = (ganttData.barHeight + ganttData.barGap).toDouble();
    final dayWidth = timelineWidth / ganttData.totalDays;
    final minDate = ganttData.minDate!;
    final lanes = ganttData.taskLanes;
    for (var index = ganttData.tasks.length - 1; index >= 0; index--) {
      final task = ganttData.tasks[index];
      final start =
          task.startDate.difference(minDate).inMicroseconds /
          Duration.microsecondsPerDay;
      final duration = math.max(
        task.endDate.difference(task.startDate).inMicroseconds /
            Duration.microsecondsPerDay,
        1 / Duration.hoursPerDay,
      );
      final x = padding + labelWidth + start * dayWidth;
      final y = currentY + lanes[index] * rowHeight + ganttData.barGap / 2;
      final width = math.max(duration * dayWidth, 4.0);
      final hitRect = Rect.fromLTWH(
        x - 4,
        y - 4,
        width + 8,
        ganttData.barHeight + 8,
      );
      if (!hitRect.contains(position)) continue;
      for (final interaction in ganttData.interactions) {
        if (interaction.taskId == task.id) return interaction;
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (ganttData.tasks.isEmpty) return;

    final padding = ganttData.leftPadding.toDouble();
    final titleHeight = ganttData.title != null ? 40.0 : 0.0;

    // Layout constants
    final taskRowHeight = (ganttData.barHeight + ganttData.barGap).toDouble();
    final labelWidth = _calculateLabelWidth(size.width);
    final headerHeight = 50.0;
    final timelineWidth =
        size.width - labelWidth - padding - ganttData.rightPadding;

    // Calculate date range
    final minDate = ganttData.minDate!;
    final maxDate = ganttData.maxDate!;
    final totalDays = ganttData.totalDays;

    // Draw title if present
    var currentY = ganttData.titleTopMargin.toDouble();
    if (ganttData.title != null) {
      _drawTitle(canvas, ganttData.title!, size.width / 2, currentY);
      currentY += titleHeight + ganttData.topPadding;
    }

    if (ganttData.topAxis) {
      _drawTimelineHeader(
        canvas,
        Offset(labelWidth + padding, currentY),
        timelineWidth,
        headerHeight,
        minDate,
        totalDays,
      );
      currentY += headerHeight;
    }

    // Draw grid and tasks
    _drawGridAndTasks(
      canvas,
      Offset(padding, currentY),
      labelWidth,
      timelineWidth,
      taskRowHeight,
      minDate,
      totalDays,
    );

    _drawTimelineHeader(
      canvas,
      Offset(
        labelWidth + padding,
        currentY + taskRowHeight * ganttData.laneCount,
      ),
      timelineWidth,
      headerHeight,
      minDate,
      totalDays,
    );

    // Draw today marker if enabled
    if (ganttData.todayMarker) {
      final today = DateTime.now();
      if (!today.isBefore(minDate) && !today.isAfter(maxDate)) {
        _drawTodayMarker(
          canvas,
          labelWidth + padding,
          currentY,
          timelineWidth,
          taskRowHeight * ganttData.laneCount,
          minDate,
          today,
          totalDays,
        );
      }
    }
  }

  /// Calculates the width needed for task labels
  double _calculateLabelWidth(double totalWidth) {
    final fontSize = ganttData.fontSize.toDouble();
    var maxLabelWidth = 0.0;

    for (final task in ganttData.tasks) {
      final estimatedWidth = task.name.length * fontSize * 0.6;
      if (estimatedWidth > maxLabelWidth) {
        maxLabelWidth = estimatedWidth;
      }
    }

    // Add padding and constrain
    final labelWidth = (maxLabelWidth + 20).clamp(100.0, totalWidth * 0.35);
    return labelWidth;
  }

  /// Draws the chart title
  void _drawTitle(Canvas canvas, String title, double centerX, double y) {
    final textStyle = TextStyle(
      color: _themeColor(
        ganttData.theme.title,
        style.defaultNodeStyle.textColor ?? MermaidColors.defaultTextColor,
      ),
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
    );

    final textSpan = TextSpan(text: title, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, y));
  }

  /// Draws the timeline header with date markers
  void _drawTimelineHeader(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
  ) {
    final fontSize = ganttData.fontSize.toDouble();

    // Draw header background
    final headerPaint = Paint()
      ..color = Color(style.backgroundColor).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, width, height),
      headerPaint,
    );

    // Draw bottom border
    final borderPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(topLeft.dx, topLeft.dy + height),
      Offset(topLeft.dx + width, topLeft.dy + height),
      borderPaint,
    );

    // Calculate appropriate time scale
    final dayWidth = width / totalDays;
    final showDays = dayWidth >= 20;
    final showWeeks = dayWidth >= 5 && !showDays;

    final configuredInterval =
        _tickInterval() ??
        (ganttData.axisFormat == null
            ? null
            : (1, showDays ? 'day' : (showWeeks ? 'week' : 'month')));
    if (configuredInterval != null) {
      _drawConfiguredTicks(
        canvas,
        topLeft,
        width,
        height,
        minDate,
        totalDays,
        fontSize,
        configuredInterval,
      );
      return;
    }

    if (showDays && totalDays <= 60) {
      // Show individual days
      _drawDayMarkers(
        canvas,
        topLeft,
        width,
        height,
        minDate,
        totalDays,
        dayWidth,
        fontSize,
      );
    } else if (showWeeks || totalDays <= 120) {
      // Show weeks
      _drawWeekMarkers(
        canvas,
        topLeft,
        width,
        height,
        minDate,
        totalDays,
        dayWidth,
        fontSize,
      );
    } else {
      // Show months
      _drawMonthMarkers(
        canvas,
        topLeft,
        width,
        height,
        minDate,
        totalDays,
        dayWidth,
        fontSize,
      );
    }
  }

  (int, String)? _tickInterval() {
    final match = RegExp(
      r'^([1-9]\d*)(millisecond|second|minute|hour|day|week|month)$',
    ).firstMatch(ganttData.tickInterval?.trim() ?? '');
    if (match == null) return null;
    return (int.parse(match.group(1)!), match.group(2)!);
  }

  void _drawConfiguredTicks(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
    double fontSize,
    (int, String) interval,
  ) {
    final span = minDate.add(Duration(days: totalDays)).difference(minDate);
    final estimated = switch (interval.$2) {
      'millisecond' => span.inMilliseconds / interval.$1,
      'second' => span.inSeconds / interval.$1,
      'minute' => span.inMinutes / interval.$1,
      'hour' => span.inHours / interval.$1,
      'day' => span.inDays / interval.$1,
      'week' => span.inDays / (interval.$1 * 7),
      'month' => totalDays / (interval.$1 * 30),
      _ => 0,
    };
    final effectiveInterval = estimated > 10000
        ? (math.max(1, (totalDays / 10).ceil()), 'day')
        : interval;
    final textStyle = TextStyle(
      color: _defaultTextColor,
      fontSize: fontSize * 0.9,
      fontFamily: style.fontFamily,
    );
    final maxDate = minDate.add(Duration(days: totalDays));
    var tick = _alignTick(minDate, effectiveInterval.$2);
    var count = 0;
    while (!tick.isAfter(maxDate) && count++ < 10000) {
      if (!tick.isBefore(minDate)) {
        final fraction =
            tick.difference(minDate).inMicroseconds /
            maxDate.difference(minDate).inMicroseconds;
        final x = topLeft.dx + fraction * width;
        canvas.drawLine(
          Offset(x, topLeft.dy),
          Offset(x, topLeft.dy + height),
          Paint()
            ..color = _gridColor
            ..strokeWidth = 0.75,
        );
        final painter = TextPainter(
          text: TextSpan(text: _formatTick(tick), style: textStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: math.max(width, 1));
        painter.paint(
          canvas,
          Offset(
            (x - painter.width / 2).clamp(
              topLeft.dx,
              topLeft.dx + width - painter.width,
            ),
            topLeft.dy + height - painter.height - 3,
          ),
        );
      }
      tick = _advanceTick(tick, effectiveInterval.$1, effectiveInterval.$2);
    }
  }

  DateTime _alignTick(DateTime date, String unit) {
    if (unit == 'week') {
      final target = const {
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
        'friday': DateTime.friday,
        'saturday': DateTime.saturday,
        'sunday': DateTime.sunday,
      }[ganttData.weekday ?? 'sunday']!;
      var result = DateTime(date.year, date.month, date.day);
      while (result.weekday != target) {
        result = result.add(const Duration(days: 1));
      }
      return result;
    }
    if (unit == 'month') return DateTime(date.year, date.month);
    if (unit == 'day') return DateTime(date.year, date.month, date.day);
    if (unit == 'hour') {
      return DateTime(date.year, date.month, date.day, date.hour);
    }
    if (unit == 'minute') {
      return DateTime(date.year, date.month, date.day, date.hour, date.minute);
    }
    if (unit == 'second') {
      return DateTime(
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second,
      );
    }
    return date;
  }

  DateTime _advanceTick(DateTime date, int every, String unit) =>
      switch (unit) {
        'millisecond' => date.add(Duration(milliseconds: every)),
        'second' => date.add(Duration(seconds: every)),
        'minute' => date.add(Duration(minutes: every)),
        'hour' => date.add(Duration(hours: every)),
        'day' => date.add(Duration(days: every)),
        'week' => date.add(Duration(days: every * 7)),
        'month' => DateTime(date.year, date.month + every, date.day),
        _ => date,
      };

  String _formatTick(DateTime date) {
    final format = ganttData.axisFormat ?? '%Y-%m-%d';
    const shortMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const longMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const longDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayOfYear = date.difference(DateTime(date.year)).inDays + 1;
    final sundayWeek = ((dayOfYear - 1 + DateTime(date.year).weekday % 7) ~/ 7);
    final mondayWeek = ((dayOfYear - 1 + DateTime(date.year).weekday - 1) ~/ 7);
    final twelveHour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final replacements = <String, String>{
      '%Y': date.year.toString().padLeft(4, '0'),
      '%y': (date.year % 100).toString().padLeft(2, '0'),
      '%m': date.month.toString().padLeft(2, '0'),
      '%b': shortMonths[date.month - 1],
      '%B': longMonths[date.month - 1],
      '%d': date.day.toString().padLeft(2, '0'),
      '%e': date.day.toString().padLeft(2, ' '),
      '%H': date.hour.toString().padLeft(2, '0'),
      '%M': date.minute.toString().padLeft(2, '0'),
      '%S': date.second.toString().padLeft(2, '0'),
      '%L': date.millisecond.toString().padLeft(3, '0'),
      '%f': (date.millisecond * 1000).toString().padLeft(6, '0'),
      '%a': shortDays[date.weekday - 1],
      '%A': longDays[date.weekday - 1],
      '%j': dayOfYear.toString().padLeft(3, '0'),
      '%I': twelveHour.toString().padLeft(2, '0'),
      '%p': date.hour < 12 ? 'AM' : 'PM',
      '%q': (((date.month - 1) ~/ 3) + 1).toString(),
      '%Q': date.millisecondsSinceEpoch.toString(),
      '%s': (date.millisecondsSinceEpoch ~/ 1000).toString(),
      '%u': date.weekday.toString(),
      '%w': (date.weekday % 7).toString(),
      '%U': sundayWeek.toString().padLeft(2, '0'),
      '%W': mondayWeek.toString().padLeft(2, '0'),
      '%Z': date.timeZoneOffset == Duration.zero ? '+0000' : _timezone(date),
      '%x':
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.year}',
      '%X':
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}:'
          '${date.second.toString().padLeft(2, '0')}',
      '%%': '%',
    };
    var result = format;
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  String _timezone(DateTime date) {
    final offset = date.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    return '$sign${(minutes ~/ 60).toString().padLeft(2, '0')}'
        '${(minutes % 60).toString().padLeft(2, '0')}';
  }

  /// Draws day markers on the timeline
  void _drawDayMarkers(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
    double dayWidth,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      color: _defaultTextColor,
      fontSize: fontSize * 0.9,
      fontFamily: style.fontFamily,
    );

    for (var i = 0; i < totalDays; i++) {
      final date = minDate.add(Duration(days: i));
      final x = topLeft.dx + i * dayWidth;

      // Draw vertical grid line
      final linePaint = Paint()
        ..color = _gridColor.withValues(alpha: 0.5)
        ..strokeWidth = 0.5;

      canvas.drawLine(
        Offset(x, topLeft.dy),
        Offset(x, topLeft.dy + height),
        linePaint,
      );

      // Draw day number
      if (dayWidth >= 25) {
        final dayText = '${date.day}';
        final textSpan = TextSpan(text: dayText, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        textPainter.paint(
          canvas,
          Offset(
            x + (dayWidth - textPainter.width) / 2,
            topLeft.dy + height - 20,
          ),
        );
      }

      // Draw month name at the start of each month
      if (date.day == 1 || i == 0) {
        final monthText = _getMonthName(date.month);
        final monthStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
        final monthSpan = TextSpan(text: monthText, style: monthStyle);
        final monthPainter = TextPainter(
          text: monthSpan,
          textDirection: TextDirection.ltr,
        );
        monthPainter.layout();

        monthPainter.paint(canvas, Offset(x + 4, topLeft.dy + 4));
      }
    }
  }

  /// Draws week markers on the timeline
  void _drawWeekMarkers(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
    double dayWidth,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      color: _defaultTextColor,
      fontSize: fontSize * 0.9,
      fontFamily: style.fontFamily,
    );

    // Find the first Monday
    var currentDate = minDate;
    while (currentDate.weekday != DateTime.monday) {
      currentDate = currentDate.add(const Duration(days: 1));
    }

    while (!currentDate.isAfter(minDate.add(Duration(days: totalDays)))) {
      final daysFromStart = currentDate.difference(minDate).inDays;
      final x = topLeft.dx + daysFromStart * dayWidth;

      if (x >= topLeft.dx && x <= topLeft.dx + width) {
        // Draw week marker line
        final linePaint = Paint()
          ..color = _gridColor
          ..strokeWidth = 1.0;

        canvas.drawLine(
          Offset(x, topLeft.dy),
          Offset(x, topLeft.dy + height),
          linePaint,
        );

        // Draw week date
        final weekText = '${currentDate.month}/${currentDate.day}';
        final textSpan = TextSpan(text: weekText, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        textPainter.paint(canvas, Offset(x + 4, topLeft.dy + height - 18));
      }

      currentDate = currentDate.add(const Duration(days: 7));
    }

    // Draw month names
    var lastMonth = -1;
    for (var i = 0; i < totalDays; i++) {
      final date = minDate.add(Duration(days: i));
      if (date.month != lastMonth) {
        lastMonth = date.month;
        final x = topLeft.dx + i * dayWidth;

        final monthText = '${_getMonthName(date.month)} ${date.year}';
        final monthStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
        final monthSpan = TextSpan(text: monthText, style: monthStyle);
        final monthPainter = TextPainter(
          text: monthSpan,
          textDirection: TextDirection.ltr,
        );
        monthPainter.layout();

        monthPainter.paint(canvas, Offset(x + 4, topLeft.dy + 4));
      }
    }
  }

  /// Draws month markers on the timeline
  void _drawMonthMarkers(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
    double dayWidth,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      color: _defaultTextColor,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
    );

    var lastMonth = -1;
    for (var i = 0; i < totalDays; i++) {
      final date = minDate.add(Duration(days: i));
      if (date.month != lastMonth || date.day == 1) {
        if (date.month != lastMonth) {
          lastMonth = date.month;
          final x = topLeft.dx + i * dayWidth;

          // Draw month divider line
          final linePaint = Paint()
            ..color = _gridColor
            ..strokeWidth = 1.5;

          canvas.drawLine(
            Offset(x, topLeft.dy),
            Offset(x, topLeft.dy + height),
            linePaint,
          );

          // Draw month name
          final monthText = '${_getMonthName(date.month)} ${date.year}';
          final textSpan = TextSpan(text: monthText, style: textStyle);
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();

          textPainter.paint(
            canvas,
            Offset(x + 4, topLeft.dy + (height - textPainter.height) / 2),
          );
        }
      }
    }
  }

  /// Draws the task grid and task bars
  void _drawGridAndTasks(
    Canvas canvas,
    Offset topLeft,
    double labelWidth,
    double timelineWidth,
    double taskRowHeight,
    DateTime minDate,
    int totalDays,
  ) {
    final dayWidth = timelineWidth / totalDays;

    // Group tasks by section for alternating backgrounds
    var currentSection = '';
    var sectionIndex = -1;

    final lanes = ganttData.taskLanes;
    for (var i = 0; i < ganttData.tasks.length; i++) {
      final task = ganttData.tasks[i];
      final y = topLeft.dy + lanes[i] * taskRowHeight;

      // Check for section change
      var sectionChanged = false;
      if (task.section != null && task.section != currentSection) {
        currentSection = task.section!;
        sectionIndex++;
        sectionChanged = true;
      }
      if (sectionIndex < 0) sectionIndex = 0;

      // Draw row background (alternating by section)
      final bgPaint = Paint()
        ..color = _sectionBackground(sectionIndex)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(topLeft.dx, y, labelWidth + timelineWidth, taskRowHeight),
        bgPaint,
      );

      _drawExcludedCalendarBands(
        canvas,
        Offset(topLeft.dx + labelWidth, y),
        timelineWidth,
        taskRowHeight,
        minDate,
        totalDays,
      );

      // Draw horizontal grid line
      final gridPaint = Paint()
        ..color = _gridColor
        ..strokeWidth = 0.5;

      canvas.drawLine(
        Offset(topLeft.dx, y + taskRowHeight),
        Offset(topLeft.dx + labelWidth + timelineWidth, y + taskRowHeight),
        gridPaint,
      );

      // Draw task label
      _drawTaskLabel(
        canvas,
        sectionChanged ? currentSection : '',
        topLeft.dx,
        y,
        labelWidth,
        taskRowHeight,
        ganttData.sectionFontSize,
      );

      // Draw task bar
      final taskStartDays =
          task.startDate.difference(minDate).inMicroseconds /
          Duration.microsecondsPerDay;
      final taskDuration = math.max(
        task.endDate.difference(task.startDate).inMicroseconds /
            Duration.microsecondsPerDay,
        1 / Duration.hoursPerDay,
      );

      final barX = topLeft.dx + labelWidth + taskStartDays * dayWidth;
      final barWidth = math.max(taskDuration * dayWidth, 4.0);
      final barY = y + ganttData.barGap / 2;
      final barHeight = ganttData.barHeight.toDouble();

      if (task.tags.contains(GanttTaskTag.milestone) ||
          task.status == GanttTaskStatus.milestone) {
        // Draw milestone as diamond
        _drawMilestone(canvas, barX, barY + barHeight / 2, barHeight / 2, task);
      } else {
        // Draw task bar
        _drawTaskBar(canvas, barX, barY, barWidth, barHeight, task);
      }
      _drawTaskText(
        canvas,
        task,
        barX,
        barY,
        barWidth,
        barHeight,
        topLeft.dx + labelWidth + timelineWidth,
      );
      if (task.tags.contains(GanttTaskTag.vertical)) {
        _drawVerticalMarker(
          canvas,
          task,
          barX,
          topLeft.dy - ganttData.gridLineStartPadding,
          ganttData.laneCount * taskRowHeight + ganttData.gridLineStartPadding,
        );
      }
    }

    // Draw vertical separator between labels and timeline
    final separatorPaint = Paint()
      ..color = _gridColor
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(topLeft.dx + labelWidth, topLeft.dy),
      Offset(
        topLeft.dx + labelWidth,
        topLeft.dy + ganttData.laneCount * taskRowHeight,
      ),
      separatorPaint,
    );
  }

  void _drawExcludedCalendarBands(
    Canvas canvas,
    Offset topLeft,
    double width,
    double height,
    DateTime minDate,
    int totalDays,
  ) {
    final excludes = _calendarTokens(ganttData.excludes);
    if (excludes.isEmpty) return;
    final includes = _calendarTokens(ganttData.includes);
    final dayWidth = width / totalDays;
    final paint = Paint()
      ..color = _themeColor(
        ganttData.theme.excludeBackground,
        GanttChartColors.gridLineColor,
      ).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    for (var day = 0; day < totalDays; day++) {
      final date = minDate.add(Duration(days: day));
      if (!_isExcluded(date, excludes, includes)) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          topLeft.dx + day * dayWidth,
          topLeft.dy,
          dayWidth,
          height,
        ),
        paint,
      );
    }
  }

  Set<String> _calendarTokens(String? source) => source == null
      ? const {}
      : source
            .toLowerCase()
            .split(RegExp(r'[\s,]+'))
            .where((token) => token.isNotEmpty)
            .toSet();

  bool _isExcluded(DateTime date, Set<String> excludes, Set<String> includes) {
    final iso =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final weekday = const {
      DateTime.monday: 'monday',
      DateTime.tuesday: 'tuesday',
      DateTime.wednesday: 'wednesday',
      DateTime.thursday: 'thursday',
      DateTime.friday: 'friday',
      DateTime.saturday: 'saturday',
      DateTime.sunday: 'sunday',
    }[date.weekday]!;
    if (includes.contains(iso) || includes.contains(weekday)) return false;
    if (excludes.contains(iso) || excludes.contains(weekday)) return true;
    if (!excludes.contains('weekends')) return false;
    final first = ganttData.weekend == 'friday'
        ? DateTime.friday
        : DateTime.saturday;
    return date.weekday == first ||
        date.weekday ==
            (first == DateTime.friday ? DateTime.saturday : DateTime.sunday);
  }

  /// Draws a task label
  void _drawTaskLabel(
    Canvas canvas,
    String label,
    double x,
    double y,
    double width,
    double height,
    double fontSize,
  ) {
    final textStyle = TextStyle(
      color: _defaultTextColor,
      fontSize: fontSize,
      fontFamily: style.fontFamily,
    );

    final textSpan = TextSpan(text: label, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: width - 16);

    textPainter.paint(
      canvas,
      Offset(x + 8, y + (height - textPainter.height) / 2),
    );
  }

  /// Draws a task bar
  void _drawTaskBar(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    GanttTask task,
  ) {
    final colors = _taskColors(task);
    final paint = Paint()
      ..color = colors.$1
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      const Radius.circular(4),
    );

    canvas.drawRRect(rect, paint);

    // Draw border for better visibility
    final borderPaint = Paint()
      ..color = colors.$2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rect, borderPaint);
  }

  /// Draws a milestone marker
  void _drawMilestone(
    Canvas canvas,
    double x,
    double y,
    double size,
    GanttTask task,
  ) {
    final colors = _taskColors(task);
    final paint = Paint()
      ..color = colors.$1
      ..style = PaintingStyle.fill;

    // Draw diamond shape
    final path = Path()
      ..moveTo(x, y - size)
      ..lineTo(x + size, y)
      ..lineTo(x, y + size)
      ..lineTo(x - size, y)
      ..close();

    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = colors.$2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, borderPaint);
  }

  (Color, Color, Color) _taskColors(GanttTask task) {
    final critical = task.tags.contains(GanttTaskTag.critical);
    final done = task.tags.contains(GanttTaskTag.done);
    final active = task.tags.contains(GanttTaskTag.active);
    if (critical) {
      final fill = done
          ? _themeColor(
              ganttData.theme.doneTaskBackground,
              GanttChartColors.doneColor,
            )
          : active
          ? _themeColor(
              ganttData.theme.activeTaskBackground,
              GanttChartColors.activeColor,
            )
          : _themeColor(
              ganttData.theme.criticalBackground,
              GanttChartColors.criticalColor,
            );
      return (
        fill,
        _themeColor(
          ganttData.theme.criticalBorder,
          GanttChartColors.criticalColor,
        ),
        _themeColor(ganttData.theme.taskTextDark, 0xff000000),
      );
    }
    if (done || task.status == GanttTaskStatus.done) {
      return (
        _themeColor(
          ganttData.theme.doneTaskBackground,
          GanttChartColors.doneColor,
        ),
        _themeColor(ganttData.theme.doneTaskBorder, GanttChartColors.doneColor),
        _themeColor(ganttData.theme.taskTextDark, 0xff000000),
      );
    }
    if (active || task.status == GanttTaskStatus.active) {
      return (
        _themeColor(
          ganttData.theme.activeTaskBackground,
          GanttChartColors.activeColor,
        ),
        _themeColor(
          ganttData.theme.activeTaskBorder,
          GanttChartColors.activeColor,
        ),
        _themeColor(ganttData.theme.taskTextDark, 0xff000000),
      );
    }
    return (
      _themeColor(ganttData.theme.taskBackground, GanttChartColors.normalColor),
      _themeColor(ganttData.theme.taskBorder, GanttChartColors.normalColor),
      _themeColor(ganttData.theme.taskText, 0xffffffff),
    );
  }

  void _drawTaskText(
    Canvas canvas,
    GanttTask task,
    double x,
    double y,
    double width,
    double height,
    double chartRight,
  ) {
    final insideColor = _taskColors(task).$3;
    final outsideColor =
        ganttData.interactions.any(
          (interaction) => interaction.taskId == task.id,
        )
        ? _themeColor(ganttData.theme.taskTextClickable, 0xff003163)
        : _themeColor(
            ganttData.theme.taskTextOutside ?? ganttData.theme.taskTextDark,
            _defaultTextColor.toARGB32(),
          );
    var painter = _taskTextPainter(task.name, insideColor);
    painter.layout();
    final fits = painter.width + 8 <= width;
    if (!fits) {
      painter = _taskTextPainter(task.name, outsideColor)..layout();
    }
    final paintX = fits
        ? x + (width - painter.width) / 2
        : math.min(x + width + 5, chartRight - painter.width);
    painter.paint(canvas, Offset(paintX, y + (height - painter.height) / 2));
  }

  TextPainter _taskTextPainter(String value, Color color) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: color,
        fontSize: ganttData.fontSize.toDouble(),
        fontFamily: style.fontFamily,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  );

  void _drawVerticalMarker(
    Canvas canvas,
    GanttTask task,
    double x,
    double y,
    double height,
  ) {
    final color = _themeColor(ganttData.theme.verticalLine, 0xff000080);
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + height),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
    final painter = _taskTextPainter(task.name, color)..layout();
    painter.paint(canvas, Offset(x - painter.width / 2, y - painter.height));
  }

  Color _sectionBackground(int index) {
    final themed = switch (index % math.max(1, ganttData.numberSectionStyles)) {
      0 => ganttData.theme.sectionBackground,
      2 => ganttData.theme.sectionBackground2,
      _ => ganttData.theme.alternateSectionBackground,
    };
    return _themeColor(
      themed,
      GanttChartColors.sectionColors[index %
          GanttChartColors.sectionColors.length],
    ).withValues(alpha: .34);
  }

  (Color, double) _todayStyle() {
    var color = _themeColor(
      ganttData.theme.todayLine,
      GanttChartColors.todayMarkerColor,
    );
    var width = 2.0;
    final source = ganttData.todayMarkerStyle;
    if (source == null) return (color, width);
    for (final declaration in source.split(RegExp(r'[,;]'))) {
      final separator = declaration.indexOf(':');
      if (separator < 0) continue;
      final key = declaration.substring(0, separator).trim().toLowerCase();
      final value = declaration.substring(separator + 1).trim();
      if (key == 'stroke' || key == 'color') {
        color = parseMermaidCssColor(value) ?? color;
      } else if (key == 'stroke-width') {
        width =
            double.tryParse(value.replaceFirst(RegExp(r'px$'), '')) ?? width;
      }
    }
    return (color, width.clamp(.1, 20));
  }

  /// Draws the today marker
  void _drawTodayMarker(
    Canvas canvas,
    double startX,
    double y,
    double timelineWidth,
    double gridHeight,
    DateTime minDate,
    DateTime today,
    int totalDays,
  ) {
    final dayWidth = timelineWidth / totalDays;
    final todayOffset = today.difference(minDate).inDays;
    final x = startX + todayOffset * dayWidth;

    // Draw vertical line
    final todayStyle = _todayStyle();
    final linePaint = Paint()
      ..color = todayStyle.$1
      ..strokeWidth = todayStyle.$2;

    canvas.drawLine(Offset(x, y), Offset(x, y + gridHeight), linePaint);

    // Draw "Today" label
    final textStyle = TextStyle(
      color: todayStyle.$1,
      fontSize: 10.0,
      fontWeight: FontWeight.bold,
      fontFamily: style.fontFamily,
    );

    final textSpan = TextSpan(text: 'Today', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Draw background for label
    final bgPaint = Paint()
      ..color = todayStyle.$1.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - textPainter.width / 2 - 4,
          y - 16,
          textPainter.width + 8,
          14,
        ),
        const Radius.circular(2),
      ),
      bgPaint,
    );

    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 15));
  }

  /// Gets month name abbreviation
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  @override
  bool shouldRepaint(covariant GanttPainter oldDelegate) {
    return ganttData != oldDelegate.ganttData || style != oldDelegate.style;
  }
}

/// Layout engine for Gantt charts
class GanttChartLayout {
  /// Creates a Gantt chart layout
  const GanttChartLayout({this.deviceConfig});

  /// Responsive device configuration
  final MermaidDeviceConfig? deviceConfig;

  /// Computes the size needed to render the Gantt chart
  Size computeLayout(
    GanttChartData ganttData,
    MermaidStyle style,
    Size availableSize,
  ) {
    if (ganttData.tasks.isEmpty) {
      return const Size(400, 200);
    }

    final padding = ganttData.leftPadding.toDouble();
    final titleHeight = ganttData.title != null ? 50.0 : 0.0;
    final headerHeight = ganttData.topAxis ? 100.0 : 50.0;
    final taskRowHeight = (ganttData.barHeight + ganttData.barGap).toDouble();

    // Calculate minimum width based on date range
    final totalDays = ganttData.totalDays;
    final minDayWidth = deviceConfig?.deviceType == DeviceType.mobile
        ? 8.0
        : 15.0;
    final minTimelineWidth = totalDays * minDayWidth;

    // Calculate label width
    final fontSize = ganttData.fontSize.toDouble();
    var maxLabelWidth = 0.0;
    for (final task in ganttData.tasks) {
      final estimatedWidth = task.name.length * fontSize * 0.6;
      if (estimatedWidth > maxLabelWidth) {
        maxLabelWidth = estimatedWidth;
      }
    }
    final labelWidth = (maxLabelWidth + 20).clamp(100.0, 250.0);

    // Calculate total size
    final minWidth = labelWidth + minTimelineWidth + padding * 2;
    final minHeight =
        titleHeight +
        headerHeight +
        ganttData.laneCount * taskRowHeight +
        ganttData.titleTopMargin +
        ganttData.topPadding;

    // Constrain to available size
    final width = ganttData.useMaxWidth
        ? math.max(minWidth, availableSize.width)
        : minWidth;
    final height = math.max(
      minHeight,
      math.min(minHeight, availableSize.height),
    );

    return Size(width, height);
  }
}
