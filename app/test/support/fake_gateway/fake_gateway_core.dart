/*
 * [INPUT]: Uses domain gateway models and shared async controls from the FakeSkillsGateway library.
 * [OUTPUT]: Provides shared scenario state, discovery and Adoption candidates, installation history, preferences, onboarding, project behavior, and controllable fixtures for capability mixins.
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
  archiveSize: 24576,
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

abstract class FakeSkillsGatewayCore implements SkillsGateway {
  FakeSkillsGatewayCore({
    this.onboardingState = const OnboardingState(
      completed: true,
      step: OnboardingStep.projects,
    ),
    List<Object> onboardingLoadErrors = const [],
    this.onboardingStepSaveCompleter,
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
    this.projectLoadCompleter,
    AddedProject? projectToAdd,
    List<AddedProject>? projectsToAdd,
    this.projectToRelocate,
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
    List<SkillsException> detailErrors = const [],
    this.planConflictReason = '',
    this.riskPolicy = const PersonalRiskPolicy(),
    this.installFailures = const [],
    List<SkillsException> installPlanErrors = const [],
    this.updateError,
    List<SkillsException> updateCheckErrors = const [],
    this.updateState = UpdateState.available,
    this.reminderSettings = const ReminderSettings(
      updateAvailable: false,
      securityAdvisory: false,
    ),
  }) : searchResults = searchResults ?? defaultSearchResults,
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
       detailErrors = List.of(detailErrors),
       installPlanErrors = List.of(installPlanErrors),
       updateCheckErrors = List.of(updateCheckErrors),
       discoveryCompleters = List.of(discoveryCompleters),
       libraryEntries = libraryEntries == null ? null : List.of(libraryEntries),
       onboardingLoadErrors = List.of(onboardingLoadErrors),
       projectsToAdd = List.of(
         projectsToAdd ??
             (projectToAdd == null ? const [] : <AddedProject>[projectToAdd]),
       ),
       projects = List.of(addedProjects);
  OnboardingState onboardingState;
  final List<Object> onboardingLoadErrors;
  final Completer<void>? onboardingStepSaveCompleter;
  int onboardingCompletions = 0;
  int onboardingResets = 0;
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
  final AddedProject? projectToRelocate;
  final Completer<List<AddedProject>>? projectLoadCompleter;
  List<InstalledSkill>? libraryEntries;
  final SkillsException? localDetailError;
  final SkillDetail? localDetail;
  final List<AddedProject> projects;
  int projectLoads = 0;
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
  final List<SkillsException> detailErrors;
  final List<Set<String>> installFailures;
  final List<SkillsException> installPlanErrors;
  final SkillsException? updateError;
  final List<SkillsException> updateCheckErrors;
  final UpdateState updateState;
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
