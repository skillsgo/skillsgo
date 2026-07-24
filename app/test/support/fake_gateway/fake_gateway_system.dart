/*
 * [INPUT]: Uses shared controls and state from FakeSkillsGatewayCore plus domain gateway models.
 * [OUTPUT]: Provides CLI detection, single/batch Find discovery, remote detail, and system status behavior.
 * [POS]: Serves as one capability facet of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

mixin FakeGatewaySystem on FakeSkillsGatewayCore {
  @override
  Future<CliStatus> detectCli({String? customPath}) async => cliReady
      ? CliStatus(
          availability: CliAvailability.ready,
          path: customPath?.isNotEmpty == true
              ? customPath
              : '/usr/local/bin/skills',
          version: '1.5.17',
        )
      : const CliStatus(
          availability: CliAvailability.missing,
          message: 'raw process diagnostic',
          issue: CliIssue.missing,
        );

  @override
  Future<String?> loadCustomCliPath() async => savedPath;
  @override
  Future<void> saveCustomCliPath(String? path) async => savedPath = path;
  @override
  Future<String> loadFolderTheme() async => folderTheme;
  @override
  Future<void> saveFolderTheme(String theme) async => folderTheme = theme;

  @override
  Future<AppWallpaper> loadWallpaper() async => wallpaper;

  @override
  Future<void> saveWallpaper(AppWallpaper value) async => wallpaper = value;

  @override
  Future<AppThemeMode> loadThemeMode() async => themeMode;

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async => themeMode = mode;

  @override
  Future<AppLanguage> loadLanguage() async => language;

  @override
  Future<void> saveLanguage(AppLanguage value) async => language = value;

  @override
  Future<ReminderSettings> loadReminderSettings() async => reminderSettings;

  @override
  Future<void> saveReminderSettings(ReminderSettings value) async {
    reminderSettings = value;
  }

  @override
  Future<String> loadHubOrigin() async => hubOrigin;
  @override
  Future<void> saveHubOrigin(String origin) async {
    hubOrigin = origin;
  }

  @override
  Future<void> resetHubOrigin() async {
    hubOrigin = 'https://hub.skillsgo.ai';
  }

  @override
  Future<HubStatus> testHubOrigin(String origin) async => HubStatus(
    origin: origin,
    state: hubTestState,
    issue: hubTestState == HealthState.ready ? null : HubIssue.invalidProtocol,
  );

  @override
  Future<HubRuntime> loadHubRuntime() async =>
      const HubRuntime(mode: HubMode.selfhost);

  @override
  Future<PersonalRiskPolicy> loadRiskPolicy() async => riskPolicy;
  @override
  Future<void> saveRiskPolicy(PersonalRiskPolicy policy) async {
    riskPolicy = policy;
  }

  @override
  Future<String> loadAppVersion() async => appVersion;
  @override
  Future<DiscoveryPage> discover(
    DiscoveryCollection collection, {
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    collections.add(collection);
    requestedOffsets.add(offset);
    if (discoveryCompleters.isNotEmpty) {
      return discoveryCompleters.removeAt(0).future;
    }
    if (discoveryError != null) throw discoveryError!;
    final configuredError = discoveryErrors['${collection.name}:$offset'];
    if (configuredError != null) throw configuredError;
    final configured = discoveryPages['${collection.name}:$offset'];
    if (configured != null) return configured;
    if (collection == DiscoveryCollection.search) queries.add(query);
    final skills = collection == DiscoveryCollection.search
        ? await (searchCompleter?.future ?? Future.value(searchResults))
        : searchResults;
    return DiscoveryPage(skills: skills);
  }

  @override
  Future<List<SourceFindResult>> findSources(
    List<SourceFindQuery> requests, {
    int limit = 10,
  }) async {
    queries.addAll(requests.map((request) => request.name));
    if (discoveryError != null) throw discoveryError!;
    return requests
        .map(
          (request) => SourceFindResult(
            id: request.id,
            skills: searchResults
                .where(
                  (skill) =>
                      request.source.isEmpty ||
                      skill.repositoryId == request.source,
                )
                .take(limit)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill) async {
    detailLoads++;
    if (detailErrors.isNotEmpty) throw detailErrors.removeAt(0);
    return detailCompleter?.future ?? remoteDetail;
  }
}
