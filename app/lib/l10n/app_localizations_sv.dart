// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get discover => 'Upptäcka';

  @override
  String get discoverSkills => 'Det är bra att veta lite mer.';

  @override
  String get library => 'Bibliotek';

  @override
  String get settings => 'Inställningar';

  @override
  String get openSettings => 'Öppna Inställningar';

  @override
  String get cliNeedsAttention =>
      'En nödvändig SkillsGo-komponent behöver åtgärdas.';

  @override
  String get cliMissingBundled =>
      'En obligatorisk SkillsGo-komponent saknas eller kan inte startas. Installera om SkillsGo för att återställa den.';

  @override
  String get cliDamagedBundled =>
      'En nödvändig SkillsGo-komponent är skadad. Installera om SkillsGo för att återställa den.';

  @override
  String get cliIncompatibleBundled =>
      'En obligatorisk SkillsGo-komponent matchar inte denna appversion. Uppdatera eller installera om SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Hitta en skill för ditt nästa drag.';

  @override
  String get skillsLeaderboard => 'Det är bra att veta lite mer.';

  @override
  String searchResultsFor(String query) {
    return 'Resultat för “$query”';
  }

  @override
  String get searchSkills => 'Sök i skills eller klistra in en Git-länk...';

  @override
  String get search => 'Söka';

  @override
  String get ranking => 'Ranking';

  @override
  String get trending => 'Trendigt';

  @override
  String get hot => 'Varm';

  @override
  String get discoverNavigation => 'Upptäck navigering';

  @override
  String get allTimeRanking => 'Alla tiders ranking';

  @override
  String get trendingNow => 'Trender under de senaste 24 timmarna';

  @override
  String get hotNow => 'Hett just nu';

  @override
  String get allTimeDescription =>
      'Offentliga Skills sorterade efter totalt antal godkända installationer.';

  @override
  String get trendingDescription =>
      'Offentliga Skills sorterade efter godkända installationer under de senaste 24 timmarna.';

  @override
  String get hotDescription =>
      'Offentliga Skills sorterade efter den senaste installationstakten och dess förändring.';

  @override
  String get offlineTitle => 'Kan inte ansluta till SkillsGo';

  @override
  String get offlineMessage =>
      'Kontrollera din internetanslutning och försök igen. Om du använder en proxy- eller anpassad tjänstadress, granska den i Inställningar.';

  @override
  String get searchFailedTitle => 'Sökningen misslyckades';

  @override
  String get validationTitle => 'Kontrollera vad du skrivit in';

  @override
  String get validationMessage =>
      'SkillsGo kunde inte använda denna begäran. Granska vad du angav och försök igen.';

  @override
  String get serverTitle => 'Tjänsten är tillfälligt otillgänglig';

  @override
  String get serverMessage =>
      'SkillsGo kan inte slutföra denna begäran just nu. Försök igen om ett ögonblick.';

  @override
  String get timeoutTitle => 'Det här tar för lång tid';

  @override
  String get timeoutMessage =>
      'Tjänsten svarade inte i tid. Kontrollera din anslutning eller försök igen.';

  @override
  String get invalidResponseTitle => 'SkillsGo behöver en uppdatering';

  @override
  String get invalidResponseMessage =>
      'Detta svar kan inte läsas av din version av SkillsGo. Uppdatera appen och försök sedan igen.';

  @override
  String get invalidLocalDataTitle => 'Kan inte läsa en installerad skill';

  @override
  String get invalidLocalDataMessage =>
      'Viss lokal installationsinformation är skadad eller inkompatibel. Uppdatera eller installera om SkillsGo och försök sedan igen.';

  @override
  String get tryAgain => 'Försök igen';

  @override
  String get searchEmptyTitle => 'Sök, rulla inte.';

  @override
  String get searchEmptyMessage =>
      'Ange en förmåga, källa eller uppgift för att söka offentliga skills.';

  @override
  String get noSkillsTitle => 'Ingen skills hittades';

  @override
  String get noSkillsMessage =>
      'Prova en bredare fras eller kontrollera stavningen.';

  @override
  String get focusSearch => 'Fokus sökning';

  @override
  String get skillsFromLink => 'Skills från denna länk';

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
      other: '$count skills från $source',
      one: '1 skill från $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Denna länk är redo att inspekteras';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source finns inte i de aktuella sökresultaten. SkillsGo kan inspektera länken direkt i nästa steg.';
  }

  @override
  String get inspectSource => 'Se skills i denna länk';

  @override
  String get collectionEmptyTitle => 'Ingen Skills i denna samling';

  @override
  String get collectionEmptyMessage =>
      'Det finns inget här ännu. Försök igen efter mer installationsaktivitet.';

  @override
  String get loadMore => 'Ladda mer';

  @override
  String get install => 'Installera';

  @override
  String get installAll => 'Installera alla skills';

  @override
  String get latestCommit => 'Senaste commit';

  @override
  String get installToMoreTargets => 'Installera på fler platser';

  @override
  String localTargets(int count) {
    return '$count lokala mål';
  }

  @override
  String allTimeMetric(String count) {
    return '$count installationer genom tiderna';
  }

  @override
  String trendingMetric(String count) {
    return '$count installerar / 24h';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value denna timme · $change';
  }

  @override
  String get trustUnverified => 'Ej verifierad';

  @override
  String get trustCommunityVerified => 'Gemenskapen verifierad';

  @override
  String get trustPublisherVerified => 'Utgivare verifierad';

  @override
  String get trustOfficial => 'Officiell';

  @override
  String get trustWarned => 'Varnade';

  @override
  String get trustDelisted => 'Avnoterad';

  @override
  String get riskUnknown => 'Risk okänd';

  @override
  String get riskLow => 'Låg risk';

  @override
  String get riskMedium => 'Medium risk';

  @override
  String get riskHigh => 'Hög risk';

  @override
  String get riskCritical => 'Kritisk risk';

  @override
  String openSkill(String name) {
    return 'Öppna $name';
  }

  @override
  String installs(String count) {
    return '$count installeras';
  }

  @override
  String get detailFailedTitle => 'Det gick inte att ladda denna Skill';

  @override
  String get detailLoading => 'Laddar granskningsbar Skill-detalj';

  @override
  String get artifactUnavailableTitle => 'Artefakt inte tillgänglig';

  @override
  String get artifactUnavailableMessage =>
      'Denna version är inte tillgänglig just nu. Försök igen eller välj en annan version.';

  @override
  String get detailInvalidTitle => 'Artefaktmetadata stöds inte';

  @override
  String get detailInvalidMessage =>
      'Vissa detaljer för denna skill är ofullständiga eller kan inte läsas. Uppdatera SkillsGo och försök sedan igen.';

  @override
  String get instructionsTab => 'Instruktioner';

  @override
  String get manifestTab => 'Manifestera';

  @override
  String immutableVersionLabel(String version) {
    return 'Oföränderlig $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Beslut $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Träd $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Innehåll $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Utgivarens förtroende verifierar ägande eller underhåll; den intygar inte artefaktsäkerhet. Risk bedöms separat för denna oföränderliga version.';

  @override
  String get knownInstallationTargets => 'Kända installationsmål';

  @override
  String get installationRange => 'Installerad omfattning';

  @override
  String get targetDetails => 'Visa måldetaljer';

  @override
  String get hideTargetDetails => 'Dölj måldetaljer';

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
  String get fileContentUnavailable =>
      'Binär eller otillgänglig förhandsvisning';

  @override
  String get fileContentTruncated =>
      'Förhandsvisning trunkerad av Hub säkerhetsgräns.';

  @override
  String get retry => 'Försöka igen';

  @override
  String get backToSearch => 'Tillbaka till sökning';

  @override
  String get installForCodex => 'Installera för Codex';

  @override
  String get cliNotDetected => 'skills (ej upptäckt)';

  @override
  String get snapshotFiles => 'Snapshot-filer';

  @override
  String get globalCodex => 'Globalt · Codex';

  @override
  String get yourLibrary => 'Allt du vet finns här.';

  @override
  String get libraryNavigation => 'Biblioteksnavigering';

  @override
  String get all => 'Alla';

  @override
  String get allSkills => 'Alla Skills';

  @override
  String get updatesOnly => 'Uppdateringar';

  @override
  String get allAgents => 'Alla Agents';

  @override
  String get allProjects => 'Alla projekt';

  @override
  String get specificProject => 'Projekt';

  @override
  String get userScope => 'Global';

  @override
  String get addProject => 'Lägg till projekt';

  @override
  String get relocateProject => 'Förflytta';

  @override
  String get removeFromList => 'Ta bort från listan';

  @override
  String removeProjectTitle(String name) {
    return 'Ta bort $name från SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Endast appreferensen kommer att tas bort. SkillsGo kommer inte att ändra eller ta bort några filer i den här katalogen.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — ej tillgänglig';
  }

  @override
  String get emptyProjectTitle => 'Ingen Skills än';

  @override
  String get browseSkills => 'Bläddra i Skills';

  @override
  String get projectMissingTitle => 'Projektkatalog saknas';

  @override
  String get projectMissingMessage =>
      'Katalogen kan ha flyttats eller dess volym kan vara offline. Flytta den eller ta bort endast dess appreferens.';

  @override
  String get projectPermissionTitle => 'Projekttillstånd krävs';

  @override
  String get projectPermissionMessage =>
      'SkillsGo kan inte inspektera denna valda rot. Ge åtkomst genom att flytta den via katalogväljaren.';

  @override
  String get projectInaccessibleTitle => 'Projektkatalogen är otillgänglig';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo behöll denna projektreferens. Kontrollera sökvägen eller volymen och flytta den sedan.';

  @override
  String get checking => 'Kontroll…';

  @override
  String get checkUpdates => 'Kontrollera uppdateringar';

  @override
  String get refresh => 'Uppdatera';

  @override
  String get libraryUnavailable => 'Biblioteket är inte tillgängligt';

  @override
  String get libraryEmpty => 'Ingen skills installerad än';

  @override
  String get libraryEmptyMessage =>
      'Installera en Skill från Discover så visas den här.';

  @override
  String get searchLibrary => 'Sök installerade skills';

  @override
  String get libraryNoMatches => 'Ingen matchande Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Prova ett annat namn, källa, Agent, projekt eller version.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return '$count-projekt';
  }

  @override
  String versionsSummary(int count) {
    return '$count versioner';
  }

  @override
  String get hubManaged => 'Hub hanteras';

  @override
  String get localManaged => 'Lokalt skött';

  @override
  String get externalInstallation => 'Extern installation';

  @override
  String get readOnly => 'Endast läs';

  @override
  String get unversioned => 'Oversionerad';

  @override
  String get supportingFiles => 'Stödfiler';

  @override
  String get versionDivergence => 'Versionsavvikelse';

  @override
  String get healthHealthy => 'Hälsosam';

  @override
  String get healthMissing => 'Mål saknas';

  @override
  String get healthReplaced => 'Mål bytt';

  @override
  String get healthLocalModification => 'Lokal modifiering';

  @override
  String get healthUnreadable => 'Mål oläsligt';

  @override
  String get healthUndeclared => 'Ej deklarerad';

  @override
  String get healthWorkspaceUnreadable => 'Arbetsytans tillstånd oläsligt';

  @override
  String get healthLockMismatch => 'Låset matchar inte';

  @override
  String get healthUnexpectedPath => 'Oväntad målväg';

  @override
  String get modeExternal => 'Extern';

  @override
  String get notLinked => 'EJ LÄNKAD';

  @override
  String get update => 'Uppdatera';

  @override
  String get backToLibrary => 'Tillbaka till biblioteket';

  @override
  String get remove => 'Ta bort';

  @override
  String get manageTargets => 'Hantera omfattning';

  @override
  String skillsSelected(int count) {
    return '$count valt';
  }

  @override
  String get clearSelection => 'Rensa val';

  @override
  String get selectCurrentResults => 'Select aktuella resultat';

  @override
  String get clearCurrentResultSelection => 'Rensa aktuellt resultatval';

  @override
  String get manageTargetsTitle => 'Hantera installationsmål';

  @override
  String get manageTargetsDescription =>
      'Välj en exakt åtgärd för varje mål. Omarkerade mål kommer inte att ändras.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$selected av $total mål valda';
  }

  @override
  String get confirmRemoveTarget => 'Bekräfta borttagning';

  @override
  String get applyTargetActions => 'Tillämpa valda åtgärder';

  @override
  String get managementProgressTitle => 'Tillämpa målåtgärder';

  @override
  String get managementResultsTitle => 'Mål åtgärdsresultat';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded lyckades, $failed misslyckades';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Utvalda projektåtgärder kommer att uppdatera skillsgo.yaml och skillsgo.lock.';

  @override
  String get targetContentPreserved =>
      'Aktuellt målinnehåll kommer att bevaras.';

  @override
  String get localReadFailed => 'Kan inte läsa detta Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo kunde inte läsa denna installerade skill. Kontrollera att dess folder är tillgänglig och tillgänglig och försök sedan igen.';

  @override
  String get localConfiguration => 'SKILLSGO INSTÄLLNINGAR';

  @override
  String get settingsNavigation => 'Inställningarnavigering';

  @override
  String get general => 'Personifiera';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Installationspolicy';

  @override
  String get storage => 'Lagring';

  @override
  String get colorScheme => 'Färgschema';

  @override
  String get about => 'Om';

  @override
  String get colorSchemeInspectorTitle => 'Genererade Material färgroller';

  @override
  String get skillsColorTokensTitle => 'SkillsGo semantiska färger';

  @override
  String get skillsColorTokensDescription =>
      'Produktfärger byggda från Radix Sand och organiserade med Primer semantik, med Folder som en dedikerad rumslig hierarki.';

  @override
  String get colorSchemeInspectorDescription =>
      'Förhandsgranska alla icke-utfasade ColorScheme-token som genereras från det aktuella fröet. Klicka på en färg för att kopiera dess HEX-värde.';

  @override
  String get colorSchemePairPreview => 'Semantiska par';

  @override
  String get colorSchemePairPreviewDescription =>
      'Förgrunds- och bakgrundsroller renderade tillsammans för att exponera kontrast och hierarki.';

  @override
  String get colorSchemeComponentPreview => 'Komponentförhandsgranskning';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Representativa Material-kontroller renderade med detta exakta förhandsgranskningsschema.';

  @override
  String get colorSchemeSampleTitle => 'Skill korttitel';

  @override
  String get colorSchemeSampleBody =>
      'Sekundär kopia använder onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Kopierade';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Primär';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Primär betoning, containrar och fasta accentroller.';

  @override
  String get colorSchemeGroupSecondary => 'Sekundär';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Stödande betoning och fasta biroller.';

  @override
  String get colorSchemeGroupTertiary => 'Tertiär';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Kontrasterande accenter och fasta tertiära roller.';

  @override
  String get colorSchemeGroupSurface => 'Yta';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Sida-, behållare-, höjd- och förgrundshierarki.';

  @override
  String get colorSchemeGroupUtility => 'Outline & Utility';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Gränser, skuggor, scrims och omvända ytor.';

  @override
  String get colorSchemeGroupError => 'Fel';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Felåtgärder, meddelanden och behållare.';

  @override
  String get colorSchemeUsagePrimary =>
      'Primära handlingar, fokus och accenter med hög tonvikt.';

  @override
  String get colorSchemeUsageSecondary =>
      'Stödjande handlingar och accenter med medium betoning.';

  @override
  String get colorSchemeUsageTertiary =>
      'Kontrasterande accenter som kompletterar primär och sekundär.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Text och ikoner visas på $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return '$family-behållare med lägre tonvikt för urval och accenter.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Ljusstyrkeoberoende fast $family-behållare.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Dimmerad ljusstyrkeoberoende fast $family-behållare.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Hög tonvikt på den fasta $family-behållaren.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Lägre tonvikt på den fasta $family-behållaren.';
  }

  @override
  String get colorSchemeUsageSurface => 'Bassida och storregionyta.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Nedtonad basyta används vid mörkaste yttonen.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Ljus basyta som används vid den lättaste yttonen.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return '$level ytbehållarförhöjning.';
  }

  @override
  String get colorSchemeElevationLowest => 'lägst';

  @override
  String get colorSchemeElevationLow => 'låg';

  @override
  String get colorSchemeElevationDefault => 'standard';

  @override
  String get colorSchemeElevationHigh => 'hög';

  @override
  String get colorSchemeElevationHighest => 'högsta';

  @override
  String get colorSchemeUsageOnSurface =>
      'Primär text och ikoner visas på ytor.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Sekundär text, etiketter och dämpade ikoner på ytor.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Material höjdton härledd från primär.';

  @override
  String get colorSchemeUsageOutline =>
      'Framträdande gränser och fokuserade komponentkonturer.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Subtila gränser, separatorer och konturer med låg tonvikt.';

  @override
  String get colorSchemeUsageShadow => 'Skuggfärg för förhöjda ytor.';

  @override
  String get colorSchemeUsageScrim =>
      'Modal överlagring används för att tona ned bakgrundsinnehåll.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Yta med omvänd ljus och mörk betoning.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Primär accent visas på en omvänd yta.';

  @override
  String get colorSchemeUsageError =>
      'Felåtgärder, status och återkoppling med hög vikt.';

  @override
  String get save => 'Spara';

  @override
  String get advancedSettings => 'Avancerad';

  @override
  String get remindersSettings => 'Påminnelser';

  @override
  String get remindersSettingsTitle => 'Påminnelseinställningar';

  @override
  String get remindersSettingsDescription =>
      'Välj vilka påminnelser du vill ta emot.';

  @override
  String get updateReminderTitle => 'Uppdatera påminnelser';

  @override
  String get updateReminderDescription =>
      'Sök efter uppdateringar när biblioteket öppnas.';

  @override
  String get securityReminderTitle => 'Högriskvarningar';

  @override
  String get securityReminderDescription =>
      'Meddela dig om nya Höga eller Kritiska risker i installerade skills.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count installerad skills har uppdateringar';
  }

  @override
  String get openAvailableUpdates =>
      'Öppna vyn för tillgängliga uppdateringar för att granska och uppdatera dem.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count installerad skills behöver en säkerhetsgranskning';
  }

  @override
  String get reviewInstalledSkills =>
      'Granska deras riskinformation innan du använder eller uppdaterar dem.';

  @override
  String get generalSettingsTitle => 'Gör SkillsGo till din';

  @override
  String get generalSettingsDescription =>
      'Gränssnittet följer dina systemspråk, tillgänglighet och rörelsepreferenser.';

  @override
  String get agentsSettingsTitle => 'Agent körtid';

  @override
  String get hubSettingsTitle => 'Hub Ursprung';

  @override
  String get hubSettingsDescription =>
      'Använd den officiella Hub eller ett HTTP(S) självhostat ursprung som implementerar samma SkillsGo-protokoll.';

  @override
  String get testConnection => 'Testa anslutningen';

  @override
  String get saveOrigin => 'Spara Origin';

  @override
  String get resetDefault => 'Återställ till standard';

  @override
  String get connectionReady => 'Anslutning klar';

  @override
  String get connectionFailed => 'Anslutningen misslyckades';

  @override
  String get hubInvalidOrigin =>
      'Ange ett giltigt HTTP(S)-ursprung utan inloggningsuppgifter, en fråga eller ett fragment.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub returnerade HTTP $status. Kontrollera ursprungs- och serverkonfigurationen.';
  }

  @override
  String get hubInvalidProtocol =>
      'Servern returnerade inte sökprotokollet SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Hub returnerade ogiltig JSON.';

  @override
  String get hubConnectionFailure =>
      'Kunde inte nå Hub. Kontrollera ursprungs-, nätverks-, proxy- och TLS-konfigurationen.';

  @override
  String get hubConnectionTimeout =>
      'Hub-anslutningen tog timeout. Kontrollera nätverket eller försök igen.';

  @override
  String get riskPolicyTitle => 'Personlig riskpolicy';

  @override
  String get riskPolicyDescription =>
      'Säkerhetsregler gäller när du installerar eller uppdaterar en skill.';

  @override
  String get confirmHighRisk => 'Kräv bekräftelse för Hög risk';

  @override
  String get confirmHighRiskDescription =>
      'Högriskartefakter kräver alltid en ytterligare bekräftelse innan installation.';

  @override
  String get allowCriticalOverride =>
      'Tillåt en explicit åsidosättande av kritisk risk';

  @override
  String get allowCriticalOverrideDescription =>
      'Artefakter med kritiska risker förblir blockerade som standard. Aktivera detta endast för att avslöja en separat manuell åsidosättning.';

  @override
  String get storageHealthy => 'Läsbar';

  @override
  String get storageNotInitialized => 'Inte initierad';

  @override
  String get storageUnavailable => 'Inte tillgänglig';

  @override
  String get storageInvalidResponse =>
      'Den medföljande CLI returnerade ett diagnostiksvar som inte stöds.';

  @override
  String get aboutSettingsTitle => 'Produktkompatibilitet';

  @override
  String get appVersion => 'Appversion';

  @override
  String get cliVersion => 'Medföljande CLI-version';

  @override
  String get compatible => 'Kompatibel';

  @override
  String get hubOriginSaved => 'Hub Ursprung sparat och tillämpat.';

  @override
  String get policySaved => 'Installationspolicyn har sparats.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'REDO';

  @override
  String get unknown => 'OKÄND';

  @override
  String get missing => 'SAKNAD';

  @override
  String get incompatible => 'OFÖRENLIG';

  @override
  String get detecting => 'Upptäcker...';

  @override
  String get customCliPath => 'Anpassad körbar sökväg';

  @override
  String get saveAndDetect => 'Spara och upptäck';

  @override
  String get detectAgain => 'Upptäck igen';

  @override
  String get agentInstalled => 'Installerad';

  @override
  String get agentSupported => 'Stöds';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed installerad · $supported stöds';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Installerad · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Ej installerat · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Stöds av SkillsGo, men detekteras inte på denna Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Skill laddningsvägar: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Agent-detekteringsdata är inte tillgänglig. Kör detektering igen.';

  @override
  String get noInstalledAgentsTitle => 'Ingen installerad Agents upptäckt';

  @override
  String get noInstalledAgentsMessage =>
      'Du kan fortsätta bläddra i denna Skill, men det finns inget installationsmål än. Installera en Agent som stöds och kör sedan upptäckt igen.';

  @override
  String get clearCustomPath => 'Rensa anpassad sökväg';

  @override
  String get privacyProvenance => 'Sekretess och härkomst';

  @override
  String get privacySummary =>
      'Dina sökningar sparas inte och SkillsGo för inte kommandologgar.';

  @override
  String get language => 'Språk';

  @override
  String get personalizationTheme => 'Tema';

  @override
  String get folderColorTheme => 'Tema färg';

  @override
  String get folderColorThemeDescription =>
      'Välj en färg du gillar. SkillsGo kommer att bygga en koordinerad gränssnittspalett runt den.';

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
  String get appearanceMode => 'Läge';

  @override
  String get appearanceModeDescription =>
      'Följ ditt systemutseende, eller använd alltid ett ljust eller mörkt tema.';

  @override
  String get followSystem => 'System';

  @override
  String get lightMode => 'Ljus';

  @override
  String get darkMode => 'Mörk';

  @override
  String get wallpaper => 'Tapet';

  @override
  String get wallpaperDescription =>
      'Välj en himmelsk bakgrund. Ditt val visas omedelbart bakom Folder.';

  @override
  String get wallpaperSun => 'Sol';

  @override
  String get wallpaperMercury => 'Merkurius';

  @override
  String get wallpaperVenus => 'Venus';

  @override
  String get wallpaperEarth => 'Jorden';

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
  String get wallpaperMoon => 'Måne';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Folder tema';
  }

  @override
  String get privacyAffiliation =>
      'Anonym installationstelemetri styrs av SkillsGo-inställningar. SkillsGo är inte ansluten till OpenAI eller Codex.';

  @override
  String get commandCompleted => 'Kommandot avslutat';

  @override
  String get commandFailed => 'Kommandot misslyckades';

  @override
  String commandExit(int code) {
    return 'Avsluta $code · expandera för denna sessions logg';
  }

  @override
  String get command => 'Kommando';

  @override
  String get cancel => 'Avbryt';

  @override
  String get updateUnknown => 'OKÄND';

  @override
  String get updateChecking => 'KONTROLL';

  @override
  String get upToDate => 'UPPDATERAD';

  @override
  String get updateAvailable => 'UPPDATERA';

  @override
  String get updateUnavailable => 'INTE TILLGÄNGLIG';

  @override
  String get updateCheckFailed => 'KONTROLL MISSLYCKADES';

  @override
  String get installSkill => 'Installera Skill';

  @override
  String get installLocationTitle => 'Ställ in installationsplats';

  @override
  String get userLevel => 'Användarnivå';

  @override
  String get projectLevel => 'Projektnivå';

  @override
  String get projects => 'Projekt';

  @override
  String get loading => 'Belastning…';

  @override
  String get repositoryParsing => 'Parsar arkivet...';

  @override
  String userInstallSummary(int agents) {
    return 'Tillgänglig för $agents Agents på användarnivå';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects-projekt · $agents Agents';
  }

  @override
  String get installationResults => 'Installationsresultat';

  @override
  String get installationInProgress => 'Installation pågår';

  @override
  String get installationSucceeded => 'Installationen är klar';

  @override
  String get installationSucceededMessage =>
      'Skill är nu tillgänglig på de valda platserna.';

  @override
  String get projectUnavailable => 'Projektet är inte tillgängligt';

  @override
  String get installedCell => 'Installerad';

  @override
  String get unsupportedCell => 'Inte tillgänglig';

  @override
  String get confirmInstall => 'Bekräfta installationen';

  @override
  String installAllRepositorySkills(int count) {
    return 'Installera hela arkivet skills ($count)';
  }

  @override
  String get installAllSkillsTo => 'Installera alla skills till';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Installera alla $repository skills ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Installera $skill till';
  }

  @override
  String get availableInAllProjects => 'Alla projekt';

  @override
  String get availableInSelectedProjects => 'Utvalda projekt';

  @override
  String get usedBy => 'För Agents';

  @override
  String get backToTargets => 'Tillbaka till mål';

  @override
  String get stayHere => 'Stanna här';

  @override
  String get viewInLibrary => 'Visa i biblioteket';

  @override
  String planCreateCount(int count) {
    return '$count skapa';
  }

  @override
  String planSkipCount(int count) {
    return '$count hoppa över';
  }

  @override
  String planReplaceCount(int count) {
    return '$count byt ut';
  }

  @override
  String planConflictCount(int count) {
    return '$count konflikt';
  }

  @override
  String planRiskCount(int count) {
    return '$count risk blockerad';
  }

  @override
  String get refreshInstallationPlan => 'Tillämpa resolutioner';

  @override
  String get replaceVersionConflict =>
      'Ersätt den installerade versionen vid detta mål';

  @override
  String get replaceSkillIdCollision =>
      'Byt ut de olika Skill ID vid detta mål';

  @override
  String get replaceLocalModification =>
      'Släng lokala ändringar och ersätt detta mål';

  @override
  String get sharedTargetConflict =>
      'Den här sökvägen delas av other Agent-mål';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Återgå till målmatrisen och select alla berörda Agent innan du byter ut: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Byt ut det motstridiga målet';

  @override
  String get confirmHighRiskArtifact => 'Bekräftelse av högriskartefakter';

  @override
  String get confirmCriticalRiskArtifact =>
      'Bekräftelse av åsidosättande av kritisk risk';

  @override
  String get confirmRiskForSelectedTargets =>
      'Jag granskade artefaktfilerna och accepterar denna risk för de valda målen';

  @override
  String get criticalRiskBlocked =>
      'Installation med kritiska risker är blockerad';

  @override
  String get criticalRiskOverrideDisabled =>
      'Aktivera den explicita åsidosättningen av kritisk risk i Inställningar innan den här planen kan fortsätta.';

  @override
  String get workspaceManifestChanges => 'Workspace Manifest förändringar';

  @override
  String get noWorkspaceManifestChanges =>
      'Inga Workspace Manifest-filer kommer att ändras.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'inte närvarande';

  @override
  String get planActionCreate => 'Skapa';

  @override
  String get planActionReplace => 'Ersätta';

  @override
  String get planActionSkip => 'Hoppa';

  @override
  String get planActionConflict => 'Konflikt';

  @override
  String get planActionBlockedByRisk => 'Blockerad av risk';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return '$succeeded-mål installerade, $failed misslyckades';
  }

  @override
  String get installationProgressTitle => 'Installation pågår';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished av $total mål klara';
  }

  @override
  String get targetWaiting => 'Väntan';

  @override
  String get targetRunning => 'Installerar';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Försök igen $count misslyckade mål',
      one: 'Försök 1 misslyckat mål igen',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Select mål att uppdatera';

  @override
  String get updatePlanDescription =>
      'Välj exakta installationsmål. Omarkerad Agents och projekt förblir oförändrade.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected av $available uppdateringsbara mål har valts';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Källhänvisning: $reference';
  }

  @override
  String get fixedVersionTarget => 'Fäst — ingen rörlig referens';

  @override
  String get currentVersionTarget => 'Uppdaterad';

  @override
  String get updateCheckTargetFailed => 'Uppdateringskontrollen misslyckades';

  @override
  String get reconcileWorkspaceManifestTarget => 'Reparera arbetsyta manifest';

  @override
  String get updateSelectedTargets => 'Uppdatera valda mål';

  @override
  String get updateProgressTitle => 'Uppdatering av mål';

  @override
  String get updateResultsTitle => 'Uppdatera resultat';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished av $total mål klara';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Försök igen $count misslyckade uppdateringar',
      one: 'Försök 1 misslyckad uppdatering igen',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Inget valt mål har en tillgänglig uppdatering.';

  @override
  String get closeUpdatePlan => 'Nära';

  @override
  String get targetSucceeded => 'Installerad';

  @override
  String get targetSkipped => 'Hoppade över';

  @override
  String get targetConflict => 'Konflikt';

  @override
  String get targetFailed => 'Misslyckades';

  @override
  String get targetFailureRetryable =>
      'Denna plats kunde inte ändras. Du kan försöka igen.';

  @override
  String get targetFailureNeedsAttention =>
      'Den här platsen behöver din uppmärksamhet innan du försöker igen.';

  @override
  String get installationTargetFailureMessage =>
      'Ingenting ändrades på denna plats. Kontrollera att folder är tillgänglig och försök igen.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Ingenting ändrades eftersom SkillsGo inte kunde spara projektinställningarna. Kontrollera att projektet folder är skrivbart och försök igen.';

  @override
  String get installationStateChangedMessage =>
      'Den här platsen ändrades medan du granskade den. Granska det senaste tillståndet innan du försöker igen.';

  @override
  String get updateTargetFailureMessage =>
      'Den här platsen kunde inte uppdateras. Other-platser påverkades inte, så du kan bara försöka igen.';

  @override
  String get managementTargetFailureMessage =>
      'Denna åtgärd kunde inte slutföras här. Other-platser påverkades inte, så du kan bara försöka igen.';

  @override
  String get technicalDetails => 'Tekniska detaljer';

  @override
  String get targetPathExists =>
      'Ett annat objekt finns redan på den här platsen.';

  @override
  String get targetBlockedByRisk =>
      'Dina nuvarande säkerhetsinställningar blockerade installationen på den här platsen.';

  @override
  String get targetInstallFailed =>
      'skill kunde inte installeras på den här platsen.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'skill installerades, men projektinställningarna kunde inte uppdateras.';

  @override
  String get installationPlanFailed =>
      'Installationsplanen kunde inte fortsätta';

  @override
  String get installationFailed => 'Installationen kunde inte slutföras';

  @override
  String get localSource => 'Lokal källa';

  @override
  String get noDescriptionAvailable => 'Ingen beskrivning tillgänglig';

  @override
  String moreCoverage(int count) {
    return '+$count fler platser';
  }

  @override
  String get batchTakeoverAction => 'Hantera befintliga skills';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Hantera ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Kontrollerar befintliga skills...';

  @override
  String get batchTakeoverRetry => 'Kontrollera hanterbara skills igen';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count kan hanteras';
  }

  @override
  String get batchTakeoverPending => 'Lägger till skills i hanteringen...';

  @override
  String get batchTakeoverTitle => 'Hantera befintliga skills med SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo kommer att lägga till lokala hanteringsposter utan att flytta, skriva över eller ladda upp skill-filer. Objekt som inte stöds eller ändras kommer att hoppas över.';

  @override
  String get batchTakeoverStoryTitle =>
      'Förvandla spridda skills till ett enkelt bibliotek';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count befintlig skills',
      one: '1 befintlig skill',
    );
    return 'SkillsGo hittade $_temp0 som den kan hantera på den här platsen.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Före hanteringen är det oklart var befintliga skills är installerade, om de är aktuella, hur man återställer dem eller om projekt använder samma version.';

  @override
  String get batchTakeoverPainLocation => 'Okänd installationsplats';

  @override
  String get batchTakeoverPainFreshness => 'Okänd uppdateringsstatus';

  @override
  String get batchTakeoverPainRecovery =>
      'Ingen återhämtning när den är bruten';

  @override
  String get batchTakeoverPainVersionDrift => 'Olika versioner över projekt';

  @override
  String get batchTakeoverFolderTitle => 'Befintlig Skills';

  @override
  String get batchTakeoverFolderSubtitle => 'Oklart status';

  @override
  String get batchTakeoverAfterLabel => 'EFTER';

  @override
  String get batchTakeoverAfterTitle => 'Ett tydligt bibliotek';

  @override
  String get batchTakeoverLibraryTitle => 'SkillsGo bibliotek';

  @override
  String get batchTakeoverBenefitLocation => 'Rensa platser';

  @override
  String get batchTakeoverBenefitFreshness => 'Uppdateringar synliga';

  @override
  String get batchTakeoverBenefitRecovery => 'Enkel återhämtning';

  @override
  String get batchTakeoverBenefitVersions => 'Versioner tydliga';

  @override
  String get batchTakeoverManagedSection => 'Drivs av SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'I avvaktan på';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name hanteras av SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name kunde inte läggas till i hanteringen';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name väntar på att bli hanterad';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills är',
      one: '1 skill är',
    );
    return 'Efter hantering, $_temp0 organiserade i ett bibliotek med en tydlig hanterad status.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count mer';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Lägg till dessa befintliga skills till SkillsGo-hantering.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANISERA';

  @override
  String get batchTakeoverStatusTitle => 'Ledningsstatus';

  @override
  String get batchTakeoverStatusManaged => 'Hanterade';

  @override
  String get batchTakeoverStatusProgress => 'Organisera';

  @override
  String get batchTakeoverStatusSkipped => 'Hoppade över';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Skill-filer stannar på sina ursprungliga platser';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills är ordnade i kompletta rader och spelas in av SkillsGo utan att flytta sina filer.';

  @override
  String get batchTakeoverBoardComplete => 'FARAN ÖVER';

  @override
  String get batchTakeoverBoardPartial => 'KOMPLETT';

  @override
  String get batchTakeoverStatusTotal => 'Total';

  @override
  String get batchTakeoverQueueComplete => 'Inga skills väntar';

  @override
  String get batchTakeoverQueueWaiting =>
      'Efter verifieringen visas Skills här';

  @override
  String get batchTakeoverNextLabel => 'NÄSTA';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo arrangörsblock',
      one: '1 SkillsGo arrangörsblock',
    );
    return '$_temp0 slutför de sista raderna';
  }

  @override
  String get batchTakeoverPreservation =>
      'Dina filer, sökvägar och nuvarande arbetsflöden stannar precis där de är. SkillsGo kompletterar endast sina lokala förvaltningsposter.';

  @override
  String get batchTakeoverLaterHint =>
      'Om du hoppar över kan du när som helst använda Hantera befintliga skills från biblioteket.';

  @override
  String get batchTakeoverSkip => 'Inte nu';

  @override
  String get batchTakeoverConfirm => 'Lägg till i hanteringen';

  @override
  String get batchTakeoverExecutionRetry => 'Försöka igen';

  @override
  String get batchTakeoverResultTitle => 'Skills har lagts till i ledningen';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver skills lades till i ledningen, $skipped hoppade över.';
  }

  @override
  String get batchTakeoverClose => 'Stäng';

  @override
  String get installMoreTargets => 'Installera på fler platser';

  @override
  String get detailRepository => 'Förvar';

  @override
  String get detailStars => 'Stjärnor';

  @override
  String get detailUpdated => 'Uppdaterad';

  @override
  String get detailArchiveSize => 'ZIP-storlek';

  @override
  String get pathLabel => 'Projektväg';

  @override
  String get copyProjectPath => 'Kopiera projektsökväg';

  @override
  String get projectPathCopied => 'Projektsökvägen kopierad';

  @override
  String get onboardingWelcomeTitle => 'Välkommen till SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Upptäck, installera och hantera Skills över dina Agents och projekt.';

  @override
  String get onboardingDetectedAgents => 'Detekterade Agents';

  @override
  String get onboardingNoAgents =>
      'Ingen installerad Agents upptäckt. Du kan fortfarande fortsätta.';

  @override
  String get onboardingNext => 'Nästa';

  @override
  String get onboardingProjectsTitle => 'Lägg till dina projekt';

  @override
  String get onboardingProjectsDescription =>
      'Välj de projekt du vill att SkillsGo ska hantera.';

  @override
  String get onboardingAddProject => 'Lägg till nu';

  @override
  String get onboardingAddProjectLater => 'eller senare';

  @override
  String get onboardingStartUsing => 'Börja använda SkillsGo';

  @override
  String get onboardingBack => 'Tillbaka';

  @override
  String get restartOnboardingTitle => 'Onboarding';

  @override
  String get restartOnboardingDescription =>
      'Se första-lanseringsguiden igen utan att ta bort projekt, inställningar eller Skills-data.';

  @override
  String get restartOnboardingAction => 'Starta om Onboarding';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo kunde inte starta om Onboarding.';

  @override
  String get libraryRefreshSettingsTitle => 'Uppdatera det lokala biblioteket';

  @override
  String get libraryRefreshSettingsDescription =>
      'Skanna om installerade Skills, Added Projects, Agents och externa Skills som kan hanteras. Detta installerar, uppdaterar eller tar inte bort någonting.';

  @override
  String get libraryRefreshSettingsAction => 'Uppdatera biblioteket';

  @override
  String get libraryRefreshSettingsPending => 'Uppdaterar biblioteket...';

  @override
  String get libraryRefreshSettingsSuccess => 'Lokalbiblioteket uppdaterat.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo kunde inte uppdatera det lokala biblioteket.';

  @override
  String get onboardingProjectError =>
      'SkillsGo kunde inte lägga till projekt från den här katalogen.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo kunde inte ladda dina tillagda projekt.';

  @override
  String get onboardingStartupError =>
      'SkillsGo kunde inte ladda inställningen.';

  @override
  String get onboardingStateError =>
      'SkillsGo kunde inte spara dina installationsförlopp. Försök igen.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI behöver uppmärksamhet';

  @override
  String get onboardingCliErrorDescription =>
      'Reparera den medföljande CLI och försök sedan igen för att fortsätta.';
}
