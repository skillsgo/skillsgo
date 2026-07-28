/*
 * [INPUT]: Depends on Dart Zones/UI dispatch, Flutter desktop bindings, process-singleton macOS window integration, Marionette debug instrumentation, build mode, App logging, and the real SkillsGateway with an optional preconfigured process-isolated instance.
 * [OUTPUT]: Starts or replaces the SkillsGo widget application through main or the integration-test-safe runSkillsGoApp entry, with App-wide failure/lifecycle capture, one-time desktop initialization, build-time Hub defaults, runtime Gateway injection, and debug navigation measurements.
 * [POS]: Serves as the Flutter workspace process entry point, global observability bootstrap, and platform initialization boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'infrastructure/logging/app_logger.dart';
import 'infrastructure/real_skills_gateway.dart';

const _debugHubBaseUrl = String.fromEnvironment(
  'SKILLSGO_HUB_URL',
  defaultValue: 'http://127.0.0.1:3000',
);

Future<void>? _desktopInitialization;
_AppLifecycleLogger? _lifecycleLogger;

Future<void> main() async {
  await appLogger.initialize();
  appLogger.info('app.lifecycle', 'launch_started');
  final launch = runZonedGuarded(
    () => runSkillsGoApp(installGlobalErrorHandlers: true),
    (error, stackTrace) {
      appLogger.error('app.error', 'uncaught_zone_error', error, stackTrace);
    },
  );
  if (launch != null) await launch;
}

Future<void> runSkillsGoApp({
  bool initializeBinding = true,
  RealSkillsGateway? gateway,
  bool installGlobalErrorHandlers = false,
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

  await (_desktopInitialization ??= _initializeDesktopWindow());

  runApp(
    SkillsGoApp(
      gateway:
          gateway ??
          RealSkillsGateway(
            hubBaseUrl: kDebugMode
                ? _debugHubBaseUrl
                : 'https://hub.skillsgo.ai',
          ),
    ),
  );
  appLogger.info('app.lifecycle', 'launch_ready');
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
  await WindowManipulator.initialize(enableWindowDelegate: true);
  await WindowManipulator.makeTitlebarTransparent();
  await WindowManipulator.enableFullSizeContentView();
  await WindowManipulator.hideTitle();
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1120, 760),
    minimumSize: Size(940, 640),
    center: true,
    backgroundColor: Color(0x00000000),
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
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
