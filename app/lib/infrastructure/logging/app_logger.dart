/*
 * [INPUT]: Depends on package:logging records, Dart Zones/IO, HumanLogFormatter, RollingTextLogSink, build mode, and structured caller data.
 * [OUTPUT]: Provides the App-wide categorized logger, session/operation correlation, centralized redaction, bounded structure-preserving JSON request/response previews, recent/live diagnostic entries, failure diagnostics, and debug-console plus human-readable rolling-file delivery.
 * [POS]: Serves as the single observability boundary shared by App lifecycle, UI operations, Gateways, and process adapters.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../domain/system_models.dart';
import 'human_log_formatter.dart';
import 'rolling_text_log_sink.dart';

const _operationZoneKey = #skillsgoLogOperationId;

final appLogger = AppLogger();

final class AppLogger {
  AppLogger();

  final Logger _logger = Logger('skillsgo');
  final Random _random = Random.secure();
  final HumanLogFormatter _formatter = const HumanLogFormatter();
  final StreamController<DiagnosticLogEntry> _events =
      StreamController<DiagnosticLogEntry>.broadcast();
  final List<DiagnosticLogEntry> _recent = [];
  StreamSubscription<LogRecord>? _subscription;
  RollingTextLogSink? _sink;
  Future<void> _writeQueue = Future<void>.value();
  late String _sessionId;
  String? _home;

  bool get initialized => _sink != null;
  String? get operationId => Zone.current[_operationZoneKey] as String?;
  Directory? get directory => _sink?.directory;
  Stream<DiagnosticLogEntry> get events => _events.stream;

  List<DiagnosticLogEntry> recent({int limit = 200}) {
    final start = max(0, _recent.length - limit);
    return List.unmodifiable(_recent.sublist(start));
  }

  Future<int> totalBytes() async {
    await flush();
    final root = directory;
    if (root == null || !await root.exists()) return 0;
    var total = 0;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is File && entry.path.endsWith('.log')) {
        total += await entry.length();
      }
    }
    return total;
  }

  Future<void> exportTo(File destination) async {
    await flush();
    final root = directory;
    if (root == null || !await root.exists()) {
      await destination.writeAsString('');
      return;
    }
    final files = await root
        .list(followLinks: false)
        .where((entry) => entry is File && entry.path.endsWith('.log'))
        .cast<File>()
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));
    final output = destination.openWrite();
    try {
      for (final file in files) {
        await output.addStream(file.openRead());
      }
    } finally {
      await output.close();
    }
  }

  Future<void> clear() async {
    await flush();
    final root = directory;
    if (root == null || !await root.exists()) return;
    await for (final entry in root.list(followLinks: false)) {
      if (entry is File && entry.path.endsWith('.log')) {
        try {
          await entry.delete();
        } on FileSystemException {
          // Best effort: an active external reader must not break Settings.
        }
      }
    }
  }

  Future<void> initialize({Directory? directory, LogClock? clock}) async {
    if (initialized) return;
    _sessionId = _id('session');
    _home = Platform.environment['HOME'];
    final root = directory ?? _defaultDirectory();
    _sink = RollingTextLogSink(directory: root, clock: clock);
    await _sink!.initialize();
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    _subscription = Logger.root.onRecord.listen(_record);
    info('app.lifecycle', 'logging_initialized', {
      'session': _sessionId.split('-').last,
      'retentionDays': 7,
      'maxDirectoryBytes': 50 * 1024 * 1024,
    });
    await flush();
  }

  Future<void> dispose() async {
    await flush();
    await _subscription?.cancel();
    _subscription = null;
    _sink = null;
  }

  void debug(
    String category,
    String event, [
    Map<String, Object?> data = const {},
  ]) => _log(Level.FINE, category, event, data);

  void info(
    String category,
    String event, [
    Map<String, Object?> data = const {},
  ]) => _log(Level.INFO, category, event, data);

  void warning(
    String category,
    String event, [
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  ]) => _log(Level.WARNING, category, event, data, error, stackTrace);

  void error(
    String category,
    String event,
    Object error,
    StackTrace stackTrace, [
    Map<String, Object?> data = const {},
  ]) => _log(Level.SEVERE, category, event, data, error, stackTrace);

  Future<T> operation<T>(
    String category,
    String event,
    Future<T> Function() run, {
    Map<String, Object?> data = const {},
  }) async {
    final id = _id('operation');
    final stopwatch = Stopwatch()..start();
    info(category, '${event}_started', {...data, 'operationId': id});
    try {
      final result = await runZoned(run, zoneValues: {_operationZoneKey: id});
      info(category, '${event}_finished', {
        ...data,
        'operationId': id,
        'durationMs': stopwatch.elapsedMilliseconds,
      });
      return result;
    } on Object catch (cause, stackTrace) {
      error(category, '${event}_failed', cause, stackTrace, {
        ...data,
        'operationId': id,
        'durationMs': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  String nextId(String prefix) => _id(prefix);

  Future<void> flush() => _writeQueue;

  void _log(
    Level level,
    String category,
    String event,
    Map<String, Object?> data, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _logger.log(
      level,
      _AppLogMessage(
        category: category,
        event: event,
        data: data,
        operationId: operationId,
      ),
      error,
      stackTrace,
    );
  }

  void _record(LogRecord record) {
    final message = record.object;
    if (message is! _AppLogMessage) return;
    final data =
        (sanitize({
                  ...message.data,
                  if (message.operationId != null)
                    'operationId': message.operationId,
                })
                as Map)
            .cast<String, Object?>();
    final error = record.error == null
        ? null
        : truncate(sanitizeString(record.error.toString()), 16 * 1024);
    final stackTrace = record.stackTrace == null
        ? null
        : truncate(sanitizeString(record.stackTrace.toString()), 32 * 1024);
    final unformatted = DiagnosticLogEntry(
      time: record.time,
      level: _diagnosticLevel(record.level),
      category: message.category,
      event: message.event,
      formatted: '',
      data: data,
      error: error,
      stackTrace: stackTrace,
    );
    final event = DiagnosticLogEntry(
      time: unformatted.time,
      level: unformatted.level,
      category: unformatted.category,
      event: unformatted.event,
      formatted: _formatter.format(unformatted),
      data: unformatted.data,
      error: unformatted.error,
      stackTrace: unformatted.stackTrace,
    );
    _recent.add(event);
    if (_recent.length > 2000) _recent.removeRange(0, _recent.length - 2000);
    _events.add(event);
    if (kDebugMode) {
      debugPrint('[${event.level.label}] ${message.category}.${message.event}');
    }
    final sink = _sink;
    if (sink == null) return;
    _writeQueue = _writeQueue
        .then((_) => sink.append(event.formatted))
        .catchError((_) {
          // Logging must never affect product behavior.
        });
  }

  Object? sanitize(Object? value, {String? key}) {
    if (key != null && value is String && _pathKey.hasMatch(key)) {
      return '<path:${_fnv(value)}>';
    }
    if (key != null &&
        key != 'hasStdin' &&
        key != 'stdinBytes' &&
        _sensitiveKey.hasMatch(key)) {
      return '<redacted>';
    }
    return switch (value) {
      String() => sanitizeString(value),
      Map() => {
        for (final entry in value.entries)
          entry.key.toString(): sanitize(
            entry.value,
            key: entry.key.toString(),
          ),
      },
      Iterable() => [for (final item in value) sanitize(item)],
      num() || bool() || null => value,
      _ => sanitizeString(value.toString()),
    };
  }

  String sanitizeString(String value) {
    var sanitized = value;
    final home = _home;
    if (home != null && home.isNotEmpty) {
      sanitized = sanitized.replaceAll(home, r'$HOME');
    }
    sanitized = sanitized.replaceAllMapped(
      RegExp(
        r'(token|password|secret|authorization)([=:]\s*)([^\s,;]+)',
        caseSensitive: false,
      ),
      (match) => '${match[1]}${match[2]}<redacted>',
    );
    sanitized = sanitized.replaceAllMapped(RegExp(r'https?://[^\s]+'), (match) {
      final uri = Uri.tryParse(match[0]!);
      if (uri == null) return match[0]!;
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      ).toString();
    });
    return sanitized;
  }

  List<String> sanitizeCliArguments(List<String> arguments) {
    const pathFlags = {'--project', '--path'};
    const payloadFlags = {'--input', '--installed', '--requests'};
    const secretFlags = {'--token', '--password', '--authorization'};
    final result = <String>[];
    var redactNextFindQuery = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (redactNextFindQuery && !argument.startsWith('-')) {
        result.add('<query:redacted>');
        redactNextFindQuery = false;
        continue;
      }
      if (argument.startsWith('{') || argument.startsWith('[')) {
        result.add('<payload:${_fnv(argument)}>');
        continue;
      }
      if (argument.startsWith('/') || argument.startsWith('~/')) {
        result.add('<path:${_fnv(argument)}>');
        continue;
      }
      result.add(argument);
      if (argument == 'find') redactNextFindQuery = true;
      if (index + 1 >= arguments.length) continue;
      if (secretFlags.contains(argument)) {
        result.add('<redacted>');
        index++;
      } else if (pathFlags.contains(argument)) {
        final path = arguments[++index];
        result.add('<path:${_fnv(path)}>');
      } else if (payloadFlags.contains(argument)) {
        final payload = arguments[++index];
        result.add('<payload:${_fnv(payload)}>');
      }
    }
    return result.map(sanitizeString).toList(growable: false);
  }

  String humanPreview(String source, {int maxBytes = 8 * 1024}) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '';
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      for (final line in trimmed.split('\n').reversed) {
        try {
          decoded = jsonDecode(line);
          break;
        } on FormatException {
          // Keep looking for the final machine-protocol line.
        }
      }
    }
    if (decoded == null) {
      return truncate(sanitizeString(trimmed), maxBytes);
    }
    final formatted = const JsonEncoder.withIndent(
      '  ',
    ).convert(sanitize(decoded));
    return truncate(formatted, maxBytes);
  }

  static String truncate(String value, int maxBytes) {
    final bytes = utf8.encode(value);
    if (bytes.length <= maxBytes) return value;
    return '${utf8.decode(bytes.take(maxBytes).toList(), allowMalformed: true)}…';
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${_random.nextInt(0xffffff).toRadixString(36).padLeft(5, '0')}';

  static String _fnv(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Directory _defaultDirectory() {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return Directory('$home/Library/Logs/SkillsGo');
  }

  static DiagnosticLogLevel _diagnosticLevel(Level level) {
    if (level >= Level.SEVERE) return DiagnosticLogLevel.error;
    if (level >= Level.WARNING) return DiagnosticLogLevel.warning;
    if (level >= Level.INFO) return DiagnosticLogLevel.info;
    return DiagnosticLogLevel.debug;
  }

  static final _sensitiveKey = RegExp(
    r'token|password|secret|authorization|stdin|content',
    caseSensitive: false,
  );
  static final _pathKey = RegExp(
    r'(^|_)(path|directory|root|workspace|project)(s)?$',
    caseSensitive: false,
  );
}

final class _AppLogMessage {
  const _AppLogMessage({
    required this.category,
    required this.event,
    required this.data,
    this.operationId,
  });

  final String category;
  final String event;
  final Map<String, Object?> data;
  final String? operationId;

  @override
  String toString() => '$category.$event';
}
