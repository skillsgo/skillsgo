// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get discover => 'Ontdekken';

  @override
  String get discoverSkills => 'Het is leuk om iets meer te weten.';

  @override
  String get library => 'Bibliotheek';

  @override
  String get settings => 'Instellingen';

  @override
  String get openSettings => 'Instellingen openen';

  @override
  String get cliNeedsAttention =>
      'Een vereist SkillsGo-onderdeel heeft aandacht nodig.';

  @override
  String get cliMissingBundled =>
      'Een vereist SkillsGo-onderdeel ontbreekt of kan niet starten. Installeer SkillsGo opnieuw om het te herstellen.';

  @override
  String get cliDamagedBundled =>
      'Een vereist SkillsGo-onderdeel is beschadigd. Installeer SkillsGo opnieuw om het te herstellen.';

  @override
  String get cliIncompatibleBundled =>
      'Een vereist SkillsGo-onderdeel komt niet overeen met deze app-versie. Update of installeer SkillsGo opnieuw.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Zoek een skill voor uw volgende zet.';

  @override
  String get skillsLeaderboard => 'Het is leuk om iets meer te weten.';

  @override
  String searchResultsFor(String query) {
    return 'Resultaten voor “$query”';
  }

  @override
  String get searchSkills => 'Zoek in skills of plak een Git-link...';

  @override
  String get search => 'Zoekopdracht';

  @override
  String get ranking => 'Ranglijst';

  @override
  String get trending => 'Populair';

  @override
  String get hot => 'Heet';

  @override
  String get discoverNavigation => 'Ontdek navigatie';

  @override
  String get allTimeRanking => 'Ranglijst aller tijden';

  @override
  String get trendingNow => 'Trends van de afgelopen 24 uur';

  @override
  String get hotNow => 'Heet op dit moment';

  @override
  String get allTimeDescription =>
      'Openbare Skills, gesorteerd op het totale aantal geaccepteerde installaties.';

  @override
  String get trendingDescription =>
      'Openbare Skills, gesorteerd op geaccepteerde installaties in de afgelopen 24 uur.';

  @override
  String get hotDescription =>
      'Openbare Skills, gesorteerd op recente installatiesnelheid en verandering.';

  @override
  String get offlineTitle => 'Kan geen verbinding maken met SkillsGo';

  @override
  String get offlineMessage =>
      'Controleer uw internetverbinding en probeer het opnieuw. Als u een proxy of een aangepast serviceadres gebruikt, controleert u dit in Instellingen.';

  @override
  String get searchFailedTitle => 'Zoeken mislukt';

  @override
  String get validationTitle => 'Controleer wat je hebt ingevoerd';

  @override
  String get validationMessage =>
      'SkillsGo kan dit verzoek niet gebruiken. Controleer wat u heeft ingevoerd en probeer het opnieuw.';

  @override
  String get serverTitle => 'Dienst tijdelijk niet beschikbaar';

  @override
  String get serverMessage =>
      'SkillsGo kan dit verzoek momenteel niet voltooien. Probeer het zo nog eens.';

  @override
  String get timeoutTitle => 'Dit duurt te lang';

  @override
  String get timeoutMessage =>
      'De dienst reageerde niet op tijd. Controleer uw verbinding of probeer het opnieuw.';

  @override
  String get invalidResponseTitle => 'SkillsGo heeft een update nodig';

  @override
  String get invalidResponseMessage =>
      'Dit antwoord kan niet worden gelezen door uw versie van SkillsGo. Update de app en probeer het opnieuw.';

  @override
  String get invalidLocalDataTitle => 'Kan een geïnstalleerde skill niet lezen';

  @override
  String get invalidLocalDataMessage =>
      'Sommige lokale installatie-informatie is beschadigd of incompatibel. Update of installeer SkillsGo opnieuw en probeer het opnieuw.';

  @override
  String get tryAgain => 'Probeer het opnieuw';

  @override
  String get searchEmptyTitle => 'Zoeken, niet scrollen.';

  @override
  String get searchEmptyMessage =>
      'Voer een mogelijkheid, bron of taak in om in openbare skills te zoeken.';

  @override
  String get noSkillsTitle => 'Geen skills gevonden';

  @override
  String get noSkillsMessage =>
      'Probeer een bredere zin of controleer de spelling.';

  @override
  String get focusSearch => 'Focus zoeken';

  @override
  String get skillsFromLink => 'Skills via deze link';

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
      other: '$count skills uit $source',
      one: '1 skill uit $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Deze link is klaar om te inspecteren';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source staat niet in de huidige zoekresultaten. SkillsGo kan de link in de volgende stap direct inspecteren.';
  }

  @override
  String get inspectSource => 'Bekijk skills via deze link';

  @override
  String get collectionEmptyTitle => 'Geen Skills in deze collectie';

  @override
  String get collectionEmptyMessage =>
      'Er is hier nog niets. Probeer het opnieuw na meer installatieactiviteit.';

  @override
  String get loadMore => 'Laad meer';

  @override
  String get install => 'Installeren';

  @override
  String get installAll => 'Installeer alle skills';

  @override
  String get latestCommit => 'Laatste toezegging';

  @override
  String get installToMoreTargets => 'Installeer op meer locaties';

  @override
  String localTargets(int count) {
    return '$count lokale doelen';
  }

  @override
  String allTimeMetric(String count) {
    return '$count-installaties aller tijden';
  }

  @override
  String trendingMetric(String count) {
    return '$count-installaties / 24 uur';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value dit uur · $change';
  }

  @override
  String get trustUnverified => 'Niet geverifieerd';

  @override
  String get trustCommunityVerified => 'Gemeenschap geverifieerd';

  @override
  String get trustPublisherVerified => 'Uitgever geverifieerd';

  @override
  String get trustOfficial => 'Officieel';

  @override
  String get trustWarned => 'Gewaarschuwd';

  @override
  String get trustDelisted => 'Verwijderd';

  @override
  String get riskUnknown => 'Risico onbekend';

  @override
  String get riskLow => 'Laag risico';

  @override
  String get riskMedium => 'Middelmatig risico';

  @override
  String get riskHigh => 'Hoog risico';

  @override
  String get riskCritical => 'Kritiek risico';

  @override
  String openSkill(String name) {
    return 'Open $name';
  }

  @override
  String installs(String count) {
    return '$count-installaties';
  }

  @override
  String get detailFailedTitle => 'Kan deze Skill niet laden';

  @override
  String get detailLoading => 'Controleerbaar Skill-detail laden';

  @override
  String get artifactUnavailableTitle => 'Artefact niet beschikbaar';

  @override
  String get artifactUnavailableMessage =>
      'Deze versie is momenteel niet beschikbaar. Probeer het opnieuw of kies een andere versie.';

  @override
  String get detailInvalidTitle =>
      'Metagegevens van artefacten worden niet ondersteund';

  @override
  String get detailInvalidMessage =>
      'Sommige gegevens voor deze skill zijn onvolledig of kunnen niet worden gelezen. Update SkillsGo en probeer het opnieuw.';

  @override
  String get instructionsTab => 'Instructies';

  @override
  String get manifestTab => 'Manifest';

  @override
  String immutableVersionLabel(String version) {
    return 'Onveranderlijk $version';
  }

  @override
  String commitIdentity(String sha) {
    return '$sha vastleggen';
  }

  @override
  String treeIdentity(String sha) {
    return 'Boom $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Inhoud $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Uitgeversvertrouwen verifieert eigendom of onderhoud; het certificeert de veiligheid van artefacten niet. Voor deze onveranderlijke versie wordt het risico afzonderlijk beoordeeld.';

  @override
  String get knownInstallationTargets => 'Bekende installatiedoelen';

  @override
  String get installationRange => 'Geïnstalleerd bereik';

  @override
  String get targetDetails => 'Toon doeldetails';

  @override
  String get hideTargetDetails => 'Doeldetails verbergen';

  @override
  String installedVersionLabel(String version) {
    return 'Versie $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Project';

  @override
  String get fileContentUnavailable => 'Binair of niet-beschikbaar voorbeeld';

  @override
  String get fileContentTruncated =>
      'Voorbeeld afgekapt door de Hub-veiligheidslimiet.';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String get backToSearch => 'Terug naar zoeken';

  @override
  String get installForCodex => 'Installeren voor Codex';

  @override
  String get cliNotDetected => 'skills (niet gedetecteerd)';

  @override
  String get snapshotFiles => 'Momentopnamebestanden';

  @override
  String get globalCodex => 'Globaal · Codex';

  @override
  String get yourLibrary => 'Wat je weet is hier allemaal.';

  @override
  String get libraryNavigation => 'Bibliotheeknavigatie';

  @override
  String get all => 'Alle';

  @override
  String get allSkills => 'Alle Skills';

  @override
  String get updatesOnly => 'Updates';

  @override
  String get allAgents => 'Alle Agents';

  @override
  String get allProjects => 'Alle projecten';

  @override
  String get specificProject => 'Project';

  @override
  String get userScope => 'Globaal';

  @override
  String get addProject => 'Project toevoegen';

  @override
  String get relocateProject => 'Verhuizen';

  @override
  String get removeFromList => 'Verwijderen uit lijst';

  @override
  String removeProjectTitle(String name) {
    return '$name verwijderen uit SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Alleen de app-referentie wordt verwijderd. SkillsGo zal geen bestanden in deze map wijzigen of verwijderen.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — niet beschikbaar';
  }

  @override
  String get emptyProjectTitle => 'Nog geen Skills';

  @override
  String get browseSkills => 'Blader door Skills';

  @override
  String get projectMissingTitle => 'Projectmap ontbreekt';

  @override
  String get projectMissingMessage =>
      'De map is mogelijk verplaatst of het volume ervan is mogelijk offline. Verplaats het of verwijder alleen de app-referentie.';

  @override
  String get projectPermissionTitle => 'Projectvergunning is vereist';

  @override
  String get projectPermissionMessage =>
      'SkillsGo kan deze geselecteerde root niet inspecteren. Verleen toegang door deze te verplaatsen via de directorykiezer.';

  @override
  String get projectInaccessibleTitle =>
      'Projectdirectory is niet toegankelijk';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo heeft deze projectreferentie behouden. Controleer het pad of volume en verplaats het vervolgens.';

  @override
  String get checking => 'Controleren…';

  @override
  String get checkUpdates => 'Controleer updates';

  @override
  String get refresh => 'Vernieuwen';

  @override
  String get libraryUnavailable => 'Bibliotheek niet beschikbaar';

  @override
  String get libraryEmpty => 'Nog geen skills geïnstalleerd';

  @override
  String get libraryEmptyMessage =>
      'Installeer een Skill van Discover en deze zal hier verschijnen.';

  @override
  String get searchLibrary => 'Zoek naar geïnstalleerde skills';

  @override
  String get libraryNoMatches => 'Geen overeenkomende Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Probeer een andere naam, bron, Agent, project of versie.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return '$count-projecten';
  }

  @override
  String versionsSummary(int count) {
    return '$count-versies';
  }

  @override
  String get hubManaged => 'Hub beheerd';

  @override
  String get localManaged => 'Lokaal beheerd';

  @override
  String get externalInstallation => 'Externe installatie';

  @override
  String get readOnly => 'Alleen lezen';

  @override
  String get unversioned => 'Geen versiebeheer';

  @override
  String get supportingFiles => 'Ondersteunende bestanden';

  @override
  String get versionDivergence => 'Versie-divergentie';

  @override
  String get healthHealthy => 'Gezond';

  @override
  String get healthMissing => 'Doel ontbreekt';

  @override
  String get healthReplaced => 'Doel vervangen';

  @override
  String get healthLocalModification => 'Lokale wijziging';

  @override
  String get healthUnreadable => 'Doel onleesbaar';

  @override
  String get healthUndeclared => 'Niet verklaard';

  @override
  String get healthWorkspaceUnreadable => 'Werkruimtestatus onleesbaar';

  @override
  String get healthLockMismatch => 'Niet-overeenkomende vergrendeling';

  @override
  String get healthUnexpectedPath => 'Onverwacht doelpad';

  @override
  String get modeSymlink => 'Symlink';

  @override
  String get modeCopy => 'Kopiëren';

  @override
  String get modeExternal => 'Extern';

  @override
  String get notLinked => 'NIET GEKOPPELD';

  @override
  String get update => 'Update';

  @override
  String get backToLibrary => 'Terug naar Bibliotheek';

  @override
  String get remove => 'Verwijderen';

  @override
  String get manageTargets => 'Beheer bereik';

  @override
  String skillsSelected(int count) {
    return '$count geselecteerd';
  }

  @override
  String get clearSelection => 'Duidelijke selectie';

  @override
  String get selectCurrentResults => 'Select huidige resultaten';

  @override
  String get clearCurrentResultSelection => 'Wis huidige resultaatselectie';

  @override
  String get manageTargetsTitle => 'Beheer installatiedoelen';

  @override
  String get manageTargetsDescription =>
      'Kies een exacte actie voor elk doelwit. Niet-geselecteerde doelen veranderen niet.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$selected van $total doelen geselecteerd';
  }

  @override
  String get repairTarget => 'Reparatie';

  @override
  String get confirmRemoveTarget => 'Bevestig verwijderen';

  @override
  String get applyTargetActions => 'Pas geselecteerde acties toe';

  @override
  String get managementProgressTitle => 'Doelacties toepassen';

  @override
  String get managementResultsTitle => 'Doelactieresultaten';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded geslaagd, $failed mislukt';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Geselecteerde projectacties zullen skillsgo.mod en skillsgo.sum bijwerken.';

  @override
  String get targetContentPreserved => 'De huidige doelinhoud blijft behouden.';

  @override
  String get localReadFailed => 'Kan deze Skill niet lezen';

  @override
  String get localReadFailedMessage =>
      'SkillsGo kon deze geïnstalleerde skill niet lezen. Controleer of de folder beschikbaar en toegankelijk is en probeer het vervolgens opnieuw.';

  @override
  String get localConfiguration => 'SKILLSGO INSTELLINGEN';

  @override
  String get settingsNavigation => 'Navigatie instellingen';

  @override
  String get general => 'Personaliseer';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Installatiebeleid';

  @override
  String get storage => 'Opslag';

  @override
  String get colorScheme => 'Kleurenschema';

  @override
  String get about => 'Over';

  @override
  String get colorSchemeInspectorTitle => 'Gegenereerde Material-kleurrollen';

  @override
  String get skillsColorTokensTitle => 'SkillsGo semantische kleuren';

  @override
  String get skillsColorTokensDescription =>
      'Productkleuren opgebouwd uit Radix Sand en georganiseerd met Primer-semantiek, met Folder als een speciale ruimtelijke hiërarchie.';

  @override
  String get colorSchemeInspectorDescription =>
      'Bekijk een voorbeeld van elk niet-verouderd ColorScheme-token dat is gegenereerd op basis van de huidige Seed. Klik op een kleur om de HEX-waarde ervan te kopiëren.';

  @override
  String get colorSchemePairPreview => 'Semantische paren';

  @override
  String get colorSchemePairPreviewDescription =>
      'Voorgrond- en achtergrondrollen worden samen weergegeven om contrast en hiërarchie bloot te leggen.';

  @override
  String get colorSchemeComponentPreview => 'Componentvoorbeeld';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Representatieve Material-besturingselementen weergegeven met dit exacte voorbeeldschema.';

  @override
  String get colorSchemeSampleTitle => 'Skill-kaarttitel';

  @override
  String get colorSchemeSampleBody =>
      'Secundaire kopie maakt gebruik van onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Gekopieerd';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Primair';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Primaire nadruk, containers en rollen met vaste accenten.';

  @override
  String get colorSchemeGroupSecondary => 'Secundair';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Ondersteunende nadruk en vaste nevenrollen.';

  @override
  String get colorSchemeGroupTertiary => 'Tertiair';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Contrasterende accenten en vaste tertiaire rollen.';

  @override
  String get colorSchemeGroupSurface => 'Oppervlak';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Pagina-, container-, hoogte- en voorgrondhiërarchie.';

  @override
  String get colorSchemeGroupUtility => 'Overzicht en bruikbaarheid';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Grenzen, schaduwen, gaasdoeken en omgekeerde oppervlakken.';

  @override
  String get colorSchemeGroupError => 'Fout';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Foutacties, berichten en containers.';

  @override
  String get colorSchemeUsagePrimary =>
      'Primaire acties, focus en accenten met hoge nadruk.';

  @override
  String get colorSchemeUsageSecondary =>
      'Ondersteunende acties en accenten met gemiddelde nadruk.';

  @override
  String get colorSchemeUsageTertiary =>
      'Contrasterende accenten die primair en secundair aanvullen.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Tekst en pictogrammen weergegeven op $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return '$family-container met lagere nadruk voor selecties en accenten.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Helderheidsonafhankelijke vaste $family-container.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Gedimde helderheidsonafhankelijke vaste $family-container.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Inhoud met hoge nadruk op de vaste $family-container.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Inhoud met minder nadruk op de vaste $family-container.';
  }

  @override
  String get colorSchemeUsageSurface => 'Basispagina en groot oppervlak.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Gedimd basisoppervlak gebruikt in de donkerste oppervlaktetint.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Helder basisoppervlak gebruikt in de lichtste oppervlaktetint.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'De $level-oppervlaktecontainerverhoging.';
  }

  @override
  String get colorSchemeElevationLowest => 'laagste';

  @override
  String get colorSchemeElevationLow => 'laag';

  @override
  String get colorSchemeElevationDefault => 'standaard';

  @override
  String get colorSchemeElevationHigh => 'hoog';

  @override
  String get colorSchemeElevationHighest => 'hoogste';

  @override
  String get colorSchemeUsageOnSurface =>
      'Primaire tekst en pictogrammen weergegeven op oppervlakken.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Secundaire tekst, labels en ingetogen pictogrammen op oppervlakken.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Material elevatietint afgeleid van primair.';

  @override
  String get colorSchemeUsageOutline =>
      'Duidelijke grenzen en gerichte componentcontouren.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Subtiele grenzen, scheidingslijnen en contouren met weinig nadruk.';

  @override
  String get colorSchemeUsageShadow =>
      'Slagschaduwkleur voor verhoogde oppervlakken.';

  @override
  String get colorSchemeUsageScrim =>
      'Modale overlay die wordt gebruikt om achtergrondinhoud minder te benadrukken.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Oppervlak met omgekeerde lichte en donkere accenten.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Primair accent weergegeven op een omgekeerd oppervlak.';

  @override
  String get colorSchemeUsageError =>
      'Foutacties, status en feedback met hoge nadruk.';

  @override
  String get save => 'Redden';

  @override
  String get advancedSettings => 'Geavanceerd';

  @override
  String get remindersSettings => 'Herinneringen';

  @override
  String get remindersSettingsTitle => 'Herinneringsinstellingen';

  @override
  String get remindersSettingsDescription =>
      'Kies welke herinneringen u wilt ontvangen.';

  @override
  String get updateReminderTitle => 'Herinneringen bijwerken';

  @override
  String get updateReminderDescription =>
      'Controleer op updates wanneer de bibliotheek wordt geopend.';

  @override
  String get securityReminderTitle => 'Waarschuwingen met hoog risico';

  @override
  String get securityReminderDescription =>
      'Houdt u op de hoogte van nieuwe hoge of kritieke risico\'s in geïnstalleerde skills.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count geïnstalleerd skills heeft updates';
  }

  @override
  String get openAvailableUpdates =>
      'Open de weergave met beschikbare updates om ze te bekijken en bij te werken.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count geïnstalleerd skills heeft een beveiligingsbeoordeling nodig';
  }

  @override
  String get reviewInstalledSkills =>
      'Controleer hun risico-informatie voordat u deze gebruikt of bijwerkt.';

  @override
  String get generalSettingsTitle => 'Maak SkillsGo van jou';

  @override
  String get generalSettingsDescription =>
      'De interface volgt uw systeemtaal, toegankelijkheid en bewegingsvoorkeuren.';

  @override
  String get agentsSettingsTitle => 'Agent-runtime';

  @override
  String get hubSettingsTitle => 'Hub Oorsprong';

  @override
  String get hubSettingsDescription =>
      'Gebruik de officiële Hub of een zelf-gehoste HTTP(S)-oorsprong die hetzelfde SkillsGo-protocol implementeert.';

  @override
  String get testConnection => 'Verbinding testen';

  @override
  String get saveOrigin => 'Bewaar oorsprong';

  @override
  String get resetDefault => 'Resetten naar standaard';

  @override
  String get connectionReady => 'Verbinding gereed';

  @override
  String get connectionFailed => 'Verbinding mislukt';

  @override
  String get hubInvalidOrigin =>
      'Voer een geldige HTTP(S)-oorsprong in zonder inloggegevens, een query of een fragment.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub heeft HTTP $status geretourneerd. Controleer de Origin- en serverconfiguratie.';
  }

  @override
  String get hubInvalidProtocol =>
      'De server heeft het zoekprotocol SkillsGo Hub niet geretourneerd.';

  @override
  String get hubInvalidJson => 'De Hub heeft een ongeldige JSON geretourneerd.';

  @override
  String get hubConnectionFailure =>
      'Kon de Hub niet bereiken. Controleer de Origin-, netwerk-, proxy- en TLS-configuratie.';

  @override
  String get hubConnectionTimeout =>
      'Er is een time-out opgetreden bij de Hub-verbinding. Controleer het netwerk of probeer het opnieuw.';

  @override
  String get riskPolicyTitle => 'Persoonlijk risicobeleid';

  @override
  String get riskPolicyDescription =>
      'Bij het installeren of updaten van een skill zijn veiligheidsregels van toepassing.';

  @override
  String get confirmHighRisk => 'Bevestiging vereist voor Hoog risico';

  @override
  String get confirmHighRiskDescription =>
      'Voor artefacten met een hoog risico is vóór de installatie altijd een aanvullende bevestiging vereist.';

  @override
  String get allowCriticalOverride =>
      'Sta een expliciete overschrijving van kritieke risico\'s toe';

  @override
  String get allowCriticalOverrideDescription =>
      'Artefacten met een kritiek risico blijven standaard geblokkeerd. Schakel dit alleen in om een ​​afzonderlijke handmatige overschrijving beschikbaar te maken.';

  @override
  String get storageSettingsTitle => 'Op inhoud gerichte winkel';

  @override
  String get storageHealthy => 'Leesbaar';

  @override
  String get storageNotInitialized => 'Niet geïnitialiseerd';

  @override
  String get storageUnavailable => 'Niet beschikbaar';

  @override
  String get storagePathUnavailable =>
      'Winkelpad niet beschikbaar totdat de CLI-diagnostiek gereed is.';

  @override
  String get storageHealthyDescription =>
      'De CLI kan de Store lezen zonder de inhoud ervan te wijzigen.';

  @override
  String get storageNotInitializedDescription =>
      'De Store bestaat nog niet en is door deze controle niet aangemaakt.';

  @override
  String get storageUnavailableDescription =>
      'De CLI kan de Store niet lezen. Controleer de machtigingen en de bovenliggende map.';

  @override
  String get storageInvalidResponse =>
      'De gebundelde CLI retourneerde een niet-ondersteund diagnostisch antwoord.';

  @override
  String get aboutSettingsTitle => 'Productcompatibiliteit';

  @override
  String get appVersion => 'App-versie';

  @override
  String get cliVersion => 'Gebundelde CLI-versie';

  @override
  String get compatible => 'Verenigbaar';

  @override
  String get hubOriginSaved => 'Hub Oorsprong opgeslagen en toegepast.';

  @override
  String get policySaved => 'Installatiebeleid opgeslagen.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'KLAAR';

  @override
  String get unknown => 'ONBEKEND';

  @override
  String get missing => 'VERMIST';

  @override
  String get incompatible => 'ONVERENIGBAAR';

  @override
  String get detecting => 'Detecteren…';

  @override
  String get customCliPath => 'Aangepast uitvoerbaar pad';

  @override
  String get saveAndDetect => 'Opslaan en detecteren';

  @override
  String get detectAgain => 'Opnieuw detecteren';

  @override
  String get agentInstalled => 'Geïnstalleerd';

  @override
  String get agentSupported => 'Ondersteund';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed geïnstalleerd · $supported ondersteund';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Geïnstalleerd · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Niet geïnstalleerd · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Ondersteund door SkillsGo, maar niet gedetecteerd op deze Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Skill laadpaden: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Agent-detectiegegevens zijn niet beschikbaar. Voer de detectie opnieuw uit.';

  @override
  String get noInstalledAgentsTitle =>
      'Geen geïnstalleerde Agents gedetecteerd';

  @override
  String get noInstalledAgentsMessage =>
      'U kunt door deze Skill blijven bladeren, maar er is nog geen installatiedoel. Installeer een ondersteunde Agent en voer de detectie opnieuw uit.';

  @override
  String get clearCustomPath => 'Aangepast pad wissen';

  @override
  String get privacyProvenance => 'Privacy & herkomst';

  @override
  String get privacySummary =>
      'Uw zoekopdrachten worden niet opgeslagen en SkillsGo houdt geen opdrachtlogboeken bij.';

  @override
  String get language => 'Taal';

  @override
  String get personalizationTheme => 'Thema';

  @override
  String get folderColorTheme => 'Thema kleur';

  @override
  String get folderColorThemeDescription =>
      'Kies een kleur die je mooi vindt. SkillsGo zal er een gecoördineerd interfacepalet omheen bouwen.';

  @override
  String get brandNameNeteaseCloudMusic => 'NetEase Cloud-muziek';

  @override
  String get brandNameRaspberryPi => 'Framboos Pi';

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
      'Volg het uiterlijk van uw systeem of gebruik altijd een licht of donker thema.';

  @override
  String get followSystem => 'Systeem';

  @override
  String get lightMode => 'Licht';

  @override
  String get darkMode => 'Donker';

  @override
  String get wallpaper => 'Behang';

  @override
  String get wallpaperDescription =>
      'Kies een hemelse achtergrond. Uw selectie verschijnt direct achter Folder.';

  @override
  String get wallpaperSun => 'Zon';

  @override
  String get wallpaperMercury => 'Kwik';

  @override
  String get wallpaperVenus => 'Venus';

  @override
  String get wallpaperEarth => 'Aarde';

  @override
  String get wallpaperMars => 'Mars';

  @override
  String get wallpaperJupiter => 'Jupiter';

  @override
  String get wallpaperSaturn => 'Saturnus';

  @override
  String get wallpaperUranus => 'Uranus';

  @override
  String get wallpaperNeptune => 'Neptunus';

  @override
  String get wallpaperPluto => 'Pluto';

  @override
  String get wallpaperMoon => 'Maan';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Folder-thema';
  }

  @override
  String get privacyAffiliation =>
      'Anonieme installatietelemetrie wordt beheerd door de SkillsGo-instellingen. SkillsGo is niet aangesloten bij OpenAI of Codex.';

  @override
  String get commandCompleted => 'Commando voltooid';

  @override
  String get commandFailed => 'Commando mislukt';

  @override
  String commandExit(int code) {
    return 'Sluit $code af · vouw uit voor het logboek van deze sessie';
  }

  @override
  String get command => 'Commando';

  @override
  String get cancel => 'Annuleren';

  @override
  String get updateUnknown => 'ONBEKEND';

  @override
  String get updateChecking => 'CONTROLEREN';

  @override
  String get upToDate => 'UP-TO-DATE';

  @override
  String get updateAvailable => 'UPDATE';

  @override
  String get updateUnavailable => 'NIET BESCHIKBAAR';

  @override
  String get updateCheckFailed => 'CONTROLE MISLUKT';

  @override
  String get installSkill => 'Installeer Skill';

  @override
  String get installLocationTitle => 'Installatielocatie instellen';

  @override
  String get userLevel => 'Gebruikersniveau';

  @override
  String get projectLevel => 'Projectniveau';

  @override
  String get projects => 'Projecten';

  @override
  String get loading => 'Laden…';

  @override
  String get repositoryParsing => 'Repository parseren…';

  @override
  String userInstallSummary(int agents) {
    return 'Beschikbaar voor $agents Agents op gebruikersniveau';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects-projecten · $agents Agents';
  }

  @override
  String get installationResults => 'Installatieresultaten';

  @override
  String get installationInProgress => 'Installatie wordt uitgevoerd';

  @override
  String get installationSucceeded => 'Installatie voltooid';

  @override
  String get installationSucceededMessage =>
      'De Skill is nu beschikbaar op de geselecteerde locaties.';

  @override
  String get projectUnavailable => 'Project niet beschikbaar';

  @override
  String get installedCell => 'Geïnstalleerd';

  @override
  String get unsupportedCell => 'Niet beschikbaar';

  @override
  String get confirmInstall => 'Bevestig de installatie';

  @override
  String installAllRepositorySkills(int count) {
    return 'Installeer alle repository skills ($count)';
  }

  @override
  String get installAllSkillsTo => 'Installeer alle skills op';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Installeer alle $repository skills ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Installeer $skill op';
  }

  @override
  String get availableInAllProjects => 'Alle projecten';

  @override
  String get availableInSelectedProjects => 'Geselecteerde projecten';

  @override
  String get usedBy => 'Voor Agents';

  @override
  String get backToTargets => 'Terug naar Doelen';

  @override
  String get stayHere => 'Blijf hier';

  @override
  String get viewInLibrary => 'Bekijk in Bibliotheek';

  @override
  String planCreateCount(int count) {
    return '$count maken';
  }

  @override
  String planSkipCount(int count) {
    return '$count overslaan';
  }

  @override
  String planReplaceCount(int count) {
    return '$count vervangen';
  }

  @override
  String planConflictCount(int count) {
    return '$count-conflict';
  }

  @override
  String planRiskCount(int count) {
    return '$count-risico geblokkeerd';
  }

  @override
  String get refreshInstallationPlan => 'Resoluties toepassen';

  @override
  String get replaceVersionConflict =>
      'Vervang de geïnstalleerde versie op dit doel';

  @override
  String get replaceSkillIdCollision =>
      'Vervang de verschillende Skill ID op dit doel';

  @override
  String get replaceLocalModification =>
      'Gooi lokale wijzigingen weg en vervang dit doel';

  @override
  String get sharedTargetConflict =>
      'Dit pad wordt gedeeld door other Agent-doelen';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Keer terug naar de doelmatrix en select elke betrokken Agent voordat u deze vervangt: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Vervang het conflicterende doel';

  @override
  String get confirmHighRiskArtifact =>
      'Bevestiging van artefacten met hoog risico';

  @override
  String get confirmCriticalRiskArtifact =>
      'Bevestiging van overschrijven van kritiek risico';

  @override
  String get confirmRiskForSelectedTargets =>
      'Ik heb de artefactbestanden beoordeeld en accepteer dit risico voor de geselecteerde doelen';

  @override
  String get criticalRiskBlocked =>
      'Installatie met een kritiek risico is geblokkeerd';

  @override
  String get criticalRiskOverrideDisabled =>
      'Schakel de expliciete overschrijving van kritieke risico\'s in Instellingen in voordat dit plan kan worden voortgezet.';

  @override
  String get workspaceManifestChanges => 'Werkruimte Duidelijke veranderingen';

  @override
  String get noWorkspaceManifestChanges =>
      'Er worden geen Workspace Manifest-bestanden gewijzigd.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'niet aanwezig';

  @override
  String get planActionCreate => 'Creëren';

  @override
  String get planActionReplace => 'Vervangen';

  @override
  String get planActionSkip => 'Overslaan';

  @override
  String get planActionConflict => 'Conflict';

  @override
  String get planActionBlockedByRisk => 'Geblokkeerd door risico';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded-doelen geïnstalleerd, $failed mislukt';
  }

  @override
  String get installationProgressTitle => 'Installatie wordt uitgevoerd';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished van $total-doelen voltooid';
  }

  @override
  String get targetWaiting => 'Wachten';

  @override
  String get targetRunning => 'Installeren';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opnieuw proberen mislukte doelen',
      one: '1 mislukt doel opnieuw proberen',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Select-doelen om te updaten';

  @override
  String get updatePlanDescription =>
      'Kies exacte installatiedoelen. Niet-geselecteerde Agents en projecten blijven ongewijzigd.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected van $available-bijwerkbare doelen geselecteerd';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Bronreferentie: $reference';
  }

  @override
  String get fixedVersionTarget => 'Vastgezet - geen verplaatsbare referentie';

  @override
  String get currentVersionTarget => 'Up-to-date';

  @override
  String get updateCheckTargetFailed => 'Updatecontrole mislukt';

  @override
  String get reconcileWorkspaceManifestTarget => 'Werkruimtemanifest repareren';

  @override
  String get updateSelectedTargets => 'Geselecteerde doelen bijwerken';

  @override
  String get updateProgressTitle => 'Doelen bijwerken';

  @override
  String get updateResultsTitle => 'Resultaten bijwerken';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished van $total-doelen voltooid';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opnieuw proberen, mislukte updates',
      one: '1 keer opnieuw proberen, mislukte update',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Voor geen enkel geselecteerd doel is een update beschikbaar.';

  @override
  String get closeUpdatePlan => 'Dichtbij';

  @override
  String get targetSucceeded => 'Geïnstalleerd';

  @override
  String get targetSkipped => 'Overgeslagen';

  @override
  String get targetConflict => 'Conflict';

  @override
  String get targetFailed => 'Mislukt';

  @override
  String get targetFailureRetryable =>
      'Deze locatie kon niet worden gewijzigd. Je kunt het opnieuw proberen.';

  @override
  String get targetFailureNeedsAttention =>
      'Deze locatie heeft uw aandacht nodig voordat u het opnieuw probeert.';

  @override
  String get installationTargetFailureMessage =>
      'Op deze locatie is niets veranderd. Controleer of de folder beschikbaar is en probeer het opnieuw.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Er is niets gewijzigd omdat SkillsGo de projectinstellingen niet kon opslaan. Controleer of het project folder schrijfbaar is en probeer het opnieuw.';

  @override
  String get installationStateChangedMessage =>
      'Deze locatie is gewijzigd terwijl u deze beoordeelde. Controleer de laatste status voordat u het opnieuw probeert.';

  @override
  String get updateTargetFailureMessage =>
      'Deze locatie kan niet worden bijgewerkt. Other-locaties zijn niet beïnvloed, dus u kunt alleen deze opnieuw proberen.';

  @override
  String get managementTargetFailureMessage =>
      'Deze actie kan hier niet worden voltooid. Other-locaties zijn niet beïnvloed, dus u kunt alleen deze opnieuw proberen.';

  @override
  String get technicalDetails => 'Technische details';

  @override
  String get targetPathExists =>
      'Er bestaat al een ander item op deze locatie.';

  @override
  String get targetBlockedByRisk =>
      'Uw huidige veiligheidsinstellingen hebben de installatie op deze locatie geblokkeerd.';

  @override
  String get targetInstallFailed =>
      'De skill kon op deze locatie niet worden geïnstalleerd.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'De skill is geïnstalleerd, maar de projectinstellingen kunnen niet worden bijgewerkt.';

  @override
  String get installationPlanFailed => 'Installatieplan kon niet doorgaan';

  @override
  String get installationFailed => 'De installatie kon niet worden voltooid';

  @override
  String get localSource => 'Lokale bron';

  @override
  String get noDescriptionAvailable => 'Geen beschrijving beschikbaar';

  @override
  String moreCoverage(int count) {
    return '+$count meer locaties';
  }

  @override
  String get batchTakeoverAction => 'Beheer bestaande skills';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Beheren ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Bestaande skills controleren…';

  @override
  String get batchTakeoverRetry => 'Controleer de beheersbare skills opnieuw';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count kan worden beheerd';
  }

  @override
  String get batchTakeoverPending => 'skills toevoegen aan beheer...';

  @override
  String get batchTakeoverTitle => 'Bestaande skills beheren met SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo voegt lokale beheerrecords toe zonder skill-bestanden te verplaatsen, overschrijven of uploaden. Niet-ondersteunde of gewijzigde items worden overgeslagen.';

  @override
  String get batchTakeoverStoryTitle =>
      'Verander verspreide skills in één overzichtelijke bibliotheek';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bestaande skills',
      one: '1 bestaande skill',
    );
    return 'SkillsGo heeft $_temp0 gevonden die hij op deze locatie kan beheren.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Voor het management is het onduidelijk waar bestaande skills zijn geïnstalleerd, of ze actueel zijn, hoe ze kunnen worden hersteld en of projecten dezelfde versie gebruiken.';

  @override
  String get batchTakeoverPainLocation => 'Onbekende installatielocatie';

  @override
  String get batchTakeoverPainFreshness => 'Onbekende updatestatus';

  @override
  String get batchTakeoverPainRecovery => 'Geen herstel bij breuk';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Verschillende versies voor projecten';

  @override
  String get batchTakeoverFolderTitle => 'Bestaande Skills';

  @override
  String get batchTakeoverFolderSubtitle => 'Onduidelijke status';

  @override
  String get batchTakeoverAfterLabel => 'NA';

  @override
  String get batchTakeoverAfterTitle => 'Eén duidelijke bibliotheek';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo-bibliotheek';

  @override
  String get batchTakeoverBenefitLocation => 'Duidelijke locaties';

  @override
  String get batchTakeoverBenefitFreshness => 'Updates zichtbaar';

  @override
  String get batchTakeoverBenefitRecovery => 'Gemakkelijk herstel';

  @override
  String get batchTakeoverBenefitVersions => 'Versies duidelijk';

  @override
  String get batchTakeoverManagedSection => 'Beheerd door SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'In behandeling';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name wordt beheerd door SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name kan niet worden toegevoegd aan het beheer';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name wacht op beheer';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills zijn',
      one: '1 skill is',
    );
    return 'Na beheer is $_temp0 georganiseerd in één bibliotheek met een duidelijke beheerde status.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count meer';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Voeg deze bestaande skills toe aan het SkillsGo-beheer.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANISEREN';

  @override
  String get batchTakeoverStatusTitle => 'Beheerstatus';

  @override
  String get batchTakeoverStatusManaged => 'Beheerd';

  @override
  String get batchTakeoverStatusProgress => 'Organiseren';

  @override
  String get batchTakeoverStatusSkipped => 'Overgeslagen';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Skill-bestanden blijven op hun oorspronkelijke locatie';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills worden in volledige rijen gerangschikt en opgenomen door SkillsGo zonder de bestanden te verplaatsen.';

  @override
  String get batchTakeoverBoardComplete => 'ALLES DUIDELIJK';

  @override
  String get batchTakeoverBoardPartial => 'COMPLEET';

  @override
  String get batchTakeoverStatusTotal => 'Totaal';

  @override
  String get batchTakeoverQueueComplete => 'Er wachten geen skills';

  @override
  String get batchTakeoverQueueWaiting =>
      'Na verificatie worden de Skills hier weergegeven';

  @override
  String get batchTakeoverNextLabel => 'VOLGENDE';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo organisatorblokken',
      one: '1 SkillsGo organisatorblok',
    );
    return '$_temp0 voltooi de laatste rijen';
  }

  @override
  String get batchTakeoverPreservation =>
      'Uw bestanden, paden en huidige workflows blijven precies waar ze zijn. SkillsGo vult alleen de lokale managementadministratie in.';

  @override
  String get batchTakeoverLaterHint =>
      'Als u dit overslaat, kunt u op elk gewenst moment Bestaande skills vanuit Bibliotheek beheren gebruiken.';

  @override
  String get batchTakeoverSkip => 'Niet nu';

  @override
  String get batchTakeoverConfirm => 'Voeg toe aan beheer';

  @override
  String get batchTakeoverExecutionRetry => 'Opnieuw proberen';

  @override
  String get batchTakeoverResultTitle => 'Skills toegevoegd aan beheer';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver skills toegevoegd aan beheer, $skipped overgeslagen.';
  }

  @override
  String get batchTakeoverClose => 'Sluiten';

  @override
  String get installMoreTargets => 'Installeer op meer locaties';

  @override
  String get exportLocalSkill => 'Exporteren';

  @override
  String get exportLocalSkillDescription =>
      'Exporteer deze lokale Skill als een draagbaar ZIP-archief.';

  @override
  String get detailRepository => 'Opslagplaats';

  @override
  String get detailStars => 'Sterren';

  @override
  String get detailUpdated => 'Bijgewerkt';

  @override
  String get detailArchiveSize => 'ZIP-formaat';

  @override
  String get pathLabel => 'Projectpad';

  @override
  String get copyProjectPath => 'Kopieer het projectpad';

  @override
  String get projectPathCopied => 'Projectpad gekopieerd';

  @override
  String get onboardingWelcomeTitle => 'Welkom bij SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Ontdek, installeer en beheer Skills voor uw Agents en projecten.';

  @override
  String get onboardingDetectedAgents => 'Agents gedetecteerd';

  @override
  String get onboardingNoAgents =>
      'Geen geïnstalleerde Agents gedetecteerd. Je kunt nog steeds doorgaan.';

  @override
  String get onboardingNext => 'Volgende';

  @override
  String get onboardingProjectsTitle => 'Voeg uw projecten toe';

  @override
  String get onboardingProjectsDescription =>
      'Kies de projecten die u door SkillsGo wilt laten beheren.';

  @override
  String get onboardingAddProject => 'Voeg nu toe';

  @override
  String get onboardingAddProjectLater => 'of later';

  @override
  String get onboardingStartUsing => 'Begin met het gebruik van SkillsGo';

  @override
  String get onboardingBack => 'Rug';

  @override
  String get restartOnboardingTitle => 'Aan boord';

  @override
  String get restartOnboardingDescription =>
      'Bekijk de eerste lanceringshandleiding opnieuw zonder projecten, instellingen of Skills-gegevens te verwijderen.';

  @override
  String get restartOnboardingAction => 'Start de onboarding opnieuw';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo kan de onboarding niet opnieuw starten.';

  @override
  String get libraryRefreshSettingsTitle => 'Vernieuw de lokale bibliotheek';

  @override
  String get libraryRefreshSettingsDescription =>
      'Scan de geïnstalleerde Skills, toegevoegde projecten, Agents en externe Skills die kunnen worden beheerd opnieuw. Hiermee wordt niets geïnstalleerd, bijgewerkt of verwijderd.';

  @override
  String get libraryRefreshSettingsAction => 'Bibliotheek vernieuwen';

  @override
  String get libraryRefreshSettingsPending => 'Bibliotheek vernieuwen...';

  @override
  String get libraryRefreshSettingsSuccess => 'Lokale bibliotheek vernieuwd.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo kan de lokale bibliotheek niet vernieuwen.';

  @override
  String get onboardingProjectError =>
      'SkillsGo kan geen projecten uit deze map toevoegen.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo kan uw toegevoegde projecten niet laden.';

  @override
  String get onboardingStartupError =>
      'SkillsGo kan de installatie niet laden.';

  @override
  String get onboardingStateError =>
      'SkillsGo kan uw installatievoortgang niet opslaan. Probeer het opnieuw.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI heeft aandacht nodig';

  @override
  String get onboardingCliErrorDescription =>
      'Repareer de gebundelde CLI en probeer opnieuw door te gaan.';
}
