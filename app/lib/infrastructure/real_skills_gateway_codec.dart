/*
 * [INPUT]: Depends on the shared RealSkillsGateway library, Dart JSON/filesystem primitives, and App domain models.
 * [OUTPUT]: Provides centralized machine-document envelope validation, private strict CLI decoders, argument encoders, local Skill inspection, and schema invariants.
 * [POS]: Serves as the machine-protocol codec implementation inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

Map<String, dynamic> _versionedDocument(
  Object? raw, {
  required int schemaVersion,
}) {
  if (raw is! Map<String, dynamic> || raw['schemaVersion'] != schemaVersion) {
    throw const FormatException('Invalid SkillsGo versioned document.');
  }
  return raw;
}

Map<String, dynamic> _decodeVersionedDocument(
  String encoded, {
  required int schemaVersion,
}) => _versionedDocument(jsonDecode(encoded), schemaVersion: schemaVersion);

Map<String, dynamic> _machineDocument(
  Object? raw, {
  required Iterable<String> phases,
  int schemaVersion = 1,
}) {
  final document = _versionedDocument(raw, schemaVersion: schemaVersion);
  if (document['phase'] is! String || !phases.contains(document['phase'])) {
    throw const FormatException('Invalid SkillsGo machine document.');
  }
  return document;
}

Map<String, dynamic> _decodeMachineDocument(
  String encoded, {
  required String phase,
  int schemaVersion = 1,
}) => _machineDocument(
  jsonDecode(encoded),
  phases: [phase],
  schemaVersion: schemaVersion,
);

SkillTrustLevel _trustLevel(Object? value) => switch (value) {
  'unverified' => SkillTrustLevel.unverified,
  'community_verified' => SkillTrustLevel.communityVerified,
  'publisher_verified' => SkillTrustLevel.publisherVerified,
  'official' => SkillTrustLevel.official,
  'warned' => SkillTrustLevel.warned,
  'delisted' => SkillTrustLevel.delisted,
  _ => throw const SkillsException(
    'Discovery Trust Level is invalid.',
    kind: SkillsFailureKind.invalidResponse,
  ),
};

SkillRiskAssessment _riskAssessment(Object? value) => switch (value) {
  'unknown' => SkillRiskAssessment.unknown,
  'low' => SkillRiskAssessment.low,
  'medium' => SkillRiskAssessment.medium,
  'high' => SkillRiskAssessment.high,
  'critical' => SkillRiskAssessment.critical,
  _ => throw const SkillsException(
    'Discovery Risk Assessment is invalid.',
    kind: SkillsFailureKind.invalidResponse,
  ),
};

InstallationScope _installationScope(Object? value) => switch (value) {
  'user' => InstallationScope.user,
  'project' => InstallationScope.project,
  _ => throw const FormatException('Unknown installation scope.'),
};

InstallationHealth _installationHealth(Object? value) => switch (value) {
  'healthy' => InstallationHealth.healthy,
  'missing' => InstallationHealth.missing,
  'replaced' => InstallationHealth.replaced,
  'local-modification' => InstallationHealth.localModification,
  'unreadable' => InstallationHealth.unreadable,
  'undeclared' => InstallationHealth.undeclared,
  'workspace-unreadable' => InstallationHealth.workspaceUnreadable,
  'lock-mismatch' => InstallationHealth.lockMismatch,
  'unexpected-path' => InstallationHealth.unexpectedPath,
  _ => throw const FormatException('Unknown installation health.'),
};

LibraryProvenance _libraryProvenance(Object? value) => switch (value) {
  'hub' => LibraryProvenance.hub,
  'external' => LibraryProvenance.external,
  _ => throw const FormatException('Unknown Library provenance.'),
};

DiscoveryVerification _discoveryVerification(Object? value) => switch (value) {
  'verified' => DiscoveryVerification.verified,
  'unverified' => DiscoveryVerification.unverified,
  _ => throw const FormatException('Unknown discovery verification.'),
};

int _localTargetReadRank(SkillInstallationTarget target) {
  if (target.health == InstallationHealth.healthy) return 0;
  return 1;
}

const _localFilePreviewLimit = 256 * 1024;
const _inventorySchemaVersion = 6;

bool _looksExecutablePath(String path) {
  final lower = path.toLowerCase();
  const extensions = [
    '.sh',
    '.bash',
    '.zsh',
    '.fish',
    '.ps1',
    '.bat',
    '.cmd',
    '.exe',
    '.js',
    '.mjs',
    '.py',
    '.rb',
  ];
  return lower.contains('/scripts/') || extensions.any(lower.endsWith);
}

Future<List<SkillFile>> _inspectLocalFiles(String root) async {
  final files = await Directory(root)
      .list(recursive: true, followLinks: false)
      .where((entity) => entity is File)
      .cast<File>()
      .toList();
  files.sort((left, right) => left.path.compareTo(right.path));
  final result = <SkillFile>[];
  for (final file in files) {
    final relative = p.relative(file.path, from: root);
    final stat = await file.stat();
    var contents = '';
    var binary = false;
    final truncated = stat.size > _localFilePreviewLimit;
    final bytes = await file
        .openRead(0, min(stat.size, _localFilePreviewLimit))
        .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
    if (bytes.contains(0)) {
      binary = true;
    } else {
      try {
        contents = utf8.decode(bytes, allowMalformed: truncated);
      } on FormatException {
        binary = true;
      }
    }
    result.add(
      SkillFile(
        path: relative,
        contents: contents,
        size: stat.size,
        kind: relative == 'SKILL.md' ? 'instructions' : 'supporting',
        executable:
            _looksExecutablePath(relative) ||
            (!Platform.isWindows && stat.mode & 0x49 != 0),
        binary: binary,
        truncated: truncated,
      ),
    );
  }
  return List.unmodifiable(result);
}

List<String> _strictStringList(Object? value) {
  if (value is! List || value.any((item) => item is! String || item.isEmpty)) {
    throw const FormatException('Expected a string list.');
  }
  final result = value.cast<String>().toList(growable: false);
  if (result.toSet().length != result.length) {
    throw const FormatException('String lists must not contain duplicates.');
  }
  return result;
}

bool _sameStringSet(List<String> left, Iterable<String> right) {
  final rightSet = right.toSet();
  return left.length == rightSet.length && left.every(rightSet.contains);
}

int _strictNonNegativeInt(Object? value) {
  if (value is! int || value < 0) throw const FormatException();
  return value;
}

InstallationPlanTarget _installationPlanTarget(Object? raw) {
  if (raw is! Map<String, dynamic> ||
      raw['agent'] is! String ||
      (raw['agent'] as String).isEmpty ||
      raw['path'] is! String ||
      (raw['path'] as String).isEmpty ||
      (raw['projectRoot'] != null && raw['projectRoot'] is! String)) {
    throw const FormatException();
  }
  final scope = _installationScope(raw['scope']);
  final projectRoot = raw['projectRoot'] as String? ?? '';
  if ((scope == InstallationScope.user && projectRoot.isNotEmpty) ||
      (scope == InstallationScope.project && projectRoot.isEmpty)) {
    throw const FormatException();
  }
  return InstallationPlanTarget(
    scope: scope,
    projectRoot: projectRoot,
    agent: raw['agent'] as String,
    path: raw['path'] as String,
  );
}

bool _samePlanTarget(
  InstallationPlanTarget left,
  InstallationPlanTarget right,
) =>
    left.scope == right.scope &&
    left.projectRoot == right.projectRoot &&
    left.agent == right.agent &&
    left.path == right.path;

List<InstallationTargetResult> _repositoryInstallationResults(
  Object? value,
  SkillSummary skill,
  String immutableVersion,
  List<InstallationTargetSelection> selections,
) {
  final raw = _machineDocument(value, phases: const ['repository-install']);
  if (raw['repository'] != skill.repositoryId ||
      raw['version'] != immutableVersion ||
      raw['sum'] is! String ||
      (raw['sum'] as String).isEmpty ||
      raw['vendor'] is! String ||
      (raw['vendor'] as String).isEmpty ||
      raw['skills'] is! List ||
      raw['agents'] is! List ||
      raw['projections'] is! List ||
      raw['workspace'] is! Map<String, dynamic>) {
    throw const FormatException();
  }
  final expectedMember = skill.installationSelector;
  if (!_strictStringList(raw['skills']).contains(expectedMember) ||
      !_sameStringSet(
        _strictStringList(raw['agents']),
        selections.map((selection) => selection.agent),
      )) {
    throw const FormatException();
  }
  final workspace = raw['workspace'] as Map<String, dynamic>;
  if (workspace['manifest'] is! String ||
      !(workspace['manifest'] as String).endsWith('skillsgo.yaml') ||
      workspace['lock'] is! String ||
      !(workspace['lock'] as String).endsWith('skillsgo-lock.yaml')) {
    throw const FormatException();
  }
  final pathsByAgent = <String, String>{};
  for (final rawProjection in raw['projections'] as List) {
    if (rawProjection is! Map<String, dynamic> ||
        rawProjection['path'] is! String ||
        (rawProjection['path'] as String).isEmpty) {
      throw const FormatException();
    }
    for (final agent in _strictStringList(rawProjection['agents'])) {
      if (pathsByAgent.containsKey(agent)) throw const FormatException();
      pathsByAgent[agent] = rawProjection['path'] as String;
    }
  }
  return selections
      .map((selection) {
        final path = pathsByAgent[selection.agent];
        if (path == null) throw const FormatException();
        return InstallationTargetResult(
          target: InstallationPlanTarget(
            scope: selection.scope,
            projectRoot: selection.projectRoot,
            agent: selection.agent,
            path: path,
          ),
          action: InstallationPlanAction.create,
          outcome: InstallationTargetOutcome.succeeded,
        );
      })
      .toList(growable: false);
}

TargetFailure? _targetFailure(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map<String, dynamic> ||
      raw['code'] is! String ||
      (raw['code'] as String).isEmpty ||
      raw['retryable'] is! bool ||
      (raw['details'] != null && raw['details'] is! Map<String, dynamic>) ||
      (raw['requestId'] != null && raw['requestId'] is! String) ||
      (raw['diagnostic'] != null && raw['diagnostic'] is! String)) {
    throw const FormatException();
  }
  return TargetFailure(
    code: raw['code'] as String,
    retryable: raw['retryable'] as bool,
    details: Map<String, Object?>.unmodifiable(
      raw['details'] as Map<String, dynamic>? ?? const {},
    ),
    requestId: raw['requestId'] as String? ?? '',
    diagnostic: raw['diagnostic'] as String? ?? '',
  );
}

TargetManagementAction _targetManagementAction(Object? value) =>
    switch (value) {
      'remove' => TargetManagementAction.remove,
      _ => throw const FormatException(),
    };

TargetManagementOutcome _targetManagementOutcome(Object? value) =>
    switch (value) {
      'succeeded' => TargetManagementOutcome.succeeded,
      'failed' => TargetManagementOutcome.failed,
      _ => throw const FormatException(),
    };

String _targetManagementActionValue(TargetManagementAction action) =>
    switch (action) {
      TargetManagementAction.remove => 'remove',
    };

TargetManagementResult _targetManagementResult(
  Object? raw,
  TargetManagementPlanItem expected,
) {
  if (raw is! Map<String, dynamic> ||
      raw['name'] != expected.name ||
      raw['skillId'] != expected.skillId ||
      raw['version'] != expected.version ||
      raw['action'] != _targetManagementActionValue(expected.action!) ||
      raw.containsKey('errorCode') ||
      raw.containsKey('diagnostic')) {
    throw const FormatException();
  }
  final target = _installationPlanTarget(raw['target']);
  if (!_samePlanTarget(target, expected.target)) throw const FormatException();
  final outcome = _targetManagementOutcome(raw['outcome']);
  final error = _targetFailure(raw['error']);
  if (outcome == TargetManagementOutcome.failed && error == null) {
    throw const FormatException();
  }
  if (outcome == TargetManagementOutcome.succeeded && error != null) {
    throw const FormatException();
  }
  return TargetManagementResult(
    target: target,
    name: expected.name,
    skillId: expected.skillId,
    version: expected.version,
    action: expected.action!,
    outcome: outcome,
    error: error,
  );
}

String _installedSkillUpdateKey(InstalledSkill skill) =>
    skill.inventoryKey.isEmpty ? skill.name : skill.inventoryKey;

SkillMetricKind _metricKind(String value) => switch (value) {
  'all_time_installs' => SkillMetricKind.allTimeInstalls,
  'installs_24h' => SkillMetricKind.installs24h,
  'hot_velocity' => SkillMetricKind.hotVelocity,
  _ => throw const SkillsException(
    'Discovery metric is invalid.',
    kind: SkillsFailureKind.invalidResponse,
  ),
};
