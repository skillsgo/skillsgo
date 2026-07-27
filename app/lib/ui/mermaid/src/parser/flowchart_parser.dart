/*
 * [INPUT]: Depends on Mermaid 11.16.0 flowchart grammar plus shared node, edge, subgraph, style, and configuration models.
 * [OUTPUT]: Strictly parses legacy and attribute node shapes, edge families/IDs/metadata, multi-node chains, subgraphs, directions, classes, styles, interactions, titles, and accessibility.
 * [POS]: Serves as the lossless native flowchart parser feeding Flutter layout, interaction, and Canvas painting.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
library;

import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/flowchart.dart';
import '../models/node.dart';
import '../models/style.dart';

class FlowchartParser {
  final Map<String, MermaidNode> _nodes = {};
  final List<MermaidEdge> _edges = [];
  final List<Subgraph> _subgraphs = [];
  final Map<String, NodeStyle> _classDefs = {};
  final Map<String, String> _classStyleSources = {};
  final Map<String, List<String>> _nodeClasses = {};
  final Map<String, NodeStyle> _pendingNodeStyles = {};
  final List<_FlowSubgraphState> _subgraphStack = [];
  final Map<String, int> _edgeIds = {};
  final Map<String, int> _edgePairCounts = {};
  DiagramDirection _direction = DiagramDirection.topToBottom;
  String? _title;
  String? _accessibilityTitle;
  String? _accessibilityDescription;
  bool _readingAccessibility = false;
  final List<String> _accessibilityLines = [];

  MermaidDiagramData? parse(List<String> lines) {
    _reset();
    final statements = _joinMarkdownStatements(
      lines,
    ).expand(_splitStatements).toList(growable: false);
    if (statements.isEmpty) return null;
    final header = RegExp(
      r'^(?:flowchart|graph)(?:\s+(TB|TD|BT|LR|RL))?$',
      caseSensitive: false,
    ).firstMatch(statements.first.trim());
    if (header == null) return null;
    _direction =
        _directionFrom(header.group(1)) ?? DiagramDirection.topToBottom;

    for (final statement in statements.skip(1)) {
      if (!_parseStatement(statement.trim())) return null;
    }
    if (_readingAccessibility || _subgraphStack.isNotEmpty) return null;
    _applyStyles();
    return MermaidDiagramData(
      type: DiagramType.flowchart,
      nodes: _nodes.values.toList(growable: false),
      edges: List.unmodifiable(_edges),
      direction: _direction,
      subgraphs: List.unmodifiable(_subgraphs),
      style: MermaidStyle(classDefs: _classDefs),
      title: _title,
      accessibilityTitle: _accessibilityTitle,
      accessibilityDescription: _accessibilityDescription,
      flowchartConfig: const FlowchartConfig(),
    );
  }

  void _reset() {
    _nodes.clear();
    _edges.clear();
    _subgraphs.clear();
    _classDefs.clear();
    _classStyleSources.clear();
    _nodeClasses.clear();
    _pendingNodeStyles.clear();
    _subgraphStack.clear();
    _edgeIds.clear();
    _edgePairCounts.clear();
    _title = null;
    _accessibilityTitle = null;
    _accessibilityDescription = null;
    _readingAccessibility = false;
    _accessibilityLines.clear();
  }

  bool _parseStatement(String line) {
    if (line.isEmpty) return true;
    if (_readingAccessibility) {
      final close = line.indexOf('}');
      if (close < 0) {
        _accessibilityLines.add(line);
      } else {
        _accessibilityLines.add(line.substring(0, close).trim());
        _accessibilityDescription = _accessibilityLines
            .where((value) => value.isNotEmpty)
            .join('\n');
        _readingAccessibility = false;
      }
      return true;
    }
    final lower = line.toLowerCase();
    if (lower.startsWith('title:')) {
      _title = line.substring(line.indexOf(':') + 1).trim();
      return true;
    }
    if (lower.startsWith('acctitle:')) {
      _accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
      return true;
    }
    if (RegExp(r'^accdescr\s*\{', caseSensitive: false).hasMatch(line)) {
      final remainder = line.substring(line.indexOf('{') + 1);
      final close = remainder.indexOf('}');
      if (close >= 0) {
        _accessibilityDescription = remainder.substring(0, close).trim();
      } else {
        _readingAccessibility = true;
        if (remainder.trim().isNotEmpty) {
          _accessibilityLines.add(remainder.trim());
        }
      }
      return true;
    }
    if (lower.startsWith('accdescr:')) {
      _accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
      return true;
    }
    if (lower.startsWith('subgraph ')) {
      return _startSubgraph(line.substring(9).trim());
    }
    if (lower == 'end') return _endSubgraph();
    if (lower.startsWith('direction ')) {
      final direction = _directionFrom(line.substring(10).trim());
      if (direction == null) return false;
      if (_subgraphStack.isEmpty) {
        _direction = direction;
      } else {
        _subgraphStack.last.direction = direction;
      }
      return true;
    }
    if (lower.startsWith('classdef ')) return _parseClassDef(line);
    if (lower.startsWith('class ')) return _parseClassAssignment(line);
    if (lower.startsWith('style ')) return _parseStyle(line);
    if (lower.startsWith('linkstyle ')) return _parseLinkStyle(line);
    if (lower.startsWith('click ') || lower.startsWith('href ')) {
      return _parseInteraction(line);
    }
    if (_parseMetadataStatement(line)) return true;
    return _parseGraphStatement(_normalizeInlineEdgeLabels(line));
  }

  bool _startSubgraph(String source) {
    if (source.isEmpty) return false;
    String id;
    String label;
    final bracket = RegExp(r'^([^\s\[]+)\s*\[(.*)\]$').firstMatch(source);
    if (bracket != null) {
      id = bracket.group(1)!;
      label = _cleanLabel(bracket.group(2)!);
    } else {
      final quoted = RegExp(r'^(?:"([^"]+)"|(.+))$').firstMatch(source)!;
      label = quoted.group(1) ?? quoted.group(2)!;
      id = label.contains(RegExp(r'\s'))
          ? 'subgraph_${_subgraphs.length}'
          : label;
    }
    if (_subgraphs.any((item) => item.id == id) ||
        _subgraphStack.any((item) => item.id == id)) {
      return false;
    }
    _subgraphStack.add(
      _FlowSubgraphState(
        id: id,
        label: label,
        parentId: _subgraphStack.isEmpty ? null : _subgraphStack.last.id,
      ),
    );
    return true;
  }

  bool _endSubgraph() {
    if (_subgraphStack.isEmpty) return false;
    final state = _subgraphStack.removeLast();
    _subgraphs.add(
      Subgraph(
        id: state.id,
        label: state.label,
        nodeIds: List.unmodifiable(state.nodeIds),
        direction: state.direction,
        parentId: state.parentId,
        style: state.style,
      ),
    );
    if (_subgraphStack.isNotEmpty) {
      for (final id in state.nodeIds) {
        _trackNode(id);
      }
    }
    return true;
  }

  bool _parseMetadataStatement(String line) {
    final match = RegExp(
      r'^([A-Za-z0-9_][\w-]*)@\s*(\{.*\})$',
    ).firstMatch(line);
    if (match == null) return false;
    final id = match.group(1)!;
    Map<String, Object?> values;
    try {
      values = _decodeObject(match.group(2)!);
    } on Object {
      return false;
    }
    if (_edgeIds[id] case final edgeIndex?) {
      final edge = _edges[edgeIndex];
      final animate = _bool(values['animate']);
      final speed = values['animation']?.toString();
      final curve = values['curve']?.toString();
      _edges[edgeIndex] = edge.copyWith(
        animated: animate,
        animationSpeed: speed,
        interpolate: curve,
      );
      return true;
    }
    final existing = _nodes[id];
    final parsed = _nodeFromAttributes(id, values, existing: existing);
    if (parsed == null) return false;
    _nodes[id] = parsed;
    _trackNode(id);
    return true;
  }

  bool _parseGraphStatement(String line) {
    final matches = _edgePattern
        .allMatches(_maskNodeBodiesForEdges(line))
        .toList();
    if (matches.isEmpty) return _parseNodeGroup(line).isNotEmpty;
    final segments = <String>[];
    var cursor = 0;
    for (final match in matches) {
      segments.add(line.substring(cursor, match.start).trim());
      cursor = match.end;
    }
    segments.add(line.substring(cursor).trim());
    if (segments.length != matches.length + 1 ||
        segments.any((item) => item.isEmpty)) {
      return false;
    }
    final groups = segments.map(_parseNodeGroup).toList(growable: false);
    if (groups.any((item) => item.isEmpty)) return false;
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final edgeId = match.group(1);
      final token = match.group(2)!;
      final label = match.group(3)?.trim();
      final left = groups[index];
      final right = groups[index + 1];
      final explicitPosition = left.length > 1
          ? (left.length - 1) * right.length
          : 0;
      var combination = 0;
      for (final from in left) {
        for (final to in right) {
          final assignExplicit =
              edgeId != null &&
              combination == explicitPosition &&
              !_edgeIds.containsKey(edgeId);
          final pair = '$from\u0000$to';
          final pairIndex = _edgePairCounts.update(
            pair,
            (value) => value + 1,
            ifAbsent: () => 0,
          );
          final resolvedId = assignExplicit
              ? edgeId
              : 'L_${from}_${to}_$pairIndex';
          final edge = MermaidEdge(
            from: from,
            to: to,
            id: resolvedId,
            label: label == null ? null : _cleanLabel(label),
            arrowType: _arrowType(token),
            sourceArrowType: _sourceArrowType(token),
            lineType: _lineType(token),
            bidirectional:
                token.startsWith('<') ||
                (token.startsWith('o') && token.endsWith('o')) ||
                (token.startsWith('x') && token.endsWith('x')),
            invisible: token.contains('~'),
            minLength: _edgeLength(token),
            isSubgraphEdge: _isSubgraph(from) || _isSubgraph(to),
          );
          if (assignExplicit) {
            _edgeIds[edgeId] = _edges.length;
          }
          _edges.add(edge);
          combination++;
        }
      }
    }
    return true;
  }

  String _maskNodeBodiesForEdges(String source) {
    final result = StringBuffer();
    var quote = '';
    var depth = 0;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      final wasProtected = quote.isNotEmpty || depth > 0;
      if ((char == '"' || char == "'" || char == '`') &&
          (quote.isEmpty || quote == char)) {
        quote = quote.isEmpty ? char : '';
      } else if (quote.isEmpty && '([{'.contains(char)) {
        depth++;
      } else if (quote.isEmpty && ')]}'.contains(char) && depth > 0) {
        depth--;
      }
      result.write(wasProtected || quote.isNotEmpty || depth > 0 ? ' ' : char);
    }
    return result.toString();
  }

  List<String> _parseNodeGroup(String source) {
    final parts = _splitOutside(source, '&');
    final result = <String>[];
    for (final part in parts) {
      final token = part.trim();
      if (token.isEmpty) return const [];
      if (_isSubgraph(token)) {
        result.add(token);
        continue;
      }
      final node = _parseNode(token);
      if (node == null) return const [];
      final existing = _nodes[node.id];
      _nodes[node.id] = existing == null || _isRicher(node, existing)
          ? node
          : existing;
      _trackNode(node.id);
      result.add(node.id);
    }
    return result;
  }

  MermaidNode? _parseNode(String source) {
    var token = source.trim().replaceAll('\n', '<br/>');
    String? directClass;
    final classMatch = RegExp(
      r'(?:(:::)|\.)([A-Za-z0-9_][\w-]*)$',
    ).firstMatch(token);
    if (classMatch != null) {
      directClass = classMatch.group(2);
      token = token.substring(0, classMatch.start).trim();
    }
    final attributes = RegExp(
      r'^([A-Za-z0-9_][\w-]*)@\s*(\{.*\})$',
    ).firstMatch(token);
    if (attributes != null) {
      try {
        final node = _nodeFromAttributes(
          attributes.group(1)!,
          _decodeObject(attributes.group(2)!),
          existing: _nodes[attributes.group(1)!],
        );
        if (node != null && directClass != null) {
          _nodeClasses.putIfAbsent(node.id, () => []).add(directClass);
        }
        return node;
      } on Object {
        return null;
      }
    }
    final definitions = <(RegExp, NodeShape)>[
      (
        RegExp(r'^([A-Za-z0-9_][\w-]*)\(\(\((.*)\)\)\)$'),
        NodeShape.doubleCircle,
      ),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\(\((.*)\)\)$'), NodeShape.circle),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\{\{(.*)\}\}$'), NodeShape.hexagon),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\[\[(.*)\]\]$'), NodeShape.subroutine),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\[\((.*)\)\]$'), NodeShape.cylinder),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\(\[(.*)\]\)$'), NodeShape.stadium),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\[/(.*)/\]$'), NodeShape.parallelogram),
      (
        RegExp(r'^([A-Za-z0-9_][\w-]*)\[\\(.*)\\\]$'),
        NodeShape.parallelogramAlt,
      ),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\[/(.*)\\\]$'), NodeShape.trapezoid),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\[\\(.*)/\]$'), NodeShape.trapezoidAlt),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)>(.*)\]$'), NodeShape.asymmetric),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\[(.*)\]$'), NodeShape.rectangle),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\((.*)\)$'), NodeShape.roundedRect),
      (RegExp(r'^([A-Za-z0-9_][\w-]*)\{(.*)\}$'), NodeShape.diamond),
    ];
    for (final definition in definitions) {
      final match = definition.$1.firstMatch(token);
      if (match == null) continue;
      final id = match.group(1)!;
      if (directClass != null) {
        _nodeClasses.putIfAbsent(id, () => []).add(directClass);
      }
      return MermaidNode(
        id: id,
        label: _cleanLabel(match.group(2)!),
        shape: definition.$2,
      );
    }
    final plain = RegExp(r'^([A-Za-z0-9_][\w-]*)$').firstMatch(token);
    if (plain == null) return null;
    final id = plain.group(1)!;
    if (directClass != null) {
      _nodeClasses.putIfAbsent(id, () => []).add(directClass);
    }
    return MermaidNode(id: id, label: id);
  }

  MermaidNode? _nodeFromAttributes(
    String id,
    Map<String, Object?> values, {
    MermaidNode? existing,
  }) {
    final shapeSource = values['shape']?.toString();
    final shape = values.containsKey('img')
        ? NodeShape.image
        : values.containsKey('icon')
        ? NodeShape.icon
        : shapeSource == null
        ? existing?.shape ?? NodeShape.rectangle
        : _shape(shapeSource);
    if (shape == null) return null;
    return MermaidNode(
      id: id,
      label: _cleanLabel(values['label']?.toString() ?? existing?.label ?? id),
      shape: shape,
      style: existing?.style,
      className: existing?.className,
      link: existing?.link,
      tooltip: existing?.tooltip,
      linkTarget: existing?.linkTarget,
      callback: existing?.callback,
      callbackArgs: existing?.callbackArgs ?? const [],
      attributes: {...?existing?.attributes, ...values},
    );
  }

  bool _parseClassDef(String line) {
    final match = RegExp(
      r'^classDef\s+([\w,-]+)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return false;
    final style = _nodeStyle(match.group(2)!);
    for (final name in match.group(1)!.split(',')) {
      final normalized = name.trim();
      _classDefs[normalized] = style;
      _classStyleSources[normalized] = match.group(2)!;
    }
    return true;
  }

  bool _parseClassAssignment(String line) {
    final match = RegExp(
      r'^class\s+([^\s]+)\s+([^\s]+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return false;
    final classes = match.group(2)!.split(',');
    for (final id in match.group(1)!.split(',')) {
      if (_edgeIds[id] case final edgeIndex?) {
        _edges[edgeIndex] = _edges[edgeIndex].copyWith(
          className: classes.join(' '),
        );
      } else {
        _nodeClasses.putIfAbsent(id, () => []).addAll(classes);
      }
    }
    return true;
  }

  bool _parseStyle(String line) {
    final match = RegExp(
      r'^style\s+([^\s]+)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return false;
    final ids = match.group(1)!.split(',').map((value) => value.trim());
    final style = _nodeStyle(match.group(2)!);
    for (final id in ids) {
      if (id.isEmpty) return false;
      if (_isSubgraph(id)) {
        final subgraphStyle = _subgraphStyle(match.group(2)!);
        final index = _subgraphs.indexWhere((item) => item.id == id);
        if (index >= 0) {
          final old = _subgraphs[index];
          _subgraphs[index] = Subgraph(
            id: old.id,
            label: old.label,
            nodeIds: old.nodeIds,
            direction: old.direction,
            parentId: old.parentId,
            style: subgraphStyle,
          );
        }
      } else {
        _pendingNodeStyles[id] = style;
      }
    }
    return true;
  }

  bool _parseLinkStyle(String line) {
    final match = RegExp(
      r'^linkStyle\s+([^\s]+)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return false;
    final styleSource = match.group(2)!;
    final interpolation = RegExp(
      r'\binterpolate\s+([A-Za-z]+)',
      caseSensitive: false,
    ).firstMatch(styleSource);
    final cleanedStyle = styleSource.replaceFirst(
      RegExp(r'\binterpolate\s+[A-Za-z]+\s*', caseSensitive: false),
      '',
    );
    final edgeStyle = _edgeStyle(cleanedStyle);
    final curve =
        interpolation?.group(1) ??
        _property(styleSource, 'curve') ??
        _property(styleSource, 'interpolate');
    final targets = match.group(1)!.toLowerCase() == 'default'
        ? List<int>.generate(_edges.length, (index) => index)
        : match
              .group(1)!
              .split(',')
              .map(int.tryParse)
              .whereType<int>()
              .toList();
    if (targets.isEmpty ||
        targets.any((index) => index < 0 || index >= _edges.length)) {
      return false;
    }
    for (final index in targets) {
      _edges[index] = _edges[index].copyWith(
        style: edgeStyle,
        interpolate: curve,
      );
    }
    return true;
  }

  bool _parseInteraction(String line) {
    final match = RegExp(
      r'^(?:click|href)\s+([^\s]+)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null || !_nodes.containsKey(match.group(1)!)) return false;
    final id = match.group(1)!;
    var remainder = match.group(2)!.trim();
    final words = _quotedWords(remainder);
    if (words.isEmpty) return false;
    String? link;
    String? callback;
    List<String> callbackArgs = const [];
    if (remainder.toLowerCase().startsWith('href ')) {
      remainder = remainder.substring(5).trim();
    }
    final explicitCall = remainder.toLowerCase().startsWith('call ');
    if (explicitCall) remainder = remainder.substring(5).trim();
    final callbackMatch = RegExp(
      r'^([\w.]+)\s*\((.*?)\)(?:\s+(.*))?$',
    ).firstMatch(remainder);
    String action;
    String trailing;
    if (callbackMatch != null) {
      action = callbackMatch.group(1)!;
      trailing = callbackMatch.group(3) ?? '';
      callbackArgs = _splitOutside(callbackMatch.group(2) ?? '', ',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } else {
      final actionMatch = RegExp(
        r'''^(?:"([^"]*)"|'([^']*)'|(\S+))(?:\s+(.*))?$''',
      ).firstMatch(remainder);
      if (actionMatch == null) return false;
      action =
          actionMatch.group(1) ?? actionMatch.group(2) ?? actionMatch.group(3)!;
      trailing = actionMatch.group(4) ?? '';
    }
    if (action.contains('://') ||
        action.startsWith('/') ||
        action.startsWith('#')) {
      link = action;
    } else if (callbackMatch != null || explicitCall) {
      callback = action;
    } else {
      callback = action;
    }
    String? tooltip;
    String? target;
    for (final value in _quotedWords(trailing)) {
      if (value.startsWith('_')) {
        target = value;
      } else {
        tooltip = value;
      }
    }
    final node = _nodes[id]!;
    _nodes[id] = node.copyWith(
      link: link,
      tooltip: tooltip,
      linkTarget: target,
      callback: callback,
      callbackArgs: callbackArgs,
    );
    return true;
  }

  void _applyStyles() {
    for (final entry in _nodes.entries.toList()) {
      final classes = _nodeClasses[entry.key] ?? const [];
      var node = entry.value;
      NodeStyle? resolved = _classDefs['default'];
      for (final className in classes) {
        if (_classDefs[className] case final style?) {
          resolved = _mergeNodeStyle(resolved, style);
        }
      }
      if (_pendingNodeStyles[entry.key] case final style?) {
        resolved = _mergeNodeStyle(resolved, style);
      }
      if (resolved != null || classes.isNotEmpty) {
        node = node.copyWith(style: resolved, className: classes.join(' '));
      }
      _nodes[entry.key] = node;
    }
    for (var index = 0; index < _edges.length; index++) {
      final edge = _edges[index];
      if (edge.className == null) continue;
      EdgeStyle? resolved = edge.style;
      for (final className in edge.className!.split(RegExp(r'\s+'))) {
        final source = _classStyleSources[className];
        if (source != null) {
          resolved = _mergeEdgeStyle(resolved, _edgeStyle(source));
        }
      }
      if (resolved != null) _edges[index] = edge.copyWith(style: resolved);
    }
  }

  void _trackNode(String id) {
    for (final state in _subgraphStack) {
      if (!state.nodeIds.contains(id)) state.nodeIds.add(id);
    }
  }

  bool _isSubgraph(String id) =>
      _subgraphs.any((item) => item.id == id) ||
      _subgraphStack.any((item) => item.id == id);

  bool _isRicher(MermaidNode candidate, MermaidNode existing) =>
      (existing.label == existing.id && candidate.label != candidate.id) ||
      (existing.shape == NodeShape.rectangle &&
          candidate.shape != NodeShape.rectangle) ||
      candidate.attributes.isNotEmpty;

  DiagramDirection? _directionFrom(String? value) =>
      switch (value?.toUpperCase()) {
        'TB' || 'TD' => DiagramDirection.topToBottom,
        'BT' => DiagramDirection.bottomToTop,
        'LR' => DiagramDirection.leftToRight,
        'RL' => DiagramDirection.rightToLeft,
        _ => null,
      };

  ArrowType _arrowType(String token) {
    if (token.contains('x')) return ArrowType.cross;
    if (token.contains('o')) return ArrowType.circle;
    if (token.contains('>')) return ArrowType.arrow;
    return ArrowType.none;
  }

  ArrowType? _sourceArrowType(String token) {
    if (token.startsWith('<')) return ArrowType.arrow;
    if (token.startsWith('x')) return ArrowType.cross;
    if (token.startsWith('o')) return ArrowType.circle;
    return null;
  }

  LineType _lineType(String token) {
    if (token.contains('=')) return LineType.thick;
    if (token.contains('.')) return LineType.dotted;
    return LineType.solid;
  }

  int _edgeLength(String token) {
    if (token.contains('~')) return 1;
    if (token.contains('.')) {
      return ('.'.allMatches(token).length - 1).clamp(1, 100);
    }
    final count = token.contains('=')
        ? '='.allMatches(token).length
        : '-'.allMatches(token).length;
    return (count - 1).clamp(1, 100);
  }

  NodeShape? _shape(String source) => _shapeAliases[source.toLowerCase()];

  String _cleanLabel(String source) {
    var value = source.trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    if (value.startsWith('`') && value.endsWith('`')) {
      value = value.substring(1, value.length - 1);
    }
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  }

  Map<String, Object?> _decodeObject(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      decoded = loadYaml(source);
    }
    if (decoded is! Map) throw const FormatException('Expected object');
    return decoded.map((key, value) => MapEntry(key.toString(), _plain(value)));
  }

  Object? _plain(Object? value) {
    if (value is Map) {
      return value.map((key, child) => MapEntry(key.toString(), _plain(child)));
    }
    if (value is List) return value.map(_plain).toList(growable: false);
    return value;
  }

  NodeStyle _nodeStyle(String source) {
    final values = _styleProperties(source);
    return NodeStyle(
      fillColor: _color(values['fill']),
      strokeColor: _color(values['stroke']),
      strokeWidth: _number(values['stroke-width']) ?? 1,
      textColor: _color(values['color']),
      fontSize: _number(values['font-size']) ?? 14,
    );
  }

  EdgeStyle _edgeStyle(String source) {
    final values = _styleProperties(source);
    return EdgeStyle(
      strokeColor: _color(values['stroke']),
      strokeWidth: _number(values['stroke-width']) ?? 1.5,
      labelColor: _color(values['color']),
      dashPattern: values['stroke-dasharray']
          ?.split(RegExp(r'[\s,]+'))
          .map(double.tryParse)
          .whereType<double>()
          .toList(),
    );
  }

  SubgraphStyle _subgraphStyle(String source) {
    final values = _styleProperties(source);
    return SubgraphStyle(
      backgroundColor: _color(values['fill']),
      borderColor: _color(values['stroke']),
      borderWidth: _number(values['stroke-width']) ?? 1,
    );
  }

  Map<String, String> _styleProperties(String source) {
    final result = <String, String>{};
    final pattern = RegExp(
      r'([A-Za-z-]+)\s*:\s*(.*?)(?=,\s*[A-Za-z-]+\s*:|$)',
    );
    for (final property in pattern.allMatches(source.trim())) {
      result[property.group(1)!.trim()] = property.group(2)!.trim();
    }
    return result;
  }

  String? _property(String source, String key) => _styleProperties(source)[key];

  NodeStyle _mergeNodeStyle(NodeStyle? base, NodeStyle overlay) => NodeStyle(
    fillColor: overlay.fillColor ?? base?.fillColor,
    strokeColor: overlay.strokeColor ?? base?.strokeColor,
    strokeWidth: overlay.strokeWidth,
    textColor: overlay.textColor ?? base?.textColor,
    fontSize: overlay.fontSize,
    fontWeight: overlay.fontWeight ?? base?.fontWeight,
    borderRadius: overlay.borderRadius,
  );

  EdgeStyle _mergeEdgeStyle(EdgeStyle? base, EdgeStyle overlay) => EdgeStyle(
    strokeColor: overlay.strokeColor ?? base?.strokeColor,
    strokeWidth: overlay.strokeWidth,
    labelColor: overlay.labelColor ?? base?.labelColor,
    labelFontSize: overlay.labelFontSize,
    labelBackgroundColor:
        overlay.labelBackgroundColor ?? base?.labelBackgroundColor,
    dashPattern: overlay.dashPattern ?? base?.dashPattern,
  );

  int? _color(String? source) {
    if (source == null || source == 'none') return null;
    final value = source.trim();
    if (value.startsWith('#')) {
      var hex = value.substring(1);
      if (hex.length == 3) {
        hex = hex.split('').map((item) => '$item$item').join();
      }
      if (hex.length == 6) hex = 'FF$hex';
      return int.tryParse(hex, radix: 16);
    }
    return _namedColors[value.toLowerCase()];
  }

  double? _number(String? source) => source == null
      ? null
      : double.tryParse(source.replaceAll(RegExp(r'px$'), '').trim());

  bool? _bool(Object? value) => switch (value) {
    bool value => value,
    String value when value.toLowerCase() == 'true' => true,
    String value when value.toLowerCase() == 'false' => false,
    _ => null,
  };

  List<String> _quotedWords(String source) {
    final result = <String>[];
    final matches = RegExp(
      r'"([^"]*)"|\x27([^\x27]*)\x27|(\S+)',
    ).allMatches(source);
    for (final match in matches) {
      result.add(match.group(1) ?? match.group(2) ?? match.group(3)!);
    }
    return result;
  }

  String _normalizeInlineEdgeLabels(String source) {
    var value = source;
    value = value.replaceAllMapped(
      RegExp(r'<--\s+(.+?)\s+(-{2,}>)', caseSensitive: false),
      (match) => '<${match.group(2)}|${match.group(1)}|',
    );
    value = value.replaceAllMapped(
      RegExp(r'<==\s+(.+?)\s+(={2,}>)'),
      (match) => '<${match.group(2)}|${match.group(1)}|',
    );
    value = value.replaceAllMapped(
      RegExp(r'<-\.\s+(.+?)\s+(\.+->)'),
      (match) => '<-${match.group(2)}|${match.group(1)}|',
    );
    value = value.replaceAllMapped(
      RegExp(r'--\s+(.+?)\s+(-{2,}>)', caseSensitive: false),
      (match) => '${match.group(2)}|${match.group(1)}|',
    );
    value = value.replaceAllMapped(
      RegExp(r'==\s+(.+?)\s+==>'),
      (match) => '==>|${match.group(1)}|',
    );
    value = value.replaceAllMapped(
      RegExp(r'-\.\s+(.+?)\s+\.->'),
      (match) => '-.->|${match.group(1)}|',
    );
    value = value.replaceAllMapped(
      RegExp(r'--\s+(.+?)\s+---'),
      (match) => '---|${match.group(1)}|',
    );
    return value;
  }

  Iterable<String> _splitStatements(String source) sync* {
    var quote = '';
    var escaped = false;
    var braces = 0;
    var start = 0;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if ((char == '"' || char == "'" || char == '`') &&
          (quote.isEmpty || quote == char)) {
        quote = quote.isEmpty ? char : '';
      } else if (quote.isEmpty && char == '{') {
        braces++;
      } else if (quote.isEmpty && char == '}') {
        braces--;
      } else if (quote.isEmpty && braces == 0 && char == ';') {
        final value = source.substring(start, index).trim();
        if (value.isNotEmpty) yield value;
        start = index + 1;
      }
    }
    final value = source.substring(start).trim();
    if (value.isNotEmpty) yield value;
  }

  Iterable<String> _joinMarkdownStatements(List<String> lines) sync* {
    String? pending;
    for (final line in lines) {
      final value = pending == null ? line : '$pending\n$line';
      if ('`'.allMatches(value).length.isOdd) {
        pending = value;
      } else {
        yield value;
        pending = null;
      }
    }
    if (pending != null) yield pending;
  }

  List<String> _splitOutside(String source, String delimiter) {
    final result = <String>[];
    var quote = '';
    var depth = 0;
    var start = 0;
    for (var index = 0; index < source.length; index++) {
      final char = source[index];
      if ((char == '"' || char == "'" || char == '`') &&
          (quote.isEmpty || quote == char)) {
        quote = quote.isEmpty ? char : '';
      } else if (quote.isEmpty && '([{'.contains(char)) {
        depth++;
      } else if (quote.isEmpty && ')]}'.contains(char)) {
        depth--;
      } else if (quote.isEmpty && depth == 0 && char == delimiter) {
        result.add(source.substring(start, index));
        start = index + 1;
      }
    }
    result.add(source.substring(start));
    return result;
  }

  static final RegExp _edgePattern = RegExp(
    r'\s*(?:([A-Za-z0-9_][\w-]*)@)?((?:<)?(?:o|x)?(?:-{2,}|={2,}|-\.+-|~{3,})(?:>|o|x)?)(?:\|([^|]*)\|)?\s*',
  );

  static const Map<String, int> _namedColors = {
    'red': 0xFFFF0000,
    'green': 0xFF008000,
    'blue': 0xFF0000FF,
    'white': 0xFFFFFFFF,
    'black': 0xFF000000,
    'yellow': 0xFFFFFF00,
    'orange': 0xFFFFA500,
    'purple': 0xFF800080,
    'pink': 0xFFFFC0CB,
    'cyan': 0xFF00FFFF,
    'gray': 0xFF808080,
    'grey': 0xFF808080,
    'transparent': 0x00000000,
  };

  static const Map<String, NodeShape> _shapeAliases = {
    'rect': NodeShape.rectangle,
    'proc': NodeShape.rectangle,
    'process': NodeShape.rectangle,
    'rectangle': NodeShape.rectangle,
    'rounded': NodeShape.roundedRect,
    'event': NodeShape.roundedRect,
    'stadium': NodeShape.stadium,
    'terminal': NodeShape.stadium,
    'pill': NodeShape.stadium,
    'fr-rect': NodeShape.subroutine,
    'subprocess': NodeShape.subroutine,
    'subproc': NodeShape.subroutine,
    'subroutine': NodeShape.subroutine,
    'cyl': NodeShape.cylinder,
    'db': NodeShape.cylinder,
    'database': NodeShape.cylinder,
    'cylinder': NodeShape.cylinder,
    'datastore': NodeShape.datastore,
    'data-store': NodeShape.datastore,
    'circle': NodeShape.circle,
    'circ': NodeShape.circle,
    'bang': NodeShape.bang,
    'cloud': NodeShape.cloud,
    'diam': NodeShape.diamond,
    'decision': NodeShape.diamond,
    'diamond': NodeShape.diamond,
    'question': NodeShape.diamond,
    'hex': NodeShape.hexagon,
    'hexagon': NodeShape.hexagon,
    'prepare': NodeShape.hexagon,
    'lean-r': NodeShape.parallelogram,
    'lean-right': NodeShape.parallelogram,
    'in-out': NodeShape.parallelogram,
    'lean-l': NodeShape.parallelogramAlt,
    'lean-left': NodeShape.parallelogramAlt,
    'out-in': NodeShape.parallelogramAlt,
    'trap-b': NodeShape.trapezoid,
    'priority': NodeShape.trapezoid,
    'trapezoid': NodeShape.trapezoid,
    'trap-t': NodeShape.trapezoidAlt,
    'manual': NodeShape.trapezoidAlt,
    'inv-trapezoid': NodeShape.trapezoidAlt,
    'dbl-circ': NodeShape.doubleCircle,
    'double-circle': NodeShape.doubleCircle,
    'text': NodeShape.textBlock,
    'notch-rect': NodeShape.notchedRectangle,
    'card': NodeShape.notchedRectangle,
    'lin-rect': NodeShape.linedRectangle,
    'lined-process': NodeShape.linedRectangle,
    'sm-circ': NodeShape.smallCircle,
    'start': NodeShape.smallCircle,
    'fr-circ': NodeShape.framedCircle,
    'stop': NodeShape.framedCircle,
    'framed-circle': NodeShape.framedCircle,
    'fork': NodeShape.forkJoin,
    'join': NodeShape.forkJoin,
    'hourglass': NodeShape.hourglass,
    'collate': NodeShape.hourglass,
    'brace': NodeShape.braceLeft,
    'comment': NodeShape.braceLeft,
    'brace-l': NodeShape.braceLeft,
    'brace-r': NodeShape.braceRight,
    'braces': NodeShape.braces,
    'bolt': NodeShape.lightningBolt,
    'com-link': NodeShape.lightningBolt,
    'doc': NodeShape.document,
    'document': NodeShape.document,
    'delay': NodeShape.delay,
    'h-cyl': NodeShape.horizontalCylinder,
    'das': NodeShape.horizontalCylinder,
    'lin-cyl': NodeShape.linedCylinder,
    'disk': NodeShape.linedCylinder,
    'curv-trap': NodeShape.curvedTrapezoid,
    'display': NodeShape.curvedTrapezoid,
    'div-rect': NodeShape.dividedRectangle,
    'div-proc': NodeShape.dividedRectangle,
    'tri': NodeShape.triangle,
    'extract': NodeShape.triangle,
    'win-pane': NodeShape.windowPane,
    'internal-storage': NodeShape.windowPane,
    'f-circ': NodeShape.filledCircle,
    'junction': NodeShape.filledCircle,
    'notch-pent': NodeShape.notchedPentagon,
    'loop-limit': NodeShape.notchedPentagon,
    'flip-tri': NodeShape.flippedTriangle,
    'manual-file': NodeShape.flippedTriangle,
    'sl-rect': NodeShape.slopedRectangle,
    'manual-input': NodeShape.slopedRectangle,
    'docs': NodeShape.multiDocument,
    'documents': NodeShape.multiDocument,
    'st-rect': NodeShape.multiProcess,
    'procs': NodeShape.multiProcess,
    'processes': NodeShape.multiProcess,
    'bow-rect': NodeShape.bowTieRectangle,
    'stored-data': NodeShape.bowTieRectangle,
    'cross-circ': NodeShape.crossedCircle,
    'summary': NodeShape.crossedCircle,
    'tag-doc': NodeShape.taggedDocument,
    'tagged-document': NodeShape.taggedDocument,
    'tag-rect': NodeShape.taggedRectangle,
    'tag-proc': NodeShape.taggedRectangle,
    'flag': NodeShape.paperTape,
    'paper-tape': NodeShape.paperTape,
    'odd': NodeShape.odd,
    'lin-doc': NodeShape.linedDocument,
    'lined-document': NodeShape.linedDocument,
  };
}

class _FlowSubgraphState {
  _FlowSubgraphState({required this.id, required this.label, this.parentId});
  final String id;
  final String label;
  final String? parentId;
  final List<String> nodeIds = [];
  DiagramDirection? direction;
  SubgraphStyle? style;
}
