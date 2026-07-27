/*
 * [INPUT]: Depends on Mermaid 11.16.0 user-journey grammar and native journey plus shared graph models.
 * [OUTPUT]: Strictly parses titles, accessibility directives, ordered sections, numeric task scores, and actor lists.
 * [POS]: Serves as the lossless native parser for journey and rejects unknown statements instead of dropping them.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/journey.dart';
import '../models/node.dart';

class NativeJourneyDiagramParser {
  const NativeJourneyDiagramParser();

  (MermaidDiagramData, JourneyChartData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (header < 0 || lines[header].trim().toLowerCase() != 'journey') {
      return null;
    }
    final sections = <JourneySectionData>[];
    final tasks = <JourneyTaskData>[];
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    int? currentSection;
    var index = header + 1;
    while (index < lines.length) {
      final line = _withoutComment(lines[index++]).trim();
      if (line.isEmpty || line == '---') continue;
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
      final inlineAccDescr = RegExp(
        r'^accDescr\s*\{(.*)\}\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (inlineAccDescr != null) {
        accessibilityDescription = inlineAccDescr.group(1)!.trim();
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
      if (lower.startsWith('section ')) {
        final sectionTitle = line.substring(8).trim();
        if (sectionTitle.isEmpty || RegExp(r'[:;]').hasMatch(sectionTitle)) {
          return null;
        }
        currentSection = sections.length;
        sections.add(
          JourneySectionData(index: currentSection, title: sectionTitle),
        );
        continue;
      }
      final task = RegExp(
        r'^([^:;]+?)\s*:\s*([^:;]+)(?:\s*:\s*([^;]*))?$',
      ).firstMatch(line);
      if (task == null) return null;
      final name = task.group(1)!.trim();
      final scoreSource = task.group(2)!.trim();
      final score = double.tryParse(scoreSource);
      if (name.isEmpty || score == null || !score.isFinite) return null;
      final actors = (task.group(3) ?? '')
          .split(',')
          .map((actor) => actor.trim())
          .where((actor) => actor.isNotEmpty)
          .toList();
      tasks.add(
        JourneyTaskData(
          index: tasks.length,
          name: name,
          score: score,
          actors: actors,
          sectionIndex: currentSection,
          rawTaskData: line.substring(line.indexOf(':')),
        ),
      );
    }
    final nodes = [
      for (final task in tasks)
        MermaidNode(
          id: 'journey_${task.index}',
          label: [
            if (task.sectionIndex case final int sectionIndex)
              sections[sectionIndex].title,
            task.name,
            '${_scoreLabel(task.score)}/5',
            if (task.actors.isNotEmpty) task.actors.join(', '),
          ].join('\n'),
          shape: NodeShape.roundedRect,
        ),
    ];
    return (
      MermaidDiagramData(
        type: DiagramType.journey,
        nodes: nodes,
        edges: [
          for (var taskIndex = 1; taskIndex < tasks.length; taskIndex++)
            MermaidEdge(
              from: 'journey_${taskIndex - 1}',
              to: 'journey_$taskIndex',
            ),
        ],
        direction: DiagramDirection.leftToRight,
        title: title,
      ),
      JourneyChartData(
        sections: sections,
        tasks: tasks,
        actors: {...tasks.expand((task) => task.actors)}.toList()..sort(),
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  String _withoutComment(String value) {
    final percent = value.indexOf('%%');
    final hash = value.trimLeft().startsWith('#') ? value.indexOf('#') : -1;
    final offsets = [percent, hash].where((offset) => offset >= 0).toList()
      ..sort();
    return offsets.isEmpty ? value : value.substring(0, offsets.first);
  }

  String _scoreLabel(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}
