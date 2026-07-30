/*
 * [INPUT]: Depends on the shared gateway state, SharedPreferences, secure randomness, CLI user-config project commands, directory pickers, project inspection, App locale, Hub health CLI command, and Cloud ranking HTTP protocol.
 * [OUTPUT]: Provides appearance with one-time randomized wallpaper initialization, language, reminder, onboarding, CLI-owned Added Project access, independent Hub/Cloud origin configuration, risk policy, and App-version persistence operations.
 * [POS]: Serves as the local preference and CLI-backed project-reference capability inside the DesktopSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'desktop_skills_gateway.dart';

mixin _DesktopSkillsGatewayPreferences on _DesktopSkillsGatewayCore {
  @override
  Future<UpdateCheckCache?> loadUpdateCheckCache() async {
    final encoded = (await SharedPreferences.getInstance()).getString(
      _updateCheckCacheKey,
    );
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final raw = jsonDecode(encoded);
      if (raw is! Map<String, dynamic> ||
          raw['checkedAt'] is! String ||
          raw['results'] is! Map<String, dynamic>) {
        return null;
      }
      final checkedAt = DateTime.tryParse(raw['checkedAt'] as String)?.toUtc();
      if (checkedAt == null) return null;
      final results = <String, UpdateAvailability>{};
      for (final entry in (raw['results'] as Map<String, dynamic>).entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic> || value['state'] is! String) {
          return null;
        }
        final state = UpdateState.values
            .where((candidate) => candidate.name == value['state'])
            .firstOrNull;
        if (state == null || state == UpdateState.checking) return null;
        final removed = value['removedSkills'];
        if (removed is! List) return null;
        results[entry.key] = UpdateAvailability(
          state: state,
          toVersion: value['toVersion'] is String
              ? value['toVersion'] as String
              : '',
          selectedSkillCount: value['selectedSkillCount'] is int
              ? value['selectedSkillCount'] as int
              : 0,
          removedSkills: [
            for (final item in removed)
              if (item is Map<String, dynamic> &&
                  item['name'] is String &&
                  item['path'] is String)
                RemovedSkillImpact(
                  name: item['name'] as String,
                  path: item['path'] as String,
                ),
          ],
        );
      }
      return UpdateCheckCache(checkedAt: checkedAt, results: results);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveUpdateCheckCache(UpdateCheckCache cache) async {
    final encoded = jsonEncode({
      'checkedAt': cache.checkedAt.toUtc().toIso8601String(),
      'results': {
        for (final entry in cache.results.entries)
          entry.key: {
            'state': entry.value.state.name,
            'toVersion': entry.value.toVersion,
            'selectedSkillCount': entry.value.selectedSkillCount,
            'removedSkills': [
              for (final skill in entry.value.removedSkills)
                {'name': skill.name, 'path': skill.path},
            ],
          },
      },
    });
    await (await SharedPreferences.getInstance()).setString(
      _updateCheckCacheKey,
      encoded,
    );
  }

  @override
  Future<String> loadFolderTheme() async {
    return (await SharedPreferences.getInstance()).getString(_folderThemeKey) ??
        '#FFFFFF';
  }

  @override
  Future<void> saveFolderTheme(String theme) async {
    final normalized = theme.toUpperCase();
    final valid = RegExp(r'^#[0-9A-F]{6}$').hasMatch(normalized);
    await (await SharedPreferences.getInstance()).setString(
      _folderThemeKey,
      valid ? normalized : '#FFFFFF',
    );
  }

  @override
  Future<AppWallpaper> loadWallpaper() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_wallpaperKey);
    if (saved == null) {
      final wallpaper = AppWallpaper
          .values[Random.secure().nextInt(AppWallpaper.values.length)];
      await preferences.setString(_wallpaperKey, wallpaper.name);
      return wallpaper;
    }
    return AppWallpaper.values.firstWhere(
      (wallpaper) => wallpaper.name == saved,
      orElse: () => AppWallpaper.sun,
    );
  }

  @override
  Future<void> saveWallpaper(AppWallpaper wallpaper) async {
    await (await SharedPreferences.getInstance()).setString(
      _wallpaperKey,
      wallpaper.name,
    );
  }

  @override
  Future<AppThemeMode> loadThemeMode() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _themeModeKey,
    );
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => AppThemeMode.system,
    );
  }

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    await (await SharedPreferences.getInstance()).setString(
      _themeModeKey,
      mode.name,
    );
  }

  @override
  Future<AppLanguage> loadLanguage() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _languageKey,
    );
    return AppLanguage.values.firstWhere(
      (language) => language.name == saved,
      orElse: () => AppLanguage.system,
    );
  }

  @override
  Future<void> saveLanguage(AppLanguage language) async {
    await (await SharedPreferences.getInstance()).setString(
      _languageKey,
      language.name,
    );
  }

  @override
  Future<ReminderSettings> loadReminderSettings() async {
    final preferences = await SharedPreferences.getInstance();
    return ReminderSettings(
      updateAvailable: preferences.getBool(_updateReminderKey) ?? true,
      securityAdvisory: preferences.getBool(_securityReminderKey) ?? true,
    );
  }

  @override
  Future<void> saveReminderSettings(ReminderSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setBool(_updateReminderKey, settings.updateAvailable),
      preferences.setBool(_securityReminderKey, settings.securityAdvisory),
    ]);
  }

  @override
  Future<OnboardingState> loadOnboardingState() async {
    final preferences = await SharedPreferences.getInstance();
    final completed = preferences.getBool(_onboardingCompletedKey);
    if (completed != null) {
      return OnboardingState(
        completed: completed,
        step: _onboardingStep(preferences.getString(_onboardingStepKey)),
      );
    }
    return const OnboardingState(
      completed: false,
      step: OnboardingStep.welcome,
    );
  }

  OnboardingStep _onboardingStep(String? saved) =>
      OnboardingStep.values.firstWhere(
        (step) => step.name == saved,
        orElse: () => OnboardingStep.welcome,
      );

  @override
  Future<void> saveOnboardingStep(OnboardingStep step) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setBool(_onboardingCompletedKey, false),
      preferences.setString(_onboardingStepKey, step.name),
    ]);
  }

  @override
  Future<void> completeOnboarding() async {
    await (await SharedPreferences.getInstance()).setBool(
      _onboardingCompletedKey,
      true,
    );
  }

  @override
  Future<void> resetOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setBool(_onboardingCompletedKey, false),
      preferences.setString(_onboardingStepKey, OnboardingStep.welcome.name),
    ]);
  }

  @override
  Future<String> _contentLang() async {
    final language = await loadLanguage();
    return language.contentTag(
      ui.PlatformDispatcher.instance.locale.toLanguageTag(),
    );
  }

  Future<String> _canonicalProjectPath(String path) async {
    final normalized = p.normalize(p.absolute(path));
    try {
      return p.normalize(await Directory(normalized).resolveSymbolicLinks());
    } on FileSystemException {
      return normalized;
    }
  }

  Future<List<({String name, String path})>>
  _loadManagedProjectReferences() async {
    final command = await _runCli([
      'project',
      'list',
      '--output',
      'json',
    ], retryOnTransportFailure: true);
    if (!command.succeeded) throw _commandFailure(command);
    final raw = _decodeMachineDocument(
      command.output.stdout,
      phase: 'project-list',
    );
    if (raw['projects'] is! List) throw const FormatException();
    return (raw['projects'] as List)
        .map((entry) {
          if (entry is! Map<String, dynamic> ||
              entry['name'] is! String ||
              entry['root'] is! String) {
            throw const FormatException();
          }
          return (name: entry['name'] as String, path: entry['root'] as String);
        })
        .toList(growable: false);
  }

  Future<AddedProject> _resolveProject(
    ({String name, String path}) reference,
  ) async {
    final path = await _canonicalProjectPath(reference.path);
    final access = await _projectPathInspector(path);
    return AddedProject(
      id: path,
      name: reference.name,
      path: path,
      accessState: access.state,
      diagnostic: access.diagnostic,
      icon: await _projectIconResolver.cached(path),
    );
  }

  @override
  Future<AddedProject> resolveProjectIcon(AddedProject project) async {
    final icon = await _projectIconResolver.resolve(project);
    return project.copyWith(icon: icon, clearIcon: icon == null);
  }

  @override
  Future<List<AddedProject>> loadAddedProjects() async {
    final references = await _loadManagedProjectReferences();
    final projects = <AddedProject>[];
    for (final reference in references) {
      projects.add(await _resolveProject(reference));
    }
    return projects;
  }

  @override
  Future<List<AddedProject>> addProjects() async {
    final selected = await _directoryPathsPicker();
    if (selected.isEmpty) return const [];
    final references = await _loadManagedProjectReferences();
    final referencesByPath = <String, ({String name, String path})>{};
    for (final reference in references) {
      referencesByPath[await _canonicalProjectPath(reference.path)] = reference;
    }

    final selectedReferences = <({String name, String path})>[];
    final selectedPaths = <String>{};
    for (final rawPath in selected) {
      final value = rawPath.trim();
      if (value.isEmpty) continue;
      final path = await _canonicalProjectPath(value);
      if (!selectedPaths.add(path)) continue;

      final entityType = await FileSystemEntity.type(path, followLinks: true);
      if (entityType != FileSystemEntityType.directory &&
          entityType != FileSystemEntityType.notFound) {
        throw const SkillsException(
          'Only directories can be added as projects.',
        );
      }

      final existing = referencesByPath[path];
      if (existing != null) {
        selectedReferences.add(existing);
        continue;
      }

      final command = await _runCli([
        'project',
        'add',
        path,
        '--output',
        'json',
      ]);
      if (!command.succeeded) throw _commandFailure(command);
      final raw = _decodeMachineDocument(
        command.output.stdout,
        phase: 'project-add',
      );
      if (raw['projects'] is! List || (raw['projects'] as List).length != 1) {
        throw const FormatException();
      }
      final added = (raw['projects'] as List).single;
      if (added is! Map<String, dynamic> ||
          added['name'] is! String ||
          added['root'] is! String) {
        throw const FormatException();
      }
      final reference = (
        name: added['name'] as String,
        path: added['root'] as String,
      );
      referencesByPath[path] = reference;
      selectedReferences.add(reference);
    }
    final projects = <AddedProject>[];
    for (final reference in selectedReferences) {
      projects.add(await _resolveProject(reference));
    }
    return projects;
  }

  @override
  Future<void> removeProject(String id) async {
    final command = await _runCli([
      'project',
      'remove',
      id,
      '--output',
      'json',
    ]);
    if (!command.succeeded) throw _commandFailure(command);
  }

  @override
  Future<String> loadHubOrigin() async {
    await _ensureHubOrigin();
    return _hubOrigin;
  }

  @override
  Future<void> saveHubOrigin(String origin) async {
    final parsed = _originUri(origin);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _hubOriginKey,
      parsed.toString().replaceFirst(RegExp(r'/$'), ''),
    );
    _hubBase = parsed;
    _hubOriginLoaded = true;
  }

  @override
  Future<void> resetHubOrigin() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_hubOriginKey);
    _hubBase = _defaultHubBase;
    _hubOriginLoaded = true;
  }

  @override
  Future<String> loadCloudOrigin() async {
    await _ensureCloudOrigin();
    return _cloudOrigin;
  }

  @override
  Future<void> saveCloudOrigin(String origin) async {
    final parsed = _originUri(origin);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _cloudOriginKey,
      parsed.toString().replaceFirst(RegExp(r'/$'), ''),
    );
    _cloudBase = parsed;
    _cloudOriginLoaded = true;
  }

  @override
  Future<void> resetCloudOrigin() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_cloudOriginKey);
    _cloudBase = _defaultCloudBase;
    _cloudOriginLoaded = true;
  }

  @override
  Future<HubStatus> testHubOrigin(String origin) async {
    final Uri base;
    try {
      base = _originUri(origin);
    } on FormatException catch (error) {
      return HubStatus(
        origin: origin.trim(),
        state: HealthState.invalid,
        issue: HubIssue.invalidOrigin,
        diagnostic: error.message,
      );
    }
    final normalized = base.toString().replaceFirst(RegExp(r'/$'), '');
    try {
      final result = await _runCli([
        'hub',
        'check',
        '--hub',
        normalized,
        '--output',
        'json',
      ]);
      if (!result.succeeded) throw _commandFailure(result);
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> || decoded['skills'] is! List) {
        return HubStatus(
          origin: normalized,
          state: HealthState.invalid,
          issue: HubIssue.invalidProtocol,
        );
      }
      return HubStatus(origin: normalized, state: HealthState.ready);
    } on FormatException {
      return HubStatus(
        origin: normalized,
        state: HealthState.invalid,
        issue: HubIssue.invalidJson,
      );
    } on Object catch (error) {
      return HubStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: HubIssue.connectionFailure,
        diagnostic: error.toString(),
      );
    }
  }

  @override
  Future<HubStatus> testCloudOrigin(String origin) async {
    final Uri base;
    try {
      base = _originUri(origin);
    } on FormatException catch (error) {
      return HubStatus(
        origin: origin.trim(),
        state: HealthState.invalid,
        issue: HubIssue.invalidOrigin,
        diagnostic: error.message,
      );
    }
    final normalized = base.toString().replaceFirst(RegExp(r'/$'), '');
    final uri = base
        .resolve('api/v1/rankings/all_time')
        .replace(
          queryParameters: const {'page': '0', 'perPage': '1', 'lang': 'en'},
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
        return HubStatus(
          origin: normalized,
          state: HealthState.unreachable,
          issue: HubIssue.httpFailure,
          httpStatus: response.statusCode,
        );
      }
      final decoded = jsonDecode(body);
      if (!_isCloudRankingDocument(decoded)) {
        return HubStatus(
          origin: normalized,
          state: HealthState.invalid,
          issue: HubIssue.invalidProtocol,
        );
      }
      return HubStatus(origin: normalized, state: HealthState.ready);
    } on TimeoutException catch (error) {
      return HubStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: HubIssue.timeout,
        diagnostic: error.toString(),
      );
    } on FormatException catch (error) {
      return HubStatus(
        origin: normalized,
        state: HealthState.invalid,
        issue: HubIssue.invalidJson,
        diagnostic: error.message,
      );
    } on Object catch (error) {
      return HubStatus(
        origin: normalized,
        state: HealthState.unreachable,
        issue: HubIssue.connectionFailure,
        diagnostic: error.toString(),
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<PersonalRiskPolicy> loadRiskPolicy() async {
    final preferences = await SharedPreferences.getInstance();
    return PersonalRiskPolicy(
      allowCriticalOverride:
          preferences.getBool(_allowCriticalOverrideKey) ?? false,
    );
  }

  @override
  Future<void> saveRiskPolicy(PersonalRiskPolicy policy) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      _allowCriticalOverrideKey,
      policy.allowCriticalOverride,
    );
  }

  @override
  Future<String> loadAppVersion() async =>
      _injectedAppVersion ?? (await PackageInfo.fromPlatform()).version;
}
