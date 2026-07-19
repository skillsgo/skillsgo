/*
 * [INPUT]: Depends on dart:io local directory metadata, JSON cache records, path normalization, and SharedPreferences persistence.
 * [OUTPUT]: Provides bounded, non-following, high-confidence project icon discovery with cache-first reads and safe fallback behavior.
 * [POS]: Serves as the infrastructure resolver that enriches explicit Added Projects without blocking their primary loading path.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/skills_gateway.dart';

class ProjectIconResolver {
  const ProjectIconResolver();

  static Future<void> _cacheWrites = Future<void>.value();
  static const _cacheKey = 'project_icons_v1';
  static const _maxDepth = 3;
  static const _maxBytes = 5 * 1024 * 1024;
  static const _extensions = {'.png', '.jpg', '.jpeg', '.webp', '.svg', '.ico'};
  static const _names = {
    'icon',
    'app-icon',
    'app_icon',
    'logo',
    'app-logo',
    'app_logo',
    'favicon',
  };
  static const _excludedDirectories = {
    '.git',
    '.dart_tool',
    'node_modules',
    'vendor',
    'pods',
    'build',
    'dist',
    'target',
  };
  static const _trustedDirectories = {
    '',
    'assets',
    'images',
    'icons',
    'public',
    'static',
    'resources',
    'src/assets',
    'assets/icons',
    'public/icons',
    'static/icons',
    'resources/icons',
  };

  Future<ProjectIcon?> cached(String projectId) async {
    final records = await _records();
    final record = records[projectId];
    if (record is! Map<String, dynamic>) return null;
    final path = record['path'];
    final fingerprint = record['fingerprint'];
    if (path is! String || fingerprint is! String) return null;
    final file = File(path);
    try {
      final stat = await file.stat();
      if (_fingerprint(stat) != fingerprint) return null;
      return ProjectIcon(path: path, sourceFingerprint: fingerprint);
    } on FileSystemException {
      return null;
    }
  }

  Future<ProjectIcon?> resolve(AddedProject project) async {
    if (!project.isAccessible) return null;
    final root = Directory(project.path);
    final rootPath = p.normalize(p.absolute(root.path));
    final candidates = <_ProjectIconCandidate>[];
    final projectName = _normalizedName(project.name);
    await _scan(root, rootPath, projectName, 0, candidates);
    candidates.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      return left.relativePath.compareTo(right.relativePath);
    });
    if (candidates.isEmpty || candidates.first.score < 70) {
      await _save(project.id, null);
      return null;
    }
    final selected = candidates.first;
    final stat = await selected.file.stat();
    final icon = ProjectIcon(
      path: selected.file.path,
      sourceFingerprint: _fingerprint(stat),
    );
    await _save(project.id, icon);
    return icon;
  }

  Future<void> _scan(
    Directory directory,
    String rootPath,
    String projectName,
    int depth,
    List<_ProjectIconCandidate> candidates,
  ) async {
    if (depth > _maxDepth) return;
    List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } on FileSystemException {
      return;
    }
    for (final entry in entries) {
      if (entry is Link) continue;
      final absolute = p.normalize(p.absolute(entry.path));
      if (!p.isWithin(rootPath, absolute)) continue;
      if (entry is Directory) {
        final name = p.basename(entry.path).toLowerCase();
        if (depth < _maxDepth && !_excludedDirectories.contains(name)) {
          await _scan(entry, rootPath, projectName, depth + 1, candidates);
        }
        continue;
      }
      if (entry is! File) continue;
      final extension = p.extension(entry.path).toLowerCase();
      final basename = p.basenameWithoutExtension(entry.path).toLowerCase();
      final normalizedBasename = _normalizedName(basename);
      final projectLogo =
          normalizedBasename == '${projectName}logo' ||
          normalizedBasename == '${projectName}icon';
      if (!_extensions.contains(extension) ||
          (!_names.contains(basename) && !projectLogo)) {
        continue;
      }
      final relative = p.relative(entry.path, from: rootPath);
      final parent = p.dirname(relative) == '.'
          ? ''
          : p.dirname(relative).replaceAll('\\', '/').toLowerCase();
      final parentName = p.basename(parent);
      if (!_trustedDirectories.contains(parent) &&
          !_trustedDirectories.contains(parentName)) {
        continue;
      }
      FileStat stat;
      try {
        stat = await entry.stat();
        if (stat.type != FileSystemEntityType.file ||
            stat.size <= 0 ||
            stat.size > _maxBytes) {
          continue;
        }
        if (extension == '.svg') {
          if (!await _safeSvg(entry)) continue;
        } else if (!await _validRasterHeader(entry, extension)) {
          continue;
        }
      } on FileSystemException {
        continue;
      }
      var score = basename == 'favicon'
          ? 104
          : basename.contains('app')
          ? 96
          : projectLogo
          ? 92
          : basename == 'icon'
          ? 88
          : 70;
      if (parent.isEmpty) score += 12;
      if (_trustedDirectories.contains(parent)) score += 8;
      score -= depth * 3;
      candidates.add(
        _ProjectIconCandidate(
          file: entry,
          relativePath: relative,
          score: score,
        ),
      );
    }
  }

  Future<bool> _safeSvg(File file) async {
    final source = await file
        .openRead(0, 64 * 1024)
        .transform(utf8.decoder)
        .join();
    final lower = source.toLowerCase();
    return lower.contains('<svg') &&
        !lower.contains('<script') &&
        !lower.contains('javascript:') &&
        !lower.contains('file://') &&
        !RegExp(r'''(?:href|src)\s*=\s*["']https?://''').hasMatch(lower);
  }

  Future<bool> _validRasterHeader(File file, String extension) async {
    final bytes = await file
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
    bool startsWith(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(signature.length, (index) => bytes[index]).join(',') ==
            signature.join(',');
    return switch (extension) {
      '.png' => startsWith(const [137, 80, 78, 71, 13, 10, 26, 10]),
      '.jpg' || '.jpeg' => startsWith(const [255, 216, 255]),
      '.webp' =>
        bytes.length >= 12 &&
            String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
            String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP',
      '.ico' => startsWith(const [0, 0, 1, 0]),
      _ => false,
    };
  }

  String _fingerprint(FileStat stat) =>
      '${stat.size}:${stat.modified.millisecondsSinceEpoch}';

  String _normalizedName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  Future<Map<String, dynamic>> _records() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  Future<void> _save(String projectId, ProjectIcon? icon) async {
    _cacheWrites = _cacheWrites.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final records = await _records();
      if (icon == null) {
        records.remove(projectId);
      } else {
        records[projectId] = {
          'path': icon.path,
          'fingerprint': icon.sourceFingerprint,
        };
      }
      await preferences.setString(_cacheKey, jsonEncode(records));
    });
    await _cacheWrites;
  }
}

class _ProjectIconCandidate {
  const _ProjectIconCandidate({
    required this.file,
    required this.relativePath,
    required this.score,
  });

  final File file;
  final String relativePath;
  final int score;
}
