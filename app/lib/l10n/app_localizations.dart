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
  /// **'The SkillsGo CLI needs attention.'**
  String get cliNeedsAttention;

  /// No description provided for @cliMissingBundled.
  ///
  /// In en, this message translates to:
  /// **'The bundled SkillsGo CLI is missing or cannot run. Reinstall SkillsGo.'**
  String get cliMissingBundled;

  /// No description provided for @cliDamagedBundled.
  ///
  /// In en, this message translates to:
  /// **'The bundled SkillsGo CLI returned an invalid startup response. Reinstall SkillsGo.'**
  String get cliDamagedBundled;

  /// No description provided for @cliIncompatibleBundled.
  ///
  /// In en, this message translates to:
  /// **'The bundled SkillsGo CLI is incompatible with this version of SkillsGo. Update or reinstall the app.'**
  String get cliIncompatibleBundled;

  /// No description provided for @officialIndex.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo Registry'**
  String get officialIndex;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a skill for your next move.'**
  String get discoverTitle;

  /// No description provided for @searchSkills.
  ///
  /// In en, this message translates to:
  /// **'Search skills…'**
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
  /// **'You’re offline'**
  String get offlineTitle;

  /// No description provided for @offlineMessage.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo could not reach the Registry. Check your network, proxy, or Registry Origin.'**
  String get offlineMessage;

  /// No description provided for @searchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Search stumbled'**
  String get searchFailedTitle;

  /// No description provided for @validationTitle.
  ///
  /// In en, this message translates to:
  /// **'Check this request'**
  String get validationTitle;

  /// No description provided for @validationMessage.
  ///
  /// In en, this message translates to:
  /// **'The Registry rejected the request. Review the query and try again.'**
  String get validationMessage;

  /// No description provided for @serverTitle.
  ///
  /// In en, this message translates to:
  /// **'Registry unavailable'**
  String get serverTitle;

  /// No description provided for @serverMessage.
  ///
  /// In en, this message translates to:
  /// **'The Registry could not complete this request. Try again in a moment.'**
  String get serverMessage;

  /// No description provided for @timeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Registry timed out'**
  String get timeoutTitle;

  /// No description provided for @timeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The Registry took too long to respond. Check the connection or try again.'**
  String get timeoutMessage;

  /// No description provided for @invalidResponseTitle.
  ///
  /// In en, this message translates to:
  /// **'Registry response unsupported'**
  String get invalidResponseTitle;

  /// No description provided for @invalidResponseMessage.
  ///
  /// In en, this message translates to:
  /// **'This Registry returned a response SkillsGo cannot read. Check its version and protocol compatibility.'**
  String get invalidResponseMessage;

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
  /// **'Enter a capability, source, or task to search the public Registry.'**
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

  /// No description provided for @collectionEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Skills in this collection'**
  String get collectionEmptyTitle;

  /// No description provided for @collectionEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'The Registry returned an empty collection. Try again after new install activity is recorded.'**
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

  /// No description provided for @installToMoreTargets.
  ///
  /// In en, this message translates to:
  /// **'Install to More Targets'**
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
  /// **'The Registry could not provide this immutable artifact. Retry now or inspect another version.'**
  String get artifactUnavailableMessage;

  /// No description provided for @detailInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Artifact metadata unsupported'**
  String get detailInvalidTitle;

  /// No description provided for @detailInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'The Registry returned incomplete or malformed audit metadata. Retry after checking Registry compatibility.'**
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

  /// No description provided for @targetSummary.
  ///
  /// In en, this message translates to:
  /// **'{scope} / {agent} · {version}'**
  String targetSummary(String scope, String agent, String version);

  /// No description provided for @userScope.
  ///
  /// In en, this message translates to:
  /// **'User Scope'**
  String get userScope;

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
  /// **'Preview truncated by the Registry safety limit.'**
  String get fileContentTruncated;

  /// No description provided for @riskEvidence.
  ///
  /// In en, this message translates to:
  /// **'Executable evidence: {paths}'**
  String riskEvidence(String paths);

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

  /// No description provided for @executableRisk.
  ///
  /// In en, this message translates to:
  /// **'This snapshot contains scripts or executable content. Review the files before installing; SkillsGo does not audit them.'**
  String get executableRisk;

  /// No description provided for @removeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeTitle(String name);

  /// No description provided for @removeDescription.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo will remove this user-level Skill. Codex will no longer see it.'**
  String get removeDescription;

  /// No description provided for @skillFact.
  ///
  /// In en, this message translates to:
  /// **'Skill: {name}'**
  String skillFact(String name);

  /// No description provided for @scopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Scope: global'**
  String get scopeGlobal;

  /// No description provided for @agentImpactCodex.
  ///
  /// In en, this message translates to:
  /// **'Agent impact: Codex'**
  String get agentImpactCodex;

  /// No description provided for @removeSkill.
  ///
  /// In en, this message translates to:
  /// **'Remove Skill'**
  String get removeSkill;

  /// No description provided for @globalCodex.
  ///
  /// In en, this message translates to:
  /// **'Global · Codex'**
  String get globalCodex;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your Library'**
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

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get addProject;

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
  /// **'Your Library is empty'**
  String get libraryEmpty;

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Install a Skill from Discover and it will appear here.'**
  String get libraryEmptyMessage;

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

  /// No description provided for @removeNamed.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeNamed(String name);

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

  /// No description provided for @localReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Can’t read this Skill'**
  String get localReadFailed;

  /// No description provided for @localConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Local configuration'**
  String get localConfiguration;

  /// No description provided for @settingsNavigation.
  ///
  /// In en, this message translates to:
  /// **'Settings navigation'**
  String get settingsNavigation;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @agents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agents;

  /// No description provided for @registry.
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get registry;

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

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @generalSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop preferences'**
  String get generalSettingsTitle;

  /// No description provided for @generalSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'SkillsGo follows the system language and accessibility preferences, including reduced motion.'**
  String get generalSettingsDescription;

  /// No description provided for @agentsSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent runtime'**
  String get agentsSettingsTitle;

  /// No description provided for @registrySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Registry Origin'**
  String get registrySettingsTitle;

  /// No description provided for @registrySettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the official Registry or an HTTP(S) self-hosted origin that implements the same SkillsGo protocol.'**
  String get registrySettingsDescription;

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

  /// No description provided for @registryInvalidOrigin.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP(S) Origin without credentials, a query, or a fragment.'**
  String get registryInvalidOrigin;

  /// No description provided for @registryHttpFailure.
  ///
  /// In en, this message translates to:
  /// **'Registry returned HTTP {status}. Check the Origin and server configuration.'**
  String registryHttpFailure(int status);

  /// No description provided for @registryInvalidProtocol.
  ///
  /// In en, this message translates to:
  /// **'The server did not return the SkillsGo Registry search protocol.'**
  String get registryInvalidProtocol;

  /// No description provided for @registryInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'The Registry returned invalid JSON.'**
  String get registryInvalidJson;

  /// No description provided for @registryConnectionFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the Registry. Check the Origin, network, proxy, and TLS configuration.'**
  String get registryConnectionFailure;

  /// No description provided for @registryConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'The Registry connection timed out. Check the network or try again.'**
  String get registryConnectionTimeout;

  /// No description provided for @riskPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal risk policy'**
  String get riskPolicyTitle;

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

  /// No description provided for @registryOriginSaved.
  ///
  /// In en, this message translates to:
  /// **'Registry Origin saved and applied.'**
  String get registryOriginSaved;

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

  /// No description provided for @agentDetectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Agent installation detected. Skills can target its supported scopes.'**
  String get agentDetectedDescription;

  /// No description provided for @agentSupportedDescription.
  ///
  /// In en, this message translates to:
  /// **'Supported, but no installation signal was found. Install the Agent or use a project target.'**
  String get agentSupportedDescription;

  /// No description provided for @agentUserTarget.
  ///
  /// In en, this message translates to:
  /// **'User target: {path}'**
  String agentUserTarget(String path);

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
  /// **'SkillsGo does not store searches or persist command logs. Its bundled CLI remains inside the App and is never installed into your system PATH.'**
  String get privacySummary;

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
