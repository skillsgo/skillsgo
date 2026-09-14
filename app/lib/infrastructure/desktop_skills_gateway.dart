/*
 * [INPUT]: Depends on the platform bundle's resolved CLI process boundary for all Hub and local business access, the local filesystem, secure randomness, bounded ProjectIconResolver, platform pickers, URL launching, and SharedPreferences-backed product preferences.
 * [OUTPUT]: Provides the exact App/CLI compatibility handshake plus typed long-lived and recoverable CLI-backed operations, explicit lifecycle closure, process-wide analytics progress and invalidations, diagnostics, and persisted product preferences.
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
import 'package:url_launcher/url_launcher.dart';

import '../domain/skills_gateway.dart';
import 'bundled_cli_locator.dart';
import 'io_process_runner.dart';
import 'logging/app_logger.dart';
import 'project_icon_resolver.dart';

part 'desktop_skills_gateway_codec.dart';
part 'desktop_skills_gateway_cli.dart';
part 'desktop_skills_gateway_preferences.dart';
part 'desktop_skills_gateway_discovery.dart';
part 'desktop_skills_gateway_inventory.dart';
part 'desktop_skills_gateway_installation.dart';
part 'desktop_skills_gateway_execution.dart';
part 'desktop_skills_gateway_target_management.dart';
part 'desktop_skills_gateway_updates.dart';
part 'desktop_skills_gateway_failures.dart';

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
const _updateCheckCacheKey = 'update_check_cache_v1';
const _allowCriticalOverrideKey = 'allow_critical_risk_override';
const _onboardingCompletedKey = 'onboarding_completed_v1';
const _onboardingStepKey = 'onboarding_step_v1';
const _localScanNoticeAcknowledgedKey = 'local_scan_notice_acknowledged_v1';
const _localScanNoticeDecisionKey = 'local_scan_notice_decision_v2';
const _startupHandshakeSchemaVersion = 1;
const _appProtocolVersion = 20;

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

abstract class _DesktopSkillsGatewayCore
    implements
        SkillsGateway,
        AnalyticsInvalidationSource,
        AnalyticsProgressSource {
  _DesktopSkillsGatewayCore({
    ProcessRunner? processRunner,
    @visibleForTesting String? initialCliPath,
    String? bundledCliPath,
    this.allowDeveloperCliOverride = !kReleaseMode,
    String? expectedCliOS,
    String hubBaseUrl = 'https://hub.skillsgo.ai',
    String? appVersion,
    DirectoryPathsPicker? directoryPathsPicker,
    ProjectPathInspector? projectPathInspector,
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
       _injectedAppVersion = appVersion,
       _directoryPathsPicker = directoryPathsPicker ?? _pickDirectories,
       _projectPathInspector = projectPathInspector ?? _inspectProjectPath;

  final ProcessRunner _runner;
  CliServerSession? _cliServerSession;
  Future<CliServerSession>? _cliServerStart;
  StreamSubscription<CliServerAnalyticsInvalidation>?
  _cliAnalyticsInvalidations;
  StreamSubscription<CliServerAnalyticsProgress>? _cliAnalyticsProgress;
  final _analyticsInvalidations = StreamController<int>.broadcast();
  final _analyticsProgress =
      StreamController<AnalyticsSyncProgress>.broadcast();
  Future<CliStatus>? _cliDetection;
  int _activeCliRequests = 0;
  Completer<void>? _cliRequestsDrained;
  final Uri _defaultHubBase;
  Uri _hubBase;
  final String _bundledCliPath;
  final bool allowDeveloperCliOverride;
  final String _expectedCliOS;
  final String? _injectedAppVersion;
  final DirectoryPathsPicker _directoryPathsPicker;
  final ProjectPathInspector _projectPathInspector;
  final ProjectIconResolver _projectIconResolver;
  String? _cliPath;
  bool _hubOriginLoaded = false;
  String? _imageProxyOrigin;
  String? _imageProxyHubOrigin;
  DateTime? _hubInfoRetryAfter;
  Future<void>? _hubInfoRefresh;
  bool _hubInfoDiscoveryEnabled = false;

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

  void _beginHubInfoRefresh() {
    if (!_hubInfoDiscoveryEnabled) return;
    final origin = _hubOrigin;
    if (_hubInfoRefresh != null) return;
    if (_imageProxyHubOrigin == origin) {
      final retryAfter = _hubInfoRetryAfter;
      if (retryAfter == null || DateTime.now().isBefore(retryAfter)) return;
    }
    final refresh = _refreshHubInfo(origin);
    _hubInfoRefresh = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_hubInfoRefresh, refresh)) _hubInfoRefresh = null;
      }),
    );
  }

  Future<void> _refreshHubInfo(String origin) async {
    String? proxyOrigin;
    var valid = false;
    try {
      final result = await _runCli([
        'hub',
        'info',
        '--hub',
        origin,
        '--output',
        'json',
      ], retryOnTransportFailure: true);
      if (result.succeeded) {
        final decoded = jsonDecode(result.output.stdout);
        if (decoded is Map<String, dynamic> &&
            decoded['schemaVersion'] == 1 &&
            (decoded['imageProxyOrigin'] == null ||
                decoded['imageProxyOrigin'] is String)) {
          valid = true;
          final raw = (decoded['imageProxyOrigin'] as String? ?? '').trim();
          if (raw.isNotEmpty) {
            proxyOrigin = _originUri(
              raw,
            ).toString().replaceFirst(RegExp(r'/$'), '');
          }
        }
      }
    } on Object {
      // Old, self-hosted, or temporarily unavailable Hubs retain direct images.
    }
    if (_hubOrigin == origin) {
      _imageProxyHubOrigin = origin;
      _imageProxyOrigin = proxyOrigin;
      _hubInfoRetryAfter = valid
          ? null
          : DateTime.now().add(const Duration(minutes: 1));
    }
  }

  Future<void> _waitForHubInfoRefresh({Duration? timeout}) async {
    final refresh = _hubInfoRefresh;
    if (refresh == null) return;
    if (timeout == null) {
      await refresh;
    } else {
      await refresh.timeout(timeout, onTimeout: () {});
    }
  }

  String? _resolvePackageImageUrl(String packagePath, [String? directUrl]) {
    final parts = packagePath
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 3 || parts.first.toLowerCase() != 'github.com') {
      return directUrl;
    }
    final owner = Uri.encodeComponent(parts[1]);
    final proxyOrigin = _imageProxyHubOrigin == _hubOrigin
        ? _imageProxyOrigin
        : null;
    if (proxyOrigin != null) {
      return '$proxyOrigin/github/$owner?size=96';
    }
    if (_hubInfoDiscoveryEnabled && _imageProxyHubOrigin != _hubOrigin) {
      return null;
    }
    if (directUrl != null && directUrl.trim().isNotEmpty) return directUrl;
    return 'https://github.com/$owner.png?size=96';
  }

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
    bool retryOnTransportFailure = false,
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

class DesktopSkillsGateway extends _DesktopSkillsGatewayCore
    with
        _DesktopSkillsGatewayCli,
        _DesktopSkillsGatewayPreferences,
        _DesktopSkillsGatewayDiscovery,
        _DesktopSkillsGatewayInventory,
        _DesktopSkillsGatewayInstallation,
        _DesktopSkillsGatewayExecutionSupport,
        _DesktopSkillsGatewayTargetManagement,
        _DesktopSkillsGatewayUpdates,
        _DesktopSkillsGatewayFailures {
  DesktopSkillsGateway({
    super.processRunner,
    super.initialCliPath,
    super.bundledCliPath,
    super.allowDeveloperCliOverride,
    super.expectedCliOS,
    super.hubBaseUrl,
    super.appVersion,
    super.directoryPathsPicker,
    super.projectPathInspector,
    super.projectIconResolver,
  });

  Future<void> close() async {
    await _closeCliServer();
    await _analyticsInvalidations.close();
    await _analyticsProgress.close();
  }
}
