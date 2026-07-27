/*
 * [INPUT]: Depends on ZenUML participants, calls, replies, creation, comments, and nested control fragments.
 * [OUTPUT]: Defines immutable ZenUML participant, message, comment, and fragment events with source nesting depth.
 * [POS]: Serves as the lossless chart-specific representation alongside the shared sequence graph projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum ZenParticipantKind {
  participant,
  actor,
  database,
  boundary,
  control,
  entity,
}

enum ZenMessageKind { asynchronous, synchronous, creation, reply }

enum ZenFragmentKind {
  whileLoop,
  forLoop,
  forEachLoop,
  loop,
  alternative,
  elseAlternative,
  optional,
  parallel,
  tryBlock,
  catchBlock,
  finallyBlock,
}

sealed class ZenEventData {
  const ZenEventData({required this.depth});
  final int depth;
}

class ZenMessageData extends ZenEventData {
  const ZenMessageData({
    required super.depth,
    required this.from,
    required this.to,
    required this.text,
    required this.kind,
  });
  final String from;
  final String to;
  final String text;
  final ZenMessageKind kind;
}

class ZenFragmentData extends ZenEventData {
  const ZenFragmentData({
    required super.depth,
    required this.kind,
    this.condition,
  });
  final ZenFragmentKind kind;
  final String? condition;
}

class ZenCommentData extends ZenEventData {
  const ZenCommentData({required super.depth, required this.text});
  final String text;
}

class ZenParticipantData {
  const ZenParticipantData({
    required this.id,
    required this.label,
    required this.kind,
  });
  final String id;
  final String label;
  final ZenParticipantKind kind;
}

class ZenUmlChartData {
  const ZenUmlChartData({
    required this.participants,
    required this.events,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.useMaxWidth = true,
  });
  final List<ZenParticipantData> participants;
  final List<ZenEventData> events;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final bool useMaxWidth;

  ZenUmlChartData copyWith({String? title, bool? useMaxWidth}) =>
      ZenUmlChartData(
        participants: participants,
        events: events,
        title: title ?? this.title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
        useMaxWidth: useMaxWidth ?? this.useMaxWidth,
      );
}
