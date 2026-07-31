// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get discover => 'Scoprire';

  @override
  String get discoverSkills => 'È bello sapere qualcosa in più.';

  @override
  String get library => 'Biblioteca';

  @override
  String get settings => 'Impostazioni';

  @override
  String get appUpdateTitle => 'App updates';

  @override
  String get appUpdateDescription =>
      'Check the signed release feed for a newer version of SkillsGo.';

  @override
  String get appUpdateNotConfigured =>
      'App updates are unavailable in this build.';

  @override
  String get appUpdateReady =>
      'Check when you’re ready. SkillsGo will not install an update without your action.';

  @override
  String get appUpdateChecking => 'Checking for an App update…';

  @override
  String get appUpdateApplying =>
      'Downloading the update. SkillsGo will restart when it is ready.';

  @override
  String get appUpdateCheckFailed =>
      'SkillsGo could not check for an App update. Check your connection and try again.';

  @override
  String appUpdateAvailable(String version) {
    return 'SkillsGo $version is available.';
  }

  @override
  String appUpdateCurrent(String version) {
    return 'SkillsGo $version is up to date.';
  }

  @override
  String get appUpdateCheckAction => 'Check for App updates';

  @override
  String get appUpdateApplyAction => 'Update and restart';

  @override
  String get openSettings => 'Apri Impostazioni';

  @override
  String get cliNeedsAttention =>
      'Un componente SkillsGo richiesto richiede attenzione.';

  @override
  String get cliMissingBundled =>
      'Un componente SkillsGo richiesto manca o non può essere avviato. Reinstallare SkillsGo per ripristinarlo.';

  @override
  String get cliDamagedBundled =>
      'Un componente SkillsGo richiesto è danneggiato. Reinstallare SkillsGo per ripristinarlo.';

  @override
  String get cliIncompatibleBundled =>
      'Un componente SkillsGo richiesto non corrisponde a questa versione dell\'app. Aggiorna o reinstalla SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Trova uno skill per la tua prossima mossa.';

  @override
  String get skillsLeaderboard => 'È bello sapere qualcosa in più.';

  @override
  String searchResultsFor(String query) {
    return 'Risultati per “$query”';
  }

  @override
  String get searchSkills => 'Cerca skills o incolla un collegamento Git...';

  @override
  String get search => 'Ricerca';

  @override
  String get ranking => 'Classifica';

  @override
  String get trending => 'Tendenza';

  @override
  String get hot => 'Caldo';

  @override
  String get discoverNavigation => 'Scopri la navigazione';

  @override
  String get allTimeRanking => 'Classifica di tutti i tempi';

  @override
  String get trendingNow => 'Tendenza nelle ultime 24 ore';

  @override
  String get hotNow => 'Caldo in questo momento';

  @override
  String get allTimeDescription =>
      'Skill pubblici ordinati per numero totale di installazioni accettate.';

  @override
  String get trendingDescription =>
      'Skill pubblici ordinati per installazioni accettate nelle ultime 24 ore.';

  @override
  String get hotDescription =>
      'Skill pubblici ordinati per velocità di installazione recente e relativa variazione.';

  @override
  String get offlineTitle => 'Impossibile connettersi a SkillsGo';

  @override
  String get offlineMessage =>
      'Controlla la connessione Internet e riprova. Se utilizzi un proxy o un indirizzo di servizio personalizzato, controllalo in Impostazioni.';

  @override
  String get searchFailedTitle => 'Ricerca non riuscita';

  @override
  String get validationTitle => 'Controlla cosa hai inserito';

  @override
  String get validationMessage =>
      'SkillsGo non ha potuto utilizzare questa richiesta. Rivedi ciò che hai inserito e riprova.';

  @override
  String get serverTitle => 'Servizio momentaneamente non disponibile';

  @override
  String get serverMessage =>
      'SkillsGo non può completare questa richiesta in questo momento. Riprova tra un attimo.';

  @override
  String get timeoutTitle => 'Ci vuole troppo tempo per farlo';

  @override
  String get timeoutMessage =>
      'Il servizio non ha risposto in tempo. Controlla la connessione o riprova.';

  @override
  String get invalidResponseTitle => 'SkillsGo necessita di un aggiornamento';

  @override
  String get invalidResponseMessage =>
      'Questa risposta non può essere letta dalla tua versione di SkillsGo. Aggiorna l\'app, quindi riprova.';

  @override
  String get invalidLocalDataTitle =>
      'Impossibile leggere uno skill installato';

  @override
  String get invalidLocalDataMessage =>
      'Alcune informazioni sull\'installazione locale sono danneggiate o incompatibili. Aggiorna o reinstalla SkillsGo, quindi riprova.';

  @override
  String get tryAgain => 'Riprova';

  @override
  String get searchEmptyTitle => 'Cerca, non scorrere.';

  @override
  String get searchEmptyMessage =>
      'Inserisci una capacità, un\'origine o un\'attività per cercare skills pubblico.';

  @override
  String get noSkillsTitle => 'Nessun skills trovato';

  @override
  String get noSkillsMessage =>
      'Prova una frase più ampia o controlla l\'ortografia.';

  @override
  String get focusSearch => 'Focalizza la ricerca';

  @override
  String get skillsFromLink => 'Skills da questo link';

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
      other: '$count skills da $source',
      one: '1 skill da $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle =>
      'Questo collegamento è pronto per essere ispezionato';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source non è presente nei risultati della ricerca corrente. SkillsGo può ispezionare il collegamento direttamente nel passaggio successivo.';
  }

  @override
  String get inspectSource => 'Visualizza skills in questo collegamento';

  @override
  String get collectionEmptyTitle => 'Nessun Skills in questa raccolta';

  @override
  String get collectionEmptyMessage =>
      'Non c\'è ancora niente qui. Riprovare dopo ulteriori attività di installazione.';

  @override
  String get loadMore => 'Carica di più';

  @override
  String get install => 'Installare';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get downgrade => 'Downgrade';

  @override
  String get packageSkillsSwitchTogether =>
      'Skills from this package will switch version together.';

  @override
  String get switchVersion => 'Switch version';

  @override
  String upgradeToVersion(String version) {
    return 'Upgrade to $version';
  }

  @override
  String downgradeToVersion(String version) {
    return 'Downgrade to $version';
  }

  @override
  String get installAll => 'Installa tutti gli skills';

  @override
  String get latestCommit => 'Ultimo impegno';

  @override
  String get installToMoreTargets => 'Installa in più posizioni';

  @override
  String localTargets(int count) {
    return 'Obiettivi locali $count';
  }

  @override
  String allTimeMetric(String count) {
    return '$count installazioni di tutti i tempi';
  }

  @override
  String trendingMetric(String count) {
    return '$count installa / 24 ore';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value a quest\'ora · $change';
  }

  @override
  String get trustUnverified => 'Non verificato';

  @override
  String get trustCommunityVerified => 'Comunità verificata';

  @override
  String get trustPublisherVerified => 'Editore verificato';

  @override
  String get trustOfficial => 'Ufficiale';

  @override
  String get trustWarned => 'Avvisato';

  @override
  String get trustDelisted => 'Cancellato';

  @override
  String get riskUnknown => 'Rischio sconosciuto';

  @override
  String get riskLow => 'Basso rischio';

  @override
  String get riskMedium => 'Rischio medio';

  @override
  String get riskHigh => 'Alto rischio';

  @override
  String get riskCritical => 'Rischio critico';

  @override
  String openSkill(String name) {
    return 'Apri $name';
  }

  @override
  String installs(String count) {
    return '$count si installa';
  }

  @override
  String get detailFailedTitle => 'Impossibile caricare questo Skill';

  @override
  String get detailLoading => 'Caricamento dei dettagli Skill verificabili';

  @override
  String get artifactUnavailableTitle => 'Artefatto non disponibile';

  @override
  String get artifactUnavailableMessage =>
      'Questa versione non è disponibile al momento. Riprova o scegli un\'altra versione.';

  @override
  String get detailInvalidTitle => 'Metadati dell\'artefatto non supportati';

  @override
  String get detailInvalidMessage =>
      'Alcuni dettagli per questo skill sono incompleti o non possono essere letti. Aggiorna SkillsGo, quindi riprova.';

  @override
  String get instructionsTab => 'Istruzioni';

  @override
  String get manifestTab => 'Manifesto';

  @override
  String immutableVersionLabel(String version) {
    return '$version immutabile';
  }

  @override
  String commitIdentity(String sha) {
    return 'Impegna $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Albero $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Contenuto $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'La fiducia dell\'editore verifica la proprietà o la manutenzione; non certifica la sicurezza degli artefatti. Il rischio viene valutato separatamente per questa versione immutabile.';

  @override
  String get knownInstallationTargets => 'Obiettivi di installazione noti';

  @override
  String get installationRange => 'Ambito installato';

  @override
  String get targetDetails => 'Mostra i dettagli del target';

  @override
  String get hideTargetDetails => 'Nascondi i dettagli del target';

  @override
  String installedVersionLabel(String version) {
    return 'Versione $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Progetto';

  @override
  String get fileContentUnavailable => 'Anteprima binaria o non disponibile';

  @override
  String get fileContentTruncated =>
      'Anteprima troncata dal limite di sicurezza Hub.';

  @override
  String get retry => 'Riprova';

  @override
  String get backToSearch => 'Torna alla ricerca';

  @override
  String get installForCodex => 'Installare per Codex';

  @override
  String get cliNotDetected => 'skills (non rilevato)';

  @override
  String get snapshotFiles => 'File di istantanee';

  @override
  String get globalCodex => 'Globale · Codex';

  @override
  String get yourLibrary => 'Quello che sai è tutto qui.';

  @override
  String get libraryNavigation => 'Navigazione della biblioteca';

  @override
  String get all => 'Tutto';

  @override
  String get allSkills => 'Tutti Skills';

  @override
  String get updatesOnly => 'Aggiornamenti';

  @override
  String get allAgents => 'Tutti Agents';

  @override
  String get allProjects => 'Tutti i progetti';

  @override
  String get specificProject => 'Progetto';

  @override
  String get libraryGlobalScope => 'Global Skills';

  @override
  String get globalScope => 'Globale';

  @override
  String get globalSkills => 'Global Skills';

  @override
  String get addProject => 'Aggiungi progetto';

  @override
  String get removeFromList => 'Rimuovi dall\'elenco';

  @override
  String removeProjectTitle(String name) {
    return 'Rimuovere $name da SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Verrà rimosso solo il riferimento all\'app. SkillsGo non modificherà né eliminerà alcun file in questa directory.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — non disponibile';
  }

  @override
  String get emptyProjectTitle => 'Nessun Skills ancora';

  @override
  String get browseSkills => 'Sfoglia Skills';

  @override
  String get projectMissingTitle => 'Manca la directory del progetto';

  @override
  String get projectMissingMessage =>
      'The directory may have moved or its volume may be offline. Check the path or remove its App reference.';

  @override
  String get projectPermissionTitle =>
      'È richiesta l\'autorizzazione al progetto';

  @override
  String get projectPermissionMessage =>
      'SkillsGo cannot inspect this project root. Check its filesystem permissions or remove its App reference.';

  @override
  String get projectInaccessibleTitle =>
      'La directory del progetto è inaccessibile';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo kept this project reference. Check the path or volume, or remove its App reference.';

  @override
  String get checking => 'Controllo…';

  @override
  String get checkUpdates => 'Controlla gli aggiornamenti';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get libraryUnavailable => 'Libreria non disponibile';

  @override
  String get libraryEmpty => 'Nessun skills ancora installato';

  @override
  String get libraryEmptyMessage =>
      'Installa uno Skill da Discover e apparirà qui.';

  @override
  String get searchLibrary => 'Cerca skills installato';

  @override
  String get libraryNoMatches => 'Nessun Skills corrispondente';

  @override
  String get libraryNoMatchesMessage =>
      'Prova un nome, una sorgente, Agent, un progetto o una versione diversi.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return 'Progetti $count';
  }

  @override
  String versionsSummary(int count) {
    return 'Versioni $count';
  }

  @override
  String get hubManaged => 'Hub gestito';

  @override
  String get localManaged => 'Gestito localmente';

  @override
  String get externalInstallation => 'Installazione esterna';

  @override
  String get readOnly => 'Sola lettura';

  @override
  String get unversioned => 'Senza versione';

  @override
  String get supportingFiles => 'File di supporto';

  @override
  String get versionDivergence => 'Divergenza di versione';

  @override
  String get healthHealthy => 'Salutare';

  @override
  String get healthMissing => 'Obiettivo mancante';

  @override
  String get healthReplaced => 'Obiettivo sostituito';

  @override
  String get healthLocalModification => 'Modifica locale';

  @override
  String get healthUnreadable => 'Obiettivo illeggibile';

  @override
  String get healthUndeclared => 'Non dichiarato';

  @override
  String get healthWorkspaceUnreadable =>
      'Stato dell\'area di lavoro illeggibile';

  @override
  String get healthLockMismatch => 'Blocca la mancata corrispondenza';

  @override
  String get healthUnexpectedPath => 'Percorso target imprevisto';

  @override
  String get modeExternal => 'Esterno';

  @override
  String get notLinked => 'NON COLLEGATO';

  @override
  String get update => 'Aggiornamento';

  @override
  String get backToLibrary => 'Ritorno alla Biblioteca';

  @override
  String get remove => 'Rimuovere';

  @override
  String skillsSelected(int count) {
    return '$count selezionato';
  }

  @override
  String get clearSelection => 'Cancella selezione';

  @override
  String get selectCurrentResults => 'Select risultati attuali';

  @override
  String get clearCurrentResultSelection =>
      'Cancella la selezione del risultato corrente';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'Bersagli $selected di $total selezionati';
  }

  @override
  String get confirmRemoveTarget => 'Conferma la rimozione';

  @override
  String get managementProgressTitle => 'Applicazione delle azioni target';

  @override
  String get managementResultsTitle => 'Risultati dell\'azione mirata';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded ha avuto successo, $failed ha fallito';
  }

  @override
  String get targetContentPreserved =>
      'Il contenuto di destinazione corrente verrà preservato.';

  @override
  String get localReadFailed => 'Impossibile leggere questo Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo non è riuscito a leggere questo skill installato. Verifica che il suo folder sia disponibile e accessibile, quindi riprova.';

  @override
  String get localConfiguration => 'IMPOSTAZIONI SKILLSGO';

  @override
  String get settingsNavigation => 'Navigazione delle impostazioni';

  @override
  String get general => 'Personalizzare';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Politica di installazione';

  @override
  String get storage => 'Magazzinaggio';

  @override
  String get colorScheme => 'Combinazione di colori';

  @override
  String get about => 'Di';

  @override
  String get colorSchemeInspectorTitle => 'Ruoli colore Material generati';

  @override
  String get skillsColorTokensTitle => 'Colori semantici SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Colori del prodotto creati da Radix Sand e organizzati con la semantica Primer, con Folder come gerarchia spaziale dedicata.';

  @override
  String get colorSchemeInspectorDescription =>
      'Visualizza l\'anteprima di ogni token ColorScheme non obsoleto generato dal seed corrente. Fare clic su un colore per copiarne il valore HEX.';

  @override
  String get colorSchemePairPreview => 'Coppie semantiche';

  @override
  String get colorSchemePairPreviewDescription =>
      'Ruoli di primo piano e di sfondo resi insieme per esporre contrasto e gerarchia.';

  @override
  String get colorSchemeComponentPreview => 'Anteprima del componente';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Controlli Material rappresentativi renderizzati con questo esatto schema di anteprima.';

  @override
  String get colorSchemeSampleTitle => 'Titolo della carta Skill';

  @override
  String get colorSchemeSampleBody =>
      'La copia secondaria utilizza onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Copiato';

  @override
  String get colorSchemeSampleGlyphs => 'AA 123';

  @override
  String get colorSchemeGroupPrimary => 'Primario';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Enfasi primaria, contenitori e ruoli di accento fisso.';

  @override
  String get colorSchemeGroupSecondary => 'Secondario';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Supportare l\'enfasi e i ruoli secondari fissi.';

  @override
  String get colorSchemeGroupTertiary => 'Terziario';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Accenti contrastanti e ruoli terziari fissi.';

  @override
  String get colorSchemeGroupSurface => 'Superficie';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Gerarchia di pagina, contenitore, elevazione e primo piano.';

  @override
  String get colorSchemeGroupUtility => 'Contorno e utilità';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Confini, ombre, tele e superfici inverse.';

  @override
  String get colorSchemeGroupError => 'Errore';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Azioni di errore, messaggi e contenitori.';

  @override
  String get colorSchemeUsagePrimary =>
      'Azioni primarie, focus e accenti di grande enfasi.';

  @override
  String get colorSchemeUsageSecondary =>
      'Azioni di supporto e accenti di media enfasi.';

  @override
  String get colorSchemeUsageTertiary =>
      'Accenti contrastanti che completano il primario e il secondario.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Testo e icone visualizzati su $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Contenitore $family con enfasi inferiore per selezioni e accenti.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Contenitore fisso $family indipendente dalla luminosità.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Contenitore fisso $family dimmerato indipendente dalla luminosità.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Contenuti di grande rilievo sul contenitore fisso $family.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Contenuti con enfasi inferiore sul contenitore $family fisso.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Pagina di base e superficie di grandi dimensioni.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Superficie di base attenuata utilizzata con il tono di superficie più scuro.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Superficie di base luminosa utilizzata con il tono di superficie più chiaro.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'L\'elevazione della superficie del contenitore $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'più basso';

  @override
  String get colorSchemeElevationLow => 'Basso';

  @override
  String get colorSchemeElevationDefault => 'predefinito';

  @override
  String get colorSchemeElevationHigh => 'alto';

  @override
  String get colorSchemeElevationHighest => 'più alto';

  @override
  String get colorSchemeUsageOnSurface =>
      'Testo principale e icone visualizzati sulle superfici.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Testo secondario, etichette e icone attenuate sulle superfici.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Tinta in elevazione Material derivata dal primario.';

  @override
  String get colorSchemeUsageOutline =>
      'Confini prominenti e contorni dei componenti focalizzati.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Confini sottili, separatori e contorni poco enfatizzati.';

  @override
  String get colorSchemeUsageShadow => 'Colore ombra per superfici elevate.';

  @override
  String get colorSchemeUsageScrim =>
      'Sovrapposizione modale utilizzata per de-enfatizzare il contenuto dello sfondo.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Superficie con enfasi invertita di chiaro e scuro.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Accento primario visualizzato su una superficie inversa.';

  @override
  String get colorSchemeUsageError =>
      'Azioni di errore, stato e feedback di grande enfasi.';

  @override
  String get save => 'Salva';

  @override
  String get advancedSettings => 'Avanzato';

  @override
  String get remindersSettings => 'Promemoria';

  @override
  String get remindersSettingsTitle => 'Impostazioni promemoria';

  @override
  String get remindersSettingsDescription =>
      'Scegli quali promemoria ricevere.';

  @override
  String get updateReminderTitle => 'Aggiorna promemoria';

  @override
  String get updateReminderDescription =>
      'Controlla gli aggiornamenti all\'apertura della Libreria.';

  @override
  String get securityReminderTitle => 'Avvisi ad alto rischio';

  @override
  String get securityReminderDescription =>
      'Notifica di nuovi rischi elevati o critici nello skills installato.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count installato skills dispone di aggiornamenti';
  }

  @override
  String get openAvailableUpdates =>
      'Apri la vista degli aggiornamenti disponibili per rivederli e aggiornarli.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count installato skills necessita di una revisione della sicurezza';
  }

  @override
  String get reviewInstalledSkills =>
      'Esaminare le informazioni sui rischi prima di utilizzarle o aggiornarle.';

  @override
  String get generalSettingsTitle => 'Rendi SkillsGo tuo';

  @override
  String get generalSettingsDescription =>
      'L\'interfaccia segue la lingua del sistema, l\'accessibilità e le preferenze di movimento.';

  @override
  String get agentsSettingsTitle => 'Tempo di esecuzione Agent';

  @override
  String get hubSettingsTitle => 'Hub Origine';

  @override
  String get hubSettingsDescription =>
      'Utilizza lo Hub ufficiale o un\'origine HTTP(S) self-hosted che implementa lo stesso protocollo SkillsGo.';

  @override
  String get testConnection => 'Testare la connessione';

  @override
  String get saveOrigin => 'Salva origine';

  @override
  String get resetDefault => 'Ripristina le impostazioni predefinite';

  @override
  String get connectionReady => 'Connessione pronta';

  @override
  String get connectionFailed => 'Connessione non riuscita';

  @override
  String get hubInvalidOrigin =>
      'Inserisci un\'origine HTTP(S) valida senza credenziali, una query o un frammento.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub ha restituito HTTP $status. Controlla l\'origine e la configurazione del server.';
  }

  @override
  String get hubInvalidProtocol =>
      'Il server non ha restituito il protocollo di ricerca SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Hub ha restituito un JSON non valido.';

  @override
  String get hubConnectionFailure =>
      'Impossibile raggiungere Hub. Controlla la configurazione di origine, rete, proxy e TLS.';

  @override
  String get hubConnectionTimeout =>
      'La connessione Hub è scaduta. Controlla la rete o riprova.';

  @override
  String cloudHttpFailure(int status) {
    return 'Cloud returned HTTP $status. Check the Origin and service configuration.';
  }

  @override
  String get cloudInvalidProtocol =>
      'The server did not return the SkillsGo Cloud ranking protocol.';

  @override
  String get cloudInvalidJson => 'Cloud returned invalid JSON.';

  @override
  String get cloudConnectionFailure =>
      'Could not reach Cloud. Check the Origin, network, proxy, and TLS configuration.';

  @override
  String get cloudConnectionTimeout =>
      'The Cloud connection timed out. Check the network or try again.';

  @override
  String get riskPolicyTitle => 'Politica del rischio personale';

  @override
  String get riskPolicyDescription =>
      'Si applicano regole di sicurezza quando si installa o si aggiorna uno skill.';

  @override
  String get confirmHighRisk => 'Richiedi conferma per rischio alto';

  @override
  String get confirmHighRiskDescription =>
      'Gli artefatti ad alto rischio richiedono sempre un\'ulteriore conferma prima dell\'installazione.';

  @override
  String get allowCriticalOverride =>
      'Consentire un esplicito override del rischio critico';

  @override
  String get allowCriticalOverrideDescription =>
      'Gli artefatti a rischio critico rimangono bloccati per impostazione predefinita. Abilitarlo solo per esporre un override manuale separato.';

  @override
  String get storageHealthy => 'Leggibile';

  @override
  String get storageNotInitialized => 'Non inizializzato';

  @override
  String get storageUnavailable => 'Non disponibile';

  @override
  String get storageInvalidResponse =>
      'Lo CLI in bundle ha restituito una risposta diagnostica non supportata.';

  @override
  String get aboutSettingsTitle => 'Compatibilità del prodotto';

  @override
  String get appVersion => 'Versione dell\'app';

  @override
  String get cliVersion => 'Versione CLI in bundle';

  @override
  String get compatible => 'Compatibile';

  @override
  String get hubOriginSaved => 'Hub Origine salvata e applicata.';

  @override
  String get policySaved => 'Criterio di installazione salvato.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'PRONTO';

  @override
  String get unknown => 'SCONOSCIUTO';

  @override
  String get missing => 'MANCANTE';

  @override
  String get incompatible => 'INCOMPATIBILE';

  @override
  String get detecting => 'Rilevamento…';

  @override
  String get customCliPath => 'Percorso eseguibile personalizzato';

  @override
  String get saveAndDetect => 'Salva e rileva';

  @override
  String get detectAgain => 'Rileva di nuovo';

  @override
  String get agentInstalled => 'Installato';

  @override
  String get agentSupported => 'Supportato';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed installato · $supported supportato';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Installato · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Non installato · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Supportato da SkillsGo, ma non rilevato su questo Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Percorsi di caricamento Skill: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'I dati di rilevamento Agent non sono disponibili. Eseguire nuovamente il rilevamento.';

  @override
  String get noInstalledAgentsTitle => 'Nessun Agents installato rilevato';

  @override
  String get noInstalledAgentsMessage =>
      'Puoi continuare a navigare in questo Skill, ma non esiste ancora una destinazione di installazione. Installare uno Agent supportato, quindi eseguire nuovamente il rilevamento.';

  @override
  String get clearCustomPath => 'Cancella percorso personalizzato';

  @override
  String get privacyProvenance => 'Privacy e provenienza';

  @override
  String get privacySummary =>
      'Search text and Skill content aren’t logged. Sanitized local diagnostics are retained for up to 7 days and never uploaded automatically.';

  @override
  String get diagnosticLogsTitle => 'Diagnostic logs';

  @override
  String diagnosticLogsDescription(String size) {
    return 'Local App and CLI diagnostics use $size. Logs rotate automatically, are retained for up to 7 days, and are never uploaded automatically.';
  }

  @override
  String get openLogFolder => 'Open folder';

  @override
  String get viewLiveLogs => 'View live';

  @override
  String get exportLogs => 'Export logs';

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get logsExported => 'Diagnostic logs exported.';

  @override
  String get logsCleared => 'Diagnostic logs cleared.';

  @override
  String get logActionFailed =>
      'The diagnostic log action could not be completed.';

  @override
  String get logViewerLive => 'Live';

  @override
  String get logViewerPaused => 'Paused';

  @override
  String get searchLogs => 'Search logs';

  @override
  String get allLogLevels => 'All';

  @override
  String get warningLogs => 'Warnings';

  @override
  String get errorLogs => 'Errors';

  @override
  String get pauseLogFollow => 'Pause';

  @override
  String get resumeLogFollow => 'Resume';

  @override
  String get clearViewer => 'Clear view';

  @override
  String get noDiagnosticLogs => 'No matching logs yet.';

  @override
  String get backToLatestLog => 'Latest';

  @override
  String get language => 'Lingua';

  @override
  String get originalContent => 'Original';

  @override
  String get translatedContent => 'Tradotto';

  @override
  String translatedFrom(String language) {
    return 'Tradotto da $language';
  }

  @override
  String sourceLanguageName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'en': 'inglese',
      'zhHans': 'cinese semplificato',
      'zhHant': 'cinese tradizionale',
      'ja': 'giapponese',
      'ko': 'coreano',
      'fr': 'francese',
      'de': 'tedesco',
      'it': 'italiano',
      'es': 'spagnolo',
      'pt': 'portoghese',
      'ru': 'russo',
      'ar': 'arabo',
      'hi': 'hindi',
      'id': 'indonesiano',
      'tr': 'turco',
      'nl': 'olandese',
      'pl': 'polacco',
      'th': 'thailandese',
      'vi': 'vietnamita',
      'ms': 'malese',
      'sv': 'svedese',
      'uk': 'ucraino',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String get showOriginalContent => 'Mostra originale';

  @override
  String get showTranslation => 'Mostra traduzione';

  @override
  String get personalizationTheme => 'Tema';

  @override
  String get folderColorTheme => 'Colore del tema';

  @override
  String get folderColorThemeDescription =>
      'Scegli un colore che ti piace. SkillsGo costruirà attorno ad esso una tavolozza di interfacce coordinata.';

  @override
  String get brandNameNeteaseCloudMusic => 'NetEase Musica sul cloud';

  @override
  String get brandNameRaspberryPi => 'Lampone Pi';

  @override
  String get brandNameChinaEasternAirlines => 'China Eastern Airlines';

  @override
  String get brandNameNvidia => 'NVIDIA';

  @override
  String get brandNameTaobao => 'Taobao';

  @override
  String get brandNameBitcoin => 'Bitcoin';

  @override
  String get appearanceMode => 'Modalità';

  @override
  String get appearanceModeDescription =>
      'Segui l\'aspetto del tuo sistema o utilizza sempre un tema chiaro o scuro.';

  @override
  String get followSystem => 'Sistema';

  @override
  String get lightMode => 'Leggero';

  @override
  String get darkMode => 'Buio';

  @override
  String get wallpaper => 'Carta da parati';

  @override
  String get wallpaperDescription =>
      'Scegli uno sfondo celeste. La tua selezione appare immediatamente dietro Folder.';

  @override
  String get wallpaperSun => 'Sole';

  @override
  String get wallpaperMercury => 'Mercurio';

  @override
  String get wallpaperVenus => 'Venere';

  @override
  String get wallpaperEarth => 'Terra';

  @override
  String get wallpaperMars => 'Marte';

  @override
  String get wallpaperJupiter => 'Giove';

  @override
  String get wallpaperSaturn => 'Saturno';

  @override
  String get wallpaperUranus => 'Urano';

  @override
  String get wallpaperNeptune => 'Nettuno';

  @override
  String get wallpaperPluto => 'Plutone';

  @override
  String get wallpaperMoon => 'Luna';

  @override
  String folderThemeChoice(String theme) {
    return 'Tema $theme Folder';
  }

  @override
  String get privacyAffiliation =>
      'La telemetria di installazione anonima è controllata dalle impostazioni SkillsGo. SkillsGo non è affiliato con OpenAI o Codex.';

  @override
  String get commandCompleted => 'Comando completato';

  @override
  String get commandFailed => 'Comando fallito';

  @override
  String commandExit(int code) {
    return 'Esci da $code · espandi per il registro di questa sessione';
  }

  @override
  String get command => 'Comando';

  @override
  String get cancel => 'Annulla';

  @override
  String get updateUnknown => 'SCONOSCIUTO';

  @override
  String get updateChecking => 'VERIFICA';

  @override
  String get upToDate => 'AGGIORNATO';

  @override
  String get updateAvailable => 'AGGIORNAMENTO';

  @override
  String get updateUnavailable => 'NON DISPONIBILE';

  @override
  String get updateCheckFailed => 'VERIFICA FALLITA';

  @override
  String get installSkill => 'Installa Skill';

  @override
  String get installLocationTitle => 'Imposta il percorso di installazione';

  @override
  String get globalLevel => 'Global';

  @override
  String get projectLevel => 'Livello di progetto';

  @override
  String get projects => 'Progetti';

  @override
  String get loading => 'Caricamento…';

  @override
  String get repositoryParsing => 'Analisi del repository…';

  @override
  String globalInstallSummary(int agents) {
    return 'Available globally to $agents Agents';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return 'Progetti $projects · $agents Agents';
  }

  @override
  String get installationResults => 'Risultati dell\'installazione';

  @override
  String get installationInProgress => 'Installazione in corso';

  @override
  String get installationSucceeded => 'Installazione completata';

  @override
  String get installationSucceededMessage =>
      'Lo Skill è ora disponibile nelle località selezionate.';

  @override
  String get projectUnavailable => 'Progetto non disponibile';

  @override
  String get installedCell => 'Installato';

  @override
  String get unsupportedCell => 'Non disponibile';

  @override
  String get confirmInstall => 'Conferma l\'installazione';

  @override
  String installAllPackageSkills(int count) {
    return 'Installa tutto il repository skills ($count)';
  }

  @override
  String get installAllSkillsTo => 'Installa tutti gli skills su';

  @override
  String installPackageSkills(String packagePath, int count) {
    return 'Installa tutti i $packagePath skills ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Installa $skill su';
  }

  @override
  String get availableInAllProjects => 'Tutti i progetti';

  @override
  String get availableInSelectedProjects => 'Progetti selezionati';

  @override
  String get usedBy => 'Per Agents';

  @override
  String get backToTargets => 'Torniamo agli obiettivi';

  @override
  String get stayHere => 'Resta qui';

  @override
  String get viewInLibrary => 'Visualizza nella libreria';

  @override
  String planCreateCount(int count) {
    return '$count creare';
  }

  @override
  String planSkipCount(int count) {
    return '$count salta';
  }

  @override
  String planReplaceCount(int count) {
    return '$count sostituire';
  }

  @override
  String planConflictCount(int count) {
    return 'Conflitto $count';
  }

  @override
  String planRiskCount(int count) {
    return 'Rischio $count bloccato';
  }

  @override
  String get refreshInstallationPlan => 'Applicare risoluzioni';

  @override
  String get replaceVersionConflict =>
      'Sostituisci la versione installata in questa destinazione';

  @override
  String get replaceSkillIdCollision =>
      'Sostituisci i diversi Skill ID su questo target';

  @override
  String get replaceLocalModification =>
      'Scarta le Modifiche Locali e sostituisci questo bersaglio';

  @override
  String get sharedTargetConflict =>
      'Questo percorso è condiviso dai target other Agent';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Ritornare alla matrice di destinazione e select a tutti gli Agent interessati prima di sostituire: $agents';
  }

  @override
  String get replaceConflictingTarget =>
      'Sostituisci la destinazione in conflitto';

  @override
  String get confirmHighRiskArtifact => 'Conferma di artefatti ad alto rischio';

  @override
  String get confirmCriticalRiskArtifact =>
      'Conferma dell\'override del rischio critico';

  @override
  String get confirmRiskForSelectedTargets =>
      'Ho esaminato i file degli artefatti e accetto questo rischio per gli obiettivi selezionati';

  @override
  String get criticalRiskBlocked =>
      'L\'installazione a rischio critico è bloccata';

  @override
  String get criticalRiskOverrideDisabled =>
      'Abilita l\'esplicito override del rischio critico nelle Impostazioni prima che questo piano possa continuare.';

  @override
  String get workspaceManifestChanges =>
      'Modifiche al manifesto dell\'area di lavoro';

  @override
  String get noWorkspaceManifestChanges =>
      'Nessun file manifest dell\'area di lavoro verrà modificato.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'non presente';

  @override
  String get planActionCreate => 'Creare';

  @override
  String get planActionReplace => 'Sostituire';

  @override
  String get planActionSkip => 'Saltare';

  @override
  String get planActionConflict => 'Conflitto';

  @override
  String get planActionBlockedByRisk => 'Bloccato dal rischio';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'Target $succeeded installati, $failed non riuscito';
  }

  @override
  String get installationProgressTitle => 'Installazione in corso';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished dei bersagli $total finiti';
  }

  @override
  String get targetWaiting => 'In attesa';

  @override
  String get targetRunning => 'Installazione';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Riprova $count target non riusciti',
      one: 'Riprova 1 target non riuscito',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Obiettivi Select da aggiornare';

  @override
  String get updatePlanDescription =>
      'Scegli gli obiettivi di installazione esatti. Agents e progetti deselezionati rimangono invariati.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected di target aggiornabili $available selezionati';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Riferimento fonte: $reference';
  }

  @override
  String get fixedVersionTarget => 'Bloccato: nessun riferimento mobile';

  @override
  String get currentVersionTarget => 'Aggiornato';

  @override
  String get updateCheckTargetFailed =>
      'Controllo dell\'aggiornamento non riuscito';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Riparare il manifesto dell\'area di lavoro';

  @override
  String get updateSelectedTargets => 'Aggiorna i target selezionati';

  @override
  String get updateProgressTitle => 'Aggiornamento degli obiettivi';

  @override
  String get updateResultsTitle => 'Aggiorna i risultati';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished dei bersagli $total finiti';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Riprova $count aggiornamenti non riusciti',
      one: 'Riprova 1 aggiornamento non riuscito',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Nessuna destinazione selezionata ha un aggiornamento disponibile.';

  @override
  String get closeUpdatePlan => 'Vicino';

  @override
  String get targetSucceeded => 'Installato';

  @override
  String get targetSkipped => 'Saltato';

  @override
  String get targetConflict => 'Conflitto';

  @override
  String get targetFailed => 'Fallito';

  @override
  String get targetFailureRetryable =>
      'Questa posizione non può essere modificata. Puoi riprovare.';

  @override
  String get targetFailureNeedsAttention =>
      'Questa posizione richiede la tua attenzione prima di riprovare.';

  @override
  String get installationTargetFailureMessage =>
      'Nulla è stato cambiato in questa posizione. Verifica che folder sia disponibile e riprova.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Non è stato modificato nulla perché SkillsGo non è riuscito a salvare le impostazioni del progetto. Verifica che il progetto folder sia scrivibile e riprova.';

  @override
  String get installationStateChangedMessage =>
      'Questa posizione è cambiata mentre la stavi rivedendo. Rivedi lo stato più recente prima di riprovare.';

  @override
  String get updateTargetFailureMessage =>
      'Impossibile aggiornare questa posizione. Le posizioni Other non sono state interessate, quindi puoi riprovare solo con questa.';

  @override
  String get managementTargetFailureMessage =>
      'Impossibile completare questa azione qui. Le posizioni Other non sono state interessate, quindi puoi riprovare solo con questa.';

  @override
  String get technicalDetails => 'Dettagli tecnici';

  @override
  String get targetPathExists =>
      'Un altro elemento esiste già in questa posizione.';

  @override
  String get targetBlockedByRisk =>
      'Le tue attuali impostazioni di sicurezza hanno bloccato l\'installazione in questa posizione.';

  @override
  String get targetInstallFailed =>
      'Impossibile installare skill in questa posizione.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'skill è stato installato, ma non è stato possibile aggiornare le impostazioni del progetto.';

  @override
  String get installationPlanFailed =>
      'Impossibile continuare il piano di installazione';

  @override
  String get installationFailed => 'Impossibile completare l\'installazione';

  @override
  String get localSource => 'Fonte locale';

  @override
  String get noDescriptionAvailable => 'Nessuna descrizione disponibile';

  @override
  String moreCoverage(int count) {
    return '+$count altre località';
  }

  @override
  String get batchAdoptionAction => 'Gestisci skills esistente';

  @override
  String handExternalSkillsToSkillsGoManagementCount(int count) {
    return 'Let SkillsGo manage $count external skills';
  }

  @override
  String confirmSkillsGoManagementCount(int selected, int total) {
    return 'Confirm SkillsGo management ($selected/$total)';
  }

  @override
  String get skillColumnLabel => 'Skill';

  @override
  String get packageSourceColumnLabel => 'Source';

  @override
  String get versionColumnLabel => 'Version';

  @override
  String get packageMatching => 'Matching sources…';

  @override
  String get sourceMatchUnavailable => 'Source matching unavailable';

  @override
  String get noSourceMatches => 'No matching source';

  @override
  String sourceMatchPercent(int percent) {
    return '$percent% match';
  }

  @override
  String get versionPendingSelection => 'Select a source first';

  @override
  String batchAdoptionActionCount(int count) {
    return 'Gestisci ($count)';
  }

  @override
  String get batchAdoptionChecking => 'Controllo skills esistente…';

  @override
  String get batchAdoptionRetry => 'Controlla di nuovo skills gestibile';

  @override
  String batchAdoptionEligibleCount(int count) {
    return '$count può essere gestito';
  }

  @override
  String get batchAdoptionPending => 'Aggiunta di skills alla gestione…';

  @override
  String get batchAdoptionTitle => 'Gestire skills esistente con SkillsGo?';

  @override
  String get batchAdoptionDescription =>
      'SkillsGo aggiungerà record di gestione locale senza spostare, sovrascrivere o caricare file skill. Gli elementi non supportati o modificati verranno ignorati.';

  @override
  String get batchAdoptionStoryTitle =>
      'Trasforma skills sparsi in un\'unica libreria libera';

  @override
  String batchAdoptionStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills esistente',
      one: '1 skill esistente',
    );
    return 'SkillsGo ha trovato $_temp0 che può gestire in questa posizione.';
  }

  @override
  String get batchAdoptionBeforeSemantics =>
      'Prima della gestione, non è chiaro dove siano installati gli skills esistenti, se siano attuali, come ripristinarli o se i progetti utilizzino la stessa versione.';

  @override
  String get batchAdoptionPainLocation =>
      'Percorso di installazione sconosciuto';

  @override
  String get batchAdoptionPainFreshness =>
      'Stato dell\'aggiornamento sconosciuto';

  @override
  String get batchAdoptionPainRecovery => 'Nessun recupero in caso di rottura';

  @override
  String get batchAdoptionPainVersionDrift => 'Versioni diverse nei progetti';

  @override
  String get batchAdoptionFolderTitle => 'Skills esistente';

  @override
  String get batchAdoptionFolderSubtitle => 'Stato poco chiaro';

  @override
  String get batchAdoptionAfterLabel => 'DOPO';

  @override
  String get batchAdoptionAfterTitle => 'Una libreria libera';

  @override
  String get batchAdoptionLibraryTitle => 'Libreria SkillsGo';

  @override
  String get batchAdoptionBenefitLocation => 'Posizioni chiare';

  @override
  String get batchAdoptionBenefitFreshness => 'Aggiornamenti visibili';

  @override
  String get batchAdoptionBenefitRecovery => 'Recupero facile';

  @override
  String get batchAdoptionBenefitVersions => 'Versioni chiare';

  @override
  String get batchAdoptionManagedSection => 'Gestito da SkillsGo';

  @override
  String get batchAdoptionPendingSection => 'In attesa di';

  @override
  String batchAdoptionItemManaged(String name) {
    return '$name è gestito da SkillsGo';
  }

  @override
  String batchAdoptionItemSkipped(String name) {
    return 'Impossibile aggiungere $name alla gestione';
  }

  @override
  String batchAdoptionItemPending(String name) {
    return '$name è in attesa di essere gestito';
  }

  @override
  String batchAdoptionAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills are',
      one: '1 skill is',
    );
    return 'Dopo la gestione, $_temp0 organizzati in un\'unica libreria con uno stato gestito chiaro.';
  }

  @override
  String batchAdoptionMoreSkills(int count) {
    return '+$count altro';
  }

  @override
  String get batchAdoptionTransitionSemantics =>
      'Aggiungi questi skills esistenti alla gestione SkillsGo.';

  @override
  String get batchAdoptionTransitionLabel => 'ORGANIZZARE';

  @override
  String get batchAdoptionStatusTitle => 'Stato di gestione';

  @override
  String get batchAdoptionStatusManaged => 'Gestito';

  @override
  String get batchAdoptionStatusProgress => 'Organizzare';

  @override
  String get batchAdoptionStatusSkipped => 'Saltato';

  @override
  String get batchAdoptionStatusFilesStay =>
      'I file Skill rimangono nelle posizioni originali';

  @override
  String get batchAdoptionBoardSemantics =>
      'Skills sono disposti in righe complete e registrati da SkillsGo senza spostare i file.';

  @override
  String get batchAdoptionBoardComplete => 'TUTTO CHIARO';

  @override
  String get batchAdoptionBoardPartial => 'COMPLETARE';

  @override
  String get batchAdoptionStatusTotal => 'Totale';

  @override
  String get batchAdoptionQueueComplete => 'Nessuno skills sta aspettando';

  @override
  String get batchAdoptionQueueWaiting =>
      'Dopo la verifica, gli Skill verranno visualizzati qui';

  @override
  String get batchAdoptionNextLabel => 'PROSSIMO';

  @override
  String batchAdoptionFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo blocchi organizzatore',
      one: '1 blocco organizzatore SkillsGo',
    );
    return '$_temp0 completa le righe finali';
  }

  @override
  String get batchAdoptionPreservation =>
      'I tuoi file, percorsi e flussi di lavoro attuali rimangono esattamente dove sono. SkillsGo completa solo i registri di gestione locale.';

  @override
  String get batchAdoptionLaterHint =>
      'Se salti l\'operazione, puoi utilizzare Gestisci skills esistente dalla Libreria in qualsiasi momento.';

  @override
  String get batchAdoptionSkip => 'Non adesso';

  @override
  String get batchAdoptionConfirm => 'Aggiungi alla gestione';

  @override
  String get batchAdoptionExecutionRetry => 'Riprova';

  @override
  String get batchAdoptionResultTitle => 'Skills aggiunto alla gestione';

  @override
  String batchAdoptionSummary(int adopted, int skipped) {
    return '$adopted skills aggiunto alla gestione, $skipped saltato.';
  }

  @override
  String batchAdoptionFailureSummary(int adopted, int failed) {
    return '$adopted skills added to management, $failed failed.';
  }

  @override
  String get batchAdoptionStatusFailed => 'Failed';

  @override
  String batchAdoptionItemFailed(String name) {
    return '$name failed';
  }

  @override
  String get batchAdoptionClose => 'Chiudi';

  @override
  String get installMoreTargets => 'Installa in più posizioni';

  @override
  String get detailPackageSource => 'Origine del pacchetto';

  @override
  String get detailStars => 'Stelle';

  @override
  String get detailUpdated => 'Aggiornato';

  @override
  String get detailArchiveSize => 'Dimensione del pacchetto';

  @override
  String get pathLabel => 'Percorso del progetto';

  @override
  String get copyProjectPath => 'Copia il percorso del progetto';

  @override
  String get projectPathCopied => 'Percorso del progetto copiato';

  @override
  String get onboardingWelcomeTitle => 'Benvenuti in SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Scopri, installa e gestisci Skills nel tuo Agents e nei tuoi progetti.';

  @override
  String get onboardingDetectedAgents => 'Rilevato Agents';

  @override
  String get onboardingNoAgents =>
      'Nessun Agents installato rilevato. Puoi ancora continuare.';

  @override
  String get onboardingNext => 'Prossimo';

  @override
  String get onboardingProjectsTitle => 'Aggiungi i tuoi progetti';

  @override
  String get onboardingProjectsDescription =>
      'Scegli i progetti che vuoi che SkillsGo gestisca.';

  @override
  String get onboardingAddProject => 'Aggiungi ora';

  @override
  String get onboardingAddProjectLater => 'o più tardi';

  @override
  String get onboardingStartUsing => 'Inizia a utilizzare SkillsGo';

  @override
  String get onboardingBack => 'Indietro';

  @override
  String get restartOnboardingTitle => 'Onboarding';

  @override
  String get restartOnboardingDescription =>
      'Visualizza nuovamente la guida al primo avvio senza rimuovere progetti, impostazioni o dati Skills.';

  @override
  String get restartOnboardingAction => 'Riavviare l\'onboarding';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo non è riuscito a riavviare l\'onboarding.';

  @override
  String get libraryRefreshSettingsTitle => 'Aggiorna la libreria locale';

  @override
  String get libraryRefreshSettingsDescription =>
      'Eseguire nuovamente la scansione di Skills installato, progetti aggiunti, Agents e Skills esterni che possono essere gestiti. Questo non installa, aggiorna o rimuove nulla.';

  @override
  String get libraryRefreshSettingsAction => 'Aggiorna libreria';

  @override
  String get libraryRefreshSettingsPending => 'Aggiornamento della libreria…';

  @override
  String get libraryRefreshSettingsSuccess => 'Biblioteca locale aggiornata.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo non è riuscito ad aggiornare la libreria locale.';

  @override
  String get onboardingProjectError =>
      'SkillsGo non ha potuto aggiungere progetti da questa directory.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo non è riuscito a caricare i progetti aggiunti.';

  @override
  String get onboardingStartupError =>
      'SkillsGo non è riuscito a caricare la configurazione.';

  @override
  String get onboardingStateError =>
      'SkillsGo non è riuscito a salvare l\'avanzamento della configurazione. Riprova.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI necessita di attenzione';

  @override
  String get onboardingCliErrorDescription =>
      'Riparare lo CLI in bundle, quindi riprovare per continuare.';

  @override
  String get removeSkillsDescription => 'The following Skills will be removed';

  @override
  String confirmRemoveSkillsInline(int count) {
    return 'Remove $count Skills?';
  }

  @override
  String removingSkillsProgress(int finished, int total) {
    return 'Removing $finished/$total';
  }

  @override
  String get confirmRemoveSkillsAction => 'Remove now';

  @override
  String get viewRemovalDetails => 'View details';

  @override
  String get hideRemovalDetails => 'Hide details';
}
