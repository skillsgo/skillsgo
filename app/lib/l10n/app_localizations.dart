import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @discoverSkills.
  ///
  /// In en, this message translates to:
  /// **'It’s nice to know a little more.'**
  String get discoverSkills;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @cliNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'A required SkillsGo component needs attention.'**
  String get cliNeedsAttention;

  /// No description provided for @cliMissingBundled.
  ///
  /// In en, this message translates to:
  /// **'A required SkillsGo component is missing or cannot start. Reinstall SkillsGo to restore it.'**
  String get cliMissingBundled;

  /// No description provided for @cliDamagedBundled.
  ///
  /// In en, this message translates to:
  /// **'A required SkillsGo component is damaged. Reinstall SkillsGo to restore it.'**
  String get cliDamagedBundled;

  /// No description provided for @cliIncompatibleBundled.
  ///
  /// In en, this message translates to:
  /// **'A required SkillsGo component does not match this app version. Update or reinstall SkillsGo.'**
  String get cliIncompatibleBundled;

  /// No description provided for @officialIndex.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo Hub'**
  String get officialIndex;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a skill for your next move.'**
  String get discoverTitle;

  /// No description provided for @skillsLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'It’s nice to know a little more.'**
  String get skillsLeaderboard;

  /// No description provided for @searchResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Results for “{query}”'**
  String searchResultsFor(String query);

  /// No description provided for @searchSkills.
  ///
  /// In en, this message translates to:
  /// **'Search skills or paste a Git link…'**
  String get searchSkills;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @ranking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get ranking;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @hot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get hot;

  /// No description provided for @discoverNavigation.
  ///
  /// In en, this message translates to:
  /// **'Discover navigation'**
  String get discoverNavigation;

  /// No description provided for @allTimeRanking.
  ///
  /// In en, this message translates to:
  /// **'All-time ranking'**
  String get allTimeRanking;

  /// No description provided for @trendingNow.
  ///
  /// In en, this message translates to:
  /// **'Trending in the last 24 hours'**
  String get trendingNow;

  /// No description provided for @hotNow.
  ///
  /// In en, this message translates to:
  /// **'Hot right now'**
  String get hotNow;

  /// No description provided for @allTimeDescription.
  ///
  /// In en, this message translates to:
  /// **'Public Skills ordered by accepted installs across all time.'**
  String get allTimeDescription;

  /// No description provided for @trendingDescription.
  ///
  /// In en, this message translates to:
  /// **'Public Skills ordered by accepted installs during the latest 24-hour window.'**
  String get trendingDescription;

  /// No description provided for @hotDescription.
  ///
  /// In en, this message translates to:
  /// **'Public Skills ordered by short-term installation velocity and change.'**
  String get hotDescription;

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Can’t connect to SkillsGo'**
  String get offlineTitle;

  /// No description provided for @offlineMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again. If you use a proxy or custom service address, review it in Settings.'**
  String get offlineMessage;

  /// No description provided for @searchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Search stumbled'**
  String get searchFailedTitle;

  /// No description provided for @validationTitle.
  ///
  /// In en, this message translates to:
  /// **'Check what you entered'**
  String get validationTitle;

  /// No description provided for @validationMessage.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo couldn’t use this request. Review what you entered and try again.'**
  String get validationMessage;

  /// No description provided for @serverTitle.
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable'**
  String get serverTitle;

  /// No description provided for @serverMessage.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo can’t complete this request right now. Try again in a moment.'**
  String get serverMessage;

  /// No description provided for @timeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'This is taking too long'**
  String get timeoutTitle;

  /// No description provided for @timeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The service did not respond in time. Check your connection or try again.'**
  String get timeoutMessage;

  /// No description provided for @invalidResponseTitle.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo needs an update'**
  String get invalidResponseTitle;

  /// No description provided for @invalidResponseMessage.
  ///
  /// In en, this message translates to:
  /// **'This response cannot be read by your version of SkillsGo. Update the app, then try again.'**
  String get invalidResponseMessage;

  /// No description provided for @invalidLocalDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Can’t read an installed skill'**
  String get invalidLocalDataTitle;

  /// No description provided for @invalidLocalDataMessage.
  ///
  /// In en, this message translates to:
  /// **'Some local installation information is damaged or incompatible. Update or reinstall SkillsGo, then try again.'**
  String get invalidLocalDataMessage;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Search, don’t scroll.'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a capability, source, or task to search public skills.'**
  String get searchEmptyMessage;

  /// No description provided for @noSkillsTitle.
  ///
  /// In en, this message translates to:
  /// **'No skills found'**
  String get noSkillsTitle;

  /// No description provided for @noSkillsMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a broader phrase or check the spelling.'**
  String get noSkillsMessage;

  /// No description provided for @focusSearch.
  ///
  /// In en, this message translates to:
  /// **'Focus search'**
  String get focusSearch;

  /// No description provided for @skillsFromLink.
  ///
  /// In en, this message translates to:
  /// **'Skills from this link'**
  String get skillsFromLink;

  /// No description provided for @skillCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 skill} other{{count} skills}}'**
  String skillCount(int count);

  /// No description provided for @sourceResultsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 skill from {source}} other{{count} skills from {source}}}'**
  String sourceResultsSummary(String source, int count);

  /// No description provided for @sourceSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'This link is ready to inspect'**
  String get sourceSearchEmptyTitle;

  /// No description provided for @sourceSearchEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'{source} is not in the current search results. SkillsGo can inspect the link directly in the next step.'**
  String sourceSearchEmptyMessage(String source);

  /// No description provided for @inspectSource.
  ///
  /// In en, this message translates to:
  /// **'View skills in this link'**
  String get inspectSource;

  /// No description provided for @collectionEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Skills in this collection'**
  String get collectionEmptyTitle;

  /// No description provided for @collectionEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'There’s nothing here yet. Try again after more installation activity.'**
  String get collectionEmptyMessage;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @installAll.
  ///
  /// In en, this message translates to:
  /// **'Install all skills'**
  String get installAll;

  /// No description provided for @latestCommit.
  ///
  /// In en, this message translates to:
  /// **'Latest commit'**
  String get latestCommit;

  /// No description provided for @installToMoreTargets.
  ///
  /// In en, this message translates to:
  /// **'Install in More Locations'**
  String get installToMoreTargets;

  /// No description provided for @localTargets.
  ///
  /// In en, this message translates to:
  /// **'{count} local targets'**
  String localTargets(int count);

  /// No description provided for @allTimeMetric.
  ///
  /// In en, this message translates to:
  /// **'{count} all-time installs'**
  String allTimeMetric(String count);

  /// No description provided for @trendingMetric.
  ///
  /// In en, this message translates to:
  /// **'{count} installs / 24h'**
  String trendingMetric(String count);

  /// No description provided for @hotMetric.
  ///
  /// In en, this message translates to:
  /// **'{value} this hour · {change}'**
  String hotMetric(String value, String change);

  /// No description provided for @trustUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get trustUnverified;

  /// No description provided for @trustCommunityVerified.
  ///
  /// In en, this message translates to:
  /// **'Community verified'**
  String get trustCommunityVerified;

  /// No description provided for @trustPublisherVerified.
  ///
  /// In en, this message translates to:
  /// **'Publisher verified'**
  String get trustPublisherVerified;

  /// No description provided for @trustOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get trustOfficial;

  /// No description provided for @trustWarned.
  ///
  /// In en, this message translates to:
  /// **'Warned'**
  String get trustWarned;

  /// No description provided for @trustDelisted.
  ///
  /// In en, this message translates to:
  /// **'Delisted'**
  String get trustDelisted;

  /// No description provided for @riskUnknown.
  ///
  /// In en, this message translates to:
  /// **'Risk unknown'**
  String get riskUnknown;

  /// No description provided for @riskLow.
  ///
  /// In en, this message translates to:
  /// **'Low risk'**
  String get riskLow;

  /// No description provided for @riskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium risk'**
  String get riskMedium;

  /// No description provided for @riskHigh.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get riskHigh;

  /// No description provided for @riskCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical risk'**
  String get riskCritical;

  /// No description provided for @openSkill.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String openSkill(String name);

  /// No description provided for @installs.
  ///
  /// In en, this message translates to:
  /// **'{count} installs'**
  String installs(String count);

  /// No description provided for @detailFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load this Skill'**
  String get detailFailedTitle;

  /// No description provided for @detailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading auditable Skill detail'**
  String get detailLoading;

  /// No description provided for @artifactUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifact unavailable'**
  String get artifactUnavailableTitle;

  /// No description provided for @artifactUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This version is not available right now. Try again or choose another version.'**
  String get artifactUnavailableMessage;

  /// No description provided for @detailInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifact metadata unsupported'**
  String get detailInvalidTitle;

  /// No description provided for @detailInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'Some details for this skill are incomplete or cannot be read. Update SkillsGo, then try again.'**
  String get detailInvalidMessage;

  /// No description provided for @instructionsTab.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructionsTab;

  /// No description provided for @manifestTab.
  ///
  /// In en, this message translates to:
  /// **'Manifest'**
  String get manifestTab;

  /// No description provided for @immutableVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Immutable {version}'**
  String immutableVersionLabel(String version);

  /// No description provided for @commitIdentity.
  ///
  /// In en, this message translates to:
  /// **'Commit {sha}'**
  String commitIdentity(String sha);

  /// No description provided for @treeIdentity.
  ///
  /// In en, this message translates to:
  /// **'Tree {sha}'**
  String treeIdentity(String sha);

  /// No description provided for @contentIdentity.
  ///
  /// In en, this message translates to:
  /// **'Content {digest}'**
  String contentIdentity(String digest);

  /// No description provided for @trustDoesNotProveSafety.
  ///
  /// In en, this message translates to:
  /// **'Publisher trust verifies ownership or maintenance; it does not certify artifact safety. Risk is assessed separately for this immutable version.'**
  String get trustDoesNotProveSafety;

  /// No description provided for @knownInstallationTargets.
  ///
  /// In en, this message translates to:
  /// **'Known installation targets'**
  String get knownInstallationTargets;

  /// No description provided for @installationRange.
  ///
  /// In en, this message translates to:
  /// **'Installed scope'**
  String get installationRange;

  /// No description provided for @targetDetails.
  ///
  /// In en, this message translates to:
  /// **'Show target details'**
  String get targetDetails;

  /// No description provided for @hideTargetDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide target details'**
  String get hideTargetDetails;

  /// No description provided for @installedVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String installedVersionLabel(String version);

  /// No description provided for @targetSummary.
  ///
  /// In en, this message translates to:
  /// **'{scope} / {agent} · {version}'**
  String targetSummary(String scope, String agent, String version);

  /// No description provided for @projectScope.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get projectScope;

  /// No description provided for @fileContentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Binary or unavailable preview'**
  String get fileContentUnavailable;

  /// No description provided for @fileContentTruncated.
  ///
  /// In en, this message translates to:
  /// **'Preview truncated by the Hub safety limit.'**
  String get fileContentTruncated;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @backToSearch.
  ///
  /// In en, this message translates to:
  /// **'Back to search'**
  String get backToSearch;

  /// No description provided for @installForCodex.
  ///
  /// In en, this message translates to:
  /// **'Install for Codex'**
  String get installForCodex;

  /// No description provided for @cliNotDetected.
  ///
  /// In en, this message translates to:
  /// **'skills (not detected)'**
  String get cliNotDetected;

  /// No description provided for @snapshotFiles.
  ///
  /// In en, this message translates to:
  /// **'Snapshot files'**
  String get snapshotFiles;

  /// No description provided for @globalCodex.
  ///
  /// In en, this message translates to:
  /// **'Global · Codex'**
  String get globalCodex;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'What you know is all here.'**
  String get yourLibrary;

  /// No description provided for @libraryNavigation.
  ///
  /// In en, this message translates to:
  /// **'Library navigation'**
  String get libraryNavigation;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allSkills.
  ///
  /// In en, this message translates to:
  /// **'All Skills'**
  String get allSkills;

  /// No description provided for @updatesOnly.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updatesOnly;

  /// No description provided for @allAgents.
  ///
  /// In en, this message translates to:
  /// **'All Agents'**
  String get allAgents;

  /// No description provided for @allProjects.
  ///
  /// In en, this message translates to:
  /// **'All Projects'**
  String get allProjects;

  /// No description provided for @specificProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get specificProject;

  /// No description provided for @userScope.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get userScope;

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get addProject;

  /// No description provided for @relocateProject.
  ///
  /// In en, this message translates to:
  /// **'Relocate'**
  String get relocateProject;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from List'**
  String get removeFromList;

  /// No description provided for @removeProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from SkillsGo?'**
  String removeProjectTitle(String name);

  /// No description provided for @removeProjectDescription.
  ///
  /// In en, this message translates to:
  /// **'Only the App reference will be removed. SkillsGo will not change or delete any files in this directory.'**
  String get removeProjectDescription;

  /// No description provided for @projectRailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{name} — unavailable'**
  String projectRailUnavailable(String name);

  /// No description provided for @emptyProjectTitle.
  ///
  /// In en, this message translates to:
  /// **'No Skills yet'**
  String get emptyProjectTitle;

  /// No description provided for @browseSkills.
  ///
  /// In en, this message translates to:
  /// **'Browse Skills'**
  String get browseSkills;

  /// No description provided for @projectMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Project directory is missing'**
  String get projectMissingTitle;

  /// No description provided for @projectMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'The directory may have moved or its volume may be offline. Relocate it or remove only its App reference.'**
  String get projectMissingMessage;

  /// No description provided for @projectPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Project permission is required'**
  String get projectPermissionTitle;

  /// No description provided for @projectPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo cannot inspect this selected root. Grant access by relocating it through the directory picker.'**
  String get projectPermissionMessage;

  /// No description provided for @projectInaccessibleTitle.
  ///
  /// In en, this message translates to:
  /// **'Project directory is inaccessible'**
  String get projectInaccessibleTitle;

  /// No description provided for @projectInaccessibleMessage.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo kept this project reference. Check the path or volume, then relocate it.'**
  String get projectInaccessibleMessage;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check updates'**
  String get checkUpdates;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @libraryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Library unavailable'**
  String get libraryUnavailable;

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No skills installed yet'**
  String get libraryEmpty;

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Install a Skill from Discover and it will appear here.'**
  String get libraryEmptyMessage;

  /// No description provided for @searchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search installed skills'**
  String get searchLibrary;

  /// No description provided for @libraryNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching Skills'**
  String get libraryNoMatches;

  /// No description provided for @libraryNoMatchesMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different name, source, Agent, project, or version.'**
  String get libraryNoMatchesMessage;

  /// No description provided for @agentsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} Agents'**
  String agentsSummary(int count);

  /// No description provided for @projectsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} projects'**
  String projectsSummary(int count);

  /// No description provided for @versionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} versions'**
  String versionsSummary(int count);

  /// No description provided for @hubManaged.
  ///
  /// In en, this message translates to:
  /// **'Hub managed'**
  String get hubManaged;

  /// No description provided for @localManaged.
  ///
  /// In en, this message translates to:
  /// **'Local managed'**
  String get localManaged;

  /// No description provided for @externalInstallation.
  ///
  /// In en, this message translates to:
  /// **'External installation'**
  String get externalInstallation;

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get readOnly;

  /// No description provided for @unversioned.
  ///
  /// In en, this message translates to:
  /// **'Unversioned'**
  String get unversioned;

  /// No description provided for @supportingFiles.
  ///
  /// In en, this message translates to:
  /// **'Supporting files'**
  String get supportingFiles;

  /// No description provided for @versionDivergence.
  ///
  /// In en, this message translates to:
  /// **'Version divergence'**
  String get versionDivergence;

  /// No description provided for @healthHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthHealthy;

  /// No description provided for @healthMissing.
  ///
  /// In en, this message translates to:
  /// **'Target missing'**
  String get healthMissing;

  /// No description provided for @healthReplaced.
  ///
  /// In en, this message translates to:
  /// **'Target replaced'**
  String get healthReplaced;

  /// No description provided for @healthLocalModification.
  ///
  /// In en, this message translates to:
  /// **'Local Modification'**
  String get healthLocalModification;

  /// No description provided for @healthUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Target unreadable'**
  String get healthUnreadable;

  /// No description provided for @healthUndeclared.
  ///
  /// In en, this message translates to:
  /// **'Not declared'**
  String get healthUndeclared;

  /// No description provided for @healthWorkspaceUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Workspace state unreadable'**
  String get healthWorkspaceUnreadable;

  /// No description provided for @healthLockMismatch.
  ///
  /// In en, this message translates to:
  /// **'Lock mismatch'**
  String get healthLockMismatch;

  /// No description provided for @healthUnexpectedPath.
  ///
  /// In en, this message translates to:
  /// **'Unexpected target path'**
  String get healthUnexpectedPath;

  /// No description provided for @modeSymlink.
  ///
  /// In en, this message translates to:
  /// **'Symlink'**
  String get modeSymlink;

  /// No description provided for @modeCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get modeCopy;

  /// No description provided for @modeExternal.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get modeExternal;

  /// No description provided for @notLinked.
  ///
  /// In en, this message translates to:
  /// **'NOT LINKED'**
  String get notLinked;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @backToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to Library'**
  String get backToLibrary;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @manageTargets.
  ///
  /// In en, this message translates to:
  /// **'Manage scope'**
  String get manageTargets;

  /// No description provided for @skillsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String skillsSelected(int count);

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @selectCurrentResults.
  ///
  /// In en, this message translates to:
  /// **'Select current results'**
  String get selectCurrentResults;

  /// No description provided for @clearCurrentResultSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear current result selection'**
  String get clearCurrentResultSelection;

  /// No description provided for @manageTargetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage installation targets'**
  String get manageTargetsTitle;

  /// No description provided for @manageTargetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose an exact action for each target. Unselected targets will not change.'**
  String get manageTargetsDescription;

  /// No description provided for @targetActionsSelected.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} targets selected'**
  String targetActionsSelected(int selected, int total);

  /// No description provided for @repairTarget.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get repairTarget;

  /// No description provided for @confirmRemoveTarget.
  ///
  /// In en, this message translates to:
  /// **'Confirm remove'**
  String get confirmRemoveTarget;

  /// No description provided for @applyTargetActions.
  ///
  /// In en, this message translates to:
  /// **'Apply selected actions'**
  String get applyTargetActions;

  /// No description provided for @managementProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Applying target actions'**
  String get managementProgressTitle;

  /// No description provided for @managementResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Target action results'**
  String get managementResultsTitle;

  /// No description provided for @managementResultSummary.
  ///
  /// In en, this message translates to:
  /// **'{succeeded} succeeded, {failed} failed'**
  String managementResultSummary(int succeeded, int failed);

  /// No description provided for @workspaceOwnershipChanges.
  ///
  /// In en, this message translates to:
  /// **'Selected project actions will update skillsgo.mod and skillsgo.sum.'**
  String get workspaceOwnershipChanges;

  /// No description provided for @targetContentPreserved.
  ///
  /// In en, this message translates to:
  /// **'Current target content will be preserved.'**
  String get targetContentPreserved;

  /// No description provided for @localReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Can’t read this Skill'**
  String get localReadFailed;

  /// No description provided for @localReadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo could not read this installed skill. Check that its folder is available and accessible, then try again.'**
  String get localReadFailedMessage;

  /// No description provided for @localConfiguration.
  ///
  /// In en, this message translates to:
  /// **'SKILLSGO SETTINGS'**
  String get localConfiguration;

  /// No description provided for @settingsNavigation.
  ///
  /// In en, this message translates to:
  /// **'Settings navigation'**
  String get settingsNavigation;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'Personalize'**
  String get general;

  /// No description provided for @agents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agents;

  /// No description provided for @hub.
  ///
  /// In en, this message translates to:
  /// **'Hub'**
  String get hub;

  /// No description provided for @installationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Installation Policy'**
  String get installationPolicy;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @colorScheme.
  ///
  /// In en, this message translates to:
  /// **'Color Scheme'**
  String get colorScheme;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @colorSchemeInspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated Material color roles'**
  String get colorSchemeInspectorTitle;

  /// No description provided for @skillsColorTokensTitle.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo semantic colors'**
  String get skillsColorTokensTitle;

  /// No description provided for @skillsColorTokensDescription.
  ///
  /// In en, this message translates to:
  /// **'Product colors built from Radix Sand and organized with Primer semantics, with Folder as a dedicated spatial hierarchy.'**
  String get skillsColorTokensDescription;

  /// No description provided for @colorSchemeInspectorDescription.
  ///
  /// In en, this message translates to:
  /// **'Preview every non-deprecated ColorScheme token generated from the current seed. Click a color to copy its HEX value.'**
  String get colorSchemeInspectorDescription;

  /// No description provided for @colorSchemePairPreview.
  ///
  /// In en, this message translates to:
  /// **'Semantic pairs'**
  String get colorSchemePairPreview;

  /// No description provided for @colorSchemePairPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Foreground and background roles rendered together to expose contrast and hierarchy.'**
  String get colorSchemePairPreviewDescription;

  /// No description provided for @colorSchemeComponentPreview.
  ///
  /// In en, this message translates to:
  /// **'Component preview'**
  String get colorSchemeComponentPreview;

  /// No description provided for @colorSchemeComponentPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Representative Material controls rendered with this exact preview scheme.'**
  String get colorSchemeComponentPreviewDescription;

  /// No description provided for @colorSchemeSampleTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill card title'**
  String get colorSchemeSampleTitle;

  /// No description provided for @colorSchemeSampleBody.
  ///
  /// In en, this message translates to:
  /// **'Secondary copy uses onSurfaceVariant.'**
  String get colorSchemeSampleBody;

  /// No description provided for @colorSchemeCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get colorSchemeCopied;

  /// No description provided for @colorSchemeSampleGlyphs.
  ///
  /// In en, this message translates to:
  /// **'Aa 123'**
  String get colorSchemeSampleGlyphs;

  /// No description provided for @colorSchemeGroupPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get colorSchemeGroupPrimary;

  /// No description provided for @colorSchemeGroupPrimaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Primary emphasis, containers, and fixed accent roles.'**
  String get colorSchemeGroupPrimaryDescription;

  /// No description provided for @colorSchemeGroupSecondary.
  ///
  /// In en, this message translates to:
  /// **'Secondary'**
  String get colorSchemeGroupSecondary;

  /// No description provided for @colorSchemeGroupSecondaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Supporting emphasis and fixed secondary roles.'**
  String get colorSchemeGroupSecondaryDescription;

  /// No description provided for @colorSchemeGroupTertiary.
  ///
  /// In en, this message translates to:
  /// **'Tertiary'**
  String get colorSchemeGroupTertiary;

  /// No description provided for @colorSchemeGroupTertiaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Contrasting accents and fixed tertiary roles.'**
  String get colorSchemeGroupTertiaryDescription;

  /// No description provided for @colorSchemeGroupSurface.
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get colorSchemeGroupSurface;

  /// No description provided for @colorSchemeGroupSurfaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Page, container, elevation, and foreground hierarchy.'**
  String get colorSchemeGroupSurfaceDescription;

  /// No description provided for @colorSchemeGroupUtility.
  ///
  /// In en, this message translates to:
  /// **'Outline & Utility'**
  String get colorSchemeGroupUtility;

  /// No description provided for @colorSchemeGroupUtilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Boundaries, shadows, scrims, and inverse surfaces.'**
  String get colorSchemeGroupUtilityDescription;

  /// No description provided for @colorSchemeGroupError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get colorSchemeGroupError;

  /// No description provided for @colorSchemeGroupErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Error actions, messages, and containers.'**
  String get colorSchemeGroupErrorDescription;

  /// No description provided for @colorSchemeUsagePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary actions, focus, and high-emphasis accents.'**
  String get colorSchemeUsagePrimary;

  /// No description provided for @colorSchemeUsageSecondary.
  ///
  /// In en, this message translates to:
  /// **'Supporting actions and medium-emphasis accents.'**
  String get colorSchemeUsageSecondary;

  /// No description provided for @colorSchemeUsageTertiary.
  ///
  /// In en, this message translates to:
  /// **'Contrasting accents that complement primary and secondary.'**
  String get colorSchemeUsageTertiary;

  /// No description provided for @colorSchemeUsageContentOn.
  ///
  /// In en, this message translates to:
  /// **'Text and icons displayed on {token}.'**
  String colorSchemeUsageContentOn(String token);

  /// No description provided for @colorSchemeUsageContainer.
  ///
  /// In en, this message translates to:
  /// **'Lower-emphasis {family} container for selections and accents.'**
  String colorSchemeUsageContainer(String family);

  /// No description provided for @colorSchemeUsageFixed.
  ///
  /// In en, this message translates to:
  /// **'Brightness-independent fixed {family} container.'**
  String colorSchemeUsageFixed(String family);

  /// No description provided for @colorSchemeUsageFixedDim.
  ///
  /// In en, this message translates to:
  /// **'Dimmed brightness-independent fixed {family} container.'**
  String colorSchemeUsageFixedDim(String family);

  /// No description provided for @colorSchemeUsageFixedContent.
  ///
  /// In en, this message translates to:
  /// **'High-emphasis content on the fixed {family} container.'**
  String colorSchemeUsageFixedContent(String family);

  /// No description provided for @colorSchemeUsageFixedVariantContent.
  ///
  /// In en, this message translates to:
  /// **'Lower-emphasis content on the fixed {family} container.'**
  String colorSchemeUsageFixedVariantContent(String family);

  /// No description provided for @colorSchemeUsageSurface.
  ///
  /// In en, this message translates to:
  /// **'Base page and large-region surface.'**
  String get colorSchemeUsageSurface;

  /// No description provided for @colorSchemeUsageSurfaceDim.
  ///
  /// In en, this message translates to:
  /// **'Dimmed base surface used at the darkest surface tone.'**
  String get colorSchemeUsageSurfaceDim;

  /// No description provided for @colorSchemeUsageSurfaceBright.
  ///
  /// In en, this message translates to:
  /// **'Bright base surface used at the lightest surface tone.'**
  String get colorSchemeUsageSurfaceBright;

  /// No description provided for @colorSchemeUsageSurfaceElevation.
  ///
  /// In en, this message translates to:
  /// **'The {level} surface-container elevation.'**
  String colorSchemeUsageSurfaceElevation(String level);

  /// No description provided for @colorSchemeElevationLowest.
  ///
  /// In en, this message translates to:
  /// **'lowest'**
  String get colorSchemeElevationLowest;

  /// No description provided for @colorSchemeElevationLow.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get colorSchemeElevationLow;

  /// No description provided for @colorSchemeElevationDefault.
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get colorSchemeElevationDefault;

  /// No description provided for @colorSchemeElevationHigh.
  ///
  /// In en, this message translates to:
  /// **'high'**
  String get colorSchemeElevationHigh;

  /// No description provided for @colorSchemeElevationHighest.
  ///
  /// In en, this message translates to:
  /// **'highest'**
  String get colorSchemeElevationHighest;

  /// No description provided for @colorSchemeUsageOnSurface.
  ///
  /// In en, this message translates to:
  /// **'Primary text and icons displayed on surfaces.'**
  String get colorSchemeUsageOnSurface;

  /// No description provided for @colorSchemeUsageOnSurfaceVariant.
  ///
  /// In en, this message translates to:
  /// **'Secondary text, labels, and subdued icons on surfaces.'**
  String get colorSchemeUsageOnSurfaceVariant;

  /// No description provided for @colorSchemeUsageSurfaceTint.
  ///
  /// In en, this message translates to:
  /// **'Material elevation tint derived from primary.'**
  String get colorSchemeUsageSurfaceTint;

  /// No description provided for @colorSchemeUsageOutline.
  ///
  /// In en, this message translates to:
  /// **'Prominent boundaries and focused component outlines.'**
  String get colorSchemeUsageOutline;

  /// No description provided for @colorSchemeUsageOutlineVariant.
  ///
  /// In en, this message translates to:
  /// **'Subtle boundaries, separators, and low-emphasis outlines.'**
  String get colorSchemeUsageOutlineVariant;

  /// No description provided for @colorSchemeUsageShadow.
  ///
  /// In en, this message translates to:
  /// **'Drop-shadow color for elevated surfaces.'**
  String get colorSchemeUsageShadow;

  /// No description provided for @colorSchemeUsageScrim.
  ///
  /// In en, this message translates to:
  /// **'Modal overlay used to de-emphasize background content.'**
  String get colorSchemeUsageScrim;

  /// No description provided for @colorSchemeUsageInverseSurface.
  ///
  /// In en, this message translates to:
  /// **'Surface with reversed light and dark emphasis.'**
  String get colorSchemeUsageInverseSurface;

  /// No description provided for @colorSchemeUsageInversePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary accent displayed on an inverse surface.'**
  String get colorSchemeUsageInversePrimary;

  /// No description provided for @colorSchemeUsageError.
  ///
  /// In en, this message translates to:
  /// **'Error actions, status, and high-emphasis feedback.'**
  String get colorSchemeUsageError;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSettings;

  /// No description provided for @remindersSettings.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersSettings;

  /// No description provided for @remindersSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder settings'**
  String get remindersSettingsTitle;

  /// No description provided for @remindersSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which reminders to receive.'**
  String get remindersSettingsDescription;

  /// No description provided for @updateReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Update reminders'**
  String get updateReminderTitle;

  /// No description provided for @updateReminderDescription.
  ///
  /// In en, this message translates to:
  /// **'Check for updates when Library opens.'**
  String get updateReminderDescription;

  /// No description provided for @securityReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'High-risk alerts'**
  String get securityReminderTitle;

  /// No description provided for @securityReminderDescription.
  ///
  /// In en, this message translates to:
  /// **'Notify you of new High or Critical risks in installed skills.'**
  String get securityReminderDescription;

  /// No description provided for @availableUpdatesReminder.
  ///
  /// In en, this message translates to:
  /// **'{count} installed skills have updates'**
  String availableUpdatesReminder(int count);

  /// No description provided for @openAvailableUpdates.
  ///
  /// In en, this message translates to:
  /// **'Open the available-updates view to review and update them.'**
  String get openAvailableUpdates;

  /// No description provided for @securityAdvisoriesReminder.
  ///
  /// In en, this message translates to:
  /// **'{count} installed skills need a security review'**
  String securityAdvisoriesReminder(int count);

  /// No description provided for @reviewInstalledSkills.
  ///
  /// In en, this message translates to:
  /// **'Review their risk information before using or updating them.'**
  String get reviewInstalledSkills;

  /// No description provided for @generalSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Make SkillsGo yours'**
  String get generalSettingsTitle;

  /// No description provided for @generalSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'The interface follows your system language, accessibility, and motion preferences.'**
  String get generalSettingsDescription;

  /// No description provided for @agentsSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent runtime'**
  String get agentsSettingsTitle;

  /// No description provided for @hubSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hub Origin'**
  String get hubSettingsTitle;

  /// No description provided for @hubSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the official Hub or an HTTP(S) self-hosted origin that implements the same SkillsGo protocol.'**
  String get hubSettingsDescription;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @saveOrigin.
  ///
  /// In en, this message translates to:
  /// **'Save Origin'**
  String get saveOrigin;

  /// No description provided for @resetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetDefault;

  /// No description provided for @connectionReady.
  ///
  /// In en, this message translates to:
  /// **'Connection ready'**
  String get connectionReady;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @hubInvalidOrigin.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP(S) Origin without credentials, a query, or a fragment.'**
  String get hubInvalidOrigin;

  /// No description provided for @hubHttpFailure.
  ///
  /// In en, this message translates to:
  /// **'Hub returned HTTP {status}. Check the Origin and server configuration.'**
  String hubHttpFailure(int status);

  /// No description provided for @hubInvalidProtocol.
  ///
  /// In en, this message translates to:
  /// **'The server did not return the SkillsGo Hub search protocol.'**
  String get hubInvalidProtocol;

  /// No description provided for @hubInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'The Hub returned invalid JSON.'**
  String get hubInvalidJson;

  /// No description provided for @hubConnectionFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the Hub. Check the Origin, network, proxy, and TLS configuration.'**
  String get hubConnectionFailure;

  /// No description provided for @hubConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'The Hub connection timed out. Check the network or try again.'**
  String get hubConnectionTimeout;

  /// No description provided for @riskPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal risk policy'**
  String get riskPolicyTitle;

  /// No description provided for @riskPolicyDescription.
  ///
  /// In en, this message translates to:
  /// **'Safety rules apply when you install or update a skill.'**
  String get riskPolicyDescription;

  /// No description provided for @confirmHighRisk.
  ///
  /// In en, this message translates to:
  /// **'Require confirmation for High risk'**
  String get confirmHighRisk;

  /// No description provided for @confirmHighRiskDescription.
  ///
  /// In en, this message translates to:
  /// **'High-risk artifacts always require an additional confirmation before installation.'**
  String get confirmHighRiskDescription;

  /// No description provided for @allowCriticalOverride.
  ///
  /// In en, this message translates to:
  /// **'Allow an explicit Critical-risk override'**
  String get allowCriticalOverride;

  /// No description provided for @allowCriticalOverrideDescription.
  ///
  /// In en, this message translates to:
  /// **'Critical-risk artifacts remain blocked by default. Enable this only to expose a separate manual override.'**
  String get allowCriticalOverrideDescription;

  /// No description provided for @storageSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Content-addressed Store'**
  String get storageSettingsTitle;

  /// No description provided for @storageHealthy.
  ///
  /// In en, this message translates to:
  /// **'Readable'**
  String get storageHealthy;

  /// No description provided for @storageNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'Not initialized'**
  String get storageNotInitialized;

  /// No description provided for @storageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get storageUnavailable;

  /// No description provided for @storagePathUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store path unavailable until CLI diagnostics are ready.'**
  String get storagePathUnavailable;

  /// No description provided for @storageHealthyDescription.
  ///
  /// In en, this message translates to:
  /// **'The CLI can read the Store without changing its contents.'**
  String get storageHealthyDescription;

  /// No description provided for @storageNotInitializedDescription.
  ///
  /// In en, this message translates to:
  /// **'The Store does not exist yet and was not created by this check.'**
  String get storageNotInitializedDescription;

  /// No description provided for @storageUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'The CLI cannot read the Store. Check its permissions and parent directory.'**
  String get storageUnavailableDescription;

  /// No description provided for @storageInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The bundled CLI returned an unsupported diagnostics response.'**
  String get storageInvalidResponse;

  /// No description provided for @aboutSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Product compatibility'**
  String get aboutSettingsTitle;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @cliVersion.
  ///
  /// In en, this message translates to:
  /// **'Bundled CLI version'**
  String get cliVersion;

  /// No description provided for @compatible.
  ///
  /// In en, this message translates to:
  /// **'Compatible'**
  String get compatible;

  /// No description provided for @hubOriginSaved.
  ///
  /// In en, this message translates to:
  /// **'Hub Origin saved and applied.'**
  String get hubOriginSaved;

  /// No description provided for @policySaved.
  ///
  /// In en, this message translates to:
  /// **'Installation policy saved.'**
  String get policySaved;

  /// No description provided for @officialCli.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo CLI'**
  String get officialCli;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get ready;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'UNKNOWN'**
  String get unknown;

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'MISSING'**
  String get missing;

  /// No description provided for @incompatible.
  ///
  /// In en, this message translates to:
  /// **'INCOMPATIBLE'**
  String get incompatible;

  /// No description provided for @detecting.
  ///
  /// In en, this message translates to:
  /// **'Detecting…'**
  String get detecting;

  /// No description provided for @customCliPath.
  ///
  /// In en, this message translates to:
  /// **'Custom executable path'**
  String get customCliPath;

  /// No description provided for @saveAndDetect.
  ///
  /// In en, this message translates to:
  /// **'Save & detect'**
  String get saveAndDetect;

  /// No description provided for @detectAgain.
  ///
  /// In en, this message translates to:
  /// **'Detect again'**
  String get detectAgain;

  /// No description provided for @agentInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get agentInstalled;

  /// No description provided for @agentSupported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get agentSupported;

  /// No description provided for @agentCatalogSummary.
  ///
  /// In en, this message translates to:
  /// **'{installed} installed · {supported} supported'**
  String agentCatalogSummary(int installed, int supported);

  /// No description provided for @installedAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Installed · {count}'**
  String installedAgentsTitle(int count);

  /// No description provided for @notInstalledAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Not installed · {count}'**
  String notInstalledAgentsTitle(int count);

  /// No description provided for @notInstalledAgentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Supported by SkillsGo, but not detected on this Mac.'**
  String get notInstalledAgentsDescription;

  /// No description provided for @agentDiscoveryRoots.
  ///
  /// In en, this message translates to:
  /// **'Skill loading paths: {paths}'**
  String agentDiscoveryRoots(String paths);

  /// No description provided for @agentInspectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Agent detection data is unavailable. Run detection again.'**
  String get agentInspectionFailed;

  /// No description provided for @noInstalledAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'No installed Agents detected'**
  String get noInstalledAgentsTitle;

  /// No description provided for @noInstalledAgentsMessage.
  ///
  /// In en, this message translates to:
  /// **'You can keep browsing this Skill, but there is no installation target yet. Install a supported Agent, then run detection again.'**
  String get noInstalledAgentsMessage;

  /// No description provided for @clearCustomPath.
  ///
  /// In en, this message translates to:
  /// **'Clear custom path'**
  String get clearCustomPath;

  /// No description provided for @privacyProvenance.
  ///
  /// In en, this message translates to:
  /// **'Privacy & provenance'**
  String get privacyProvenance;

  /// No description provided for @privacySummary.
  ///
  /// In en, this message translates to:
  /// **'Your searches aren’t saved, and SkillsGo doesn’t keep command logs.'**
  String get privacySummary;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @personalizationTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get personalizationTheme;

  /// No description provided for @folderColorTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get folderColorTheme;

  /// No description provided for @folderColorThemeDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick a color you like. SkillsGo will build a coordinated interface palette around it.'**
  String get folderColorThemeDescription;

  /// No description provided for @brandNameNeteaseCloudMusic.
  ///
  /// In en, this message translates to:
  /// **'NetEase Cloud Music'**
  String get brandNameNeteaseCloudMusic;

  /// No description provided for @brandNameRaspberryPi.
  ///
  /// In en, this message translates to:
  /// **'Raspberry Pi'**
  String get brandNameRaspberryPi;

  /// No description provided for @brandNameChinaEasternAirlines.
  ///
  /// In en, this message translates to:
  /// **'China Eastern Airlines'**
  String get brandNameChinaEasternAirlines;

  /// No description provided for @brandNameNvidia.
  ///
  /// In en, this message translates to:
  /// **'NVIDIA'**
  String get brandNameNvidia;

  /// No description provided for @brandNameTaobao.
  ///
  /// In en, this message translates to:
  /// **'Taobao'**
  String get brandNameTaobao;

  /// No description provided for @brandNameBitcoin.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get brandNameBitcoin;

  /// No description provided for @appearanceMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get appearanceMode;

  /// No description provided for @appearanceModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow your system appearance, or always use a light or dark theme.'**
  String get appearanceModeDescription;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get followSystem;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @wallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get wallpaper;

  /// No description provided for @wallpaperDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a celestial background. Your selection appears immediately behind Folder.'**
  String get wallpaperDescription;

  /// No description provided for @wallpaperSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get wallpaperSun;

  /// No description provided for @wallpaperMercury.
  ///
  /// In en, this message translates to:
  /// **'Mercury'**
  String get wallpaperMercury;

  /// No description provided for @wallpaperVenus.
  ///
  /// In en, this message translates to:
  /// **'Venus'**
  String get wallpaperVenus;

  /// No description provided for @wallpaperEarth.
  ///
  /// In en, this message translates to:
  /// **'Earth'**
  String get wallpaperEarth;

  /// No description provided for @wallpaperMars.
  ///
  /// In en, this message translates to:
  /// **'Mars'**
  String get wallpaperMars;

  /// No description provided for @wallpaperJupiter.
  ///
  /// In en, this message translates to:
  /// **'Jupiter'**
  String get wallpaperJupiter;

  /// No description provided for @wallpaperSaturn.
  ///
  /// In en, this message translates to:
  /// **'Saturn'**
  String get wallpaperSaturn;

  /// No description provided for @wallpaperUranus.
  ///
  /// In en, this message translates to:
  /// **'Uranus'**
  String get wallpaperUranus;

  /// No description provided for @wallpaperNeptune.
  ///
  /// In en, this message translates to:
  /// **'Neptune'**
  String get wallpaperNeptune;

  /// No description provided for @wallpaperPluto.
  ///
  /// In en, this message translates to:
  /// **'Pluto'**
  String get wallpaperPluto;

  /// No description provided for @wallpaperMoon.
  ///
  /// In en, this message translates to:
  /// **'Moon'**
  String get wallpaperMoon;

  /// No description provided for @folderThemeChoice.
  ///
  /// In en, this message translates to:
  /// **'{theme} Folder theme'**
  String folderThemeChoice(String theme);

  /// No description provided for @privacyAffiliation.
  ///
  /// In en, this message translates to:
  /// **'Anonymous installation telemetry is controlled by SkillsGo settings. SkillsGo is not affiliated with OpenAI or Codex.'**
  String get privacyAffiliation;

  /// No description provided for @commandCompleted.
  ///
  /// In en, this message translates to:
  /// **'Command completed'**
  String get commandCompleted;

  /// No description provided for @commandFailed.
  ///
  /// In en, this message translates to:
  /// **'Command failed'**
  String get commandFailed;

  /// No description provided for @commandExit.
  ///
  /// In en, this message translates to:
  /// **'Exit {code} · expand for this session’s log'**
  String commandExit(int code);

  /// No description provided for @command.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get command;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @updateUnknown.
  ///
  /// In en, this message translates to:
  /// **'UNKNOWN'**
  String get updateUnknown;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'CHECKING'**
  String get updateChecking;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'UP TO DATE'**
  String get upToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get updateAvailable;

  /// No description provided for @updateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'UNAVAILABLE'**
  String get updateUnavailable;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'CHECK FAILED'**
  String get updateCheckFailed;

  /// No description provided for @installSkill.
  ///
  /// In en, this message translates to:
  /// **'Install Skill'**
  String get installSkill;

  /// No description provided for @installLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Set installation location'**
  String get installLocationTitle;

  /// No description provided for @userLevel.
  ///
  /// In en, this message translates to:
  /// **'User Level'**
  String get userLevel;

  /// No description provided for @projectLevel.
  ///
  /// In en, this message translates to:
  /// **'Project Level'**
  String get projectLevel;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @repositoryParsing.
  ///
  /// In en, this message translates to:
  /// **'Parsing Repository…'**
  String get repositoryParsing;

  /// No description provided for @userInstallSummary.
  ///
  /// In en, this message translates to:
  /// **'Available to {agents} Agents at user level'**
  String userInstallSummary(int agents);

  /// No description provided for @projectInstallSummary.
  ///
  /// In en, this message translates to:
  /// **'{projects} projects · {agents} Agents'**
  String projectInstallSummary(int projects, int agents);

  /// No description provided for @installationResults.
  ///
  /// In en, this message translates to:
  /// **'Installation results'**
  String get installationResults;

  /// No description provided for @installationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Installation in progress'**
  String get installationInProgress;

  /// No description provided for @installationSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Installation complete'**
  String get installationSucceeded;

  /// No description provided for @installationSucceededMessage.
  ///
  /// In en, this message translates to:
  /// **'The Skill is now available in the selected locations.'**
  String get installationSucceededMessage;

  /// No description provided for @projectUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Project unavailable'**
  String get projectUnavailable;

  /// No description provided for @installedCell.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installedCell;

  /// No description provided for @unsupportedCell.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unsupportedCell;

  /// No description provided for @confirmInstall.
  ///
  /// In en, this message translates to:
  /// **'Confirm Installation'**
  String get confirmInstall;

  /// No description provided for @installAllRepositorySkills.
  ///
  /// In en, this message translates to:
  /// **'Install all repository skills ({count})'**
  String installAllRepositorySkills(int count);

  /// No description provided for @installAllSkillsTo.
  ///
  /// In en, this message translates to:
  /// **'Install all skills to'**
  String get installAllSkillsTo;

  /// No description provided for @installRepositorySkills.
  ///
  /// In en, this message translates to:
  /// **'Install all {repository} skills ({count})'**
  String installRepositorySkills(String repository, int count);

  /// No description provided for @installSkillTo.
  ///
  /// In en, this message translates to:
  /// **'Install {skill} to'**
  String installSkillTo(String skill);

  /// No description provided for @availableInAllProjects.
  ///
  /// In en, this message translates to:
  /// **'All projects'**
  String get availableInAllProjects;

  /// No description provided for @availableInSelectedProjects.
  ///
  /// In en, this message translates to:
  /// **'Selected projects'**
  String get availableInSelectedProjects;

  /// No description provided for @usedBy.
  ///
  /// In en, this message translates to:
  /// **'For Agents'**
  String get usedBy;

  /// No description provided for @backToTargets.
  ///
  /// In en, this message translates to:
  /// **'Back to Targets'**
  String get backToTargets;

  /// No description provided for @stayHere.
  ///
  /// In en, this message translates to:
  /// **'Stay Here'**
  String get stayHere;

  /// No description provided for @viewInLibrary.
  ///
  /// In en, this message translates to:
  /// **'View in Library'**
  String get viewInLibrary;

  /// No description provided for @planCreateCount.
  ///
  /// In en, this message translates to:
  /// **'{count} create'**
  String planCreateCount(int count);

  /// No description provided for @planSkipCount.
  ///
  /// In en, this message translates to:
  /// **'{count} skip'**
  String planSkipCount(int count);

  /// No description provided for @planReplaceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} replace'**
  String planReplaceCount(int count);

  /// No description provided for @planConflictCount.
  ///
  /// In en, this message translates to:
  /// **'{count} conflict'**
  String planConflictCount(int count);

  /// No description provided for @planRiskCount.
  ///
  /// In en, this message translates to:
  /// **'{count} risk blocked'**
  String planRiskCount(int count);

  /// No description provided for @refreshInstallationPlan.
  ///
  /// In en, this message translates to:
  /// **'Apply Resolutions'**
  String get refreshInstallationPlan;

  /// No description provided for @replaceVersionConflict.
  ///
  /// In en, this message translates to:
  /// **'Replace the installed version at this target'**
  String get replaceVersionConflict;

  /// No description provided for @replaceSkillIdCollision.
  ///
  /// In en, this message translates to:
  /// **'Replace the different Skill ID at this target'**
  String get replaceSkillIdCollision;

  /// No description provided for @replaceLocalModification.
  ///
  /// In en, this message translates to:
  /// **'Discard Local Modifications and replace this target'**
  String get replaceLocalModification;

  /// No description provided for @sharedTargetConflict.
  ///
  /// In en, this message translates to:
  /// **'This path is shared by other Agent targets'**
  String get sharedTargetConflict;

  /// No description provided for @sharedTargetConflictDescription.
  ///
  /// In en, this message translates to:
  /// **'Return to the target matrix and select every affected Agent before replacing: {agents}'**
  String sharedTargetConflictDescription(String agents);

  /// No description provided for @replaceConflictingTarget.
  ///
  /// In en, this message translates to:
  /// **'Replace the conflicting target'**
  String get replaceConflictingTarget;

  /// No description provided for @confirmHighRiskArtifact.
  ///
  /// In en, this message translates to:
  /// **'High-risk artifact confirmation'**
  String get confirmHighRiskArtifact;

  /// No description provided for @confirmCriticalRiskArtifact.
  ///
  /// In en, this message translates to:
  /// **'Critical-risk override confirmation'**
  String get confirmCriticalRiskArtifact;

  /// No description provided for @confirmRiskForSelectedTargets.
  ///
  /// In en, this message translates to:
  /// **'I reviewed the artifact files and accept this risk for the selected targets'**
  String get confirmRiskForSelectedTargets;

  /// No description provided for @criticalRiskBlocked.
  ///
  /// In en, this message translates to:
  /// **'Critical-risk installation is blocked'**
  String get criticalRiskBlocked;

  /// No description provided for @criticalRiskOverrideDisabled.
  ///
  /// In en, this message translates to:
  /// **'Enable the explicit Critical-risk override in Settings before this plan can continue.'**
  String get criticalRiskOverrideDisabled;

  /// No description provided for @workspaceManifestChanges.
  ///
  /// In en, this message translates to:
  /// **'Workspace Manifest changes'**
  String get workspaceManifestChanges;

  /// No description provided for @noWorkspaceManifestChanges.
  ///
  /// In en, this message translates to:
  /// **'No Workspace Manifest files will change.'**
  String get noWorkspaceManifestChanges;

  /// No description provided for @lockVersionChange.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String lockVersionChange(String from, String to);

  /// No description provided for @notPresent.
  ///
  /// In en, this message translates to:
  /// **'not present'**
  String get notPresent;

  /// No description provided for @planActionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get planActionCreate;

  /// No description provided for @planActionReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get planActionReplace;

  /// No description provided for @planActionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get planActionSkip;

  /// No description provided for @planActionConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get planActionConflict;

  /// No description provided for @planActionBlockedByRisk.
  ///
  /// In en, this message translates to:
  /// **'Blocked by risk'**
  String get planActionBlockedByRisk;

  /// No description provided for @installationResultSummary.
  ///
  /// In en, this message translates to:
  /// **'{succeeded} targets installed, {failed} failed'**
  String installationResultSummary(int succeeded, int failed);

  /// No description provided for @installationProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Installation in progress'**
  String get installationProgressTitle;

  /// No description provided for @installationProgressSummary.
  ///
  /// In en, this message translates to:
  /// **'{finished} of {total} targets finished'**
  String installationProgressSummary(int finished, int total);

  /// No description provided for @targetWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get targetWaiting;

  /// No description provided for @targetRunning.
  ///
  /// In en, this message translates to:
  /// **'Installing'**
  String get targetRunning;

  /// No description provided for @retryFailedTargets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Retry 1 Failed Target} other{Retry {count} Failed Targets}}'**
  String retryFailedTargets(int count);

  /// No description provided for @updatePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Select targets to update'**
  String get updatePlanTitle;

  /// No description provided for @updatePlanDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose exact Installation Targets. Unselected Agents and projects remain unchanged.'**
  String get updatePlanDescription;

  /// No description provided for @updateTargetsSelected.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {available} updateable targets selected'**
  String updateTargetsSelected(int selected, int available);

  /// No description provided for @updateVersionChange.
  ///
  /// In en, this message translates to:
  /// **'{fromVersion} → {toVersion}'**
  String updateVersionChange(String fromVersion, String toVersion);

  /// No description provided for @sourceReference.
  ///
  /// In en, this message translates to:
  /// **'Source reference: {reference}'**
  String sourceReference(String reference);

  /// No description provided for @fixedVersionTarget.
  ///
  /// In en, this message translates to:
  /// **'Pinned — no movable reference'**
  String get fixedVersionTarget;

  /// No description provided for @currentVersionTarget.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get currentVersionTarget;

  /// No description provided for @updateCheckTargetFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get updateCheckTargetFailed;

  /// No description provided for @reconcileWorkspaceManifestTarget.
  ///
  /// In en, this message translates to:
  /// **'Repair workspace manifest'**
  String get reconcileWorkspaceManifestTarget;

  /// No description provided for @updateSelectedTargets.
  ///
  /// In en, this message translates to:
  /// **'Update selected targets'**
  String get updateSelectedTargets;

  /// No description provided for @updateProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Updating targets'**
  String get updateProgressTitle;

  /// No description provided for @updateResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Update results'**
  String get updateResultsTitle;

  /// No description provided for @updateProgressSummary.
  ///
  /// In en, this message translates to:
  /// **'{finished} of {total} targets finished'**
  String updateProgressSummary(int finished, int total);

  /// No description provided for @retryFailedUpdates.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Retry 1 Failed Update} other{Retry {count} Failed Updates}}'**
  String retryFailedUpdates(int count);

  /// No description provided for @noUpdateableTargets.
  ///
  /// In en, this message translates to:
  /// **'No selected target has an available update.'**
  String get noUpdateableTargets;

  /// No description provided for @closeUpdatePlan.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeUpdatePlan;

  /// No description provided for @targetSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get targetSucceeded;

  /// No description provided for @targetSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get targetSkipped;

  /// No description provided for @targetConflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get targetConflict;

  /// No description provided for @targetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get targetFailed;

  /// No description provided for @targetFailureRetryable.
  ///
  /// In en, this message translates to:
  /// **'This location could not be changed. You can try again.'**
  String get targetFailureRetryable;

  /// No description provided for @targetFailureNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'This location needs your attention before you try again.'**
  String get targetFailureNeedsAttention;

  /// No description provided for @installationTargetFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed at this location. Check that the folder is available and try again.'**
  String get installationTargetFailureMessage;

  /// No description provided for @workspacePersistenceFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed because SkillsGo could not save the project settings. Check that the project folder is writable and try again.'**
  String get workspacePersistenceFailureMessage;

  /// No description provided for @installationStateChangedMessage.
  ///
  /// In en, this message translates to:
  /// **'This location changed while you were reviewing it. Review the latest state before trying again.'**
  String get installationStateChangedMessage;

  /// No description provided for @updateTargetFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'This location could not be updated. Other locations were not affected, so you can retry only this one.'**
  String get updateTargetFailureMessage;

  /// No description provided for @managementTargetFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'This action could not be completed here. Other locations were not affected, so you can retry only this one.'**
  String get managementTargetFailureMessage;

  /// No description provided for @technicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get technicalDetails;

  /// No description provided for @targetPathExists.
  ///
  /// In en, this message translates to:
  /// **'Another item already exists at this location.'**
  String get targetPathExists;

  /// No description provided for @targetBlockedByRisk.
  ///
  /// In en, this message translates to:
  /// **'Your current safety settings blocked installation at this location.'**
  String get targetBlockedByRisk;

  /// No description provided for @targetInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'The skill could not be installed at this location.'**
  String get targetInstallFailed;

  /// No description provided for @targetWorkspaceUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'The skill was installed, but the project settings could not be updated.'**
  String get targetWorkspaceUpdateFailed;

  /// No description provided for @installationPlanFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation plan could not continue'**
  String get installationPlanFailed;

  /// No description provided for @installationFailed.
  ///
  /// In en, this message translates to:
  /// **'Installation could not be completed'**
  String get installationFailed;

  /// No description provided for @localSource.
  ///
  /// In en, this message translates to:
  /// **'Local source'**
  String get localSource;

  /// No description provided for @noDescriptionAvailable.
  ///
  /// In en, this message translates to:
  /// **'No description available'**
  String get noDescriptionAvailable;

  /// No description provided for @moreCoverage.
  ///
  /// In en, this message translates to:
  /// **'+{count} more locations'**
  String moreCoverage(int count);

  /// No description provided for @batchTakeoverAction.
  ///
  /// In en, this message translates to:
  /// **'Manage existing skills'**
  String get batchTakeoverAction;

  /// No description provided for @batchTakeoverActionCount.
  ///
  /// In en, this message translates to:
  /// **'Manage ({count})'**
  String batchTakeoverActionCount(int count);

  /// No description provided for @batchTakeoverChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking existing skills…'**
  String get batchTakeoverChecking;

  /// No description provided for @batchTakeoverRetry.
  ///
  /// In en, this message translates to:
  /// **'Check manageable skills again'**
  String get batchTakeoverRetry;

  /// No description provided for @batchTakeoverEligibleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} can be managed'**
  String batchTakeoverEligibleCount(int count);

  /// No description provided for @batchTakeoverPending.
  ///
  /// In en, this message translates to:
  /// **'Adding skills to management…'**
  String get batchTakeoverPending;

  /// No description provided for @batchTakeoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage existing skills with SkillsGo?'**
  String get batchTakeoverTitle;

  /// No description provided for @batchTakeoverDescription.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo will add local management records without moving, overwriting, or uploading skill files. Unsupported or changed items will be skipped.'**
  String get batchTakeoverDescription;

  /// No description provided for @batchTakeoverStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn scattered skills into one clear Library'**
  String get batchTakeoverStoryTitle;

  /// No description provided for @batchTakeoverStoryDescription.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo found {count, plural, =1{1 existing skill} other{{count} existing skills}} it can manage in this location.'**
  String batchTakeoverStoryDescription(int count);

  /// No description provided for @batchTakeoverBeforeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Before management, it is unclear where existing skills are installed, whether they are current, how to recover them, or whether projects use the same version.'**
  String get batchTakeoverBeforeSemantics;

  /// No description provided for @batchTakeoverPainLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown install location'**
  String get batchTakeoverPainLocation;

  /// No description provided for @batchTakeoverPainFreshness.
  ///
  /// In en, this message translates to:
  /// **'Unknown update status'**
  String get batchTakeoverPainFreshness;

  /// No description provided for @batchTakeoverPainRecovery.
  ///
  /// In en, this message translates to:
  /// **'No recovery when broken'**
  String get batchTakeoverPainRecovery;

  /// No description provided for @batchTakeoverPainVersionDrift.
  ///
  /// In en, this message translates to:
  /// **'Different versions across projects'**
  String get batchTakeoverPainVersionDrift;

  /// No description provided for @batchTakeoverFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Existing Skills'**
  String get batchTakeoverFolderTitle;

  /// No description provided for @batchTakeoverFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unclear status'**
  String get batchTakeoverFolderSubtitle;

  /// No description provided for @batchTakeoverAfterLabel.
  ///
  /// In en, this message translates to:
  /// **'AFTER'**
  String get batchTakeoverAfterLabel;

  /// No description provided for @batchTakeoverAfterTitle.
  ///
  /// In en, this message translates to:
  /// **'One clear Library'**
  String get batchTakeoverAfterTitle;

  /// No description provided for @batchTakeoverLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo Library'**
  String get batchTakeoverLibraryTitle;

  /// No description provided for @batchTakeoverBenefitLocation.
  ///
  /// In en, this message translates to:
  /// **'Clear locations'**
  String get batchTakeoverBenefitLocation;

  /// No description provided for @batchTakeoverBenefitFreshness.
  ///
  /// In en, this message translates to:
  /// **'Updates visible'**
  String get batchTakeoverBenefitFreshness;

  /// No description provided for @batchTakeoverBenefitRecovery.
  ///
  /// In en, this message translates to:
  /// **'Easy recovery'**
  String get batchTakeoverBenefitRecovery;

  /// No description provided for @batchTakeoverBenefitVersions.
  ///
  /// In en, this message translates to:
  /// **'Versions clear'**
  String get batchTakeoverBenefitVersions;

  /// No description provided for @batchTakeoverManagedSection.
  ///
  /// In en, this message translates to:
  /// **'Managed by SkillsGo'**
  String get batchTakeoverManagedSection;

  /// No description provided for @batchTakeoverPendingSection.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be managed'**
  String get batchTakeoverPendingSection;

  /// No description provided for @batchTakeoverItemManaged.
  ///
  /// In en, this message translates to:
  /// **'{name} is managed by SkillsGo'**
  String batchTakeoverItemManaged(String name);

  /// No description provided for @batchTakeoverItemSkipped.
  ///
  /// In en, this message translates to:
  /// **'{name} could not be added to management'**
  String batchTakeoverItemSkipped(String name);

  /// No description provided for @batchTakeoverItemPending.
  ///
  /// In en, this message translates to:
  /// **'{name} is waiting to be managed'**
  String batchTakeoverItemPending(String name);

  /// No description provided for @batchTakeoverAfterSemantics.
  ///
  /// In en, this message translates to:
  /// **'After management, {count, plural, =1{1 skill is} other{{count} skills are}} organized in one Library with a clear managed status.'**
  String batchTakeoverAfterSemantics(int count);

  /// No description provided for @batchTakeoverMoreSkills.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String batchTakeoverMoreSkills(int count);

  /// No description provided for @batchTakeoverTransitionSemantics.
  ///
  /// In en, this message translates to:
  /// **'Add these existing skills to SkillsGo management.'**
  String get batchTakeoverTransitionSemantics;

  /// No description provided for @batchTakeoverTransitionLabel.
  ///
  /// In en, this message translates to:
  /// **'ORGANIZE'**
  String get batchTakeoverTransitionLabel;

  /// No description provided for @batchTakeoverPreservation.
  ///
  /// In en, this message translates to:
  /// **'Your files, paths, and current workflows stay exactly where they are. SkillsGo only completes its local management records.'**
  String get batchTakeoverPreservation;

  /// No description provided for @batchTakeoverLaterHint.
  ///
  /// In en, this message translates to:
  /// **'If you skip, you can use Manage existing skills from Library anytime.'**
  String get batchTakeoverLaterHint;

  /// No description provided for @batchTakeoverSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get batchTakeoverSkip;

  /// No description provided for @batchTakeoverConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add to management'**
  String get batchTakeoverConfirm;

  /// No description provided for @batchTakeoverExecutionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get batchTakeoverExecutionRetry;

  /// No description provided for @batchTakeoverResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills added to management'**
  String get batchTakeoverResultTitle;

  /// No description provided for @batchTakeoverSummary.
  ///
  /// In en, this message translates to:
  /// **'{takenOver} skills added to management, {skipped} skipped.'**
  String batchTakeoverSummary(int takenOver, int skipped);

  /// No description provided for @batchTakeoverClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get batchTakeoverClose;

  /// No description provided for @installMoreTargets.
  ///
  /// In en, this message translates to:
  /// **'Install in more locations'**
  String get installMoreTargets;

  /// No description provided for @exportLocalSkill.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportLocalSkill;

  /// No description provided for @exportLocalSkillDescription.
  ///
  /// In en, this message translates to:
  /// **'Export this Local Skill as a portable ZIP archive.'**
  String get exportLocalSkillDescription;

  /// No description provided for @detailInstalls.
  ///
  /// In en, this message translates to:
  /// **'Installs'**
  String get detailInstalls;

  /// No description provided for @detailRepository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get detailRepository;

  /// No description provided for @detailStars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get detailStars;

  /// No description provided for @detailUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get detailUpdated;

  /// No description provided for @detailArchiveSize.
  ///
  /// In en, this message translates to:
  /// **'ZIP Size'**
  String get detailArchiveSize;

  /// No description provided for @pathLabel.
  ///
  /// In en, this message translates to:
  /// **'Project path'**
  String get pathLabel;

  /// No description provided for @copyProjectPath.
  ///
  /// In en, this message translates to:
  /// **'Copy project path'**
  String get copyProjectPath;

  /// No description provided for @projectPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Project path copied'**
  String get projectPathCopied;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to SkillsGo'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Discover, install, and manage Skills across your Agents and projects.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingDetectedAgents.
  ///
  /// In en, this message translates to:
  /// **'Detected Agents'**
  String get onboardingDetectedAgents;

  /// No description provided for @onboardingNoAgents.
  ///
  /// In en, this message translates to:
  /// **'No installed Agents detected. You can still continue.'**
  String get onboardingNoAgents;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingProjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your projects'**
  String get onboardingProjectsTitle;

  /// No description provided for @onboardingProjectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the projects you want SkillsGo to manage.'**
  String get onboardingProjectsDescription;

  /// No description provided for @onboardingAddProject.
  ///
  /// In en, this message translates to:
  /// **'Add now'**
  String get onboardingAddProject;

  /// No description provided for @onboardingAddProjectLater.
  ///
  /// In en, this message translates to:
  /// **'or later'**
  String get onboardingAddProjectLater;

  /// No description provided for @onboardingStartUsing.
  ///
  /// In en, this message translates to:
  /// **'Start Using SkillsGo'**
  String get onboardingStartUsing;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @restartOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get restartOnboardingTitle;

  /// No description provided for @restartOnboardingDescription.
  ///
  /// In en, this message translates to:
  /// **'View the first-launch guide again without removing projects, settings, or Skills data.'**
  String get restartOnboardingDescription;

  /// No description provided for @restartOnboardingAction.
  ///
  /// In en, this message translates to:
  /// **'Restart Onboarding'**
  String get restartOnboardingAction;

  /// No description provided for @restartOnboardingFailed.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo could not restart Onboarding.'**
  String get restartOnboardingFailed;

  /// No description provided for @libraryRefreshSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh local Library'**
  String get libraryRefreshSettingsTitle;

  /// No description provided for @libraryRefreshSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Rescan installed Skills, Added Projects, Agents, and external Skills that can be managed. This does not install, update, or remove anything.'**
  String get libraryRefreshSettingsDescription;

  /// No description provided for @libraryRefreshSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh Library'**
  String get libraryRefreshSettingsAction;

  /// No description provided for @libraryRefreshSettingsPending.
  ///
  /// In en, this message translates to:
  /// **'Refreshing Library…'**
  String get libraryRefreshSettingsPending;

  /// No description provided for @libraryRefreshSettingsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Local Library refreshed.'**
  String get libraryRefreshSettingsSuccess;

  /// No description provided for @libraryRefreshSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo could not refresh the local Library.'**
  String get libraryRefreshSettingsFailed;

  /// No description provided for @onboardingProjectError.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo could not add projects from this directory.'**
  String get onboardingProjectError;

  /// No description provided for @onboardingProjectsLoadError.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo could not load your added projects.'**
  String get onboardingProjectsLoadError;

  /// No description provided for @onboardingStartupError.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo could not load setup.'**
  String get onboardingStartupError;

  /// No description provided for @onboardingStateError.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo could not save your setup progress. Try again.'**
  String get onboardingStateError;

  /// No description provided for @onboardingCliErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo CLI needs attention'**
  String get onboardingCliErrorTitle;

  /// No description provided for @onboardingCliErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Repair the bundled CLI, then retry to continue.'**
  String get onboardingCliErrorDescription;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
