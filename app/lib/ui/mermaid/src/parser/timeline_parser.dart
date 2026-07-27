/*
 * [INPUT]: Depends on Mermaid 11.16.0 Timeline Jison grammar and native Timeline/diagram models.
 * [OUTPUT]: Strictly parses LR/TD direction, sections, periods, event continuations, title, accessibility, and comment syntax.
 * [POS]: Serves as the lossless native Timeline parser before configuration and Canvas rendering.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/timeline.dart';

class TimelineParser {
  const TimelineParser();

  (MermaidDiagramData, TimelineChartData)? parse(List<String> lines) {
    if (lines.isEmpty) return null;
    final header = RegExp(
      r'^timeline(?:\s+(LR|TD))?\s*$',
      caseSensitive: false,
    ).firstMatch(lines.first.trim());
    if (header == null) return null;

    final direction = header.group(1)?.toUpperCase() == 'TD'
        ? TimelineDirection.topDown
        : TimelineDirection.leftToRight;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    final sections = <TimelineSection>[];
    var currentSectionTitle = '';
    var currentTasks = <TimelineEvent>[];
    var hasExplicitSection = false;

    void flushSection({bool includeEmpty = false}) {
      if (currentTasks.isEmpty && !includeEmpty) return;
      sections.add(
        TimelineSection(
          title: currentSectionTitle,
          events: List<TimelineEvent>.unmodifiable(currentTasks),
        ),
      );
      currentTasks = <TimelineEvent>[];
    }

    var index = 1;
    while (index < lines.length) {
      final raw = lines[index++];
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final lower = line.toLowerCase();
      if (lower.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (lower.startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (lower.startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      final inlineDescription = RegExp(
        r'^accDescr\s*\{(.*)\}\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (inlineDescription != null) {
        accessibilityDescription = inlineDescription.group(1)!.trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
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
        continue;
      }
      final section = RegExp(
        r'^section\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (section != null) {
        if (hasExplicitSection || currentTasks.isNotEmpty) flushSection();
        currentSectionTitle = section.group(1)!.trim();
        currentTasks = <TimelineEvent>[];
        hasExplicitSection = true;
        continue;
      }

      final parts = _splitEventFields(line);
      if (parts.isEmpty) return null;
      if (parts.first.isEmpty) {
        if (currentTasks.isEmpty || parts.length == 1) return null;
        final previous = currentTasks.last;
        currentTasks[currentTasks.length - 1] = previous.copyWith(
          periods: [...previous.periods, ...parts.skip(1)],
        );
      } else {
        currentTasks.add(
          TimelineEvent(title: parts.first, periods: parts.skip(1).toList()),
        );
      }
    }
    if (currentTasks.isNotEmpty || hasExplicitSection) {
      flushSection(includeEmpty: hasExplicitSection && currentTasks.isEmpty);
    }

    final data = TimelineChartData(
      title: title,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      direction: direction,
      sections: List<TimelineSection>.unmodifiable(sections),
    );
    return (
      MermaidDiagramData(
        type: DiagramType.timeline,
        nodes: const [],
        edges: const [],
        title: title,
      ),
      data,
    );
  }

  List<String> _splitEventFields(String source) {
    final result = <String>[];
    var start = 0;
    for (var index = 0; index < source.length; index++) {
      if (source[index] != ':') continue;
      final nextIsSeparator =
          index + 1 == source.length || _isWhitespace(source[index + 1]);
      if (!nextIsSeparator) continue;
      result.add(source.substring(start, index).trim());
      start = index + 1;
      while (start < source.length && _isWhitespace(source[start])) {
        start++;
      }
      index = start - 1;
    }
    result.add(source.substring(start).trim());
    return result;
  }

  bool _isWhitespace(String value) => value.trim().isEmpty;
}
