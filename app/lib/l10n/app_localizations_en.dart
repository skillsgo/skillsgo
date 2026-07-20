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
  String get discoverSkills => 'It’s nice to know a little more.';

  @override
  String get library => 'Library';

  @override
  String get settings => 'Settings';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get cliNeedsAttention =>
      'A required SkillsGo component needs attention.';

  @override
  String get cliMissingBundled =>
      'A required SkillsGo component is missing or cannot start. Reinstall SkillsGo to restore it.';

  @override
  String get cliDamagedBundled =>
      'A required SkillsGo component is damaged. Reinstall SkillsGo to restore it.';

  @override
  String get cliIncompatibleBundled =>
      'A required SkillsGo component does not match this app version. Update or reinstall SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Find a skill for your next move.';

  @override
  String get skillsLeaderboard => 'It’s nice to know a little more.';

  @override
  String searchResultsFor(String query) {
    return 'Results for “$query”';
  }

  @override
  String get searchSkills => 'Search skills or paste a Git link…';

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
  String get offlineTitle => 'Can’t connect to SkillsGo';

  @override
  String get offlineMessage =>
      'Check your internet connection and try again. If you use a proxy or custom service address, review it in Settings.';

  @override
  String get searchFailedTitle => 'Search stumbled';

  @override
  String get validationTitle => 'Check what you entered';

  @override
  String get validationMessage =>
      'SkillsGo couldn’t use this request. Review what you entered and try again.';

  @override
  String get serverTitle => 'Service temporarily unavailable';

  @override
  String get serverMessage =>
      'SkillsGo can’t complete this request right now. Try again in a moment.';

  @override
  String get timeoutTitle => 'This is taking too long';

  @override
  String get timeoutMessage =>
      'The service did not respond in time. Check your connection or try again.';

  @override
  String get invalidResponseTitle => 'SkillsGo needs an update';

  @override
  String get invalidResponseMessage =>
      'This response cannot be read by your version of SkillsGo. Update the app, then try again.';

  @override
  String get invalidLocalDataTitle => 'Can’t read an installed skill';

  @override
  String get invalidLocalDataMessage =>
      'Some local installation information is damaged or incompatible. Update or reinstall SkillsGo, then try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get searchEmptyTitle => 'Search, don’t scroll.';

  @override
  String get searchEmptyMessage =>
      'Enter a capability, source, or task to search public skills.';

  @override
  String get noSkillsTitle => 'No skills found';

  @override
  String get noSkillsMessage => 'Try a broader phrase or check the spelling.';

  @override
  String get focusSearch => 'Focus search';

  @override
  String get skillsFromLink => 'Skills from this link';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills',
      one: '1 skill',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills from $source',
      one: '1 skill from $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'This link is ready to inspect';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source is not in the current search results. SkillsGo can inspect the link directly in the next step.';
  }

  @override
  String get inspectSource => 'View skills in this link';

  @override
  String get collectionEmptyTitle => 'No Skills in this collection';

  @override
  String get collectionEmptyMessage =>
      'There’s nothing here yet. Try again after more installation activity.';

  @override
  String get loadMore => 'Load more';

  @override
  String get install => 'Install';

  @override
  String get installAll => 'Install all skills';

  @override
  String get latestCommit => 'Latest commit';

  @override
  String get installToMoreTargets => 'Install in More Locations';

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
      'This version is not available right now. Try again or choose another version.';

  @override
  String get detailInvalidTitle => 'Artifact metadata unsupported';

  @override
  String get detailInvalidMessage =>
      'Some details for this skill are incomplete or cannot be read. Update SkillsGo, then try again.';

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
  String get installationRange => 'Installed scope';

  @override
  String get targetDetails => 'Show target details';

  @override
  String get hideTargetDetails => 'Hide target details';

  @override
  String installedVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Project';

  @override
  String get fileContentUnavailable => 'Binary or unavailable preview';

  @override
  String get fileContentTruncated =>
      'Preview truncated by the Hub safety limit.';

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
  String get globalCodex => 'Global · Codex';

  @override
  String get yourLibrary => 'What you know is all here.';

  @override
  String get libraryNavigation => 'Library navigation';

  @override
  String get all => 'All';

  @override
  String get allSkills => 'All Skills';

  @override
  String get updatesOnly => 'Updates';

  @override
  String get allAgents => 'All Agents';

  @override
  String get allProjects => 'All Projects';

  @override
  String get specificProject => 'Project';

  @override
  String get userScope => 'Global';

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
  String get emptyProjectTitle => 'No Skills yet';

  @override
  String get browseSkills => 'Browse Skills';

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
  String get libraryEmpty => 'No skills installed yet';

  @override
  String get libraryEmptyMessage =>
      'Install a Skill from Discover and it will appear here.';

  @override
  String get searchLibrary => 'Search installed skills';

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
  String get hubManaged => 'Hub managed';

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
  String get modeSymlink => 'Symlink';

  @override
  String get modeCopy => 'Copy';

  @override
  String get modeExternal => 'External';

  @override
  String get notLinked => 'NOT LINKED';

  @override
  String get update => 'Update';

  @override
  String get backToLibrary => 'Back to Library';

  @override
  String get remove => 'Remove';

  @override
  String get manageTargets => 'Manage scope';

  @override
  String skillsSelected(int count) {
    return '$count selected';
  }

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get selectCurrentResults => 'Select current results';

  @override
  String get clearCurrentResultSelection => 'Clear current result selection';

  @override
  String get manageTargetsTitle => 'Manage installation targets';

  @override
  String get manageTargetsDescription =>
      'Choose an exact action for each target. Unselected targets will not change.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$selected of $total targets selected';
  }

  @override
  String get repairTarget => 'Repair';

  @override
  String get confirmRemoveTarget => 'Confirm remove';

  @override
  String get applyTargetActions => 'Apply selected actions';

  @override
  String get managementProgressTitle => 'Applying target actions';

  @override
  String get managementResultsTitle => 'Target action results';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded succeeded, $failed failed';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Selected project actions will update skillsgo.mod and skillsgo.sum.';

  @override
  String get targetContentPreserved =>
      'Current target content will be preserved.';

  @override
  String get localReadFailed => 'Can’t read this Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo could not read this installed skill. Check that its folder is available and accessible, then try again.';

  @override
  String get localConfiguration => 'SKILLSGO SETTINGS';

  @override
  String get settingsNavigation => 'Settings navigation';

  @override
  String get general => 'Personalize';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Installation Policy';

  @override
  String get storage => 'Storage';

  @override
  String get colorScheme => 'Color Scheme';

  @override
  String get about => 'About';

  @override
  String get colorSchemeInspectorTitle => 'Generated Material color roles';

  @override
  String get skillsColorTokensTitle => 'SkillsGo semantic colors';

  @override
  String get skillsColorTokensDescription =>
      'Product colors built from Radix Sand and organized with Primer semantics, with Folder as a dedicated spatial hierarchy.';

  @override
  String get colorSchemeInspectorDescription =>
      'Preview every non-deprecated ColorScheme token generated from the current seed. Click a color to copy its HEX value.';

  @override
  String get colorSchemePairPreview => 'Semantic pairs';

  @override
  String get colorSchemePairPreviewDescription =>
      'Foreground and background roles rendered together to expose contrast and hierarchy.';

  @override
  String get colorSchemeComponentPreview => 'Component preview';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Representative Material controls rendered with this exact preview scheme.';

  @override
  String get colorSchemeSampleTitle => 'Skill card title';

  @override
  String get colorSchemeSampleBody => 'Secondary copy uses onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Copied';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Primary';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Primary emphasis, containers, and fixed accent roles.';

  @override
  String get colorSchemeGroupSecondary => 'Secondary';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Supporting emphasis and fixed secondary roles.';

  @override
  String get colorSchemeGroupTertiary => 'Tertiary';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Contrasting accents and fixed tertiary roles.';

  @override
  String get colorSchemeGroupSurface => 'Surface';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Page, container, elevation, and foreground hierarchy.';

  @override
  String get colorSchemeGroupUtility => 'Outline & Utility';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Boundaries, shadows, scrims, and inverse surfaces.';

  @override
  String get colorSchemeGroupError => 'Error';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Error actions, messages, and containers.';

  @override
  String get colorSchemeUsagePrimary =>
      'Primary actions, focus, and high-emphasis accents.';

  @override
  String get colorSchemeUsageSecondary =>
      'Supporting actions and medium-emphasis accents.';

  @override
  String get colorSchemeUsageTertiary =>
      'Contrasting accents that complement primary and secondary.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Text and icons displayed on $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Lower-emphasis $family container for selections and accents.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Brightness-independent fixed $family container.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Dimmed brightness-independent fixed $family container.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'High-emphasis content on the fixed $family container.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Lower-emphasis content on the fixed $family container.';
  }

  @override
  String get colorSchemeUsageSurface => 'Base page and large-region surface.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Dimmed base surface used at the darkest surface tone.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Bright base surface used at the lightest surface tone.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'The $level surface-container elevation.';
  }

  @override
  String get colorSchemeElevationLowest => 'lowest';

  @override
  String get colorSchemeElevationLow => 'low';

  @override
  String get colorSchemeElevationDefault => 'default';

  @override
  String get colorSchemeElevationHigh => 'high';

  @override
  String get colorSchemeElevationHighest => 'highest';

  @override
  String get colorSchemeUsageOnSurface =>
      'Primary text and icons displayed on surfaces.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Secondary text, labels, and subdued icons on surfaces.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Material elevation tint derived from primary.';

  @override
  String get colorSchemeUsageOutline =>
      'Prominent boundaries and focused component outlines.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Subtle boundaries, separators, and low-emphasis outlines.';

  @override
  String get colorSchemeUsageShadow =>
      'Drop-shadow color for elevated surfaces.';

  @override
  String get colorSchemeUsageScrim =>
      'Modal overlay used to de-emphasize background content.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Surface with reversed light and dark emphasis.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Primary accent displayed on an inverse surface.';

  @override
  String get colorSchemeUsageError =>
      'Error actions, status, and high-emphasis feedback.';

  @override
  String get save => 'Save';

  @override
  String get advancedSettings => 'Advanced';

  @override
  String get remindersSettings => 'Reminders';

  @override
  String get remindersSettingsTitle => 'Reminder settings';

  @override
  String get remindersSettingsDescription =>
      'Choose which reminders to receive.';

  @override
  String get updateReminderTitle => 'Update reminders';

  @override
  String get updateReminderDescription =>
      'Check for updates when Library opens.';

  @override
  String get securityReminderTitle => 'High-risk alerts';

  @override
  String get securityReminderDescription =>
      'Notify you of new High or Critical risks in installed skills.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count installed skills have updates';
  }

  @override
  String get openAvailableUpdates =>
      'Open the available-updates view to review and update them.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count installed skills need a security review';
  }

  @override
  String get reviewInstalledSkills =>
      'Review their risk information before using or updating them.';

  @override
  String get generalSettingsTitle => 'Make SkillsGo yours';

  @override
  String get generalSettingsDescription =>
      'The interface follows your system language, accessibility, and motion preferences.';

  @override
  String get agentsSettingsTitle => 'Agent runtime';

  @override
  String get hubSettingsTitle => 'Hub Origin';

  @override
  String get hubSettingsDescription =>
      'Use the official Hub or an HTTP(S) self-hosted origin that implements the same SkillsGo protocol.';

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
  String get hubInvalidOrigin =>
      'Enter a valid HTTP(S) Origin without credentials, a query, or a fragment.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub returned HTTP $status. Check the Origin and server configuration.';
  }

  @override
  String get hubInvalidProtocol =>
      'The server did not return the SkillsGo Hub search protocol.';

  @override
  String get hubInvalidJson => 'The Hub returned invalid JSON.';

  @override
  String get hubConnectionFailure =>
      'Could not reach the Hub. Check the Origin, network, proxy, and TLS configuration.';

  @override
  String get hubConnectionTimeout =>
      'The Hub connection timed out. Check the network or try again.';

  @override
  String get riskPolicyTitle => 'Personal risk policy';

  @override
  String get riskPolicyDescription =>
      'Safety rules apply when you install or update a skill.';

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
  String get hubOriginSaved => 'Hub Origin saved and applied.';

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
  String installedAgentsTitle(int count) {
    return 'Installed · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Not installed · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Supported by SkillsGo, but not detected on this Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Skill loading paths: $paths';
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
      'Your searches aren’t saved, and SkillsGo doesn’t keep command logs.';

  @override
  String get language => 'Language';

  @override
  String get personalizationTheme => 'Theme';

  @override
  String get folderColorTheme => 'Theme color';

  @override
  String get folderColorThemeDescription =>
      'Pick a color you like. SkillsGo will build a coordinated interface palette around it.';

  @override
  String get brandNameNeteaseCloudMusic => 'NetEase Cloud Music';

  @override
  String get brandNameRaspberryPi => 'Raspberry Pi';

  @override
  String get brandNameChinaEasternAirlines => 'China Eastern Airlines';

  @override
  String get brandNameNvidia => 'NVIDIA';

  @override
  String get brandNameTaobao => 'Taobao';

  @override
  String get brandNameBitcoin => 'Bitcoin';

  @override
  String get appearanceMode => 'Mode';

  @override
  String get appearanceModeDescription =>
      'Follow your system appearance, or always use a light or dark theme.';

  @override
  String get followSystem => 'System';

  @override
  String get lightMode => 'Light';

  @override
  String get darkMode => 'Dark';

  @override
  String get wallpaper => 'Wallpaper';

  @override
  String get wallpaperDescription =>
      'Choose a celestial background. Your selection appears immediately behind Folder.';

  @override
  String get wallpaperSun => 'Sun';

  @override
  String get wallpaperMercury => 'Mercury';

  @override
  String get wallpaperVenus => 'Venus';

  @override
  String get wallpaperEarth => 'Earth';

  @override
  String get wallpaperMars => 'Mars';

  @override
  String get wallpaperJupiter => 'Jupiter';

  @override
  String get wallpaperSaturn => 'Saturn';

  @override
  String get wallpaperUranus => 'Uranus';

  @override
  String get wallpaperNeptune => 'Neptune';

  @override
  String get wallpaperPluto => 'Pluto';

  @override
  String get wallpaperMoon => 'Moon';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Folder theme';
  }

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
  String get installLocationTitle => 'Set installation location';

  @override
  String get userLevel => 'User Level';

  @override
  String get projectLevel => 'Project Level';

  @override
  String get projects => 'Projects';

  @override
  String get loading => 'Loading…';

  @override
  String get repositoryParsing => 'Parsing Repository…';

  @override
  String userInstallSummary(int agents) {
    return 'Available to $agents Agents at user level';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects projects · $agents Agents';
  }

  @override
  String get installationResults => 'Installation results';

  @override
  String get installationInProgress => 'Installation in progress';

  @override
  String get installationSucceeded => 'Installation complete';

  @override
  String get installationSucceededMessage =>
      'The Skill is now available in the selected locations.';

  @override
  String get projectUnavailable => 'Project unavailable';

  @override
  String get installedCell => 'Installed';

  @override
  String get unsupportedCell => 'Unavailable';

  @override
  String get confirmInstall => 'Confirm Installation';

  @override
  String installAllRepositorySkills(int count) {
    return 'Install all repository skills ($count)';
  }

  @override
  String get installAllSkillsTo => 'Install all skills to';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Install all $repository skills ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Install $skill to';
  }

  @override
  String get availableInAllProjects => 'All projects';

  @override
  String get availableInSelectedProjects => 'Selected projects';

  @override
  String get usedBy => 'For Agents';

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
  String get replaceSkillIdCollision =>
      'Replace the different Skill ID at this target';

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
  String get workspaceManifestChanges => 'Workspace Manifest changes';

  @override
  String get noWorkspaceManifestChanges =>
      'No Workspace Manifest files will change.';

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
  String get reconcileWorkspaceManifestTarget => 'Repair workspace manifest';

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
  String get targetFailureRetryable =>
      'This location could not be changed. You can try again.';

  @override
  String get targetFailureNeedsAttention =>
      'This location needs your attention before you try again.';

  @override
  String get installationTargetFailureMessage =>
      'Nothing was changed at this location. Check that the folder is available and try again.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Nothing was changed because SkillsGo could not save the project settings. Check that the project folder is writable and try again.';

  @override
  String get installationStateChangedMessage =>
      'This location changed while you were reviewing it. Review the latest state before trying again.';

  @override
  String get updateTargetFailureMessage =>
      'This location could not be updated. Other locations were not affected, so you can retry only this one.';

  @override
  String get managementTargetFailureMessage =>
      'This action could not be completed here. Other locations were not affected, so you can retry only this one.';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String get targetPathExists =>
      'Another item already exists at this location.';

  @override
  String get targetBlockedByRisk =>
      'Your current safety settings blocked installation at this location.';

  @override
  String get targetInstallFailed =>
      'The skill could not be installed at this location.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'The skill was installed, but the project settings could not be updated.';

  @override
  String get installationPlanFailed => 'Installation plan could not continue';

  @override
  String get installationFailed => 'Installation could not be completed';

  @override
  String get localSource => 'Local source';

  @override
  String get noDescriptionAvailable => 'No description available';

  @override
  String moreCoverage(int count) {
    return '+$count more locations';
  }

  @override
  String get batchTakeoverAction => 'Manage existing skills';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Manage ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Checking existing skills…';

  @override
  String get batchTakeoverRetry => 'Check manageable skills again';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count can be managed';
  }

  @override
  String get batchTakeoverPending => 'Adding skills to management…';

  @override
  String get batchTakeoverTitle => 'Manage existing skills with SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo will add local management records without moving, overwriting, or uploading skill files. Unsupported or changed items will be skipped.';

  @override
  String get batchTakeoverStoryTitle =>
      'Turn scattered skills into one clear Library';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count existing skills',
      one: '1 existing skill',
    );
    return 'SkillsGo found $_temp0 it can manage in this location.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Before management, it is unclear where existing skills are installed, whether they are current, how to recover them, or whether projects use the same version.';

  @override
  String get batchTakeoverPainLocation => 'Unknown install location';

  @override
  String get batchTakeoverPainFreshness => 'Unknown update status';

  @override
  String get batchTakeoverPainRecovery => 'No recovery when broken';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Different versions across projects';

  @override
  String get batchTakeoverFolderTitle => 'Existing Skills';

  @override
  String get batchTakeoverFolderSubtitle => 'Unclear status';

  @override
  String get batchTakeoverAfterLabel => 'AFTER';

  @override
  String get batchTakeoverAfterTitle => 'One clear Library';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo Library';

  @override
  String get batchTakeoverBenefitLocation => 'Clear locations';

  @override
  String get batchTakeoverBenefitFreshness => 'Updates visible';

  @override
  String get batchTakeoverBenefitRecovery => 'Easy recovery';

  @override
  String get batchTakeoverBenefitVersions => 'Versions clear';

  @override
  String get batchTakeoverManagedSection => 'Managed by SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Waiting to be managed';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name is managed by SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name could not be added to management';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name is waiting to be managed';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills are',
      one: '1 skill is',
    );
    return 'After management, $_temp0 organized in one Library with a clear managed status.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count more';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Add these existing skills to SkillsGo management.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANIZE';

  @override
  String get batchTakeoverPreservation =>
      'Your files, paths, and current workflows stay exactly where they are. SkillsGo only completes its local management records.';

  @override
  String get batchTakeoverLaterHint =>
      'If you skip, you can use Manage existing skills from Library anytime.';

  @override
  String get batchTakeoverSkip => 'Not now';

  @override
  String get batchTakeoverConfirm => 'Add to management';

  @override
  String get batchTakeoverExecutionRetry => 'Retry';

  @override
  String get batchTakeoverResultTitle => 'Skills added to management';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver skills added to management, $skipped skipped.';
  }

  @override
  String get batchTakeoverClose => 'Close';

  @override
  String get installMoreTargets => 'Install in more locations';

  @override
  String get exportLocalSkill => 'Export';

  @override
  String get exportLocalSkillDescription =>
      'Export this Local Skill as a portable ZIP archive.';

  @override
  String get detailInstalls => 'Installs';

  @override
  String get detailRepository => 'Repository';

  @override
  String get detailStars => 'Stars';

  @override
  String get detailUpdated => 'Updated';

  @override
  String get detailArchiveSize => 'ZIP Size';

  @override
  String get pathLabel => 'Project path';

  @override
  String get copyProjectPath => 'Copy project path';

  @override
  String get projectPathCopied => 'Project path copied';

  @override
  String get onboardingWelcomeTitle => 'Welcome to SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Discover, install, and manage Skills across your Agents and projects.';

  @override
  String get onboardingDetectedAgents => 'Detected Agents';

  @override
  String get onboardingNoAgents =>
      'No installed Agents detected. You can still continue.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingProjectsTitle => 'Add your projects';

  @override
  String get onboardingProjectsDescription =>
      'Choose the projects you want SkillsGo to manage.';

  @override
  String get onboardingAddProject => 'Add now';

  @override
  String get onboardingAddProjectLater => 'or later';

  @override
  String get onboardingStartUsing => 'Start Using SkillsGo';

  @override
  String get onboardingBack => 'Back';

  @override
  String get restartOnboardingTitle => 'Onboarding';

  @override
  String get restartOnboardingDescription =>
      'View the first-launch guide again without removing projects, settings, or Skills data.';

  @override
  String get restartOnboardingAction => 'Restart Onboarding';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo could not restart Onboarding.';

  @override
  String get libraryRefreshSettingsTitle => 'Refresh local Library';

  @override
  String get libraryRefreshSettingsDescription =>
      'Rescan installed Skills, Added Projects, Agents, and external Skills that can be managed. This does not install, update, or remove anything.';

  @override
  String get libraryRefreshSettingsAction => 'Refresh Library';

  @override
  String get libraryRefreshSettingsPending => 'Refreshing Library…';

  @override
  String get libraryRefreshSettingsSuccess => 'Local Library refreshed.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo could not refresh the local Library.';

  @override
  String get onboardingProjectError =>
      'SkillsGo could not add projects from this directory.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo could not load your added projects.';

  @override
  String get onboardingStartupError => 'SkillsGo could not load setup.';

  @override
  String get onboardingStateError =>
      'SkillsGo could not save your setup progress. Try again.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI needs attention';

  @override
  String get onboardingCliErrorDescription =>
      'Repair the bundled CLI, then retry to continue.';
}
