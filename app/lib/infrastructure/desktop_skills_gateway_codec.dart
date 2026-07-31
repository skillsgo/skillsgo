/*
 * [INPUT]: Depends on the shared DesktopSkillsGateway library, Dart JSON/filesystem primitives, and App domain models.
 * [OUTPUT]: Provides centralized machine-document envelope validation, strict local External source evidence decoding, minimal Package-install receipt validation, private CLI decoders, argument encoders, and schema invariants.
 * [POS]: Serves as the machine-protocol codec implementation inside the DesktopSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'desktop_skills_gateway.dart';

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

InstallationScope _installationScope(Object? value) => switch (value) {
  'global' => InstallationScope.global,
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

const _inventorySchemaVersion = 8;

ExternalSourceStatus _externalSourceStatus(Object? value) => switch (value) {
  'confirmed' => ExternalSourceStatus.confirmed,
  'import-only' => ExternalSourceStatus.importOnly,
  'conflict' => ExternalSourceStatus.conflict,
  'unknown' => ExternalSourceStatus.unknown,
  _ => throw const FormatException('Unknown External source status.'),
};

ExternalSourceConfidence _externalSourceConfidence(Object? value) =>
    switch (value) {
      'high' => ExternalSourceConfidence.high,
      'medium' => ExternalSourceConfidence.medium,
      'none' => ExternalSourceConfidence.none,
      _ => throw const FormatException('Unknown External source confidence.'),
    };

ExternalSourceEvidenceKind _externalSourceEvidenceKind(Object? value) =>
    switch (value) {
      'skills-sh-lock' => ExternalSourceEvidenceKind.skillsShLock,
      'clawhub-origin' => ExternalSourceEvidenceKind.clawHubOrigin,
      'git-origin' => ExternalSourceEvidenceKind.gitOrigin,
      _ => throw const FormatException('Unknown External evidence kind.'),
    };

ExternalSourceResolution _externalSourceResolution(Object? value) {
  if (value is! Map<String, dynamic> || value['evidence'] is! List) {
    throw const FormatException();
  }
  final status = _externalSourceStatus(value['status']);
  final confidence = _externalSourceConfidence(value['confidence']);
  final coordinate = _optionalString(value, 'coordinate');
  final url = _optionalExternalUrl(value, 'url');
  final channel = _optionalString(value, 'channel');
  final reference = _optionalString(value, 'reference');
  final evidence = (value['evidence'] as List)
      .map(_externalSourceEvidence)
      .toList(growable: false);
  final valid = switch (status) {
    ExternalSourceStatus.confirmed =>
      coordinate.isNotEmpty &&
          url.isNotEmpty &&
          channel.isEmpty &&
          reference.isEmpty &&
          confidence != ExternalSourceConfidence.none &&
          evidence.isNotEmpty,
    ExternalSourceStatus.importOnly =>
      coordinate.isEmpty &&
          channel.isNotEmpty &&
          reference.isNotEmpty &&
          confidence != ExternalSourceConfidence.none &&
          evidence.isNotEmpty,
    ExternalSourceStatus.conflict =>
      coordinate.isEmpty &&
          url.isEmpty &&
          channel.isEmpty &&
          reference.isEmpty &&
          confidence == ExternalSourceConfidence.none &&
          evidence.length > 1,
    ExternalSourceStatus.unknown =>
      coordinate.isEmpty &&
          url.isEmpty &&
          channel.isEmpty &&
          reference.isEmpty &&
          confidence == ExternalSourceConfidence.none &&
          evidence.isEmpty,
  };
  if (!valid) throw const FormatException();
  return ExternalSourceResolution(
    status: status,
    confidence: confidence,
    coordinate: coordinate,
    url: url,
    channel: channel,
    reference: reference,
    evidence: List.unmodifiable(evidence),
  );
}

ExternalSourceEvidence _externalSourceEvidence(Object? value) {
  if (value is! Map<String, dynamic> ||
      value['location'] is! String ||
      (value['location'] as String).isEmpty) {
    throw const FormatException();
  }
  final kind = _externalSourceEvidenceKind(value['kind']);
  final confidence = _externalSourceConfidence(value['confidence']);
  final coordinate = _optionalString(value, 'coordinate');
  final url = _optionalExternalUrl(value, 'url');
  final channel = _optionalString(value, 'channel');
  final reference = _optionalString(value, 'reference');
  if (confidence == ExternalSourceConfidence.none ||
      (coordinate.isNotEmpty && url.isEmpty) ||
      (kind == ExternalSourceEvidenceKind.gitOrigin &&
          (coordinate.isEmpty || channel.isNotEmpty || reference.isNotEmpty))) {
    throw const FormatException();
  }
  return ExternalSourceEvidence(
    kind: kind,
    confidence: confidence,
    location: value['location'] as String,
    coordinate: coordinate,
    url: url,
    channel: channel,
    reference: reference,
  );
}

String _optionalString(Map<String, dynamic> value, String key) {
  final item = value[key];
  if (item == null) return '';
  if (item is! String) throw const FormatException();
  return item;
}

String _optionalExternalUrl(Map<String, dynamic> value, String key) {
  final item = _optionalString(value, key);
  if (item.isEmpty) return '';
  final parsed = Uri.tryParse(item);
  if (parsed == null ||
      (parsed.scheme != 'https' && parsed.scheme != 'http') ||
      parsed.host.isEmpty ||
      parsed.userInfo.isNotEmpty ||
      parsed.hasQuery ||
      parsed.hasFragment) {
    throw const FormatException();
  }
  return item;
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
  if ((scope == InstallationScope.global && projectRoot.isNotEmpty) ||
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

void _validatePackageInstallationReceipt(
  Object? value,
  String packagePath,
  String immutableVersion,
) {
  final raw = _machineDocument(value, phases: const ['package-install']);
  if (raw['packagePath'] != packagePath || raw['version'] != immutableVersion) {
    throw const FormatException();
  }
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

SkillMetricKind _metricKind(String value) => switch (value) {
  'all_time_installs' => SkillMetricKind.allTimeInstalls,
  'installs_24h' => SkillMetricKind.installs24h,
  'hot_velocity' => SkillMetricKind.hotVelocity,
  _ => throw const SkillsException(
    'Discovery metric is invalid.',
    kind: SkillsFailureKind.invalidResponse,
  ),
};
