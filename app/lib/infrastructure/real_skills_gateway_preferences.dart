/*
 * [INPUT]: Depends on the shared gateway state, SharedPreferences, directory pickers, project inspection, App locale, and Hub health CLI command.
 * [OUTPUT]: Provides appearance, language, reminder, onboarding, Added Project, Hub origin, risk policy, storage, and App-version persistence operations.
 * [POS]: Serves as the local preference and project-reference capability inside the RealSkillsGateway adapter.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of 'real_skills_gateway.dart';

mixin _RealSkillsGatewayPreferences on _RealSkillsGatewayCore {
  @override
  Future<String> loadFolderTheme() async {
    final saved =
        (await SharedPreferences.getInstance()).getString(_folderThemeKey) ??
        '#FFFFFF';
    return const {
          'manila': '#514532',
          'blue': '#294556',
          'sage': '#3D5141',
          'charcoal': '#292A2B',
        }[saved] ??
        saved;
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
    const legacyKeys = {
      _customCliKey,
      _hubOriginKey,
      _folderThemeKey,
      _wallpaperKey,
      _themeModeKey,
      _languageKey,
      _updateReminderKey,
      _securityReminderKey,
      _allowCriticalOverrideKey,
      _addedProjectsKey,
    };
    if (preferences.getKeys().any(legacyKeys.contains)) {
      await preferences.setBool(_onboardingCompletedKey, true);
      return const OnboardingState(
        completed: true,
        step: OnboardingStep.projects,
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
  Future<String> _contentLocale() async {
    final language = await loadLanguage();
    return language.contentTag(
      ui.PlatformDispatcher.instance.locale.languageCode,
    );
  }

  String _newProjectID() {
    final bytes = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
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
  _loadProjectReferences() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _addedProjectsKey,
    );
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException();
      final ids = <String>{};
      final paths = <String>{};
      return decoded
          .map((entry) {
            if (entry is! Map<String, dynamic> ||
                entry['id'] is! String ||
                (entry['id'] as String).isEmpty ||
                entry['name'] is! String ||
                (entry['name'] as String).isEmpty ||
                entry['path'] is! String ||
                (entry['path'] as String).isEmpty ||
                !ids.add(entry['id'] as String) ||
                !paths.add(entry['path'] as String)) {
              throw const FormatException();
            }
            return (
              id: entry['id'] as String,
              name: entry['name'] as String,
              path: entry['path'] as String,
            );
          })
          .toList(growable: false);
    } on FormatException {
      throw const SkillsException(
        'Saved project references are invalid.',
        kind: SkillsFailureKind.invalidResponse,
      );
    }
  }

  Future<void> _saveProjectReferences(
    List<({String id, String name, String path})> projects,
  ) async {
    final encoded = jsonEncode([
      for (final project in projects)
        {'id': project.id, 'name': project.name, 'path': project.path},
    ]);
    await (await SharedPreferences.getInstance()).setString(
      _addedProjectsKey,
      encoded,
    );
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
    final references = await _loadProjectReferences();
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
    final references = await _loadProjectReferences();
    final referencesByPath =
        <String, ({String id, String name, String path})>{};
    for (final reference in references) {
      referencesByPath[await _canonicalProjectPath(reference.path)] = reference;
    }

    final selectedReferences = <({String id, String name, String path})>[];
    final selectedPaths = <String>{};
    final addedReferences = <({String id, String name, String path})>[];
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

      final basename = p.basename(path);
      final reference = (
        id: _newProjectID(),
        name: basename.isEmpty ? path : basename,
        path: path,
      );
      referencesByPath[path] = reference;
      selectedReferences.add(reference);
      addedReferences.add(reference);
    }

    if (addedReferences.isNotEmpty) {
      await _saveProjectReferences([...references, ...addedReferences]);
    }
    final projects = <AddedProject>[];
    for (final reference in selectedReferences) {
      projects.add(await _resolveProject(reference));
    }
    return projects;
  }

  @override
  Future<AddedProject?> relocateProject(String id) async {
    final references = await _loadProjectReferences();
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
    final relocated = (
      id: references[index].id,
      name: references[index].name,
      path: path,
    );
    final updated = [...references]..[index] = relocated;
    await _saveProjectReferences(updated);
    return _resolveProject(relocated);
  }

  @override
  Future<void> removeProject(String id) async {
    final references = await _loadProjectReferences();
    await _saveProjectReferences(
      references.where((project) => project.id != id).toList(growable: false),
    );
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
      final result = await _runCli(['hub', 'check', '--hub', normalized]);
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
  Future<StorageStatus> inspectStorage() async {
    try {
      final result = await _runCli(const ['diagnostics', '--output', 'json']);
      if (!result.succeeded) {
        return const StorageStatus(path: '', state: HealthState.unreachable);
      }
      final decoded = jsonDecode(result.output.stdout);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != 1 ||
          decoded['store'] is! Map<String, dynamic>) {
        return const StorageStatus(path: '', state: HealthState.invalid);
      }
      final store = decoded['store'] as Map<String, dynamic>;
      if (store['path'] is! String || store['state'] is! String) {
        return const StorageStatus(path: '', state: HealthState.invalid);
      }
      final state = switch (store['state']) {
        'ready' => HealthState.ready,
        'not_initialized' => HealthState.notInitialized,
        'unreadable' => HealthState.unreachable,
        _ => HealthState.invalid,
      };
      return StorageStatus(path: store['path'] as String, state: state);
    } on Object {
      return const StorageStatus(path: '', state: HealthState.unreachable);
    }
  }

  @override
  Future<String> loadAppVersion() async =>
      _injectedAppVersion ?? (await PackageInfo.fromPlatform()).version;
}
