/*
 * [INPUT]: Depends on official ZenUML syntax and native ZenUML plus shared sequence graph models.
 * [OUTPUT]: Parses participants, annotators, aliases, async/sync/create/reply messages, comments, and nested control fragments.
 * [POS]: Serves as the native syntax adapter for Mermaid's externally registered ZenUML diagram family.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/zenuml.dart';

class ZenUmlDiagramParser {
  const ZenUmlDiagramParser();

  (MermaidDiagramData, ZenUmlChartData)? parse(List<String> lines) {
    if (lines.isEmpty || lines.first.trim().toLowerCase() != 'zenuml') {
      return null;
    }
    final participants = <String, ZenParticipantData>{};
    final events = <ZenEventData>[];
    final activations = <String>[];
    final pendingComments = <String>[];
    var depth = 0;
    var pendingReply = false;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;

    void flushComments() {
      for (final comment in pendingComments) {
        events.add(ZenCommentData(depth: depth, text: comment));
      }
      pendingComments.clear();
    }

    void participant(
      String id, {
      String? label,
      ZenParticipantKind kind = ZenParticipantKind.participant,
    }) {
      participants.putIfAbsent(
        id,
        () => ZenParticipantData(id: id, label: label ?? id, kind: kind),
      );
    }

    for (final raw in lines.skip(1)) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('//')) {
        pendingComments.add(line.substring(2).trim());
        continue;
      }
      while (line.startsWith('}')) {
        if (depth > 0) depth--;
        if (activations.length > depth) activations.removeLast();
        line = line.substring(1).trim();
      }
      if (line.isEmpty) continue;
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
      if (line == '@return' || line == '@reply') {
        pendingReply = true;
        continue;
      }

      final branch = RegExp(
        r'^(else(?:\s+if\s*\((.*)\))?|catch|finally)\s*\{$',
      ).firstMatch(line);
      if (branch != null) {
        flushComments();
        final token = branch.group(1)!;
        events.add(
          ZenFragmentData(
            depth: depth,
            kind: token.startsWith('else')
                ? ZenFragmentKind.elseAlternative
                : token == 'catch'
                ? ZenFragmentKind.catchBlock
                : ZenFragmentKind.finallyBlock,
            condition: branch.group(2),
          ),
        );
        depth++;
        continue;
      }
      final fragment = RegExp(
        r'^(while|for|forEach|foreach|loop|if|opt|par|try)(?:\s*\((.*)\))?\s*\{$',
      ).firstMatch(line);
      if (fragment != null) {
        flushComments();
        events.add(
          ZenFragmentData(
            depth: depth,
            kind: _fragment(fragment.group(1)!),
            condition: fragment.group(2),
          ),
        );
        depth++;
        continue;
      }
      final annotated = RegExp(
        r'^@(Actor|Database|Boundary|Control|Entity)\s+([\w.$-]+)(?:\s+as\s+(.+))?$',
      ).firstMatch(line);
      if (annotated != null) {
        pendingComments.clear();
        participant(
          annotated.group(2)!,
          label: annotated.group(3),
          kind: ZenParticipantKind.values.byName(
            annotated.group(1)!.toLowerCase(),
          ),
        );
        continue;
      }
      final alias = RegExp(r'^([\w.$-]+)\s+as\s+(.+)$').firstMatch(line);
      if (alias != null) {
        pendingComments.clear();
        participant(alias.group(1)!, label: alias.group(2)!);
        continue;
      }
      final creation = RegExp(
        r'^new\s+([\w.$-]+)(?:\((.*)\))?\s*(\{)?$',
      ).firstMatch(line);
      if (creation != null) {
        flushComments();
        final to = creation.group(1)!;
        final from = activations.isEmpty ? 'External' : activations.last;
        participant(from);
        participant(to);
        events.add(
          ZenMessageData(
            depth: depth,
            from: from,
            to: to,
            text:
                'new $to${creation.group(2) == null ? '' : '(${creation.group(2)})'}',
            kind: ZenMessageKind.creation,
          ),
        );
        if (creation.group(3) != null) {
          activations.add(to);
          depth++;
        }
        continue;
      }
      final asynchronous = RegExp(
        r'^([\w.$-]+)\s*->\s*([\w.$-]+)(?:\.([^:]+))?\s*:\s*(.+)$',
      ).firstMatch(line);
      if (asynchronous != null) {
        flushComments();
        final from = asynchronous.group(1)!;
        final to = asynchronous.group(2)!;
        participant(from);
        participant(to);
        events.add(
          ZenMessageData(
            depth: depth,
            from: from,
            to: to,
            text: asynchronous.group(4)!,
            kind: pendingReply
                ? ZenMessageKind.reply
                : ZenMessageKind.asynchronous,
          ),
        );
        pendingReply = false;
        continue;
      }
      final directedCall = RegExp(
        r'^([\w.$-]+)\s*->\s*([\w.$-]+)\.([\w$-]+)(?:\((.*)\))?\s*(\{)?$',
      ).firstMatch(line);
      if (directedCall != null) {
        flushComments();
        final from = directedCall.group(1)!;
        final to = directedCall.group(2)!;
        participant(from);
        participant(to);
        events.add(
          ZenMessageData(
            depth: depth,
            from: from,
            to: to,
            text: '${directedCall.group(3)}(${directedCall.group(4) ?? ''})',
            kind: ZenMessageKind.synchronous,
          ),
        );
        if (directedCall.group(5) != null) {
          activations.add(to);
          depth++;
        }
        continue;
      }
      final returned = RegExp(r'^return(?:\s+(.+))?$').firstMatch(line);
      if (returned != null) {
        flushComments();
        if (activations.length >= 2) {
          events.add(
            ZenMessageData(
              depth: depth,
              from: activations.last,
              to: activations[activations.length - 2],
              text: returned.group(1) ?? 'return',
              kind: ZenMessageKind.reply,
            ),
          );
        } else if (activations.length == 1) {
          events.add(
            ZenMessageData(
              depth: depth,
              from: activations.last,
              to: 'External',
              text: returned.group(1) ?? 'return',
              kind: ZenMessageKind.reply,
            ),
          );
        }
        continue;
      }
      final call = RegExp(
        r'^(?:(?:[\w.$<>-]+\s+)?([\w.$-]+)\s*=\s*)?([\w.$-]+)\.([\w$-]+)(?:\((.*)\))?\s*(\{)?$',
      ).firstMatch(line);
      if (call != null) {
        flushComments();
        final assignment = call.group(1);
        final to = call.group(2)!;
        final from = activations.isEmpty ? 'External' : activations.last;
        participant(from);
        participant(to);
        events.add(
          ZenMessageData(
            depth: depth,
            from: from,
            to: to,
            text: '${call.group(3)}(${call.group(4) ?? ''})',
            kind: ZenMessageKind.synchronous,
          ),
        );
        if (assignment != null && call.group(5) == null) {
          events.add(
            ZenMessageData(
              depth: depth,
              from: to,
              to: from,
              text: assignment,
              kind: ZenMessageKind.reply,
            ),
          );
        }
        if (call.group(5) != null) {
          activations.add(to);
          depth++;
        }
        continue;
      }
      if (RegExp(r'^[\w.$-]+$').hasMatch(line)) {
        pendingComments.clear();
        participant(line);
        continue;
      }
      return null;
    }
    final nodes = participants.values
        .map(
          (item) => SequenceParticipant(
            id: item.id,
            label: item.label,
            participantType: switch (item.kind) {
              ZenParticipantKind.actor => ParticipantType.actor,
              ZenParticipantKind.database => ParticipantType.database,
              ZenParticipantKind.boundary => ParticipantType.boundary,
              ZenParticipantKind.control => ParticipantType.control,
              ZenParticipantKind.entity => ParticipantType.entity,
              ZenParticipantKind.participant => ParticipantType.participant,
            },
          ),
        )
        .toList();
    final edges = events
        .whereType<ZenMessageData>()
        .map(
          (item) => SequenceMessage(
            from: item.from,
            to: item.to,
            label: item.text,
            lineType: item.kind == ZenMessageKind.reply
                ? LineType.dotted
                : LineType.solid,
            messageType: item.kind == ZenMessageKind.reply
                ? MessageType.reply
                : item.kind == ZenMessageKind.asynchronous
                ? MessageType.async
                : MessageType.sync,
          ),
        )
        .toList();
    if (nodes.isEmpty) return null;
    return (
      MermaidDiagramData(
        type: DiagramType.zenuml,
        nodes: nodes,
        edges: edges,
        direction: DiagramDirection.leftToRight,
        title: title,
      ),
      ZenUmlChartData(
        participants: participants.values.toList(),
        events: events,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  ZenFragmentKind _fragment(String value) => switch (value) {
    'while' => ZenFragmentKind.whileLoop,
    'for' => ZenFragmentKind.forLoop,
    'forEach' || 'foreach' => ZenFragmentKind.forEachLoop,
    'loop' => ZenFragmentKind.loop,
    'if' => ZenFragmentKind.alternative,
    'opt' => ZenFragmentKind.optional,
    'par' => ZenFragmentKind.parallel,
    _ => ZenFragmentKind.tryBlock,
  };
}
