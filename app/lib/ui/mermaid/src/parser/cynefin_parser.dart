/*
 * [INPUT]: Depends on Mermaid 11.16.0 Cynefin DSL and native diagram/Cynefin models.
 * [OUTPUT]: Parses fixed domain blocks, quoted items, titles, accessibility lines, and labeled transitions.
 * [POS]: Serves as the dedicated native parser for cynefin-beta sense-making maps.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/cynefin.dart';
import '../models/diagram.dart';

class CynefinDiagramParser {
  const CynefinDiagramParser();

  (MermaidDiagramData, CynefinChartData)? parse(List<String> lines) {
    if (lines.isEmpty ||
        !RegExp(
          r'^cynefin-beta:?$',
          caseSensitive: false,
        ).hasMatch(lines.first.trim())) {
      return null;
    }
    final items = {
      for (final name in CynefinDomainName.values) name: <String>[],
    };
    final transitions = <CynefinTransitionData>[];
    CynefinDomainName? current;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var readingDescription = false;
    final descriptionLines = <String>[];
    for (final raw in lines.skip(1)) {
      final line = raw.trim();
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
        title = line.substring(6).trim();
        current = null;
        continue;
      }
      if (line.toLowerCase().startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        current = null;
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
        readingDescription = true;
        descriptionLines.clear();
        current = null;
        continue;
      }
      if (line.toLowerCase().startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        current = null;
        continue;
      }
      final transition = RegExp(
        r'^([a-z]+)\s*-->\s*([a-z]+)(?:\s*:\s*"((?:[^"\\]|\\.)*)")?$',
      ).firstMatch(line);
      if (transition != null) {
        final from = _domain(transition.group(1)!);
        final to = _domain(transition.group(2)!);
        if (from == null || to == null) return null;
        if (from != to) {
          transitions.add(
            CynefinTransitionData(
              from: from,
              to: to,
              label: transition.group(3),
            ),
          );
        }
        current = null;
        continue;
      }
      final domain = _domain(line);
      if (domain != null) {
        current = domain;
        continue;
      }
      final item = RegExp(r'^"((?:[^"\\]|\\.)*)"$').firstMatch(line);
      if (item == null || current == null) return null;
      items[current]!.add(item.group(1)!);
    }
    return (
      MermaidDiagramData(
        type: DiagramType.cynefin,
        nodes: const [],
        edges: const [],
        title: title,
      ),
      CynefinChartData(
        domains: [
          for (final entry in items.entries)
            CynefinDomainData(name: entry.key, items: entry.value),
        ],
        transitions: transitions,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
      ),
    );
  }

  CynefinDomainName? _domain(String value) {
    for (final domain in CynefinDomainName.values) {
      if (domain.name == value.toLowerCase()) return domain;
    }
    return null;
  }
}
