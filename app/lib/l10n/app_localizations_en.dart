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
  String get offlineTitle => 'You’re offline';

  @override
  String get offlineMessage =>
      'SkillsGo could not reach the Hub. Check your network, proxy, or Hub Origin.';

  @override
  String get searchFailedTitle => 'Search stumbled';

  @override
  String get validationTitle => 'Check this request';

  @override
  String get validationMessage =>
      'The Hub rejected the request. Review the query and try again.';

  @override
  String get serverTitle => 'Hub unavailable';

  @override
  String get serverMessage =>
      'The Hub could not complete this request. Try again in a moment.';

  @override
  String get timeoutTitle => 'Hub timed out';

  @override
  String get timeoutMessage =>
      'The Hub took too long to respond. Check the connection or try again.';

  @override
  String get invalidResponseTitle => 'Hub response unsupported';

  @override
  String get invalidResponseMessage =>
      'This Hub returned a response SkillsGo cannot read. Check its version and protocol compatibility.';

  @override
  String get invalidLocalDataTitle => 'Local installation data unreadable';

  @override
  String get invalidLocalDataMessage =>
      'The SkillsGo CLI returned local installation data the App cannot read. Update the CLI or remove damaged installation records, then try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get searchEmptyTitle => 'Search, don’t scroll.';

  @override
  String get searchEmptyMessage =>
      'Enter a capability, source, or task to search the public Hub.';

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
      'The Hub returned an empty collection. Try again after new install activity is recorded.';

  @override
  String get loadMore => 'Load more';

  @override
  String get install => 'Install';

  @override
  String get installAll => 'Install all skills';

  @override
  String get latestCommit => 'Latest commit';

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
      'The Hub could not provide this immutable artifact. Retry now or inspect another version.';

  @override
  String get detailInvalidTitle => 'Artifact metadata unsupported';

  @override
  String get detailInvalidMessage =>
      'The Hub returned incomplete or malformed audit metadata. Retry after checking Hub compatibility.';

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
  String get updatesOnly => 'Updates';

  @override
  String get allAgents => 'All Agents';

  @override
  String get allProjects => 'All Projects';

  @override
  String get specificProject => 'Project';

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
  String get manageTargets => 'Manage targets';

  @override
  String skillsSelected(int count) {
    return '$count selected';
  }

  @override
  String get clearSelection => 'Clear selection';

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
  String get stopManaging => 'Stop Managing';

  @override
  String get stopManagingDescription =>
      'Removes SkillsGo ownership metadata and preserves the current target content.';

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
      'SkillsGo could not read this local installation. Check the target health and filesystem access, then retry.';

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
      'Your searches aren’t saved, and SkillsGo doesn’t keep command logs.';

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
  String get targetFailureRetryable => 'This target failed. You can retry it.';

  @override
  String get targetFailureNeedsAttention =>
      'This target needs attention before you retry.';

  @override
  String get installationTargetFailureMessage =>
      'The target was restored to its previous state. Check its path, then retry.';

  @override
  String get workspacePersistenceFailureMessage =>
      'SkillsGo restored this target because the Workspace Manifest could not be saved. Check Workspace access, then retry.';

  @override
  String get installationStateChangedMessage =>
      'This target changed after review. Review the current state before retrying.';

  @override
  String get updateTargetFailureMessage =>
      'This update target failed without stopping unrelated updates. Retry the failed target.';

  @override
  String get managementTargetFailureMessage =>
      'This target action failed without undoing unrelated actions. Retry the failed target.';

  @override
  String get technicalDetails => 'Technical details';

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

  @override
  String get installationFailed => 'Installation could not be completed';

  @override
  String get bringUnderManagement => 'Bring under management';

  @override
  String get localSource => 'Local source';

  @override
  String get noDescriptionAvailable => 'No description available';

  @override
  String moreCoverage(int count) {
    return '+$count more locations';
  }

  @override
  String get adoptExternalTitle => 'Bring this installation under management';

  @override
  String get adoptExternalDescription =>
      'SkillsGo matched the installation by content. Review the exact source and immutable version before continuing.';

  @override
  String get adoptionContentDigest => 'Content identity';

  @override
  String get hubContentMatches => 'Hub matches';

  @override
  String hubMatchSource(String source) {
    return 'Source: $source';
  }

  @override
  String hubMatchVersion(String version) {
    return 'Immutable version: $version';
  }

  @override
  String get associateHub => 'Associate with Hub';

  @override
  String get importAsLocal => 'Import as Local Skill';

  @override
  String get importAsLocalDescription =>
      'No exact Hub match was found. This creates a private Local Skill with no publisher or update source.';

  @override
  String get adoptionPreservesContent =>
      'The current installation content will not be replaced. SkillsGo only records ownership after your confirmation.';

  @override
  String get chooseHubMatch => 'Select an exact Hub match to continue.';

  @override
  String get confirmAdoption => 'Confirm association';

  @override
  String get confirmLocalImport => 'Confirm Local import';

  @override
  String get adoptionFailed =>
      'SkillsGo could not bring this installation under management.';

  @override
  String get installMoreTargets => 'Install more';

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
}
