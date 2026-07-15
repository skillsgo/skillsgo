/*
 * [INPUT]: Depends on Registry HTTP, the local filesystem, SharedPreferences, and executable process boundaries.
 * [OUTPUT]: Provides the production SkillsGateway implementation, including bundled CLI verification and Skill operations.
 * [POS]: Serves as the App infrastructure adapter between domain journeys, the Registry, and the SkillsGo CLI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
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

class RealSkillsGateway implements SkillsGateway {
  RealSkillsGateway({
    http.Client? httpClient,
    ProcessRunner? processRunner,
    String? initialCliPath,
    String? bundledCliPath,
    this.allowDeveloperCliOverride = !kReleaseMode,
    String? expectedCliOS,
    String registryBaseUrl = 'http://localhost:3000',
  }) : _http = httpClient ?? http.Client(),
       _runner = processRunner ?? const IoProcessRunner(),
       _cliPath = initialCliPath,
       _bundledCliPath =
           bundledCliPath ?? _bundledPathFor(Platform.resolvedExecutable),
       _expectedCliOS = expectedCliOS ?? _goOperatingSystem,
       _registryBase = Uri.parse(
         registryBaseUrl.endsWith('/') ? registryBaseUrl : '$registryBaseUrl/',
       );

  static const _customCliKey = 'custom_cli_path';
  static const _startupHandshakeSchemaVersion = 1;
  static const _appProtocolVersion = 1;
  final http.Client _http;
  final ProcessRunner _runner;
  final Uri _registryBase;
  final String _bundledCliPath;
  final bool allowDeveloperCliOverride;
  final String _expectedCliOS;
  String? _cliPath;

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
  Future<List<SkillSummary>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final uri = _registryBase
        .resolve('v1/search')
        .replace(queryParameters: {'q': query.trim(), 'limit': '20'});
    try {
      final response = await _http
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SkillsException(
          'Search service returned ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['skills'] is! List) {
        throw const SkillsException(
          'Search service returned an invalid response.',
        );
      }
      return (decoded['skills'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const SkillsException('Invalid skill result.');
            }
            final source = raw['coordinate'];
            final skillId =
                raw['skillPath'] is String &&
                    (raw['skillPath'] as String).isNotEmpty
                ? p.basename(raw['skillPath'] as String)
                : raw['name'];
            final id = raw['coordinate'];
            final name = raw['name'];
            if (source is! String ||
                skillId is! String ||
                id is! String ||
                name is! String) {
              throw const SkillsException(
                'Search result is missing required fields.',
              );
            }
            return SkillSummary(
              id: id,
              skillId: skillId,
              name: name,
              source: source,
              installs: raw['installs'] is num
                  ? (raw['installs'] as num).toInt()
                  : 0,
              latestVersion: raw['latestVersion'] is String
                  ? raw['latestVersion'] as String
                  : 'main',
            );
          })
          .toList(growable: false);
    } on SocketException {
      throw const SkillsException('You appear to be offline.', isOffline: true);
    } on TimeoutException {
      throw const SkillsException(
        'Search timed out. Check your connection.',
        isOffline: true,
      );
    } on FormatException {
      throw const SkillsException('Search service returned invalid JSON.');
    }
  }

  @override
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill) async {
    final infoUri = _registryBase.resolve(
      '${skill.id}/@v/${skill.latestVersion}.info',
    );
    try {
      final infoResponse = await _http
          .get(infoUri)
          .timeout(const Duration(seconds: 20));
      if (infoResponse.statusCode < 200 || infoResponse.statusCode >= 300) {
        throw SkillsException(
          'Skill info returned ${infoResponse.statusCode}.',
        );
      }
      final info = jsonDecode(infoResponse.body);
      if (info is! Map<String, dynamic> || info['Version'] is! String) {
        throw const SkillsException('Skill info is invalid.');
      }
      final version = info['Version'] as String;
      final manifestUri = _registryBase.resolve(
        '${skill.id}/@v/$version.manifest',
      );
      final manifestResponse = await _http
          .get(manifestUri)
          .timeout(const Duration(seconds: 20));
      if (manifestResponse.statusCode < 200 ||
          manifestResponse.statusCode >= 300) {
        throw SkillsException(
          'Skill manifest returned ${manifestResponse.statusCode}.',
        );
      }
      final manifest = manifestResponse.body;
      if (manifest.trim().isEmpty) {
        throw const SkillsException('Skill manifest is empty.');
      }
      final infoText = const JsonEncoder.withIndent('  ').convert(info);
      return SkillDetail(
        name: skill.name,
        source: skill.source,
        markdown: '```yaml\n$manifest\n```',
        files: [
          SkillFile(path: '$version.info', contents: infoText),
          SkillFile(path: '$version.manifest', contents: manifest),
        ],
        installs: skill.installs,
      );
    } on SocketException {
      throw const SkillsException('You appear to be offline.', isOffline: true);
    } on TimeoutException {
      throw const SkillsException('Skill metadata timed out.', isOffline: true);
    } on FormatException {
      throw const SkillsException('Skill info returned invalid JSON.');
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
          <String, ({String name, String path, Set<String> agents})>{};
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic> ||
            raw['name'] is! String ||
            raw['target'] is! Map<String, dynamic>) {
          throw const FormatException();
        }
        final target = raw['target'] as Map<String, dynamic>;
        if (target['path'] is! String || target['agent'] is! String) {
          throw const FormatException();
        }
        final key = '${raw['coordinate'] ?? ''}\u0000${raw['name']}';
        final current = grouped[key];
        grouped[key] = (
          name: raw['name'] as String,
          path: current?.path ?? target['path'] as String,
          agents: (current?.agents ?? <String>{})
            ..add(target['agent'] as String),
        );
      }
      return grouped.values
          .map(
            (value) => InstalledSkill(
              name: value.name,
              path: value.path,
              agents: value.agents.toList(growable: false),
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
  Future<CommandResult> install(SkillSummary skill) => _runCli([
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
    _registryBase.toString().replaceFirst(RegExp(r'/$'), ''),
  ]);

  @override
  Future<CommandResult> remove(InstalledSkill skill) =>
      _runCli(['remove', skill.name, '--global', '--yes']);

  @override
  Future<CommandResult> update(InstalledSkill skill) =>
      _runCli(['update', skill.name, '--global', '--yes']);

  @override
  Future<Map<String, UpdateState>> checkUpdates(
    List<InstalledSkill> skills,
  ) async {
    if (skills.isEmpty) return const {};
    final arguments = <String>[
      'update',
      ...skills.map((skill) => skill.name),
      '--global',
      '--check',
      '--output',
      'json',
      '--registry',
      _registryBase.toString().replaceFirst(RegExp(r'/$'), ''),
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
