/*
 * [INPUT]: Uses domain gateway models and shared async controls from the FakeSkillsGateway library.
 * [OUTPUT]: Provides shared scenario state, captured discovery, Package update-check, and Adoption queries, candidates, installation history, preferences, controllable onboarding, exact-path local-scan acceptance/deferral and privacy-settings recovery state, analytics event controls, project and usage-load counters, and fixtures for capability mixins.
 * [POS]: Serves as the state-bearing core of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

const defaultSearchResults = [
  SkillSummary(
    packagePath: 'example/skills',
    installName: 'flutter-pro',
    name: 'Flutter Pro',
    installs: 1200,
    description: 'Build Flutter products with reliable engineering flows.',
  ),
];

final defaultRemoteDetail = SkillDetail(
  name: 'Flutter Pro',
  path: 'skills/flutter-pro',
  packagePath: 'example/skills',
  version: 'v1.2.3',
  time: DateTime.utc(2026, 7, 15),
  packageSize: 24576,
  description: 'Build reliable Flutter products.',
  sourceLanguage: 'en',
  translated: true,
  content: '# Real instructions',
  installationTargets: [
    SkillInstallationTarget(
      agent: 'codex',
      scope: InstallationScope.global,
      path: '/tmp/flutter-pro',
      version: 'v1.2.3',
    ),
  ],
);

abstract class FakeSkillsGatewayCore
    implements
        SkillsGateway,
        AnalyticsProgressSource,
        AnalyticsInvalidationSource {
  final _analyticsProgress =
      StreamController<AnalyticsSyncProgress>.broadcast();
  final _analyticsInvalidations = StreamController<int>.broadcast();

  @override
  Stream<AnalyticsSyncProgress> watchAnalyticsProgress() =>
      _analyticsProgress.stream;

  @override
  Stream<int> watchAnalyticsInvalidations() => _analyticsInvalidations.stream;

  void emitAnalyticsProgress(AnalyticsSyncProgress progress) =>
      _analyticsProgress.add(progress);

  void emitAnalyticsInvalidation(int revision) =>
      _analyticsInvalidations.add(revision);

  FakeSkillsGatewayCore({
    this.onboardingState = const OnboardingState(
      completed: true,
      step: OnboardingStep.projects,
    ),
    List<Object> onboardingLoadErrors = const [],
    this.onboardingLoadCompleter,
    this.onboardingStepSaveCompleter,
    bool localScanNoticeAcknowledged = true,
    bool localScanNoticeDeferred = false,
    LocalScanNoticeDecision? localScanNoticeDecision,
    List<String> localScanNoticePaths = const ['/Users/test/Documents/project'],
    this.localScanNoticePathsCompleter,
    List<Object> localScanNoticeRequirementErrors = const [],
    List<Object> localScanNoticeAcknowledgeErrors = const [],
    this.localScanNoticeAcknowledgeCompleter,
    this.localScanPrivacySettingsResult = true,
    this.localScanPrivacySettingsError,
    this.cliReady = true,
    this.installed = true,
    this.searchCompleter,
    this.installCompleter,
    this.libraryCompleter,
    List<SkillSummary>? searchResults,
    List<AdoptionCandidate>? sourceCandidates,
    this.agentNames = const ['codex'],
    this.agentStatuses,
    this.agentInspectionCompleter,
    this.agentInspectionError,
    this.libraryError,
    List<AddedProject> addedProjects = const [],
    List<AdoptionBackup> adoptionBackups = const [],
    this.projectLoadCompleter,
    AddedProject? projectToAdd,
    List<AddedProject>? projectsToAdd,
    List<InstalledSkill>? libraryEntries,
    this.localDetailError,
    this.localDetail,
    this.hubOrigin = 'https://hub.skillsgo.ai',
    this.folderTheme = '#514532',
    this.themeMode = AppThemeMode.system,
    this.language = AppLanguage.english,
    this.wallpaper = AppWallpaper.sun,
    this.hubTestState = HealthState.ready,
    this.appVersion = '1.0.0',
    this.discoveryPages = const {},
    List<Completer<DiscoveryPage>> discoveryCompleters = const [],
    this.discoveryError,
    this.discoveryErrors = const {},
    this.detailCompleter,
    SkillDetail? remoteDetail,
    PackageDetail? packageDetail,
    this.packageDetailRefreshCompleter,
    this.packageReadme = '# Package README',
    this.packageReadmeError,
    List<SkillsException> detailErrors = const [],
    this.planConflictReason = '',
    this.riskPolicy = const PersonalRiskPolicy(),
    this.installFailures = const [],
    List<SkillsException> installPlanErrors = const [],
    this.updateError,
    List<SkillsException> updateCheckErrors = const [],
    this.updateCheckCompleter,
    this.updateState = UpdateState.available,
    this.packageUpdateResult = const PackageUpdateCheckResult(
      packagePath: 'example/skills',
      status: PackageUpdateCheckStatus.upToDate,
      version: 'v1.2.3',
    ),
    this.packageUpdateCompleter,
    this.updateCheckCache,
    this.reminderSettings = const ReminderSettings(
      updateAvailable: false,
      securityAdvisory: false,
    ),
  }) : localScanNoticeDecision =
           localScanNoticeDecision ??
           (localScanNoticeAcknowledged
               ? LocalScanNoticeDecision.accepted
               : localScanNoticeDeferred
               ? LocalScanNoticeDecision.deferred
               : LocalScanNoticeDecision.unseen),
       searchResults = searchResults ?? defaultSearchResults,
       sourceCandidates =
           sourceCandidates ??
           (searchResults ?? defaultSearchResults)
               .map(
                 (skill) => AdoptionCandidate(
                   packagePath: skill.packagePath,
                   name: skill.name,
                   path: skill.path,
                   description: skill.description,
                   versions: [skill.latestVersion],
                   imageUrl: skill.imageUrl,
                 ),
               )
               .toList(growable: false),
       remoteDetail =
           remoteDetail ??
           (installed
               ? defaultRemoteDetail
               : withoutInstallationTargets(defaultRemoteDetail)),
       packageDetail =
           packageDetail ??
           PackageDetail(
             packagePath: 'example/skills',
             version: 'v1.2.3',
             time: DateTime.utc(2026, 7, 15),
             readmeUrl: Uri.parse(
               'https://cdn.jsdelivr.net/gh/example/skills@abcdef/README.md',
             ),
             skills: searchResults ?? defaultSearchResults,
             summary: const PackageSummary(
               id: 'example/skills',
               description:
                   'A focused collection of Flutter engineering skills.',
               stars: 12800,
               latestVersion: 'v1.2.3',
             ),
           ),
       detailErrors = List.of(detailErrors),
       installPlanErrors = List.of(installPlanErrors),
       updateCheckErrors = List.of(updateCheckErrors),
       discoveryCompleters = List.of(discoveryCompleters),
       libraryEntries = libraryEntries == null ? null : List.of(libraryEntries),
       onboardingLoadErrors = List.of(onboardingLoadErrors),
       localScanNoticeAcknowledgeErrors = List.of(
         localScanNoticeAcknowledgeErrors,
       ),
       localScanNoticePaths = List.of(localScanNoticePaths),
       localScanNoticeRequirementErrors = List.of(
         localScanNoticeRequirementErrors,
       ),
       projectsToAdd = List.of(
         projectsToAdd ??
             (projectToAdd == null ? const [] : <AddedProject>[projectToAdd]),
       ),
       projects = List.of(addedProjects),
       adoptionBackups = List.of(adoptionBackups);
  OnboardingState onboardingState;
  final List<Object> onboardingLoadErrors;
  final Completer<OnboardingState>? onboardingLoadCompleter;
  final Completer<void>? onboardingStepSaveCompleter;
  int onboardingCompletions = 0;
  int onboardingResets = 0;
  LocalScanNoticeDecision localScanNoticeDecision;
  bool get localScanNoticeAcknowledged =>
      localScanNoticeDecision == LocalScanNoticeDecision.accepted;
  bool get localScanNoticeDeferred =>
      localScanNoticeDecision == LocalScanNoticeDecision.deferred;
  int localScanPrivacySettingsOpens = 0;
  final bool localScanPrivacySettingsResult;
  final Object? localScanPrivacySettingsError;
  final List<String> localScanNoticePaths;
  final Completer<List<String>>? localScanNoticePathsCompleter;
  final List<Object> localScanNoticeRequirementErrors;
  final List<Object> localScanNoticeAcknowledgeErrors;
  final Completer<void>? localScanNoticeAcknowledgeCompleter;
  final bool cliReady;
  final Completer<List<SkillSummary>>? searchCompleter;
  final Completer<CommandResult>? installCompleter;
  Completer<List<InstalledSkill>>? libraryCompleter;
  final Completer<SkillDetail>? detailCompleter;
  final List<String> agentNames;
  final List<AgentStatus>? agentStatuses;
  final Completer<AgentCatalog>? agentInspectionCompleter;
  final SkillsException? agentInspectionError;
  final SkillsException? libraryError;
  final List<AddedProject> projectsToAdd;
  final Completer<List<AddedProject>>? projectLoadCompleter;
  List<InstalledSkill>? libraryEntries;
  final SkillsException? localDetailError;
  final SkillDetail? localDetail;
  final List<AddedProject> projects;
  List<AdoptionBackup> adoptionBackups;
  int projectLoads = 0;
  int usageLoads = 0;
  String hubOrigin;
  String folderTheme;
  AppThemeMode themeMode;
  AppLanguage language;
  AppWallpaper wallpaper;
  final HealthState hubTestState;
  PersonalRiskPolicy riskPolicy;
  final String planConflictReason;
  final String appVersion;
  final Map<String, DiscoveryPage> discoveryPages;
  final List<Completer<DiscoveryPage>> discoveryCompleters;
  final SkillsException? discoveryError;
  final Map<String, SkillsException> discoveryErrors;
  final SkillDetail remoteDetail;
  final PackageDetail packageDetail;
  final Completer<PackageDetail>? packageDetailRefreshCompleter;
  int packageDetailLoads = 0;
  final String packageReadme;
  final SkillsException? packageReadmeError;
  final packageReadmeRequests = <Uri>[];
  final List<SkillsException> detailErrors;
  final List<Set<String>> installFailures;
  final List<SkillsException> installPlanErrors;
  final SkillsException? updateError;
  final List<SkillsException> updateCheckErrors;
  final UpdateState updateState;
  final PackageUpdateCheckResult packageUpdateResult;
  final Completer<PackageUpdateCheckResult>? packageUpdateCompleter;
  final packageUpdateChecks = <String>[];
  UpdateCheckCache? updateCheckCache;
  int updateChecks = 0;
  final Completer<Map<String, UpdateAvailability>>? updateCheckCompleter;
  ReminderSettings reminderSettings;
  DiagnosticLogInfo diagnosticLogInfo = const DiagnosticLogInfo(
    directory: '/tmp/SkillsGo Logs',
    totalBytes: 0,
  );
  int diagnosticLogOpenCalls = 0;
  int diagnosticLogExportCalls = 0;
  int diagnosticLogClearCalls = 0;
  final diagnosticLogEntries = <DiagnosticLogEntry>[];
  final diagnosticLogEvents = StreamController<DiagnosticLogEntry>.broadcast();
  bool installed;
  final queries = <String>[];
  final sourceQueries = <PackageFindQuery>[];
  final collections = <DiscoveryCollection>[];
  final requestedPages = <int>[];
  int installCalls = 0;
  int repositoryInstallCalls = 0;

  @override
  Future<DiagnosticLogInfo> loadDiagnosticLogInfo() async => diagnosticLogInfo;

  @override
  Future<void> openDiagnosticLogDirectory() async {
    diagnosticLogOpenCalls++;
  }

  @override
  Future<bool> exportDiagnosticLogs() async {
    diagnosticLogExportCalls++;
    return true;
  }

  @override
  Future<void> clearDiagnosticLogs() async {
    diagnosticLogClearCalls++;
    diagnosticLogInfo = DiagnosticLogInfo(
      directory: diagnosticLogInfo.directory,
      totalBytes: 0,
    );
  }

  @override
  List<DiagnosticLogEntry> recentDiagnosticLogs({int limit = 200}) {
    final start = max(0, diagnosticLogEntries.length - limit);
    return List.unmodifiable(diagnosticLogEntries.sublist(start));
  }

  @override
  Stream<DiagnosticLogEntry> watchDiagnosticLogs() =>
      diagnosticLogEvents.stream;

  void emitDiagnosticLog(DiagnosticLogEntry entry) {
    diagnosticLogEntries.add(entry);
    diagnosticLogEvents.add(entry);
  }

  @override
  Future<OnboardingState> loadOnboardingState() async {
    final pending = onboardingLoadCompleter;
    if (pending != null) return pending.future;
    if (onboardingLoadErrors.isNotEmpty) {
      throw onboardingLoadErrors.removeAt(0);
    }
    return onboardingState;
  }

  @override
  Future<void> saveOnboardingStep(OnboardingStep step) async {
    await onboardingStepSaveCompleter?.future;
    onboardingState = OnboardingState(completed: false, step: step);
  }

  @override
  Future<void> completeOnboarding() async {
    onboardingCompletions++;
    onboardingState = OnboardingState(
      completed: true,
      step: onboardingState.step,
    );
  }

  @override
  Future<void> resetOnboarding() async {
    onboardingResets++;
    onboardingState = const OnboardingState(
      completed: false,
      step: OnboardingStep.welcome,
    );
  }

  int updateCalls = 0;
  List<InstallationTargetSelection> lastPlanSelections = const [];
  final executionSelectionHistory = <List<InstallationTargetSelection>>[];
  final installationSkillHistory = <SkillSummary>[];
  final installationVersionHistory = <String>[];
  final adoptionRequests = <List<AdoptionRequestItem>>[];
  final updatePackageHistory = <({String packagePath, String version})>[];
  final managementTargetHistory = <Map<String, TargetManagementAction>>[];
  int detailLoads = 0;
  int agentInspections = 0;
  String? savedPath;
  final List<SkillSummary> searchResults;
  final List<AdoptionCandidate> sourceCandidates;
}
