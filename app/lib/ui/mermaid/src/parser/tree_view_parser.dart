/*
 * [INPUT]: Depends on Mermaid 11.16.0 Tree View Langium grammar and box-drawing preprocessing rules.
 * [OUTPUT]: Strictly parses indentation/box trees, quoted names, file/directory identity, class/icon/description annotations, and accessibility metadata.
 * [POS]: Serves as the lossless native parser for treeView-beta and validates mixed or malformed tree notation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/node.dart';
import '../models/tree_view.dart';

class NativeTreeViewDiagramParser {
  const NativeTreeViewDiagramParser();

  (MermaidDiagramData, TreeViewChartData)? parse(List<String> lines) {
    final header = lines.indexWhere(
      (line) => line.trim().toLowerCase() == 'treeview-beta',
    );
    if (header < 0) return null;
    final content = lines.skip(header + 1).toList();
    final boxMode = content.any((line) => RegExp(r'[─━│┃└┗├┣]').hasMatch(line));
    final segmentWidth = _segmentWidth(content);
    final nodes = <TreeViewNodeData>[];
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var index = 0;
    while (index < content.length) {
      final original = content[index++];
      final trimmed = original.trim();
      if (trimmed.isEmpty || trimmed == '---' || trimmed.startsWith('%%')) {
        continue;
      }
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('title ')) {
        title = trimmed.substring(6).trim();
        continue;
      }
      if (lower.startsWith('acctitle:')) {
        accessibilityTitle = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        continue;
      }
      if (lower.startsWith('accdescr:')) {
        accessibilityDescription = trimmed
            .substring(trimmed.indexOf(':') + 1)
            .trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(trimmed)) {
        final values = <String>[];
        var closed = false;
        while (index < content.length) {
          final value = content[index++].trim();
          if (value == '}') {
            closed = true;
            break;
          }
          values.add(value);
        }
        if (!closed) return null;
        accessibilityDescription = values.join('\n').trim();
        continue;
      }
      var source = original.replaceAll('\t', '    ');
      late final int indentation;
      if (boxMode) {
        if (RegExp(r'^[\s│┃]+$').hasMatch(source)) continue;
        final branch = RegExp(r'[└┗├┣]').firstMatch(source);
        if (branch == null) {
          if (source.startsWith(RegExp(r'\s'))) return null;
          indentation = 0;
        } else {
          indentation = (branch.start / segmentWidth).round() + 1;
          var position = branch.end;
          while (position < source.length &&
              RegExp(r'[─━]').hasMatch(source[position])) {
            position++;
          }
          while (position < source.length && source[position] == ' ') {
            position++;
          }
          source = source.substring(position);
        }
      } else {
        indentation = source.length - source.trimLeft().length;
        source = source.trimLeft();
      }
      final parsed = _node(source.trimRight());
      if (parsed == null) return null;
      int? parent;
      for (var candidate = nodes.length - 1; candidate >= 0; candidate--) {
        if (nodes[candidate].indentation < indentation) {
          parent = candidate;
          break;
        }
      }
      nodes.add(
        TreeViewNodeData(
          index: nodes.length,
          name: parsed.name,
          kind: parsed.directory
              ? TreeViewNodeKind.directory
              : TreeViewNodeKind.file,
          indentation: indentation,
          parentIndex: parent,
          cssClass: parsed.cssClass,
          icon: parsed.icon,
          description: parsed.description,
        ),
      );
    }
    if (nodes.isEmpty) return null;
    return (
      MermaidDiagramData(
        type: DiagramType.treeView,
        nodes: [
          for (final node in nodes)
            MermaidNode(
              id: 'tree_${node.index}',
              label: [
                node.name,
                if (node.description != null) node.description!,
              ].join('\n'),
              shape: node.kind == TreeViewNodeKind.directory
                  ? NodeShape.roundedRect
                  : NodeShape.rectangle,
              className: node.cssClass,
            ),
        ],
        edges: [
          for (final node in nodes)
            if (node.parentIndex case final int parent)
              MermaidEdge(from: 'tree_$parent', to: 'tree_${node.index}'),
        ],
        direction: DiagramDirection.leftToRight,
        title: title,
      ),
      TreeViewChartData(
        nodes: nodes,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  int _segmentWidth(List<String> lines) {
    for (final original in lines) {
      final line = original.replaceAll('\t', '    ');
      final match = RegExp(r'[└┗├┣]').firstMatch(line);
      if (match != null && match.start > 0) return match.start;
    }
    return 4;
  }

  ({
    String name,
    bool directory,
    String? cssClass,
    String? icon,
    String? description,
  })?
  _node(String source) {
    String? cssClass;
    String? icon;
    String? description;
    final classMatches = RegExp(
      r'\s+:::\s*([A-Za-z_][\w-]*)',
    ).allMatches(source).toList();
    final iconMatches = RegExp(
      r'\s+icon\(([\w-]*(?::[\w-]+)?)\)',
    ).allMatches(source).toList();
    final descriptionMatches = RegExp(
      r'\s+##\s*(.*)$',
    ).allMatches(source).toList();
    if (classMatches.length > 1 ||
        iconMatches.length > 1 ||
        descriptionMatches.length > 1) {
      return null;
    }
    if (classMatches.isNotEmpty) cssClass = classMatches.single.group(1);
    if (iconMatches.isNotEmpty) {
      icon = iconMatches.single.group(1)!.isEmpty
          ? 'none'
          : iconMatches.single.group(1);
    }
    if (descriptionMatches.isNotEmpty) {
      description = descriptionMatches.single.group(1)!.trim();
    }
    final offsets = [
      ...classMatches,
      ...iconMatches,
      ...descriptionMatches,
    ].map((match) => match.start).toList();
    final end = offsets.isEmpty ? source.length : (offsets..sort()).first;
    var name = source.substring(0, end).trim();
    if ((name.startsWith('"') && name.endsWith('"')) ||
        (name.startsWith("'") && name.endsWith("'"))) {
      name = name.substring(1, name.length - 1);
    }
    if (name.isEmpty) return null;
    final directory = name.endsWith('/');
    if (directory) name = name.substring(0, name.length - 1);
    return (
      name: name,
      directory: directory,
      cssClass: cssClass,
      icon: icon,
      description: description,
    );
  }
}
