/*
 * [INPUT]: Depends on the shared RealSkillsGateway library, Dart JSON/filesystem primitives, and App domain models.
 * [OUTPUT]: Provides private strict CLI decoders, argument encoders, local Skill inspection, and schema invariants.
 * [POS]: Serves as the machine-protocol codec implementation inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

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

InstallationMode _installationMode(Object? value) => switch (value) {
  'symlink' => InstallationMode.symlink,
  'copy' => InstallationMode.copy,
  'external' => InstallationMode.external,
  _ => throw const FormatException('Unknown installation mode.'),
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
  'local' => LibraryProvenance.local,
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
const _inventorySchemaVersion = 5;

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

InstallationPlanTarget _installationPlanTarget(
  Object? raw, {
  bool allowExternal = false,
}) {
  if (raw is! Map<String, dynamic> ||
      raw['agent'] is! String ||
      (raw['agent'] as String).isEmpty ||
      raw['path'] is! String ||
      (raw['path'] as String).isEmpty ||
      (raw['projectRoot'] != null && raw['projectRoot'] is! String)) {
    throw const FormatException();
  }
  final scope = _installationScope(raw['scope']);
  final mode = _installationMode(raw['mode']);
  final projectRoot = raw['projectRoot'] as String? ?? '';
  if ((!allowExternal && mode == InstallationMode.external) ||
      (scope == InstallationScope.user && projectRoot.isNotEmpty) ||
      (scope == InstallationScope.project && projectRoot.isEmpty)) {
    throw const FormatException();
  }
  return InstallationPlanTarget(
    scope: scope,
    projectRoot: projectRoot,
    agent: raw['agent'] as String,
    mode: mode,
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
    left.mode == right.mode &&
    left.path == right.path;

List<InstallationTargetResult> _repositoryInstallationResults(
  Object? raw,
  SkillSummary skill,
  String immutableVersion,
  List<InstallationTargetSelection> selections,
) {
  if (raw is! Map<String, dynamic> ||
      raw['schemaVersion'] != 1 ||
      raw['phase'] != 'repository-install' ||
      raw['repository'] != skill.id.split('/-/').first ||
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
  final expectedMember = skill.id.contains('/-/')
      ? skill.id.split('/-/').last
      : '.';
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
      !(workspace['lock'] as String).endsWith('skillsgo.lock')) {
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
            mode: selection.mode,
            path: path,
          ),
          action: InstallationPlanAction.create,
          outcome: InstallationTargetOutcome.succeeded,
        );
      })
      .toList(growable: false);
}

UpdatePlanAction _updatePlanAction(Object? value) => switch (value) {
  'update' => UpdatePlanAction.update,
  'current' => UpdatePlanAction.current,
  'pinned' => UpdatePlanAction.pinned,
  'failed' => UpdatePlanAction.failed,
  _ => throw const FormatException(),
};

UpdateTargetOutcome _updateTargetOutcome(Object? value) => switch (value) {
  'succeeded' => UpdateTargetOutcome.succeeded,
  'skipped' => UpdateTargetOutcome.skipped,
  'failed' => UpdateTargetOutcome.failed,
  _ => throw const FormatException(),
};

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

UpdateTargetResult _updateTargetResult(Object? raw, UpdatePlanItem expected) {
  if (raw is! Map<String, dynamic> ||
      raw['name'] != expected.name ||
      raw['skillId'] != expected.skillId ||
      raw['fromVersion'] != expected.fromVersion ||
      raw['toVersion'] != expected.toVersion ||
      raw.containsKey('errorCode') ||
      raw.containsKey('diagnostic')) {
    throw const FormatException();
  }
  final target = _installationPlanTarget(
    raw['target'],
    allowExternal: expected.target.mode == InstallationMode.external,
  );
  if (!_samePlanTarget(target, expected.target)) throw const FormatException();
  final outcome = _updateTargetOutcome(raw['outcome']);
  final error = _targetFailure(raw['error']);
  if (outcome == UpdateTargetOutcome.failed && error == null) {
    throw const FormatException();
  }
  if (outcome != UpdateTargetOutcome.failed && error != null) {
    throw const FormatException();
  }
  return UpdateTargetResult(
    target: target,
    name: expected.name,
    skillId: expected.skillId,
    fromVersion: expected.fromVersion,
    toVersion: expected.toVersion,
    outcome: outcome,
    error: error,
  );
}

TargetManagementAction _targetManagementAction(Object? value) =>
    switch (value) {
      'remove' => TargetManagementAction.remove,
      'repair' => TargetManagementAction.repair,
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
      TargetManagementAction.repair => 'repair',
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
  final target = _installationPlanTarget(
    raw['target'],
    allowExternal: expected.target.mode == InstallationMode.external,
  );
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
