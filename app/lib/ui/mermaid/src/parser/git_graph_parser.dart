/*
 * [INPUT]: Depends on Mermaid 11.16.0 GitGraph Langium grammar and native GitGraph plus shared graph models.
 * [OUTPUT]: Strictly executes commit, branch/order, checkout/switch, merge attributes, cherry-pick validation, direction, title, and accessibility syntax into a typed DAG.
 * [POS]: Serves as the lossless native GitGraph parser and rejects invalid repository operations instead of inventing state.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../models/diagram.dart';
import '../models/edge.dart';
import '../models/git_graph.dart';
import '../models/node.dart';

class NativeGitGraphDiagramParser {
  const NativeGitGraphDiagramParser();

  (MermaidDiagramData, GitGraphChartData)? parse(
    List<String> lines, {
    String mainBranchName = 'main',
    double mainBranchOrder = 0,
  }) {
    final header = lines.indexWhere(
      (line) => _commentless(line).trim().isNotEmpty,
    );
    if (header < 0) return null;
    final headerMatch = RegExp(
      r'^\s*gitGraph(?:\s+(LR|TB|BT))?\s*:?[\s]*$',
      caseSensitive: false,
    ).firstMatch(_commentless(lines[header]));
    if (headerMatch == null) return null;
    var direction = _direction(headerMatch.group(1));
    final branches = <String, GitBranchData>{
      mainBranchName: GitBranchData(
        name: mainBranchName,
        creationIndex: 0,
        order: mainBranchOrder.toInt(),
        head: null,
      ),
    };
    final commits = <String, GitCommitData>{};
    final commands = <GitGraphCommandData>[];
    var currentBranch = mainBranchName;
    var sequence = 0;
    String? title;
    String? accessibilityTitle;
    String? accessibilityDescription;
    var index = header + 1;
    while (index < lines.length) {
      final line = _commentless(
        lines[index++],
      ).trim().replaceFirst(RegExp(r';\s*$'), '');
      if (line.isEmpty || line == '---') continue;
      final lower = line.toLowerCase();
      if (lower.startsWith('title ')) {
        title = line.substring(6).trim();
        continue;
      }
      if (lower.startsWith('acctitle:')) {
        accessibilityTitle = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      if (lower.startsWith('accdescr:')) {
        accessibilityDescription = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      final inlineDescription = RegExp(
        r'^accDescr\s*\{(.*)\}\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (inlineDescription != null) {
        accessibilityDescription = inlineDescription.group(1)!.trim();
        continue;
      }
      if (RegExp(r'^accDescr\s*\{$', caseSensitive: false).hasMatch(line)) {
        final values = <String>[];
        var closed = false;
        while (index < lines.length) {
          final value = lines[index++].trim();
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
      final branch = RegExp(
        r'^branch\s+("[^"]+"|[^\s]+)(?:\s+order\s*:\s*(-?\d+))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (branch != null) {
        final name = _unquote(branch.group(1)!);
        if (branches.containsKey(name)) return null;
        branches[name] = GitBranchData(
          name: name,
          creationIndex: branches.length,
          order: int.tryParse(branch.group(2) ?? ''),
          head: branches[currentBranch]!.head,
        );
        currentBranch = name;
        commands.add(
          GitGraphCommandData(
            index: commands.length,
            kind: GitGraphCommandKind.branch,
            raw: line,
            branch: name,
          ),
        );
        continue;
      }
      final checkout = RegExp(
        r'^(checkout|switch)\s+("[^"]+"|[^\s]+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (checkout != null) {
        final name = _unquote(checkout.group(2)!);
        if (!branches.containsKey(name)) return null;
        currentBranch = name;
        commands.add(
          GitGraphCommandData(
            index: commands.length,
            kind: GitGraphCommandKind.checkout,
            raw: line,
            branch: name,
          ),
        );
        continue;
      }
      final commit = RegExp(
        r'^commit(?:\s+(.*))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (commit != null) {
        final attributes = _attributes(
          commit.group(1) ?? '',
          allowMessageShorthand: true,
          allowed: const {'id', 'msg', 'tag', 'type'},
        );
        if (attributes == null) return null;
        final customId = attributes.single['id'];
        final id = customId ?? 'commit_$sequence';
        if (commits.containsKey(id)) return null;
        final kind =
            _commitKind(attributes.single['type']) ?? GitCommitKind.normal;
        if (attributes.single.containsKey('type') &&
            _commitKind(attributes.single['type']) == null) {
          return null;
        }
        final parent = branches[currentBranch]!.head;
        final value = GitCommitData(
          id: id,
          sequence: sequence++,
          message: attributes.single['msg'] ?? '',
          kind: kind,
          tags: attributes.tags,
          parents: [?parent],
          branch: currentBranch,
          customId: customId != null,
        );
        commits[id] = value;
        branches[currentBranch] = branches[currentBranch]!.copyWith(head: id);
        commands.add(
          GitGraphCommandData(
            index: commands.length,
            kind: GitGraphCommandKind.commit,
            raw: line,
            branch: currentBranch,
            commitId: id,
          ),
        );
        continue;
      }
      final merge = RegExp(
        r'^merge\s+("[^"]+"|[^\s]+)(?:\s+(.*))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (merge != null) {
        final sourceBranch = _unquote(merge.group(1)!);
        final attributes = _attributes(
          merge.group(2) ?? '',
          allowed: const {'id', 'tag', 'type'},
        );
        if (attributes == null ||
            sourceBranch == currentBranch ||
            !branches.containsKey(sourceBranch)) {
          return null;
        }
        final currentHead = branches[currentBranch]!.head;
        final sourceHead = branches[sourceBranch]!.head;
        if (currentHead == null ||
            sourceHead == null ||
            currentHead == sourceHead) {
          return null;
        }
        final customId = attributes.single['id'];
        final id = customId ?? 'merge_$sequence';
        if (commits.containsKey(id)) return null;
        final customKind = _commitKind(attributes.single['type']);
        if (attributes.single.containsKey('type') && customKind == null) {
          return null;
        }
        commits[id] = GitCommitData(
          id: id,
          sequence: sequence++,
          message: 'merged branch $sourceBranch into $currentBranch',
          kind: GitCommitKind.merge,
          tags: attributes.tags,
          parents: [currentHead, sourceHead],
          branch: currentBranch,
          customKind: customKind,
          customId: customId != null,
        );
        branches[currentBranch] = branches[currentBranch]!.copyWith(head: id);
        commands.add(
          GitGraphCommandData(
            index: commands.length,
            kind: GitGraphCommandKind.merge,
            raw: line,
            branch: sourceBranch,
            commitId: id,
          ),
        );
        continue;
      }
      final cherryPick = RegExp(
        r'^cherry-pick(?:\s+(.*))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (cherryPick != null) {
        final attributes = _attributes(
          cherryPick.group(1) ?? '',
          allowed: const {'id', 'tag', 'parent'},
        );
        if (attributes == null) return null;
        final sourceId = attributes.single['id'];
        final source = sourceId == null ? null : commits[sourceId];
        final currentHead = branches[currentBranch]!.head;
        final parent = attributes.single['parent'];
        if (source == null ||
            currentHead == null ||
            source.branch == currentBranch) {
          return null;
        }
        if (source.kind == GitCommitKind.merge &&
            (parent == null || !source.parents.contains(parent))) {
          return null;
        }
        if (source.kind != GitCommitKind.merge &&
            parent != null &&
            !source.parents.contains(parent)) {
          return null;
        }
        final id = 'cherry_pick_$sequence';
        final tags = attributes.tags.isEmpty
            ? ['cherry-pick:$sourceId${parent == null ? '' : '|parent:$parent'}']
            : attributes.tags;
        commits[id] = GitCommitData(
          id: id,
          sequence: sequence++,
          message: 'cherry-picked ${source.message} into $currentBranch',
          kind: GitCommitKind.cherryPick,
          tags: tags,
          parents: [currentHead, sourceId!],
          branch: currentBranch,
          cherryPickedFrom: sourceId,
          cherryPickParent: parent,
        );
        branches[currentBranch] = branches[currentBranch]!.copyWith(head: id);
        commands.add(
          GitGraphCommandData(
            index: commands.length,
            kind: GitGraphCommandKind.cherryPick,
            raw: line,
            branch: currentBranch,
            commitId: id,
          ),
        );
        continue;
      }
      return null;
    }
    final orderedCommits = commits.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return (
      MermaidDiagramData(
        type: DiagramType.gitGraph,
        nodes: [
          for (final commit in orderedCommits)
            MermaidNode(
              id: commit.id,
              label: [
                commit.id,
                if (commit.message.isNotEmpty) commit.message,
                ...commit.tags,
              ].join('\n'),
              shape: commit.kind == GitCommitKind.highlight
                  ? NodeShape.rectangle
                  : NodeShape.circle,
            ),
        ],
        edges: [
          for (final commit in orderedCommits)
            for (final parent in commit.parents)
              MermaidEdge(from: parent, to: commit.id),
        ],
        direction: _diagramDirection(direction),
        title: title,
      ),
      GitGraphChartData(
        direction: direction,
        branches: branches.values.toList(),
        commits: orderedCommits,
        commands: commands,
        currentBranch: currentBranch,
        title: title,
        accessibilityTitle: accessibilityTitle,
        accessibilityDescription: accessibilityDescription,
        mainBranchName: mainBranchName,
        mainBranchOrder: mainBranchOrder,
      ),
    );
  }

  ({Map<String, String> single, List<String> tags})? _attributes(
    String source, {
    required Set<String> allowed,
    bool allowMessageShorthand = false,
  }) {
    final single = <String, String>{};
    final tags = <String>[];
    var rest = source.trim();
    while (rest.isNotEmpty) {
      final shorthand = allowMessageShorthand
          ? RegExp(r'^"([^"]*)"(?:\s+|$)').firstMatch(rest)
          : null;
      if (shorthand != null) {
        if (single.containsKey('msg')) return null;
        single['msg'] = shorthand.group(1)!;
        rest = rest.substring(shorthand.end).trim();
        continue;
      }
      final match = RegExp(
        r'^(id|msg|tag|type|parent)\s*:\s*(?:"([^"]*)"|(\S+))(?:\s+|$)',
        caseSensitive: false,
      ).firstMatch(rest);
      if (match == null) return null;
      final key = match.group(1)!.toLowerCase();
      if (!allowed.contains(key)) return null;
      final value = match.group(2) ?? match.group(3)!;
      if (key == 'tag') {
        tags.add(value);
      } else {
        if (single.containsKey(key)) return null;
        single[key] = value;
      }
      rest = rest.substring(match.end).trim();
    }
    return (single: single, tags: tags);
  }

  GitCommitKind? _commitKind(String? value) => switch (value?.toUpperCase()) {
    'NORMAL' => GitCommitKind.normal,
    'REVERSE' => GitCommitKind.reverse,
    'HIGHLIGHT' => GitCommitKind.highlight,
    _ => null,
  };
  GitGraphDirection _direction(String? value) => switch (value?.toUpperCase()) {
    'TB' => GitGraphDirection.topToBottom,
    'BT' => GitGraphDirection.bottomToTop,
    _ => GitGraphDirection.leftToRight,
  };
  DiagramDirection _diagramDirection(GitGraphDirection value) =>
      switch (value) {
        GitGraphDirection.leftToRight => DiagramDirection.leftToRight,
        GitGraphDirection.topToBottom => DiagramDirection.topToBottom,
        GitGraphDirection.bottomToTop => DiagramDirection.bottomToTop,
      };
  String _unquote(String value) => value.startsWith('"') && value.endsWith('"')
      ? value.substring(1, value.length - 1)
      : value;
  String _commentless(String value) {
    var quoted = false;
    var escaped = false;
    for (var index = 0; index < value.length - 1; index++) {
      final char = value[index];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (char == '"') quoted = !quoted;
      if (!quoted && char == '%' && value[index + 1] == '%') {
        return value.substring(0, index);
      }
    }
    return value;
  }
}
