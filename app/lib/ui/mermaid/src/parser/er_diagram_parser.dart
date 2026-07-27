/*
 * [INPUT]: Depends on Mermaid 11.16.0 ER syntax and native ER plus shared graph models.
 * [OUTPUT]: Strictly parses entity aliases, optional/array types, attributes, keys/comments, cardinalities, identity, direction, and styles.
 * [POS]: Serves as the lossless native parser for erDiagram and rejects unknown statements instead of dropping them.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/er_diagram.dart';
import '../models/node.dart';

class NativeErDiagramParser {
  const NativeErDiagramParser();

  (MermaidDiagramData, ErDiagramData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (header < 0 || lines[header].trim().toLowerCase() != 'erdiagram') {
      return null;
    }
    final entities = <String, ErEntityData>{};
    final relationships = <ErRelationshipData>[];
    final classDefinitions = <String, String>{};
    var direction = DiagramDirection.topToBottom;
    String? openEntity;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;

    void ensure(String raw, {String? label, List<String>? classes}) {
      final parsed = _styledEntity(raw);
      final id = parsed.$1;
      final applied = [...parsed.$2, ...?classes];
      entities.update(
        id,
        (value) => value.copyWith(
          label: label,
          cssClasses: applied.isEmpty
              ? null
              : {...value.cssClasses, ...applied}.toList(),
        ),
        ifAbsent: () => ErEntityData(
          id: id,
          label: label ?? id,
          attributes: const [],
          cssClasses: applied,
        ),
      );
    }

    for (final raw in lines.skip(header + 1)) {
      final line = raw.trim().replaceFirst(RegExp(r';\s*$'), '');
      if (line.isEmpty || line == '---') continue;
      if (openEntity != null) {
        if (line == '}') {
          openEntity = null;
          continue;
        }
        final attribute = _attribute(line);
        if (attribute == null) return null;
        final value = entities[openEntity]!;
        entities[openEntity] = value.copyWith(
          attributes: [...value.attributes, attribute],
        );
        continue;
      }
      if (line.startsWith('direction ')) {
        direction = _direction(line.substring(10));
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
      final declaration = RegExp(
        r'^("[^"]+"|[^\s\[{:]+)(?:\["([^"]+)"\]|\[([^\]]+)\])?(?:\s*:::\s*([\w,-]+))?\s*\{$',
      ).firstMatch(line);
      if (declaration != null) {
        final id = _entityId(declaration.group(1)!);
        ensure(
          id,
          label: declaration.group(2) ?? declaration.group(3),
          classes: declaration.group(4)?.split(','),
        );
        openEntity = id;
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
        for (final rawId in style.group(1)!.split(',')) {
          final id = _entityId(rawId);
          ensure(id);
          entities[id] = entities[id]!.copyWith(rawStyle: style.group(2)!);
        }
        continue;
      }
      final symbolic = RegExp(
        r'^("[^"]+"|[^\s]+?)\s*([^\s]*?(?:--|\.\.)[^\s]*?)\s*("[^"]+"|[^\s:]+)\s*:\s*(.+)$',
      ).firstMatch(line);
      if (symbolic != null) {
        final from = _styledEntity(symbolic.group(1)!);
        final to = _styledEntity(symbolic.group(3)!);
        ensure(from.$1, classes: from.$2);
        ensure(to.$1, classes: to.$2);
        final marker = symbolic.group(2)!;
        final split = RegExp(r'(--|\.\.)').firstMatch(marker)!;
        relationships.add(
          ErRelationshipData(
            from: from.$1,
            to: to.$1,
            fromCardinality: _cardinality(marker.substring(0, split.start)),
            toCardinality: _cardinality(marker.substring(split.end)),
            identifying: split.group(1) == '--',
            label: _unquote(symbolic.group(4)!.trim()),
            rawMarker: marker,
          ),
        );
        continue;
      }
      final natural = RegExp(
        r'^("[^"]+"|[^\s]+)\s+(.+?)\s+(to|optionally\s+to)\s+(.+?)\s+("[^"]+"|[^\s:]+)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (natural != null) {
        final from = _styledEntity(natural.group(1)!);
        final to = _styledEntity(natural.group(5)!);
        ensure(from.$1, classes: from.$2);
        ensure(to.$1, classes: to.$2);
        relationships.add(
          ErRelationshipData(
            from: from.$1,
            to: to.$1,
            fromCardinality: _naturalCardinality(natural.group(2)!),
            toCardinality: _naturalCardinality(natural.group(4)!),
            identifying: natural.group(3)!.toLowerCase() == 'to',
            label: _unquote(natural.group(6)!.trim()),
            rawMarker:
                '${natural.group(2)} ${natural.group(3)} ${natural.group(4)}',
          ),
        );
        continue;
      }
      final standalone = RegExp(
        r'^("[^"]+"|[^\s{:]+)(?:\s*:::\s*([\w,-]+))?$',
      ).firstMatch(line);
      if (standalone != null) {
        ensure(standalone.group(1)!, classes: standalone.group(2)?.split(','));
        continue;
      }
      return null;
    }
    if (openEntity != null || entities.isEmpty) return null;
    final nodes = entities.values
        .map(
          (entity) => MermaidNode(
            id: entity.id,
            label: [
              entity.label,
              ...entity.attributes.map(
                (attribute) =>
                    '${attribute.type} ${attribute.name}${attribute.keys.isEmpty ? '' : ' ${attribute.keys.map((key) => key.name.toUpperCase()).join(', ')}'}${attribute.comment == null ? '' : ' — ${attribute.comment}'}',
              ),
            ].join('\n'),
            className: entity.cssClasses.isEmpty
                ? null
                : entity.cssClasses.join(' '),
            style: _resolvedStyle(entity, classDefinitions),
          ),
        )
        .toList();
    final edges = relationships
        .map(
          (relation) => MermaidEdge(
            from: relation.from,
            to: relation.to,
            label:
                '${_cardinalityLabel(relation.fromCardinality)} · ${relation.label} · ${_cardinalityLabel(relation.toCardinality)}',
            arrowType: ArrowType.none,
            lineType: relation.identifying ? LineType.solid : LineType.dotted,
          ),
        )
        .toList();
    return (
      MermaidDiagramData(
        type: DiagramType.erDiagram,
        nodes: nodes,
        edges: edges,
        direction: direction,
        title: title,
      ),
      ErDiagramData(
        entities: entities.values.toList(),
        relationships: relationships,
        classDefinitions: classDefinitions,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
        layoutDirection: switch (direction) {
          DiagramDirection.topToBottom => 'TB',
          DiagramDirection.bottomToTop => 'BT',
          DiagramDirection.leftToRight => 'LR',
          DiagramDirection.rightToLeft => 'RL',
        },
      ),
    );
  }

  ErAttributeData? _attribute(String line) {
    final match = RegExp(
      r'^([A-Za-z][\w?\-\[\]()]*)\s+(\*?[\w\-]+)(?:\s+((?:(?:PK|FK|UK)\s*,?\s*)+))?(?:\s+"([^"]*)")?$',
    ).firstMatch(line);
    if (match == null) return null;
    final keys = <ErAttributeKey>[];
    for (final token in (match.group(3) ?? '').split(RegExp(r'\s*,\s*|\s+'))) {
      switch (token) {
        case 'PK':
          keys.add(ErAttributeKey.primary);
        case 'FK':
          keys.add(ErAttributeKey.foreign);
        case 'UK':
          keys.add(ErAttributeKey.unique);
      }
    }
    return ErAttributeData(
      type: match.group(1)!,
      name: match.group(2)!,
      keys: keys,
      comment: match.group(4),
    );
  }

  (String, List<String>) _styledEntity(String value) {
    final parts = value.trim().split(':::');
    return (
      _entityId(parts.first),
      parts
          .skip(1)
          .expand((item) => item.split(','))
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  String _entityId(String value) => _unquote(value.trim());
  String _unquote(String value) =>
      value.length >= 2 && value.startsWith('"') && value.endsWith('"')
      ? value.substring(1, value.length - 1)
      : value;
  ErCardinality _cardinality(String marker) {
    final value = marker.trim();
    if (value.contains('o') && (value.contains('{') || value.contains('}'))) {
      return ErCardinality.zeroOrMore;
    }
    if (value.contains('|') && (value.contains('{') || value.contains('}'))) {
      return ErCardinality.oneOrMore;
    }
    if (value.contains('o')) return ErCardinality.zeroOrOne;
    if (value.contains('|')) return ErCardinality.exactlyOne;
    return ErCardinality.unknown;
  }

  ErCardinality _naturalCardinality(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.contains('zero or more') ||
        normalized == '0+' ||
        normalized.contains('many(0)')) {
      return ErCardinality.zeroOrMore;
    }
    if (normalized.contains('one or more') ||
        normalized == '1+' ||
        normalized.contains('many(1)')) {
      return ErCardinality.oneOrMore;
    }
    if (normalized.contains('zero or one') || normalized == '0 or 1') {
      return ErCardinality.zeroOrOne;
    }
    if (normalized.contains('only one') || normalized == '1') {
      return ErCardinality.exactlyOne;
    }
    return ErCardinality.unknown;
  }

  String _cardinalityLabel(ErCardinality value) => switch (value) {
    ErCardinality.zeroOrOne => '0..1',
    ErCardinality.exactlyOne => '1',
    ErCardinality.zeroOrMore => '0..*',
    ErCardinality.oneOrMore => '1..*',
    ErCardinality.unknown => '?',
  };
  DiagramDirection _direction(String value) =>
      switch (value.trim().toUpperCase()) {
        'BT' => DiagramDirection.bottomToTop,
        'LR' => DiagramDirection.leftToRight,
        'RL' => DiagramDirection.rightToLeft,
        _ => DiagramDirection.topToBottom,
      };
  NodeStyle? _resolvedStyle(
    ErEntityData entity,
    Map<String, String> definitions,
  ) {
    final sources = [
      if (definitions['default'] case final String value) value,
      for (final name in entity.cssClasses)
        if (definitions[name] case final String value) value,
      if (entity.rawStyle case final String value) value,
    ];
    if (sources.isEmpty) return null;
    final values = <String, String>{};
    for (final source in sources) {
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
    if (value == null || !value.startsWith('#')) return null;
    final hex = value.substring(1);
    final expanded = hex.length == 3
        ? hex.split('').map((item) => '$item$item').join()
        : hex;
    final parsed = int.tryParse(expanded, radix: 16);
    return parsed == null ? null : 0xFF000000 | parsed;
  }
}
