/*
 * [INPUT]: Depends on the pinned Mermaid 11.16.0 info grammar and shared native diagram/node models.
 * [OUTPUT]: Parses info and info showInfo into a native version-label diagram.
 * [POS]: Serves as the complete syntax adapter for Mermaid's informational version diagram.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/node.dart';

class InfoDiagramParser {
  const InfoDiagramParser();

  static const mermaidVersion = '11.16.0';

  MermaidDiagramData? parse(List<String> lines) {
    if (lines.length != 1 ||
        !RegExp(
          r'^info(?:\s+showInfo)?\s*$',
          caseSensitive: false,
        ).hasMatch(lines.single.trim())) {
      return null;
    }
    return MermaidDiagramData(
      type: DiagramType.info,
      nodes: [MermaidNode(id: 'mermaid-version', label: 'v$mermaidVersion')],
      edges: const [],
    );
  }
}
