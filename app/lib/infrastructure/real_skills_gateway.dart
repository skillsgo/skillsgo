/*
 * [INPUT]: Depends on the bundled CLI process boundary for Hub and local business access, the Hub-declared Cloud origin for ranking reads, the local filesystem, bounded ProjectIconResolver, platform pickers, and SharedPreferences-backed product preferences.
 * [OUTPUT]: Provides typed stdin-capable CLI-backed Mandatory Onboarding, Hub Find/detail, Cloud ranking composition, installation, scope-explicit Batch Takeover, inspection, atomic multi-project reference persistence with cached asynchronous identity enrichment, diagnostics, and persisted appearance/language/wallpaper/reminder/takeover-introduction operations with versioned machine-failure parsing.
 * [POS]: Serves as the App infrastructure adapter that keeps every Hub and local business operation behind the CLI machine boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/skills_gateway.dart';
import 'io_process_runner.dart';
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

typedef DirectoryPicker = Future<String?> Function({String? initialDirectory});
typedef DirectoryPathsPicker =
    Future<List<String>> Function({String? initialDirectory});
typedef ProjectPathInspector =
    Future<({ProjectAccessState state, String? diagnostic})> Function(
      String path,
    );

const _customCliKey = 'custom_cli_path';
const _hubOriginKey = 'hub_origin';
const _folderThemeKey = 'folder_theme';
const _wallpaperKey = 'wallpaper';
const _themeModeKey = 'theme_mode';
const _languageKey = 'language';
const _updateReminderKey = 'reminder_update_available';
const _securityReminderKey = 'reminder_security_advisory';
const _batchTakeoverPromptSeenKey = 'batch_takeover_prompt_seen_v1';
const _allowCriticalOverrideKey = 'allow_critical_risk_override';
const _addedProjectsKey = 'added_projects_v1';
const _onboardingCompletedKey = 'onboarding_completed_v1';
const _onboardingStepKey = 'onboarding_step_v1';
const _startupHandshakeSchemaVersion = 1;
const _appProtocolVersion = 10;

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
    throw const FormatException('Hub Origin must be an HTTP(S) URL.');
  }
  return Uri.parse(value.endsWith('/') ? value : '$value/');
}

abstract class _RealSkillsGatewayCore implements SkillsGateway {
  _RealSkillsGatewayCore({
    ProcessRunner? processRunner,
    String? initialCliPath,
    String? bundledCliPath,
    this.allowDeveloperCliOverride = !kReleaseMode,
    String? expectedCliOS,
    String hubBaseUrl = 'https://hub.skillsgo.ai',
    String? appVersion,
    DirectoryPicker? directoryPicker,
    DirectoryPathsPicker? directoryPathsPicker,
    ProjectPathInspector? projectPathInspector,
    this._projectIconResolver = const ProjectIconResolver(),
  }) : _runner = processRunner ?? const IoProcessRunner(),
       _cliPath = initialCliPath,
       _bundledCliPath =
           bundledCliPath ?? _bundledPathFor(Platform.resolvedExecutable),
       _expectedCliOS = expectedCliOS ?? _goOperatingSystem,
       _defaultHubBase = _originUri(hubBaseUrl),
       _hubBase = _originUri(hubBaseUrl),
       _injectedAppVersion = appVersion,
       _directoryPicker = directoryPicker ?? _pickDirectory,
       _directoryPathsPicker = directoryPathsPicker ?? _pickDirectories,
       _projectPathInspector = projectPathInspector ?? _inspectProjectPath;

  final ProcessRunner _runner;
  final Uri _defaultHubBase;
  Uri _hubBase;
  final String _bundledCliPath;
  final bool allowDeveloperCliOverride;
  final String _expectedCliOS;
  final String? _injectedAppVersion;
  final DirectoryPicker _directoryPicker;
  final DirectoryPathsPicker _directoryPathsPicker;
  final ProjectPathInspector _projectPathInspector;
  final ProjectIconResolver _projectIconResolver;
  String? _cliPath;
  bool _hubOriginLoaded = false;
  HubRuntime? _hubRuntime;

  static Future<String?> _pickDirectory({String? initialDirectory}) =>
      file_selector.getDirectoryPath(initialDirectory: initialDirectory);

  static Future<List<String>> _pickDirectories({
    String? initialDirectory,
  }) async => (await file_selector.getDirectoryPaths(
    initialDirectory: initialDirectory,
  )).whereType<String>().toList(growable: false);

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

  Future<String> _contentLocale();

  Future<CommandResult> _runCli(
    List<String> arguments, {
    String? stdin,
    void Function(String line)? onStdoutLine,
  });

  SkillsException _commandFailure(CommandResult result);
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
    super.appVersion,
    super.directoryPicker,
    super.directoryPathsPicker,
    super.projectPathInspector,
    super.projectIconResolver,
  });
}
