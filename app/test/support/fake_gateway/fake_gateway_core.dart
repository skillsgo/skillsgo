/*
 * [INPUT]: Uses domain gateway models and shared async controls from the FakeSkillsGateway library.
 * [OUTPUT]: Provides shared scenario state, preferences, onboarding, project behavior, and controllable Batch Takeover plans/results for capability mixins.
 * [POS]: Serves as the state-bearing core of the composable SkillsGateway test double.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
part of '../fake_skills_gateway.dart';

const defaultSearchResults = [
  SkillSummary(
    id: 'example/skills/flutter-pro',
    installName: 'flutter-pro',
    name: 'Flutter Pro',
    source: 'example/skills',
    installs: 1200,
    description: 'Build Flutter products with reliable engineering flows.',
  ),
];

final defaultRemoteDetail = SkillDetail(
  name: 'Flutter Pro',
  source: 'example/skills',
  repository: 'github.com/example/skills',
  stars: 12800,
  sourceUpdatedAt: DateTime.utc(2026, 7, 15),
  archiveSize: 24576,
  description: 'Build reliable Flutter products.',
  markdown: '# Real instructions',
  requestedVersion: 'main',
  immutableVersion: 'v1.2.3',
  commitSHA: 'commit-abc',
  treeSHA: 'tree-def',
  sum: 'h1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  trustLevel: SkillTrustLevel.publisherVerified,
  riskAssessment: SkillRiskAssessment.medium,
  riskScannerVersion: 'file-signals/v1',
  riskEvidence: [
    SkillRiskEvidence(code: 'script_file', path: 'scripts/run.sh'),
  ],
  hubExecutableSignal: true,
  files: [
    SkillFile(
      path: 'SKILL.md',
      contents: '# Real instructions',
      kind: 'instructions',
    ),
    SkillFile(path: 'references/guide.md', contents: '# Supporting guide'),
    SkillFile(
      path: 'scripts/run.sh',
      contents: 'echo test',
      kind: 'script',
      executable: true,
    ),
  ],
  installationTargets: [
    SkillInstallationTarget(
      agent: 'codex',
      scope: InstallationScope.user,
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
    this.folderTheme = 'manila',
    this.themeMode = AppThemeMode.system,
    this.language = AppLanguage.english,
    this.wallpaper = AppWallpaper.sun,
    this.hubTestState = HealthState.ready,
    this.storageStatus = const StorageStatus(
      path: '/Users/test/.skillsgo/store',
      state: HealthState.ready,
    ),
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
    this.updateFailures = const [],
    List<SkillsException> updateCheckErrors = const [],
    this.updateState = UpdateState.available,
    this.takeoverResult = const BatchTakeoverResult(takenOver: 0, skipped: 0),
    this.takeoverPlan = const BatchTakeoverPlan(
      id: 'fake-takeover-plan',
      allEligibleCount: 1,
      userEligibleCount: 1,
    ),
    this.takeoverPlanCompleter,
    this.takeoverCompleter,
    this.reminderSettings = const ReminderSettings(
      updateAvailable: false,
      securityAdvisory: false,
    ),
    this.batchTakeoverPromptSeen = true,
  }) : searchResults = searchResults ?? defaultSearchResults,
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
  final StorageStatus storageStatus;
  final String appVersion;
  final Map<String, DiscoveryPage> discoveryPages;
  final List<Completer<DiscoveryPage>> discoveryCompleters;
  final SkillsException? discoveryError;
  final Map<String, SkillsException> discoveryErrors;
  final SkillDetail remoteDetail;
  final List<SkillsException> detailErrors;
  final List<Set<String>> installFailures;
  final List<SkillsException> installPlanErrors;
  final List<Set<String>> updateFailures;
  final List<SkillsException> updateCheckErrors;
  final UpdateState updateState;
  final BatchTakeoverResult takeoverResult;
  final BatchTakeoverPlan takeoverPlan;
  final Completer<BatchTakeoverPlan>? takeoverPlanCompleter;
  final Completer<BatchTakeoverResult>? takeoverCompleter;
  ReminderSettings reminderSettings;
  bool batchTakeoverPromptSeen;
  int batchTakeoverPromptCompletions = 0;
  bool installed;
  final queries = <String>[];
  final collections = <DiscoveryCollection>[];
  final requestedOffsets = <int>[];
  int installCalls = 0;

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

  @override
  Future<bool> loadBatchTakeoverPromptSeen() async => batchTakeoverPromptSeen;

  @override
  Future<void> markBatchTakeoverPromptSeen() async {
    batchTakeoverPromptSeen = true;
    batchTakeoverPromptCompletions++;
  }

  int updateCalls = 0;
  List<InstallationTargetSelection> lastPlanSelections = const [];
  final executionSelectionHistory = <List<InstallationTargetSelection>>[];
  final updateTargetHistory = <List<String>>[];
  final managementTargetHistory = <Map<String, TargetManagementAction>>[];
  final takeoverPlanRequests = <List<String>>[];
  final takeoverRequests =
      <({BatchTakeoverPlan plan, BatchTakeoverScope scope})>[];
  int exportCalls = 0;
  int detailLoads = 0;
  int agentInspections = 0;
  String? savedPath;
  final List<SkillSummary> searchResults;
}
