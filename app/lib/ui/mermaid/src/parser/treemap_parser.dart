/*
 * [INPUT]: Depends on native Mermaid graph and Treemap models plus Mermaid 11.16.0 indentation and value syntax.
 * [OUTPUT]: Strictly parses relative-indented sections, weighted leaves, quoted labels, accessibility metadata, class definitions, and resolved class styles.
 * [POS]: Serves as the dedicated parser for official Mermaid Treemap diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/node.dart';
import '../models/treemap.dart';

class TreemapDiagramParser {
  const TreemapDiagramParser();

  (MermaidDiagramData, TreemapChartData)? parse(List<String> lines) {
    final header = lines.indexWhere((line) {
      final value = _stripComment(line).trim().toLowerCase();
      return value == 'treemap' || value == 'treemap-beta';
    });
    if (header < 0 ||
        lines
            .take(header)
            .any((line) => _stripComment(line).trim().isNotEmpty)) {
      return null;
    }
    final roots = <TreemapNode>[];
    final stack = <(int, TreemapNode)>[];
    final classes = <String, Map<String, String>>{};
    final declarations = <_TreemapDeclaration>[];
    final graphNodes = <MermaidNode>[];
    var index = 0;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var readingDescription = false;
    final descriptionLines = <String>[];

    for (final rawLine in lines.skip(header + 1)) {
      final uncommented = _stripComment(rawLine);
      final trimmed = uncommented.trim();
      if (readingDescription) {
        final closing = trimmed.indexOf('}');
        if (closing >= 0) {
          if (closing > 0) descriptionLines.add(trimmed.substring(0, closing));
          if (trimmed.substring(closing + 1).trim().isNotEmpty) return null;
          readingDescription = false;
          accessibilityDescription = descriptionLines.join('\n').trim();
        } else {
          descriptionLines.add(trimmed);
        }
        continue;
      }
      if (trimmed.isEmpty) continue;
      if (trimmed == 'title' || trimmed.startsWith('title ')) {
        title = _unquote(
          trimmed.length == 5 ? '' : trimmed.substring(6).trim(),
        );
        continue;
      }
      if (trimmed.toLowerCase().startsWith('acctitle:')) {
        accessibilityTitle = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        continue;
      }
      final descriptionBlock = RegExp(
        r'^accDescr\s*\{(.*)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (descriptionBlock != null) {
        final remainder = descriptionBlock.group(1)!;
        final closing = remainder.indexOf('}');
        descriptionLines.clear();
        if (closing >= 0) {
          if (remainder.substring(closing + 1).trim().isNotEmpty) return null;
          accessibilityDescription = remainder.substring(0, closing).trim();
        } else {
          readingDescription = true;
          if (remainder.trim().isNotEmpty) {
            descriptionLines.add(remainder.trim());
          }
        }
        continue;
      }
      if (trimmed.toLowerCase().startsWith('accdescr:')) {
        accessibilityDescription = trimmed
            .substring(trimmed.indexOf(':') + 1)
            .trim();
        continue;
      }
      final classDef = RegExp(
        r'^classDef\s+([A-Za-z_]\w*)\s*(.*?);?$',
      ).firstMatch(trimmed);
      if (classDef != null) {
        classes[classDef.group(1)!] = _styles(classDef.group(2)!);
        continue;
      }
      final match = RegExp(
        r'''^("[^"]*"|'[^']*')(?:\s*[:,]\s*([0-9_.,]+))?(?:\:\:\:([A-Za-z_]\w*))?\s*;?$''',
      ).firstMatch(trimmed);
      if (match == null) return null;
      final value = match.group(2) == null
          ? null
          : double.tryParse(match.group(2)!.replaceAll(RegExp(r'[_,]'), ''));
      if (match.group(2) != null && value == null) return null;
      final leading = uncommented.substring(
        0,
        uncommented.length - uncommented.trimLeft().length,
      );
      declarations.add(
        _TreemapDeclaration(
          indent: leading.replaceAll('\t', '    ').length,
          label: _unquote(match.group(1)!),
          value: value,
          className: match.group(3),
        ),
      );
    }
    if (readingDescription) return null;
    for (final declaration in declarations) {
      final styles = declaration.className == null
          ? const <String, String>{}
          : classes[declaration.className];
      if (styles == null) return null;
      final node = TreemapNode(
        label: declaration.label,
        value: declaration.value,
        className: declaration.className,
        fillColor: styles['fill'],
        textColor: styles['color'],
        strokeColor: styles['stroke'],
        strokeWidth: _pixels(styles['stroke-width']),
        styles: Map.unmodifiable(styles),
      );
      while (stack.isNotEmpty && stack.last.$1 >= declaration.indent) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        roots.add(node);
      } else {
        stack.last.$2.children.add(node);
      }
      if (declaration.value == null) stack.add((declaration.indent, node));
      graphNodes.add(MermaidNode(id: 'treemap_${index++}', label: node.label));
    }
    if (roots.isEmpty) return null;
    return (
      MermaidDiagramData(
        type: DiagramType.treemap,
        nodes: graphNodes,
        edges: const [],
        title: title,
      ),
      TreemapChartData(
        roots: roots,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }
}

String _stripComment(String source) {
  var quote = '';
  for (var index = 0; index + 1 < source.length; index++) {
    final character = source[index];
    if ((character == '"' || character == "'") &&
        (quote.isEmpty || quote == character)) {
      quote = quote.isEmpty ? character : '';
      continue;
    }
    if (quote.isEmpty && source[index] == '%' && source[index + 1] == '%') {
      return source.substring(0, index);
    }
  }
  return source;
}

String _unquote(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2 &&
      ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
          (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

Map<String, String> _styles(String source) {
  final styles = <String, String>{};
  for (final item in _splitStyles(source.replaceFirst(RegExp(r';$'), ''))) {
    final separator = item.indexOf(':');
    if (separator <= 0) continue;
    styles[item.substring(0, separator).trim().toLowerCase()] = item
        .substring(separator + 1)
        .trim();
  }
  return styles;
}

List<String> _splitStyles(String source) {
  final result = <String>[];
  final buffer = StringBuffer();
  var escaped = false;
  for (final rune in source.runes) {
    final character = String.fromCharCode(rune);
    if (escaped) {
      buffer.write(character);
      escaped = false;
    } else if (character == r'\') {
      escaped = true;
    } else if (character == ',') {
      result.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(character);
    }
  }
  if (escaped) buffer.write(r'\');
  result.add(buffer.toString());
  return result;
}

double? _pixels(String? value) {
  if (value == null) return null;
  return double.tryParse(value.replaceFirst(RegExp(r'px$'), ''));
}

class _TreemapDeclaration {
  const _TreemapDeclaration({
    required this.indent,
    required this.label,
    required this.value,
    required this.className,
  });
  final int indent;
  final String label;
  final double? value;
  final String? className;
}
