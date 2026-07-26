/*
 * [INPUT]: Depends on shared system vocabulary for metrics, discovery collections, and canonical Skill coordinates.
 * [OUTPUT]: Provides discovery summaries, canonical pagination, ordered Package-scoped candidate queries, canonical coordinate identity and exact Package member paths, Package metadata, pages, and auditable files.
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

  bool get isInstalled => localTargetCount > 0;

  SkillCoordinate get coordinate =>
      SkillCoordinate(packagePath: packagePath, name: name);

  String get coordinateKey => coordinate.key;

  String get installationSelector => path.isEmpty ? name : path;
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
