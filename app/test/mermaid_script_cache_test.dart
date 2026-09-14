/*
 * [INPUT]: Uses a temporary Application Support directory, deterministic gzip bytes, and controllable HTTP clients.
 * [OUTPUT]: Specifies CDN Mermaid prefetch, integrity verification, persistent compressed caching, and offline cache reuse.
 * [POS]: Serves as the infrastructure contract suite for MermaidScriptCache.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skillsgo/infrastructure/mermaid_script_cache.dart';

void main() {
  test('prefetch persists compressed Mermaid and reuses it offline', () async {
    final support = await Directory.systemTemp.createTemp(
      'skillsgo-mermaid-cache-test-',
    );
    addTearDown(() => support.delete(recursive: true));
    final compressed = gzip.encode(utf8.encode('window.mermaid = true;'));
    final digest = sha256.convert(compressed).toString();
    var requests = 0;
    final online = MermaidScriptCache(
      client: MockClient((request) async {
        requests++;
        return http.Response.bytes(compressed, HttpStatus.ok);
      }),
      supportDirectory: () async => support,
      sourceUri: Uri.parse('https://cdn.example/mermaid.js.gz'),
      expectedDigest: digest,
    );

    await online.prefetch();
    expect(await online.loadScript(), 'window.mermaid = true;');
    expect(requests, 1);

    final offline = MermaidScriptCache(
      client: MockClient((_) async => throw StateError('offline')),
      supportDirectory: () async => support,
      sourceUri: Uri.parse('https://cdn.example/mermaid.js.gz'),
      expectedDigest: digest,
    );
    expect(await offline.loadScript(), 'window.mermaid = true;');
  });

  test('rejects a CDN payload with the wrong digest', () async {
    final support = await Directory.systemTemp.createTemp(
      'skillsgo-mermaid-integrity-test-',
    );
    addTearDown(() => support.delete(recursive: true));
    final cache = MermaidScriptCache(
      client: MockClient(
        (_) async => http.Response.bytes(gzip.encode([1, 2, 3]), HttpStatus.ok),
      ),
      supportDirectory: () async => support,
      sourceUri: Uri.parse('https://cdn.example/mermaid.js.gz'),
      expectedDigest:
          '0000000000000000000000000000000000000000000000000000000000000000',
    );

    await expectLater(cache.loadScript(), throwsA(isA<FormatException>()));
  });
}
