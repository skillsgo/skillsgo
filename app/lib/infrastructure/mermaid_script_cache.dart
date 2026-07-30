/*
 * [INPUT]: Depends on the immutable SkillsGo CDN Mermaid gzip object, platform-aware HTTP bytes, SHA-256 verification, platform cache-directory conventions, atomic File replacement, dart:io gzip decoding, and App logging.
 * [OUTPUT]: Provides one App-scoped MermaidScriptCache that asynchronously prefetches, integrity-checks, persists, retries, and decodes Mermaid.js on demand.
 * [POS]: Serves as the infrastructure boundary between the CDN-hosted browser renderer payload and the UI-owned Mermaid WebView.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'logging/app_logger.dart';

final mermaidScriptCache = MermaidScriptCache();

final class MermaidScriptCache {
  MermaidScriptCache({
    http.Client? client,
    Future<Directory> Function()? supportDirectory,
    Uri? sourceUri,
    String? expectedDigest,
  }) : _client = client ?? _platformClient(),
       _supportDirectory = supportDirectory ?? _defaultCacheDirectory,
       uri = sourceUri ?? productionUri,
       _expectedDigest = expectedDigest ?? sha256Digest;

  static const version = '11.16.0';
  static const sha256Digest =
      'd0f6f8c2bcfbeeea2cc766d54b3c6c24ecf322011d8aa3ba0da5eccefcd2d373';
  static final productionUri = Uri.parse(
    'https://cdn.skillsgo.ai/app/mermaid/$version/'
    '$sha256Digest/mermaid-$version.min.js.gz',
  );

  final http.Client _client;
  final Future<Directory> Function() _supportDirectory;
  final Uri uri;
  final String _expectedDigest;
  Future<Uint8List>? _compressedFuture;

  Future<void> prefetch() async {
    try {
      await _compressed();
    } catch (error, stackTrace) {
      appLogger.warning(
        'app.mermaid',
        'script_prefetch_failed',
        {'origin': uri.origin},
        error,
        stackTrace,
      );
    }
  }

  Future<String> loadScript() async {
    final compressed = await _compressed();
    return utf8.decode(gzip.decode(compressed));
  }

  Future<Uint8List> _compressed() {
    final current = _compressedFuture;
    if (current != null) return current;
    final operation = _loadCompressed();
    _compressedFuture = operation;
    return operation;
  }

  Future<Uint8List> _loadCompressed() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        final cached = await file.readAsBytes();
        if (_isValid(cached)) return cached;
        await file.delete();
      }

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Mermaid CDN returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      final downloaded = response.bodyBytes;
      if (!_isValid(downloaded)) {
        throw const FormatException(
          'Mermaid CDN payload failed SHA-256 verification.',
        );
      }

      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.download');
      await temporary.writeAsBytes(downloaded, flush: true);
      await temporary.rename(file.path);
      return downloaded;
    } catch (_) {
      _compressedFuture = null;
      rethrow;
    }
  }

  Future<File> _cacheFile() async {
    final root = await _supportDirectory();
    return File(
      path.join(root.path, 'mermaid', version, '$_expectedDigest.js.gz'),
    );
  }

  bool _isValid(List<int> bytes) =>
      sha256.convert(bytes).toString() == _expectedDigest;

  static http.Client _platformClient() => Platform.isMacOS
      ? CupertinoClient.defaultSessionConfiguration()
      : http.Client();

  static Future<Directory> _defaultCacheDirectory() async {
    final environment = Platform.environment;
    if (Platform.isWindows) {
      final localAppData = environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return Directory(path.join(localAppData, 'SkillsGo', 'Cache'));
      }
    }
    final home = environment['HOME'];
    if (Platform.isMacOS && home != null && home.isNotEmpty) {
      return Directory(path.join(home, 'Library', 'Caches', 'SkillsGo'));
    }
    if (Platform.isLinux) {
      final xdgCache = environment['XDG_CACHE_HOME'];
      if (xdgCache != null && xdgCache.isNotEmpty) {
        return Directory(path.join(xdgCache, 'skillsgo'));
      }
      if (home != null && home.isNotEmpty) {
        return Directory(path.join(home, '.cache', 'skillsgo'));
      }
    }
    return Directory(path.join(Directory.systemTemp.path, 'skillsgo-cache'));
  }
}
