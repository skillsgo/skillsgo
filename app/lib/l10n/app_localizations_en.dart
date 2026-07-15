// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get discover => 'Discover';

  @override
  String get library => 'Library';

  @override
  String get settings => 'Settings';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get cliNeedsAttention => 'The SkillsGo CLI needs attention.';

  @override
  String get cliMissingBundled =>
      'The bundled SkillsGo CLI is missing or cannot run. Reinstall SkillsGo.';

  @override
  String get cliDamagedBundled =>
      'The bundled SkillsGo CLI returned an invalid startup response. Reinstall SkillsGo.';

  @override
  String get cliIncompatibleBundled =>
      'The bundled SkillsGo CLI is incompatible with this version of SkillsGo. Update or reinstall the app.';

  @override
  String get officialIndex => 'SkillsGo Registry';

  @override
  String get discoverTitle => 'Find a skill for your next move.';

  @override
  String get searchSkills => 'Search skills…';

  @override
  String get search => 'Search';

  @override
  String get ranking => 'Ranking';

  @override
  String get trending => 'Trending';

  @override
  String get hot => 'Hot';

  @override
  String get discoverNavigation => 'Discover navigation';

  @override
  String get allTimeRanking => 'All-time ranking';

  @override
  String get trendingNow => 'Trending in the last 24 hours';

  @override
  String get hotNow => 'Hot right now';

  @override
  String get allTimeDescription =>
      'Public Skills ordered by accepted installs across all time.';

  @override
  String get trendingDescription =>
      'Public Skills ordered by accepted installs during the latest 24-hour window.';

  @override
  String get hotDescription =>
      'Public Skills ordered by short-term installation velocity and change.';

  @override
  String get offlineTitle => 'You’re offline';

  @override
  String get offlineMessage =>
      'SkillsGo could not reach the Registry. Check your network, proxy, or Registry Origin.';

  @override
  String get searchFailedTitle => 'Search stumbled';

  @override
  String get validationTitle => 'Check this request';

  @override
  String get validationMessage =>
      'The Registry rejected the request. Review the query and try again.';

  @override
  String get serverTitle => 'Registry unavailable';

  @override
  String get serverMessage =>
      'The Registry could not complete this request. Try again in a moment.';

  @override
  String get timeoutTitle => 'Registry timed out';

  @override
  String get timeoutMessage =>
      'The Registry took too long to respond. Check the connection or try again.';

  @override
  String get invalidResponseTitle => 'Registry response unsupported';

  @override
  String get invalidResponseMessage =>
      'This Registry returned a response SkillsGo cannot read. Check its version and protocol compatibility.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get searchEmptyTitle => 'Search, don’t scroll.';

  @override
  String get searchEmptyMessage =>
      'Enter a capability, source, or task to search the public Registry.';

  @override
  String get noSkillsTitle => 'No skills found';

  @override
  String get noSkillsMessage => 'Try a broader phrase or check the spelling.';

  @override
  String get focusSearch => 'Focus search';

  @override
  String get collectionEmptyTitle => 'No Skills in this collection';

  @override
  String get collectionEmptyMessage =>
      'The Registry returned an empty collection. Try again after new install activity is recorded.';

  @override
  String get loadMore => 'Load more';

  @override
  String get install => 'Install';

  @override
  String get installToMoreTargets => 'Install to More Targets';

  @override
  String localTargets(int count) {
    return '$count local targets';
  }

  @override
  String allTimeMetric(String count) {
    return '$count all-time installs';
  }

  @override
  String trendingMetric(String count) {
    return '$count installs / 24h';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value this hour · $change';
  }

  @override
  String get trustUnverified => 'Unverified';

  @override
  String get trustCommunityVerified => 'Community verified';

  @override
  String get trustPublisherVerified => 'Publisher verified';

  @override
  String get trustOfficial => 'Official';

  @override
  String get trustWarned => 'Warned';

  @override
  String get trustDelisted => 'Delisted';

  @override
  String get riskUnknown => 'Risk unknown';

  @override
  String get riskLow => 'Low risk';

  @override
  String get riskMedium => 'Medium risk';

  @override
  String get riskHigh => 'High risk';

  @override
  String get riskCritical => 'Critical risk';

  @override
  String openSkill(String name) {
    return 'Open $name';
  }

  @override
  String installs(String count) {
    return '$count installs';
  }

  @override
  String get detailFailedTitle => 'Couldn’t load this Skill';

  @override
  String get detailLoading => 'Loading auditable Skill detail';

  @override
  String get artifactUnavailableTitle => 'Artifact unavailable';

  @override
  String get artifactUnavailableMessage =>
      'The Registry could not provide this immutable artifact. Retry now or inspect another version.';

  @override
  String get detailInvalidTitle => 'Artifact metadata unsupported';

  @override
  String get detailInvalidMessage =>
      'The Registry returned incomplete or malformed audit metadata. Retry after checking Registry compatibility.';

  @override
  String get instructionsTab => 'Instructions';

  @override
  String get manifestTab => 'Manifest';

  @override
  String immutableVersionLabel(String version) {
    return 'Immutable $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Commit $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Tree $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Content $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Publisher trust verifies ownership or maintenance; it does not certify artifact safety. Risk is assessed separately for this immutable version.';

  @override
  String get knownInstallationTargets => 'Known installation targets';

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get userScope => 'User Scope';

  @override
  String get projectScope => 'Project';

  @override
  String get fileContentUnavailable => 'Binary or unavailable preview';

  @override
  String get fileContentTruncated =>
      'Preview truncated by the Registry safety limit.';

  @override
  String riskEvidence(String paths) {
    return 'Executable evidence: $paths';
  }

  @override
  String get retry => 'Retry';

  @override
  String get backToSearch => 'Back to search';

  @override
  String get installForCodex => 'Install for Codex';

  @override
  String get cliNotDetected => 'skills (not detected)';

  @override
  String get snapshotFiles => 'Snapshot files';

  @override
  String get executableRisk =>
      'This snapshot contains scripts or executable content. Review the files before installing; SkillsGo does not audit them.';

  @override
  String removeTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeDescription =>
      'SkillsGo will remove this user-level Skill. Codex will no longer see it.';

  @override
  String skillFact(String name) {
    return 'Skill: $name';
  }

  @override
  String get scopeGlobal => 'Scope: global';

  @override
  String get agentImpactCodex => 'Agent impact: Codex';

  @override
  String get removeSkill => 'Remove Skill';

  @override
  String get globalCodex => 'Global · Codex';

  @override
  String get yourLibrary => 'Your Library';

  @override
  String get libraryNavigation => 'Library navigation';

  @override
  String get all => 'All';

  @override
  String get addProject => 'Add Project';

  @override
  String get checking => 'Checking…';

  @override
  String get checkUpdates => 'Check updates';

  @override
  String get refresh => 'Refresh';

  @override
  String get libraryUnavailable => 'Library unavailable';

  @override
  String get libraryEmpty => 'Your Library is empty';

  @override
  String get libraryEmptyMessage =>
      'Install a Skill from Discover and it will appear here.';

  @override
  String get notLinked => 'NOT LINKED';

  @override
  String get update => 'Update';

  @override
  String removeNamed(String name) {
    return 'Remove $name';
  }

  @override
  String get backToLibrary => 'Back to Library';

  @override
  String get remove => 'Remove';

  @override
  String get localReadFailed => 'Can’t read this Skill';

  @override
  String get localConfiguration => 'Local configuration';

  @override
  String get settingsNavigation => 'Settings navigation';

  @override
  String get general => 'General';

  @override
  String get agents => 'Agents';

  @override
  String get registry => 'Registry';

  @override
  String get installationPolicy => 'Installation Policy';

  @override
  String get storage => 'Storage';

  @override
  String get about => 'About';

  @override
  String get generalSettingsTitle => 'Desktop preferences';

  @override
  String get generalSettingsDescription =>
      'SkillsGo follows the system language and accessibility preferences, including reduced motion.';

  @override
  String get agentsSettingsTitle => 'Agent runtime';

  @override
  String get registrySettingsTitle => 'Registry Origin';

  @override
  String get registrySettingsDescription =>
      'Use the official Registry or an HTTP(S) self-hosted origin that implements the same SkillsGo protocol.';

  @override
  String get testConnection => 'Test connection';

  @override
  String get saveOrigin => 'Save Origin';

  @override
  String get resetDefault => 'Reset to default';

  @override
  String get connectionReady => 'Connection ready';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get registryInvalidOrigin =>
      'Enter a valid HTTP(S) Origin without credentials, a query, or a fragment.';

  @override
  String registryHttpFailure(int status) {
    return 'Registry returned HTTP $status. Check the Origin and server configuration.';
  }

  @override
  String get registryInvalidProtocol =>
      'The server did not return the SkillsGo Registry search protocol.';

  @override
  String get registryInvalidJson => 'The Registry returned invalid JSON.';

  @override
  String get registryConnectionFailure =>
      'Could not reach the Registry. Check the Origin, network, proxy, and TLS configuration.';

  @override
  String get registryConnectionTimeout =>
      'The Registry connection timed out. Check the network or try again.';

  @override
  String get riskPolicyTitle => 'Personal risk policy';

  @override
  String get confirmHighRisk => 'Require confirmation for High risk';

  @override
  String get confirmHighRiskDescription =>
      'High-risk artifacts always require an additional confirmation before installation.';

  @override
  String get allowCriticalOverride =>
      'Allow an explicit Critical-risk override';

  @override
  String get allowCriticalOverrideDescription =>
      'Critical-risk artifacts remain blocked by default. Enable this only to expose a separate manual override.';

  @override
  String get storageSettingsTitle => 'Content-addressed Store';

  @override
  String get storageHealthy => 'Readable';

  @override
  String get storageNotInitialized => 'Not initialized';

  @override
  String get storageUnavailable => 'Unavailable';

  @override
  String get storagePathUnavailable =>
      'Store path unavailable until CLI diagnostics are ready.';

  @override
  String get storageHealthyDescription =>
      'The CLI can read the Store without changing its contents.';

  @override
  String get storageNotInitializedDescription =>
      'The Store does not exist yet and was not created by this check.';

  @override
  String get storageUnavailableDescription =>
      'The CLI cannot read the Store. Check its permissions and parent directory.';

  @override
  String get storageInvalidResponse =>
      'The bundled CLI returned an unsupported diagnostics response.';

  @override
  String get aboutSettingsTitle => 'Product compatibility';

  @override
  String get appVersion => 'App version';

  @override
  String get cliVersion => 'Bundled CLI version';

  @override
  String get compatible => 'Compatible';

  @override
  String get registryOriginSaved => 'Registry Origin saved and applied.';

  @override
  String get policySaved => 'Installation policy saved.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'READY';

  @override
  String get unknown => 'UNKNOWN';

  @override
  String get missing => 'MISSING';

  @override
  String get incompatible => 'INCOMPATIBLE';

  @override
  String get detecting => 'Detecting…';

  @override
  String get customCliPath => 'Custom executable path';

  @override
  String get saveAndDetect => 'Save & detect';

  @override
  String get detectAgain => 'Detect again';

  @override
  String get agentInstalled => 'Installed';

  @override
  String get agentSupported => 'Supported';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed installed · $supported supported';
  }

  @override
  String get agentDetectedDescription =>
      'Agent installation detected. Skills can target its supported scopes.';

  @override
  String get agentSupportedDescription =>
      'Supported, but no installation signal was found. Install the Agent or use a project target.';

  @override
  String agentUserTarget(String path) {
    return 'User target: $path';
  }

  @override
  String get agentInspectionFailed =>
      'Agent detection data is unavailable. Run detection again.';

  @override
  String get noInstalledAgentsTitle => 'No installed Agents detected';

  @override
  String get noInstalledAgentsMessage =>
      'You can keep browsing this Skill, but there is no installation target yet. Install a supported Agent, then run detection again.';

  @override
  String get clearCustomPath => 'Clear custom path';

  @override
  String get privacyProvenance => 'Privacy & provenance';

  @override
  String get privacySummary =>
      'SkillsGo does not store searches or persist command logs. Its bundled CLI remains inside the App and is never installed into your system PATH.';

  @override
  String get privacyAffiliation =>
      'Anonymous installation telemetry is controlled by SkillsGo settings. SkillsGo is not affiliated with OpenAI or Codex.';

  @override
  String get commandCompleted => 'Command completed';

  @override
  String get commandFailed => 'Command failed';

  @override
  String commandExit(int code) {
    return 'Exit $code · expand for this session’s log';
  }

  @override
  String get command => 'Command';

  @override
  String get cancel => 'Cancel';

  @override
  String get updateUnknown => 'UNKNOWN';

  @override
  String get updateChecking => 'CHECKING';

  @override
  String get upToDate => 'UP TO DATE';

  @override
  String get updateAvailable => 'UPDATE';

  @override
  String get updateUnavailable => 'UNAVAILABLE';

  @override
  String get updateCheckFailed => 'CHECK FAILED';
}
