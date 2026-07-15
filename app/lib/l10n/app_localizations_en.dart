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
      'The bundled SkillsGo CLI is missing or cannot run. Reinstall SkillsPlay.';

  @override
  String get cliDamagedBundled =>
      'The bundled SkillsGo CLI returned an invalid startup response. Reinstall SkillsPlay.';

  @override
  String get cliIncompatibleBundled =>
      'The bundled SkillsGo CLI is incompatible with this version of SkillsPlay. Update or reinstall the app.';

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
  String get collectionComingSoon =>
      'This collection is ready for Registry integration.';

  @override
  String get offlineTitle => 'You’re offline';

  @override
  String get searchFailedTitle => 'Search stumbled';

  @override
  String get tryAgain => 'Try again';

  @override
  String get searchEmptyTitle => 'Search, don’t scroll.';

  @override
  String get searchEmptyMessage =>
      'SkillsPlay has no feed or ranking. Enter a capability you need.';

  @override
  String get noSkillsTitle => 'No skills found';

  @override
  String get noSkillsMessage => 'Try a broader phrase or check the spelling.';

  @override
  String get focusSearch => 'Focus search';

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
      'This snapshot contains scripts or executable content. Review the files before installing; SkillsPlay does not audit them.';

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
  String get userScope => 'User Scope';

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
  String get clearCustomPath => 'Clear custom path';

  @override
  String get privacyProvenance => 'Privacy & provenance';

  @override
  String get privacySummary =>
      'SkillsPlay does not store searches or persist command logs. Its bundled CLI remains inside the App and is never installed into your system PATH.';

  @override
  String get privacyAffiliation =>
      'Anonymous installation telemetry is controlled by SkillsGo settings. SkillsPlay is not affiliated with OpenAI or Codex.';

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
