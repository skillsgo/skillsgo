/*
 * [INPUT]: Depends on shared gateway state, the single Hub Origin, content locale, CLI Skill/ranking reads and source-language candidate Find, strict machine codecs, and discovery domain models.
 * [OUTPUT]: Provides current-language unified CLI Find enriched with local target counts and versions, source-language server-ranked Adoption candidate confidence, versions, and Package avatar decoding, system-proxy-aware Hub Ranking/Trending/Hot, and translation-aware Git Artifact Package Version Skill detail with immutable Package size, exact Skill targets, and Package-scope version targets through `show --path`.
 * [POS]: Serves as the public discovery capability inside the DesktopSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'desktop_skills_gateway.dart';

bool _isCloudRankingDocument(Object? value) {
  if (value is! Map<String, dynamic> ||
      value['skills'] is! List ||
      value['pagination'] is! Map<String, dynamic>) {
    return false;
  }
  final pagination = value['pagination'] as Map<String, dynamic>;
  if (pagination['page'] is! num ||
      pagination['perPage'] is! num ||
      pagination['hasMore'] is! bool) {
    return false;
  }
  return (value['skills'] as List).every((raw) {
    if (raw is! Map<String, dynamic> ||
        raw['packagePath'] is! String ||
        raw['name'] is! String ||
        raw['description'] is! String ||
        raw['path'] is! String ||
        raw['latestVersion'] is! String ||
        (raw['imageUrl'] != null && raw['imageUrl'] is! String) ||
        raw['metric'] is! Map<String, dynamic>) {
      return false;
    }
    final metric = raw['metric'] as Map<String, dynamic>;
    return metric['value'] is num &&
        (metric['change'] == null || metric['change'] is num);
  });
}

const _sourceFindChunkSize = 80;
const _sourceFindConcurrentChunks = 2;
const _sourceFindRequestLimit = 5000;

mixin _DesktopSkillsGatewayDiscovery on _DesktopSkillsGatewayCore {
  @override
  Future<DiscoveryPage> discover(
    DiscoveryCollection collection, {
    String query = '',
    int page = 0,
    int perPage = 20,
  }) async {
    final trimmedQuery = query.trim();
    if (collection == DiscoveryCollection.search && trimmedQuery.isEmpty) {
      throw const SkillsException(
        'Search query is required.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final expectedCollection = switch (collection) {
      DiscoveryCollection.search => 'find',
      DiscoveryCollection.ranking => 'all_time',
      DiscoveryCollection.trending => 'trending',
      DiscoveryCollection.hot => 'hot',
    };
    try {
      final dynamic decoded;
      if (collection == DiscoveryCollection.search) {
        final result = await _runCli([
          'find',
          trimmedQuery,
          '--hub',
          _hubOrigin,
          '--lang',
          await _contentLang(),
          '--page',
          '$page',
          '--per-page',
          '$perPage',
          '--output',
          'json',
        ], retryOnTransportFailure: true);
        if (!result.succeeded) throw _commandFailure(result);
        decoded = jsonDecode(result.output.stdout);
      } else {
        decoded = await _loadHubRanking(
          expectedCollection,
          page: page,
          perPage: perPage,
        );
      }
      if (decoded is! Map<String, dynamic> ||
          (collection != DiscoveryCollection.search &&
              decoded['collection'] != expectedCollection) ||
          decoded['skills'] is! List ||
          decoded['pagination'] is! Map<String, dynamic>) {
        throw const SkillsException(
          'Discovery service returned an invalid response.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final pagination = decoded['pagination'] as Map<String, dynamic>;
      if (pagination['page'] is! num ||
          pagination['perPage'] is! num ||
          pagination['hasMore'] is! bool) {
        throw const SkillsException(
          'Discovery pagination is invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final rawSkills = decoded['skills'] as List;
      final installedCounts = <String, int>{};
      final installedVersions = <String, Set<String>>{};
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        for (final skill in installed) {
          if (skill.packagePath.isNotEmpty) {
            installedCounts['${skill.packagePath}\u0000${skill.name}'] =
                skill.targetCount;
            installedVersions
                .putIfAbsent(
                  '${skill.packagePath}\u0000${skill.name}',
                  () => <String>{},
                )
                .addAll(skill.versions);
          }
        }
      } on Object {
        // Discovery remains available when local CLI inventory is unavailable.
      }
      final skills = rawSkills
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const SkillsException(
                'Invalid discovery result.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            final installName =
                raw['path'] is String && (raw['path'] as String).isNotEmpty
                ? p.basename(raw['path'] as String)
                : raw['name'];
            final packagePath = raw['packagePath'];
            final name = raw['name'];
            final description = raw['description'];
            final version = raw['latestVersion'];
            if (installName is! String ||
                packagePath is! String ||
                name is! String ||
                description is! String ||
                version is! String) {
              throw const SkillsException(
                'Discovery result is missing required fields.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            final imageUrl = raw['imageUrl'];
            if (imageUrl != null && imageUrl is! String) {
              throw const SkillsException(
                'Discovery image URL is invalid.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            final metric = raw['metric'];
            if (collection != DiscoveryCollection.search &&
                (metric is! Map<String, dynamic> ||
                    metric['kind'] is! String ||
                    metric['value'] is! num ||
                    metric['change'] is! num)) {
              throw const SkillsException(
                'Cloud ranking result is missing its metric.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            return SkillSummary(
              packagePath: packagePath,
              installName: installName,
              name: name,
              path: raw['path'] is String ? raw['path'] as String : '',
              imageUrl: imageUrl as String?,
              description: description,
              installs: metric is Map<String, dynamic>
                  ? (metric['value'] as num).toInt()
                  : 0,
              latestVersion: version,
              metricKind: metric is Map<String, dynamic>
                  ? _metricKind(metric['kind'] as String)
                  : null,
              metricChange: metric is Map<String, dynamic>
                  ? (metric['change'] as num).toInt()
                  : 0,
              localTargetCount: installedCounts['$packagePath\u0000$name'] ?? 0,
              localVersions: List.unmodifiable(
                installedVersions['$packagePath\u0000$name'] ?? const {},
              ),
            );
          })
          .toList(growable: false);
      final rawPackage = decoded['package'];
      if (rawPackage != null &&
          (rawPackage is! Map<String, dynamic> ||
              rawPackage['packagePath'] is! String ||
              rawPackage['description'] is! String ||
              rawPackage['stars'] is! num ||
              rawPackage['latestVersion'] is! String ||
              rawPackage['updatedAt'] is! String)) {
        throw const SkillsException(
          'Discovery Package summary is invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final package = rawPackage is Map<String, dynamic>
          ? PackageSummary(
              id: rawPackage['packagePath'] as String,
              description: rawPackage['description'] as String,
              stars: (rawPackage['stars'] as num).toInt(),
              latestVersion: rawPackage['latestVersion'] as String,
              updatedAt: DateTime.tryParse(rawPackage['updatedAt'] as String),
            )
          : null;
      return DiscoveryPage(
        skills: skills,
        module: package,
        pagination: Pagination(
          page: (pagination['page'] as num).toInt(),
          perPage: (pagination['perPage'] as num).toInt(),
          hasMore: pagination['hasMore'] as bool,
        ),
      );
    } on SkillsException {
      rethrow;
    } on FormatException {
      throw const SkillsException(
        'Discovery service returned invalid JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<List<List<AdoptionCandidate>>> findSources(
    List<PackageFindQuery> queries, {
    int limit = 10,
  }) async {
    if (queries.isEmpty ||
        queries.length > _sourceFindRequestLimit ||
        limit < 1 ||
        limit > 10) {
      throw const SkillsException(
        'Invalid Source Find request.',
        kind: SkillsFailureKind.validation,
      );
    }
    await _ensureHubOrigin();
    final chunks = <List<PackageFindQuery>>[
      for (var start = 0; start < queries.length; start += _sourceFindChunkSize)
        queries.sublist(
          start,
          (start + _sourceFindChunkSize).clamp(0, queries.length),
        ),
    ];
    final results = <List<AdoptionCandidate>>[];
    for (
      var start = 0;
      start < chunks.length;
      start += _sourceFindConcurrentChunks
    ) {
      final wave = chunks.sublist(
        start,
        (start + _sourceFindConcurrentChunks).clamp(0, chunks.length),
      );
      final waveResults = await Future.wait([
        for (final chunk in wave) _findSourceChunk(chunk, limit: limit),
      ]);
      for (final chunkResults in waveResults) {
        results.addAll(chunkResults);
      }
    }
    return results;
  }

  Future<List<List<AdoptionCandidate>>> _findSourceChunk(
    List<PackageFindQuery> queries, {
    required int limit,
  }) async {
    final request = jsonEncode({
      'queries': [
        for (final query in queries)
          {
            'name': query.name,
            if (query.description.trim().isNotEmpty)
              'description': query.description.trim(),
            if (query.packagePath.trim().isNotEmpty)
              'packagePath': query.packagePath.trim(),
          },
      ],
      'limit': limit,
    });
    final result = await _runCli(
      [
        'hub',
        'find-candidates',
        '--input',
        '-',
        '--hub',
        _hubOrigin,
        '--output',
        'json',
      ],
      stdin: request,
      retryOnTransportFailure: true,
    );
    if (!result.succeeded) throw _commandFailure(result);
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> || decoded['candidates'] is! List) {
        throw const FormatException();
      }
      final candidates = (decoded['candidates'] as List)
          .map((rawCandidates) {
            if (rawCandidates is! List) {
              throw const FormatException();
            }
            return rawCandidates
                .map(_decodeSkillCandidate)
                .toList(growable: false);
          })
          .toList(growable: false);
      if (candidates.length != queries.length) throw const FormatException();
      return candidates;
    } on FormatException {
      throw const SkillsException(
        'Find service returned invalid JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  AdoptionCandidate _decodeSkillCandidate(Object? raw) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final packagePath = raw['packagePath'];
    final name = raw['name'];
    final description = raw['description'];
    final versions = raw['versions'];
    final path = raw['path'];
    final imageUrl = raw['imageUrl'];
    final matchScore = raw['matchScore'];
    if (packagePath is! String ||
        name is! String ||
        description is! String ||
        versions is! List ||
        versions.isEmpty ||
        versions.any((item) => item is! String || item.isEmpty) ||
        versions.toSet().length != versions.length ||
        path is! String ||
        matchScore is! num ||
        matchScore < 0 ||
        matchScore > 1 ||
        imageUrl != null && imageUrl is! String) {
      throw const FormatException();
    }
    return AdoptionCandidate(
      packagePath: packagePath,
      name: name,
      path: path,
      description: description,
      versions: List<String>.unmodifiable(versions.cast<String>()),
      matchScore: matchScore.toDouble(),
      imageUrl: imageUrl as String?,
    );
  }

  Future<Map<String, dynamic>> _loadHubRanking(
    String collection, {
    required int page,
    required int perPage,
  }) async {
    final lang = await _contentLang();
    try {
      final result = await _runCli([
        'rankings',
        collection,
        '--hub',
        _hubOrigin,
        '--lang',
        lang,
        '--page',
        '$page',
        '--per-page',
        '$perPage',
        '--output',
        'json',
      ], retryOnTransportFailure: true);
      if (!result.succeeded) {
        throw _commandFailure(result);
      }
      final hubDocument = jsonDecode(result.output.stdout);
      if (!_isCloudRankingDocument(hubDocument)) {
        throw const FormatException('Invalid Hub ranking response.');
      }
      hubDocument as Map<String, dynamic>;
      final items = hubDocument['skills'] as List;
      final skills = <Map<String, dynamic>>[];
      for (final raw in items) {
        if (raw is! Map<String, dynamic> ||
            raw['packagePath'] is! String ||
            raw['name'] is! String ||
            raw['description'] is! String ||
            raw['path'] is! String ||
            raw['latestVersion'] is! String ||
            raw['metric'] is! Map<String, dynamic>) {
          throw const FormatException('Invalid Cloud ranking item.');
        }
        final metric = raw['metric'] as Map<String, dynamic>;
        if (metric['value'] is! num ||
            (metric['change'] != null && metric['change'] is! num)) {
          throw const FormatException('Invalid Cloud ranking metric.');
        }
        final metricKind = switch (collection) {
          'all_time' => 'all_time_installs',
          'trending' => 'installs_24h',
          'hot' => 'hot_velocity',
          _ => throw const FormatException('Invalid Cloud ranking kind.'),
        };
        skills.add({
          ...raw,
          'metric': {
            'kind': metricKind,
            'value': metric['value'],
            'change': metric['change'] ?? 0,
          },
        });
      }
      return {
        'collection': collection,
        'skills': skills,
        'pagination': hubDocument['pagination'],
      };
    } on FormatException {
      throw const SkillsException(
        'Invalid Hub ranking response.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<SkillDetail> loadRemoteDetail(
    SkillSummary skill, {
    bool source = false,
  }) async {
    await _ensureHubOrigin();
    try {
      final args = [
        'show',
        '${skill.packagePath}@${skill.latestVersion}',
        '--path',
        skill.path,
        '--hub',
        _hubOrigin,
        '--output',
        'json',
      ];
      if (!source) args.addAll(['--lang', await _contentLang()]);
      final result = await _runCli(args, retryOnTransportFailure: true);
      if (!result.succeeded) throw _commandFailure(result);
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic>) {
        throw const SkillsException(
          'Skill detail is invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      const requiredStrings = [
        'packagePath',
        'version',
        'name',
        'path',
        'description',
        'content',
        'sourceLanguage',
      ];
      if (requiredStrings.any((field) => decoded[field] is! String) ||
          decoded['time'] is! String ||
          decoded['packageSize'] is! num ||
          decoded['translated'] is! bool ||
          decoded['packagePath'] != skill.packagePath ||
          decoded['name'] != skill.name ||
          decoded['path'] != skill.path) {
        throw const SkillsException(
          'Skill detail is missing required fields.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      var installationTargets = <SkillInstallationTarget>[];
      var packageInstallationTargets = <SkillInstallationTarget>[];
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        final packageEntries = installed.where(
          (entry) => entry.packagePath == skill.packagePath,
        );
        installationTargets = packageEntries
            .where((entry) => entry.name == skill.name)
            .expand((entry) => entry.targets)
            .toList(growable: false);
        packageInstallationTargets = packageEntries
            .expand((entry) => entry.targets)
            .toList(growable: false);
      } on Object {
        // Remote artifact inspection stays available without local CLI state.
      }
      return SkillDetail(
        name: decoded['name'] as String,
        path: decoded['path'] as String,
        content: decoded['content'] as String,
        packagePath: decoded['packagePath'] as String,
        version: decoded['version'] as String,
        time: DateTime.parse(decoded['time'] as String).toLocal(),
        packageSize: (decoded['packageSize'] as num).toInt(),
        description: decoded['description'] as String,
        sourceLanguage: decoded['sourceLanguage'] as String,
        translated: decoded['translated'] as bool,
        installationTargets: installationTargets,
        packageInstallationTargets: packageInstallationTargets,
      );
    } on SkillsException {
      rethrow;
    } on FormatException {
      throw const SkillsException(
        'Skill detail returned invalid JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }
}
