/*
 * [INPUT]: Depends on the shared gateway state, Hub runtime discovery, direct Cloud HTTP ranking reads, content locale, CLI Skill reads, strict machine codecs, and discovery domain models.
 * [OUTPUT]: Provides locale-aware Hub Find search plus Cloud Ranking/Trending/Hot hydration through ordered Hub batch Skill cards, direct explicit-source routing, and remote Skill detail loading.
 * [POS]: Serves as the public discovery capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayDiscovery on _RealSkillsGatewayCore {
  @override
  Future<DiscoveryPage> discover(
    DiscoveryCollection collection, {
    String query = '',
    int offset = 0,
    int limit = 20,
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
      DiscoveryCollection.search => 'search',
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
          '--offset',
          '$offset',
          '--limit',
          '$limit',
        ]);
        if (!result.succeeded) throw _commandFailure(result);
        decoded = jsonDecode(result.output.stdout);
      } else {
        decoded = await _loadCloudRanking(
          expectedCollection,
          offset: offset,
          limit: limit,
        );
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['collection'] != expectedCollection ||
          decoded['skills'] is! List ||
          decoded['page'] is! Map<String, dynamic>) {
        throw const SkillsException(
          'Discovery service returned an invalid response.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final page = decoded['page'] as Map<String, dynamic>;
      final nextRaw = page['nextOffset'];
      if (page['limit'] is! num ||
          page['offset'] is! num ||
          (nextRaw != null && nextRaw is! num)) {
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
          if (skill.skillId.isNotEmpty) {
            installedCounts[skill.skillId] = skill.targetCount;
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
            final source = raw['source'];
            final installName =
                raw['skillPath'] is String &&
                    (raw['skillPath'] as String).isNotEmpty
                ? p.basename(raw['skillPath'] as String)
                : raw['name'];
            final id = raw['id'];
            final name = raw['name'];
            final description = raw['description'];
            final version = raw['latestVersion'];
            if (source is! String ||
                installName is! String ||
                id is! String ||
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
              id: id,
              installName: installName,
              name: name,
              source: source,
              imageUrl: imageUrl as String?,
              description: description,
              installs: metric is Map<String, dynamic>
                  ? (metric['value'] as num).toInt()
                  : 0,
              latestVersion: version,
              trustLevel: _trustLevel(raw['trustLevel']),
              riskAssessment: _riskAssessment(raw['riskAssessment']),
              metricKind: metric is Map<String, dynamic>
                  ? _metricKind(metric['kind'] as String)
                  : null,
              metricChange: metric is Map<String, dynamic>
                  ? (metric['change'] as num).toInt()
                  : 0,
              localTargetCount: installedCounts[id] ?? 0,
            );
          })
          .toList(growable: false);
      return DiscoveryPage(
        skills: skills,
        nextOffset: nextRaw == null ? null : (nextRaw as num).toInt(),
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

  Future<Map<String, dynamic>> _loadCloudRanking(
    String collection, {
    required int offset,
    required int limit,
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
      'api/v1/rankings/$collection?offset=$offset&limit=$limit',
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
          cloudDocument['collection'] != collection ||
          cloudDocument['items'] is! List ||
          cloudDocument['page'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid Cloud ranking response.');
      }
      final items = cloudDocument['items'] as List;
      final skillIDs = <String>[];
      final metrics = <String, Map<String, dynamic>>{};
      for (final raw in items) {
        if (raw is! Map<String, dynamic> ||
            raw['skillId'] is! String ||
            raw['metric'] is! Map<String, dynamic>) {
          throw const FormatException('Invalid Cloud ranking item.');
        }
        final skillID = raw['skillId'] as String;
        if (metrics.containsKey(skillID)) {
          throw const FormatException('Duplicate Cloud ranking Skill.');
        }
        skillIDs.add(skillID);
        metrics[skillID] = raw['metric'] as Map<String, dynamic>;
      }
      if (skillIDs.isEmpty) {
        return {
          'collection': collection,
          'skills': <Object>[],
          'page': cloudDocument['page'],
        };
      }
      final detailResult = await _runCli([
        'detail',
        for (final skillID in skillIDs) ...['--skill', skillID],
        '--hub',
        _hubOrigin,
      ]);
      if (!detailResult.succeeded) throw _commandFailure(detailResult);
      final hydrated = jsonDecode(detailResult.output.stdout);
      if (hydrated is! Map<String, dynamic> || hydrated['skills'] is! List) {
        throw const FormatException('Invalid Hub Skill batch response.');
      }
      final byID = <String, Map<String, dynamic>>{};
      for (final raw in hydrated['skills'] as List) {
        if (raw is! Map<String, dynamic> || raw['id'] is! String) {
          throw const FormatException('Invalid Hub Skill card.');
        }
        byID[raw['id'] as String] = raw;
      }
      final skills = <Map<String, dynamic>>[];
      for (final skillID in skillIDs) {
        final skill = byID[skillID];
        if (skill == null) continue;
        skills.add({...skill, 'metric': metrics[skillID]});
      }
      return {
        'collection': collection,
        'skills': skills,
        'page': cloudDocument['page'],
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
      'info',
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
          decoded['SchemaVersion'] != 1 ||
          decoded['Kind'] is! String) {
        throw const FormatException('Invalid SkillsGo Info response.');
      }
      final rawSkills = switch (decoded['Kind']) {
        'Skill' => <Object?>[decoded],
        'Repository' when decoded['Skills'] is List =>
          decoded['Skills'] as List,
        _ => throw const FormatException('Unknown SkillsGo Info kind.'),
      };
      final installedCounts = <String, int>{};
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        for (final skill in installed) {
          if (skill.skillId.isNotEmpty) {
            installedCounts[skill.skillId] = skill.targetCount;
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
            final id = raw['ID'];
            final name = raw['Name'];
            final description = raw['Description'];
            final version = raw['Version'];
            if (id is! String ||
                name is! String ||
                description is! String ||
                version is! String) {
              throw const FormatException('Incomplete Skill Info member.');
            }
            final imageURL = raw['ImageURL'];
            if (imageURL != null && imageURL is! String) {
              throw const FormatException('Invalid Skill Info image URL.');
            }
            final repository = id.split('/-/').first;
            return SkillSummary(
              id: id,
              installName: name,
              name: name,
              source: repository,
              imageUrl: imageURL as String?,
              description: description,
              latestVersion: version,
              trustLevel: _trustLevel(raw['TrustLevel']),
              riskAssessment: _riskAssessment(raw['RiskAssessment']),
              localTargetCount: installedCounts[id] ?? 0,
            );
          })
          .toList(growable: false);
      final firstSkill = rawSkills.isEmpty ? null : rawSkills.first;
      final firstSkillMap = firstSkill is Map<String, dynamic>
          ? firstSkill
          : null;
      final repositoryID = decoded['Kind'] == 'Repository'
          ? decoded['ID']
          : skills.isEmpty
          ? null
          : skills.first.source;
      final repositoryTime = decoded['Time'];
      return DiscoveryPage(
        skills: skills,
        repository: repositoryID is String
            ? RepositorySummary(
                id: repositoryID,
                imageUrl: firstSkillMap?['ImageURL'] as String?,
                description: decoded['Description'] is String
                    ? decoded['Description'] as String
                    : '',
                stars: firstSkillMap?['Stars'] is num
                    ? (firstSkillMap!['Stars'] as num).toInt()
                    : 0,
                latestVersion: decoded['Version'] is String
                    ? decoded['Version'] as String
                    : skills.isEmpty
                    ? ''
                    : skills.first.latestVersion,
                updatedAt: repositoryTime is String
                    ? DateTime.tryParse(repositoryTime)
                    : null,
                license: decoded['License'] is String
                    ? decoded['License'] as String
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
        'detail',
        skill.id,
        '--hub',
        _hubOrigin,
        '--content-locale',
        await _contentLocale(),
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
        'id',
        'name',
        'description',
        'source',
        'repository',
        'requestedVersion',
        'immutableVersion',
        'commitSHA',
        'treeSHA',
        'sourceRef',
        'sum',
        'instructions',
        'trustLevel',
      ];
      if (requiredStrings.any((field) => decoded[field] is! String) ||
          (decoded['imageUrl'] != null && decoded['imageUrl'] is! String) ||
          decoded['stars'] is! num ||
          decoded['sourceUpdatedAt'] is! String ||
          decoded['archiveSize'] is! num ||
          decoded['id'] != skill.id ||
          decoded['riskAssessment'] is! Map<String, dynamic> ||
          decoded['files'] is! List ||
          decoded['hasExecutableContent'] is! bool ||
          decoded['executableFiles'] is! List) {
        throw const SkillsException(
          'Skill detail is missing required fields.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final risk = decoded['riskAssessment'] as Map<String, dynamic>;
      if (risk['level'] is! String ||
          risk['scannerVersion'] is! String ||
          risk['evidence'] is! List) {
        throw const SkillsException(
          'Skill Risk Assessment is invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      final evidence = (risk['evidence'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['code'] is! String ||
                raw['path'] is! String) {
              throw const SkillsException(
                'Skill risk evidence is invalid.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            return SkillRiskEvidence(
              code: raw['code'] as String,
              path: raw['path'] as String,
            );
          })
          .toList(growable: false);
      final files = (decoded['files'] as List)
          .map((raw) {
            if (raw is! Map<String, dynamic> ||
                raw['path'] is! String ||
                raw['size'] is! num ||
                raw['kind'] is! String ||
                raw['executable'] is! bool ||
                raw['binary'] is! bool ||
                raw['truncated'] is! bool ||
                (raw['content'] != null && raw['content'] is! String)) {
              throw const SkillsException(
                'Skill file inventory is invalid.',
                kind: SkillsFailureKind.invalidResponse,
              );
            }
            return SkillFile(
              path: raw['path'] as String,
              contents: raw['content'] as String? ?? '',
              size: (raw['size'] as num).toInt(),
              kind: raw['kind'] as String,
              executable: raw['executable'] as bool,
              binary: raw['binary'] as bool,
              truncated: raw['truncated'] as bool,
            );
          })
          .toList(growable: false);
      if ((decoded['executableFiles'] as List).any((path) => path is! String)) {
        throw const SkillsException(
          'Executable file signals are invalid.',
          kind: SkillsFailureKind.invalidResponse,
        );
      }
      var installationTargets = <SkillInstallationTarget>[];
      try {
        final installed = await listInstalled(
          projects: await loadAddedProjects(),
        );
        installationTargets = installed
            .where((entry) => entry.skillId == skill.id)
            .expand((entry) => entry.targets)
            .toList(growable: false);
      } on Object {
        // Remote artifact inspection stays available without local CLI state.
      }
      return SkillDetail(
        name: decoded['name'] as String,
        source: decoded['source'] as String,
        markdown: decoded['instructions'] as String,
        files: files,
        imageUrl: decoded['imageUrl'] as String?,
        repository: decoded['repository'] as String,
        stars: (decoded['stars'] as num).toInt(),
        sourceUpdatedAt: DateTime.parse(
          decoded['sourceUpdatedAt'] as String,
        ).toLocal(),
        archiveSize: (decoded['archiveSize'] as num).toInt(),
        description: decoded['description'] as String,
        requestedVersion: decoded['requestedVersion'] as String,
        immutableVersion: decoded['immutableVersion'] as String,
        commitSHA: decoded['commitSHA'] as String,
        treeSHA: decoded['treeSHA'] as String,
        sourceRef: decoded['sourceRef'] as String,
        sum: decoded['sum'] as String,
        trustLevel: _trustLevel(decoded['trustLevel']),
        riskAssessment: _riskAssessment(risk['level']),
        riskScannerVersion: risk['scannerVersion'] as String,
        riskEvidence: evidence,
        installationTargets: installationTargets,
        hubExecutableSignal: decoded['hasExecutableContent'] as bool,
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
