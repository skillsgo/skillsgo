/*
 * [INPUT]: Depends on Registry HTTP, the local filesystem, the platform directory picker, SharedPreferences, and executable process boundaries.
 * [OUTPUT]: Provides production Registry settings, discovery/detail, managed/external inventory parsing, trusted-risk and state-bound Installation Plan/result parsing, local file inspection, project persistence, Agent inspection, typed failures, diagnostics, CLI verification, and Skill operations.
 * [POS]: Serves as the App infrastructure adapter between domain journeys, the Registry, and the SkillsGo CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/skills_gateway.dart';

typedef DirectoryPicker = Future<String?> Function({String? initialDirectory});
typedef ProjectPathInspector =
    Future<({ProjectAccessState state, String? diagnostic})> Function(
      String path,
    );

class IoProcessRunner implements ProcessRunner {
  const IoProcessRunner();

  @override
  Future<ProcessOutput> run(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
      ).timeout(const Duration(minutes: 2));
      return ProcessOutput(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on TimeoutException {
      return const ProcessOutput(
        exitCode: 124,
        stdout: '',
        stderr: 'Command timed out.',
      );
    } on ProcessException catch (error) {
      return ProcessOutput(exitCode: 127, stdout: '', stderr: error.message);
    }
  }
}

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

InstallationPlanAction _installationPlanAction(Object? value) =>
    switch (value) {
      'create' => InstallationPlanAction.create,
      'replace' => InstallationPlanAction.replace,
      'skip' => InstallationPlanAction.skip,
      'conflict' => InstallationPlanAction.conflict,
      'blocked-by-risk' => InstallationPlanAction.blockedByRisk,
      _ => throw const FormatException('Unknown Installation Plan action.'),
    };

InstallationTargetOutcome _installationTargetOutcome(Object? value) =>
    switch (value) {
      'succeeded' => InstallationTargetOutcome.succeeded,
      'skipped' => InstallationTargetOutcome.skipped,
      'conflict' => InstallationTargetOutcome.conflict,
      'failed' => InstallationTargetOutcome.failed,
      _ => throw const FormatException('Unknown Installation Target outcome.'),
    };

String _installationPlanReasonCode(Object? value) => switch (value) {
  null => '',
  'identical-target' => 'identical-target',
  'version-conflict' => 'version-conflict',
  'identity-collision' => 'identity-collision',
  'local-modification' => 'local-modification',
  'shared-target-conflict' => 'shared-target-conflict',
  'high-risk' => 'high-risk',
  'critical-risk' => 'critical-risk',
  'blocked-by-risk' => 'blocked-by-risk',
  _ => throw const FormatException('Unknown Installation Plan reason code.'),
};

bool _validPlanReason(InstallationPlanAction action, String reasonCode) =>
    switch (action) {
      InstallationPlanAction.create => reasonCode.isEmpty,
      InstallationPlanAction.skip => reasonCode == 'identical-target',
      InstallationPlanAction.replace =>
        reasonCode == 'version-conflict' ||
            reasonCode == 'identity-collision' ||
            reasonCode == 'local-modification',
      InstallationPlanAction.conflict =>
        reasonCode == 'version-conflict' ||
            reasonCode == 'identity-collision' ||
            reasonCode == 'local-modification' ||
            reasonCode == 'shared-target-conflict',
      InstallationPlanAction.blockedByRisk =>
        reasonCode == 'high-risk' || reasonCode == 'critical-risk',
    };

String _installationErrorCode(Object? value) => switch (value) {
  null => '',
  'target-path-exists' => 'target-path-exists',
  'blocked-by-risk' => 'blocked-by-risk',
  'install-failed' => 'install-failed',
  'workspace-update-failed' => 'workspace-update-failed',
  _ => throw const FormatException('Unknown Installation Target error code.'),
};

ReceiptState _receiptState(Object? value) => switch (value) {
  'present' => ReceiptState.present,
  'missing' => ReceiptState.missing,
  'invalid' => ReceiptState.invalid,
  _ => throw const FormatException('Unknown receipt state.'),
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
  'receipt-missing' => InstallationHealth.receiptMissing,
  _ => throw const FormatException('Unknown installation health.'),
};

LibraryProvenance _libraryProvenance(Object? value) => switch (value) {
  'registry' => LibraryProvenance.registry,
  'local' => LibraryProvenance.local,
  'external' => LibraryProvenance.external,
  _ => throw const FormatException('Unknown Library provenance.'),
};

int _localTargetReadRank(SkillInstallationTarget target) {
  if (target.health == InstallationHealth.healthy) return 0;
  if (target.receiptState == ReceiptState.present) return 1;
  return 2;
}

const _localFilePreviewLimit = 256 * 1024;
const _inventorySchemaVersion = 3;
const _installationPlanSchemaVersion = 2;

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
  final mode = _installationMode(raw['mode']);
  final projectRoot = raw['projectRoot'] as String? ?? '';
  if (mode == InstallationMode.external ||
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

InstallationAffectedBinding _installationAffectedBinding(Object? raw) {
  if (raw is! Map<String, dynamic> ||
      raw['agent'] is! String ||
      (raw['agent'] as String).isEmpty ||
      raw['path'] is! String ||
      (raw['path'] as String).isEmpty) {
    throw const FormatException();
  }
  final mode = _installationMode(raw['mode']);
  if (mode == InstallationMode.external) throw const FormatException();
  return InstallationAffectedBinding(
    agent: raw['agent'] as String,
    scope: _installationScope(raw['scope']),
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

String _scopeValue(InstallationScope scope) => switch (scope) {
  InstallationScope.user => 'user',
  InstallationScope.project => 'project',
};

String _modeValue(InstallationMode mode) => switch (mode) {
  InstallationMode.symlink => 'symlink',
  InstallationMode.copy => 'copy',
  InstallationMode.external => throw const FormatException(
    'External mode cannot enter an Installation Plan.',
  ),
};

String _targetArgument(InstallationTargetSelection selection) => jsonEncode({
  'scope': _scopeValue(selection.scope),
  if (selection.projectRoot.isNotEmpty) 'projectRoot': selection.projectRoot,
  'agent': selection.agent,
  'mode': _modeValue(selection.mode),
  if (selection.resolution == InstallationTargetResolution.replace)
    'resolution': 'replace',
  if (selection.resolution == InstallationTargetResolution.replace)
    'expectedReason': selection.expectedReason,
  if (selection.resolution == InstallationTargetResolution.replace)
    'expectedState': selection.expectedState,
});

SkillMetricKind _metricKind(String value) => switch (value) {
  'all_time_installs' => SkillMetricKind.allTimeInstalls,
  'installs_24h' => SkillMetricKind.installs24h,
  'hot_velocity' => SkillMetricKind.hotVelocity,
  _ => throw const SkillsException(
    'Discovery metric is invalid.',
    kind: SkillsFailureKind.invalidResponse,
  ),
};

class RealSkillsGateway implements SkillsGateway {
  RealSkillsGateway({
    http.Client? httpClient,
    ProcessRunner? processRunner,
    String? initialCliPath,
    String? bundledCliPath,
    this.allowDeveloperCliOverride = !kReleaseMode,
    String? expectedCliOS,
    String registryBaseUrl = 'http://localhost:3000',
    String? appVersion,
    this.discoveryTimeout = const Duration(seconds: 15),
    this.detailTimeout = const Duration(seconds: 20),
    DirectoryPicker? directoryPicker,
    ProjectPathInspector? projectPathInspector,
  }) : _http = httpClient ?? http.Client(),
       _runner = processRunner ?? const IoProcessRunner(),
       _cliPath = initialCliPath,
       _bundledCliPath =
           bundledCliPath ?? _bundledPathFor(Platform.resolvedExecutable),
       _expectedCliOS = expectedCliOS ?? _goOperatingSystem,
       _defaultRegistryBase = _originUri(registryBaseUrl),
       _registryBase = _originUri(registryBaseUrl),
       _injectedAppVersion = appVersion,
       _directoryPicker = directoryPicker ?? _pickDirectory,
       _projectPathInspector = projectPathInspector ?? _inspectProjectPath;

  static const _customCliKey = 'custom_cli_path';
  static const _registryOriginKey = 'registry_origin';
  static const _allowCriticalOverrideKey = 'allow_critical_risk_override';
  static const _addedProjectsKey = 'added_projects_v1';
  static const _startupHandshakeSchemaVersion = 1;
  static const _appProtocolVersion = 4;
  final http.Client _http;
  final ProcessRunner _runner;
  final Uri _defaultRegistryBase;
  Uri _registryBase;
  final String _bundledCliPath;
  final bool allowDeveloperCliOverride;
  final String _expectedCliOS;
  final String? _injectedAppVersion;
  final Duration discoveryTimeout;
  final Duration detailTimeout;
  final DirectoryPicker _directoryPicker;
  final ProjectPathInspector _projectPathInspector;
  String? _cliPath;
  bool _registryOriginLoaded = false;

  static Future<String?> _pickDirectory({String? initialDirectory}) =>
      file_selector.getDirectoryPath(initialDirectory: initialDirectory);

  static Future<({ProjectAccessState state, String? diagnostic})>
  _inspectProjectPath(String path) async {
    try {
      final type = await FileSystemEntity.type(path, followLinks: true);
      if (type != FileSystemEntityType.directory) {
        return (
          state: ProjectAccessState.missing,
          diagnostic: 'The selected directory is missing or unavailable.',
        );
      }
      await Directory(path).list(followLinks: false).take(1).drain<void>();
      return (state: ProjectAccessState.accessible, diagnostic: null);
    } on FileSystemException catch (error) {
      final permissionDenied =
          error.osError?.errorCode == 1 || error.osError?.errorCode == 13;
      return (
        state: permissionDenied
            ? ProjectAccessState.permissionDenied
            : ProjectAccessState.inaccessible,
        diagnostic: error.message,
      );
    }
  }

  static Uri _originUri(String origin) {
    final value = origin.trim();
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        !parsed.hasScheme ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw const FormatException('Registry Origin must be an HTTP(S) URL.');
    }
    return Uri.parse(value.endsWith('/') ? value : '$value/');
  }

  String get _registryOrigin =>
      _registryBase.toString().replaceFirst(RegExp(r'/$'), '');

  Future<void> _ensureRegistryOrigin() async {
    if (_registryOriginLoaded) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_registryOriginKey);
    if (saved != null) {
      try {
        _registryBase = _originUri(saved);
      } on FormatException {
        await preferences.remove(_registryOriginKey);
      }
    }
    _registryOriginLoaded = true;
  }

  static String _bundledPathFor(String executable) => p.normalize(
    p.join(p.dirname(executable), '..', 'Resources', 'bin', 'skillsgo'),
  );

  static String get _goOperatingSystem => switch (Platform.operatingSystem) {
    'macos' => 'darwin',
    final value => value,
  };

  @override
  Future<CliStatus> detectCli({String? customPath}) async {
    final previouslyResolvedPath = _cliPath;
    _cliPath = null;
    final saved = allowDeveloperCliOverride
        ? customPath ?? await loadCustomCliPath()
        : null;
    final candidates = <String>{
      if (saved != null && saved.trim().isNotEmpty) saved.trim(),
      if (allowDeveloperCliOverride) ...[
        ?previouslyResolvedPath,
        ?Platform.environment['SKILLSGO_CLI_PATH'],
      ],
      _bundledCliPath,
    };

    for (final candidate in candidates) {
      if (candidate.trim().isEmpty) continue;
      final versionResult = await _runner.run(candidate, const [
        'version',
        '--output',
        'json',
      ]);
      if (versionResult.exitCode != 0) continue;
      try {
        final decoded = jsonDecode(versionResult.stdout);
        if (decoded is! Map<String, dynamic> ||
            decoded['schemaVersion'] != _startupHandshakeSchemaVersion ||
            decoded['product'] != 'skillsgo' ||
            decoded['appProtocolVersion'] is! int ||
            decoded['version'] is! String ||
            (decoded['version'] as String).trim().isEmpty ||
            decoded['os'] is! String ||
            (decoded['os'] as String).trim().isEmpty ||
            decoded['architecture'] is! String ||
            (decoded['architecture'] as String).trim().isEmpty) {
          throw const FormatException('Invalid SkillsGo startup handshake.');
        }
        final version = decoded['version'] as String;
        if (decoded['appProtocolVersion'] != _appProtocolVersion) {
          return CliStatus(
            availability: CliAvailability.incompatible,
            path: candidate,
            version: version,
            message: 'The SkillsGo CLI App protocol is incompatible.',
            issue: CliIssue.incompatible,
          );
        }
        if (decoded['os'] != _expectedCliOS) {
          return CliStatus(
            availability: CliAvailability.incompatible,
            path: candidate,
            version: version,
            message: 'The SkillsGo CLI was built for another platform.',
            issue: CliIssue.incompatible,
          );
        }
        _cliPath = candidate;
        return CliStatus(
          availability: CliAvailability.ready,
          path: candidate,
          version: version,
        );
      } on FormatException {
        return CliStatus(
          availability: CliAvailability.incompatible,
          path: candidate,
          message: 'The SkillsGo CLI startup handshake is invalid.',
          issue: CliIssue.damaged,
        );
      }
    }
    _cliPath = null;
    return const CliStatus(
      availability: CliAvailability.missing,
      message: 'The bundled SkillsGo CLI is missing or cannot run.',
      issue: CliIssue.missing,
    );
  }

  @override
  Future<String?> loadCustomCliPath() async =>
      (await SharedPreferences.getInstance()).getString(_customCliKey);

  @override
  Future<void> saveCustomCliPath(String? path) async {
    final preferences = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await preferences.remove(_customCliKey);
    } else {
      await preferences.setString(_customCliKey, path.trim());
    }
  }

  String _newProjectID() {
    final bytes = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<List<({String id, String name, String path})>>
  _loadProjectReferences() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _addedProjectsKey,
    );
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException();
      final ids = <String>{};
      final paths = <String>{};
      return decoded
          .map((entry) {
            if (entry is! Map<String, dynamic> ||
                entry['id'] is! String ||
                (entry['id'] as String).isEmpty ||
                entry['name'] is! String ||
                (entry['name'] as String).isEmpty ||
                entry['path'] is! String ||
                (entry['path'] as String).isEmpty ||
                !ids.add(entry['id'] as String) ||
                !paths.add(entry['path'] as String)) {
              throw const FormatException();
            }
            return (
              id: entry['id'] as String,
              name: entry['name'] as String,
              path: entry['path'] as String,
            );
          })
          .toList(growable: false);
    } on FormatException {
      throw const SkillsException(
        'Saved project references are invalid.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  Future<void> _saveProjectReferences(
    List<({String id, String name, String path})> projects,
  ) async {
    final encoded = jsonEncode([
      for (final project in projects)
        {'id': project.id, 'name': project.name, 'path': project.path},
    ]);
    await (await SharedPreferences.getInstance()).setString(
      _addedProjectsKey,
      encoded,
    );
  }

  Future<AddedProject> _resolveProject(
    ({String id, String name, String path}) reference,
  ) async {
    final access = await _projectPathInspector(reference.path);
    return AddedProject(
      id: reference.id,
      name: reference.name,
      path: reference.path,
      accessState: access.state,
      diagnostic: access.diagnostic,
    );
  }

  @override
  Future<List<AddedProject>> loadAddedProjects() async {
    final references = await _loadProjectReferences();
    final projects = <AddedProject>[];
    for (final reference in references) {
      projects.add(await _resolveProject(reference));
    }
    return projects;
  }

  @override
  Future<AddedProject?> addProject() async {
    final selected = await _directoryPicker();
    if (selected == null || selected.trim().isEmpty) return null;
    final path = p.normalize(p.absolute(selected.trim()));
    final references = await _loadProjectReferences();
    for (final reference in references) {
      if (p.equals(reference.path, path)) return _resolveProject(reference);
    }
    final basename = p.basename(path);
    final reference = (
      id: _newProjectID(),
      name: basename.isEmpty ? path : basename,
      path: path,
    );
    await _saveProjectReferences([...references, reference]);
    return _resolveProject(reference);
  }

  @override
  Future<AddedProject?> relocateProject(String id) async {
    final references = await _loadProjectReferences();
    final index = references.indexWhere((project) => project.id == id);
    if (index < 0) return null;
    final selected = await _directoryPicker(
      initialDirectory: references[index].path,
    );
    if (selected == null || selected.trim().isEmpty) {
      return _resolveProject(references[index]);
    }
    final path = p.normalize(p.absolute(selected.trim()));
    if (references.any(
      (project) => project.id != id && p.equals(project.path, path),
    )) {
      throw const SkillsException('That project is already added.');
    }
    final relocated = (
      id: references[index].id,
      name: references[index].name,
      path: path,
    );
    final updated = [...references]..[index] = relocated;
    await _saveProjectReferences(updated);
    return _resolveProject(relocated);
  }

  @override
  Future<void> removeProject(String id) async {
    final references = await _loadProjectReferences();
    await _saveProjectReferences(
      references.where((project) => project.id != id).toList(growable: false),
    );
  }

  @override
  Future<String> loadRegistryOrigin() async {
    await _ensureRegistryOrigin();
    return _registryOrigin;
  }

  @override
  Future<void> saveRegistryOrigin(String origin) async {
    final parsed = _originUri(origin);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _registryOriginKey,
      parsed.toString().replaceFirst(RegExp(r'/$'), ''),
    );
    _registryBase = parsed;
    _registryOriginLoaded = true;
  }

  @override
  Future<void> resetRegistryOrigin() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_registryOriginKey);
    _registryBase = _defaultRegistryBase;
    _registryOriginLoaded = true;
  }

  @override
  Future<RegistryStatus> testRegistryOrigin(String origin) async {
    final Uri base;
    try {
      base = _originUri(origin);
    } on FormatException catch (error) {
      return RegistryStatus(
        origin: origin.trim(),
        state: HealthState.invalid,
        issue: RegistryIssue.invalidOrigin,
        diagnostic: error.message,
      );
    }
    final normalized = base.toString().replaceFirst(RegExp(r'/$'), '');
    final uri = base
        .resolve('v1/search')
        .replace(
          queryParameters: const {'q': 'skillsgo-settings-probe', 'limit': '1'},
        );
    try {
      final response = await _http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return RegistryStatus(
          origin: normalized,
          state: HealthState.unreachable,
          issue: RegistryIssue.httpFailure,
          httpStatus: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['skills'] is! List) {
        return RegistryStatus(
          origin: normalized,
          state: HealthState.invalid,
          issue: RegistryIssue.invalidProtocol,
        );
      }
      return RegistryStatus(origin: normalized, state: HealthState.ready);
    } on SocketException catch (error) {
      return RegistryStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: RegistryIssue.connectionFailure,
        diagnostic: error.message,
      );
    } on TimeoutException {
      return RegistryStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: RegistryIssue.timeout,
      );
    } on FormatException {
      return RegistryStatus(
        origin: normalized,
        state: HealthState.invalid,
        issue: RegistryIssue.invalidJson,
      );
    } on http.ClientException catch (error) {
      return RegistryStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: RegistryIssue.connectionFailure,
        diagnostic: error.message,
      );
    } on Object catch (error) {
      return RegistryStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: RegistryIssue.connectionFailure,
        diagnostic: error.toString(),
      );
    }
  }

  @override
  Future<PersonalRiskPolicy> loadRiskPolicy() async {
    final preferences = await SharedPreferences.getInstance();
    return PersonalRiskPolicy(
      allowCriticalOverride:
          preferences.getBool(_allowCriticalOverrideKey) ?? false,
    );
  }

  @override
  Future<void> saveRiskPolicy(PersonalRiskPolicy policy) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      _allowCriticalOverrideKey,
      policy.allowCriticalOverride,
    );
  }

  @override
  Future<StorageStatus> inspectStorage() async {
    try {
      final result = await _runCli(const ['diagnostics', '--output', 'json']);
      if (!result.succeeded) {
        return const StorageStatus(path: '', state: HealthState.unreachable);
      }
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['store'] is! Map<String, dynamic>) {
        return const StorageStatus(path: '', state: HealthState.invalid);
      }
      final store = decoded['store'] as Map<String, dynamic>;
      if (store['path'] is! String || store['state'] is! String) {
        return const StorageStatus(path: '', state: HealthState.invalid);
      }
      final state = switch (store['state']) {
        'ready' => HealthState.ready,
        'not_initialized' => HealthState.notInitialized,
        'unreadable' => HealthState.unreachable,
        _ => HealthState.invalid,
      };
      return StorageStatus(path: store['path'] as String, state: state);
    } on Object {
      return const StorageStatus(path: '', state: HealthState.unreachable);
    }
  }

  @override
  Future<String> loadAppVersion() async =>
      _injectedAppVersion ?? (await PackageInfo.fromPlatform()).version;

  @override
  Future<DiscoveryPage> discover(
    DiscoveryCollection collection, {
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    final trimmedQuery = query.trim();
    if (collection == DiscoveryCollection.search && trimmedQuery.isEmpty) {
      throw const SkillsException(
        'Search query is required.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureRegistryOrigin();
    final expectedCollection = switch (collection) {
      DiscoveryCollection.search => 'search',
      DiscoveryCollection.ranking => 'all_time',
      DiscoveryCollection.trending => 'trending',
      DiscoveryCollection.hot => 'hot',
    };
    final parameters = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (collection == DiscoveryCollection.search) 'q': trimmedQuery,
      if (collection != DiscoveryCollection.search) 'sort': expectedCollection,
    };
    final uri = _registryBase
        .resolve(
          collection == DiscoveryCollection.search ? 'v1/search' : 'v1/skills',
        )
        .replace(queryParameters: parameters);
    try {
      final response = await _http.get(uri).timeout(discoveryTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SkillsException(
          'Discovery service returned ${response.statusCode}.',
          kind: response.statusCode >= 400 && response.statusCode < 500
              ? SkillsFailureKind.validation
              : SkillsFailureKind.server,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['collection'] != expectedCollection ||
          decoded['skills'] is! List ||
          decoded['page'] is! Map<String, dynamic>) {
        throw const SkillsException(
          'Discovery service returned an invalid response.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final page = decoded['page'] as Map<String, dynamic>;
      final nextRaw = page['nextOffset'];
      if (page['limit'] is! num ||
          page['offset'] is! num ||
          (nextRaw != null && nextRaw is! num)) {
        throw const SkillsException(
          'Discovery pagination is invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final installedCounts = <String, int>{};
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        for (final skill in installed) {
          if (skill.coordinate.isNotEmpty) {
            installedCounts[skill.coordinate] = skill.targetCount;
          }
        }
      } on Object {
        // Discovery remains available when local CLI inventory is unavailable.
      }
      final skills = (decoded['skills'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const SkillsException(
                'Invalid discovery result.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            final source = raw['source'];
            final skillId =
                raw['skillPath'] is String &&
                    (raw['skillPath'] as String).isNotEmpty
                ? p.basename(raw['skillPath'] as String)
                : raw['name'];
            final id = raw['coordinate'];
            final name = raw['name'];
            final description = raw['description'];
            final version = raw['latestVersion'];
            final metric = raw['metric'];
            if (source is! String ||
                skillId is! String ||
                id is! String ||
                name is! String ||
                description is! String ||
                version is! String ||
                metric is! Map<String, dynamic> ||
                metric['kind'] is! String ||
                metric['value'] is! num ||
                metric['change'] is! num) {
              throw const SkillsException(
                'Discovery result is missing required fields.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            return SkillSummary(
              id: id,
              skillId: skillId,
              name: name,
              source: source,
              description: description,
              installs: (metric['value'] as num).toInt(),
              latestVersion: version,
              trustLevel: _trustLevel(raw['trustLevel']),
              riskAssessment: _riskAssessment(raw['riskAssessment']),
              metricKind: _metricKind(metric['kind'] as String),
              metricChange: (metric['change'] as num).toInt(),
              localTargetCount: installedCounts[id] ?? 0,
            );
          })
          .toList(growable: false);
      return DiscoveryPage(
        skills: skills,
        nextOffset: nextRaw == null ? null : (nextRaw as num).toInt(),
      );
    } on SkillsException {
      rethrow;
    } on SocketException {
      throw const SkillsException(
        'You appear to be offline.',
        kind: SkillsFailureKind.offline,
        isOffline: true,
      );
    } on http.ClientException {
      throw const SkillsException(
        'The Registry connection failed.',
        kind: SkillsFailureKind.offline,
        isOffline: true,
      );
    } on TimeoutException {
      throw const SkillsException(
        'Discovery timed out. Check your connection.',
        kind: SkillsFailureKind.timeout,
      );
    } on FormatException {
      throw const SkillsException(
        'Discovery service returned invalid JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill) async {
    await _ensureRegistryOrigin();
    final uri = _registryBase.resolve('v1/skills/${skill.id}');
    try {
      final response = await _http.get(uri).timeout(detailTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var code = '';
        try {
          final error = jsonDecode(response.body);
          if (error is Map<String, dynamic> && error['code'] is String) {
            code = error['code'] as String;
          }
        } on FormatException {
          // Status remains authoritative when an error body is not JSON.
        }
        throw SkillsException(
          'Skill detail returned ${response.statusCode}.',
          kind: switch (code) {
            'artifact_invalid' => SkillsFailureKind.invalidResponse,
            'artifact_unavailable' => SkillsFailureKind.artifactUnavailable,
            _ when response.statusCode >= 400 && response.statusCode < 500 =>
              SkillsFailureKind.validation,
            _ => SkillsFailureKind.server,
          },
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const SkillsException(
          'Skill detail is invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      const requiredStrings = [
        'coordinate',
        'name',
        'description',
        'source',
        'requestedVersion',
        'immutableVersion',
        'commitSHA',
        'treeSHA',
        'sourceRef',
        'contentDigest',
        'manifest',
        'instructions',
        'trustLevel',
      ];
      if (requiredStrings.any((field) => decoded[field] is! String) ||
          decoded['coordinate'] != skill.id ||
          decoded['riskAssessment'] is! Map<String, dynamic> ||
          decoded['files'] is! List ||
          decoded['hasExecutableContent'] is! bool ||
          decoded['executableFiles'] is! List) {
        throw const SkillsException(
          'Skill detail is missing required fields.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final risk = decoded['riskAssessment'] as Map<String, dynamic>;
      if (risk['level'] is! String ||
          risk['scannerVersion'] is! String ||
          risk['evidence'] is! List) {
        throw const SkillsException(
          'Skill Risk Assessment is invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final evidence = (risk['evidence'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['code'] is! String ||
                raw['path'] is! String) {
              throw const SkillsException(
                'Skill risk evidence is invalid.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            return SkillRiskEvidence(
              code: raw['code'] as String,
              path: raw['path'] as String,
            );
          })
          .toList(growable: false);
      final files = (decoded['files'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['path'] is! String ||
                raw['size'] is! num ||
                raw['kind'] is! String ||
                raw['executable'] is! bool ||
                raw['binary'] is! bool ||
                raw['truncated'] is! bool ||
                (raw['content'] != null && raw['content'] is! String)) {
              throw const SkillsException(
                'Skill file inventory is invalid.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            return SkillFile(
              path: raw['path'] as String,
              contents: raw['content'] as String? ?? '',
              size: (raw['size'] as num).toInt(),
              kind: raw['kind'] as String,
              executable: raw['executable'] as bool,
              binary: raw['binary'] as bool,
              truncated: raw['truncated'] as bool,
            );
          })
          .toList(growable: false);
      if ((decoded['executableFiles'] as List).any((path) => path is! String)) {
        throw const SkillsException(
          'Executable file signals are invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      var installationTargets = <SkillInstallationTarget>[];
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        installationTargets = installed
            .where((entry) => entry.coordinate == skill.id)
            .expand((entry) => entry.targets)
            .toList(growable: false);
      } on Object {
        // Remote artifact inspection stays available without local CLI state.
      }
      return SkillDetail(
        name: decoded['name'] as String,
        source: decoded['source'] as String,
        markdown: decoded['instructions'] as String,
        files: files,
        installs: skill.installs,
        description: decoded['description'] as String,
        requestedVersion: decoded['requestedVersion'] as String,
        immutableVersion: decoded['immutableVersion'] as String,
        commitSHA: decoded['commitSHA'] as String,
        treeSHA: decoded['treeSHA'] as String,
        sourceRef: decoded['sourceRef'] as String,
        contentDigest: decoded['contentDigest'] as String,
        manifest: decoded['manifest'] as String,
        trustLevel: _trustLevel(decoded['trustLevel']),
        riskAssessment: _riskAssessment(risk['level']),
        riskScannerVersion: risk['scannerVersion'] as String,
        riskEvidence: evidence,
        installationTargets: installationTargets,
        registryExecutableSignal: decoded['hasExecutableContent'] as bool,
      );
    } on SkillsException {
      rethrow;
    } on SocketException {
      throw const SkillsException(
        'You appear to be offline.',
        kind: SkillsFailureKind.offline,
        isOffline: true,
      );
    } on http.ClientException {
      throw const SkillsException(
        'The Registry connection failed.',
        kind: SkillsFailureKind.offline,
        isOffline: true,
      );
    } on TimeoutException {
      throw const SkillsException(
        'Skill detail timed out.',
        kind: SkillsFailureKind.timeout,
      );
    } on FormatException {
      throw const SkillsException(
        'Skill detail returned invalid JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  String get _requiredCli {
    final path = _cliPath;
    if (path == null) {
      throw const SkillsException(
        'The SkillsGo CLI is not ready. Open Settings.',
      );
    }
    return path;
  }

  Future<CommandResult> _runCli(List<String> arguments) async {
    if (_cliPath == null) {
      final status = await detectCli();
      if (!status.isReady) {
        throw SkillsException(
          status.message ?? 'The SkillsGo CLI is not ready. Open Settings.',
        );
      }
    }
    final executable = _requiredCli;
    final output = await _runner.run(executable, arguments);
    return CommandResult(command: [executable, ...arguments], output: output);
  }

  @override
  Future<AgentCatalog> inspectAgents() async {
    final result = await _runCli(const ['agents', '--output', 'json']);
    if (!result.succeeded) throw SkillsException(_commandError(result));
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['agents'] is! List) {
        throw const FormatException();
      }
      final seen = <String>{};
      final agents = (decoded['agents'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['id'] is! String ||
                (raw['id'] as String).isEmpty ||
                raw['displayName'] is! String ||
                (raw['displayName'] as String).isEmpty ||
                raw['installed'] is! bool ||
                raw['supportedScopes'] is! List ||
                !seen.add(raw['id'] as String)) {
              throw const FormatException();
            }
            final scopes = (raw['supportedScopes'] as List)
                .map(_installationScope)
                .toList(growable: false);
            if (scopes.isEmpty || scopes.toSet().length != scopes.length) {
              throw const FormatException();
            }
            final rawTarget = raw['userTarget'];
            AgentUserTarget? target;
            if (rawTarget != null) {
              if (rawTarget is! Map<String, dynamic> ||
                  rawTarget['path'] is! String ||
                  (rawTarget['path'] as String).isEmpty ||
                  rawTarget['exists'] is! bool) {
                throw const FormatException();
              }
              target = AgentUserTarget(
                path: rawTarget['path'] as String,
                exists: rawTarget['exists'] as bool,
              );
            }
            if (scopes.contains(InstallationScope.user) != (target != null)) {
              throw const FormatException();
            }
            return AgentStatus(
              id: raw['id'] as String,
              displayName: raw['displayName'] as String,
              installed: raw['installed'] as bool,
              supportedScopes: scopes,
              userTarget: target,
            );
          })
          .toList(growable: false);
      return AgentCatalog(schemaVersion: 1, agents: agents);
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Agent JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<List<InstalledSkill>> listInstalled({
    List<AddedProject> projects = const [],
  }) async {
    final arguments = <String>['inventory', '--user'];
    for (final project in projects.where(
      (project) => project.accessState == ProjectAccessState.accessible,
    )) {
      arguments.addAll(['--project', project.path]);
    }
    arguments.addAll(['--output', 'json']);
    final result = await _runCli(arguments);
    if (!result.succeeded) throw SkillsException(_commandError(result));
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != _inventorySchemaVersion ||
          decoded['entries'] is! List) {
        throw const FormatException();
      }
      return (decoded['entries'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['identity'] is! String ||
                (raw['identity'] as String).isEmpty ||
                raw['name'] is! String ||
                (raw['name'] as String).isEmpty ||
                raw['coordinate'] is! String ||
                raw['versionDivergence'] is! bool ||
                raw['targets'] is! List) {
              throw const FormatException();
            }
            final provenance = _libraryProvenance(raw['provenance']);
            final targetKeys = <String>{};
            final targets = (raw['targets'] as List)
                .map((target) {
                  if (target is! Map<String, dynamic> ||
                      target['agent'] is! String ||
                      (target['agent'] as String).isEmpty ||
                      target['path'] is! String ||
                      (target['path'] as String).isEmpty ||
                      target['version'] is! String ||
                      (target['projectRoot'] != null &&
                          target['projectRoot'] is! String)) {
                    throw const FormatException();
                  }
                  final scope = _installationScope(target['scope']);
                  final projectRoot = target['projectRoot'] as String? ?? '';
                  final version = target['version'] as String;
                  final mode = _installationMode(target['mode']);
                  final receiptState = _receiptState(target['receiptState']);
                  if ((scope == InstallationScope.project &&
                          projectRoot.isEmpty) ||
                      (scope == InstallationScope.user &&
                          projectRoot.isNotEmpty) ||
                      (provenance == LibraryProvenance.external &&
                          (version.isNotEmpty ||
                              mode != InstallationMode.external ||
                              receiptState != ReceiptState.missing)) ||
                      (provenance != LibraryProvenance.external &&
                          (version.isEmpty ||
                              mode == InstallationMode.external)) ||
                      !targetKeys.add(
                        '${target['agent']}\u0000${target['scope']}\u0000${target['path']}',
                      )) {
                    throw const FormatException();
                  }
                  return SkillInstallationTarget(
                    agent: target['agent'] as String,
                    scope: scope,
                    path: target['path'] as String,
                    version: version,
                    projectRoot: projectRoot,
                    mode: mode,
                    receiptState: receiptState,
                    health: _installationHealth(target['health']),
                  );
                })
                .toList(growable: false);
            if (targets.isEmpty) throw const FormatException();
            final agents = _strictStringList(raw['agents']);
            final projectRoots = _strictStringList(raw['projects']);
            final versions = _strictStringList(raw['versions']);
            if ((provenance != LibraryProvenance.external &&
                    versions.isEmpty) ||
                !_sameStringSet(
                  agents,
                  targets.map((target) => target.agent),
                ) ||
                !_sameStringSet(
                  projectRoots,
                  targets
                      .map((target) => target.projectRoot)
                      .where((root) => root.isNotEmpty),
                ) ||
                !_sameStringSet(
                  versions,
                  targets
                      .map((target) => target.version)
                      .where((version) => version.isNotEmpty),
                ) ||
                (raw['versionDivergence'] as bool) != (versions.length > 1)) {
              throw const FormatException();
            }
            if (provenance == LibraryProvenance.registry &&
                ((raw['coordinate'] as String).isEmpty ||
                    raw['identity'] != 'registry:${raw['coordinate']}')) {
              throw const FormatException();
            }
            if (provenance == LibraryProvenance.external &&
                ((raw['coordinate'] as String).isNotEmpty ||
                    versions.isNotEmpty ||
                    !(raw['identity'] as String).startsWith('external:'))) {
              throw const FormatException();
            }
            return InstalledSkill(
              identity: raw['identity'] as String,
              name: raw['name'] as String,
              path: targets.first.path,
              agents: agents,
              targetCount: targets.length,
              coordinate: raw['coordinate'] as String,
              targets: targets,
              provenance: provenance,
              riskAssessment: _riskAssessment(raw['risk']),
              health: _installationHealth(raw['health']),
              projects: projectRoots,
              versions: versions,
              versionDivergence: raw['versionDivergence'] as bool,
            );
          })
          .toList(growable: false);
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid inventory JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill) async {
    final targetPaths = skill.targets.isEmpty
        ? [skill.path]
        : ([...skill.targets]..sort(
                (left, right) => _localTargetReadRank(
                  left,
                ).compareTo(_localTargetReadRank(right)),
              ))
              .map((target) => target.path)
              .toList(growable: false);
    FileSystemException? lastFileError;
    for (final targetPath in targetPaths) {
      try {
        final markdown = await File(
          p.join(targetPath, 'SKILL.md'),
        ).readAsString();
        if (markdown.trim().isEmpty) continue;
        final files = await _inspectLocalFiles(targetPath);
        final executableFiles = files
            .where((file) => file.executable)
            .map(
              (file) => SkillRiskEvidence(
                code: 'executable-content',
                path: file.path,
              ),
            )
            .toList(growable: false);
        return SkillDetail(
          name: skill.name,
          source: switch (skill.provenance) {
            LibraryProvenance.registry => 'Registry',
            LibraryProvenance.local => 'Local',
            LibraryProvenance.external => 'External',
          },
          markdown: markdown,
          files: files,
          riskAssessment: skill.riskAssessment,
          riskEvidence: executableFiles,
        );
      } on FileSystemException catch (error) {
        lastFileError = error;
      }
    }
    throw SkillsException(
      lastFileError == null
          ? 'The local SKILL.md is empty.'
          : 'Cannot read local Skill: ${lastFileError.message}',
    );
  }

  @override
  Future<InstallationPlan> preflightInstall(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool riskConfirmed = false,
    bool allowCritical = false,
  }) async {
    if (immutableVersion.isEmpty || selections.isEmpty) {
      throw const SkillsException(
        'Select at least one Installation Target.',
        kind: SkillsFailureKind.validation,
      );
    }
    final cells = <String>{};
    for (final selection in selections) {
      final key =
          '${_scopeValue(selection.scope)}\u0000${selection.projectRoot}\u0000${selection.agent}';
      if (!cells.add(key) ||
          selection.agent.isEmpty ||
          (selection.scope == InstallationScope.user &&
              selection.projectRoot.isNotEmpty) ||
          (selection.scope == InstallationScope.project &&
              selection.projectRoot.isEmpty) ||
          (selection.resolution == InstallationTargetResolution.replace &&
              (selection.expectedReason.isEmpty ||
                  selection.expectedState.isEmpty)) ||
          (selection.resolution == InstallationTargetResolution.none &&
              (selection.expectedReason.isNotEmpty ||
                  selection.expectedState.isNotEmpty)) ||
          selection.mode == InstallationMode.external) {
        throw const SkillsException(
          'The Installation Target selection is invalid.',
          kind: SkillsFailureKind.validation,
        );
      }
    }
    await _ensureRegistryOrigin();
    final arguments = <String>['add', skill.id, '--skill', skill.skillId];
    for (final selection in selections) {
      arguments.addAll(['--target', _targetArgument(selection)]);
    }
    arguments.addAll([
      '--version',
      immutableVersion,
      if (riskConfirmed) '--confirm-risk',
      if (allowCritical) '--allow-critical',
      '--preflight',
      '--output',
      'json',
      '--registry',
      _registryOrigin,
    ]);
    final result = await _runCli(arguments);
    if (!result.succeeded) throw SkillsException(_commandError(result));
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != _installationPlanSchemaVersion ||
          decoded['phase'] != 'preflight' ||
          decoded['artifact'] is! Map<String, dynamic> ||
          decoded['targets'] is! List ||
          decoded['summary'] is! Map<String, dynamic> ||
          decoded['workspaceLockChanges'] is! List) {
        throw const FormatException();
      }
      final artifact = decoded['artifact'] as Map<String, dynamic>;
      if (artifact['source'] is! String ||
          artifact['coordinate'] != skill.id ||
          artifact['version'] != immutableVersion ||
          artifact['name'] != skill.skillId ||
          artifact['source'] != skill.id ||
          artifact['risk'] is! String) {
        throw const FormatException();
      }
      final trustedRiskAssessment = _riskAssessment(artifact['risk']);
      final rawTargets = decoded['targets'] as List;
      if (rawTargets.length != selections.length) throw const FormatException();
      final targets = <InstallationPlanItem>[];
      for (var index = 0; index < rawTargets.length; index++) {
        final raw = rawTargets[index];
        if (raw is! Map<String, dynamic> ||
            raw['workspaceLockChange'] is! bool ||
            (raw['reasonCode'] != null && raw['reasonCode'] is! String) ||
            (raw['stateToken'] != null && raw['stateToken'] is! String) ||
            (raw['affectedBindings'] != null &&
                raw['affectedBindings'] is! List)) {
          throw const FormatException();
        }
        final target = _installationPlanTarget(raw['target']);
        final selection = selections[index];
        if (target.scope != selection.scope ||
            target.projectRoot != selection.projectRoot ||
            target.agent != selection.agent ||
            target.mode != selection.mode) {
          throw const FormatException();
        }
        final action = _installationPlanAction(raw['action']);
        final reasonCode = _installationPlanReasonCode(raw['reasonCode']);
        if (!_validPlanReason(action, reasonCode)) {
          throw const FormatException();
        }
        final stateToken = raw['stateToken'] as String? ?? '';
        if ((action == InstallationPlanAction.conflict ||
                action == InstallationPlanAction.replace) &&
            stateToken.isEmpty) {
          throw const FormatException();
        }
        final affectedBindings =
            ((raw['affectedBindings'] as List?) ?? const [])
                .map(_installationAffectedBinding)
                .toList(growable: false);
        if (reasonCode == 'shared-target-conflict') {
          final bindingKeys = <String>{};
          var includesTargetBinding = false;
          for (final binding in affectedBindings) {
            final key = '${binding.scope.name}\u0000${binding.agent}';
            if (binding.path != target.path ||
                binding.scope != target.scope ||
                !bindingKeys.add(key)) {
              throw const FormatException();
            }
            if (binding.agent == target.agent) includesTargetBinding = true;
          }
          if (affectedBindings.length < 2 || !includesTargetBinding) {
            throw const FormatException();
          }
        }
        targets.add(
          InstallationPlanItem(
            target: target,
            action: action,
            workspaceLockChange: raw['workspaceLockChange'] as bool,
            reasonCode: reasonCode,
            stateToken: stateToken,
            affectedBindings: affectedBindings,
          ),
        );
      }
      final rawSummary = decoded['summary'] as Map<String, dynamic>;
      final summary = InstallationPlanSummary(
        create: _strictNonNegativeInt(rawSummary['create']),
        replace: _strictNonNegativeInt(rawSummary['replace']),
        skip: _strictNonNegativeInt(rawSummary['skip']),
        conflict: _strictNonNegativeInt(rawSummary['conflict']),
        blockedByRisk: _strictNonNegativeInt(rawSummary['blockedByRisk']),
      );
      final actionCounts = {
        for (final action in InstallationPlanAction.values)
          action: targets.where((item) => item.action == action).length,
      };
      if (summary.create != actionCounts[InstallationPlanAction.create] ||
          summary.replace != actionCounts[InstallationPlanAction.replace] ||
          summary.skip != actionCounts[InstallationPlanAction.skip] ||
          summary.conflict != actionCounts[InstallationPlanAction.conflict] ||
          summary.blockedByRisk !=
              actionCounts[InstallationPlanAction.blockedByRisk]) {
        throw const FormatException();
      }
      final lockRoots = <String>{};
      final lockChanges = (decoded['workspaceLockChanges'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['projectRoot'] is! String ||
                (raw['projectRoot'] as String).isEmpty ||
                raw['path'] is! String ||
                (raw['path'] as String).isEmpty ||
                raw['skill'] != skill.skillId ||
                raw['toVersion'] != artifact['version'] ||
                (raw['fromVersion'] != null && raw['fromVersion'] is! String) ||
                !lockRoots.add(raw['projectRoot'] as String)) {
              throw const FormatException();
            }
            return WorkspaceLockChange(
              projectRoot: raw['projectRoot'] as String,
              path: raw['path'] as String,
              skill: raw['skill'] as String,
              fromVersion: raw['fromVersion'] as String? ?? '',
              toVersion: raw['toVersion'] as String,
            );
          })
          .toList(growable: false);
      final expectedLockRoots = targets
          .where((item) => item.workspaceLockChange)
          .map((item) => item.target.projectRoot)
          .toSet();
      if (expectedLockRoots.length != lockRoots.length ||
          !expectedLockRoots.every(lockRoots.contains)) {
        throw const FormatException();
      }
      return InstallationPlan(
        source: artifact['source'] as String,
        coordinate: artifact['coordinate'] as String,
        version: artifact['version'] as String,
        name: artifact['name'] as String,
        selections: List.unmodifiable(selections),
        targets: List.unmodifiable(targets),
        summary: summary,
        workspaceLockChanges: lockChanges,
        riskAssessment: trustedRiskAssessment,
        riskConfirmed: riskConfirmed,
        allowCritical: allowCritical,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Installation Plan JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<InstallationExecution> executeInstall(InstallationPlan plan) async {
    await _ensureRegistryOrigin();
    final arguments = <String>['add', plan.source, '--skill', plan.name];
    for (final selection in plan.selections) {
      arguments.addAll(['--target', _targetArgument(selection)]);
    }
    arguments.addAll([
      '--version',
      plan.version,
      if (plan.riskConfirmed) '--confirm-risk',
      if (plan.allowCritical) '--allow-critical',
      '--yes',
      '--output',
      'json',
      '--registry',
      _registryOrigin,
    ]);
    final command = await _runCli(arguments);
    if (!command.succeeded) throw SkillsException(_commandError(command));
    try {
      final decoded = jsonDecode(command.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != _installationPlanSchemaVersion ||
          decoded['phase'] != 'execution' ||
          decoded['artifact'] is! Map<String, dynamic> ||
          decoded['results'] is! List ||
          decoded['summary'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final artifact = decoded['artifact'] as Map<String, dynamic>;
      if (artifact['source'] != plan.source ||
          artifact['coordinate'] != plan.coordinate ||
          artifact['version'] != plan.version ||
          artifact['name'] != plan.name) {
        throw const FormatException();
      }
      final rawResults = decoded['results'] as List;
      if (rawResults.length != plan.targets.length) {
        throw const FormatException();
      }
      final results = <InstallationTargetResult>[];
      for (var index = 0; index < rawResults.length; index++) {
        final raw = rawResults[index];
        if (raw is! Map<String, dynamic> ||
            (raw['errorCode'] != null && raw['errorCode'] is! String) ||
            (raw['diagnostic'] != null && raw['diagnostic'] is! String)) {
          throw const FormatException();
        }
        final target = _installationPlanTarget(raw['target']);
        final action = _installationPlanAction(raw['action']);
        if (!_samePlanTarget(target, plan.targets[index].target) ||
            action != plan.targets[index].action) {
          throw const FormatException();
        }
        final outcome = _installationTargetOutcome(raw['outcome']);
        final errorCode = _installationErrorCode(raw['errorCode']);
        if ((outcome == InstallationTargetOutcome.succeeded ||
                outcome == InstallationTargetOutcome.skipped) &&
            errorCode.isNotEmpty) {
          throw const FormatException();
        }
        if ((outcome == InstallationTargetOutcome.conflict ||
                outcome == InstallationTargetOutcome.failed) &&
            errorCode.isEmpty) {
          throw const FormatException();
        }
        results.add(
          InstallationTargetResult(
            target: target,
            action: action,
            outcome: outcome,
            errorCode: errorCode,
            diagnostic: raw['diagnostic'] as String? ?? '',
          ),
        );
      }
      final rawSummary = decoded['summary'] as Map<String, dynamic>;
      final summary = InstallationExecutionSummary(
        succeeded: _strictNonNegativeInt(rawSummary['succeeded']),
        skipped: _strictNonNegativeInt(rawSummary['skipped']),
        conflict: _strictNonNegativeInt(rawSummary['conflict']),
        failed: _strictNonNegativeInt(rawSummary['failed']),
      );
      final outcomeCounts = {
        for (final outcome in InstallationTargetOutcome.values)
          outcome: results.where((result) => result.outcome == outcome).length,
      };
      if (summary.succeeded !=
              outcomeCounts[InstallationTargetOutcome.succeeded] ||
          summary.skipped != outcomeCounts[InstallationTargetOutcome.skipped] ||
          summary.conflict !=
              outcomeCounts[InstallationTargetOutcome.conflict] ||
          summary.failed != outcomeCounts[InstallationTargetOutcome.failed]) {
        throw const FormatException();
      }
      return InstallationExecution(
        coordinate: plan.coordinate,
        version: plan.version,
        name: plan.name,
        results: List.unmodifiable(results),
        summary: summary,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Installation Result JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<CommandResult> install(SkillSummary skill) async {
    await _ensureRegistryOrigin();
    return _runCli([
      'add',
      skill.id,
      '--skill',
      skill.skillId,
      '--global',
      '--agent',
      'codex',
      '--yes',
      '--output',
      'json',
      '--registry',
      _registryOrigin,
    ]);
  }

  @override
  Future<CommandResult> remove(InstalledSkill skill) async {
    if (skill.provenance == LibraryProvenance.external) {
      throw const SkillsException(
        'External Installations are read-only until adoption.',
        kind: SkillsFailureKind.validation,
      );
    }
    return _runCli(['remove', skill.name, '--global', '--yes']);
  }

  @override
  Future<CommandResult> update(InstalledSkill skill) async {
    if (skill.provenance == LibraryProvenance.external) {
      throw const SkillsException(
        'External Installations are read-only until adoption.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureRegistryOrigin();
    return _runCli([
      'update',
      skill.name,
      '--global',
      '--yes',
      '--registry',
      _registryOrigin,
    ]);
  }

  @override
  Future<Map<String, UpdateState>> checkUpdates(
    List<InstalledSkill> skills,
  ) async {
    final states = {
      for (final skill in skills)
        if (skill.provenance == LibraryProvenance.external)
          skill.name: UpdateState.unsupported,
    };
    final managed = skills
        .where((skill) => skill.provenance == LibraryProvenance.registry)
        .toList(growable: false);
    if (managed.isEmpty) return states;
    await _ensureRegistryOrigin();
    final arguments = <String>[
      'update',
      ...managed.map((skill) => skill.name),
      '--global',
      '--check',
      '--output',
      'json',
      '--registry',
      _registryOrigin,
    ];
    final result = await _runCli(arguments);
    if (!result.succeeded) {
      states.addAll({
        for (final skill in managed) skill.name: UpdateState.failed,
      });
      return states;
    }
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! List) throw const FormatException();
      states.addAll({
        for (final skill in managed) skill.name: UpdateState.unsupported,
      });
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic> ||
            raw['name'] is! String ||
            raw['available'] is! bool) {
          throw const FormatException();
        }
        states[raw['name'] as String] = raw['available'] as bool
            ? UpdateState.available
            : UpdateState.upToDate;
      }
      return states;
    } catch (_) {
      states.addAll({
        for (final skill in managed) skill.name: UpdateState.failed,
      });
      return states;
    }
  }

  String _commandError(CommandResult result) {
    final stderr = result.output.stderr.trim();
    return stderr.isEmpty
        ? 'SkillsGo CLI exited with code ${result.output.exitCode}.'
        : stderr;
  }
}
