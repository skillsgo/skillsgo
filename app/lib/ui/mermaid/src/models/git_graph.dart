/*
 * [INPUT]: Depends on Mermaid GitGraph directions, ordered commands, branches, commits, merge parents, cherry-picks, tags, display types, renderer configuration, and theme variables.
 * [OUTPUT]: Defines the immutable native GitGraph DAG, source-command stream, complete layout/label configuration, and Git theme scales.
 * [POS]: Serves as the GitGraph-specific semantic model alongside the shared graph projection.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
enum GitGraphDirection { leftToRight, topToBottom, bottomToTop }

enum GitCommitKind { normal, reverse, highlight, merge, cherryPick }

enum GitGraphCommandKind { commit, branch, checkout, merge, cherryPick }

class GitGraphThemeData {
  const GitGraphThemeData({
    this.branchColors = const [],
    this.inverseColors = const [],
    this.branchLabelColors = const [],
    this.lineColor,
    this.titleColor,
    this.tagLabelColor,
    this.tagLabelBackground,
    this.tagLabelBorder,
    this.tagLabelFontSize,
    this.commitLabelColor,
    this.commitLabelBackground,
    this.commitLabelFontSize,
    this.mergeColor,
  });

  final List<String?> branchColors;
  final List<String?> inverseColors;
  final List<String?> branchLabelColors;
  final String? lineColor;
  final String? titleColor;
  final String? tagLabelColor;
  final String? tagLabelBackground;
  final String? tagLabelBorder;
  final double? tagLabelFontSize;
  final String? commitLabelColor;
  final String? commitLabelBackground;
  final double? commitLabelFontSize;
  final String? mergeColor;
}

class GitBranchData {
  const GitBranchData({
    required this.name,
    required this.creationIndex,
    required this.order,
    required this.head,
  });
  final String name;
  final int creationIndex;
  final int? order;
  final String? head;

  GitBranchData copyWith({String? head}) => GitBranchData(
    name: name,
    creationIndex: creationIndex,
    order: order,
    head: head ?? this.head,
  );
}

class GitCommitData {
  const GitCommitData({
    required this.id,
    required this.sequence,
    required this.message,
    required this.kind,
    required this.tags,
    required this.parents,
    required this.branch,
    this.customKind,
    this.customId = false,
    this.cherryPickedFrom,
    this.cherryPickParent,
  });
  final String id;
  final int sequence;
  final String message;
  final GitCommitKind kind;
  final List<String> tags;
  final List<String> parents;
  final String branch;
  final GitCommitKind? customKind;
  final bool customId;
  final String? cherryPickedFrom;
  final String? cherryPickParent;
}

class GitGraphCommandData {
  const GitGraphCommandData({
    required this.index,
    required this.kind,
    required this.raw,
    this.branch,
    this.commitId,
  });
  final int index;
  final GitGraphCommandKind kind;
  final String raw;
  final String? branch;
  final String? commitId;
}

class GitGraphChartData {
  const GitGraphChartData({
    required this.direction,
    required this.branches,
    required this.commits,
    required this.commands,
    required this.currentBranch,
    this.title,
    this.accessibilityTitle,
    this.accessibilityDescription,
    this.titleTopMargin = 25,
    this.diagramPadding = 8,
    this.nodeLabelWidth = 75,
    this.nodeLabelHeight = 100,
    this.nodeLabelX = -25,
    this.nodeLabelY = 0,
    this.mainBranchName = 'main',
    this.mainBranchOrder = 0,
    this.showCommitLabel = true,
    this.showBranches = true,
    this.rotateCommitLabel = true,
    this.parallelCommits = false,
    this.arrowMarkerAbsolute = false,
    this.useMaxWidth = true,
    this.theme = const GitGraphThemeData(),
  });
  final GitGraphDirection direction;
  final List<GitBranchData> branches;
  final List<GitCommitData> commits;
  final List<GitGraphCommandData> commands;
  final String currentBranch;
  final String? title;
  final String? accessibilityTitle;
  final String? accessibilityDescription;
  final int titleTopMargin;
  final double diagramPadding;
  final double nodeLabelWidth;
  final double nodeLabelHeight;
  final double nodeLabelX;
  final double nodeLabelY;
  final String mainBranchName;
  final double mainBranchOrder;
  final bool showCommitLabel;
  final bool showBranches;
  final bool rotateCommitLabel;
  final bool parallelCommits;
  final bool arrowMarkerAbsolute;
  final bool useMaxWidth;
  final GitGraphThemeData theme;

  GitGraphChartData copyWith({
    String? title,
    int? titleTopMargin,
    double? diagramPadding,
    double? nodeLabelWidth,
    double? nodeLabelHeight,
    double? nodeLabelX,
    double? nodeLabelY,
    String? mainBranchName,
    double? mainBranchOrder,
    bool? showCommitLabel,
    bool? showBranches,
    bool? rotateCommitLabel,
    bool? parallelCommits,
    bool? arrowMarkerAbsolute,
    bool? useMaxWidth,
    GitGraphThemeData? theme,
  }) {
    return GitGraphChartData(
      direction: direction,
      branches: branches,
      commits: commits,
      commands: commands,
      currentBranch: currentBranch,
      title: title ?? this.title,
      accessibilityTitle: accessibilityTitle,
      accessibilityDescription: accessibilityDescription,
      titleTopMargin: titleTopMargin ?? this.titleTopMargin,
      diagramPadding: diagramPadding ?? this.diagramPadding,
      nodeLabelWidth: nodeLabelWidth ?? this.nodeLabelWidth,
      nodeLabelHeight: nodeLabelHeight ?? this.nodeLabelHeight,
      nodeLabelX: nodeLabelX ?? this.nodeLabelX,
      nodeLabelY: nodeLabelY ?? this.nodeLabelY,
      mainBranchName: mainBranchName ?? this.mainBranchName,
      mainBranchOrder: mainBranchOrder ?? this.mainBranchOrder,
      showCommitLabel: showCommitLabel ?? this.showCommitLabel,
      showBranches: showBranches ?? this.showBranches,
      rotateCommitLabel: rotateCommitLabel ?? this.rotateCommitLabel,
      parallelCommits: parallelCommits ?? this.parallelCommits,
      arrowMarkerAbsolute: arrowMarkerAbsolute ?? this.arrowMarkerAbsolute,
      useMaxWidth: useMaxWidth ?? this.useMaxWidth,
      theme: theme ?? this.theme,
    );
  }
}
