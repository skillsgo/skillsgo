// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get discover => 'Entdecken';

  @override
  String get discoverSkills => 'Es ist schön, etwas mehr zu wissen.';

  @override
  String get library => 'Bibliothek';

  @override
  String get settings => 'Einstellungen';

  @override
  String get openSettings => 'Öffnen Sie Einstellungen';

  @override
  String get cliNeedsAttention =>
      'Eine erforderliche SkillsGo-Komponente erfordert Aufmerksamkeit.';

  @override
  String get cliMissingBundled =>
      'Eine erforderliche SkillsGo-Komponente fehlt oder kann nicht gestartet werden. Installieren Sie SkillsGo neu, um es wiederherzustellen.';

  @override
  String get cliDamagedBundled =>
      'Eine erforderliche SkillsGo-Komponente ist beschädigt. Installieren Sie SkillsGo neu, um es wiederherzustellen.';

  @override
  String get cliIncompatibleBundled =>
      'Eine erforderliche SkillsGo-Komponente stimmt nicht mit dieser App-Version überein. Aktualisieren oder installieren Sie SkillsGo neu.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle =>
      'Finden Sie einen skill für Ihren nächsten Schritt.';

  @override
  String get skillsLeaderboard => 'Es ist schön, etwas mehr zu wissen.';

  @override
  String searchResultsFor(String query) {
    return 'Ergebnisse für „$query“';
  }

  @override
  String get searchSkills =>
      'Suchen Sie nach skills oder fügen Sie einen Git-Link ein ...';

  @override
  String get search => 'Suchen';

  @override
  String get ranking => 'Rang';

  @override
  String get trending => 'Im Trend';

  @override
  String get hot => 'Heiß';

  @override
  String get discoverNavigation => 'Entdecken Sie die Navigation';

  @override
  String get allTimeRanking => 'Allzeit-Rangliste';

  @override
  String get trendingNow => 'Im Trend der letzten 24 Stunden';

  @override
  String get hotNow => 'Im Moment heiß';

  @override
  String get allTimeDescription =>
      'Öffentliche Skills, sortiert nach der Gesamtzahl akzeptierter Installationen.';

  @override
  String get trendingDescription =>
      'Öffentliche Skills, sortiert nach akzeptierten Installationen in den letzten 24 Stunden.';

  @override
  String get hotDescription =>
      'Öffentliche Skills, sortiert nach kurzfristiger Installationsrate und deren Veränderung.';

  @override
  String get offlineTitle =>
      'Es kann keine Verbindung zu SkillsGo hergestellt werden';

  @override
  String get offlineMessage =>
      'Überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut. Wenn Sie einen Proxy oder eine benutzerdefinierte Dienstadresse verwenden, überprüfen Sie diese in den Einstellungen.';

  @override
  String get searchFailedTitle => 'Suche fehlgeschlagen';

  @override
  String get validationTitle => 'Überprüfen Sie, was Sie eingegeben haben';

  @override
  String get validationMessage =>
      'SkillsGo konnte diese Anfrage nicht verwenden. Überprüfen Sie Ihre Eingaben und versuchen Sie es erneut.';

  @override
  String get serverTitle => 'Der Dienst ist vorübergehend nicht verfügbar';

  @override
  String get serverMessage =>
      'SkillsGo kann diese Anfrage derzeit nicht abschließen. Versuchen Sie es gleich noch einmal.';

  @override
  String get timeoutTitle => 'Das dauert zu lange';

  @override
  String get timeoutMessage =>
      'Der Dienst reagierte nicht rechtzeitig. Überprüfen Sie Ihre Verbindung oder versuchen Sie es erneut.';

  @override
  String get invalidResponseTitle => 'SkillsGo benötigt ein Update';

  @override
  String get invalidResponseMessage =>
      'Diese Antwort kann von Ihrer Version von SkillsGo nicht gelesen werden. Aktualisieren Sie die App und versuchen Sie es dann erneut.';

  @override
  String get invalidLocalDataTitle =>
      'Ein installiertes skill kann nicht gelesen werden';

  @override
  String get invalidLocalDataMessage =>
      'Einige lokale Installationsinformationen sind beschädigt oder inkompatibel. Aktualisieren Sie SkillsGo oder installieren Sie es neu, und versuchen Sie es dann erneut.';

  @override
  String get tryAgain => 'Versuchen Sie es erneut';

  @override
  String get searchEmptyTitle => 'Suchen, nicht scrollen.';

  @override
  String get searchEmptyMessage =>
      'Geben Sie eine Funktion, Quelle oder Aufgabe ein, um öffentliche skills zu durchsuchen.';

  @override
  String get noSkillsTitle => 'Kein skills gefunden';

  @override
  String get noSkillsMessage =>
      'Versuchen Sie es mit einer umfassenderen Formulierung oder überprüfen Sie die Rechtschreibung.';

  @override
  String get focusSearch => 'Fokussuche';

  @override
  String get skillsFromLink => 'Skills von diesem Link';

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
      other: '$count skills von $source',
      one: '1 skill von $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle =>
      'Dieser Link steht zur Überprüfung bereit';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source ist nicht in den aktuellen Suchergebnissen. SkillsGo kann im nächsten Schritt den Link direkt prüfen.';
  }

  @override
  String get inspectSource => 'Sehen Sie sich skills in diesem Link an';

  @override
  String get collectionEmptyTitle => 'Kein Skills in dieser Sammlung';

  @override
  String get collectionEmptyMessage =>
      'Hier ist noch nichts. Versuchen Sie es nach weiteren Installationsaktivitäten erneut.';

  @override
  String get loadMore => 'Mehr laden';

  @override
  String get install => 'Installieren';

  @override
  String get installAll => 'Installieren Sie alle skills';

  @override
  String get latestCommit => 'Letzter Commit';

  @override
  String get installToMoreTargets => 'An weiteren Standorten installieren';

  @override
  String localTargets(int count) {
    return '$count lokale Ziele';
  }

  @override
  String allTimeMetric(String count) {
    return '$count Allzeitinstallationen';
  }

  @override
  String trendingMetric(String count) {
    return '$count installiert / 24h';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value diese Stunde · $change';
  }

  @override
  String get trustUnverified => 'Nicht bestätigt';

  @override
  String get trustCommunityVerified => 'Community verifiziert';

  @override
  String get trustPublisherVerified => 'Herausgeber bestätigt';

  @override
  String get trustOfficial => 'Offiziell';

  @override
  String get trustWarned => 'Gewarnt';

  @override
  String get trustDelisted => 'Aus der Liste genommen';

  @override
  String get riskUnknown => 'Risiko unbekannt';

  @override
  String get riskLow => 'Geringes Risiko';

  @override
  String get riskMedium => 'Mittleres Risiko';

  @override
  String get riskHigh => 'Hohes Risiko';

  @override
  String get riskCritical => 'Kritisches Risiko';

  @override
  String openSkill(String name) {
    return 'Öffnen Sie $name';
  }

  @override
  String installs(String count) {
    return '$count wird installiert';
  }

  @override
  String get detailFailedTitle => 'Dieses Skill konnte nicht geladen werden';

  @override
  String get detailLoading => 'Überprüfbare Skill-Details werden geladen';

  @override
  String get artifactUnavailableTitle => 'Artefakt nicht verfügbar';

  @override
  String get artifactUnavailableMessage =>
      'Diese Version ist derzeit nicht verfügbar. Versuchen Sie es erneut oder wählen Sie eine andere Version.';

  @override
  String get detailInvalidTitle => 'Artefaktmetadaten werden nicht unterstützt';

  @override
  String get detailInvalidMessage =>
      'Einige Details zu diesem skill sind unvollständig oder nicht lesbar. Aktualisieren Sie SkillsGo und versuchen Sie es dann erneut.';

  @override
  String get instructionsTab => 'Anweisungen';

  @override
  String get manifestTab => 'Manifest';

  @override
  String immutableVersionLabel(String version) {
    return 'Unveränderlicher $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Festschreiben $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Baum $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Inhalt $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Die Herausgebervertrauensstellung überprüft den Besitz oder die Wartung; Die Sicherheit von Artefakten wird dadurch nicht zertifiziert. Das Risiko wird für diese unveränderliche Version separat bewertet.';

  @override
  String get knownInstallationTargets => 'Bekannte Installationsziele';

  @override
  String get installationRange => 'Installierter Umfang';

  @override
  String get targetDetails => 'Zieldetails anzeigen';

  @override
  String get hideTargetDetails => 'Zieldetails ausblenden';

  @override
  String installedVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Projekt';

  @override
  String get fileContentUnavailable => 'Binäre oder nicht verfügbare Vorschau';

  @override
  String get fileContentTruncated =>
      'Vorschau durch den Hub-Sicherheitsgrenzwert gekürzt.';

  @override
  String get retry => 'Wiederholen';

  @override
  String get backToSearch => 'Zurück zur Suche';

  @override
  String get installForCodex => 'Für Codex installieren';

  @override
  String get cliNotDetected => 'skills (nicht erkannt)';

  @override
  String get snapshotFiles => 'Snapshot-Dateien';

  @override
  String get globalCodex => 'Global · Codex';

  @override
  String get yourLibrary => 'Was Sie wissen, ist alles hier.';

  @override
  String get libraryNavigation => 'Bibliotheksnavigation';

  @override
  String get all => 'Alle';

  @override
  String get allSkills => 'Alle Skills';

  @override
  String get updatesOnly => 'Aktualisierungen';

  @override
  String get allAgents => 'Alle Agents';

  @override
  String get allProjects => 'Alle Projekte';

  @override
  String get specificProject => 'Projekt';

  @override
  String get userScope => 'Global';

  @override
  String get addProject => 'Projekt hinzufügen';

  @override
  String get relocateProject => 'Umzug';

  @override
  String get removeFromList => 'Aus Liste entfernen';

  @override
  String removeProjectTitle(String name) {
    return '$name aus SkillsGo entfernen?';
  }

  @override
  String get removeProjectDescription =>
      'Nur der App-Verweis wird entfernt. SkillsGo ändert oder löscht keine Dateien in diesem Verzeichnis.';

  @override
  String projectRailUnavailable(String name) {
    return '$name – nicht verfügbar';
  }

  @override
  String get emptyProjectTitle => 'Noch kein Skills';

  @override
  String get browseSkills => 'Durchsuchen Sie Skills';

  @override
  String get projectMissingTitle => 'Projektverzeichnis fehlt';

  @override
  String get projectMissingMessage =>
      'Möglicherweise wurde das Verzeichnis verschoben oder sein Volume ist offline. Verschieben Sie es oder entfernen Sie nur seinen App-Verweis.';

  @override
  String get projectPermissionTitle =>
      'Eine Projektgenehmigung ist erforderlich';

  @override
  String get projectPermissionMessage =>
      'SkillsGo kann diesen ausgewählten Stamm nicht prüfen. Gewähren Sie Zugriff, indem Sie es über die Verzeichnisauswahl verschieben.';

  @override
  String get projectInaccessibleTitle =>
      'Auf das Projektverzeichnis kann nicht zugegriffen werden';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo hat diese Projektreferenz beibehalten. Überprüfen Sie den Pfad oder das Volume und verschieben Sie es dann.';

  @override
  String get checking => 'Überprüfung…';

  @override
  String get checkUpdates => 'Überprüfen Sie Updates';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get libraryUnavailable => 'Bibliothek nicht verfügbar';

  @override
  String get libraryEmpty => 'Noch kein skills installiert';

  @override
  String get libraryEmptyMessage =>
      'Installieren Sie ein Skill von Discover und es wird hier angezeigt.';

  @override
  String get searchLibrary => 'Suche nach installiertem skills';

  @override
  String get libraryNoMatches => 'Kein passender Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Versuchen Sie es mit einem anderen Namen, einer anderen Quelle, Agent, einem anderen Projekt oder einer anderen Version.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return '$count-Projekte';
  }

  @override
  String versionsSummary(int count) {
    return '$count-Versionen';
  }

  @override
  String get hubManaged => 'Hub verwaltet';

  @override
  String get localManaged => 'Lokal verwaltet';

  @override
  String get externalInstallation => 'Externe Installation';

  @override
  String get readOnly => 'Nur lesen';

  @override
  String get unversioned => 'Unversioniert';

  @override
  String get supportingFiles => 'Unterstützende Dateien';

  @override
  String get versionDivergence => 'Versionsdivergenz';

  @override
  String get healthHealthy => 'Gesund';

  @override
  String get healthMissing => 'Ziel fehlt';

  @override
  String get healthReplaced => 'Ziel ersetzt';

  @override
  String get healthLocalModification => 'Lokale Modifikation';

  @override
  String get healthUnreadable => 'Ziel unlesbar';

  @override
  String get healthUndeclared => 'Nicht deklariert';

  @override
  String get healthWorkspaceUnreadable => 'Arbeitsbereichsstatus nicht lesbar';

  @override
  String get healthLockMismatch => 'Nicht übereinstimmendes Schloss';

  @override
  String get healthUnexpectedPath => 'Unerwarteter Zielpfad';

  @override
  String get modeExternal => 'Extern';

  @override
  String get notLinked => 'NICHT VERLINKT';

  @override
  String get update => 'Aktualisieren';

  @override
  String get backToLibrary => 'Zurück zur Bibliothek';

  @override
  String get remove => 'Entfernen';

  @override
  String get manageTargets => 'Umfang verwalten';

  @override
  String skillsSelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String get clearSelection => 'Klare Auswahl';

  @override
  String get selectCurrentResults => 'Select aktuelle Ergebnisse';

  @override
  String get clearCurrentResultSelection => 'Aktuelle Ergebnisauswahl löschen';

  @override
  String get manageTargetsTitle => 'Installationsziele verwalten';

  @override
  String get manageTargetsDescription =>
      'Wählen Sie für jedes Ziel eine genaue Aktion. Nicht ausgewählte Ziele ändern sich nicht.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$selected von $total-Zielen ausgewählt';
  }

  @override
  String get confirmRemoveTarget => 'Bestätigen Sie das Entfernen';

  @override
  String get applyTargetActions => 'Ausgewählte Aktionen anwenden';

  @override
  String get managementProgressTitle => 'Anwenden von Zielaktionen';

  @override
  String get managementResultsTitle => 'Gezielte Aktionsergebnisse';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded war erfolgreich, $failed ist fehlgeschlagen';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Ausgewählte Projektaktionen aktualisieren skillsgo.yaml und skillsgo-lock.yaml.';

  @override
  String get targetContentPreserved =>
      'Der aktuelle Zielinhalt bleibt erhalten.';

  @override
  String get localReadFailed => 'Kann dies Skill nicht lesen';

  @override
  String get localReadFailedMessage =>
      'SkillsGo konnte diesen installierten skill nicht lesen. Überprüfen Sie, ob folder verfügbar und zugänglich ist, und versuchen Sie es dann erneut.';

  @override
  String get localConfiguration => 'SKILLSGO-EINSTELLUNGEN';

  @override
  String get settingsNavigation => 'Einstellungen-Navigation';

  @override
  String get general => 'Personifizieren';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Installationsrichtlinie';

  @override
  String get storage => 'Lagerung';

  @override
  String get colorScheme => 'Farbschema';

  @override
  String get about => 'Um';

  @override
  String get colorSchemeInspectorTitle => 'Generierte Material-Farbrollen';

  @override
  String get skillsColorTokensTitle => 'Semantische Farben SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Produktfarben, die aus Radix Sand aufgebaut und mit der Primer-Semantik organisiert sind, mit Folder als dedizierter räumlicher Hierarchie.';

  @override
  String get colorSchemeInspectorDescription =>
      'Zeigen Sie eine Vorschau aller nicht veralteten ColorScheme-Token an, die aus dem aktuellen Seed generiert wurden. Klicken Sie auf eine Farbe, um ihren HEX-Wert zu kopieren.';

  @override
  String get colorSchemePairPreview => 'Semantische Paare';

  @override
  String get colorSchemePairPreviewDescription =>
      'Vordergrund- und Hintergrundrollen werden zusammen gerendert, um Kontrast und Hierarchie sichtbar zu machen.';

  @override
  String get colorSchemeComponentPreview => 'Komponentenvorschau';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Repräsentative Material-Steuerelemente, die mit genau diesem Vorschauschema gerendert wurden.';

  @override
  String get colorSchemeSampleTitle => 'Skill Kartentitel';

  @override
  String get colorSchemeSampleBody =>
      'Sekundäre Kopie verwendet onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Kopiert';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Primär';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Primäre Betonung, Container und feste Akzentrollen.';

  @override
  String get colorSchemeGroupSecondary => 'Sekundär';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Unterstützende Schwerpunkte und feste Nebenrollen.';

  @override
  String get colorSchemeGroupTertiary => 'Tertiär';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Kontrastierende Akzente und feste Tertiärrollen.';

  @override
  String get colorSchemeGroupSurface => 'Oberfläche';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Seiten-, Container-, Höhen- und Vordergrundhierarchie.';

  @override
  String get colorSchemeGroupUtility => 'Gliederung und Nutzen';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Grenzen, Schatten, Gelege und inverse Flächen.';

  @override
  String get colorSchemeGroupError => 'Fehler';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Fehleraktionen, Nachrichten und Container.';

  @override
  String get colorSchemeUsagePrimary =>
      'Primäre Aktionen, Fokus und betonte Akzente.';

  @override
  String get colorSchemeUsageSecondary =>
      'Unterstützende Aktionen und mittelbetonte Akzente.';

  @override
  String get colorSchemeUsageTertiary =>
      'Kontrastierende Akzente, die Primär- und Sekundärakzente ergänzen.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Auf $token angezeigter Text und Symbole.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return '$family-Container mit niedrigerer Betonung für Auswahlen und Akzente.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Helligkeitsunabhängiger fester $family-Container.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Gedimmter helligkeitsunabhängiger fester $family-Container.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Inhalt mit hohem Schwerpunkt auf dem festen $family-Container.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Inhalte mit geringerer Betonung auf dem festen $family-Container.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Grundseite und großflächige Oberfläche.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Gedimmte Grundfläche im dunkelsten Oberflächenton eingesetzt.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Helle Grundfläche im hellsten Oberflächenton.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'Die $level-Oberflächencontainerhöhe.';
  }

  @override
  String get colorSchemeElevationLowest => 'am niedrigsten';

  @override
  String get colorSchemeElevationLow => 'niedrig';

  @override
  String get colorSchemeElevationDefault => 'Standard';

  @override
  String get colorSchemeElevationHigh => 'hoch';

  @override
  String get colorSchemeElevationHighest => 'höchste';

  @override
  String get colorSchemeUsageOnSurface =>
      'Primärer Text und Symbole, die auf Oberflächen angezeigt werden.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Sekundärtext, Beschriftungen und dezente Symbole auf Oberflächen.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Material Höhentönung, abgeleitet vom Primärton.';

  @override
  String get colorSchemeUsageOutline =>
      'Markante Grenzen und fokussierte Komponentenumrisse.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Subtile Grenzen, Trennzeichen und Umrisse mit geringer Betonung.';

  @override
  String get colorSchemeUsageShadow =>
      'Schlagschattenfarbe für erhöhte Oberflächen.';

  @override
  String get colorSchemeUsageScrim =>
      'Modale Überlagerung, die verwendet wird, um Hintergrundinhalte abzuschwächen.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Oberfläche mit umgekehrter Hell-Dunkel-Betonung.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Primärer Akzent, der auf einer umgekehrten Oberfläche angezeigt wird.';

  @override
  String get colorSchemeUsageError =>
      'Fehleraktionen, Status und ausführliches Feedback.';

  @override
  String get save => 'Speichern';

  @override
  String get advancedSettings => 'Fortschrittlich';

  @override
  String get remindersSettings => 'Erinnerungen';

  @override
  String get remindersSettingsTitle => 'Erinnerungseinstellungen';

  @override
  String get remindersSettingsDescription =>
      'Wählen Sie aus, welche Erinnerungen Sie erhalten möchten.';

  @override
  String get updateReminderTitle => 'Erinnerungen aktualisieren';

  @override
  String get updateReminderDescription =>
      'Suchen Sie nach Updates, wenn die Bibliothek geöffnet wird.';

  @override
  String get securityReminderTitle => 'Warnungen mit hohem Risiko';

  @override
  String get securityReminderDescription =>
      'Benachrichtigt Sie über neue hohe oder kritische Risiken im installierten skills.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count installiert skills haben Updates';
  }

  @override
  String get openAvailableUpdates =>
      'Öffnen Sie die Ansicht „Verfügbare Updates“, um sie zu überprüfen und zu aktualisieren.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count installiert skills benötigt eine Sicherheitsüberprüfung';
  }

  @override
  String get reviewInstalledSkills =>
      'Überprüfen Sie deren Risikoinformationen, bevor Sie sie verwenden oder aktualisieren.';

  @override
  String get generalSettingsTitle => 'Machen Sie SkillsGo zu Ihrem';

  @override
  String get generalSettingsDescription =>
      'Die Benutzeroberfläche folgt Ihrer Systemsprache, Zugänglichkeit und Bewegungspräferenzen.';

  @override
  String get agentsSettingsTitle => 'Agent-Laufzeit';

  @override
  String get hubSettingsTitle => 'Hub Herkunft';

  @override
  String get hubSettingsDescription =>
      'Verwenden Sie den offiziellen Hub oder einen selbstgehosteten HTTP(S)-Ursprung, der dasselbe SkillsGo-Protokoll implementiert.';

  @override
  String get testConnection => 'Testverbindung';

  @override
  String get saveOrigin => 'Ursprung speichern';

  @override
  String get resetDefault => 'Auf Standard zurücksetzen';

  @override
  String get connectionReady => 'Anschluss bereit';

  @override
  String get connectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get hubInvalidOrigin =>
      'Geben Sie einen gültigen HTTP(S)-Ursprung ohne Anmeldeinformationen, eine Abfrage oder ein Fragment ein.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub hat HTTP $status zurückgegeben. Überprüfen Sie die Ursprungs- und Serverkonfiguration.';
  }

  @override
  String get hubInvalidProtocol =>
      'Der Server hat das Suchprotokoll SkillsGo Hub nicht zurückgegeben.';

  @override
  String get hubInvalidJson => 'Der Hub hat ungültiges JSON zurückgegeben.';

  @override
  String get hubConnectionFailure =>
      'Hub konnte nicht erreicht werden. Überprüfen Sie die Ursprungs-, Netzwerk-, Proxy- und TLS-Konfiguration.';

  @override
  String get hubConnectionTimeout =>
      'Bei der Hub-Verbindung ist eine Zeitüberschreitung aufgetreten. Überprüfen Sie das Netzwerk oder versuchen Sie es erneut.';

  @override
  String get riskPolicyTitle => 'Persönliche Risikorichtlinie';

  @override
  String get riskPolicyDescription =>
      'Bei der Installation oder Aktualisierung eines skill gelten Sicherheitsregeln.';

  @override
  String get confirmHighRisk =>
      'Für „Hohes Risiko“ ist eine Bestätigung erforderlich';

  @override
  String get confirmHighRiskDescription =>
      'Artefakte mit hohem Risiko erfordern vor der Installation immer eine zusätzliche Bestätigung.';

  @override
  String get allowCriticalOverride =>
      'Erlauben Sie eine explizite Außerkraftsetzung des kritischen Risikos';

  @override
  String get allowCriticalOverrideDescription =>
      'Artefakte mit kritischem Risiko bleiben standardmäßig blockiert. Aktivieren Sie dies nur, um eine separate manuelle Überschreibung verfügbar zu machen.';

  @override
  String get storageHealthy => 'Lesbar';

  @override
  String get storageNotInitialized => 'Nicht initialisiert';

  @override
  String get storageUnavailable => 'Nicht verfügbar';

  @override
  String get storageInvalidResponse =>
      'Der gebündelte CLI hat eine nicht unterstützte Diagnoseantwort zurückgegeben.';

  @override
  String get aboutSettingsTitle => 'Produktkompatibilität';

  @override
  String get appVersion => 'App-Version';

  @override
  String get cliVersion => 'Gebündelte CLI-Version';

  @override
  String get compatible => 'Kompatibel';

  @override
  String get hubOriginSaved => 'Hub Origin gespeichert und angewendet.';

  @override
  String get policySaved => 'Installationsrichtlinie gespeichert.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'BEREIT';

  @override
  String get unknown => 'UNBEKANNT';

  @override
  String get missing => 'FEHLEN';

  @override
  String get incompatible => 'UNVEREINBAR';

  @override
  String get detecting => 'Erkennen…';

  @override
  String get customCliPath => 'Benutzerdefinierter ausführbarer Pfad';

  @override
  String get saveAndDetect => 'Speichern und erkennen';

  @override
  String get detectAgain => 'Erneut erkennen';

  @override
  String get agentInstalled => 'Installiert';

  @override
  String get agentSupported => 'Unterstützt';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed installiert · $supported unterstützt';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Installiert · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Nicht installiert · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Unterstützt von SkillsGo, aber auf diesem Mac nicht erkannt.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Skill-Ladepfade: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Agent-Erkennungsdaten sind nicht verfügbar. Führen Sie die Erkennung erneut aus.';

  @override
  String get noInstalledAgentsTitle => 'Kein installiertes Agents erkannt';

  @override
  String get noInstalledAgentsMessage =>
      'Sie können dieses Skill weiter durchsuchen, es gibt jedoch noch kein Installationsziel. Installieren Sie einen unterstützten Agent und führen Sie dann die Erkennung erneut aus.';

  @override
  String get clearCustomPath => 'Benutzerdefinierten Pfad löschen';

  @override
  String get privacyProvenance => 'Datenschutz und Herkunft';

  @override
  String get privacySummary =>
      'Ihre Suchanfragen werden nicht gespeichert und SkillsGo führt keine Befehlsprotokolle.';

  @override
  String get language => 'Sprache';

  @override
  String get personalizationTheme => 'Thema';

  @override
  String get folderColorTheme => 'Themenfarbe';

  @override
  String get folderColorThemeDescription =>
      'Wählen Sie eine Farbe, die Ihnen gefällt. SkillsGo wird darum herum eine abgestimmte Schnittstellenpalette aufbauen.';

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
  String get appearanceMode => 'Modus';

  @override
  String get appearanceModeDescription =>
      'Folgen Sie dem Erscheinungsbild Ihres Systems oder verwenden Sie immer ein helles oder dunkles Design.';

  @override
  String get followSystem => 'System';

  @override
  String get lightMode => 'Licht';

  @override
  String get darkMode => 'Dunkel';

  @override
  String get wallpaper => 'Tapete';

  @override
  String get wallpaperDescription =>
      'Wählen Sie einen himmlischen Hintergrund. Ihre Auswahl erscheint direkt hinter Folder.';

  @override
  String get wallpaperSun => 'Sonne';

  @override
  String get wallpaperMercury => 'Quecksilber';

  @override
  String get wallpaperVenus => 'Venus';

  @override
  String get wallpaperEarth => 'Erde';

  @override
  String get wallpaperMars => 'Mars';

  @override
  String get wallpaperJupiter => 'Jupiter';

  @override
  String get wallpaperSaturn => 'Saturn';

  @override
  String get wallpaperUranus => 'Uranus';

  @override
  String get wallpaperNeptune => 'Neptun';

  @override
  String get wallpaperPluto => 'Pluto';

  @override
  String get wallpaperMoon => 'Mond';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Folder-Thema';
  }

  @override
  String get privacyAffiliation =>
      'Die anonyme Installationstelemetrie wird durch die SkillsGo-Einstellungen gesteuert. SkillsGo ist nicht mit OpenAI oder Codex verbunden.';

  @override
  String get commandCompleted => 'Befehl abgeschlossen';

  @override
  String get commandFailed => 'Der Befehl ist fehlgeschlagen';

  @override
  String commandExit(int code) {
    return 'Beenden Sie $code · Erweitern Sie es für das Protokoll dieser Sitzung';
  }

  @override
  String get command => 'Befehl';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get updateUnknown => 'UNBEKANNT';

  @override
  String get updateChecking => 'ÜBERPRÜFUNG';

  @override
  String get upToDate => 'UP TO DATE';

  @override
  String get updateAvailable => 'AKTUALISIEREN';

  @override
  String get updateUnavailable => 'NICHT VERFÜGBAR';

  @override
  String get updateCheckFailed => 'ÜBERPRÜFUNG FEHLGESCHLAGEN';

  @override
  String get installSkill => 'Installieren Sie Skill';

  @override
  String get installLocationTitle => 'Installationsort festlegen';

  @override
  String get userLevel => 'Benutzerebene';

  @override
  String get projectLevel => 'Projektebene';

  @override
  String get projects => 'Projekte';

  @override
  String get loading => 'Laden…';

  @override
  String get repositoryParsing => 'Parsing-Repository…';

  @override
  String userInstallSummary(int agents) {
    return 'Verfügbar für $agents Agents auf Benutzerebene';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects-Projekte · $agents Agents';
  }

  @override
  String get installationResults => 'Installationsergebnisse';

  @override
  String get installationInProgress => 'Installation läuft';

  @override
  String get installationSucceeded => 'Installation abgeschlossen';

  @override
  String get installationSucceededMessage =>
      'Der Skill ist jetzt an den ausgewählten Standorten verfügbar.';

  @override
  String get projectUnavailable => 'Projekt nicht verfügbar';

  @override
  String get installedCell => 'Installiert';

  @override
  String get unsupportedCell => 'Nicht verfügbar';

  @override
  String get confirmInstall => 'Bestätigen Sie die Installation';

  @override
  String installAllRepositorySkills(int count) {
    return 'Installieren Sie das gesamte Repository skills ($count).';
  }

  @override
  String get installAllSkillsTo => 'Installieren Sie alle skills auf';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Alle installieren $repository skills ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Installieren Sie $skill auf';
  }

  @override
  String get availableInAllProjects => 'Alle Projekte';

  @override
  String get availableInSelectedProjects => 'Ausgewählte Projekte';

  @override
  String get usedBy => 'Für Agents';

  @override
  String get backToTargets => 'Zurück zu den Zielen';

  @override
  String get stayHere => 'Bleib hier';

  @override
  String get viewInLibrary => 'In der Bibliothek ansehen';

  @override
  String planCreateCount(int count) {
    return '$count erstellen';
  }

  @override
  String planSkipCount(int count) {
    return '$count überspringen';
  }

  @override
  String planReplaceCount(int count) {
    return '$count ersetzen';
  }

  @override
  String planConflictCount(int count) {
    return '$count-Konflikt';
  }

  @override
  String planRiskCount(int count) {
    return '$count Risiko blockiert';
  }

  @override
  String get refreshInstallationPlan => 'Vorsätze anwenden';

  @override
  String get replaceVersionConflict =>
      'Ersetzen Sie die installierte Version auf diesem Ziel';

  @override
  String get replaceSkillIdCollision =>
      'Ersetzen Sie die verschiedenen Skill ID an diesem Ziel';

  @override
  String get replaceLocalModification =>
      'Lokale Änderungen verwerfen und dieses Ziel ersetzen';

  @override
  String get sharedTargetConflict =>
      'Dieser Pfad wird von other Agent-Zielen gemeinsam genutzt';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Kehren Sie zur Zielmatrix und select aller betroffenen Agent zurück, bevor Sie Folgendes ersetzen: $agents';
  }

  @override
  String get replaceConflictingTarget =>
      'Ersetzen Sie das widersprüchliche Ziel';

  @override
  String get confirmHighRiskArtifact =>
      'Bestätigung von Artefakten mit hohem Risiko';

  @override
  String get confirmCriticalRiskArtifact =>
      'Bestätigung der Außerkraftsetzung kritischer Risiken';

  @override
  String get confirmRiskForSelectedTargets =>
      'Ich habe die Artefaktdateien überprüft und akzeptiere dieses Risiko für die ausgewählten Ziele';

  @override
  String get criticalRiskBlocked =>
      'Die Installation mit kritischem Risiko ist blockiert';

  @override
  String get criticalRiskOverrideDisabled =>
      'Aktivieren Sie die explizite Überschreibung des kritischen Risikos in den Einstellungen, bevor dieser Plan fortgesetzt werden kann.';

  @override
  String get workspaceManifestChanges =>
      'Änderungen am Arbeitsbereichsmanifest';

  @override
  String get noWorkspaceManifestChanges =>
      'Es werden keine Workspace-Manifestdateien geändert.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'nicht vorhanden';

  @override
  String get planActionCreate => 'Erstellen';

  @override
  String get planActionReplace => 'Ersetzen';

  @override
  String get planActionSkip => 'Überspringen';

  @override
  String get planActionConflict => 'Konflikt';

  @override
  String get planActionBlockedByRisk => 'Durch Risiko blockiert';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded-Ziele installiert, $failed fehlgeschlagen';
  }

  @override
  String get installationProgressTitle => 'Installation läuft';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished von $total-Zielen fertig';
  }

  @override
  String get targetWaiting => 'Warten';

  @override
  String get targetRunning => 'Installieren';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fehlgeschlagene Ziele erneut versuchen',
      one: '1 fehlgeschlagenes Ziel erneut versuchen',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Zu aktualisierende Select-Ziele';

  @override
  String get updatePlanDescription =>
      'Wählen Sie genaue Installationsziele. Nicht ausgewählte Agents und Projekte bleiben unverändert.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected oder $available aktualisierbare Ziele ausgewählt';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Quellenangabe: $reference';
  }

  @override
  String get fixedVersionTarget => 'Angepinnt – keine bewegliche Referenz';

  @override
  String get currentVersionTarget => 'Auf dem neuesten Stand';

  @override
  String get updateCheckTargetFailed =>
      'Die Aktualisierungsprüfung ist fehlgeschlagen';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Arbeitsbereichsmanifest reparieren';

  @override
  String get updateSelectedTargets => 'Ausgewählte Ziele aktualisieren';

  @override
  String get updateProgressTitle => 'Ziele aktualisieren';

  @override
  String get updateResultsTitle => 'Ergebnisse aktualisieren';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished von $total-Zielen fertig';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fehlgeschlagene Updates wiederholen',
      one: '1 fehlgeschlagenes Update wiederholen',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Für kein ausgewähltes Ziel ist ein Update verfügbar.';

  @override
  String get closeUpdatePlan => 'Schließen';

  @override
  String get targetSucceeded => 'Installiert';

  @override
  String get targetSkipped => 'Übersprungen';

  @override
  String get targetConflict => 'Konflikt';

  @override
  String get targetFailed => 'Fehlgeschlagen';

  @override
  String get targetFailureRetryable =>
      'Dieser Standort konnte nicht geändert werden. Sie können es noch einmal versuchen.';

  @override
  String get targetFailureNeedsAttention =>
      'Dieser Standort erfordert Ihre Aufmerksamkeit, bevor Sie es erneut versuchen.';

  @override
  String get installationTargetFailureMessage =>
      'An diesem Standort wurde nichts geändert. Überprüfen Sie, ob folder verfügbar ist, und versuchen Sie es erneut.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Es wurde nichts geändert, da SkillsGo die Projekteinstellungen nicht speichern konnte. Überprüfen Sie, ob das Projekt folder beschreibbar ist, und versuchen Sie es erneut.';

  @override
  String get installationStateChangedMessage =>
      'Dieser Standort hat sich geändert, während Sie ihn überprüft haben. Überprüfen Sie den aktuellen Status, bevor Sie es erneut versuchen.';

  @override
  String get updateTargetFailureMessage =>
      'Dieser Standort konnte nicht aktualisiert werden. Other-Standorte waren nicht betroffen, daher können Sie es nur bei diesem erneut versuchen.';

  @override
  String get managementTargetFailureMessage =>
      'Diese Aktion konnte hier nicht abgeschlossen werden. Other-Standorte waren nicht betroffen, daher können Sie es nur bei diesem erneut versuchen.';

  @override
  String get technicalDetails => 'Technische Details';

  @override
  String get targetPathExists =>
      'An diesem Standort ist bereits ein anderer Artikel vorhanden.';

  @override
  String get targetBlockedByRisk =>
      'Ihre aktuellen Sicherheitseinstellungen haben die Installation an diesem Speicherort blockiert.';

  @override
  String get targetInstallFailed =>
      'Der skill konnte an diesem Ort nicht installiert werden.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Der skill wurde installiert, aber die Projekteinstellungen konnten nicht aktualisiert werden.';

  @override
  String get installationPlanFailed =>
      'Installationsplan konnte nicht fortgesetzt werden';

  @override
  String get installationFailed =>
      'Die Installation konnte nicht abgeschlossen werden';

  @override
  String get localSource => 'Lokale Quelle';

  @override
  String get noDescriptionAvailable => 'Keine Beschreibung verfügbar';

  @override
  String moreCoverage(int count) {
    return '+$count weitere Standorte';
  }

  @override
  String get batchTakeoverAction => 'Vorhandenes skills verwalten';

  @override
  String handExternalSkillsToSkillsGoManagementCount(int count) {
    return 'Let SkillsGo manage $count external skills';
  }

  @override
  String confirmSkillsGoManagementCount(int count) {
    return 'Confirm SkillsGo management ($count)';
  }

  @override
  String get skillColumnLabel => 'Skill';

  @override
  String get repositorySourceColumnLabel => 'Source';

  @override
  String get versionColumnLabel => 'Version';

  @override
  String get repositoryMatching => 'Matching sources…';

  @override
  String get sourceMatchUnavailable => 'Source matching unavailable';

  @override
  String get noSourceMatches => 'No matching source';

  @override
  String sourceMatchPercent(int percent) {
    return '$percent% match';
  }

  @override
  String get versionPendingSelection => 'Pending Source';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Verwalten ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Vorhandenes skills prüfen…';

  @override
  String get batchTakeoverRetry =>
      'Überprüfen Sie noch einmal das beherrschbare skills';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count kann verwaltet werden';
  }

  @override
  String get batchTakeoverPending => 'skills zum Management hinzufügen…';

  @override
  String get batchTakeoverTitle => 'Vorhandenes skills mit SkillsGo verwalten?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo fügt lokale Verwaltungsdatensätze hinzu, ohne skill-Dateien zu verschieben, zu überschreiben oder hochzuladen. Nicht unterstützte oder geänderte Elemente werden übersprungen.';

  @override
  String get batchTakeoverStoryTitle =>
      'Verwandeln Sie verstreute skills in eine übersichtliche Bibliothek';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vorhanden skills',
      one: '1 vorhanden skill',
    );
    return 'SkillsGo hat $_temp0 gefunden, das es an diesem Standort verwalten kann.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Vor der Verwaltung ist unklar, wo vorhandene skills installiert sind, ob sie aktuell sind, wie sie wiederhergestellt werden können oder ob Projekte dieselbe Version verwenden.';

  @override
  String get batchTakeoverPainLocation => 'Unbekannter Installationsort';

  @override
  String get batchTakeoverPainFreshness => 'Unbekannter Update-Status';

  @override
  String get batchTakeoverPainRecovery => 'Keine Wiederherstellung bei Defekt';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Unterschiedliche Versionen über Projekte hinweg';

  @override
  String get batchTakeoverFolderTitle => 'Vorhanden Skills';

  @override
  String get batchTakeoverFolderSubtitle => 'Unklarer Status';

  @override
  String get batchTakeoverAfterLabel => 'NACH';

  @override
  String get batchTakeoverAfterTitle => 'Eine übersichtliche Bibliothek';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo-Bibliothek';

  @override
  String get batchTakeoverBenefitLocation => 'Klare Standorte';

  @override
  String get batchTakeoverBenefitFreshness => 'Updates sichtbar';

  @override
  String get batchTakeoverBenefitRecovery => 'Einfache Wiederherstellung';

  @override
  String get batchTakeoverBenefitVersions => 'Versionen klar';

  @override
  String get batchTakeoverManagedSection => 'Verwaltet von SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Ausstehend';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name wird von SkillsGo verwaltet';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name konnte nicht zur Verwaltung hinzugefügt werden';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name wartet darauf, verwaltet zu werden';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills',
      one: '1 skill ist',
    );
    return 'Nach der Verwaltung sind $_temp0 in einer Bibliothek mit einem klaren verwalteten Status organisiert.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count mehr';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Fügen Sie diese vorhandenen skills zur SkillsGo-Verwaltung hinzu.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANISIEREN';

  @override
  String get batchTakeoverStatusTitle => 'Verwaltungsstatus';

  @override
  String get batchTakeoverStatusManaged => 'Verwaltet';

  @override
  String get batchTakeoverStatusProgress => 'Organisieren';

  @override
  String get batchTakeoverStatusSkipped => 'Übersprungen';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Skill-Dateien bleiben an ihrem ursprünglichen Speicherort';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills werden in komplette Zeilen geordnet und von SkillsGo aufgezeichnet, ohne ihre Dateien zu verschieben.';

  @override
  String get batchTakeoverBoardComplete => 'ALLES KLAR';

  @override
  String get batchTakeoverBoardPartial => 'VOLLSTÄNDIG';

  @override
  String get batchTakeoverStatusTotal => 'Gesamt';

  @override
  String get batchTakeoverQueueComplete => 'Es warten keine skills';

  @override
  String get batchTakeoverQueueWaiting =>
      'Nach der Überprüfung werden die Skills hier angezeigt';

  @override
  String get batchTakeoverNextLabel => 'NÄCHSTE';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo Organizer-Blöcke',
      one: '1 SkillsGo Organizer-Block',
    );
    return '$_temp0 vervollständigen die letzten Reihen';
  }

  @override
  String get batchTakeoverPreservation =>
      'Ihre Dateien, Pfade und aktuellen Arbeitsabläufe bleiben genau dort, wo sie sind. SkillsGo vervollständigt nur seine lokalen Verwaltungsdatensätze.';

  @override
  String get batchTakeoverLaterHint =>
      'Wenn Sie überspringen, können Sie jederzeit „Vorhandenes skills aus Bibliothek verwalten“ verwenden.';

  @override
  String get batchTakeoverSkip => 'Nicht jetzt';

  @override
  String get batchTakeoverConfirm => 'Zur Verwaltung hinzufügen';

  @override
  String get batchTakeoverExecutionRetry => 'Wiederholen';

  @override
  String get batchTakeoverResultTitle => 'Skills zur Verwaltung hinzugefügt';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver skills zur Verwaltung hinzugefügt, $skipped übersprungen.';
  }

  @override
  String get batchTakeoverClose => 'Schließen';

  @override
  String get installMoreTargets => 'An mehreren Standorten installieren';

  @override
  String get detailRepository => 'Repository';

  @override
  String get detailStars => 'Sterne';

  @override
  String get detailUpdated => 'Aktualisiert';

  @override
  String get detailArchiveSize => 'ZIP-Größe';

  @override
  String get pathLabel => 'Projektpfad';

  @override
  String get copyProjectPath => 'Projektpfad kopieren';

  @override
  String get projectPathCopied => 'Projektpfad kopiert';

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Entdecken, installieren und verwalten Sie Skills in Ihren Agents und Projekten.';

  @override
  String get onboardingDetectedAgents => 'Agents erkannt';

  @override
  String get onboardingNoAgents =>
      'Kein installiertes Agents erkannt. Sie können trotzdem fortfahren.';

  @override
  String get onboardingNext => 'Nächste';

  @override
  String get onboardingProjectsTitle => 'Fügen Sie Ihre Projekte hinzu';

  @override
  String get onboardingProjectsDescription =>
      'Wählen Sie die Projekte aus, die SkillsGo verwalten soll.';

  @override
  String get onboardingAddProject => 'Jetzt hinzufügen';

  @override
  String get onboardingAddProjectLater => 'oder später';

  @override
  String get onboardingStartUsing =>
      'Beginnen Sie mit der Verwendung von SkillsGo';

  @override
  String get onboardingBack => 'Zurück';

  @override
  String get restartOnboardingTitle => 'Onboarding';

  @override
  String get restartOnboardingDescription =>
      'Sehen Sie sich den Erststart-Leitfaden noch einmal an, ohne Projekte, Einstellungen oder Skills-Daten zu entfernen.';

  @override
  String get restartOnboardingAction => 'Starten Sie das Onboarding neu';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo konnte Onboarding nicht neu starten.';

  @override
  String get libraryRefreshSettingsTitle => 'Lokale Bibliothek aktualisieren';

  @override
  String get libraryRefreshSettingsDescription =>
      'Scannen Sie installierte Skills, hinzugefügte Projekte, Agents und externe Skills, die verwaltet werden können, erneut. Dadurch wird nichts installiert, aktualisiert oder entfernt.';

  @override
  String get libraryRefreshSettingsAction => 'Bibliothek aktualisieren';

  @override
  String get libraryRefreshSettingsPending => 'Erfrischende Bibliothek…';

  @override
  String get libraryRefreshSettingsSuccess => 'Lokale Bibliothek aktualisiert.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo konnte die lokale Bibliothek nicht aktualisieren.';

  @override
  String get onboardingProjectError =>
      'SkillsGo konnte keine Projekte aus diesem Verzeichnis hinzufügen.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo konnte Ihre hinzugefügten Projekte nicht laden.';

  @override
  String get onboardingStartupError => 'SkillsGo konnte das Setup nicht laden.';

  @override
  String get onboardingStateError =>
      'SkillsGo konnte Ihren Setup-Fortschritt nicht speichern. Versuchen Sie es erneut.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI braucht Aufmerksamkeit';

  @override
  String get onboardingCliErrorDescription =>
      'Reparieren Sie das mitgelieferte CLI und versuchen Sie dann erneut, fortzufahren.';
}
