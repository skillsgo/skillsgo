/*
 * [INPUT]: Depends on Mermaid 11.16.0 Block grammar, the native flowchart grammar for shared shapes/edges/styles, and Block grid data.
 * [OUTPUT]: Parses columns, spaces, spans, composites, common node shapes, edges, classes, and styles into native diagram and grid models.
 * [POS]: Serves as the dedicated syntax adapter for Mermaid Block diagrams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/block.dart';
import '../models/diagram.dart';
import 'flowchart_parser.dart';

class BlockDiagramParser {
  const BlockDiagramParser();

  (MermaidDiagramData, BlockChartData)? parse(List<String> lines) {
    if (lines.isEmpty ||
        !RegExp(
          r'^block(?:-beta)?\s*$',
          caseSensitive: false,
        ).hasMatch(lines.first.trim())) {
      return null;
    }
    var columns = -1;
    var compositeIndex = 0;
    final placements = <BlockPlacement>[];
    final groups = <String, BlockGroupData>{};
    final arrows = <BlockArrowData>[];
    final groupStack = <String>[];
    final flowLines = <String>['flowchart TB'];
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;

    for (var lineIndex = 1; lineIndex < lines.length; lineIndex++) {
      final raw = lines[lineIndex];
      final line = raw.trim().replaceAll(RegExp(r';\s*$'), '');
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
      final inlineDescription = RegExp(
        r'^accDescr\s*\{(.*)\}$',
        caseSensitive: false,
      ).firstMatch(line);
      if (inlineDescription != null) {
        accessibilityDescription = inlineDescription.group(1)!.trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
        final values = <String>[];
        var closed = false;
        while (++lineIndex < lines.length) {
          final value = lines[lineIndex].trim();
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
      final columnMatch = RegExp(
        r'^columns\s+(auto|\d+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (columnMatch != null) {
        final value = columnMatch.group(1)!.toLowerCase();
        final parsed = value == 'auto' ? -1 : int.parse(value);
        if (groupStack.isEmpty) {
          columns = parsed;
        } else {
          final id = groupStack.last;
          groups[id] = groups[id]!.copyWith(columns: parsed);
        }
        continue;
      }
      final spaceMatch = RegExp(
        r'^space(?::(\d+))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (spaceMatch != null) {
        placements.add(
          BlockPlacement(
            parent: groupStack.isEmpty ? null : groupStack.last,
            span: int.tryParse(spaceMatch.group(1) ?? '') ?? 1,
          ),
        );
        continue;
      }
      if (line == 'block') {
        final id = '__block_${compositeIndex++}';
        final parent = groupStack.isEmpty ? null : groupStack.last;
        groups[id] = BlockGroupData(id: id, label: '', parent: parent);
        placements.add(BlockPlacement(groupId: id, parent: parent));
        groupStack.add(id);
        flowLines.add('subgraph $id[" "]');
        continue;
      }
      if (line.startsWith('block:')) {
        final declaration = RegExp(
          r'^block:([^\s\[]+)(?:\["([^"]*)"\])?$',
        ).firstMatch(line);
        if (declaration == null) return null;
        final id = declaration.group(1)!;
        final label = declaration.group(2) ?? id;
        final parent = groupStack.isEmpty ? null : groupStack.last;
        groups[id] = BlockGroupData(id: id, label: label, parent: parent);
        placements.add(BlockPlacement(groupId: id, parent: parent));
        groupStack.add(id);
        flowLines.add('subgraph $id["$label"]');
        continue;
      }
      if (line == 'end') {
        if (groupStack.isEmpty) return null;
        groupStack.removeLast();
        flowLines.add(line);
        continue;
      }
      if (line.startsWith('classDef ') ||
          line.startsWith('class ') ||
          line.startsWith('style ')) {
        flowLines.add(line);
        continue;
      }

      final statements = _splitStatements(line);
      for (final statement in statements) {
        final spanMatch = RegExp(r':(\d+)\s*$').firstMatch(statement);
        final span = int.tryParse(spanMatch?.group(1) ?? '') ?? 1;
        var normalized = spanMatch == null
            ? statement
            : statement.substring(0, spanMatch.start).trimRight();
        final blockArrow = RegExp(
          r'^([A-Za-z_][\w.-]*)<\["([^"]*)"\]>\(([^)]*)\)$',
        ).firstMatch(normalized);
        if (blockArrow != null) {
          normalized = '${blockArrow.group(1)}["${blockArrow.group(2)}"]';
          arrows.add(
            BlockArrowData(
              nodeId: blockArrow.group(1)!,
              directions: blockArrow
                  .group(3)!
                  .split(',')
                  .map((value) => value.trim().toLowerCase())
                  .where(
                    const {'up', 'down', 'left', 'right', 'x', 'y'}.contains,
                  )
                  .toList(),
            ),
          );
        }
        flowLines.add(normalized);
        for (final match in RegExp(
          r'(?:^|\s)([A-Za-z_][\w.-]*)\s*(?=[\[({<]|$)',
        ).allMatches(normalized)) {
          final id = match.group(1)!;
          if (!placements.any((item) => item.nodeId == id)) {
            placements.add(
              BlockPlacement(
                nodeId: id,
                parent: groupStack.isEmpty ? null : groupStack.last,
                span: span,
              ),
            );
          }
        }
      }
    }

    if (groupStack.isNotEmpty) return null;
    final graph = FlowchartParser().parse(flowLines);
    if (graph == null) return null;
    final admittedIds = graph.nodes.map((node) => node.id).toSet();
    final filtered = placements
        .where(
          (item) =>
              item.isSpace || item.isGroup || admittedIds.contains(item.nodeId),
        )
        .toList();
    for (final node in graph.nodes) {
      if (!filtered.any((item) => item.nodeId == node.id)) {
        filtered.add(BlockPlacement(nodeId: node.id));
      }
    }
    final effectiveColumns = columns > 0
        ? columns
        : (filtered.where((item) => item.parent == null).isEmpty
              ? 1
              : filtered
                    .where((item) => item.parent == null)
                    .length
                    .clamp(1, 4));
    return (
      graph.copyWith(type: DiagramType.block, title: title),
      BlockChartData(
        columns: effectiveColumns,
        placements: filtered,
        groups: groups.values.toList(),
        arrows: arrows,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  List<String> _splitStatements(String line) {
    if (RegExp(r'(--|==|-\.|~~)').hasMatch(line)) return [line];
    final parts = <String>[];
    var start = 0;
    var depth = 0;
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') quoted = !quoted;
      if (!quoted && '[{(<'.contains(char)) depth++;
      if (!quoted && ']})>'.contains(char) && depth > 0) depth--;
      if (!quoted && depth == 0 && RegExp(r'\s').hasMatch(char)) {
        if (i > start) parts.add(line.substring(start, i));
        while (i + 1 < line.length && RegExp(r'\s').hasMatch(line[i + 1])) {
          i++;
        }
        start = i + 1;
      }
    }
    if (start < line.length) parts.add(line.substring(start));
    return parts.isEmpty ? [line] : parts;
  }
}
