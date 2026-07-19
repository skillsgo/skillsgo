/*
 * [INPUT]: Depends on the bundled CLI process boundary plus legacy Hub HTTP reads pending migration, the local filesystem, the platform directory picker, and SharedPreferences-backed product preferences.
 * [OUTPUT]: Provides typed CLI-backed business operations including versioned machine-failure parsing and Batch Takeover, plus temporary legacy Hub discovery/detail reads, local inspection, project persistence, diagnostics, and appearance/wallpaper settings.
 * [POS]: Serves as the App infrastructure adapter for the CLI-mediated business boundary while temporarily isolating legacy direct Hub reads scheduled for removal.
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
typedef SavePathPicker = Future<String?> Function(String suggestedName);
typedef ProjectPathInspector =
    Future<({ProjectAccessState state, String? diagnostic})> Function(
      String path,
    );

class IoProcessRunner implements ProcessRunner {
  const IoProcessRunner();

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    try {
      if (onStdoutLine != null) {
        final process = await Process.start(executable, arguments);
        final stdout = StringBuffer();
        final stdoutDone = Completer<void>();
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (stdout.isNotEmpty) stdout.writeln();
                stdout.write(line);
                onStdoutLine(line);
              },
              onError: stdoutDone.completeError,
              onDone: stdoutDone.complete,
              cancelOnError: true,
            );
        final stderrFuture = process.stderr.transform(utf8.decoder).join();
        var timedOut = false;
        late int exitCode;
        try {
          exitCode = await process.exitCode.timeout(const Duration(minutes: 2));
        } on TimeoutException {
          timedOut = true;
          process.kill();
          exitCode = await process.exitCode;
        }
        await stdoutDone.future;
        final stderr = await stderrFuture;
        return ProcessOutput(
          exitCode: timedOut ? 124 : exitCode,
          stdout: stdout.toString(),
          stderr: timedOut ? 'Command timed out.' : stderr,
        );
      }
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
const _installationPlanSchemaVersion = 3;

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

InstallationExecution _directInstallationExecution(
  Object? raw,
  SkillSummary skill,
  String immutableVersion,
  List<InstallationTargetSelection> selections,
) {
  if (raw is! Map<String, dynamic> ||
      raw['schemaVersion'] != _installationPlanSchemaVersion ||
      raw['phase'] != 'execution' ||
      raw['artifact'] is! Map<String, dynamic> ||
      raw['results'] is! List ||
      raw['summary'] is! Map<String, dynamic>) {
    throw const FormatException();
  }
  final artifact = raw['artifact'] as Map<String, dynamic>;
  if (artifact['source'] != skill.id ||
      artifact['skillId'] != skill.id ||
      artifact['version'] != immutableVersion ||
      artifact['name'] != skill.installName) {
    throw const FormatException();
  }
  final rawResults = raw['results'] as List;
  if (rawResults.length != selections.length) throw const FormatException();
  final results = <InstallationTargetResult>[];
  for (var index = 0; index < rawResults.length; index++) {
    final result = rawResults[index];
    if (result is! Map<String, dynamic>) throw const FormatException();
    final target = _installationPlanTarget(result['target']);
    final selection = selections[index];
    if (target.scope != selection.scope ||
        target.projectRoot != selection.projectRoot ||
        target.agent != selection.agent ||
        target.mode != selection.mode) {
      throw const FormatException();
    }
    final action = _installationPlanAction(result['action']);
    final outcome = _installationTargetOutcome(result['outcome']);
    if (result.containsKey('errorCode') || result.containsKey('diagnostic')) {
      throw const FormatException();
    }
    final error = _targetFailure(result['error']);
    if ((outcome == InstallationTargetOutcome.succeeded ||
            outcome == InstallationTargetOutcome.skipped) &&
        error != null) {
      throw const FormatException();
    }
    if ((outcome == InstallationTargetOutcome.conflict ||
            outcome == InstallationTargetOutcome.failed) &&
        error == null) {
      throw const FormatException();
    }
    results.add(
      InstallationTargetResult(
        target: target,
        action: action,
        outcome: outcome,
        error: error,
      ),
    );
  }
  final rawSummary = raw['summary'] as Map<String, dynamic>;
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
  if (summary.succeeded != outcomeCounts[InstallationTargetOutcome.succeeded] ||
      summary.skipped != outcomeCounts[InstallationTargetOutcome.skipped] ||
      summary.conflict != outcomeCounts[InstallationTargetOutcome.conflict] ||
      summary.failed != outcomeCounts[InstallationTargetOutcome.failed]) {
    throw const FormatException();
  }
  return InstallationExecution(
    skillId: skill.id,
    version: immutableVersion,
    name: skill.installName,
    results: List.unmodifiable(results),
    summary: summary,
  );
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
      'stop-managing' => TargetManagementAction.stopManaging,
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
      TargetManagementAction.stopManaging => 'stop-managing',
    };

ExternalAdoptionAction _externalAdoptionAction(Object? value) =>
    switch (value) {
      'associate-hub' => ExternalAdoptionAction.associateHub,
      'import-local' => ExternalAdoptionAction.importLocal,
      _ => throw const FormatException(),
    };

String _externalAdoptionActionValue(ExternalAdoptionAction action) =>
    switch (action) {
      ExternalAdoptionAction.associateHub => 'associate-hub',
      ExternalAdoptionAction.importLocal => 'import-local',
    };

bool _isSha256Digest(Object? value) =>
    value is String && RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);

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
    String hubBaseUrl = 'https://hub.skillsgo.ai',
    String? appVersion,
    this.discoveryTimeout = const Duration(seconds: 15),
    this.detailTimeout = const Duration(seconds: 20),
    DirectoryPicker? directoryPicker,
    SavePathPicker? savePathPicker,
    ProjectPathInspector? projectPathInspector,
  }) : _http = httpClient ?? http.Client(),
       _runner = processRunner ?? const IoProcessRunner(),
       _cliPath = initialCliPath,
       _bundledCliPath =
           bundledCliPath ?? _bundledPathFor(Platform.resolvedExecutable),
       _expectedCliOS = expectedCliOS ?? _goOperatingSystem,
       _defaultHubBase = _originUri(hubBaseUrl),
       _hubBase = _originUri(hubBaseUrl),
       _injectedAppVersion = appVersion,
       _directoryPicker = directoryPicker ?? _pickDirectory,
       _savePathPicker = savePathPicker ?? _pickSavePath,
       _projectPathInspector = projectPathInspector ?? _inspectProjectPath;

  static const _customCliKey = 'custom_cli_path';
  static const _hubOriginKey = 'hub_origin';
  static const _folderThemeKey = 'folder_theme';
  static const _wallpaperKey = 'wallpaper';
  static const _themeModeKey = 'theme_mode';
  static const _allowCriticalOverrideKey = 'allow_critical_risk_override';
  static const _addedProjectsKey = 'added_projects_v1';
  static const _startupHandshakeSchemaVersion = 1;
  static const _appProtocolVersion = 9;
  final http.Client _http;
  final ProcessRunner _runner;
  final Uri _defaultHubBase;
  Uri _hubBase;
  final String _bundledCliPath;
  final bool allowDeveloperCliOverride;
  final String _expectedCliOS;
  final String? _injectedAppVersion;
  final Duration discoveryTimeout;
  final Duration detailTimeout;
  final DirectoryPicker _directoryPicker;
  final SavePathPicker _savePathPicker;
  final ProjectPathInspector _projectPathInspector;
  String? _cliPath;
  bool _hubOriginLoaded = false;

  static Future<String?> _pickDirectory({String? initialDirectory}) =>
      file_selector.getDirectoryPath(initialDirectory: initialDirectory);

  static Future<String?> _pickSavePath(String suggestedName) async =>
      (await file_selector.getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          file_selector.XTypeGroup(label: 'ZIP archive', extensions: ['zip']),
        ],
      ))?.path;

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
      throw const FormatException('Hub Origin must be an HTTP(S) URL.');
    }
    return Uri.parse(value.endsWith('/') ? value : '$value/');
  }

  String get _hubOrigin => _hubBase.toString().replaceFirst(RegExp(r'/$'), '');

  Future<void> _ensureHubOrigin() async {
    if (_hubOriginLoaded) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_hubOriginKey);
    if (saved != null) {
      try {
        _hubBase = _originUri(saved);
      } on FormatException {
        await preferences.remove(_hubOriginKey);
      }
    }
    _hubOriginLoaded = true;
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

  @override
  Future<String> loadFolderTheme() async {
    final saved =
        (await SharedPreferences.getInstance()).getString(_folderThemeKey) ??
        '#514532';
    return const {
          'manila': '#514532',
          'blue': '#294556',
          'sage': '#3D5141',
          'charcoal': '#292A2B',
        }[saved] ??
        saved;
  }

  @override
  Future<void> saveFolderTheme(String theme) async {
    final normalized = theme.toUpperCase();
    final valid = RegExp(r'^#[0-9A-F]{6}$').hasMatch(normalized);
    await (await SharedPreferences.getInstance()).setString(
      _folderThemeKey,
      valid ? normalized : '#514532',
    );
  }

  @override
  Future<AppWallpaper> loadWallpaper() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _wallpaperKey,
    );
    return AppWallpaper.values.firstWhere(
      (wallpaper) => wallpaper.name == saved,
      orElse: () => AppWallpaper.sun,
    );
  }

  @override
  Future<void> saveWallpaper(AppWallpaper wallpaper) async {
    await (await SharedPreferences.getInstance()).setString(
      _wallpaperKey,
      wallpaper.name,
    );
  }

  @override
  Future<AppThemeMode> loadThemeMode() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _themeModeKey,
    );
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => AppThemeMode.system,
    );
  }

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    await (await SharedPreferences.getInstance()).setString(
      _themeModeKey,
      mode.name,
    );
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
  Future<String> loadHubOrigin() async {
    await _ensureHubOrigin();
    return _hubOrigin;
  }

  @override
  Future<void> saveHubOrigin(String origin) async {
    final parsed = _originUri(origin);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _hubOriginKey,
      parsed.toString().replaceFirst(RegExp(r'/$'), ''),
    );
    _hubBase = parsed;
    _hubOriginLoaded = true;
  }

  @override
  Future<void> resetHubOrigin() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_hubOriginKey);
    _hubBase = _defaultHubBase;
    _hubOriginLoaded = true;
  }

  @override
  Future<HubStatus> testHubOrigin(String origin) async {
    final Uri base;
    try {
      base = _originUri(origin);
    } on FormatException catch (error) {
      return HubStatus(
        origin: origin.trim(),
        state: HealthState.invalid,
        issue: HubIssue.invalidOrigin,
        diagnostic: error.message,
      );
    }
    final normalized = base.toString().replaceFirst(RegExp(r'/$'), '');
    final uri = base
        .resolve('api/v1/search')
        .replace(
          queryParameters: const {'q': 'skillsgo-settings-probe', 'limit': '1'},
        );
    try {
      final response = await _http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return HubStatus(
          origin: normalized,
          state: HealthState.unreachable,
          issue: HubIssue.httpFailure,
          httpStatus: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['skills'] is! List) {
        return HubStatus(
          origin: normalized,
          state: HealthState.invalid,
          issue: HubIssue.invalidProtocol,
        );
      }
      return HubStatus(origin: normalized, state: HealthState.ready);
    } on SocketException catch (error) {
      return HubStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: HubIssue.connectionFailure,
        diagnostic: error.message,
      );
    } on TimeoutException {
      return HubStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: HubIssue.timeout,
      );
    } on FormatException {
      return HubStatus(
        origin: normalized,
        state: HealthState.invalid,
        issue: HubIssue.invalidJson,
      );
    } on http.ClientException catch (error) {
      return HubStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: HubIssue.connectionFailure,
        diagnostic: error.message,
      );
    } on Object catch (error) {
      return HubStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: HubIssue.connectionFailure,
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
    await _ensureHubOrigin();
    if (collection == DiscoveryCollection.search &&
        _looksLikeExplicitSkillSource(trimmedQuery)) {
      return _discoverExplicitSource(trimmedQuery);
    }
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
    final uri = _hubBase
        .resolve(
          collection == DiscoveryCollection.search
              ? 'api/v1/search'
              : 'api/v1/skills',
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
      final rawSkills = decoded['skills'] as List;
      if (collection == DiscoveryCollection.search &&
          offset == 0 &&
          rawSkills.isEmpty &&
          _looksLikeGitHubRepositoryShorthand(trimmedQuery)) {
        return _discoverExplicitSource('github.com/$trimmedQuery');
      }
      final installedCounts = <String, int>{};
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        for (final skill in installed) {
          if (skill.skillId.isNotEmpty) {
            installedCounts[skill.skillId] = skill.targetCount;
          }
        }
      } on Object {
        // Discovery remains available when local CLI inventory is unavailable.
      }
      final skills = rawSkills
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const SkillsException(
                'Invalid discovery result.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            final source = raw['source'];
            final installName =
                raw['skillPath'] is String &&
                    (raw['skillPath'] as String).isNotEmpty
                ? p.basename(raw['skillPath'] as String)
                : raw['name'];
            final id = raw['id'];
            final name = raw['name'];
            final description = raw['description'];
            final version = raw['latestVersion'];
            final metric = raw['metric'];
            if (source is! String ||
                installName is! String ||
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
            final imageUrl = raw['imageUrl'];
            if (imageUrl != null && imageUrl is! String) {
              throw const SkillsException(
                'Discovery image URL is invalid.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            return SkillSummary(
              id: id,
              installName: installName,
              name: name,
              source: source,
              imageUrl: imageUrl as String?,
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
        'The Hub connection failed.',
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

  static bool _looksLikeExplicitSkillSource(String query) {
    final value = query.trim();
    if (value.contains('://') || value.startsWith('git@')) return true;
    if (value.contains(RegExp(r'\s'))) return false;
    final coordinate = value.split('@').first;
    final segments = coordinate.split('/');
    return segments.length >= 3 && segments.first.contains('.');
  }

  static bool _looksLikeGitHubRepositoryShorthand(String query) =>
      RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(query);

  Future<DiscoveryPage> _discoverExplicitSource(String source) async {
    final result = await _runCli([
      'info',
      source,
      '--hub',
      _hubOrigin,
      '--output',
      'json',
    ]);
    if (!result.succeeded) throw _commandFailure(result);
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['SchemaVersion'] != 1 ||
          decoded['Kind'] is! String) {
        throw const FormatException('Invalid SkillsGo Info response.');
      }
      final rawSkills = switch (decoded['Kind']) {
        'Skill' => <Object?>[decoded],
        'Repository' when decoded['Skills'] is List =>
          decoded['Skills'] as List,
        _ => throw const FormatException('Unknown SkillsGo Info kind.'),
      };
      final installedCounts = <String, int>{};
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        for (final skill in installed) {
          if (skill.skillId.isNotEmpty) {
            installedCounts[skill.skillId] = skill.targetCount;
          }
        }
      } on Object {
        // Explicit-source discovery remains useful without local inventory.
      }
      final skills = rawSkills
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Invalid Skill Info member.');
            }
            final id = raw['ID'];
            final name = raw['Name'];
            final description = raw['Description'];
            final version = raw['Version'];
            final installs = raw['Installs'];
            if (id is! String ||
                name is! String ||
                description is! String ||
                version is! String ||
                installs is! num) {
              throw const FormatException('Incomplete Skill Info member.');
            }
            final imageURL = raw['ImageURL'];
            if (imageURL != null && imageURL is! String) {
              throw const FormatException('Invalid Skill Info image URL.');
            }
            final repository = id.split('/-/').first;
            return SkillSummary(
              id: id,
              installName: name,
              name: name,
              source: repository,
              imageUrl: imageURL as String?,
              description: description,
              installs: installs.toInt(),
              latestVersion: version,
              trustLevel: _trustLevel(raw['TrustLevel']),
              riskAssessment: _riskAssessment(raw['RiskAssessment']),
              localTargetCount: installedCounts[id] ?? 0,
            );
          })
          .toList(growable: false);
      final firstSkill = rawSkills.isEmpty ? null : rawSkills.first;
      final firstSkillMap = firstSkill is Map<String, dynamic>
          ? firstSkill
          : null;
      final repositoryID = decoded['Kind'] == 'Repository'
          ? decoded['ID']
          : skills.isEmpty
          ? null
          : skills.first.source;
      final repositoryTime = decoded['Time'];
      return DiscoveryPage(
        skills: skills,
        repository: repositoryID is String
            ? RepositorySummary(
                id: repositoryID,
                imageUrl: firstSkillMap?['ImageURL'] as String?,
                description: decoded['Description'] is String
                    ? decoded['Description'] as String
                    : '',
                stars: firstSkillMap?['Stars'] is num
                    ? (firstSkillMap!['Stars'] as num).toInt()
                    : 0,
                latestVersion: decoded['Version'] is String
                    ? decoded['Version'] as String
                    : skills.isEmpty
                    ? ''
                    : skills.first.latestVersion,
                updatedAt: repositoryTime is String
                    ? DateTime.tryParse(repositoryTime)
                    : null,
                license: decoded['License'] is String
                    ? decoded['License'] as String
                    : null,
              )
            : null,
      );
    } on FormatException {
      throw const SkillsException(
        'SkillsGo Info returned invalid JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill) async {
    await _ensureHubOrigin();
    final uri = _hubBase.resolve('api/v1/skills/${skill.id}');
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
        'id',
        'name',
        'description',
        'source',
        'repository',
        'requestedVersion',
        'immutableVersion',
        'commitSHA',
        'treeSHA',
        'sourceRef',
        'contentDigest',
        'instructions',
        'trustLevel',
      ];
      if (requiredStrings.any((field) => decoded[field] is! String) ||
          (decoded['imageUrl'] != null && decoded['imageUrl'] is! String) ||
          decoded['installs'] is! num ||
          decoded['stars'] is! num ||
          decoded['sourceUpdatedAt'] is! String ||
          decoded['archiveSize'] is! num ||
          decoded['id'] != skill.id ||
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
            .where((entry) => entry.skillId == skill.id)
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
        imageUrl: decoded['imageUrl'] as String?,
        installs: (decoded['installs'] as num).toInt(),
        repository: decoded['repository'] as String,
        stars: (decoded['stars'] as num).toInt(),
        sourceUpdatedAt: DateTime.parse(
          decoded['sourceUpdatedAt'] as String,
        ).toLocal(),
        archiveSize: (decoded['archiveSize'] as num).toInt(),
        description: decoded['description'] as String,
        requestedVersion: decoded['requestedVersion'] as String,
        immutableVersion: decoded['immutableVersion'] as String,
        commitSHA: decoded['commitSHA'] as String,
        treeSHA: decoded['treeSHA'] as String,
        sourceRef: decoded['sourceRef'] as String,
        contentDigest: decoded['contentDigest'] as String,
        trustLevel: _trustLevel(decoded['trustLevel']),
        riskAssessment: _riskAssessment(risk['level']),
        riskScannerVersion: risk['scannerVersion'] as String,
        riskEvidence: evidence,
        installationTargets: installationTargets,
        hubExecutableSignal: decoded['hasExecutableContent'] as bool,
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
        'The Hub connection failed.',
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

  Future<CommandResult> _runCli(
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    if (_cliPath == null) {
      final status = await detectCli();
      if (!status.isReady) {
        throw SkillsException(
          status.message ?? 'The SkillsGo CLI is not ready. Open Settings.',
          kind: status.issue == CliIssue.damaged
              ? SkillsFailureKind.invalidLocalData
              : SkillsFailureKind.server,
        );
      }
    }
    final executable = _requiredCli;
    final output = await _runner.run(
      executable,
      arguments,
      onStdoutLine: onStdoutLine,
    );
    return CommandResult(command: [executable, ...arguments], output: output);
  }

  @override
  Future<AgentCatalog> inspectAgents() async {
    final result = await _runCli(const ['agents', '--output', 'json']);
    if (!result.succeeded) throw _commandFailure(result);
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
        kind: SkillsFailureKind.invalidLocalData,
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
    if (!result.succeeded) throw _commandFailure(result);
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
                raw['inventoryKey'] is! String ||
                (raw['inventoryKey'] as String).isEmpty ||
                raw['name'] is! String ||
                (raw['name'] as String).isEmpty ||
                (raw['description'] != null && raw['description'] is! String) ||
                raw['skillId'] is! String ||
                raw['versionDivergence'] is! bool ||
                raw['targets'] is! List ||
                raw['visibility'] is! List) {
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
                  if ((scope == InstallationScope.project &&
                          projectRoot.isEmpty) ||
                      (scope == InstallationScope.user &&
                          projectRoot.isNotEmpty) ||
                      (provenance == LibraryProvenance.external &&
                          (version.isNotEmpty ||
                              mode != InstallationMode.external)) ||
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
                    health: _installationHealth(target['health']),
                  );
                })
                .toList(growable: false);
            if (targets.isEmpty) throw const FormatException();
            final agents = _strictStringList(raw['agents']);
            final projectRoots = _strictStringList(raw['projects']);
            final versions = _strictStringList(raw['versions']);
            final visibilityKeys = <String>{};
            final visibility = (raw['visibility'] as List)
                .map((item) {
                  if (item is! Map<String, dynamic> ||
                      item['agent'] is! String ||
                      (item['agent'] as String).isEmpty ||
                      item['paths'] is! List ||
                      (item['projectRoot'] != null &&
                          item['projectRoot'] is! String)) {
                    throw const FormatException();
                  }
                  final scope = _installationScope(item['scope']);
                  final projectRoot = item['projectRoot'] as String? ?? '';
                  final paths = _strictStringList(item['paths']);
                  final key =
                      '${item['agent']}\u0000${item['scope']}\u0000$projectRoot';
                  if (paths.isEmpty ||
                      (scope == InstallationScope.project &&
                          projectRoot.isEmpty) ||
                      (scope == InstallationScope.user &&
                          projectRoot.isNotEmpty) ||
                      !visibilityKeys.add(key)) {
                    throw const FormatException();
                  }
                  return SkillVisibility(
                    agent: item['agent'] as String,
                    scope: scope,
                    projectRoot: projectRoot,
                    paths: paths,
                    verification: _discoveryVerification(item['verification']),
                  );
                })
                .toList(growable: false);
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
            if (provenance == LibraryProvenance.hub &&
                ((raw['skillId'] as String).isEmpty ||
                    raw['inventoryKey'] != 'hub:${raw['skillId']}')) {
              throw const FormatException();
            }
            if (provenance == LibraryProvenance.external &&
                ((raw['skillId'] as String).isNotEmpty ||
                    versions.isNotEmpty ||
                    !(raw['inventoryKey'] as String).startsWith('external:'))) {
              throw const FormatException();
            }
            return InstalledSkill(
              inventoryKey: raw['inventoryKey'] as String,
              name: raw['name'] as String,
              description: raw['description'] as String? ?? '',
              path: targets.first.path,
              agents: agents,
              targetCount: targets.length,
              skillId: raw['skillId'] as String,
              targets: targets,
              visibility: visibility,
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
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
  }

  @override
  Future<BatchTakeoverResult> takeoverExistingSkills({
    String? projectRoot,
  }) async {
    final normalizedProject = projectRoot?.trim();
    if (projectRoot != null && normalizedProject!.isEmpty) {
      throw const SkillsException(
        'Batch Takeover Workspace must not be empty.',
        kind: SkillsFailureKind.validation,
      );
    }
    final command = await _runCli([
      'takeover',
      if (normalizedProject != null) ...['--project', normalizedProject],
      '--yes',
      '--output',
      'json',
    ]);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final raw = jsonDecode(command.output.stdout);
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] != 1 ||
          raw['summary'] is! Map<String, dynamic> ||
          raw['results'] is! List) {
        throw const FormatException();
      }
      final summary = raw['summary'] as Map<String, dynamic>;
      final takenOver = summary['takenOver'];
      final skipped = summary['skipped'];
      if (takenOver is! int ||
          takenOver < 0 ||
          skipped is! int ||
          skipped < 0) {
        throw const FormatException();
      }
      var actualTakenOver = 0;
      var actualSkipped = 0;
      for (final item in raw['results'] as List) {
        if (item is! Map<String, dynamic> ||
            item['status'] is! String ||
            item['target'] is! Map<String, dynamic>) {
          throw const FormatException();
        }
        final target = item['target'] as Map<String, dynamic>;
        if (target['scope'] != 'user' && target['scope'] != 'project' ||
            target['mode'] != 'copy' && target['mode'] != 'symlink' ||
            target['path'] is! String) {
          throw const FormatException();
        }
        switch (item['status']) {
          case 'taken-over':
            if (item['skillId'] is! String ||
                (item['skillId'] as String).isEmpty ||
                item['version'] is! String ||
                (item['version'] as String).isEmpty ||
                (target['path'] as String).isEmpty) {
              throw const FormatException();
            }
            actualTakenOver++;
          case 'skipped':
            if (item['reason'] is! String ||
                (item['reason'] as String).isEmpty) {
              throw const FormatException();
            }
            actualSkipped++;
          default:
            throw const FormatException();
        }
      }
      if (actualTakenOver != takenOver || actualSkipped != skipped) {
        throw const FormatException();
      }
      return BatchTakeoverResult(takenOver: takenOver, skipped: skipped);
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Batch Takeover JSON.',
        kind: SkillsFailureKind.invalidLocalData,
      );
    }
  }

  @override
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill) async {
    final immutableVersions = {
      ...skill.versions.where((version) => version.isNotEmpty),
      ...skill.targets
          .map((target) => target.version)
          .where((version) => version.isNotEmpty),
    };
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
            LibraryProvenance.hub => 'Hub',
            LibraryProvenance.local => 'Local',
            LibraryProvenance.external => 'External',
          },
          markdown: markdown,
          files: files,
          immutableVersion: immutableVersions.length == 1
              ? immutableVersions.single
              : '',
          riskAssessment: skill.riskAssessment,
          riskEvidence: executableFiles,
          installationTargets: skill.targets,
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
  Future<InstallationExecution> installTargets(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  }) async {
    if (immutableVersion.isEmpty || selections.isEmpty) {
      throw const SkillsException(
        'Select at least one Installation Target.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final arguments = <String>['add', skill.id, '--skill', skill.installName];
    for (final selection in selections) {
      arguments.addAll(['--target', _targetArgument(selection)]);
    }
    arguments.addAll([
      '--version',
      immutableVersion,
      if (confirmRisk) '--confirm-risk',
      if (allowCritical) '--allow-critical',
      '--yes',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
    ]);
    final command = await _runCli(arguments);
    try {
      return _directInstallationExecution(
        jsonDecode(command.output.stdout),
        skill,
        immutableVersion,
        selections,
      );
    } on FormatException {
      if (!command.succeeded) throw _commandFailure(command);
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Installation Result JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<CommandResult> install(SkillSummary skill) async {
    await _ensureHubOrigin();
    return _runCli([
      'add',
      skill.id,
      '--skill',
      skill.installName,
      '--global',
      '--agent',
      'codex',
      '--yes',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
    ]);
  }

  Map<String, dynamic> _externalAdoptionTarget(
    InstalledSkill skill,
    SkillInstallationTarget target, {
    ExternalAdoptionAction? action,
    HubContentMatch? match,
    String? stateToken,
  }) => {
    'inventoryKey': skill.inventoryKey,
    'name': skill.name,
    'scope': target.scope.name,
    if (target.scope == InstallationScope.project)
      'projectRoot': target.projectRoot,
    'agent': target.agent,
    'path': target.path,
    if (action != null) 'action': _externalAdoptionActionValue(action),
    if (match != null) 'matchSkillId': match.skillId,
    if (match != null) 'matchVersion': match.immutableVersion,
    'stateToken': ?stateToken,
  };

  @override
  Future<ExternalAdoptionPlan> preflightExternalAdoption(
    InstalledSkill skill,
  ) async {
    if (skill.provenance != LibraryProvenance.external ||
        skill.targets.length != 1 ||
        skill.targets.single.mode != InstallationMode.external) {
      throw const SkillsException(
        'Adoption requires one exact External Installation.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final sourceTarget = skill.targets.single;
    final command = await _runCli([
      'adopt',
      '--target',
      jsonEncode(_externalAdoptionTarget(skill, sourceTarget)),
      '--preflight',
      '--output',
      'json',
      '--hub',
      _hubOrigin,
    ]);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final raw = jsonDecode(command.output.stdout);
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] != 1 ||
          raw['phase'] != 'adoption-preflight' ||
          raw['inventoryKey'] != skill.inventoryKey ||
          raw['name'] != skill.name ||
          !_isSha256Digest(raw['contentDigest']) ||
          raw['stateToken'] is! String ||
          (raw['stateToken'] as String).isEmpty ||
          raw['matches'] is! List ||
          raw['canImportLocal'] is! bool ||
          (raw['sourceHint'] != null && raw['sourceHint'] is! String)) {
        throw const FormatException();
      }
      final targetRaw = raw['target'];
      if (targetRaw is! Map<String, dynamic> ||
          targetRaw['scope'] != sourceTarget.scope.name ||
          (targetRaw['projectRoot'] ?? '') != sourceTarget.projectRoot ||
          targetRaw['agent'] != sourceTarget.agent ||
          targetRaw['path'] != sourceTarget.path) {
        throw const FormatException();
      }
      final matches = <HubContentMatch>[];
      final seen = <String>{};
      for (final candidate in raw['matches'] as List) {
        if (candidate is! Map<String, dynamic> ||
            candidate['skillId'] is! String ||
            (candidate['skillId'] as String).isEmpty ||
            candidate['name'] is! String ||
            (candidate['name'] as String).isEmpty ||
            candidate['source'] is! String ||
            (candidate['source'] as String).isEmpty ||
            candidate['skillPath'] is! String ||
            candidate['immutableVersion'] is! String ||
            (candidate['immutableVersion'] as String).isEmpty ||
            candidate['commitSHA'] is! String ||
            (candidate['commitSHA'] as String).isEmpty ||
            candidate['treeSHA'] is! String ||
            (candidate['treeSHA'] as String).isEmpty ||
            candidate['contentDigest'] != raw['contentDigest']) {
          throw const FormatException();
        }
        final key =
            '${candidate['skillId']}\u0000${candidate['immutableVersion']}';
        if (!seen.add(key)) throw const FormatException();
        matches.add(
          HubContentMatch(
            skillId: candidate['skillId'] as String,
            name: candidate['name'] as String,
            source: candidate['source'] as String,
            skillPath: candidate['skillPath'] as String,
            immutableVersion: candidate['immutableVersion'] as String,
            commitSHA: candidate['commitSHA'] as String,
            treeSHA: candidate['treeSHA'] as String,
            contentDigest: candidate['contentDigest'] as String,
          ),
        );
      }
      return ExternalAdoptionPlan(
        inventoryKey: skill.inventoryKey,
        name: skill.name,
        target: InstallationPlanTarget(
          scope: sourceTarget.scope,
          projectRoot: sourceTarget.projectRoot,
          agent: sourceTarget.agent,
          mode: InstallationMode.copy,
          path: sourceTarget.path,
        ),
        contentDigest: raw['contentDigest'] as String,
        sourceHint: raw['sourceHint'] as String? ?? '',
        stateToken: raw['stateToken'] as String,
        matches: List.unmodifiable(matches),
        canImportLocal: raw['canImportLocal'] as bool,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid External Adoption Plan JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<ExternalAdoptionResult> executeExternalAdoption(
    ExternalAdoptionPlan plan,
  ) async {
    final action = plan.action;
    final selected = plan.selectedMatch;
    final reviewedMatch =
        selected != null &&
        plan.matches.any(
          (candidate) =>
              candidate.skillId == selected.skillId &&
              candidate.immutableVersion == selected.immutableVersion &&
              candidate.contentDigest == plan.contentDigest,
        );
    if (action == null ||
        (action == ExternalAdoptionAction.associateHub && !reviewedMatch) ||
        (action == ExternalAdoptionAction.importLocal &&
            !plan.canImportLocal)) {
      throw const SkillsException(
        'Adoption execution requires an explicitly reviewed action.',
        kind: SkillsFailureKind.validation,
      );
    }
    final sourceTarget = SkillInstallationTarget(
      agent: plan.target.agent,
      scope: plan.target.scope,
      projectRoot: plan.target.projectRoot,
      path: plan.target.path,
      version: '',
      mode: InstallationMode.external,
    );
    final skill = InstalledSkill(
      inventoryKey: plan.inventoryKey,
      name: plan.name,
      path: plan.target.path,
      agents: [plan.target.agent],
      targetCount: 1,
      provenance: LibraryProvenance.external,
      targets: [sourceTarget],
    );
    final arguments = <String>[
      'adopt',
      '--target',
      jsonEncode(
        _externalAdoptionTarget(
          skill,
          sourceTarget,
          action: action,
          match: plan.selectedMatch,
          stateToken: plan.stateToken,
        ),
      ),
      '--output',
      'json',
    ];
    if (action == ExternalAdoptionAction.associateHub) {
      await _ensureHubOrigin();
      arguments.addAll(['--hub', _hubOrigin]);
    }
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final raw = jsonDecode(command.output.stdout);
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] != 1 ||
          raw['phase'] != 'adoption-execution' ||
          raw['action'] != _externalAdoptionActionValue(action) ||
          raw['name'] != plan.name ||
          raw['skillId'] is! String ||
          (raw['skillId'] as String).isEmpty ||
          raw['version'] is! String ||
          (raw['version'] as String).isEmpty ||
          raw['contentDigest'] != plan.contentDigest ||
          raw['provenance'] is! String ||
          raw['target'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final provenance = _libraryProvenance(raw['provenance']);
      final expectedProvenance = action == ExternalAdoptionAction.importLocal
          ? LibraryProvenance.local
          : LibraryProvenance.hub;
      if (provenance != expectedProvenance) throw const FormatException();
      if (action == ExternalAdoptionAction.associateHub &&
          (raw['skillId'] != selected!.skillId ||
              raw['version'] != selected.immutableVersion)) {
        throw const FormatException();
      }
      if (action == ExternalAdoptionAction.importLocal &&
          (!(raw['skillId'] as String).startsWith('local.skillsgo/') ||
              !(raw['version'] as String).startsWith('local-'))) {
        throw const FormatException();
      }
      final target = _installationPlanTarget({
        ...raw['target'] as Map<String, dynamic>,
        'mode': 'copy',
      });
      if (!_samePlanTarget(target, plan.target)) throw const FormatException();
      return ExternalAdoptionResult(
        action: _externalAdoptionAction(raw['action']),
        name: plan.name,
        skillId: raw['skillId'] as String,
        version: raw['version'] as String,
        provenance: provenance,
        contentDigest: plan.contentDigest,
        target: target,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid External Adoption Result JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<CommandResult?> exportLocalSkill(InstalledSkill skill) async {
    if (skill.provenance != LibraryProvenance.local || skill.targets.isEmpty) {
      throw const SkillsException(
        'Only managed private Local Skills can be exported.',
        kind: SkillsFailureKind.validation,
      );
    }
    final versions = skill.targets
        .map((target) => target.version)
        .where((version) => version.isNotEmpty)
        .toSet();
    if (skill.skillId.isEmpty || versions.length != 1) {
      throw const SkillsException(
        'Local Skill export requires one immutable version.',
        kind: SkillsFailureKind.validation,
      );
    }
    final destination = await _savePathPicker('${skill.name}.zip');
    if (destination == null) return null;
    final result = await _runCli([
      'export',
      '--skill-id',
      skill.skillId,
      '--version',
      versions.single,
      '--destination',
      destination,
      '--output',
      'json',
    ]);
    if (!result.succeeded) return result;
    try {
      final raw = jsonDecode(result.output.stdout);
      if (raw is! Map<String, dynamic> ||
          raw['schemaVersion'] != 1 ||
          raw['phase'] != 'local-export' ||
          raw['skillId'] != skill.skillId ||
          raw['version'] != versions.single ||
          raw['destination'] != destination) {
        throw const FormatException();
      }
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Local Skill export JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
    return result;
  }

  String _managementTargetArgument(
    String skillId,
    SkillInstallationTarget target, {
    TargetManagementAction? action,
    String? stateToken,
  }) => jsonEncode({
    'scope': target.scope.name,
    if (target.scope == InstallationScope.project)
      'projectRoot': target.projectRoot,
    'agent': target.agent,
    'mode': target.mode.name,
    'path': target.path,
    'skillId': skillId,
    'version': target.version,
    if (action != null) 'action': _targetManagementActionValue(action),
    'stateToken': ?stateToken,
  });

  @override
  Future<TargetManagementPlan> preflightTargetManagement(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  ) async {
    final external = skill.provenance == LibraryProvenance.external;
    if ((!external && skill.skillId.isEmpty) ||
        targets.isEmpty ||
        targets.any(
          (target) =>
              (external
                  ? target.mode != InstallationMode.external ||
                        target.version.isNotEmpty
                  : target.mode == InstallationMode.external ||
                        target.version.isEmpty) ||
              (target.scope == InstallationScope.project &&
                  target.projectRoot.isEmpty),
        )) {
      throw const SkillsException(
        'Only exact managed targets or exact External Installation removals can enter a Target Management Plan.',
        kind: SkillsFailureKind.validation,
      );
    }
    final arguments = <String>['manage'];
    for (final target in targets) {
      arguments.addAll([
        '--target',
        _managementTargetArgument(skill.skillId, target),
      ]);
    }
    arguments.addAll(['--preflight', '--output', 'json']);
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final decoded = jsonDecode(command.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['phase'] != 'management-preflight' ||
          decoded['targets'] is! List ||
          decoded['summary'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final rawTargets = decoded['targets'] as List;
      if (rawTargets.length != targets.length) throw const FormatException();
      final items = <TargetManagementPlanItem>[];
      for (var index = 0; index < rawTargets.length; index++) {
        final raw = rawTargets[index];
        if (raw is! Map<String, dynamic> ||
            raw['name'] is! String ||
            raw['skillId'] != skill.skillId ||
            raw['version'] != targets[index].version ||
            raw['allowedActions'] is! List ||
            raw['stateToken'] is! String ||
            (raw['stateToken'] as String).isEmpty ||
            raw['workspaceMetadataChange'] is! bool ||
            raw['action'] != null ||
            (raw['diagnostic'] != null && raw['diagnostic'] is! String) ||
            (raw['affectedBindings'] != null &&
                raw['affectedBindings'] is! List)) {
          throw const FormatException();
        }
        final target = _installationPlanTarget(
          raw['target'],
          allowExternal: external,
        );
        final expected = targets[index];
        if (target.scope != expected.scope ||
            target.projectRoot != expected.projectRoot ||
            target.agent != expected.agent ||
            target.mode != expected.mode ||
            target.path != expected.path ||
            (raw['workspaceMetadataChange'] as bool) !=
                (target.scope == InstallationScope.project && !external)) {
          throw const FormatException();
        }
        final health = _installationHealth(raw['health']);
        final actionValues = raw['allowedActions'] as List;
        final allowedActions = actionValues
            .map(_targetManagementAction)
            .toList(growable: false);
        if (allowedActions.isEmpty ||
            allowedActions.toSet().length != allowedActions.length ||
            (health == InstallationHealth.healthy &&
                (allowedActions.length != 1 ||
                    allowedActions.single != TargetManagementAction.remove)) ||
            (health != InstallationHealth.healthy &&
                (allowedActions.contains(TargetManagementAction.remove) ||
                    !allowedActions.contains(
                      TargetManagementAction.stopManaging,
                    )))) {
          throw const FormatException();
        }
        items.add(
          TargetManagementPlanItem(
            target: target,
            name: raw['name'] as String,
            skillId: skill.skillId,
            version: expected.version,
            health: health,
            allowedActions: List.unmodifiable(allowedActions),
            stateToken: raw['stateToken'] as String,
            workspaceMetadataChange: raw['workspaceMetadataChange'] as bool,
            diagnostic: raw['diagnostic'] as String? ?? '',
            affectedBindings: List.unmodifiable([
              for (final binding
                  in raw['affectedBindings'] as List? ?? const [])
                _installationPlanTarget(binding, allowExternal: external),
            ]),
          ),
        );
      }
      final targetKeys = items
          .map((item) => updateTargetKey(item.target))
          .toSet();
      for (final item in items) {
        if (item.affectedBindings.isNotEmpty &&
            (!item.affectedBindings.any(
                  (binding) =>
                      updateTargetKey(binding) == updateTargetKey(item.target),
                ) ||
                item.affectedBindings.any(
                  (binding) => !targetKeys.contains(updateTargetKey(binding)),
                ))) {
          throw const FormatException();
        }
      }
      final rawSummary = decoded['summary'] as Map<String, dynamic>;
      final summary = TargetManagementPlanSummary(
        removable: _strictNonNegativeInt(rawSummary['removable']),
        repairable: _strictNonNegativeInt(rawSummary['repairable']),
        stoppable: _strictNonNegativeInt(rawSummary['stoppable']),
      );
      int count(TargetManagementAction action) =>
          items.where((item) => item.allowedActions.contains(action)).length;
      if (summary.removable != count(TargetManagementAction.remove) ||
          summary.repairable != count(TargetManagementAction.repair) ||
          summary.stoppable != count(TargetManagementAction.stopManaging)) {
        throw const FormatException();
      }
      return TargetManagementPlan(
        targets: List.unmodifiable(items),
        summary: summary,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Target Management Plan JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<TargetManagementExecution> executeTargetManagement(
    TargetManagementPlan plan, {
    void Function(TargetManagementProgress progress)? onProgress,
  }) async {
    if (plan.targets.isEmpty ||
        plan.targets.any(
          (item) =>
              item.action == null || !item.allowedActions.contains(item.action),
        )) {
      throw const SkillsException(
        'Target Management execution requires explicit reviewed actions.',
        kind: SkillsFailureKind.validation,
      );
    }
    final arguments = <String>['manage'];
    for (final item in plan.targets) {
      arguments.addAll([
        '--target',
        jsonEncode({
          'scope': item.target.scope.name,
          if (item.target.scope == InstallationScope.project)
            'projectRoot': item.target.projectRoot,
          'agent': item.target.agent,
          'mode': item.target.mode.name,
          'path': item.target.path,
          'skillId': item.skillId,
          'version': item.version,
          'action': _targetManagementActionValue(item.action!),
          'stateToken': item.stateToken,
        }),
      ]);
    }
    arguments.addAll(['--output', 'ndjson']);
    final expected = {
      for (final item in plan.targets) updateTargetKey(item.target): item,
    };
    final states = <String, InstallationProgressState>{};
    final terminal = <String, TargetManagementResult>{};
    Map<String, dynamic>? finalPayload;
    Object? streamFailure;
    var sequence = 1;
    var sawLine = false;
    void consume(String line) {
      sawLine = true;
      if (streamFailure != null) return;
      try {
        final raw = jsonDecode(line);
        if (raw is! Map<String, dynamic> || raw['schemaVersion'] != 1) {
          throw const FormatException();
        }
        if (raw['phase'] == 'management-progress') {
          if (raw['sequence'] != sequence++ ||
              raw['name'] is! String ||
              raw['skillId'] is! String ||
              raw['version'] is! String ||
              raw['action'] is! String) {
            throw const FormatException();
          }
          final target = _installationPlanTarget(
            raw['target'],
            allowExternal: true,
          );
          final key = updateTargetKey(target);
          final item = expected[key];
          if (item == null ||
              raw['name'] != item.name ||
              raw['skillId'] != item.skillId ||
              raw['version'] != item.version ||
              raw['action'] != _targetManagementActionValue(item.action!)) {
            throw const FormatException();
          }
          final state = switch (raw['state']) {
            'started' => InstallationProgressState.started,
            'finished' => InstallationProgressState.finished,
            _ => throw const FormatException(),
          };
          TargetManagementResult? result;
          if (state == InstallationProgressState.started) {
            if (states.containsKey(key) || raw.containsKey('result')) {
              throw const FormatException();
            }
          } else {
            if (states[key] != InstallationProgressState.started ||
                raw['result'] == null) {
              throw const FormatException();
            }
            result = _targetManagementResult(raw['result'], item);
            terminal[key] = result;
          }
          states[key] = state;
          onProgress?.call(
            TargetManagementProgress(
              sequence: raw['sequence'] as int,
              target: target,
              name: item.name,
              skillId: item.skillId,
              version: item.version,
              action: item.action!,
              state: state,
              result: result,
            ),
          );
        } else if (raw['phase'] == 'management-execution') {
          if (finalPayload != null ||
              states.length != expected.length ||
              states.values.any(
                (state) => state != InstallationProgressState.finished,
              )) {
            throw const FormatException();
          }
          finalPayload = raw;
        } else {
          throw const FormatException();
        }
      } catch (error) {
        streamFailure = error;
      }
    }

    final command = await _runCli(arguments, onStdoutLine: consume);
    if (!sawLine) {
      for (final line in const LineSplitter().convert(command.output.stdout)) {
        consume(line);
      }
    }
    if (!command.succeeded && finalPayload == null) {
      throw _commandFailure(command);
    }
    try {
      final raw = finalPayload;
      if (streamFailure != null ||
          raw == null ||
          raw['results'] is! List ||
          raw['summary'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final rawResults = raw['results'] as List;
      if (rawResults.length != plan.targets.length) {
        throw const FormatException();
      }
      final results = <TargetManagementResult>[
        for (var index = 0; index < rawResults.length; index++)
          _targetManagementResult(rawResults[index], plan.targets[index]),
      ];
      for (final result in results) {
        final streamed = terminal[updateTargetKey(result.target)];
        if (streamed == null ||
            streamed.outcome != result.outcome ||
            streamed.error?.code != result.error?.code ||
            streamed.error?.diagnostic != result.error?.diagnostic) {
          throw const FormatException();
        }
      }
      final rawSummary = raw['summary'] as Map<String, dynamic>;
      final summary = TargetManagementExecutionSummary(
        succeeded: _strictNonNegativeInt(rawSummary['succeeded']),
        failed: _strictNonNegativeInt(rawSummary['failed']),
      );
      if (summary.succeeded !=
              results
                  .where(
                    (result) =>
                        result.outcome == TargetManagementOutcome.succeeded,
                  )
                  .length ||
          summary.failed !=
              results
                  .where(
                    (result) =>
                        result.outcome == TargetManagementOutcome.failed,
                  )
                  .length) {
        throw const FormatException();
      }
      return TargetManagementExecution(
        results: List.unmodifiable(results),
        summary: summary,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Target Management Result NDJSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  String _updateTargetArgument(
    String skillId,
    SkillInstallationTarget target, {
    String? toVersion,
    String? stateToken,
  }) => jsonEncode({
    'scope': target.scope.name,
    if (target.scope == InstallationScope.project)
      'projectRoot': target.projectRoot,
    'agent': target.agent,
    'mode': target.mode.name,
    'path': target.path,
    'skillId': skillId,
    'version': target.version,
    'toVersion': ?toVersion,
    'stateToken': ?stateToken,
  });

  @override
  Future<UpdatePlan> preflightUpdate(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  ) async {
    if (skill.provenance != LibraryProvenance.hub ||
        skill.skillId.isEmpty ||
        targets.isEmpty ||
        targets.any(
          (target) =>
              target.mode == InstallationMode.external ||
              target.version.isEmpty ||
              (target.scope == InstallationScope.project &&
                  target.projectRoot.isEmpty),
        )) {
      throw const SkillsException(
        'Only explicit managed Hub targets can be checked for updates.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final arguments = <String>['update'];
    for (final target in targets) {
      arguments.addAll([
        '--target',
        _updateTargetArgument(skill.skillId, target),
      ]);
    }
    arguments.addAll(['--preflight', '--output', 'json', '--hub', _hubOrigin]);
    final command = await _runCli(arguments);
    if (!command.succeeded) throw _commandFailure(command);
    try {
      final decoded = jsonDecode(command.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['phase'] != 'update-preflight' ||
          decoded['targets'] is! List ||
          decoded['workspaceManifestChanges'] is! List ||
          decoded['summary'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final rawTargets = decoded['targets'] as List;
      if (rawTargets.length != targets.length) throw const FormatException();
      final items = <UpdatePlanItem>[];
      for (var index = 0; index < rawTargets.length; index++) {
        final raw = rawTargets[index];
        if (raw is! Map<String, dynamic> ||
            raw['name'] is! String ||
            raw['skillId'] != skill.skillId ||
            raw['sourceRef'] is! String ||
            raw['fromVersion'] != targets[index].version ||
            raw['toVersion'] is! String ||
            raw['stateToken'] is! String ||
            raw['workspaceManifestChange'] is! bool ||
            (raw['affectedBindings'] != null &&
                raw['affectedBindings'] is! List) ||
            (raw['reasonCode'] != null && raw['reasonCode'] is! String) ||
            (raw['diagnostic'] != null && raw['diagnostic'] is! String)) {
          throw const FormatException();
        }
        final target = _installationPlanTarget(raw['target']);
        final expected = targets[index];
        final action = _updatePlanAction(raw['action']);
        final reasonCode = raw['reasonCode'] as String? ?? '';
        final fromVersion = expected.version;
        final toVersion = raw['toVersion'] as String;
        final stateToken = raw['stateToken'] as String;
        final workspaceManifestChange = raw['workspaceManifestChange'] as bool;
        if (target.scope != expected.scope ||
            target.projectRoot != expected.projectRoot ||
            target.agent != expected.agent ||
            target.mode != expected.mode ||
            target.path != expected.path ||
            stateToken.isEmpty ||
            (workspaceManifestChange &&
                target.scope != InstallationScope.project) ||
            (action == UpdatePlanAction.update &&
                fromVersion == toVersion &&
                reasonCode != 'workspace-manifest-reconcile') ||
            (reasonCode == 'workspace-manifest-reconcile' &&
                (action != UpdatePlanAction.update ||
                    !workspaceManifestChange ||
                    fromVersion != toVersion))) {
          throw const FormatException();
        }
        items.add(
          UpdatePlanItem(
            target: target,
            name: raw['name'] as String,
            skillId: skill.skillId,
            sourceRef: raw['sourceRef'] as String,
            fromVersion: fromVersion,
            toVersion: toVersion,
            action: action,
            reasonCode: reasonCode,
            diagnostic: raw['diagnostic'] as String? ?? '',
            stateToken: stateToken,
            workspaceManifestChange: workspaceManifestChange,
            affectedBindings: List.unmodifiable([
              for (final binding
                  in raw['affectedBindings'] as List? ?? const [])
                _installationPlanTarget(binding),
            ]),
          ),
        );
      }
      final targetKeys = items
          .map((item) => updateTargetKey(item.target))
          .toSet();
      for (final item in items) {
        if (item.affectedBindings.isNotEmpty &&
            (!item.affectedBindings.any(
                  (binding) =>
                      updateTargetKey(binding) == updateTargetKey(item.target),
                ) ||
                item.affectedBindings.any(
                  (binding) => !targetKeys.contains(updateTargetKey(binding)),
                ))) {
          throw const FormatException();
        }
      }
      final changes = <WorkspaceManifestChange>[];
      final changeKeys = <String>{};
      for (final raw in decoded['workspaceManifestChanges'] as List) {
        if (raw is! Map<String, dynamic> ||
            raw['projectRoot'] is! String ||
            raw['path'] is! String ||
            raw['skill'] is! String ||
            raw['fromVersion'] is! String ||
            raw['toVersion'] is! String) {
          throw const FormatException();
        }
        final projectRoot = raw['projectRoot'] as String;
        final path = raw['path'] as String;
        final skillName = raw['skill'] as String;
        final fromVersion = raw['fromVersion'] as String;
        final toVersion = raw['toVersion'] as String;
        final key = '$projectRoot\u0000$skillName\u0000$toVersion';
        final matchesItem = items.any(
          (item) =>
              item.workspaceManifestChange &&
              item.target.scope == InstallationScope.project &&
              item.target.projectRoot == projectRoot &&
              item.name == skillName &&
              item.toVersion == toVersion,
        );
        if (projectRoot.isEmpty ||
            skillName.isEmpty ||
            fromVersion.isEmpty ||
            toVersion.isEmpty ||
            p.normalize(path) !=
                p.normalize(p.join(projectRoot, 'skillsgo.mod')) ||
            !matchesItem ||
            !changeKeys.add(key)) {
          throw const FormatException();
        }
        changes.add(
          WorkspaceManifestChange(
            projectRoot: projectRoot,
            path: path,
            skill: skillName,
            fromVersion: fromVersion,
            toVersion: toVersion,
          ),
        );
      }
      final expectedChangeKeys = {
        for (final item in items)
          if (item.workspaceManifestChange)
            '${item.target.projectRoot}\u0000${item.name}\u0000${item.toVersion}',
      };
      if (changeKeys.length != expectedChangeKeys.length ||
          !changeKeys.containsAll(expectedChangeKeys)) {
        throw const FormatException();
      }
      final rawSummary = decoded['summary'] as Map<String, dynamic>;
      final summary = UpdatePlanSummary(
        update: _strictNonNegativeInt(rawSummary['update']),
        current: _strictNonNegativeInt(rawSummary['current']),
        pinned: _strictNonNegativeInt(rawSummary['pinned']),
        failed: _strictNonNegativeInt(rawSummary['failed']),
      );
      if (summary.update !=
              items
                  .where((item) => item.action == UpdatePlanAction.update)
                  .length ||
          summary.current !=
              items
                  .where((item) => item.action == UpdatePlanAction.current)
                  .length ||
          summary.pinned !=
              items
                  .where((item) => item.action == UpdatePlanAction.pinned)
                  .length ||
          summary.failed !=
              items
                  .where((item) => item.action == UpdatePlanAction.failed)
                  .length) {
        throw const FormatException();
      }
      return UpdatePlan(
        targets: List.unmodifiable(items),
        workspaceManifestChanges: List.unmodifiable(changes),
        summary: summary,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Update Plan JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<UpdateExecution> executeUpdate(
    UpdatePlan plan, {
    void Function(UpdateTargetProgress progress)? onProgress,
  }) async {
    if (plan.targets.isEmpty ||
        plan.targets.any((item) => item.action != UpdatePlanAction.update)) {
      throw const SkillsException(
        'Update execution requires explicit updateable targets.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final arguments = <String>['update'];
    for (final item in plan.targets) {
      arguments.addAll([
        '--target',
        jsonEncode({
          'scope': item.target.scope.name,
          if (item.target.scope == InstallationScope.project)
            'projectRoot': item.target.projectRoot,
          'agent': item.target.agent,
          'mode': item.target.mode.name,
          'path': item.target.path,
          'skillId': item.skillId,
          'version': item.fromVersion,
          'toVersion': item.toVersion,
          'stateToken': item.stateToken,
        }),
      ]);
    }
    arguments.addAll(['--output', 'ndjson', '--hub', _hubOrigin]);
    final expected = {
      for (final item in plan.targets) updateTargetKey(item.target): item,
    };
    final states = <String, InstallationProgressState>{};
    final terminal = <String, UpdateTargetResult>{};
    Map<String, dynamic>? finalPayload;
    Object? streamFailure;
    var sequence = 1;
    var sawLine = false;
    void consume(String line) {
      sawLine = true;
      if (streamFailure != null) return;
      try {
        final raw = jsonDecode(line);
        if (raw is! Map<String, dynamic> || raw['schemaVersion'] != 1) {
          throw const FormatException();
        }
        if (raw['phase'] == 'update-progress') {
          if (raw['sequence'] != sequence++ ||
              raw['name'] is! String ||
              raw['skillId'] is! String ||
              raw['fromVersion'] is! String ||
              raw['toVersion'] is! String) {
            throw const FormatException();
          }
          final target = _installationPlanTarget(raw['target']);
          final key = updateTargetKey(target);
          final item = expected[key];
          if (item == null ||
              raw['name'] != item.name ||
              raw['skillId'] != item.skillId ||
              raw['fromVersion'] != item.fromVersion ||
              raw['toVersion'] != item.toVersion) {
            throw const FormatException();
          }
          final state = switch (raw['state']) {
            'started' => InstallationProgressState.started,
            'finished' => InstallationProgressState.finished,
            _ => throw const FormatException(),
          };
          UpdateTargetResult? result;
          if (state == InstallationProgressState.started) {
            if (states.containsKey(key) || raw.containsKey('result')) {
              throw const FormatException();
            }
          } else {
            if (states[key] != InstallationProgressState.started ||
                raw['result'] == null) {
              throw const FormatException();
            }
            result = _updateTargetResult(raw['result'], item);
            terminal[key] = result;
          }
          states[key] = state;
          onProgress?.call(
            UpdateTargetProgress(
              sequence: raw['sequence'] as int,
              target: target,
              name: item.name,
              skillId: item.skillId,
              fromVersion: item.fromVersion,
              toVersion: item.toVersion,
              state: state,
              result: result,
            ),
          );
        } else if (raw['phase'] == 'update-execution') {
          if (finalPayload != null ||
              states.length != expected.length ||
              states.values.any(
                (state) => state != InstallationProgressState.finished,
              )) {
            throw const FormatException();
          }
          finalPayload = raw;
        } else {
          throw const FormatException();
        }
      } catch (error) {
        streamFailure = error;
      }
    }

    final command = await _runCli(arguments, onStdoutLine: consume);
    if (!sawLine) {
      for (final line in const LineSplitter().convert(command.output.stdout)) {
        consume(line);
      }
    }
    if (!command.succeeded && finalPayload == null) {
      throw _commandFailure(command);
    }
    try {
      final raw = finalPayload;
      if (streamFailure != null ||
          raw == null ||
          raw['results'] is! List ||
          raw['summary'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final rawResults = raw['results'] as List;
      if (rawResults.length != plan.targets.length) {
        throw const FormatException();
      }
      final results = <UpdateTargetResult>[
        for (var index = 0; index < rawResults.length; index++)
          _updateTargetResult(rawResults[index], plan.targets[index]),
      ];
      for (final result in results) {
        final streamed = terminal[updateTargetKey(result.target)];
        if (streamed == null ||
            streamed.outcome != result.outcome ||
            streamed.error?.code != result.error?.code ||
            streamed.error?.diagnostic != result.error?.diagnostic) {
          throw const FormatException();
        }
      }
      final rawSummary = raw['summary'] as Map<String, dynamic>;
      final summary = UpdateExecutionSummary(
        succeeded: _strictNonNegativeInt(rawSummary['succeeded']),
        skipped: _strictNonNegativeInt(rawSummary['skipped']),
        failed: _strictNonNegativeInt(rawSummary['failed']),
      );
      if (summary.succeeded !=
              results
                  .where(
                    (result) => result.outcome == UpdateTargetOutcome.succeeded,
                  )
                  .length ||
          summary.skipped !=
              results
                  .where(
                    (result) => result.outcome == UpdateTargetOutcome.skipped,
                  )
                  .length ||
          summary.failed !=
              results
                  .where(
                    (result) => result.outcome == UpdateTargetOutcome.failed,
                  )
                  .length) {
        throw const FormatException();
      }
      return UpdateExecution(
        results: List.unmodifiable(results),
        summary: summary,
      );
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid Update Result NDJSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<Map<String, UpdateState>> checkUpdates(
    List<InstalledSkill> skills,
  ) async {
    final states = <String, UpdateState>{};
    Object? failure;
    await Future.wait([
      for (final skill in skills)
        () async {
          final key = _installedSkillUpdateKey(skill);
          if (skill.provenance != LibraryProvenance.hub) {
            states[key] = UpdateState.unsupported;
            return;
          }
          try {
            final plan = await preflightUpdate(skill, skill.targets);
            if (plan.summary.update > 0) {
              states[key] = UpdateState.available;
            } else if (plan.summary.failed > 0) {
              states[key] = UpdateState.failed;
            } else if (plan.summary.current > 0) {
              states[key] = UpdateState.upToDate;
            } else {
              states[key] = UpdateState.unsupported;
            }
          } catch (caught) {
            states[key] = UpdateState.failed;
            failure ??= caught;
          }
        }(),
    ]);
    if (failure != null) throw failure!;
    return states;
  }

  SkillsException _commandFailure(CommandResult result) {
    final machineFailure = _parseMachineFailure(result.output.stdout);
    if (machineFailure != null) return machineFailure;
    final stderr = result.output.stderr.trim();
    final message = stderr.isEmpty
        ? 'SkillsGo CLI exited with code ${result.output.exitCode}.'
        : stderr;
    return switch (result.output.exitCode) {
      69 => SkillsException(
        message,
        kind: SkillsFailureKind.offline,
        isOffline: true,
      ),
      75 => SkillsException(message, kind: SkillsFailureKind.timeout),
      _ => SkillsException(message),
    };
  }

  SkillsException? _parseMachineFailure(String stdout) {
    if (stdout.trim().isEmpty) return null;
    try {
      Object? decoded;
      try {
        decoded = jsonDecode(stdout);
      } on FormatException {
        final lines = const LineSplitter()
            .convert(stdout)
            .where((line) => line.trim().isNotEmpty)
            .toList(growable: false);
        if (lines.isEmpty) rethrow;
        decoded = jsonDecode(lines.last);
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['phase'] != 'error' ||
          decoded['error'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final raw = decoded['error'] as Map<String, dynamic>;
      if (raw['code'] is! String ||
          (raw['code'] as String).isEmpty ||
          raw['retryable'] is! bool ||
          (raw['details'] != null && raw['details'] is! Map<String, dynamic>) ||
          (raw['requestId'] != null && raw['requestId'] is! String) ||
          (raw['diagnostic'] != null && raw['diagnostic'] is! String)) {
        throw const FormatException();
      }
      final code = raw['code'] as String;
      final kind = switch (code) {
        'input.invalid' => SkillsFailureKind.validation,
        'hub.unavailable' => SkillsFailureKind.offline,
        'hub.timeout' => SkillsFailureKind.timeout,
        'hub.rate_limited' => SkillsFailureKind.server,
        'protocol.invalid_response' => SkillsFailureKind.invalidResponse,
        'protocol.incompatible' ||
        'local.data_invalid' => SkillsFailureKind.invalidLocalData,
        _ => SkillsFailureKind.server,
      };
      return SkillsException(
        code,
        kind: kind,
        isOffline: code == 'hub.unavailable',
        code: code,
        retryable: raw['retryable'] as bool,
        details: Map<String, Object?>.unmodifiable(
          (raw['details'] as Map<String, dynamic>?) ?? const {},
        ),
        requestId: raw['requestId'] as String? ?? '',
        diagnostic: raw['diagnostic'] as String? ?? '',
      );
    } on FormatException {
      return const SkillsException(
        'protocol.incompatible',
        kind: SkillsFailureKind.invalidLocalData,
        code: 'protocol.incompatible',
      );
    }
  }
}
