/*
 * [INPUT]: Depends on Mermaid 11.16.0 classDiagram syntax and native class plus shared graph models.
 * [OUTPUT]: Strictly parses classes, members, generics, annotations, namespaces, UML relations/cardinalities, notes, styles, and interactions.
 * [POS]: Serves as the lossless native parser for classDiagram and rejects unknown statements instead of dropping them.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/class_diagram.dart';
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';

class NativeClassDiagramParser {
  const NativeClassDiagramParser();

  (MermaidDiagramData, ClassDiagramData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) {
      final value = line.trim().toLowerCase();
      return value == 'classdiagram' || value == 'classdiagram-v2';
    });
    if (header < 0) return null;
    final classes = <String, ClassEntityData>{};
    final namespaces = <String, ClassNamespaceData>{};
    final relations = <ClassRelationData>[];
    final notes = <ClassNoteData>[];
    final classDefinitions = <String, String>{};
    final namespaceStack = <String>[];
    String? openClass;
    var direction = DiagramDirection.topToBottom;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;

    void ensure(
      String raw, {
      String? label,
      String? generic,
      String? cssClass,
    }) {
      final id = _id(raw);
      classes.update(
        id,
        (value) => value.copyWith(
          label: label,
          genericType: generic,
          namespace: namespaceStack.isEmpty ? null : namespaceStack.last,
          cssClass: cssClass,
        ),
        ifAbsent: () => ClassEntityData(
          id: id,
          label: label ?? id,
          genericType: generic,
          namespace: namespaceStack.isEmpty ? null : namespaceStack.last,
          members: const [],
          annotations: const [],
          cssClass: cssClass,
        ),
      );
    }

    for (final raw in lines.skip(header + 1)) {
      final line = raw.trim().replaceFirst(RegExp(r';\s*$'), '');
      if (line.isEmpty || line == '---') continue;
      if (openClass != null) {
        if (line == '}') {
          openClass = null;
          continue;
        }
        final annotation = RegExp(r'^<<(.+)>>$').firstMatch(line);
        if (annotation != null) {
          final value = classes[openClass]!;
          classes[openClass] = value.copyWith(
            annotations: [...value.annotations, annotation.group(1)!.trim()],
          );
          continue;
        }
        final value = classes[openClass]!;
        classes[openClass] = value.copyWith(
          members: [...value.members, _member(line)],
        );
        continue;
      }
      if (line == '}') {
        if (namespaceStack.isEmpty) return null;
        namespaceStack.removeLast();
        continue;
      }
      if (line.startsWith('direction ')) {
        direction = _direction(line.substring(10));
        continue;
      }
      if (line.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('accTitle:')) {
        accessibilityTitle = line.substring('accTitle:'.length).trim();
        continue;
      }
      if (line.startsWith('accDescr:')) {
        accessibilityDescription = line.substring('accDescr:'.length).trim();
        continue;
      }
      final namespace = RegExp(
        r'^namespace\s+([^\s\[]+)(?:\["([^"]+)"\])?\s*\{$',
      ).firstMatch(line);
      if (namespace != null) {
        final rawId = _id(namespace.group(1)!);
        final parent = namespaceStack.isEmpty ? null : namespaceStack.last;
        final id = parent == null || rawId.contains('.')
            ? rawId
            : '$parent.$rawId';
        final segments = id.split('.');
        for (var index = 0; index < segments.length; index++) {
          final path = segments.take(index + 1).join('.');
          namespaces.putIfAbsent(
            path,
            () => ClassNamespaceData(
              id: path,
              label: path == id
                  ? namespace.group(2) ?? segments[index]
                  : segments[index],
              parent: index == 0 ? null : segments.take(index).join('.'),
            ),
          );
        }
        namespaceStack.add(id);
        continue;
      }
      final declaration = RegExp(
        r'^class\s+(`[^`]+`|[^\s\[{:]+)(?:\["([^"]+)"\])?(?:\s+<<([^>]+)>>)?(?:\s*:::\s*([\w,-]+))?\s*(\{)?$',
      ).firstMatch(line);
      if (declaration != null) {
        final rawName = declaration.group(1)!;
        final generic = RegExp(r'~(.*)~').firstMatch(rawName)?.group(1);
        final id = _id(rawName);
        ensure(
          id,
          label: declaration.group(2),
          generic: generic,
          cssClass: declaration.group(4),
        );
        if (declaration.group(3) != null) {
          final value = classes[id]!;
          classes[id] = value.copyWith(
            annotations: [...value.annotations, declaration.group(3)!.trim()],
          );
        }
        if (declaration.group(5) != null) openClass = id;
        continue;
      }
      final separateAnnotation = RegExp(
        r'^<<([^>]+)>>\s+(.+)$',
      ).firstMatch(line);
      if (separateAnnotation != null) {
        final id = _id(separateAnnotation.group(2)!);
        ensure(id);
        final value = classes[id]!;
        classes[id] = value.copyWith(
          annotations: [
            ...value.annotations,
            separateAnnotation.group(1)!.trim(),
          ],
        );
        continue;
      }
      final inlineMember = RegExp(
        r'^(`[^`]+`|[\w.~-]+)\s*:\s*(.+)$',
      ).firstMatch(line);
      if (inlineMember != null && !_looksLikeRelation(line)) {
        final id = _id(inlineMember.group(1)!);
        ensure(id);
        final value = classes[id]!;
        classes[id] = value.copyWith(
          members: [...value.members, _member(inlineMember.group(2)!.trim())],
        );
        continue;
      }
      final note = RegExp(
        r'^note(?:\s+for\s+([^\s]+))?\s+"((?:[^"\\]|\\.)*)"$',
        caseSensitive: false,
      ).firstMatch(line);
      if (note != null) {
        final classId = note.group(1) == null ? null : _id(note.group(1)!);
        if (classId != null) ensure(classId);
        notes.add(ClassNoteData(text: note.group(2)!, classId: classId));
        continue;
      }
      final classDef = RegExp(r'^classDef\s+([^\s]+)\s+(.+)$').firstMatch(line);
      if (classDef != null) {
        for (final name in classDef.group(1)!.split(',')) {
          classDefinitions[name] = classDef.group(2)!;
        }
        continue;
      }
      final style = RegExp(r'^style\s+([^\s]+)\s+(.+)$').firstMatch(line);
      if (style != null) {
        final id = _id(style.group(1)!);
        ensure(id);
        classes[id] = classes[id]!.copyWith(rawStyle: style.group(2)!);
        continue;
      }
      final css = RegExp(
        r'^cssClass\s+"?([^"\s]+)"?\s+([^\s]+)$',
      ).firstMatch(line);
      if (css != null) {
        for (final rawId in css.group(1)!.split(',')) {
          final id = _id(rawId);
          ensure(id);
          classes[id] = classes[id]!.copyWith(cssClass: css.group(2)!);
        }
        continue;
      }
      final interaction =
          RegExp(
            r'^(link|callback)\s+([^\s]+)\s+"([^"]+)"(?:\s+"([^"]*)")?$',
          ).firstMatch(line) ??
          RegExp(
            r'^click\s+([^\s]+)\s+(?:href\s+"([^"]+)"|call\s+([^\s(]+)\([^)]*\))(?:\s+"([^"]*)")?$',
          ).firstMatch(line);
      if (interaction != null) {
        _applyInteraction(
          classes,
          ensure,
          interaction,
          line.startsWith('click '),
        );
        continue;
      }
      final relation = _relation(line);
      if (relation != null) {
        ensure(relation.from);
        ensure(relation.to);
        relations.add(relation);
        continue;
      }
      return null;
    }
    if (openClass != null || namespaceStack.isNotEmpty || classes.isEmpty) {
      return null;
    }
    final nodes = classes.values
        .map(
          (item) => MermaidNode(
            id: item.id,
            label: [
              if (item.annotations.isNotEmpty)
                item.annotations.map((value) => '«$value»').join(' '),
              '${item.label}${item.genericType == null ? '' : '<${item.genericType}>'}',
              ...item.members.map((member) => member.text),
              ...notes
                  .where((note) => note.classId == item.id)
                  .map((note) => '📝 ${note.text}'),
            ].join('\n'),
            style: _resolvedStyle(item, classDefinitions),
            className: item.cssClass,
            link: item.link,
            tooltip: item.tooltip,
          ),
        )
        .toList();
    for (var index = 0; index < notes.length; index++) {
      final note = notes[index];
      if (note.classId == null) {
        nodes.add(
          MermaidNode(
            id: '__class_note_$index',
            label: note.text,
            shape: NodeShape.roundedRect,
            style: const NodeStyle(
              fillColor: 0xFFFFF7C7,
              strokeColor: 0xFFB49A37,
              textColor: 0xFF4E430F,
            ),
          ),
        );
      }
    }
    final edges = relations
        .map(
          (item) => MermaidEdge(
            from: item.from,
            to: item.to,
            label: [
              if (item.leftCardinality != null) item.leftCardinality!,
              if (item.label != null) item.label!,
              if (item.rightCardinality != null) item.rightCardinality!,
            ].join(' · '),
            arrowType:
                item.leftEnd == ClassRelationEnd.none &&
                    item.rightEnd == ClassRelationEnd.none
                ? ArrowType.none
                : ArrowType.arrow,
            lineType: item.dashed ? LineType.dotted : LineType.solid,
            bidirectional:
                item.leftEnd != ClassRelationEnd.none &&
                item.rightEnd != ClassRelationEnd.none,
          ),
        )
        .toList();
    final subgraphs = namespaces.values
        .map(
          (namespace) => Subgraph(
            id: namespace.id,
            label: namespace.label,
            nodeIds: classes.values
                .where((item) => item.namespace == namespace.id)
                .map((item) => item.id)
                .toList(),
          ),
        )
        .toList();
    return (
      MermaidDiagramData(
        type: DiagramType.classDiagram,
        nodes: nodes,
        edges: edges,
        subgraphs: subgraphs,
        direction: direction,
        title: title,
      ),
      ClassDiagramData(
        classes: classes.values.toList(),
        namespaces: namespaces.values.toList(),
        relations: relations,
        notes: notes,
        classDefinitions: classDefinitions,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  ClassMemberData _member(String text) {
    final first = text.isEmpty ? '' : text[0];
    final visibility = switch (first) {
      '+' => ClassMemberVisibility.public,
      '-' => ClassMemberVisibility.private,
      '#' => ClassMemberVisibility.protected,
      '~' => ClassMemberVisibility.package,
      _ => ClassMemberVisibility.unspecified,
    };
    return ClassMemberData(
      text: text,
      kind: text.contains('(')
          ? ClassMemberKind.method
          : ClassMemberKind.attribute,
      visibility: visibility,
      isStatic: text.endsWith(r'$'),
      isAbstract: text.endsWith('*'),
    );
  }

  bool _looksLikeRelation(String line) => RegExp(r'(?:--|\.\.)').hasMatch(line);
  ClassRelationData? _relation(String line) {
    final match = RegExp(
      r'^(`[^`]+`|[^\s"]+)(?:\s+"([^"]+)")?\s+(\S*(?:--|\.\.)\S*)\s+(?:"([^"]+)"\s+)?(`[^`]+`|[^\s:]+)(?:\s*:\s*(.+))?$',
    ).firstMatch(line);
    if (match == null) return null;
    final token = match.group(3)!;
    final split = RegExp(r'(--|\.\.)').firstMatch(token);
    if (split == null) return null;
    final dashed = split.group(1) == '..';
    return ClassRelationData(
      from: _id(match.group(1)!),
      to: _id(match.group(5)!),
      leftEnd: _end(token.substring(0, split.start), dashed: dashed),
      rightEnd: _end(token.substring(split.end), dashed: dashed),
      dashed: dashed,
      leftCardinality: match.group(2),
      rightCardinality: match.group(4),
      label: match.group(6)?.trim(),
    );
  }

  ClassRelationEnd _end(String value, {required bool dashed}) {
    if (value.contains('<|') || value.contains('|>')) {
      return dashed
          ? ClassRelationEnd.realization
          : ClassRelationEnd.inheritance;
    }
    if (value.contains('*')) return ClassRelationEnd.composition;
    if (value.contains('o')) return ClassRelationEnd.aggregation;
    if (value.contains('()')) return ClassRelationEnd.lollipop;
    if (value.contains('<') || value.contains('>')) {
      return ClassRelationEnd.association;
    }
    return ClassRelationEnd.none;
  }

  void _applyInteraction(
    Map<String, ClassEntityData> classes,
    void Function(String, {String? label, String? generic, String? cssClass})
    ensure,
    RegExpMatch match,
    bool click,
  ) {
    late final String id;
    String? link;
    String? callback;
    String? tooltip;
    if (click) {
      id = _id(match.group(1)!);
      link = match.group(2);
      callback = match.group(3);
      tooltip = match.group(4);
    } else {
      id = _id(match.group(2)!);
      if (match.group(1) == 'link') {
        link = match.group(3);
      } else {
        callback = match.group(3);
      }
      tooltip = match.group(4);
    }
    ensure(id);
    classes[id] = classes[id]!.copyWith(
      link: link,
      callback: callback,
      tooltip: tooltip,
    );
  }

  String _id(String value) {
    var result = value.trim();
    if (result.startsWith('`') && result.endsWith('`')) {
      result = result.substring(1, result.length - 1);
    }
    return result.replaceAll(RegExp(r'~.*~'), '');
  }

  DiagramDirection _direction(String value) =>
      switch (value.trim().toUpperCase()) {
        'BT' => DiagramDirection.bottomToTop,
        'LR' => DiagramDirection.leftToRight,
        'RL' => DiagramDirection.rightToLeft,
        _ => DiagramDirection.topToBottom,
      };

  NodeStyle? _resolvedStyle(
    ClassEntityData item,
    Map<String, String> definitions,
  ) {
    final sources = <String>[
      if (definitions['default'] case final String value) value,
      for (final name in item.cssClass?.split(',') ?? const <String>[])
        if (definitions[name] case final String value) value,
      if (item.rawStyle case final String value) value,
    ];
    if (sources.isEmpty) return null;
    final values = <String, String>{};
    for (final source in sources) {
      for (final declaration in source.split(',')) {
        final separator = declaration.indexOf(':');
        if (separator > 0) {
          values[declaration.substring(0, separator).trim().toLowerCase()] =
              declaration.substring(separator + 1).trim();
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
      fontSize:
          double.tryParse(
            values['font-size']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
          ) ??
          14,
    );
  }

  int? _color(String? value) {
    if (value == null || !value.startsWith('#')) return null;
    final hex = value.substring(1);
    final expanded = hex.length == 3
        ? hex.split('').map((digit) => '$digit$digit').join()
        : hex;
    if (expanded.length != 6) return null;
    final rgb = int.tryParse(expanded, radix: 16);
    return rgb == null ? null : 0xFF000000 | rgb;
  }
}
