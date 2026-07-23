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
  String get userScope => 'Globale';

  @override
  String get addProject => 'Aggiungi progetto';

  @override
  String get relocateProject => 'Trasferirsi';

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
      'La directory potrebbe essere stata spostata o il suo volume potrebbe essere offline. Riposizionalo o rimuovi solo il riferimento all\'app.';

  @override
  String get projectPermissionTitle =>
      'È richiesta l\'autorizzazione al progetto';

  @override
  String get projectPermissionMessage =>
      'SkillsGo non può ispezionare questa radice selezionata. Concedi l\'accesso riposizionandolo tramite il selettore di directory.';

  @override
  String get projectInaccessibleTitle =>
      'La directory del progetto è inaccessibile';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo ha mantenuto questo riferimento al progetto. Controllare il percorso o il volume, quindi riposizionarlo.';

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
  String get manageTargets => 'Gestire l\'ambito';

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
  String get manageTargetsTitle => 'Gestire le destinazioni di installazione';

  @override
  String get manageTargetsDescription =>
      'Scegli un\'azione esatta per ciascun bersaglio. I target non selezionati non cambieranno.';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'Bersagli $selected di $total selezionati';
  }

  @override
  String get repairTarget => 'Riparazione';

  @override
  String get confirmRemoveTarget => 'Conferma la rimozione';

  @override
  String get applyTargetActions => 'Applica le azioni selezionate';

  @override
  String get managementProgressTitle => 'Applicazione delle azioni target';

  @override
  String get managementResultsTitle => 'Risultati dell\'azione mirata';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded ha avuto successo, $failed ha fallito';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Le azioni del progetto selezionate aggiorneranno skillsgo.yaml e skillsgo.lock.';

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
      'Le tue ricerche non vengono salvate e SkillsGo non conserva i registri dei comandi.';

  @override
  String get language => 'Lingua';

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
  String get userLevel => 'Livello utente';

  @override
  String get projectLevel => 'Livello di progetto';

  @override
  String get projects => 'Progetti';

  @override
  String get loading => 'Caricamento…';

  @override
  String get repositoryParsing => 'Analisi del repository…';

  @override
  String userInstallSummary(int agents) {
    return 'Disponibile per $agents Agents a livello utente';
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
  String installAllRepositorySkills(int count) {
    return 'Installa tutto il repository skills ($count)';
  }

  @override
  String get installAllSkillsTo => 'Installa tutti gli skills su';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Installa tutti i $repository skills ($count)';
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
  String get batchTakeoverAction => 'Gestisci skills esistente';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Gestisci ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Controllo skills esistente…';

  @override
  String get batchTakeoverRetry => 'Controlla di nuovo skills gestibile';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count può essere gestito';
  }

  @override
  String get batchTakeoverPending => 'Aggiunta di skills alla gestione…';

  @override
  String get batchTakeoverTitle => 'Gestire skills esistente con SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo aggiungerà record di gestione locale senza spostare, sovrascrivere o caricare file skill. Gli elementi non supportati o modificati verranno ignorati.';

  @override
  String get batchTakeoverStoryTitle =>
      'Trasforma skills sparsi in un\'unica libreria libera';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills esistente',
      one: '1 skill esistente',
    );
    return 'SkillsGo ha trovato $_temp0 che può gestire in questa posizione.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Prima della gestione, non è chiaro dove siano installati gli skills esistenti, se siano attuali, come ripristinarli o se i progetti utilizzino la stessa versione.';

  @override
  String get batchTakeoverPainLocation =>
      'Percorso di installazione sconosciuto';

  @override
  String get batchTakeoverPainFreshness =>
      'Stato dell\'aggiornamento sconosciuto';

  @override
  String get batchTakeoverPainRecovery => 'Nessun recupero in caso di rottura';

  @override
  String get batchTakeoverPainVersionDrift => 'Versioni diverse nei progetti';

  @override
  String get batchTakeoverFolderTitle => 'Skills esistente';

  @override
  String get batchTakeoverFolderSubtitle => 'Stato poco chiaro';

  @override
  String get batchTakeoverAfterLabel => 'DOPO';

  @override
  String get batchTakeoverAfterTitle => 'Una libreria libera';

  @override
  String get batchTakeoverLibraryTitle => 'Libreria SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Posizioni chiare';

  @override
  String get batchTakeoverBenefitFreshness => 'Aggiornamenti visibili';

  @override
  String get batchTakeoverBenefitRecovery => 'Recupero facile';

  @override
  String get batchTakeoverBenefitVersions => 'Versioni chiare';

  @override
  String get batchTakeoverManagedSection => 'Gestito da SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'In attesa di';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name è gestito da SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return 'Impossibile aggiungere $name alla gestione';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name è in attesa di essere gestito';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills are',
      one: '1 skill is',
    );
    return 'Dopo la gestione, $_temp0 organizzati in un\'unica libreria con uno stato gestito chiaro.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count altro';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Aggiungi questi skills esistenti alla gestione SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANIZZARE';

  @override
  String get batchTakeoverStatusTitle => 'Stato di gestione';

  @override
  String get batchTakeoverStatusManaged => 'Gestito';

  @override
  String get batchTakeoverStatusProgress => 'Organizzare';

  @override
  String get batchTakeoverStatusSkipped => 'Saltato';

  @override
  String get batchTakeoverStatusFilesStay =>
      'I file Skill rimangono nelle posizioni originali';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills sono disposti in righe complete e registrati da SkillsGo senza spostare i file.';

  @override
  String get batchTakeoverBoardComplete => 'TUTTO CHIARO';

  @override
  String get batchTakeoverBoardPartial => 'COMPLETARE';

  @override
  String get batchTakeoverStatusTotal => 'Totale';

  @override
  String get batchTakeoverQueueComplete => 'Nessuno skills sta aspettando';

  @override
  String get batchTakeoverQueueWaiting =>
      'Dopo la verifica, gli Skill verranno visualizzati qui';

  @override
  String get batchTakeoverNextLabel => 'PROSSIMO';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo blocchi organizzatore',
      one: '1 blocco organizzatore SkillsGo',
    );
    return '$_temp0 completa le righe finali';
  }

  @override
  String get batchTakeoverPreservation =>
      'I tuoi file, percorsi e flussi di lavoro attuali rimangono esattamente dove sono. SkillsGo completa solo i registri di gestione locale.';

  @override
  String get batchTakeoverLaterHint =>
      'Se salti l\'operazione, puoi utilizzare Gestisci skills esistente dalla Libreria in qualsiasi momento.';

  @override
  String get batchTakeoverSkip => 'Non adesso';

  @override
  String get batchTakeoverConfirm => 'Aggiungi alla gestione';

  @override
  String get batchTakeoverExecutionRetry => 'Riprova';

  @override
  String get batchTakeoverResultTitle => 'Skills aggiunto alla gestione';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver skills aggiunto alla gestione, $skipped saltato.';
  }

  @override
  String get batchTakeoverClose => 'Chiudi';

  @override
  String get installMoreTargets => 'Installa in più posizioni';

  @override
  String get exportLocalSkill => 'Esportare';

  @override
  String get exportLocalSkillDescription =>
      'Esporta questo Skill locale come archivio ZIP portatile.';

  @override
  String get detailRepository => 'Deposito';

  @override
  String get detailStars => 'Stelle';

  @override
  String get detailUpdated => 'Aggiornato';

  @override
  String get detailArchiveSize => 'Dimensione ZIP';

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
}
