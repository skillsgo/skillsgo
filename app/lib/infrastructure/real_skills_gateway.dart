/*
 * [INPUT]: Depends on the platform bundle's resolved CLI process boundary for Hub and local business access, platform-native macOS HTTP plus portable IO HTTP for independently configured Cloud ranking reads, the local filesystem, secure randomness, bounded ProjectIconResolver, platform pickers, and SharedPreferences-backed product preferences.
 * [OUTPUT]: Provides typed long-lived CLI-backed Mandatory Onboarding, Hub Find/detail, system-proxy-aware Cloud ranking composition, installation and reviewed Adoption, inspection, CLI-owned Managed Project references with cached asynchronous identity enrichment, diagnostics, protocol-decode failure telemetry, and persisted appearance/language/first-run-randomized-wallpaper/reminder operations with versioned machine-failure parsing.
 * [POS]: Serves as the App infrastructure adapter that keeps every Hub and local business operation behind the CLI machine boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cupertino_http/cupertino_http.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/skills_gateway.dart';
import 'bundled_cli_locator.dart';
import 'io_process_runner.dart';
import 'logging/app_logger.dart';
import 'project_icon_resolver.dart';

part 'real_skills_gateway_codec.dart';
part 'real_skills_gateway_cli.dart';
part 'real_skills_gateway_preferences.dart';
part 'real_skills_gateway_discovery.dart';
part 'real_skills_gateway_inventory.dart';
part 'real_skills_gateway_installation.dart';
part 'real_skills_gateway_execution.dart';
part 'real_skills_gateway_target_management.dart';
part 'real_skills_gateway_updates.dart';
part 'real_skills_gateway_failures.dart';

typedef DirectoryPathsPicker =
    Future<List<String>> Function({String? initialDirectory});
typedef ProjectPathInspector =
    Future<({ProjectAccessState state, String? diagnostic})> Function(
      String path,
    );

const _customCliKey = 'custom_cli_path';
const _hubOriginKey = 'hub_origin';
const _cloudOriginKey = 'cloud_origin';
const _folderThemeKey = 'folder_theme';
const _wallpaperKey = 'wallpaper';
const _themeModeKey = 'theme_mode';
const _languageKey = 'language';
const _updateReminderKey = 'reminder_update_available';
const _securityReminderKey = 'reminder_security_advisory';
const _updateCheckCacheKey = 'update_check_cache_v1';
const _allowCriticalOverrideKey = 'allow_critical_risk_override';
const _onboardingCompletedKey = 'onboarding_completed_v1';
const _onboardingStepKey = 'onboarding_step_v1';
const _startupHandshakeSchemaVersion = 1;
const _appProtocolVersion = 17;

Uri _originUri(String origin) {
  final value = origin.trim();
  final parsed = Uri.tryParse(value);
  if (parsed == null ||
      !parsed.hasScheme ||
      (parsed.scheme != 'http' && parsed.scheme != 'https') ||
      parsed.host.isEmpty ||
      parsed.userInfo.isNotEmpty ||
      parsed.hasQuery ||
      parsed.hasFragment) {
    throw const FormatException('Origin must be an HTTP(S) URL.');
  }
  return Uri.parse(value.endsWith('/') ? value : '$value/');
}

abstract class _RealSkillsGatewayCore implements SkillsGateway {
  _RealSkillsGatewayCore({
    ProcessRunner? processRunner,
    @visibleForTesting String? initialCliPath,
    String? bundledCliPath,
    this.allowDeveloperCliOverride = !kReleaseMode,
    String? expectedCliOS,
    String hubBaseUrl = 'https://hub.skillsgo.ai',
    String cloudBaseUrl = 'https://cloud.skillsgo.ai',
    String? appVersion,
    DirectoryPathsPicker? directoryPathsPicker,
    ProjectPathInspector? projectPathInspector,
    http.Client Function()? cloudHttpClientFactory,
    this._projectIconResolver = const ProjectIconResolver(),
  }) : _runner = processRunner ?? const IoProcessRunner(),
       _cliPath = kReleaseMode ? null : initialCliPath,
       _bundledCliPath =
           bundledCliPath ??
           bundledCliPathFor(
             operatingSystem: Platform.operatingSystem,
             executable: Platform.resolvedExecutable,
           ),
       _expectedCliOS = expectedCliOS ?? _goOperatingSystem,
       _defaultHubBase = _originUri(hubBaseUrl),
       _hubBase = _originUri(hubBaseUrl),
       _defaultCloudBase = _originUri(cloudBaseUrl),
       _cloudBase = _originUri(cloudBaseUrl),
       _injectedAppVersion = appVersion,
       _directoryPathsPicker = directoryPathsPicker ?? _pickDirectories,
       _projectPathInspector = projectPathInspector ?? _inspectProjectPath,
       _cloudHttpClientFactory =
           cloudHttpClientFactory ?? _platformCloudHttpClient;

  final ProcessRunner _runner;
  CliServerSession? _cliServerSession;
  Future<CliServerSession>? _cliServerStart;
  Future<CliStatus>? _cliDetection;
  final Uri _defaultHubBase;
  Uri _hubBase;
  final Uri _defaultCloudBase;
  Uri _cloudBase;
  final String _bundledCliPath;
  final bool allowDeveloperCliOverride;
  final String _expectedCliOS;
  final String? _injectedAppVersion;
  final DirectoryPathsPicker _directoryPathsPicker;
  final ProjectPathInspector _projectPathInspector;
  final ProjectIconResolver _projectIconResolver;
  final http.Client Function() _cloudHttpClientFactory;
  String? _cliPath;
  bool _hubOriginLoaded = false;
  bool _cloudOriginLoaded = false;

  static Future<List<String>> _pickDirectories({
    String? initialDirectory,
  }) async => (await file_selector.getDirectoryPaths(
    initialDirectory: initialDirectory,
  )).whereType<String>().toList(growable: false);

  static http.Client _platformCloudHttpClient() => Platform.isMacOS
      ? CupertinoClient.defaultSessionConfiguration()
      : http.Client();

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

  String get _hubOrigin => _hubBase.toString().replaceFirst(RegExp(r'/$'), '');
  String get _cloudOrigin =>
      _cloudBase.toString().replaceFirst(RegExp(r'/$'), '');

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

  Future<void> _ensureCloudOrigin() async {
    if (_cloudOriginLoaded) return;
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_cloudOriginKey);
    if (saved != null) {
      try {
        _cloudBase = _originUri(saved);
      } on FormatException {
        await preferences.remove(_cloudOriginKey);
      }
    }
    _cloudOriginLoaded = true;
  }

  @override
  Future<DiagnosticLogInfo> loadDiagnosticLogInfo() async => DiagnosticLogInfo(
    directory: appLogger.directory?.path ?? '',
    totalBytes: await appLogger.totalBytes(),
  );

  @override
  Future<void> openDiagnosticLogDirectory() async {
    final directory = appLogger.directory;
    if (directory == null) return;
    await directory.create(recursive: true);
    await Process.start('/usr/bin/open', [directory.path]);
  }

  @override
  Future<bool> exportDiagnosticLogs() async {
    final location = await file_selector.getSaveLocation(
      suggestedName: 'skillsgo-diagnostics.log',
      acceptedTypeGroups: const [
        file_selector.XTypeGroup(label: 'Log', extensions: ['log']),
      ],
    );
    if (location == null) return false;
    await appLogger.exportTo(File(location.path));
    return true;
  }

  @override
  Future<void> clearDiagnosticLogs() => appLogger.clear();

  @override
  List<DiagnosticLogEntry> recentDiagnosticLogs({int limit = 200}) =>
      appLogger.recent(limit: limit);

  @override
  Stream<DiagnosticLogEntry> watchDiagnosticLogs() => appLogger.events;

  static String get _goOperatingSystem => switch (Platform.operatingSystem) {
    'macos' => 'darwin',
    final value => value,
  };

  Future<String> _contentLang();

  Future<CommandResult> _runCli(
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  });

  SkillsException _commandFailure(CommandResult result);

  SkillsException _invalidCliResponse(
    String operation,
    String message,
    CommandResult command,
    Object error,
    StackTrace stackTrace,
  ) {
    appLogger.error(
      'gateway.protocol',
      'response_decode_failed',
      error,
      stackTrace,
      {
        'operation': operation,
        'responsePreview': appLogger.humanPreview(command.output.stdout),
      },
    );
    return SkillsException(message, kind: SkillsFailureKind.invalidResponse);
  }
}

class RealSkillsGateway extends _RealSkillsGatewayCore
    with
        _RealSkillsGatewayCli,
        _RealSkillsGatewayPreferences,
        _RealSkillsGatewayDiscovery,
        _RealSkillsGatewayInventory,
        _RealSkillsGatewayInstallation,
        _RealSkillsGatewayExecutionSupport,
        _RealSkillsGatewayTargetManagement,
        _RealSkillsGatewayUpdates,
        _RealSkillsGatewayFailures {
  RealSkillsGateway({
    super.processRunner,
    super.initialCliPath,
    super.bundledCliPath,
    super.allowDeveloperCliOverride,
    super.expectedCliOS,
    super.hubBaseUrl,
    super.cloudBaseUrl,
    super.appVersion,
    super.directoryPathsPicker,
    super.projectPathInspector,
    super.cloudHttpClientFactory,
    super.projectIconResolver,
  });
}
