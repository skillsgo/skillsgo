/*
 * [INPUT]: Depends on Flutter Material and image precaching, Riverpod, SkillsGateway, startup Cloud and appearance state, localization delegates, the App shell, brand tokens, and the shared Mermaid WebView renderer.
 * [OUTPUT]: Provides SkillsGoApp, the persisted-language-aware localized desktop application root with App-scoped Gateway, selected-wallpaper startup presentation readiness, always-enabled product motion, Mermaid renderer, and eager configured-Cloud initialization.
 * [POS]: Serves as the App composition boundary between platform startup and product UI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/skills_gateway.dart';
import 'l10n/app_localizations.dart';
import 'ui/app_shell.dart';
import 'ui/app_providers.dart';
import 'ui/appearance_controller.dart';
import 'ui/brand.dart';
import 'ui/mermaid_webview_diagram.dart';

class SkillsGoApp extends StatelessWidget {
  const SkillsGoApp({
    super.key,
    required this.gateway,
    this.onStartupPresentationReady,
  });

  final SkillsGateway gateway;
  final Future<void> Function()? onStartupPresentationReady;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [skillsGatewayProvider.overrideWithValue(gateway)],
      child: _SkillsGoMaterialApp(
        gateway: gateway,
        onStartupPresentationReady: onStartupPresentationReady,
      ),
    );
  }
}

class _SkillsGoMaterialApp extends ConsumerWidget {
  const _SkillsGoMaterialApp({
    required this.gateway,
    required this.onStartupPresentationReady,
  });

  final SkillsGateway gateway;
  final Future<void> Function()? onStartupPresentationReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cloudOriginProvider);
    final language = ref.watch(appearanceProvider).value?.language;
    final localeParts = language?.explicitUiLocale;
    final locale = localeParts == null
        ? null
        : Locale.fromSubtags(
            languageCode: localeParts.languageCode,
            scriptCode: localeParts.scriptCode,
            countryCode: localeParts.countryCode,
          );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillsGo',
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: ThemeMode.system,
      theme: buildSkillsTheme(
        const Color(0xFF514532),
        brightness: Brightness.light,
      ),
      darkTheme: buildSkillsTheme(const Color(0xFF514532)),
      builder: (context, child) => MermaidWebViewRendererScope(child: child!),
      home: _StartupPresentationGate(
        onReady: onStartupPresentationReady,
        child: AppShell(gateway: gateway),
      ),
    );
  }
}

class _StartupPresentationGate extends ConsumerStatefulWidget {
  const _StartupPresentationGate({required this.onReady, required this.child});

  final Future<void> Function()? onReady;
  final Widget child;

  @override
  ConsumerState<_StartupPresentationGate> createState() =>
      _StartupPresentationGateState();
}

class _StartupPresentationGateState
    extends ConsumerState<_StartupPresentationGate> {
  bool _preparing = false;
  bool _completed = false;
  bool _completing = false;
  bool _disposed = false;
  int _presentationAttempts = 0;
  Timer? _fallbackTimer;
  ImageStream? _wallpaperStream;
  ImageStreamListener? _wallpaperListener;
  Completer<void>? _wallpaperDecoded;

  @override
  void initState() {
    super.initState();
    if (widget.onReady != null) {
      _fallbackTimer = Timer(const Duration(seconds: 3), _complete);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _fallbackTimer?.cancel();
    _removeWallpaperListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearanceState = ref.watch(appearanceProvider);
    final appearance = appearanceState.value;
    if (!_preparing && appearance != null && widget.onReady != null) {
      _preparing = true;
      unawaited(_prepare(appearance.wallpaper));
    } else if (!_preparing && appearanceState.hasError) {
      _preparing = true;
      unawaited(_complete());
    }
    return widget.child;
  }

  Future<void> _prepare(AppWallpaper wallpaper) async {
    final image = AssetImage(wallpaper.assetPath);
    final stream = image.resolve(createLocalImageConfiguration(context));
    final decoded = Completer<void>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        if (!decoded.isCompleted) decoded.complete();
      },
      onError: (Object error, StackTrace? stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'SkillsGo startup presentation',
            context: ErrorDescription('while decoding the selected wallpaper'),
          ),
        );
        if (!decoded.isCompleted) decoded.complete();
      },
    );
    _wallpaperStream = stream;
    _wallpaperListener = listener;
    _wallpaperDecoded = decoded;
    stream.addListener(listener);
    try {
      await decoded.future;
    } finally {
      _removeWallpaperListener();
    }
    if (_disposed) return;
    await _complete();
  }

  void _removeWallpaperListener() {
    final stream = _wallpaperStream;
    final listener = _wallpaperListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    final decoded = _wallpaperDecoded;
    if (decoded != null && !decoded.isCompleted) decoded.complete();
    _wallpaperStream = null;
    _wallpaperListener = null;
    _wallpaperDecoded = null;
  }

  Future<void> _complete() async {
    if (_disposed || _completed || _completing) return;
    _completing = true;
    _removeWallpaperListener();
    try {
      _presentationAttempts += 1;
      await widget.onReady?.call();
      _completed = true;
      _fallbackTimer?.cancel();
    } on Object {
      if (_presentationAttempts < 2) {
        _fallbackTimer?.cancel();
        _fallbackTimer = Timer(const Duration(milliseconds: 250), _complete);
      }
      rethrow;
    } finally {
      _completing = false;
    }
  }
}
