/*
 * [INPUT]: Depends on the shared gateway state, Hub runtime discovery, direct Cloud-composed ranking reads, content locale, CLI Skill reads, strict machine codecs, and discovery domain models.
 * [OUTPUT]: Provides locale-aware single and bounded-chunk batch Hub Find plus Cloud-composed Ranking/Trending/Hot cards, direct `show` explicit-source routing, and strict `show --path` Package Version Skill detail loading.
 * [POS]: Serves as the public discovery capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

const _sourceFindChunkSize = 80;
const _sourceFindConcurrentChunks = 2;
const _sourceFindRequestLimit = 5000;

mixin _RealSkillsGatewayDiscovery on _RealSkillsGatewayCore {
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
    if (collection == DiscoveryCollection.search &&
        _looksLikeExplicitSkillSource(trimmedQuery)) {
      return _discoverExplicitSource(trimmedQuery);
    }
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
          '--content-locale',
          await _contentLocale(),
          '--page',
          '$page',
          '--per-page',
          '$perPage',
          '--output',
          'json',
        ]);
        if (!result.succeeded) throw _commandFailure(result);
        decoded = jsonDecode(result.output.stdout);
      } else {
        decoded = await _loadCloudRanking(
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
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        for (final skill in installed) {
          if (skill.packagePath.isNotEmpty) {
            installedCounts['${skill.packagePath}\u0000${skill.name}'] =
                skill.targetCount;
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
            );
          })
          .toList(growable: false);
      return DiscoveryPage(
        skills: skills,
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
  Future<List<List<SkillSummary>>> findSources(
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
    final locale = await _contentLocale();
    final chunks = <List<PackageFindQuery>>[
      for (var start = 0; start < queries.length; start += _sourceFindChunkSize)
        queries.sublist(
          start,
          (start + _sourceFindChunkSize).clamp(0, queries.length),
        ),
    ];
    final results = <List<SkillSummary>>[];
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
        for (final chunk in wave)
          _findSourceChunk(chunk, limit: limit, locale: locale),
      ]);
      for (final chunkResults in waveResults) {
        results.addAll(chunkResults);
      }
    }
    return results;
  }

  Future<List<List<SkillSummary>>> _findSourceChunk(
    List<PackageFindQuery> queries, {
    required int limit,
    required String locale,
  }) async {
    final request = jsonEncode({
      'queries': [
        for (final query in queries)
          {
            'name': query.name,
            if (query.packagePath.trim().isNotEmpty)
              'packagePath': query.packagePath.trim(),
          },
      ],
      'limit': limit,
    });
    final result = await _runCli([
      'find',
      '--input',
      '-',
      '--hub',
      _hubOrigin,
      '--content-locale',
      locale,
      '--output',
      'json',
    ], stdin: request);
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

  SkillSummary _decodeSkillCandidate(Object? raw) {
    if (raw is! Map<String, dynamic>) throw const FormatException();
    final packagePath = raw['packagePath'];
    final name = raw['name'];
    final description = raw['description'];
    final version = raw['version'];
    final path = raw['path'];
    if (packagePath is! String ||
        name is! String ||
        description is! String ||
        version is! String ||
        path is! String) {
      throw const FormatException();
    }
    return SkillSummary(
      packagePath: packagePath,
      installName: path.isNotEmpty ? p.basename(path) : name,
      name: name,
      path: path,
      description: description,
      latestVersion: version,
    );
  }

  Future<Map<String, dynamic>> _loadCloudRanking(
    String collection, {
    required int page,
    required int perPage,
  }) async {
    final runtime = await loadHubRuntime();
    final cloud = runtime.cloudOrigin;
    if (runtime.mode != HubMode.cloud || cloud == null) {
      throw const SkillsException(
        'Rankings are available only when the current Hub uses SkillsGo Cloud.',
        kind: SkillsFailureKind.validation,
      );
    }
    final uri = cloud.resolve(
      'api/v1/rankings/$collection?page=$page&perPage=$perPage',
    );
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw SkillsException(
          'Cloud ranking request failed with HTTP ${response.statusCode}.',
          kind: SkillsFailureKind.server,
        );
      }
      final cloudDocument = jsonDecode(body);
      if (cloudDocument is! Map<String, dynamic> ||
          cloudDocument['skills'] is! List ||
          cloudDocument['pagination'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid Cloud ranking response.');
      }
      final items = cloudDocument['skills'] as List;
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
        'pagination': cloudDocument['pagination'],
      };
    } on TimeoutException {
      throw const SkillsException(
        'Cloud ranking request timed out.',
        kind: SkillsFailureKind.timeout,
      );
    } on SocketException {
      throw const SkillsException(
        'Cloud ranking service is unavailable.',
        kind: SkillsFailureKind.offline,
      );
    } finally {
      client.close(force: true);
    }
  }

  static bool _looksLikeExplicitSkillSource(String query) {
    final value = query.trim();
    if (value.contains('://') || value.startsWith('git@')) return true;
    if (value.contains(RegExp(r'\s'))) return false;
    final coordinate = value.split('@').first;
    final segments = coordinate
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return segments.length >= 2;
  }

  Future<DiscoveryPage> _discoverExplicitSource(String source) async {
    final result = await _runCli([
      'show',
      source,
      '--hub',
      _hubOrigin,
      '--output',
      'json',
    ]);
    if (!result.succeeded) throw _commandFailure(result);
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['kind'] is! String) {
        throw const FormatException('Invalid SkillsGo Info response.');
      }
      final rawSkills = switch (decoded['kind']) {
        'Skill' => <Object?>[decoded],
        'Package' when decoded['skills'] is List => decoded['skills'] as List,
        _ => throw const FormatException('Unknown SkillsGo Info kind.'),
      };
      final installedCounts = <String, int>{};
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        for (final skill in installed) {
          if (skill.packagePath.isNotEmpty) {
            installedCounts['${skill.packagePath}\u0000${skill.name}'] =
                skill.targetCount;
          }
        }
      } on Object {
        // Explicit-source discovery remains useful without local inventory.
      }
      final skills = rawSkills
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Invalid Skill Info member.');
            }
            final packagePath = raw['packagePath'];
            final name = raw['name'];
            final description = raw['description'];
            final version = raw['version'];
            final path = raw['path'];
            if (packagePath is! String ||
                name is! String ||
                description is! String ||
                version is! String ||
                path is! String ||
                path.isEmpty) {
              throw const FormatException('Incomplete Skill Info member.');
            }
            final imageURL = raw['imageUrl'];
            if (imageURL != null && imageURL is! String) {
              throw const FormatException('Invalid Skill Info image URL.');
            }
            return SkillSummary(
              packagePath: packagePath,
              installName: name,
              name: name,
              path: path,
              imageUrl: imageURL as String?,
              description: description,
              latestVersion: version,
              localTargetCount: installedCounts['$packagePath\u0000$name'] ?? 0,
            );
          })
          .toList(growable: false);
      final firstSkill = rawSkills.isEmpty ? null : rawSkills.first;
      final firstSkillMap = firstSkill is Map<String, dynamic>
          ? firstSkill
          : null;
      final packagePath = decoded['kind'] == 'Package'
          ? decoded['packagePath']
          : skills.isEmpty
          ? null
          : skills.first.packagePath;
      final repositoryTime = decoded['time'];
      return DiscoveryPage(
        skills: skills,
        module: packagePath is String
            ? PackageSummary(
                id: packagePath,
                imageUrl: firstSkillMap?['imageUrl'] as String?,
                description: decoded['description'] is String
                    ? decoded['description'] as String
                    : '',
                stars: firstSkillMap?['stars'] is num
                    ? (firstSkillMap!['stars'] as num).toInt()
                    : 0,
                latestVersion: decoded['version'] is String
                    ? decoded['version'] as String
                    : skills.isEmpty
                    ? ''
                    : skills.first.latestVersion,
                updatedAt: repositoryTime is String
                    ? DateTime.tryParse(repositoryTime)
                    : null,
              )
            : null,
      );
    } on FormatException {
      throw const SkillsException(
        'SkillsGo Info returned invalid JSON.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  @override
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill) async {
    await _ensureHubOrigin();
    try {
      final result = await _runCli([
        'show',
        '${skill.packagePath}@${skill.latestVersion}',
        '--path',
        skill.path,
        '--hub',
        _hubOrigin,
        '--output',
        'json',
      ]);
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
      ];
      if (requiredStrings.any((field) => decoded[field] is! String) ||
          decoded['time'] is! String ||
          decoded['archiveSize'] is! num ||
          decoded['packagePath'] != skill.packagePath ||
          decoded['name'] != skill.name ||
          decoded['path'] != skill.path) {
        throw const SkillsException(
          'Skill detail is missing required fields.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      var installationTargets = <SkillInstallationTarget>[];
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        installationTargets = installed
            .where(
              (entry) =>
                  entry.packagePath == skill.packagePath &&
                  entry.name == skill.name,
            )
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
        archiveSize: (decoded['archiveSize'] as num).toInt(),
        description: decoded['description'] as String,
        installationTargets: installationTargets,
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
