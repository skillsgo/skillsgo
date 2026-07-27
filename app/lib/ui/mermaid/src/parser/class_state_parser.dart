/*
 * [INPUT]: Depends on the strict lossless native Class and State diagram parsers.
 * [OUTPUT]: Provides the original public ClassDiagramParser and StateDiagramParser graph-only compatibility facades.
 * [POS]: Preserves the vendored parser API while routing both diagram families through their complete implementations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import 'class_diagram_parser.dart';
import 'state_diagram_parser.dart';

class ClassDiagramParser {
  const ClassDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeClassDiagramParser().parse(lines)?.$1;
}

class StateDiagramParser {
  const StateDiagramParser();

  MermaidDiagramData? parse(List<String> lines) =>
      const NativeStateDiagramParser().parse(lines)?.$1;
}
