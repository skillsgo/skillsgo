/*
 * [INPUT]: Depends on the focused domain model modules for discovery, installation, Library, updates, target management, settings, and process contracts.
 * [OUTPUT]: Provides the stable SkillsGateway interface and re-exports the complete App domain vocabulary for existing callers.
 * [POS]: Serves as the narrow compatibility seam shared by UI journeys, production infrastructure, and test adapters while domain models remain locally organized.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'discovery_models.dart';
import 'installation_models.dart';
import 'library_models.dart';
import 'presentation_language.dart';
import 'system_models.dart';
import 'target_management_models.dart';
import 'update_models.dart';

export 'discovery_models.dart';
export 'installation_models.dart';
export 'library_models.dart';
export 'presentation_language.dart';
export 'system_models.dart';
export 'target_management_models.dart';
export 'update_models.dart';

abstract interface class SkillsGateway {
  Future<OnboardingState> loadOnboardingState();
  Future<void> saveOnboardingStep(OnboardingStep step);
  Future<void> completeOnboarding();
  Future<void> resetOnboarding();
  Future<CliStatus> detectCli({String? customPath});
  Future<void> saveCustomCliPath(String? path);
  Future<String?> loadCustomCliPath();
  Future<String> loadHubOrigin();
  Future<void> saveHubOrigin(String origin);
  Future<void> resetHubOrigin();
  Future<String> loadFolderTheme();
  Future<void> saveFolderTheme(String theme);
  Future<AppWallpaper> loadWallpaper();
  Future<void> saveWallpaper(AppWallpaper wallpaper);
  Future<AppThemeMode> loadThemeMode();
  Future<void> saveThemeMode(AppThemeMode mode);
  Future<AppLanguage> loadLanguage();
  Future<void> saveLanguage(AppLanguage language);
  Future<ReminderSettings> loadReminderSettings();
  Future<void> saveReminderSettings(ReminderSettings settings);
  Future<bool> loadBatchTakeoverPromptSeen();
  Future<void> markBatchTakeoverPromptSeen();
  Future<HubStatus> testHubOrigin(String origin);
  Future<HubRuntime> loadHubRuntime();
  Future<PersonalRiskPolicy> loadRiskPolicy();
  Future<void> saveRiskPolicy(PersonalRiskPolicy policy);
  Future<StorageStatus> inspectStorage();
  Future<String> loadAppVersion();
  Future<DiscoveryPage> discover(
    DiscoveryCollection collection, {
    String query = '',
    int offset = 0,
    int limit = 20,
  });
  Future<SkillDetail> loadRemoteDetail(SkillSummary skill);
  Future<AgentCatalog> inspectOnboardingAgents();
  Future<AgentCatalog> inspectAgents();
  Future<List<AddedProject>> loadAddedProjects();
  Future<AddedProject> resolveProjectIcon(AddedProject project);
  Future<List<AddedProject>> addProjects();
  Future<AddedProject?> relocateProject(String id);
  Future<void> removeProject(String id);
  Future<List<InstalledSkill>> listInstalled({
    List<AddedProject> projects = const [],
  });
  Future<BatchTakeoverPlan> planBatchTakeover({
    List<String> projectRoots = const [],
  });
  Future<BatchTakeoverResult> executeBatchTakeover(
    BatchTakeoverPlan plan,
    BatchTakeoverScope scope,
  );
  Future<SkillDetail> loadLocalDetail(InstalledSkill skill);
  Future<CommandResult> install(SkillSummary skill);
  Future<TargetManagementPlan> preflightTargetManagement(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets,
  );
  Future<InstallationExecution> installTargets(
    SkillSummary skill,
    String immutableVersion,
    List<InstallationTargetSelection> selections, {
    bool confirmRisk = false,
    bool allowCritical = false,
  });
  Future<TargetManagementExecution> executeTargetManagement(
    TargetManagementPlan plan, {
    void Function(TargetManagementProgress progress)? onProgress,
  });
  Future<CommandResult?> exportLocalSkill(InstalledSkill skill);
  Future<UpdatePlan> preflightUpdate(
    InstalledSkill skill,
    List<SkillInstallationTarget> targets, {
    String? toVersion,
  });
  Future<UpdateExecution> executeUpdate(
    UpdatePlan plan, {
    void Function(UpdateTargetProgress progress)? onProgress,
  });
  Future<Map<String, UpdateAvailability>> checkUpdates(
    List<InstalledSkill> skills,
  );
}
