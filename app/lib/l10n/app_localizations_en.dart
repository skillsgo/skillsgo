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
  String get relocateProject => 'Relocate';

  @override
  String get removeFromList => 'Remove from List';

  @override
  String removeProjectTitle(String name) {
    return 'Remove $name from SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Only the App reference will be removed. SkillsGo will not change or delete any files in this directory.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — unavailable';
  }

  @override
  String emptyProjectTitle(String name) {
    return 'No Skills found in $name';
  }

  @override
  String get emptyProjectMessage =>
      'This project does not need Git or SkillsGo files. Install its first Skill when you are ready.';

  @override
  String get projectMissingTitle => 'Project directory is missing';

  @override
  String get projectMissingMessage =>
      'The directory may have moved or its volume may be offline. Relocate it or remove only its App reference.';

  @override
  String get projectPermissionTitle => 'Project permission is required';

  @override
  String get projectPermissionMessage =>
      'SkillsGo cannot inspect this selected root. Grant access by relocating it through the directory picker.';

  @override
  String get projectInaccessibleTitle => 'Project directory is inaccessible';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo kept this project reference. Check the path or volume, then relocate it.';

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
  String get searchLibrary => 'Search this Library view';

  @override
  String get libraryNoMatches => 'No matching Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Try a different name, source, Agent, project, or version.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return '$count projects';
  }

  @override
  String versionsSummary(int count) {
    return '$count versions';
  }

  @override
  String get registryManaged => 'Registry managed';

  @override
  String get localManaged => 'Local managed';

  @override
  String get externalInstallation => 'External installation';

  @override
  String get readOnly => 'Read only';

  @override
  String get unversioned => 'Unversioned';

  @override
  String get supportingFiles => 'Supporting files';

  @override
  String get versionDivergence => 'Version divergence';

  @override
  String get healthHealthy => 'Healthy';

  @override
  String get healthMissing => 'Target missing';

  @override
  String get healthReplaced => 'Target replaced';

  @override
  String get healthLocalModification => 'Local Modification';

  @override
  String get healthUnreadable => 'Target unreadable';

  @override
  String get healthUndeclared => 'Not declared';

  @override
  String get healthWorkspaceUnreadable => 'Workspace state unreadable';

  @override
  String get healthLockMismatch => 'Lock mismatch';

  @override
  String get healthUnexpectedPath => 'Unexpected target path';

  @override
  String get healthReceiptMissing => 'Receipt missing';

  @override
  String get modeSymlink => 'Symlink';

  @override
  String get modeCopy => 'Copy';

  @override
  String get modeExternal => 'External';

  @override
  String get receiptPresent => 'Receipt present';

  @override
  String get receiptMissing => 'Receipt missing';

  @override
  String get receiptInvalid => 'Receipt invalid';

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
  String get localReadFailedMessage =>
      'SkillsGo could not read this local installation. Check the target health and filesystem access, then retry.';

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

  @override
  String get installSkill => 'Install Skill';

  @override
  String get installationPlanTitle => 'Choose installation targets';

  @override
  String get closeInstallationPlan => 'Close installation plan';

  @override
  String get installationPlanDescription =>
      'Select exact location-and-Agent cells. Row and column controls are shortcuts for those explicit cells.';

  @override
  String get reviewInstallationPlan => 'Review installation plan';

  @override
  String get reviewInstallationPlanDescription =>
      'Review every target action and Workspace Lock change before files are changed.';

  @override
  String get installationResults => 'Installation results';

  @override
  String get installationResultsDescription =>
      'Each target completed independently. You can stay here or view the installed Skill in Library.';

  @override
  String get installationInProgress => 'Installation in progress';

  @override
  String get locationAgentMatrix => 'Location × Agent';

  @override
  String targetsSelected(int count) {
    return '$count targets selected';
  }

  @override
  String get location => 'Location';

  @override
  String get select => 'Select';

  @override
  String selectTarget(String location, String agent) {
    return 'Select $location for $agent';
  }

  @override
  String selectLocationTargets(String location) {
    return 'Select all available targets in $location';
  }

  @override
  String selectAgentTargets(String agent) {
    return 'Select all available targets for $agent';
  }

  @override
  String get projectUnavailable => 'Project unavailable';

  @override
  String get installedCell => 'Installed';

  @override
  String get unsupportedCell => 'Unavailable';

  @override
  String reviewTargets(int count) {
    return 'Review $count Targets';
  }

  @override
  String installSelectedTargets(int count) {
    return 'Install $count Targets';
  }

  @override
  String get backToTargets => 'Back to Targets';

  @override
  String get stayHere => 'Stay Here';

  @override
  String get viewInLibrary => 'View in Library';

  @override
  String planCreateCount(int count) {
    return '$count create';
  }

  @override
  String planSkipCount(int count) {
    return '$count skip';
  }

  @override
  String planReplaceCount(int count) {
    return '$count replace';
  }

  @override
  String planConflictCount(int count) {
    return '$count conflict';
  }

  @override
  String planRiskCount(int count) {
    return '$count risk blocked';
  }

  @override
  String get refreshInstallationPlan => 'Apply Resolutions';

  @override
  String get replaceVersionConflict =>
      'Replace the installed version at this target';

  @override
  String get replaceIdentityCollision =>
      'Replace the different Skill identity at this target';

  @override
  String get replaceLocalModification =>
      'Discard Local Modifications and replace this target';

  @override
  String get sharedTargetConflict =>
      'This path is shared by other Agent targets';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Return to the target matrix and select every affected Agent before replacing: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Replace the conflicting target';

  @override
  String get confirmHighRiskArtifact => 'High-risk artifact confirmation';

  @override
  String get confirmCriticalRiskArtifact =>
      'Critical-risk override confirmation';

  @override
  String get confirmRiskForSelectedTargets =>
      'I reviewed the artifact files and accept this risk for the selected targets';

  @override
  String get criticalRiskBlocked => 'Critical-risk installation is blocked';

  @override
  String get criticalRiskOverrideDisabled =>
      'Enable the explicit Critical-risk override in Settings before this plan can continue.';

  @override
  String get workspaceLockChanges => 'Workspace Lock changes';

  @override
  String get noWorkspaceLockChanges => 'No Workspace Lock files will change.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'not present';

  @override
  String get planActionCreate => 'Create';

  @override
  String get planActionReplace => 'Replace';

  @override
  String get planActionSkip => 'Skip';

  @override
  String get planActionConflict => 'Conflict';

  @override
  String get planActionBlockedByRisk => 'Blocked by risk';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded targets installed, $failed failed';
  }

  @override
  String get installationProgressTitle => 'Installation in progress';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished of $total targets finished';
  }

  @override
  String get targetWaiting => 'Waiting';

  @override
  String get targetRunning => 'Installing';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retry $count Failed Targets',
      one: 'Retry 1 Failed Target',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Select targets to update';

  @override
  String get updatePlanDescription =>
      'Choose exact Installation Targets. Unselected Agents and projects remain unchanged.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected of $available updateable targets selected';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Source reference: $reference';
  }

  @override
  String get fixedVersionTarget => 'Pinned — no movable reference';

  @override
  String get currentVersionTarget => 'Up to date';

  @override
  String get updateCheckTargetFailed => 'Update check failed';

  @override
  String get reconcileWorkspaceLockTarget => 'Repair workspace lock';

  @override
  String get updateSelectedTargets => 'Update selected targets';

  @override
  String get updateProgressTitle => 'Updating targets';

  @override
  String get updateResultsTitle => 'Update results';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished of $total targets finished';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retry $count Failed Updates',
      one: 'Retry 1 Failed Update',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'No selected target has an available update.';

  @override
  String get closeUpdatePlan => 'Close';

  @override
  String get targetSucceeded => 'Installed';

  @override
  String get targetSkipped => 'Skipped';

  @override
  String get targetConflict => 'Conflict';

  @override
  String get targetFailed => 'Failed';

  @override
  String get targetPathExists =>
      'Another item already exists at this target path.';

  @override
  String get targetBlockedByRisk =>
      'This target was blocked by the current risk policy.';

  @override
  String get targetInstallFailed =>
      'The Skill could not be written to this target.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'The Skill was written, but its Workspace files could not be updated.';

  @override
  String get installationPlanFailed => 'Installation plan could not continue';
}
