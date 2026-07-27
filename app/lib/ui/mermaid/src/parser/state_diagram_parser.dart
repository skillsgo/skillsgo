/*
 * [INPUT]: Depends on Mermaid 11.16.0 stateDiagram syntax and native state plus shared graph models.
 * [OUTPUT]: Strictly parses aliases, descriptions, composite hierarchy, pseudostates, concurrency, notes, transitions, directions, and classes.
 * [POS]: Serves as the lossless native parser for stateDiagram and rejects unknown statements instead of dropping them.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/state_diagram.dart';

class NativeStateDiagramParser {
  const NativeStateDiagramParser();

  (MermaidDiagramData, StateDiagramData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (header < 0 ||
        !RegExp(
          r'^stateDiagram(?:-v2)?$',
          caseSensitive: false,
        ).hasMatch(lines[header].trim())) {
      return null;
    }
    final states = <String, StateNodeData>{};
    final transitions = <StateTransitionData>[];
    final notes = <StateNoteData>[];
    final regions = <StateRegionData>[];
    final classDefinitions = <String, String>{};
    final compositeStack = <String>[];
    var direction = DiagramDirection.topToBottom;
    String? noteState;
    StateNotePosition? notePosition;
    final noteLines = <String>[];
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;

    void ensure(
      String raw, {
      String? label,
      StateNodeKind? kind,
      List<String>? classes,
    }) {
      final parsed = _styledId(raw);
      final id = parsed.$1;
      final applied = [...parsed.$2, ...?classes];
      states.update(
        id,
        (value) => value.copyWith(
          label: label,
          kind: kind,
          cssClasses: applied.isEmpty
              ? null
              : {...value.cssClasses, ...applied}.toList(),
        ),
        ifAbsent: () => StateNodeData(
          id: id,
          label: label ?? id,
          kind: kind ?? StateNodeKind.simple,
          parent: compositeStack.isEmpty ? null : compositeStack.last,
          cssClasses: applied,
        ),
      );
    }

    for (final raw in lines.skip(header + 1)) {
      final line = raw.trim().replaceFirst(RegExp(r';\s*$'), '');
      if (line.isEmpty || line == '---') continue;
      if (noteState != null) {
        if (line.toLowerCase() == 'end note') {
          notes.add(
            StateNoteData(
              stateId: noteState,
              position: notePosition!,
              text: noteLines.join('\n'),
            ),
          );
          noteState = null;
          notePosition = null;
          noteLines.clear();
        } else {
          noteLines.add(line);
        }
        continue;
      }
      if (line == '}') {
        if (compositeStack.isEmpty) return null;
        compositeStack.removeLast();
        continue;
      }
      if (line == '--') {
        if (compositeStack.isEmpty) return null;
        regions.add(
          StateRegionData(
            parent: compositeStack.last,
            index:
                regions
                    .where((item) => item.parent == compositeStack.last)
                    .length +
                1,
          ),
        );
        continue;
      }
      if (line.startsWith('direction ')) {
        final parsed = _direction(line.substring(10));
        if (compositeStack.isEmpty) {
          direction = parsed;
        } else {
          states[compositeStack.last] = states[compositeStack.last]!.copyWith(
            direction: parsed,
          );
        }
        continue;
      }
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
      final alias = RegExp(
        r'^state\s+"([^"]+)"\s+as\s+([^\s]+)$',
      ).firstMatch(line);
      if (alias != null) {
        ensure(alias.group(2)!, label: alias.group(1)!);
        continue;
      }
      final special = RegExp(
        r'^state\s+([^\s{]+)\s+<<(choice|fork|join)>>$',
      ).firstMatch(line);
      if (special != null) {
        ensure(
          special.group(1)!,
          kind: StateNodeKind.values.byName(special.group(2)!),
        );
        continue;
      }
      final composite = RegExp(r'^state\s+([^\s{]+)\s*\{$').firstMatch(line);
      if (composite != null) {
        final id = _styledId(composite.group(1)!).$1;
        ensure(id, kind: StateNodeKind.composite);
        compositeStack.add(id);
        continue;
      }
      final standalone = RegExp(r'^state\s+([^\s]+)$').firstMatch(line);
      if (standalone != null) {
        ensure(standalone.group(1)!);
        continue;
      }
      final note = RegExp(
        r'^note\s+(left|right)\s+of\s+([^\s:]+)(?:\s*:\s*(.+))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (note != null) {
        final id = _styledId(note.group(2)!).$1;
        ensure(id);
        final position = note.group(1)!.toLowerCase() == 'left'
            ? StateNotePosition.left
            : StateNotePosition.right;
        if (note.group(3) != null) {
          notes.add(
            StateNoteData(
              stateId: id,
              position: position,
              text: note.group(3)!.trim(),
            ),
          );
        } else {
          noteState = id;
          notePosition = position;
        }
        continue;
      }
      final classDef = RegExp(r'^classDef\s+([^\s]+)\s+(.+)$').firstMatch(line);
      if (classDef != null) {
        classDefinitions[classDef.group(1)!] = classDef.group(2)!;
        continue;
      }
      final classLine = RegExp(r'^class\s+([^\s]+)\s+(.+)$').firstMatch(line);
      if (classLine != null) {
        final names = classLine.group(1)!.split(',');
        final classes = classLine
            .group(2)!
            .split(',')
            .map((value) => value.trim())
            .toList();
        for (final name in names) {
          ensure(name.trim(), classes: classes);
        }
        continue;
      }
      final transition = RegExp(
        r'^(\[\*\]|(?:[^\s:]|:::)+)\s*-->\s*(\[\*\]|(?:[^\s:]|:::)+)(?:\s*:\s*(.+))?$',
      ).firstMatch(line);
      if (transition != null) {
        final from = _styledId(transition.group(1)!);
        final to = _styledId(transition.group(2)!);
        if (from.$1 != '[*]') ensure(from.$1, classes: from.$2);
        if (to.$1 != '[*]') ensure(to.$1, classes: to.$2);
        transitions.add(
          StateTransitionData(
            from: from.$1,
            to: to.$1,
            label: transition.group(3)?.trim(),
            fromClasses: from.$2,
            toClasses: to.$2,
          ),
        );
        continue;
      }
      final description = RegExp(r'^([^\s:]+)\s*:\s*(.+)$').firstMatch(line);
      if (description != null) {
        ensure(description.group(1)!, label: description.group(2)!.trim());
        continue;
      }
      if (RegExp(r'^[\w.-]+$').hasMatch(line)) {
        ensure(line);
        continue;
      }
      return null;
    }
    if (noteState != null ||
        compositeStack.isNotEmpty ||
        states.isEmpty && transitions.isEmpty) {
      return null;
    }
    final nodes = states.values
        .map(
          (state) => MermaidNode(
            id: state.id,
            label: [
              state.label,
              ...notes
                  .where((note) => note.stateId == state.id)
                  .map((note) => '📝 ${note.text}'),
            ].join('\n'),
            shape: switch (state.kind) {
              StateNodeKind.choice => NodeShape.diamond,
              StateNodeKind.fork || StateNodeKind.join => NodeShape.stadium,
              _ => NodeShape.roundedRect,
            },
            className: state.cssClasses.isEmpty
                ? null
                : state.cssClasses.join(' '),
            style: _resolvedStyle(state.cssClasses, classDefinitions),
          ),
        )
        .toList();
    final edges = <MermaidEdge>[];
    var boundary = 0;
    for (final transition in transitions) {
      var from = transition.from;
      var to = transition.to;
      if (from == '[*]') {
        from = '__state_start_${boundary++}';
        nodes.add(MermaidNode(id: from, label: '', shape: NodeShape.circle));
      }
      if (to == '[*]') {
        to = '__state_end_${boundary++}';
        nodes.add(
          MermaidNode(id: to, label: '', shape: NodeShape.doubleCircle),
        );
      }
      edges.add(MermaidEdge(from: from, to: to, label: transition.label));
    }
    final subgraphs = states.values
        .where((state) => state.kind == StateNodeKind.composite)
        .map(
          (state) => Subgraph(
            id: state.id,
            label: state.label,
            nodeIds: states.values
                .where((child) => child.parent == state.id)
                .map((child) => child.id)
                .toList(),
          ),
        )
        .toList();
    return (
      MermaidDiagramData(
        type: DiagramType.stateDiagram,
        nodes: nodes,
        edges: edges,
        subgraphs: subgraphs,
        direction: direction,
        title: title,
      ),
      StateDiagramData(
        states: states.values.toList(),
        transitions: transitions,
        notes: notes,
        regions: regions,
        classDefinitions: classDefinitions,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  (String, List<String>) _styledId(String value) {
    final parts = value.trim().split(':::');
    return (
      parts.first,
      parts
          .skip(1)
          .expand((item) => item.split(','))
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  DiagramDirection _direction(String value) =>
      switch (value.trim().toUpperCase()) {
        'BT' => DiagramDirection.bottomToTop,
        'LR' => DiagramDirection.leftToRight,
        'RL' => DiagramDirection.rightToLeft,
        _ => DiagramDirection.topToBottom,
      };
  NodeStyle? _resolvedStyle(
    List<String> classes,
    Map<String, String> definitions,
  ) {
    final declarations = [
      if (definitions['default'] case final String value) value,
      for (final name in classes)
        if (definitions[name] case final String value) value,
    ];
    if (declarations.isEmpty) return null;
    final values = <String, String>{};
    for (final source in declarations) {
      for (final part in source.split(',')) {
        final separator = part.indexOf(':');
        if (separator > 0) {
          values[part.substring(0, separator).trim()] = part
              .substring(separator + 1)
              .trim();
        }
      }
    }
    return NodeStyle(
      fillColor: _color(values['fill']),
      strokeColor: _color(values['stroke']),
      textColor: _color(values['color']),
      strokeWidth:
          double.tryParse(
            values['stroke-width']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
          ) ??
          1,
    );
  }

  int? _color(String? value) {
    if (value == null || !value.startsWith('#')) {
      return value?.toLowerCase() == 'white'
          ? 0xFFFFFFFF
          : value?.toLowerCase() == 'red'
          ? 0xFFFF0000
          : null;
    }
    final hex = value.substring(1);
    final expanded = hex.length == 3
        ? hex.split('').map((item) => '$item$item').join()
        : hex;
    final parsed = int.tryParse(expanded, radix: 16);
    return parsed == null ? null : 0xFF000000 | parsed;
  }
}
