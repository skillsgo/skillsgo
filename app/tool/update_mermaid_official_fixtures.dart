/*
 * [INPUT]: Depends on a pinned Mermaid source checkout's packages/mermaid/src/docs/syntax Markdown files.
 * [OUTPUT]: Generates a deterministic JSON corpus of complete official Mermaid documentation diagrams.
 * [POS]: Serves as the reproducible upstream fixture importer for native Mermaid compatibility gates.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/update_mermaid_official_fixtures.dart '
      '<mermaid-checkout> <output-json>',
    );
    exitCode = 64;
    return;
  }
  final syntaxDirectory = Directory(
    '${arguments[0]}/packages/mermaid/src/docs/syntax',
  );
  if (!syntaxDirectory.existsSync()) {
    stderr.writeln(
      'Mermaid syntax directory not found: ${syntaxDirectory.path}',
    );
    exitCode = 66;
    return;
  }
  final files =
      syntaxDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final fixtures = <Map<String, Object>>[];
  final fence = RegExp(
    r'```(?:mermaid-example|mermaid|zenuml)\s*\n([\s\S]*?)```',
  );
  for (final file in files) {
    var index = 0;
    for (final match in fence.allMatches(file.readAsStringSync())) {
      final source = match.group(1)!.trim();
      if (source.isEmpty || source.startsWith('---')) continue;
      index++;
      final filename = file.uri.pathSegments.last;
      if (filename == 'zenuml.md' &&
          source.split('\n').first.trim() != 'zenuml') {
        continue;
      }
      fixtures.add({'document': filename, 'index': index, 'source': source});
    }
  }
  final output = File(arguments[1]);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'mermaidVersion': '11.16.0', 'commit': '7c0cafcf42e76bfaf79d0cbbd12edb986612f014', 'fixtures': fixtures})}\n',
  );
  stdout.writeln('Wrote ${fixtures.length} fixtures to ${output.path}');
}
