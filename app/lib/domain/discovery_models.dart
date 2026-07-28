/*
 * [INPUT]: Depends on shared system vocabulary for metrics, discovery collections, and canonical Skill coordinates.
 * [OUTPUT]: Provides discovery summaries with local-version install actions, canonical pagination, ordered Package-scoped candidate queries, canonical coordinate identity and exact Package member paths, Package metadata, pages, and auditable files.
 * [POS]: Serves as the focused public discovery model module consumed by Discover, detail, and CLI decoding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'system_models.dart';
import 'skill_coordinate.dart';

class SkillSummary {
  const SkillSummary({
    required this.packagePath,
    required this.installName,
    required this.name,
    this.path = '',
    this.installs = 0,
    this.imageUrl,
    this.latestVersion = 'main',
    this.description = '',
    this.metricKind,
    this.metricChange = 0,
    this.localTargetCount = 0,
    this.localVersions = const [],
  });

  final String packagePath;
  final String installName;
  final String name;
  final String path;
  final String? imageUrl;
  final int installs;
  final String latestVersion;
  final String description;
  final SkillMetricKind? metricKind;
  final int metricChange;
  final int localTargetCount;
  final List<String> localVersions;

  bool get isInstalled => localTargetCount > 0;

  InstallationVersionAction get installationVersionAction =>
      resolveInstallationVersionAction(
        targetVersion: latestVersion,
        localVersions: localVersions,
        installed: isInstalled,
      );

  SkillCoordinate get coordinate =>
      SkillCoordinate(packagePath: packagePath, name: name);

  String get coordinateKey => coordinate.key;

  /// Identifies one immutable Package member view. Unlike [coordinateKey],
  /// this changes when the user opens another version of the same Skill.
  String get versionedCoordinateKey =>
      '${coordinate.key}\u0000${latestVersion.trim()}\u0000$installationSelector';

  String get installationSelector => path.isEmpty ? name : path;
}

enum InstallationVersionAction { install, installed, upgrade, downgrade }

InstallationVersionAction resolveInstallationVersionAction({
  required String targetVersion,
  required List<String> localVersions,
  required bool installed,
}) {
  if (!installed) return InstallationVersionAction.install;
  if (localVersions.isEmpty || localVersions.contains(targetVersion)) {
    return InstallationVersionAction.installed;
  }
  final target = _stableSemanticVersion(targetVersion);
  final installedVersions = localVersions
      .map(_stableSemanticVersion)
      .toList(growable: false);
  if (target == null || installedVersions.any((version) => version == null)) {
    return InstallationVersionAction.install;
  }
  if (installedVersions.every(
    (version) => _compareVersion(version!, target) < 0,
  )) {
    return InstallationVersionAction.upgrade;
  }
  if (installedVersions.every(
    (version) => _compareVersion(version!, target) > 0,
  )) {
    return InstallationVersionAction.downgrade;
  }
  return InstallationVersionAction.install;
}

List<int>? _stableSemanticVersion(String raw) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(raw.trim());
  if (match == null) return null;
  return [
    for (var index = 1; index <= 3; index++) int.parse(match.group(index)!),
  ];
}

int _compareVersion(List<int> left, List<int> right) {
  for (var index = 0; index < 3; index++) {
    final compared = left[index].compareTo(right[index]);
    if (compared != 0) return compared;
  }
  return 0;
}

class PackageSummary {
  const PackageSummary({
    required this.id,
    this.imageUrl,
    this.description = '',
    this.stars = 0,
    this.latestVersion = '',
    this.updatedAt,
  });

  final String id;
  final String? imageUrl;
  final String description;
  final int stars;
  final String latestVersion;
  final DateTime? updatedAt;
}

class DiscoveryPage {
  const DiscoveryPage({
    required this.skills,
    this.pagination = const Pagination(),
    this.module,
  });

  final List<SkillSummary> skills;
  final Pagination pagination;
  final PackageSummary? module;
}

class Pagination {
  const Pagination({this.page = 0, this.perPage = 20, this.hasMore = false});

  final int page;
  final int perPage;
  final bool hasMore;

  int? get nextPage => hasMore ? page + 1 : null;
}

class PackageFindQuery {
  const PackageFindQuery({required this.name, this.packagePath = ''});

  final String name;
  final String packagePath;
}

class SkillFile {
  const SkillFile({
    required this.path,
    required this.contents,
    this.size = 0,
    this.kind = 'text',
    this.executable = false,
    this.binary = false,
    this.truncated = false,
  });

  final String path;
  final String contents;
  final int size;
  final String kind;
  final bool executable;
  final bool binary;
  final bool truncated;
}
