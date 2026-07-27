/*
 * [INPUT]: Depends on Mermaid 11.16.0 sequenceDiagram syntax and native sequence, node, edge, and diagram models.
 * [OUTPUT]: Parses participants with strict or relaxed attributes, properties, details, links, messages, numbering, notes, lifecycle, activations, backgrounds, and nested fragments without silently dropping unknown statements.
 * [POS]: Serves as the dedicated lossless native parser for sequence diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/sequence.dart';

class SequenceParser {
  const SequenceParser();

  MermaidDiagramData? parse(List<String> lines) => parseWithData(lines)?.$1;

  (MermaidDiagramData, SequenceChartData)? parseWithData(List<String> lines) {
    final statements = lines.expand(_splitStatements).toList(growable: false);
    if (statements.isEmpty ||
        statements.first.trim().toLowerCase() != 'sequencediagram') {
      return null;
    }
    final participants = <String, SequenceParticipantData>{};
    final edges = <SequenceMessage>[];
    final events = <SequenceEventData>[];
    final fragmentStack = <SequenceFragmentKind>[];
    final boxes = <SequenceBoxData>[];
    final activationDepth = <String, int>{};
    int? activeBoxId;
    var autoNumber = false;
    num autoNumberStart = 1;
    num autoNumberStep = 1;
    num nextNumber = 1;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var readingAccessibilityDescription = false;
    final accessibilityDescriptionLines = <String>[];

    void ensure(String id, {String? label, SequenceParticipantKind? kind}) {
      participants.update(
        id,
        (value) => value.copyWith(label: label, kind: kind, boxId: activeBoxId),
        ifAbsent: () => SequenceParticipantData(
          id: id,
          label: label ?? id,
          kind: kind ?? SequenceParticipantKind.participant,
          boxId: activeBoxId,
        ),
      );
    }

    for (final raw in statements.skip(1)) {
      final line = raw.trim().replaceFirst(RegExp(r';\s*$'), '');
      if (readingAccessibilityDescription) {
        final close = line.indexOf('}');
        if (close >= 0) {
          accessibilityDescriptionLines.add(line.substring(0, close).trim());
          accessibilityDescription = accessibilityDescriptionLines
              .where((value) => value.isNotEmpty)
              .join('\n');
          readingAccessibilityDescription = false;
        } else {
          accessibilityDescriptionLines.add(line);
        }
        continue;
      }
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();
      if (lower.startsWith('title ') || lower.startsWith('title:')) {
        title = line.substring(line.indexOf(RegExp(r'[:\s]')) + 1).trim();
        continue;
      }
      if (lower.startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (RegExp(r'^accdescr\s*\{', caseSensitive: false).hasMatch(line)) {
        final open = line.indexOf('{');
        final remainder = line.substring(open + 1);
        final close = remainder.indexOf('}');
        if (close >= 0) {
          accessibilityDescription = remainder.substring(0, close).trim();
        } else {
          readingAccessibilityDescription = true;
          if (remainder.trim().isNotEmpty) {
            accessibilityDescriptionLines.add(remainder.trim());
          }
        }
        continue;
      }
      if (lower.startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (lower == 'autonumber off') {
        autoNumber = false;
        continue;
      }
      if (lower == 'autonumber' || lower.startsWith('autonumber ')) {
        final values = line
            .substring('autonumber'.length)
            .trim()
            .split(RegExp(r'\s+'))
            .where((value) => value.isNotEmpty)
            .map(_parseSequenceNumber)
            .toList();
        if (values.any((value) => value == null) || values.length > 2) {
          return null;
        }
        autoNumber = true;
        autoNumberStart = values.isEmpty ? 1 : values[0]!;
        autoNumberStep = values.length < 2 ? 1 : values[1]!;
        nextNumber = autoNumberStart;
        continue;
      }
      if (lower == 'end') {
        if (activeBoxId != null && fragmentStack.isEmpty) {
          activeBoxId = null;
          continue;
        }
        if (fragmentStack.isEmpty) return null;
        final kind = fragmentStack.removeLast();
        events.add(
          SequenceFragmentData(
            depth: fragmentStack.length,
            kind: kind,
            isEnd: true,
          ),
        );
        continue;
      }
      final box = RegExp(
        r'^box(?:\s+(.*))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (box != null) {
        if (activeBoxId != null || fragmentStack.isNotEmpty) return null;
        final parsed = _parseBox(box.group(1)?.trim());
        final id = boxes.length;
        boxes.add(SequenceBoxData(id: id, label: parsed.$1, color: parsed.$2));
        activeBoxId = id;
        continue;
      }
      final participant = RegExp(
        r'^(participant|actor)\s+(.+?)(?:\s*@\s*(\{.*\}))?(?:\s+as\s+(.+))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (participant != null) {
        final id = participant.group(2)!;
        var kind = participant.group(1)!.toLowerCase() == 'actor'
            ? SequenceParticipantKind.actor
            : SequenceParticipantKind.participant;
        String? attributeAlias;
        if (participant.group(3) case final attributes?) {
          try {
            final decoded = _decodeObject(attributes);
            attributeAlias = decoded['alias']?.toString();
            final type = decoded['type']?.toString();
            if (type != null) {
              kind = SequenceParticipantKind.values.byName(type);
            }
            ensure(
              id,
              label: participant.group(4)?.trim() ?? attributeAlias,
              kind: kind,
            );
            participants[id] = participants[id]!.copyWith(
              properties: {...participants[id]!.properties, ...decoded},
            );
          } on Object {
            return null;
          }
        } else {
          ensure(
            id,
            label: participant.group(4)?.trim() ?? attributeAlias,
            kind: kind,
          );
        }
        continue;
      }
      final lifecycleDeclaration = RegExp(
        r'^(create|destroy)\s+(participant|actor)\s+(.+?)(?:\s*@\s*(\{.*\}))?(?:\s+as\s+(.+))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (lifecycleDeclaration != null) {
        final id = lifecycleDeclaration.group(3)!;
        var kind = lifecycleDeclaration.group(2)!.toLowerCase() == 'actor'
            ? SequenceParticipantKind.actor
            : SequenceParticipantKind.participant;
        Map<String, Object?> attributes = const {};
        if (lifecycleDeclaration.group(4) case final source?) {
          try {
            attributes = _decodeObject(source);
            if (attributes['type'] case final type?) {
              kind = SequenceParticipantKind.values.byName(type.toString());
            }
          } on Object {
            return null;
          }
        }
        ensure(
          id,
          label:
              lifecycleDeclaration.group(5)?.trim() ??
              attributes['alias']?.toString(),
          kind: kind,
        );
        participants[id] = participants[id]!.copyWith(
          properties: {...participants[id]!.properties, ...attributes},
        );
        events.add(
          SequenceLifecycleData(
            depth: fragmentStack.length,
            actor: id,
            kind: lifecycleDeclaration.group(1)!.toLowerCase() == 'create'
                ? SequenceLifecycleKind.create
                : SequenceLifecycleKind.destroy,
          ),
        );
        continue;
      }
      final lifecycle = RegExp(
        r'^(create|destroy)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (lifecycle != null) {
        final id = lifecycle.group(2)!;
        ensure(id);
        events.add(
          SequenceLifecycleData(
            depth: fragmentStack.length,
            actor: id,
            kind: lifecycle.group(1)!.toLowerCase() == 'create'
                ? SequenceLifecycleKind.create
                : SequenceLifecycleKind.destroy,
          ),
        );
        continue;
      }
      final activation = RegExp(
        r'^(activate|deactivate)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (activation != null) {
        final id = activation.group(2)!;
        final active = activation.group(1)!.toLowerCase() == 'activate';
        final depth = activationDepth[id] ?? 0;
        if (!active && depth == 0) return null;
        activationDepth[id] = active ? depth + 1 : depth - 1;
        ensure(id);
        events.add(
          SequenceActivationData(
            depth: fragmentStack.length,
            actor: id,
            active: active,
          ),
        );
        continue;
      }
      final note = RegExp(
        r'^note\s+(left of|right of|over)\s+([^:]+)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (note != null) {
        final text = _parseText(note.group(3)!.trim());
        final actorIds = note
            .group(2)!
            .split(',')
            .map((value) => value.trim())
            .toList();
        for (final id in actorIds) {
          ensure(id);
        }
        events.add(
          SequenceNoteData(
            depth: fragmentStack.length,
            position: switch (note.group(1)!.toLowerCase()) {
              'left of' => SequenceNotePosition.leftOf,
              'right of' => SequenceNotePosition.rightOf,
              _ => SequenceNotePosition.over,
            },
            actors: actorIds,
            text: text.$1,
            wrap: text.$2,
          ),
        );
        continue;
      }
      final links = RegExp(
        r'^links\s+([^:]+)\s*:\s*(\{.*\})$',
        caseSensitive: false,
      ).firstMatch(line);
      if (links != null) {
        final id = links.group(1)!.trim();
        ensure(id);
        try {
          final decoded = _decodeObject(
            links.group(2)!,
          ).map((key, value) => MapEntry(key, value.toString()));
          participants[id] = participants[id]!.copyWith(
            links: {...participants[id]!.links, ...decoded},
          );
        } on Object {
          return null;
        }
        continue;
      }
      final link = RegExp(
        r'^link\s+([^:]+)\s*:\s*(.+?)\s*@\s*(\S+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (link != null) {
        final id = link.group(1)!.trim();
        ensure(id);
        participants[id] = participants[id]!.copyWith(
          links: {
            ...participants[id]!.links,
            link.group(2)!.trim(): link.group(3)!,
          },
        );
        continue;
      }
      final properties = RegExp(
        r'^properties\s+([^:]+)\s*:\s*(\{.*\})$',
        caseSensitive: false,
      ).firstMatch(line);
      if (properties != null) {
        final id = properties.group(1)!.trim();
        ensure(id);
        try {
          final decoded = _decodeObject(properties.group(2)!);
          participants[id] = participants[id]!.copyWith(
            properties: {...participants[id]!.properties, ...decoded},
          );
        } on Object {
          return null;
        }
        continue;
      }
      final details = RegExp(
        r'^details\s+([^:]+)\s*:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (details != null) {
        final id = details.group(1)!.trim();
        ensure(id);
        participants[id] = participants[id]!.copyWith(
          detailsReference: details.group(2),
        );
        continue;
      }
      final fragment = _fragment(line);
      if (fragment != null) {
        if ((fragment.$1 == SequenceFragmentKind.elseAlternative &&
                (fragmentStack.isEmpty ||
                    fragmentStack.last != SequenceFragmentKind.alternative)) ||
            (fragment.$1 == SequenceFragmentKind.parallelAnd &&
                (fragmentStack.isEmpty ||
                    (fragmentStack.last != SequenceFragmentKind.parallel &&
                        fragmentStack.last !=
                            SequenceFragmentKind.parallelOver))) ||
            (fragment.$1 == SequenceFragmentKind.option &&
                (fragmentStack.isEmpty ||
                    fragmentStack.last != SequenceFragmentKind.critical))) {
          return null;
        }
        final text = fragment.$2 == null ? null : _parseText(fragment.$2!);
        events.add(
          SequenceFragmentData(
            depth: fragmentStack.length,
            kind: fragment.$1,
            label: text?.$1,
            wrap: text?.$2,
          ),
        );
        if (fragment.$1 != SequenceFragmentKind.elseAlternative &&
            fragment.$1 != SequenceFragmentKind.parallelAnd &&
            fragment.$1 != SequenceFragmentKind.option) {
          fragmentStack.add(fragment.$1);
        }
        continue;
      }
      final message = _parseMessage(line);
      if (message != null) {
        final from = message.from;
        final token = message.token;
        final activationMarker = message.activation;
        final to = message.to;
        ensure(from);
        ensure(to);
        edges.add(
          SequenceMessage(
            from: from,
            to: to,
            label: message.label,
            arrowType: switch (message.kind) {
              SequenceSignalKind.solidOpen ||
              SequenceSignalKind.dottedOpen => ArrowType.none,
              SequenceSignalKind.solidCross ||
              SequenceSignalKind.dottedCross => ArrowType.cross,
              _ => ArrowType.arrow,
            },
            lineType: token.startsWith('--') ? LineType.dotted : LineType.solid,
            bidirectional: token.startsWith('<<'),
            messageType: token.contains(')')
                ? MessageType.async
                : token.startsWith('--')
                ? MessageType.reply
                : MessageType.sync,
          ),
        );
        events.add(
          SequenceMessageEventData(
            depth: fragmentStack.length,
            edgeIndex: edges.length - 1,
            signalKind: message.kind,
            number: autoNumber ? nextNumber : null,
            centralAtSource: message.centralAtSource,
            centralAtTarget: message.centralAtTarget,
            wrap: message.wrap,
          ),
        );
        if (autoNumber) nextNumber += autoNumberStep;
        if (activationMarker.isNotEmpty) {
          final actor = activationMarker == '+' ? to : from;
          final active = activationMarker == '+';
          final depth = activationDepth[actor] ?? 0;
          if (!active && depth == 0) return null;
          activationDepth[actor] = active ? depth + 1 : depth - 1;
          events.add(
            SequenceActivationData(
              depth: fragmentStack.length,
              actor: actor,
              active: active,
            ),
          );
        }
        continue;
      }
      return null;
    }
    if (readingAccessibilityDescription ||
        fragmentStack.isNotEmpty ||
        activeBoxId != null ||
        participants.isEmpty) {
      return null;
    }
    final nodes = participants.values
        .map(
          (item) => SequenceParticipant(
            id: item.id,
            label: item.label,
            participantType: switch (item.kind) {
              SequenceParticipantKind.participant =>
                ParticipantType.participant,
              SequenceParticipantKind.actor => ParticipantType.actor,
              SequenceParticipantKind.boundary => ParticipantType.boundary,
              SequenceParticipantKind.control => ParticipantType.control,
              SequenceParticipantKind.entity => ParticipantType.entity,
              SequenceParticipantKind.database => ParticipantType.database,
              SequenceParticipantKind.collections =>
                ParticipantType.collections,
              SequenceParticipantKind.queue => ParticipantType.queue,
            },
            className: item.cssClass,
          ),
        )
        .toList();
    return (
      MermaidDiagramData(
        type: DiagramType.sequence,
        nodes: nodes,
        edges: edges,
        direction: DiagramDirection.leftToRight,
        title: title,
        sequenceConfig: const SequenceConfig(),
      ),
      SequenceChartData(
        participants: participants.values.toList(),
        events: events,
        autoNumber: autoNumber,
        autoNumberStart: autoNumberStart,
        autoNumberStep: autoNumberStep,
        boxes: boxes,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  num? _parseSequenceNumber(String value) {
    if (!RegExp(r'^(?:\d+(?:\.\d{1,2})?|\.\d{1,2})$').hasMatch(value)) {
      return null;
    }
    return value.contains('.') ? double.tryParse(value) : int.tryParse(value);
  }

  Iterable<String> _splitStatements(String source) sync* {
    source = _stripHashComment(source);
    var quote = '';
    var escaped = false;
    var start = 0;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if ((char == '"' || char == "'") &&
          (quote.isEmpty || quote == char)) {
        quote = quote.isEmpty ? char : '';
      } else if (char == ';' && quote.isEmpty) {
        final statement = source.substring(start, index).trim();
        if (statement.isNotEmpty) yield statement;
        start = index + 1;
      }
    }
    final statement = source.substring(start).trim();
    if (statement.isNotEmpty) yield statement;
  }

  String _stripHashComment(String source) {
    var quote = '';
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if ((char == '"' || char == "'") &&
          (quote.isEmpty || quote == char)) {
        quote = quote.isEmpty ? char : '';
      } else if (char == '#' && quote.isEmpty) {
        return source.substring(0, index);
      }
    }
    return source;
  }

  (String?, String?) _parseBox(String? value) {
    if (value == null || value.isEmpty) return (null, null);
    final color = RegExp(
      r'^((?:rgba?|hsla?)\s*\([^)]*\)|#[0-9a-fA-F]{3,8}|[a-zA-Z]+)(?:\s+(.*))?$',
    ).firstMatch(value);
    if (color == null) return (value, null);
    final candidate = color.group(1)!;
    const cssNames = {
      'aqua',
      'black',
      'blue',
      'fuchsia',
      'gray',
      'green',
      'lime',
      'maroon',
      'navy',
      'olive',
      'orange',
      'purple',
      'red',
      'silver',
      'teal',
      'transparent',
      'white',
      'yellow',
    };
    final isColor =
        candidate.startsWith('#') ||
        candidate.contains('(') ||
        cssNames.contains(candidate.toLowerCase());
    return isColor ? (color.group(2)?.trim(), candidate) : (value, null);
  }

  (String, bool?) _parseText(String value) {
    final match = RegExp(
      r'^:?(wrap|nowrap):\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return (value, null);
    return (match.group(2)!, match.group(1)!.toLowerCase() == 'wrap');
  }

  _ParsedSequenceMessage? _parseMessage(String line) {
    final colon = line.indexOf(':');
    if (colon < 0) return null;
    final body = line.substring(0, colon).trim();
    final text = _parseText(line.substring(colon + 1).trim());
    const tokens = <String, SequenceSignalKind>{
      '<<-->>': SequenceSignalKind.bidirectionalDotted,
      '<<->>': SequenceSignalKind.bidirectionalSolid,
      '--|\\': SequenceSignalKind.solidTopDotted,
      '--|/': SequenceSignalKind.solidBottomDotted,
      '--\\\\': SequenceSignalKind.stickTopDotted,
      '--//': SequenceSignalKind.stickBottomDotted,
      '/|--': SequenceSignalKind.solidTopReverseDotted,
      '\\|--': SequenceSignalKind.solidBottomReverseDotted,
      '//--': SequenceSignalKind.stickTopReverseDotted,
      '\\\\--': SequenceSignalKind.stickBottomReverseDotted,
      '-->>': SequenceSignalKind.dotted,
      '->>': SequenceSignalKind.solid,
      '-->': SequenceSignalKind.dottedOpen,
      '--x': SequenceSignalKind.dottedCross,
      '--)': SequenceSignalKind.dottedPoint,
      '-|\\': SequenceSignalKind.solidTop,
      '-|/': SequenceSignalKind.solidBottom,
      '-\\\\': SequenceSignalKind.stickTop,
      '-//': SequenceSignalKind.stickBottom,
      '/|-': SequenceSignalKind.solidTopReverse,
      '\\|-': SequenceSignalKind.solidBottomReverse,
      '//-': SequenceSignalKind.stickTopReverse,
      '\\\\-': SequenceSignalKind.stickBottomReverse,
      '->': SequenceSignalKind.solidOpen,
      '-x': SequenceSignalKind.solidCross,
      '-)': SequenceSignalKind.solidPoint,
    };
    for (final entry in tokens.entries) {
      final position = body.indexOf(entry.key);
      if (position <= 0) continue;
      var from = body.substring(0, position).trim();
      var remainder = body.substring(position + entry.key.length).trim();
      var centralAtSource = false;
      var centralAtTarget = false;
      if (from.endsWith('()')) {
        centralAtSource = true;
        from = from.substring(0, from.length - 2).trim();
      }
      if (remainder.startsWith('()')) {
        centralAtTarget = true;
        remainder = remainder.substring(2).trim();
      }
      var activation = '';
      if (remainder.startsWith('+') || remainder.startsWith('-')) {
        activation = remainder[0];
        remainder = remainder.substring(1).trim();
      }
      if (from.isEmpty || remainder.isEmpty) return null;
      return _ParsedSequenceMessage(
        from: from,
        to: remainder,
        token: entry.key,
        label: text.$1,
        activation: activation,
        kind: entry.value,
        centralAtSource: centralAtSource,
        centralAtTarget: centralAtTarget,
        wrap: text.$2,
      );
    }
    return null;
  }

  Map<String, Object?> _decodeObject(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      decoded = loadYaml(source);
    }
    if (decoded is! Map) throw const FormatException('Expected object');
    return decoded.map(
      (key, value) => MapEntry(key.toString(), _plainYaml(value)),
    );
  }

  Object? _plainYaml(Object? value) {
    if (value is Map) {
      return value.map(
        (key, child) => MapEntry(key.toString(), _plainYaml(child)),
      );
    }
    if (value is List) return value.map(_plainYaml).toList(growable: false);
    return value;
  }

  (SequenceFragmentKind, String?)? _fragment(String line) {
    final match = RegExp(
      r'^(loop|opt|alt|else|par|par_over|and|critical|option|break|rect)(?:\s+(.*))?$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return null;
    final kind = switch (match.group(1)!.toLowerCase()) {
      'loop' => SequenceFragmentKind.loop,
      'opt' => SequenceFragmentKind.optional,
      'alt' => SequenceFragmentKind.alternative,
      'else' => SequenceFragmentKind.elseAlternative,
      'par' => SequenceFragmentKind.parallel,
      'par_over' => SequenceFragmentKind.parallelOver,
      'and' => SequenceFragmentKind.parallelAnd,
      'critical' => SequenceFragmentKind.critical,
      'option' => SequenceFragmentKind.option,
      'break' => SequenceFragmentKind.breakBlock,
      'rect' => SequenceFragmentKind.rectangle,
      _ => SequenceFragmentKind.rectangle,
    };
    return (kind, match.group(2)?.trim());
  }
}

class _ParsedSequenceMessage {
  const _ParsedSequenceMessage({
    required this.from,
    required this.to,
    required this.token,
    required this.label,
    required this.activation,
    required this.kind,
    required this.centralAtSource,
    required this.centralAtTarget,
    required this.wrap,
  });

  final String from;
  final String to;
  final String token;
  final String label;
  final String activation;
  final SequenceSignalKind kind;
  final bool centralAtSource;
  final bool centralAtTarget;
  final bool? wrap;
}
