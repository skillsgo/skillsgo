/*
 * [INPUT]: Depends on the bundled Mermaid.js 11.16.0 renderer page, webview_flutter, JSON/base64 messaging, and the active Material ColorScheme.
 * [OUTPUT]: Provides one self-sizing official Mermaid.js renderer per source block, using a WebView for SVG generation and WebKit rasterization for reliable macOS composition.
 * [POS]: Serves as the deliberately simple one-WebView-engine-per-block bridge shared by Markdown and the Settings renderer gallery.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MermaidWebViewDiagram extends StatefulWidget {
  const MermaidWebViewDiagram({
    super.key,
    required this.source,
    required this.fallbackBuilder,
    this.minHeight = 160,
    this.maxHeight = 800,
  });

  final String source;
  final Widget Function(BuildContext context, Object? error) fallbackBuilder;
  final double minHeight;
  final double maxHeight;

  @override
  State<MermaidWebViewDiagram> createState() => _MermaidWebViewDiagramState();
}

class _MermaidWebViewDiagramState extends State<MermaidWebViewDiagram> {
  WebViewController? _controller;
  Object? _error;
  double? _height;
  Uint8List? _imageBytes;
  String? _renderSignature;
  ColorScheme? _pendingScheme;
  var _pageReady = false;

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance == null) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MermaidHost', onMessageReceived: _handleMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _pageReady = true;
            final scheme = _pendingScheme;
            if (scheme != null) unawaited(_render(scheme));
          },
        ),
      )
      ..loadFlutterAsset('assets/mermaid-js/renderer.html');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scheme = Theme.of(context).colorScheme;
    final signature =
        '${widget.source}\u0000${Theme.of(context).brightness}'
        '\u0000${scheme.primary.toARGB32()}';
    if (_controller == null || signature == _renderSignature) return;
    _renderSignature = signature;
    _pendingScheme = scheme;
    _error = null;
    if (_pageReady) unawaited(_render(scheme));
  }

  @override
  void didUpdateWidget(covariant MermaidWebViewDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _renderSignature = null;
  }

  void _handleMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      final error = payload['error'] as String?;
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      final height = (payload['height'] as num?)?.toDouble();
      final png = payload['png'] as String?;
      if (height != null && png != null) {
        setState(() {
          _height = height.clamp(widget.minHeight, widget.maxHeight);
          _imageBytes = base64Decode(png);
        });
      }
    } catch (error) {
      setState(() => _error = error);
    }
  }

  Future<void> _render(ColorScheme scheme) async {
    if (!mounted || _controller == null) return;
    String hex(Color color) =>
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final colors = {
      'background': hex(scheme.surfaceContainerLow),
      'foreground': hex(scheme.onSurface),
      'muted': hex(scheme.onSurfaceVariant),
      'primary': hex(scheme.primary),
    };
    await _controller!.runJavaScript(
      'renderMermaid(${jsonEncode(widget.source)}, ${jsonEncode(colors)});',
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _error != null) {
      return widget.fallbackBuilder(context, _error);
    }
    final imageBytes = _imageBytes;
    if (imageBytes != null) {
      return SizedBox(
        key: const Key('mermaid-webview-diagram'),
        height: _height ?? widget.minHeight,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    }
    return SizedBox(
      key: const Key('mermaid-webview-diagram'),
      height: _height ?? widget.minHeight,
      child: WebViewWidget(controller: controller),
    );
  }
}
