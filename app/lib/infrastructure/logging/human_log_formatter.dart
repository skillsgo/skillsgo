/*
 * [INPUT]: Depends on Dart JSON decoding, sanitized DiagnosticLogEntry values, and stable structured event fields produced by AppLogger callers.
 * [OUTPUT]: Provides compact fixed-order human-readable log lines with indented request, pretty-printed JSON response, error, and stack continuation lines.
 * [POS]: Serves as the single presentation policy shared by on-disk logs and the in-App live diagnostic viewer.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';

import '../../domain/system_models.dart';

final class HumanLogFormatter {
  const HumanLogFormatter();

  String format(DiagnosticLogEntry entry) {
    final buffer = StringBuffer()
      ..write(_timestamp(entry.time))
      ..write(' ')
      ..write(entry.level.label.padRight(5))
      ..write(' [${entry.category}] ')
      ..write(entry.event);
    final details = _details(entry.data);
    if (details.isNotEmpty) buffer.write(' | $details');
    _writePreview(buffer, 'request', entry.data['requestPreview']);
    _writePreview(
      buffer,
      'response',
      _formatJsonResponse(entry.data['responsePreview']),
    );
    if (entry.error case final error?) {
      buffer.write('\n  ${_singleLine(error)}');
    }
    if (entry.stackTrace case final stack?) {
      for (final line in stack.split('\n')) {
        if (line.trim().isNotEmpty) buffer.write('\n  ${line.trimRight()}');
      }
    }
    return buffer.toString();
  }

  String _details(Map<String, Object?> data) {
    final parts = <String>[];
    for (final entry in data.entries) {
      if (entry.key == 'invocationId' || entry.key == 'operationId') continue;
      if (entry.key == 'requestPreview' || entry.key == 'responsePreview') {
        continue;
      }
      final value = _valueFor(entry.key, entry.value);
      if (value.isEmpty) continue;
      parts.add('${_label(entry.key)}=$value');
    }
    return parts.join(' | ');
  }

  void _writePreview(StringBuffer buffer, String label, Object? value) {
    if (value is! String || value.isEmpty) return;
    buffer.write('\n  $label:');
    for (final line in value.split('\n')) {
      buffer.write('\n    ${line.trimRight()}');
    }
  }

  Object? _formatJsonResponse(Object? value) {
    if (value is! String || value.trim().isEmpty) return value;
    final trimmed = value.trim();
    final whole = _prettyJson(trimmed);
    if (whole != null) return whole;

    // Streaming CLI responses use newline-delimited JSON. Format them record by
    // record only when every non-empty line is valid JSON; mixed diagnostic
    // output must remain byte-for-byte readable.
    final lines = trimmed.split('\n').where((line) => line.trim().isNotEmpty);
    final formatted = <String>[];
    for (final line in lines) {
      final pretty = _prettyJson(line.trim());
      if (pretty == null) return value;
      formatted.add(pretty);
    }
    return formatted.join('\n');
  }

  String? _prettyJson(String value) {
    try {
      final decoded = jsonDecode(value);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } on FormatException {
      return null;
    }
  }

  String _valueFor(String key, Object? value) {
    if (value == false) return '';
    if (value is num) {
      if (key == 'durationMs') return '${value}ms';
      if (key == 'stdoutBytes' ||
          key == 'stderrBytes' ||
          key == 'stdinBytes' ||
          key == 'maxDirectoryBytes') {
        return '${value}B';
      }
    }
    return _value(value);
  }

  String _value(Object? value) => switch (value) {
    null => '',
    List() => value.map(_value).where((item) => item.isNotEmpty).join(' '),
    Map() =>
      value.entries
          .map((entry) => '${entry.key}:${_value(entry.value)}')
          .join(','),
    _ => _singleLine(value.toString()),
  };

  String _label(String key) => switch (key) {
    'durationMs' => 'duration',
    'exitCode' => 'exit',
    'stdoutBytes' => 'stdout',
    'stderrBytes' => 'stderr',
    'stdinBytes' => 'stdin',
    _ => key,
  };

  String _singleLine(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ');
    final start = compact.indexOf('{');
    if (start < 0 || !compact.endsWith('}')) return compact;
    try {
      final decoded = jsonDecode(compact.substring(start));
      if (decoded is! Map) return compact;
      final fields = decoded.entries
          .map((entry) => '${entry.key}:${_value(entry.value)}')
          .join(',');
      return '${compact.substring(0, start).trimRight()} $fields';
    } on FormatException {
      return compact;
    }
  }

  String _timestamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}.'
      '${value.millisecond.toString().padLeft(3, '0')}';
}
