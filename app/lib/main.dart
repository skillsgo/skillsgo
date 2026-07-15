/*
 * [INPUT]: Depends on Flutter desktop bindings, macOS window integration, Marionette debug instrumentation, and the real SkillsGateway.
 * [OUTPUT]: Starts the SkillsGo desktop process and exposes debug-only navigation measurements.
 * [POS]: Serves as the Flutter workspace process entry point and platform initialization boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'infrastructure/real_skills_gateway.dart';

Future<void> main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
    registerMarionetteExtension(
      name: 'skillsgo.measureNavigation',
      description: 'Measure navigation indicator and label bounds.',
      callback: (_) async =>
          MarionetteExtensionResult.success({'elements': _measureNavigation()}),
    );
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

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

  runApp(SkillsGoApp(gateway: RealSkillsGateway()));
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
