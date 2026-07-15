/*
 * [INPUT]: Depends on Registry HTTP, the local filesystem, SharedPreferences, and executable process boundaries.
 * [OUTPUT]: Provides production Registry settings, paginated discovery, auditable artifact detail with local targets and typed failures, diagnostics, bundled CLI verification, and Skill operations.
 * [POS]: Serves as the App infrastructure adapter between domain journeys, the Registry, and the SkillsGo CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/skills_gateway.dart';

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

SkillInstallationScope _installationScope(Object? value) => switch (value) {
  'user' => SkillInstallationScope.user,
  'project' => SkillInstallationScope.project,
  _ => throw const FormatException('Unknown installation scope.'),
};

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
  }) : _http = httpClient ?? http.Client(),
       _runner = processRunner ?? const IoProcessRunner(),
       _cliPath = initialCliPath,
       _bundledCliPath =
           bundledCliPath ?? _bundledPathFor(Platform.resolvedExecutable),
       _expectedCliOS = expectedCliOS ?? _goOperatingSystem,
       _defaultRegistryBase = _originUri(registryBaseUrl),
       _registryBase = _originUri(registryBaseUrl),
       _injectedAppVersion = appVersion;

  static const _customCliKey = 'custom_cli_path';
  static const _registryOriginKey = 'registry_origin';
  static const _allowCriticalOverrideKey = 'allow_critical_risk_override';
  static const _startupHandshakeSchemaVersion = 1;
  static const _appProtocolVersion = 1;
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
  String? _cliPath;
  bool _registryOriginLoaded = false;

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
        final installed = await listInstalled();
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
        final installed = await listInstalled();
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
  Future<List<InstalledSkill>> listInstalled() async {
    final result = await _runCli(const ['list', '--global', '--json']);
    if (!result.succeeded) throw SkillsException(_commandError(result));
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! List) throw const FormatException();
      final grouped =
          <
            String,
            ({
              String coordinate,
              String name,
              String path,
              Set<String> agents,
              int targetCount,
              List<SkillInstallationTarget> targets,
            })
          >{};
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic> ||
            raw['name'] is! String ||
            raw['version'] is! String ||
            raw['target'] is! Map<String, dynamic>) {
          throw const FormatException();
        }
        final target = raw['target'] as Map<String, dynamic>;
        if (target['path'] is! String ||
            target['agent'] is! String ||
            target['scope'] is! String) {
          throw const FormatException();
        }
        final key = '${raw['coordinate'] ?? ''}\u0000${raw['name']}';
        final current = grouped[key];
        grouped[key] = (
          coordinate: raw['coordinate'] is String
              ? raw['coordinate'] as String
              : '',
          name: raw['name'] as String,
          path: current?.path ?? target['path'] as String,
          agents: (current?.agents ?? <String>{})
            ..add(target['agent'] as String),
          targetCount: (current?.targetCount ?? 0) + 1,
          targets: [
            ...?current?.targets,
            SkillInstallationTarget(
              agent: target['agent'] as String,
              scope: _installationScope(target['scope']),
              path: target['path'] as String,
              version: raw['version'] as String,
            ),
          ],
        );
      }
      return grouped.values
          .map(
            (value) => InstalledSkill(
              name: value.name,
              path: value.path,
              agents: value.agents.toList(growable: false),
              targetCount: value.targetCount,
              coordinate: value.coordinate,
              targets: value.targets,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      throw const SkillsException(
        'The SkillsGo CLI returned invalid list JSON.',
      );
    }
  }

  @override
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill) async {
    final file = File(p.join(skill.path, 'SKILL.md'));
    try {
      final markdown = await file.readAsString();
      if (markdown.trim().isEmpty) {
        throw const SkillsException('The local SKILL.md is empty.');
      }
      final files = await Directory(skill.path)
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File)
          .map(
            (entity) => SkillFile(
              path: p.relative(entity.path, from: skill.path),
              contents: '',
            ),
          )
          .toList();
      return SkillDetail(
        name: skill.name,
        source: 'Local',
        markdown: markdown,
        files: files,
      );
    } on FileSystemException catch (error) {
      throw SkillsException('Cannot read local Skill: ${error.message}');
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
  Future<CommandResult> remove(InstalledSkill skill) =>
      _runCli(['remove', skill.name, '--global', '--yes']);

  @override
  Future<CommandResult> update(InstalledSkill skill) async {
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
    if (skills.isEmpty) return const {};
    await _ensureRegistryOrigin();
    final arguments = <String>[
      'update',
      ...skills.map((skill) => skill.name),
      '--global',
      '--check',
      '--output',
      'json',
      '--registry',
      _registryOrigin,
    ];
    final result = await _runCli(arguments);
    if (!result.succeeded) {
      return {for (final skill in skills) skill.name: UpdateState.failed};
    }
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! List) throw const FormatException();
      final states = {
        for (final skill in skills) skill.name: UpdateState.unsupported,
      };
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
      return {for (final skill in skills) skill.name: UpdateState.failed};
    }
  }

  String _commandError(CommandResult result) {
    final stderr = result.output.stderr.trim();
    return stderr.isEmpty
        ? 'SkillsGo CLI exited with code ${result.output.exitCode}.'
        : stderr;
  }
}
