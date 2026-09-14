/*
 * [INPUT]: Depends on Dart IO/UTF-8, a caller-provided clock, and already sanitized human-readable App log text.
 * [OUTPUT]: Provides serialized text append, 10 MB size rotation, seven-day retention, 50 MB directory bounding, legacy JSONL removal, and deterministic cleanup.
 * [POS]: Serves as the bounded local persistence sink for the App-wide human-readable logging pipeline.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

typedef LogClock = DateTime Function();

final class RollingTextLogSink {
  RollingTextLogSink({
    required this.directory,
    LogClock? clock,
    this.retention = const Duration(days: 7),
    this.maxFileBytes = 10 * 1024 * 1024,
    this.maxDirectoryBytes = 50 * 1024 * 1024,
    this.cleanupInterval = 100,
  }) : _clock = clock ?? DateTime.now;

  final Directory directory;
  final Duration retention;
  final int maxFileBytes;
  final int maxDirectoryBytes;
  final int cleanupInterval;
  final LogClock _clock;
  int _writes = 0;
  String? _activeDate;

  Future<void> initialize() async {
    await directory.create(recursive: true);
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File && entry.path.endsWith('.jsonl')) {
        await _deleteBestEffort(entry);
      }
    }
    await cleanup();
  }

  Future<void> append(String text) async {
    await directory.create(recursive: true);
    final now = _clock();
    final date = _dateKey(now);
    final dateChanged = _activeDate != date;
    _activeDate = date;
    if (_writes == 0 || dateChanged || _writes % cleanupInterval == 0) {
      await cleanup(now: now);
    }
    final encoded = text.endsWith('\n') ? text : '$text\n';
    final bytes = utf8.encode(encoded);
    final file = await _targetFile(date, bytes.length);
    final sink = file.openWrite(mode: FileMode.append, encoding: utf8);
    try {
      sink.add(bytes);
      await sink.flush();
    } finally {
      await sink.close();
    }
    _writes++;
    if (await _directorySize() > maxDirectoryBytes) {
      await cleanup(now: now, activePath: file.path);
    }
  }

  Future<void> cleanup({DateTime? now, String? activePath}) async {
    if (!await directory.exists()) return;
    final threshold = (now ?? _clock()).subtract(retention);
    final files = await _logFiles();
    for (final file in files) {
      if (file.path == activePath) continue;
      final modified = await file.lastModified();
      if (modified.isBefore(threshold)) await _deleteBestEffort(file);
    }
    final retained = await _logFiles();
    retained.sort(
      (left, right) =>
          left.lastModifiedSync().compareTo(right.lastModifiedSync()),
    );
    var total = 0;
    final sizes = <File, int>{};
    for (final file in retained) {
      final size = await file.length();
      sizes[file] = size;
      total += size;
    }
    for (final file in retained) {
      if (total <= maxDirectoryBytes) break;
      if (file.path == activePath) continue;
      final size = sizes[file] ?? 0;
      if (await _deleteBestEffort(file)) total -= size;
    }
  }

  Future<File> _targetFile(String date, int incomingBytes) async {
    var index = 0;
    while (true) {
      final suffix = index == 0 ? '' : '.$index';
      final candidate = File('${directory.path}/app-$date$suffix.log');
      final length = await candidate.exists() ? await candidate.length() : 0;
      if (length == 0 || length + incomingBytes <= maxFileBytes) {
        return candidate;
      }
      index++;
    }
  }

  Future<List<File>> _logFiles() async => directory
      .list(followLinks: false)
      .where((entry) => entry is File && _isLogFile(entry.path))
      .cast<File>()
      .toList();

  Future<int> _directorySize() async {
    var total = 0;
    for (final file in await _logFiles()) {
      total += await file.length();
    }
    return total;
  }

  Future<bool> _deleteBestEffort(File file) async {
    try {
      await file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static bool _isLogFile(String path) =>
      RegExp(r'(^|[/\\])app-\d{4}-\d{2}-\d{2}(?:\.\d+)?\.log$').hasMatch(path);

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
