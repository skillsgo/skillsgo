/*
 * [INPUT]: Depends on Mermaid 11.16.0 Kanban relative-indentation grammar, node shapes, decorations, and JSON-schema YAML metadata.
 * [OUTPUT]: Strictly parses sections, tasks, generated IDs, Markdown labels, icons, classes, priorities, tickets, assignees, and accessibility extensions.
 * [POS]: Serves as the lossless native syntax adapter for Kanban boards.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:yaml/yaml.dart';

import '../models/diagram.dart';
import '../models/kanban.dart';

class KanbanParser {
  const KanbanParser();

  (MermaidDiagramData, KanbanChartData)? parse(List<String> lines) {
    if (lines.isEmpty || lines.first.trim().toLowerCase() != 'kanban') {
      return null;
    }
    final columns = <KanbanColumn>[];
    KanbanColumn? currentColumn;
    final tasks = <KanbanTask>[];
    int? sectionLevel;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var readingDescription = false;
    final descriptionLines = <String>[];
    KanbanTask? lastTask;
    var generatedId = 0;

    void saveColumn() {
      if (currentColumn != null) {
        columns.add(currentColumn.copyWith(tasks: List.of(tasks)));
        tasks.clear();
      }
    }

    for (var index = 1; index < lines.length; index++) {
      final raw = lines[index];
      final line = raw.trim();
      if (readingDescription) {
        if (line == '}') {
          readingDescription = false;
          accessibilityDescription = descriptionLines.join('\n').trim();
        } else {
          descriptionLines.add(line);
        }
        continue;
      }
      if (line.isEmpty || line.startsWith('%%')) continue;
      if (line.toLowerCase().startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (line.toLowerCase().startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
        readingDescription = true;
        descriptionLines.clear();
        continue;
      }
      if (line.toLowerCase().startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      final icon = RegExp(r'^::icon\((.+)\)$').firstMatch(line);
      if (icon != null) {
        final value = icon.group(1)!.trim();
        if (lastTask != null) {
          final decorated = lastTask.copyWith(icon: value);
          tasks[tasks.length - 1] = decorated;
          lastTask = decorated;
        } else if (currentColumn != null) {
          currentColumn = currentColumn.copyWith(icon: value);
        } else {
          return null;
        }
        continue;
      }
      if (line.startsWith(':::')) {
        if (line.length == 3) return null;
        final value = line.substring(3).trim();
        if (lastTask != null) {
          final decorated = lastTask.copyWith(cssClass: value);
          tasks[tasks.length - 1] = decorated;
          lastTask = decorated;
        } else if (currentColumn != null) {
          currentColumn = currentColumn.copyWith(cssClass: value);
        } else {
          return null;
        }
        continue;
      }

      var statement = line;
      while (statement.contains('@{') && !statement.contains('}')) {
        if (++index >= lines.length) return null;
        statement += '\n${lines[index].trim()}';
      }
      final metadataStart = statement.indexOf('@{');
      String? metadataSource;
      if (metadataStart >= 0) {
        if (!statement.trimRight().endsWith('}')) return null;
        metadataSource = statement.substring(metadataStart + 2).trim();
        metadataSource = metadataSource.substring(0, metadataSource.length - 1);
        statement = statement.substring(0, metadataStart).trimRight();
      }
      final node = _node(statement, generatedId++);
      if (node == null) return null;
      final metadata = _metadata(metadataSource);
      if (metadata == null) return null;
      final level = _indent(raw);
      sectionLevel ??= level;
      if (level < sectionLevel) return null;

      final label = (metadata['label'] ?? metadata['descr'])?.toString();
      final shapeName = metadata['shape']?.toString();
      if (shapeName != null &&
          (shapeName != shapeName.toLowerCase() || shapeName.contains('_'))) {
        return null;
      }
      if (shapeName != null && shapeName != 'kanbanitem') return null;
      if (level == sectionLevel) {
        saveColumn();
        currentColumn = KanbanColumn(
          id: node.$1,
          title: label ?? node.$2,
          tasks: const [],
          shape: node.$3,
          icon: metadata['icon']?.toString(),
        );
        lastTask = null;
        continue;
      }
      if (currentColumn == null) return null;
      final task = KanbanTask(
        id: node.$1,
        description: label ?? node.$2,
        assigned: metadata['assigned']?.toString(),
        ticket: metadata['ticket']?.toString(),
        priority: _priority(metadata['priority']?.toString()),
        icon: metadata['icon']?.toString(),
        shape: node.$3,
        metadata: metadata,
      );
      tasks.add(task);
      lastTask = task;
    }
    if (readingDescription) return null;
    saveColumn();
    if (columns.isEmpty) return null;
    final data = KanbanChartData(
      columns: columns,
      title: title,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
    );
    return (
      MermaidDiagramData(
        type: DiagramType.kanban,
        nodes: const [],
        edges: const [],
        title: title,
      ),
      data,
    );
  }

  (String, String, KanbanNodeShape)? _node(String source, int generated) {
    final patterns = <(RegExp, KanbanNodeShape)>[
      (RegExp(r'^(.*?)\{\{(.*)\}\}$'), KanbanNodeShape.hexagon),
      (RegExp(r'^(.*?)\(\((.*)\)\)$'), KanbanNodeShape.circle),
      (RegExp(r'^(.*?)\)\)(.*)\(\($'), KanbanNodeShape.bang),
      (RegExp(r'^(.*?)\)(.*)\($'), KanbanNodeShape.cloud),
      (RegExp(r'^(.*?)\((-?)(.*?)(-?)\)$'), KanbanNodeShape.rounded),
      (RegExp(r'^(.*?)\[(.*)\]$'), KanbanNodeShape.rectangle),
    ];
    for (final pattern in patterns) {
      final match = pattern.$1.firstMatch(source);
      if (match == null) continue;
      final id = match.group(1)!.trim();
      final rawLabel = pattern.$2 == KanbanNodeShape.rounded
          ? match.group(3)!
          : match.group(2)!;
      final shape =
          pattern.$2 == KanbanNodeShape.rounded &&
              (match.group(2) == '-' || match.group(4) == '-')
          ? KanbanNodeShape.cloud
          : pattern.$2;
      final label = _label(rawLabel);
      if (label.isEmpty) return null;
      return (id.isEmpty ? 'kbn$generated' : id, label, shape);
    }
    final value = _label(source.trim());
    return value.isEmpty ? null : (value, value, KanbanNodeShape.plain);
  }

  String _label(String source) {
    final value = source.trim();
    if (value.startsWith('"`') && value.endsWith('`"')) {
      return value.substring(2, value.length - 2).replaceAll(r'\n', '\n');
    }
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  Map<String, Object?>? _metadata(String? source) {
    if (source == null || source.trim().isEmpty) return const {};
    try {
      final decoded = loadYaml('{${source.replaceAll('\n', ',')}}');
      if (decoded is! Map) return null;
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): _value(entry.value),
      };
    } on YamlException {
      return null;
    }
  }

  Object? _value(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _value(entry.value),
      };
    }
    if (value is List) return value.map(_value).toList(growable: false);
    return value;
  }

  int _indent(String line) {
    var count = 0;
    for (final unit in line.codeUnits) {
      if (unit == 0x20) {
        count++;
      } else if (unit == 0x09) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  KanbanPriority _priority(String? value) => switch (value?.toLowerCase()) {
    'very high' => KanbanPriority.veryHigh,
    'high' => KanbanPriority.high,
    'low' => KanbanPriority.low,
    'very low' => KanbanPriority.veryLow,
    _ => KanbanPriority.normal,
  };
}
