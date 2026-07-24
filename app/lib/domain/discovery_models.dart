/*
 * [INPUT]: Depends on shared system vocabulary for trust, risk, metrics, discovery collections, and canonical Skill coordinates.
 * [OUTPUT]: Provides discovery summaries, batch Source Find queries/results, canonical coordinate identity and exact Repository member paths, repository metadata, pages, auditable files, and risk evidence.
 * [POS]: Serves as the focused public discovery model module consumed by Discover, detail, and CLI decoding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'system_models.dart';
import 'skill_coordinate.dart';

class SkillSummary {
  const SkillSummary({
    required this.repositoryId,
    required this.installName,
    required this.name,
    required this.source,
    this.skillPath = '',
    this.installs = 0,
    this.imageUrl,
    this.latestVersion = 'main',
    this.description = '',
    this.trustLevel = SkillTrustLevel.unverified,
    this.riskAssessment = SkillRiskAssessment.unknown,
    this.metricKind,
    this.metricChange = 0,
    this.localTargetCount = 0,
  });

  final String repositoryId;
  final String installName;
  final String name;
  final String source;
  final String skillPath;
  final String? imageUrl;
  final int installs;
  final String latestVersion;
  final String description;
  final SkillTrustLevel trustLevel;
  final SkillRiskAssessment riskAssessment;
  final SkillMetricKind? metricKind;
  final int metricChange;
  final int localTargetCount;

  bool get isInstalled => localTargetCount > 0;

  SkillCoordinate get coordinate =>
      SkillCoordinate(repositoryId: repositoryId, name: name);

  String get coordinateKey => coordinate.key;

  String get installationSelector => skillPath.isEmpty ? name : skillPath;
}

class RepositorySummary {
  const RepositorySummary({
    required this.id,
    this.imageUrl,
    this.description = '',
    this.stars = 0,
    this.latestVersion = '',
    this.updatedAt,
    this.license,
  });

  final String id;
  final String? imageUrl;
  final String description;
  final int stars;
  final String latestVersion;
  final DateTime? updatedAt;
  final String? license;
}

class DiscoveryPage {
  const DiscoveryPage({required this.skills, this.nextOffset, this.repository});

  final List<SkillSummary> skills;
  final int? nextOffset;
  final RepositorySummary? repository;
}

class SourceFindQuery {
  const SourceFindQuery({
    required this.id,
    required this.name,
    this.source = '',
  });

  final String id;
  final String name;
  final String source;
}

class SourceFindResult {
  const SourceFindResult({required this.id, required this.skills});

  final String id;
  final List<SkillSummary> skills;
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

class SkillRiskEvidence {
  const SkillRiskEvidence({required this.code, required this.path});

  final String code;
  final String path;
}
