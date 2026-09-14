/*
 * [INPUT]: Depends on Flutter test IO, AppLogger, HumanLogFormatter, RollingTextLogSink, and the production IoProcessRunner.
 * [OUTPUT]: Verifies human-readable persistence, JSON response formatting, live structured entries, redaction, size rotation, age/cap cleanup, export/clear, and correlated CLI success/failure diagnostics.
 * [POS]: Serves as the App observability contract suite covering privacy and bounded-storage invariants at their highest infrastructure seams.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skillsgo/domain/system_models.dart';
import 'package:skillsgo/infrastructure/io_process_runner.dart';
import 'package:skillsgo/infrastructure/logging/app_logger.dart';
import 'package:skillsgo/infrastructure/logging/human_log_formatter.dart';
import 'package:skillsgo/infrastructure/logging/rolling_text_log_sink.dart';

void main() {
  test(
    'AppLogger writes readable text and exposes redacted live data',
    () async {
      final directory = await Directory.systemTemp.createTemp('skillsgo-log-');
      final logger = AppLogger();
      addTearDown(() async {
        await logger.dispose();
        await directory.delete(recursive: true);
      });

      await logger.initialize(directory: directory);
      logger.info('installation', 'requested', {
        'token': 'secret-token',
        'stdin': 'private payload',
        'diagnostic':
            'password=hunter2 ${Platform.environment['HOME']}/project '
            'https://example.com/a?token=value#fragment',
      });
      await logger.flush();

      final requested = logger.recent().singleWhere(
        (event) => event.event == 'requested',
      );
      final data = requested.data;
      expect(data['token'], '<redacted>');
      expect(data['stdin'], '<redacted>');
      expect(data['diagnostic'], isNot(contains('hunter2')));
      expect(data['diagnostic'], isNot(contains('?token=')));
      expect(data['diagnostic'], contains(r'$HOME'));
      final text = await _readLogs(directory);
      expect(text, contains('INFO  [installation] requested'));
      expect(text, isNot(contains('{"')));
      expect(text, isNot(contains('secret-token')));
      expect(logger.sanitize({'hasStdin': true, 'stdinBytes': 42}), {
        'hasStdin': true,
        'stdinBytes': 42,
      });
      final preview = logger.humanPreview(
        '{"path":"/private/project","content":"private",'
        '"payload":{"code":"ready"}}',
      );
      expect(preview, startsWith('{\n'));
      expect(preview, contains('"path": "<path:'));
      expect(preview, contains('"content": "<redacted>"'));
      expect(preview, contains('"payload": {\n    "code": "ready"'));
    },
  );

  test('RollingTextLogSink rotates by size and deletes legacy logs', () async {
    final directory = await Directory.systemTemp.createTemp('skillsgo-roll-');
    addTearDown(() => directory.delete(recursive: true));
    var now = DateTime(2026, 7, 28, 12);
    final expired = File('${directory.path}/app-2026-07-20.log');
    await expired.writeAsString('expired\n');
    await expired.setLastModified(now.subtract(const Duration(days: 8)));
    final legacy = File('${directory.path}/app-2026-07-28.jsonl');
    await legacy.writeAsString('{"legacy":true}\n');
    final sink = RollingTextLogSink(
      directory: directory,
      clock: () => now,
      maxFileBytes: 90,
      maxDirectoryBytes: 250,
      cleanupInterval: 1,
    );
    await sink.initialize();

    for (var index = 0; index < 5; index++) {
      await sink.append('INFO [test] event-$index ${'a' * 45}');
    }

    expect(await expired.exists(), isFalse);
    expect(await legacy.exists(), isFalse);
    final files = await directory
        .list()
        .where((entry) => entry is File)
        .cast<File>()
        .toList();
    expect(files.length, greaterThan(1));
    expect(
      files.fold<int>(0, (total, file) => total + file.lengthSync()),
      lessThanOrEqualTo(250),
    );
  });

  test('AppLogger exports then clears all local text logs', () async {
    final directory = await Directory.systemTemp.createTemp('skillsgo-log-');
    final exportDirectory = await Directory.systemTemp.createTemp(
      'skillsgo-export-',
    );
    final logger = AppLogger();
    addTearDown(() async {
      await logger.dispose();
      await directory.delete(recursive: true);
      await exportDirectory.delete(recursive: true);
    });
    await logger.initialize(directory: directory);
    logger.info('app.lifecycle', 'test_event');
    final destination = File('${exportDirectory.path}/diagnostics.log');

    await logger.exportTo(destination);
    expect(await destination.readAsString(), contains('test_event'));
    expect(await logger.totalBytes(), greaterThan(0));
    await logger.clear();
    expect(await logger.totalBytes(), 0);
  });

  test(
    'IoProcessRunner records sanitized success and failure summaries',
    () async {
      final directory = await Directory.systemTemp.createTemp('skillsgo-cli-');
      addTearDown(() async {
        await appLogger.dispose();
        await directory.delete(recursive: true);
      });
      await appLogger.initialize(directory: directory);
      const runner = IoProcessRunner();

      final success = await runner.run('/usr/bin/printf', ['ok']);
      final failure = await runner.run('/usr/bin/false', [
        'find',
        'private search',
        '--token',
        'secret',
        '--installed',
        '{"path":"/private/project"}',
      ]);
      await appLogger.flush();

      expect(success.exitCode, 0);
      expect(failure.exitCode, isNot(0));
      final events = appLogger.recent();
      final starts = events
          .where((event) => event.event == 'invocation_started')
          .toList();
      expect(starts, hasLength(2));
      final failureStart = starts.last.data;
      expect(
        failureStart['arguments'].toString(),
        contains('<query:redacted>'),
      );
      expect(failureStart['arguments'].toString(), isNot(contains('secret')));
      expect(
        failureStart['arguments'].toString(),
        isNot(contains('/private/project')),
      );
      expect(
        events.any((event) => event.event == 'invocation_finished'),
        isTrue,
      );
      expect(
        events
            .firstWhere((event) => event.event == 'invocation_finished')
            .data['responsePreview'],
        'ok',
      );
      final failureEvent = events.firstWhere(
        (event) => event.event == 'invocation_failed',
      );
      expect(failureEvent.data['executable'], 'false');
      expect(failureEvent.data['arguments'].toString(), contains('find'));
      expect(
        failureEvent.data['arguments'].toString(),
        contains('<query:redacted>'),
      );
      expect(failureEvent.formatted, contains('executable=false'));
      expect(failureEvent.formatted, contains('arguments=find'));
      expect(events.any((event) => event.event == 'invocation_failed'), isTrue);
    },
  );

  test('HumanLogFormatter keeps normal fields on one readable line', () {
    final entry = DiagnosticLogEntry(
      time: DateTime(2026, 7, 28, 11, 28, 4, 126),
      level: DiagnosticLogLevel.warning,
      category: 'gateway.cli',
      event: 'invocation_failed',
      formatted: '',
      data: const {'exitCode': 69, 'durationMs': 5487},
      error:
          'Hub returned HTTP 502: '
          '{"error":"update failed","code":"resolution_failed"}',
      stackTrace: '#0 first\n#1 second',
    );

    expect(
      const HumanLogFormatter().format(entry),
      '2026-07-28 11:28:04.126 WARN  [gateway.cli] invocation_failed | '
      'exit=69 | duration=5487ms\n'
      '  Hub returned HTTP 502: error:update failed,code:resolution_failed\n'
      '  #0 first\n'
      '  #1 second',
    );
  });

  test('HumanLogFormatter pretty prints JSON response previews', () {
    final entry = DiagnosticLogEntry(
      time: DateTime(2026, 7, 28, 13, 41, 18, 974),
      level: DiagnosticLogLevel.info,
      category: 'gateway.cli',
      event: 'invocation_finished',
      formatted: '',
      data: const {
        'responsePreview':
            '{"schemaVersion":1,"result":{"adopted":2,"failed":0}}',
      },
    );

    expect(
      const HumanLogFormatter().format(entry),
      '2026-07-28 13:41:18.974 INFO  [gateway.cli] invocation_finished\n'
      '  response:\n'
      '    {\n'
      '      "schemaVersion": 1,\n'
      '      "result": {\n'
      '        "adopted": 2,\n'
      '        "failed": 0\n'
      '      }\n'
      '    }',
    );
  });

  test('HumanLogFormatter preserves a non-JSON response preview', () {
    final entry = DiagnosticLogEntry(
      time: DateTime(2026, 7, 28, 13, 41, 18, 974),
      level: DiagnosticLogLevel.info,
      category: 'gateway.cli',
      event: 'invocation_finished',
      formatted: '',
      data: const {'responsePreview': 'installed successfully'},
    );

    expect(
      const HumanLogFormatter().format(entry),
      contains('\n  response:\n    installed successfully'),
    );
  });
}

Future<String> _readLogs(Directory directory) async {
  final files = await directory
      .list()
      .where((entry) => entry is File && entry.path.endsWith('.log'))
      .cast<File>()
      .toList();
  final output = StringBuffer();
  for (final file in files) {
    output.write(await file.readAsString());
  }
  return output.toString();
}
