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
  /// **'The bundled SkillsGo CLI is missing or cannot run. Reinstall SkillsPlay.'**
  String get cliMissingBundled;

  /// No description provided for @cliDamagedBundled.
  ///
  /// In en, this message translates to:
  /// **'The bundled SkillsGo CLI returned an invalid startup response. Reinstall SkillsPlay.'**
  String get cliDamagedBundled;

  /// No description provided for @cliIncompatibleBundled.
  ///
  /// In en, this message translates to:
  /// **'The bundled SkillsGo CLI is incompatible with this version of SkillsPlay. Update or reinstall the app.'**
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

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'You’re offline'**
  String get offlineTitle;

  /// No description provided for @searchFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Search stumbled'**
  String get searchFailedTitle;

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
  /// **'SkillsPlay has no feed or ranking. Enter a capability you need.'**
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
  /// **'This snapshot contains scripts or executable content. Review the files before installing; SkillsPlay does not audit them.'**
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
  /// **'SkillsPlay does not store searches or persist command logs. Its bundled CLI remains inside the App and is never installed into your system PATH.'**
  String get privacySummary;

  /// No description provided for @privacyAffiliation.
  ///
  /// In en, this message translates to:
  /// **'Anonymous installation telemetry is controlled by SkillsGo settings. SkillsPlay is not affiliated with OpenAI or Codex.'**
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
