/*
 * [INPUT]: Depends on native-runner-forwarded arguments including Windows Velopack fast-exit hooks, Dart Zones/UI dispatch, Flutter desktop bindings, the SkillsGo semantic theme, native window integration, Marionette instrumentation, App logging, and DesktopSkillsGateway.
 * [OUTPUT]: Exits before UI initialization for official Velopack lifecycle hooks, otherwise starts or replaces SkillsGo through main or runSkillsGoApp with failure/lifecycle capture, first-frame presentation, native window initialization, Hub defaults, Gateway injection, and debug measurements.
 * [POS]: Serves as the earliest desktop lifecycle boundary, Flutter process entry point, observability bootstrap, and native-window presentation boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'infrastructure/logging/app_logger.dart';
import 'infrastructure/desktop_skills_gateway.dart';
import 'ui/brand.dart';

const _debugHubBaseUrl = String.fromEnvironment(
  'SKILLSGO_HUB_URL',
  defaultValue: 'http://127.0.0.1:3000',
);

Future<void>? _desktopInitialization;
Future<void>? _firstFrameRasterized;
_AppLifecycleLogger? _lifecycleLogger;

const _velopackFastExitHooks = {
  '--veloapp-install',
  '--veloapp-obsolete',
  '--veloapp-updated',
  '--veloapp-uninstall',
};

@visibleForTesting
bool isVelopackFastExitInvocation(List<String> arguments) =>
    arguments.length == 2 && _velopackFastExitHooks.contains(arguments.first);

Future<void> main(List<String> arguments) async {
  if (isVelopackFastExitInvocation(arguments)) return;
  await appLogger.initialize();
  appLogger.info('app.lifecycle', 'launch_started');
  final launch = runZonedGuarded(
    () => runSkillsGoApp(
      installGlobalErrorHandlers: true,
      manageInitialWindowVisibility: true,
    ),
    (error, stackTrace) {
      appLogger.error('app.error', 'uncaught_zone_error', error, stackTrace);
    },
  );
  if (launch != null) await launch;
}

Future<void> runSkillsGoApp({
  bool initializeBinding = true,
  DesktopSkillsGateway? gateway,
  bool installGlobalErrorHandlers = false,
  bool manageInitialWindowVisibility = false,
}) async {
  if (initializeBinding && kDebugMode) {
    MarionetteBinding.ensureInitialized();
    registerMarionetteExtension(
      name: 'skillsgo.measureNavigation',
      description: 'Measure navigation indicator and label bounds.',
      callback: (_) async =>
          MarionetteExtensionResult.success({'elements': _measureNavigation()}),
    );
  } else if (initializeBinding) {
    WidgetsFlutterBinding.ensureInitialized();
  }

  if (installGlobalErrorHandlers) _installGlobalErrorHandlers();

  if (manageInitialWindowVisibility) {
    WidgetsBinding.instance.deferFirstFrame();
  }

  await (_desktopInitialization ??= _initializeDesktopWindow());

  runApp(
    SkillsGoApp(
      gateway:
          gateway ??
          DesktopSkillsGateway(
            hubBaseUrl: kDebugMode
                ? _debugHubBaseUrl
                : 'https://hub.skillsgo.ai',
          ),
      onStartupPresentationReady: manageInitialWindowVisibility
          ? _presentDesktopWindow
          : null,
    ),
  );
  if (!manageInitialWindowVisibility) {
    appLogger.info('app.lifecycle', 'launch_ready');
  }
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    appLogger.error(
      'app.error',
      'flutter_framework_error',
      details.exception,
      details.stack ?? StackTrace.current,
      {if (details.library != null) 'library': details.library},
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    appLogger.error(
      'app.error',
      'platform_dispatcher_error',
      error,
      stackTrace,
    );
    return true;
  };
  final lifecycleLogger = _lifecycleLogger ??= _AppLifecycleLogger();
  WidgetsBinding.instance.addObserver(lifecycleLogger);
}

final class _AppLifecycleLogger with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLogger.info('app.lifecycle', 'state_changed', {'state': state.name});
  }
}

Future<void> _initializeDesktopWindow() async {
  if (Platform.isMacOS) {
    await WindowManipulator.initialize(enableWindowDelegate: true);
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.hideTitle();
  }
  await windowManager.ensureInitialized();
  final brightness = PlatformDispatcher.instance.platformBrightness;
  final startupBackground = buildSkillsTheme(
    const Color(0xFF514532),
    brightness: brightness,
  ).colorScheme.surface;
  final options = WindowOptions(
    size: const Size(1120, 760),
    minimumSize: const Size(940, 640),
    center: true,
    backgroundColor: startupBackground,
    titleBarStyle: Platform.isMacOS
        ? TitleBarStyle.hidden
        : TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options);
}

Future<void> _presentDesktopWindow() async {
  await (_firstFrameRasterized ??= _releaseFirstFrame());
  if (Platform.isMacOS) await windowManager.show();
  await windowManager.focus();
  appLogger.info('app.lifecycle', 'launch_ready');
}

Future<void> _releaseFirstFrame() async {
  final binding = WidgetsBinding.instance;
  binding.allowFirstFrame();
  await binding.waitUntilFirstFrameRasterized;
}

List<Map<String, Object>> _measureNavigation() {
  final measurements = <Map<String, Object>>[];
  void visit(Element element) {
    final key = element.widget.key;
    final isIndicator = key == const ValueKey('nav-indicator');
    final isLabel = key == const ValueKey('nav-label');
    final renderObject = element.renderObject;
    if ((isIndicator || isLabel) && renderObject is RenderBox) {
      final origin = renderObject.localToGlobal(Offset.zero);
      measurements.add({
        'kind': isIndicator ? 'indicator' : 'label',
        if (element.widget case Text(:final data)) 'text': data ?? '',
        'x': origin.dx,
        'y': origin.dy,
        'width': renderObject.size.width,
        'height': renderObject.size.height,
        'centerY': origin.dy + renderObject.size.height / 2,
      });
    }
    element.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return measurements;
}
