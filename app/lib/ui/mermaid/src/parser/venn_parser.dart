/*
 * [INPUT]: Depends on native Mermaid graph and Venn models plus Mermaid 11.16.0 set, union, size, label, and annotation syntax.
 * [OUTPUT]: Strictly parses validated Venn subsets, unions, explicit/indented annotations, target styles, and accessibility metadata into native chart data.
 * [POS]: Serves as the dedicated parser for official Mermaid Venn diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/venn.dart';

class VennDiagramParser {
  const VennDiagramParser();

  (MermaidDiagramData, VennChartData)? parse(List<String> lines) {
    if (lines.isEmpty || lines.first.trim().toLowerCase() != 'venn-beta') {
      return null;
    }
    final subsets = <VennSubset>[];
    final annotations = <VennAnnotation>[];
    final graphNodes = <MermaidNode>[];
    final knownSets = <String>{};
    final styles = <String, Map<String, String>>{};
    List<String>? activeSets;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var readingDescription = false;
    final descriptionLines = <String>[];
    for (final rawLine in lines.skip(1)) {
      final line = _stripComment(rawLine).trim();
      if (readingDescription) {
        if (line == '}') {
          readingDescription = false;
          accessibilityDescription = descriptionLines.join('\n').trim();
        } else {
          descriptionLines.add(line);
        }
        continue;
      }
      if (line.isEmpty) continue;
      if (line.startsWith('title ')) {
        title = _unquote(line.substring(6));
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
      final style = RegExp(
        r'^style\s+(.+?)\s+([A-Za-z_-]+\s*:.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (style != null) {
        final targets = _identifiers(style.group(1)!);
        if (targets == null || targets.isEmpty) return null;
        final values = _styles(style.group(2)!);
        if (values == null) return null;
        final setTargets = targets.where(knownSets.contains).toList()..sort();
        final key = setTargets.length == targets.length
            ? setTargets.join(',')
            : targets.length == 1
            ? targets.single
            : null;
        if (key == null) return null;
        styles[key] = {...?styles[key], ...values};
        continue;
      }
      final subset = RegExp(
        r'^(set|union)\s+(.+?)(?:\["?([^\]"]+)"?\])?(?:\s*:\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+)))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (subset != null) {
        final sets = _identifiers(subset.group(2)!);
        if (sets == null || sets.isEmpty) return null;
        if (subset.group(1)!.toLowerCase() == 'set' && sets.length != 1) {
          return null;
        }
        if (sets.length > 1 && sets.any((set) => !knownSets.contains(set))) {
          return null;
        }
        if (sets.length > 1 && sets.toSet().length < 2) return null;
        sets.sort();
        final size =
            double.tryParse(subset.group(4) ?? '') ??
            10 / (sets.length * sets.length);
        if (size < 0) return null;
        final label = subset.group(3)?.trim();
        subsets.add(VennSubset(sets: sets, size: size, label: label));
        activeSets = sets;
        if (sets.length == 1) {
          knownSets.add(sets.single);
          graphNodes.add(
            MermaidNode(id: sets.single, label: label ?? sets.single),
          );
        }
        continue;
      }
      final text = RegExp(
        r'^text\s+(.+?)(?:\["?([^\]"]+)"?\])?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (text != null) {
        final target = _textTarget(text.group(1)!);
        if (target == null) return null;
        late final List<String> targetSets;
        late final String id;
        if (target.$1 == null) {
          if (activeSets == null) return null;
          targetSets = List.of(activeSets);
          id = target.$2;
        } else {
          id = target.$2;
          targetSets = target.$1!..sort();
          if (targetSets.any((set) => !knownSets.contains(set))) return null;
        }
        annotations.add(
          VennAnnotation(
            sets: targetSets,
            id: id,
            label: text.group(2)?.trim(),
          ),
        );
        continue;
      }
      return null;
    }
    if (readingDescription) return null;
    return (
      MermaidDiagramData(
        type: DiagramType.venn,
        nodes: graphNodes,
        edges: const [],
      ),
      VennChartData(
        subsets: subsets,
        annotations: annotations,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
        styles: Map<String, Map<String, String>>.unmodifiable({
          for (final entry in styles.entries)
            entry.key: Map<String, String>.unmodifiable(entry.value),
        }),
      ),
    );
  }
}

(List<String>?, String)? _textTarget(String source) {
  var quoted = false;
  var split = -1;
  for (var index = source.length - 1; index >= 0; index--) {
    if (source[index] == '"') quoted = !quoted;
    if (!quoted && RegExp(r'\s').hasMatch(source[index])) {
      split = index;
      break;
    }
  }
  if (split < 0) {
    final id = _unquote(source);
    return id.isEmpty ? null : (null, id);
  }
  final sets = _identifiers(source.substring(0, split));
  final id = _unquote(source.substring(split + 1));
  return sets == null || sets.isEmpty || id.isEmpty ? null : (sets, id);
}

List<String>? _identifiers(String source) {
  final result = <String>[];
  for (final raw in _identifierFields(source)) {
    final value = _unquote(raw);
    if (!RegExp(r'^[\w.-]+$').hasMatch(value) &&
        !(raw.trim().startsWith('"') && raw.trim().endsWith('"'))) {
      return null;
    }
    result.add(value);
  }
  return result;
}

Iterable<String> _identifierFields(String source) sync* {
  var quoted = false;
  var escaped = false;
  var start = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '"') quoted = !quoted;
    if (!quoted && char == ',') {
      yield source.substring(start, index);
      start = index + 1;
    }
  }
  if (quoted) return;
  yield source.substring(start);
}

String _stripComment(String source) {
  var quoted = false;
  var escaped = false;
  for (var index = 0; index < source.length - 1; index++) {
    final char = source[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '"') quoted = !quoted;
    if (!quoted && char == '%' && source[index + 1] == '%') {
      return source.substring(0, index);
    }
  }
  return source;
}

String _unquote(String source) {
  final value = source.trim();
  return value.length >= 2 && value.startsWith('"') && value.endsWith('"')
      ? value.substring(1, value.length - 1)
      : value;
}

Map<String, String>? _styles(String source) {
  final result = <String, String>{};
  for (final raw in _styleFields(source)) {
    final separator = raw.indexOf(':');
    if (separator <= 0) return null;
    result[raw.substring(0, separator).trim().toLowerCase()] = _unquote(
      raw.substring(separator + 1),
    );
  }
  return result;
}

Iterable<String> _styleFields(String source) sync* {
  var depth = 0;
  var quoted = false;
  var start = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (char == '"') quoted = !quoted;
    if (!quoted && char == '(') depth++;
    if (!quoted && char == ')' && depth > 0) depth--;
    if (!quoted && depth == 0 && char == ',') {
      yield source.substring(start, index);
      start = index + 1;
    }
  }
  yield source.substring(start);
}
