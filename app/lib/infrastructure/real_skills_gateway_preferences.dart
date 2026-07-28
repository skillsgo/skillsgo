/*
 * [INPUT]: Depends on the shared gateway state, SharedPreferences, CLI Managed Scope commands, directory pickers, project inspection, App locale, and Hub health CLI command.
 * [OUTPUT]: Provides appearance, language, reminder, onboarding, CLI-owned Added Project access, Hub origin and runtime discovery, risk policy, and App-version persistence operations.
 * [POS]: Serves as the local preference and CLI-backed project-reference capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayPreferences on _RealSkillsGatewayCore {
  @override
  Future<HubRuntime> loadHubRuntime() async {
    await _ensureHubOrigin();
    final cached = _hubRuntime;
    if (cached != null) return cached;
    final result = await _runCli([
      'hub',
      'info',
      '--hub',
      _hubOrigin,
      '--output',
      'json',
    ]);
    if (!result.succeeded) throw _commandFailure(result);
    try {
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> || decoded['mode'] is! String) {
        throw const FormatException('Invalid Hub info response.');
      }
      final mode = switch (decoded['mode']) {
        'selfhost' => HubMode.selfhost,
        'cloud' => HubMode.cloud,
        _ => throw const FormatException('Invalid Hub mode.'),
      };
      Uri? cloudOrigin;
      if (mode == HubMode.cloud) {
        final rawCloud = decoded['cloud'];
        if (rawCloud is! String) {
          throw const FormatException('Cloud origin is missing.');
        }
        cloudOrigin = _originUri(rawCloud);
      } else if (decoded.containsKey('cloud')) {
        throw const FormatException('Selfhost Hub must not declare Cloud.');
      }
      return _hubRuntime = HubRuntime(mode: mode, cloudOrigin: cloudOrigin);
    } on FormatException catch (error) {
      throw SkillsException(
        error.message,
        kind: SkillsFailureKind.invalidResponse,
      );
    }
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
    final saved = (await SharedPreferences.getInstance()).getString(
      _wallpaperKey,
    );
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

  Future<List<({String id, String name, String path})>>
  _loadManagedProjectReferences() async {
    final command = await _runCli(['project', 'list', '--output', 'json']);
    if (!command.succeeded) throw _commandFailure(command);
    final raw = _decodeMachineDocument(
      command.output.stdout,
      phase: 'project-list',
    );
    if (raw['projects'] is! List) throw const FormatException();
    return (raw['projects'] as List)
        .map((entry) {
          if (entry is! Map<String, dynamic> ||
              entry['id'] is! String ||
              entry['name'] is! String ||
              entry['root'] is! String) {
            throw const FormatException();
          }
          return (
            id: entry['id'] as String,
            name: entry['name'] as String,
            path: entry['root'] as String,
          );
        })
        .toList(growable: false);
  }

  Future<AddedProject> _resolveProject(
    ({String id, String name, String path}) reference,
  ) async {
    final path = await _canonicalProjectPath(reference.path);
    final access = await _projectPathInspector(path);
    return AddedProject(
      id: reference.id,
      name: reference.name,
      path: path,
      accessState: access.state,
      diagnostic: access.diagnostic,
      icon: await _projectIconResolver.cached(reference.id),
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
    final referencesByPath =
        <String, ({String id, String name, String path})>{};
    for (final reference in references) {
      referencesByPath[await _canonicalProjectPath(reference.path)] = reference;
    }

    final selectedReferences = <({String id, String name, String path})>[];
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
          added['id'] is! String ||
          added['name'] is! String ||
          added['root'] is! String) {
        throw const FormatException();
      }
      final reference = (
        id: added['id'] as String,
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
  Future<AddedProject?> relocateProject(String id) async {
    final references = await _loadManagedProjectReferences();
    final index = references.indexWhere((project) => project.id == id);
    if (index < 0) return null;
    final selected = await _directoryPicker(
      initialDirectory: references[index].path,
    );
    if (selected == null || selected.trim().isEmpty) {
      return _resolveProject(references[index]);
    }
    final path = await _canonicalProjectPath(selected.trim());
    for (final project in references) {
      if (project.id != id &&
          p.equals(await _canonicalProjectPath(project.path), path)) {
        throw const SkillsException('That project is already added.');
      }
    }
    final command = await _runCli([
      'project',
      'move',
      id,
      path,
      '--output',
      'json',
    ]);
    if (!command.succeeded) throw _commandFailure(command);
    final raw = _decodeMachineDocument(
      command.output.stdout,
      phase: 'project-move',
    );
    if (raw['projects'] is! List || (raw['projects'] as List).length != 1) {
      throw const FormatException();
    }
    final moved = (raw['projects'] as List).single;
    if (moved is! Map<String, dynamic> ||
        moved['id'] is! String ||
        moved['name'] is! String ||
        moved['root'] is! String) {
      throw const FormatException();
    }
    return _resolveProject((
      id: moved['id'] as String,
      name: moved['name'] as String,
      path: moved['root'] as String,
    ));
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
    _hubRuntime = null;
  }

  @override
  Future<void> resetHubOrigin() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_hubOriginKey);
    _hubBase = _defaultHubBase;
    _hubOriginLoaded = true;
    _hubRuntime = null;
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
