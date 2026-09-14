/*
 * [INPUT]: Depends on the bundled renderer page, the App-scoped asynchronous CDN MermaidScriptCache, rootBundle, one App-scoped webview_flutter controller, JSON/base64 messaging, and the active Material ColorScheme.
 * [OUTPUT]: Provides MermaidWebViewRendererScope and self-sizing MermaidWebViewDiagram widgets backed by one queued WebView-to-PNG renderer.
 * [POS]: Serves as the sole shared browser rendering service for every Markdown and Settings Mermaid block.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../infrastructure/mermaid_script_cache.dart';

class MermaidWebViewRendererScope extends StatefulWidget {
  const MermaidWebViewRendererScope({super.key, required this.child});

  final Widget child;

  static _MermaidWebViewRendererState? _maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_MermaidRendererProvider>()
      ?.renderer;

  @override
  State<MermaidWebViewRendererScope> createState() =>
      _MermaidWebViewRendererState();
}

class _MermaidRendererProvider extends InheritedWidget {
  const _MermaidRendererProvider({
    required this.renderer,
    required super.child,
  });

  final _MermaidWebViewRendererState renderer;

  @override
  bool updateShouldNotify(_MermaidRendererProvider oldWidget) => false;
}

class MermaidRenderResult {
  const MermaidRenderResult({required this.png, required this.height});

  final Uint8List png;
  final double height;
}

class _MermaidWebViewRendererState extends State<MermaidWebViewRendererScope> {
  final _ready = Completer<void>();
  final _cache = <String, MermaidRenderResult>{};
  WebViewController? _controller;
  Future<void>? _initializing;
  Completer<MermaidRenderResult>? _active;
  Future<void> _queue = Future.value();

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance != null) {
      unawaited(mermaidScriptCache.prefetch());
    }
  }

  Future<void> _ensureRenderer() {
    final initializing = _initializing;
    if (initializing != null) return initializing;
    final created = _initializeRenderer();
    _initializing = created;
    return created;
  }

  Future<void> _initializeRenderer() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MermaidHost', onMessageReceived: _handleMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!_ready.isCompleted) _ready.complete();
          },
        ),
      );
    setState(() => _controller = controller);
    await _loadRenderer(controller);
  }

  Future<void> _loadRenderer(WebViewController controller) async {
    try {
      final template = await rootBundle.loadString(
        'assets/mermaid-js/renderer.html',
      );
      final script = await mermaidScriptCache.loadScript();
      final html = template.replaceFirst('/*__MERMAID_SCRIPT__*/', script);
      if (html == template) {
        throw const FormatException(
          'Mermaid renderer template is missing its script slot.',
        );
      }
      await controller.loadHtmlString(html);
    } catch (error, stackTrace) {
      if (!_ready.isCompleted) _ready.completeError(error, stackTrace);
    }
  }

  Future<MermaidRenderResult> render(String source, ColorScheme scheme) {
    final key =
        '$source\u0000${scheme.brightness}\u0000${scheme.primary.toARGB32()}';
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    if (WebViewPlatform.instance == null) {
      return Future.error(UnsupportedError('当前平台没有可用的 Mermaid WebView 实现。'));
    }
    final result = Completer<MermaidRenderResult>();
    _queue = _queue.then((_) async {
      await _ensureRenderer();
      await _ready.future;
      if (!mounted) throw StateError('Mermaid WebView renderer is disposed.');
      _active = result;
      String hex(Color color) =>
          '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
      final colors = {
        'background': hex(scheme.surfaceContainerLow),
        'foreground': hex(scheme.onSurface),
        'muted': hex(scheme.onSurfaceVariant),
        'primary': hex(scheme.primary),
      };
      try {
        await _controller!.runJavaScript(
          'renderMermaid(${jsonEncode(source)}, ${jsonEncode(colors)});',
        );
        final rendered = await result.future;
        _cache[key] = rendered;
      } catch (error, stackTrace) {
        if (!result.isCompleted) result.completeError(error, stackTrace);
      } finally {
        _active = null;
      }
    });
    return result.future;
  }

  void _handleMessage(JavaScriptMessage message) {
    final active = _active;
    if (active == null || active.isCompleted) return;
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      final error = payload['error'] as String?;
      if (error != null) {
        active.completeError(FormatException(error));
        return;
      }
      final height = (payload['height'] as num?)?.toDouble();
      final png = payload['png'] as String?;
      if (height == null || png == null) {
        active.completeError(const FormatException('Mermaid 返回结果不完整。'));
        return;
      }
      active.complete(
        MermaidRenderResult(png: base64Decode(png), height: height),
      );
    } catch (error, stackTrace) {
      active.completeError(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return _MermaidRendererProvider(
      renderer: this,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (controller != null)
            Positioned(
              left: -10000,
              top: 0,
              width: 800,
              height: 800,
              child: IgnorePointer(
                child: WebViewWidget(controller: controller),
              ),
            ),
        ],
      ),
    );
  }
}

class MermaidWebViewDiagram extends StatefulWidget {
  const MermaidWebViewDiagram({
    super.key,
    required this.source,
    this.minHeight = 160,
    this.maxHeight = 800,
  });

  final String source;
  final double minHeight;
  final double maxHeight;

  @override
  State<MermaidWebViewDiagram> createState() => _MermaidWebViewDiagramState();
}

class _MermaidWebViewDiagramState extends State<MermaidWebViewDiagram> {
  MermaidRenderResult? _result;
  Object? _error;
  String? _signature;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scheme = Theme.of(context).colorScheme;
    final signature =
        '${widget.source}\u0000${scheme.brightness}\u0000${scheme.primary.toARGB32()}';
    if (signature == _signature) return;
    _signature = signature;
    _result = null;
    _error = null;
    final renderer = MermaidWebViewRendererScope._maybeOf(context);
    if (renderer == null) {
      _error = StateError('Mermaid WebView renderer is not mounted.');
      return;
    }
    unawaited(
      renderer
          .render(widget.source, scheme)
          .then(
            (result) {
              if (mounted && _signature == signature) {
                setState(() => _result = result);
              }
            },
            onError: (Object error) {
              if (mounted && _signature == signature) {
                setState(() => _error = error);
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (_error case final error?) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(error.toString()),
      );
    }
    final estimatedHeight = _estimatedMermaidHeight(
      widget.source,
    ).clamp(widget.minHeight, widget.maxHeight);
    final height = result?.height.clamp(widget.minHeight, widget.maxHeight);
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        key: const Key('mermaid-webview-diagram'),
        height: height ?? estimatedHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: result == null
              ? const _MermaidSkeleton(key: ValueKey('mermaid-skeleton'))
              : Padding(
                  key: const ValueKey('mermaid-image'),
                  padding: const EdgeInsets.all(16),
                  child: Image.memory(
                    result.png,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
        ),
      ),
    );
  }
}

double _estimatedMermaidHeight(String source) {
  final firstLine = source.trimLeft().split('\n').first.toLowerCase();
  if (firstLine.startsWith('sequencediagram')) return 360;
  if (firstLine.startsWith('gantt') ||
      firstLine.startsWith('timeline') ||
      firstLine.startsWith('mindmap') ||
      firstLine.startsWith('gitgraph') ||
      firstLine.startsWith('radar') ||
      firstLine.startsWith('xychart')) {
    return 320;
  }
  if (firstLine.startsWith('classdiagram') ||
      firstLine.startsWith('statediagram') ||
      firstLine.startsWith('erdiagram')) {
    return 280;
  }
  return 220;
}

class _MermaidSkeleton extends StatefulWidget {
  const _MermaidSkeleton({super.key});

  @override
  State<_MermaidSkeleton> createState() => _MermaidSkeletonState();
}

class _MermaidSkeletonState extends State<_MermaidSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: .45,
      upperBound: .85,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '正在渲染 Mermaid 图表',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Opacity(
            opacity: _controller.value,
            child: CustomPaint(
              painter: _MermaidSkeletonPainter(scheme),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _MermaidSkeletonPainter extends CustomPainter {
  const _MermaidSkeletonPainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = scheme.outlineVariant
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = scheme.surfaceContainerHighest
      ..style = PaintingStyle.fill;
    final accent = Paint()
      ..color = scheme.primary.withValues(alpha: .28)
      ..strokeWidth = 3;
    final centerY = size.height / 2;
    final nodeWidth = (size.width * .2).clamp(72.0, 150.0);
    final nodeHeight = (size.height * .28).clamp(44.0, 72.0);
    final left = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * .2, centerY),
        width: nodeWidth,
        height: nodeHeight,
      ),
      const Radius.circular(10),
    );
    final right = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * .8, centerY),
        width: nodeWidth,
        height: nodeHeight,
      ),
      const Radius.circular(10),
    );
    canvas
      ..drawLine(
        Offset(size.width * .3, centerY),
        Offset(size.width * .7, centerY),
        accent,
      )
      ..drawRRect(left, fill)
      ..drawRRect(left, stroke)
      ..drawRRect(right, fill)
      ..drawRRect(right, stroke)
      ..drawCircle(Offset(size.width * .5, centerY), 8, accent);
  }

  @override
  bool shouldRepaint(_MermaidSkeletonPainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}
