/*
 * [INPUT]: Depends on shared system vocabulary for trust, risk, metrics, and discovery collections.
 * [OUTPUT]: Provides discovery summaries, repository metadata, pages, auditable files, and risk evidence.
 * [POS]: Serves as the focused public discovery model module consumed by Discover, detail, and CLI decoding.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'system_models.dart';

class SkillSummary {
  const SkillSummary({
    required this.id,
    required this.installName,
    required this.name,
    required this.source,
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

  final String id;
  final String installName;
  final String name;
  final String source;
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
