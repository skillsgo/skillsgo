// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get discover => 'Découvrir';

  @override
  String get discoverSkills => 'C\'est bien d\'en savoir un peu plus.';

  @override
  String get library => 'Bibliothèque';

  @override
  String get settings => 'Paramètres';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get cliNeedsAttention =>
      'Un composant SkillsGo requis nécessite une attention particulière.';

  @override
  String get cliMissingBundled =>
      'Un composant SkillsGo requis est manquant ou ne peut pas démarrer. Réinstallez SkillsGo pour le restaurer.';

  @override
  String get cliDamagedBundled =>
      'Un composant SkillsGo requis est endommagé. Réinstallez SkillsGo pour le restaurer.';

  @override
  String get cliIncompatibleBundled =>
      'Un composant SkillsGo requis ne correspond pas à cette version de l\'application. Mettez à jour ou réinstallez SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Trouvez un Skill pour votre prochaine étape.';

  @override
  String get skillsLeaderboard => 'C\'est bien d\'en savoir un peu plus.';

  @override
  String searchResultsFor(String query) {
    return 'Résultats pour « $query »';
  }

  @override
  String get searchSkills => 'Recherchez skills ou collez un lien Git…';

  @override
  String get search => 'Recherche';

  @override
  String get ranking => 'Classement';

  @override
  String get trending => 'Tendance';

  @override
  String get hot => 'Chaud';

  @override
  String get discoverNavigation => 'Découvrir la navigation';

  @override
  String get allTimeRanking => 'Classement de tous les temps';

  @override
  String get trendingNow => 'Tendance des dernières 24 heures';

  @override
  String get hotNow => 'Chaud en ce moment';

  @override
  String get allTimeDescription =>
      'Skills publics classés selon le nombre total d’installations acceptées.';

  @override
  String get trendingDescription =>
      'Skills publics classés selon les installations acceptées au cours des dernières 24 heures.';

  @override
  String get hotDescription =>
      'Skills publics classés selon la cadence récente des installations et son évolution.';

  @override
  String get offlineTitle => 'Impossible de se connecter à SkillsGo';

  @override
  String get offlineMessage =>
      'Vérifiez votre connexion Internet et réessayez. Si vous utilisez un proxy ou une adresse de service personnalisée, vérifiez-la dans Paramètres.';

  @override
  String get searchFailedTitle => 'La recherche a échoué';

  @override
  String get validationTitle => 'Vérifiez ce que vous avez entré';

  @override
  String get validationMessage =>
      'SkillsGo n\'a pas pu utiliser cette requête. Vérifiez ce que vous avez saisi et réessayez.';

  @override
  String get serverTitle => 'Service temporairement indisponible';

  @override
  String get serverMessage =>
      'SkillsGo ne peut pas répondre à cette demande pour le moment. Réessayez dans un instant.';

  @override
  String get timeoutTitle => 'Cela prend trop de temps';

  @override
  String get timeoutMessage =>
      'Le service n\'a pas répondu à temps. Vérifiez votre connexion ou réessayez.';

  @override
  String get invalidResponseTitle => 'SkillsGo a besoin d\'une mise à jour';

  @override
  String get invalidResponseMessage =>
      'Cette réponse ne peut pas être lue par votre version de SkillsGo. Mettez à jour l\'application, puis réessayez.';

  @override
  String get invalidLocalDataTitle => 'Impossible de lire un skill installé';

  @override
  String get invalidLocalDataMessage =>
      'Certaines informations d\'installation locale sont endommagées ou incompatibles. Mettez à jour ou réinstallez SkillsGo, puis réessayez.';

  @override
  String get tryAgain => 'Essayer à nouveau';

  @override
  String get searchEmptyTitle => 'Recherchez, ne faites pas défiler.';

  @override
  String get searchEmptyMessage =>
      'Entrez une capacité, une source ou une tâche pour rechercher le skills public.';

  @override
  String get noSkillsTitle => 'Aucun skills trouvé';

  @override
  String get noSkillsMessage =>
      'Essayez une phrase plus large ou vérifiez l’orthographe.';

  @override
  String get focusSearch => 'Recherche ciblée';

  @override
  String get skillsFromLink => 'Skills à partir de ce lien';

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
      other: '$count skills de $source',
      one: '1 skill de $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Ce lien est prêt à inspecter';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source ne figure pas dans les résultats de recherche actuels. SkillsGo peut inspecter le lien directement à l\'étape suivante.';
  }

  @override
  String get inspectSource => 'Voir skills dans ce lien';

  @override
  String get collectionEmptyTitle => 'Aucun Skills dans cette collection';

  @override
  String get collectionEmptyMessage =>
      'Il n’y a encore rien ici. Réessayez après d\'autres activités d\'installation.';

  @override
  String get loadMore => 'Charger plus';

  @override
  String get install => 'Installer';

  @override
  String get installAll => 'Installez tous les skills';

  @override
  String get latestCommit => 'Dernier commit';

  @override
  String get installToMoreTargets => 'Installer dans plus d\'emplacements';

  @override
  String localTargets(int count) {
    return 'Cibles locales $count';
  }

  @override
  String allTimeMetric(String count) {
    return '$count installations de tous les temps';
  }

  @override
  String trendingMetric(String count) {
    return '$count installations / 24h';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value cette heure · $change';
  }

  @override
  String get trustUnverified => 'Non vérifié';

  @override
  String get trustCommunityVerified => 'Communauté vérifiée';

  @override
  String get trustPublisherVerified => 'Éditeur vérifié';

  @override
  String get trustOfficial => 'Officiel';

  @override
  String get trustWarned => 'Averti';

  @override
  String get trustDelisted => 'Radié';

  @override
  String get riskUnknown => 'Risque inconnu';

  @override
  String get riskLow => 'Faible risque';

  @override
  String get riskMedium => 'Risque moyen';

  @override
  String get riskHigh => 'Risque élevé';

  @override
  String get riskCritical => 'Risque critique';

  @override
  String openSkill(String name) {
    return 'Ouvrir $name';
  }

  @override
  String installs(String count) {
    return '$count installe';
  }

  @override
  String get detailFailedTitle => 'Impossible de charger ce Skill';

  @override
  String get detailLoading => 'Chargement des détails vérifiables du Skill';

  @override
  String get artifactUnavailableTitle => 'Artefact indisponible';

  @override
  String get artifactUnavailableMessage =>
      'Cette version n\'est pas disponible pour le moment. Réessayez ou choisissez une autre version.';

  @override
  String get detailInvalidTitle =>
      'Métadonnées d\'artefact non prises en charge';

  @override
  String get detailInvalidMessage =>
      'Certains détails de ce skill sont incomplets ou ne peuvent pas être lus. Mettez à jour SkillsGo, puis réessayez.';

  @override
  String get instructionsTab => 'Instructions';

  @override
  String get manifestTab => 'Manifeste';

  @override
  String immutableVersionLabel(String version) {
    return 'Immuable $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Valider $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Arbre $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Contenu $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'La confiance de l\'éditeur vérifie la propriété ou la maintenance ; il ne certifie pas la sécurité des artefacts. Le risque est évalué séparément pour cette version immuable.';

  @override
  String get knownInstallationTargets => 'Cibles d\'installation connues';

  @override
  String get installationRange => 'Portée installée';

  @override
  String get targetDetails => 'Afficher les détails de la cible';

  @override
  String get hideTargetDetails => 'Masquer les détails de la cible';

  @override
  String installedVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Projet';

  @override
  String get fileContentUnavailable => 'Aperçu binaire ou indisponible';

  @override
  String get fileContentTruncated =>
      'Aperçu tronqué par la limite de sécurité Hub.';

  @override
  String get retry => 'Réessayer';

  @override
  String get backToSearch => 'Retour à la recherche';

  @override
  String get installForCodex => 'Installer pour Codex';

  @override
  String get cliNotDetected => 'skills (non détecté)';

  @override
  String get snapshotFiles => 'Fichiers d\'instantanés';

  @override
  String get globalCodex => 'Mondial · Codex';

  @override
  String get yourLibrary => 'Tout ce que vous savez est ici.';

  @override
  String get libraryNavigation => 'Navigation dans la bibliothèque';

  @override
  String get all => 'Tous';

  @override
  String get allSkills => 'Tous les Skills';

  @override
  String get updatesOnly => 'Mises à jour';

  @override
  String get allAgents => 'Tous les Agents';

  @override
  String get allProjects => 'Tous les projets';

  @override
  String get specificProject => 'Projet';

  @override
  String get userScope => 'Mondial';

  @override
  String get addProject => 'Ajouter un projet';

  @override
  String get relocateProject => 'Déménager';

  @override
  String get removeFromList => 'Supprimer de la liste';

  @override
  String removeProjectTitle(String name) {
    return 'Supprimer $name de SkillsGo ?';
  }

  @override
  String get removeProjectDescription =>
      'Seule la référence à l\'application sera supprimée. SkillsGo ne modifiera ni ne supprimera aucun fichier de ce répertoire.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — indisponible';
  }

  @override
  String get emptyProjectTitle => 'Pas encore de Skills';

  @override
  String get browseSkills => 'Parcourir Skills';

  @override
  String get projectMissingTitle => 'Le répertoire du projet est manquant';

  @override
  String get projectMissingMessage =>
      'Le répertoire a peut-être été déplacé ou son volume est peut-être hors ligne. Déplacez-le ou supprimez uniquement sa référence d\'application.';

  @override
  String get projectPermissionTitle => 'L\'autorisation du projet est requise';

  @override
  String get projectPermissionMessage =>
      'SkillsGo ne peut pas inspecter cette racine sélectionnée. Accordez l\'accès en le déplaçant via le sélecteur de répertoire.';

  @override
  String get projectInaccessibleTitle =>
      'Le répertoire du projet est inaccessible';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo a conservé cette référence de projet. Vérifiez le chemin ou le volume, puis déplacez-le.';

  @override
  String get checking => 'Vérification…';

  @override
  String get checkUpdates => 'Vérifier les mises à jour';

  @override
  String get refresh => 'Rafraîchir';

  @override
  String get libraryUnavailable => 'Bibliothèque indisponible';

  @override
  String get libraryEmpty => 'Aucun skills n\'est encore installé';

  @override
  String get libraryEmptyMessage =>
      'Installez un Skill depuis Discover et il apparaîtra ici.';

  @override
  String get searchLibrary => 'Rechercher les skills installés';

  @override
  String get libraryNoMatches => 'Aucun Skills correspondant';

  @override
  String get libraryNoMatchesMessage =>
      'Essayez un autre nom, source, Agent, projet ou version.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return 'Projets $count';
  }

  @override
  String versionsSummary(int count) {
    return 'Versions $count';
  }

  @override
  String get hubManaged => 'Hub géré';

  @override
  String get localManaged => 'Géré localement';

  @override
  String get externalInstallation => 'Installation externe';

  @override
  String get readOnly => 'Lecture seule';

  @override
  String get unversioned => 'Non versionné';

  @override
  String get supportingFiles => 'Fichiers de support';

  @override
  String get versionDivergence => 'Différence de version';

  @override
  String get healthHealthy => 'En bonne santé';

  @override
  String get healthMissing => 'Cible manquante';

  @override
  String get healthReplaced => 'Cible remplacée';

  @override
  String get healthLocalModification => 'Modification locale';

  @override
  String get healthUnreadable => 'Cible illisible';

  @override
  String get healthUndeclared => 'Non déclaré';

  @override
  String get healthWorkspaceUnreadable =>
      'État de l\'espace de travail illisible';

  @override
  String get healthLockMismatch => 'Incompatibilité de verrouillage';

  @override
  String get healthUnexpectedPath => 'Chemin cible inattendu';

  @override
  String get modeExternal => 'Externe';

  @override
  String get notLinked => 'NON LIÉ';

  @override
  String get update => 'Mise à jour';

  @override
  String get backToLibrary => 'Retour à la bibliothèque';

  @override
  String get remove => 'Retirer';

  @override
  String get manageTargets => 'Gérer la portée';

  @override
  String skillsSelected(int count) {
    return '$count sélectionné';
  }

  @override
  String get clearSelection => 'Effacer la sélection';

  @override
  String get selectCurrentResults => 'Résultats actuels de Select';

  @override
  String get clearCurrentResultSelection =>
      'Effacer la sélection de résultats actuelle';

  @override
  String get manageTargetsTitle => 'Gérer les cibles d\'installation';

  @override
  String get manageTargetsDescription =>
      'Choisissez une action exacte pour chaque cible. Les cibles non sélectionnées ne changeront pas.';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'Cibles $selected sur $total sélectionnées';
  }

  @override
  String get repairTarget => 'Réparation';

  @override
  String get confirmRemoveTarget => 'Confirmer la suppression';

  @override
  String get applyTargetActions => 'Appliquer les actions sélectionnées';

  @override
  String get managementProgressTitle => 'Appliquer des actions cibles';

  @override
  String get managementResultsTitle => 'Cibler les résultats des actions';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded a réussi, $failed a échoué';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Les actions de projet sélectionnées mettront à jour skillsgo.yaml et skillsgo.lock.';

  @override
  String get targetContentPreserved => 'Le contenu cible actuel sera conservé.';

  @override
  String get localReadFailed => 'Je ne peux pas lire ce Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo n\'a pas pu lire ce skill installé. Vérifiez que son folder est disponible et accessible, puis réessayez.';

  @override
  String get localConfiguration => 'PARAMÈTRES SKILLSGO';

  @override
  String get settingsNavigation => 'Navigation dans les paramètres';

  @override
  String get general => 'Personnaliser';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Politique d\'installation';

  @override
  String get storage => 'Stockage';

  @override
  String get colorScheme => 'Schéma de couleurs';

  @override
  String get about => 'À propos';

  @override
  String get colorSchemeInspectorTitle => 'Rôles de couleurs Material générés';

  @override
  String get skillsColorTokensTitle => 'Couleurs sémantiques SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Couleurs de produits construites à partir de Radix Sand et organisées avec la sémantique Primer, avec Folder comme hiérarchie spatiale dédiée.';

  @override
  String get colorSchemeInspectorDescription =>
      'Prévisualisez chaque jeton ColorScheme non obsolète généré à partir de la graine actuelle. Cliquez sur une couleur pour copier sa valeur HEX.';

  @override
  String get colorSchemePairPreview => 'Paires sémantiques';

  @override
  String get colorSchemePairPreviewDescription =>
      'Rôles de premier plan et d\'arrière-plan rendus ensemble pour exposer le contraste et la hiérarchie.';

  @override
  String get colorSchemeComponentPreview => 'Aperçu du composant';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Contrôles Material représentatifs rendus avec ce schéma d\'aperçu exact.';

  @override
  String get colorSchemeSampleTitle => 'Titre de la carte Skill';

  @override
  String get colorSchemeSampleBody =>
      'La copie secondaire utilise onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Copié';

  @override
  String get colorSchemeSampleGlyphs => 'AA 123';

  @override
  String get colorSchemeGroupPrimary => 'Primaire';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Accent principal, conteneurs et rôles d\'accent fixe.';

  @override
  String get colorSchemeGroupSecondary => 'Secondaire';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Accent mis sur le soutien et rôles secondaires fixes.';

  @override
  String get colorSchemeGroupTertiary => 'Tertiaire';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Des accents contrastés et des rôles tertiaires figés.';

  @override
  String get colorSchemeGroupSurface => 'Surface';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Hiérarchie de page, de conteneur, d’élévation et de premier plan.';

  @override
  String get colorSchemeGroupUtility => 'Aperçu et utilité';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Limites, ombres, canevas et surfaces inversées.';

  @override
  String get colorSchemeGroupError => 'Erreur';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Actions d\'erreur, messages et conteneurs.';

  @override
  String get colorSchemeUsagePrimary =>
      'Actions principales, concentration et accents élevés.';

  @override
  String get colorSchemeUsageSecondary =>
      'Actions de soutien et accents moyens.';

  @override
  String get colorSchemeUsageTertiary =>
      'Des accents contrastés qui complètent le primaire et le secondaire.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Texte et icônes affichés sur $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Conteneur $family à faible accentuation pour les sélections et les accents.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Conteneur $family fixe indépendant de la luminosité.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Conteneur $family fixe à intensité variable et indépendant de la luminosité.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Contenu mettant l\'accent sur le conteneur $family fixe.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Contenu moins important sur le conteneur $family fixe.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Page de base et surface de grande région.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Surface de base atténuée utilisée sur le ton de surface le plus foncé.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Surface de base brillante utilisée avec le ton de surface le plus clair.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'L\'élévation du conteneur de surface $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'le plus bas';

  @override
  String get colorSchemeElevationLow => 'faible';

  @override
  String get colorSchemeElevationDefault => 'défaut';

  @override
  String get colorSchemeElevationHigh => 'haut';

  @override
  String get colorSchemeElevationHighest => 'le plus élevé';

  @override
  String get colorSchemeUsageOnSurface =>
      'Texte principal et icônes affichés sur les surfaces.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Texte secondaire, étiquettes et icônes discrètes sur les surfaces.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Teinte d\'élévation Material dérivée du primaire.';

  @override
  String get colorSchemeUsageOutline =>
      'Limites importantes et contours des composants ciblés.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Limites subtiles, séparateurs et contours peu accentués.';

  @override
  String get colorSchemeUsageShadow =>
      'Couleur d\'ombre portée pour les surfaces surélevées.';

  @override
  String get colorSchemeUsageScrim =>
      'Superposition modale utilisée pour minimiser le contenu d\'arrière-plan.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Surface avec lumière inversée et accent sombre.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Accent primaire affiché sur une surface inversée.';

  @override
  String get colorSchemeUsageError =>
      'Actions d’erreur, statut et commentaires très importants.';

  @override
  String get save => 'Sauvegarder';

  @override
  String get advancedSettings => 'Avancé';

  @override
  String get remindersSettings => 'Rappels';

  @override
  String get remindersSettingsTitle => 'Paramètres de rappel';

  @override
  String get remindersSettingsDescription =>
      'Choisissez les rappels à recevoir.';

  @override
  String get updateReminderTitle => 'Mettre à jour les rappels';

  @override
  String get updateReminderDescription =>
      'Recherchez les mises à jour à l\'ouverture de la bibliothèque.';

  @override
  String get securityReminderTitle => 'Alertes à haut risque';

  @override
  String get securityReminderDescription =>
      'Vous avertir des nouveaux risques élevés ou critiques dans le skills installé.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count installé skills ont des mises à jour';
  }

  @override
  String get openAvailableUpdates =>
      'Ouvrez la vue des mises à jour disponibles pour les examiner et les mettre à jour.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count installé skills nécessite un examen de sécurité';
  }

  @override
  String get reviewInstalledSkills =>
      'Examinez leurs informations sur les risques avant de les utiliser ou de les mettre à jour.';

  @override
  String get generalSettingsTitle => 'Personnalisez le SkillsGo';

  @override
  String get generalSettingsDescription =>
      'L\'interface suit la langue de votre système, l\'accessibilité et les préférences de mouvement.';

  @override
  String get agentsSettingsTitle => 'Exécution Agent';

  @override
  String get hubSettingsTitle => 'Hub Origine';

  @override
  String get hubSettingsDescription =>
      'Utilisez le Hub officiel ou une origine HTTP(S) auto-hébergée qui implémente le même protocole SkillsGo.';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get saveOrigin => 'Enregistrer l\'origine';

  @override
  String get resetDefault => 'Réinitialiser aux valeurs par défaut';

  @override
  String get connectionReady => 'Connexion prête';

  @override
  String get connectionFailed => 'La connexion a échoué';

  @override
  String get hubInvalidOrigin =>
      'Saisissez une origine HTTP(S) valide sans informations d\'identification, requête ou fragment.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub a renvoyé HTTP $status. Vérifiez l\'origine et la configuration du serveur.';
  }

  @override
  String get hubInvalidProtocol =>
      'Le serveur n\'a pas renvoyé le protocole de recherche SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Le Hub a renvoyé un JSON non valide.';

  @override
  String get hubConnectionFailure =>
      'Impossible d\'atteindre le Hub. Vérifiez la configuration Origin, réseau, proxy et TLS.';

  @override
  String get hubConnectionTimeout =>
      'La connexion Hub a expiré. Vérifiez le réseau ou réessayez.';

  @override
  String get riskPolicyTitle => 'Politique de risques personnels';

  @override
  String get riskPolicyDescription =>
      'Des règles de sécurité s\'appliquent lorsque vous installez ou mettez à jour un skill.';

  @override
  String get confirmHighRisk => 'Exiger une confirmation pour risque élevé';

  @override
  String get confirmHighRiskDescription =>
      'Les artefacts à haut risque nécessitent toujours une confirmation supplémentaire avant l\'installation.';

  @override
  String get allowCriticalOverride =>
      'Autoriser un remplacement explicite du risque critique';

  @override
  String get allowCriticalOverrideDescription =>
      'Les artefacts à risque critique restent bloqués par défaut. Activez cette option uniquement pour exposer une commande manuelle distincte.';

  @override
  String get storageHealthy => 'Lisible';

  @override
  String get storageNotInitialized => 'Non initialisé';

  @override
  String get storageUnavailable => 'Indisponible';

  @override
  String get storageInvalidResponse =>
      'Le CLI fourni a renvoyé une réponse de diagnostic non prise en charge.';

  @override
  String get aboutSettingsTitle => 'Compatibilité du produit';

  @override
  String get appVersion => 'Version de l\'application';

  @override
  String get cliVersion => 'Version CLI groupée';

  @override
  String get compatible => 'Compatible';

  @override
  String get hubOriginSaved => 'Hub Origine enregistrée et appliquée.';

  @override
  String get policySaved => 'Politique d\'installation enregistrée.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'PRÊT';

  @override
  String get unknown => 'INCONNU';

  @override
  String get missing => 'MANQUANT';

  @override
  String get incompatible => 'INCOMPATIBLE';

  @override
  String get detecting => 'Détection…';

  @override
  String get customCliPath => 'Chemin d\'accès à l\'exécutable personnalisé';

  @override
  String get saveAndDetect => 'Enregistrer et détecter';

  @override
  String get detectAgain => 'Détecter à nouveau';

  @override
  String get agentInstalled => 'Installé';

  @override
  String get agentSupported => 'Soutenu';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed installé · $supported pris en charge';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Installé · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Non installé · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Pris en charge par SkillsGo, mais non détecté sur ce Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Chemins de chargement Skill : $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Les données de détection Agent ne sont pas disponibles. Exécutez à nouveau la détection.';

  @override
  String get noInstalledAgentsTitle => 'Aucun Agents installé détecté';

  @override
  String get noInstalledAgentsMessage =>
      'Vous pouvez continuer à parcourir ce Skill, mais il n\'y a pas encore de cible d\'installation. Installez un Agent pris en charge, puis exécutez à nouveau la détection.';

  @override
  String get clearCustomPath => 'Effacer le chemin personnalisé';

  @override
  String get privacyProvenance => 'Confidentialité et provenance';

  @override
  String get privacySummary =>
      'Vos recherches ne sont pas enregistrées et SkillsGo ne conserve pas de journaux de commandes.';

  @override
  String get language => 'Langue';

  @override
  String get personalizationTheme => 'Thème';

  @override
  String get folderColorTheme => 'Couleur du thème';

  @override
  String get folderColorThemeDescription =>
      'Choisissez une couleur que vous aimez. SkillsGo construira autour de lui une palette d’interface coordonnée.';

  @override
  String get brandNameNeteaseCloudMusic => 'Musique en nuage NetEase';

  @override
  String get brandNameRaspberryPi => 'Framboise Pi';

  @override
  String get brandNameChinaEasternAirlines =>
      'Compagnies aériennes chinoises orientales';

  @override
  String get brandNameNvidia => 'Nvidia';

  @override
  String get brandNameTaobao => 'Taobao';

  @override
  String get brandNameBitcoin => 'Bitcoin';

  @override
  String get appearanceMode => 'Mode';

  @override
  String get appearanceModeDescription =>
      'Suivez l\'apparence de votre système ou utilisez toujours un thème clair ou sombre.';

  @override
  String get followSystem => 'Système';

  @override
  String get lightMode => 'Lumière';

  @override
  String get darkMode => 'Sombre';

  @override
  String get wallpaper => 'Papier peint';

  @override
  String get wallpaperDescription =>
      'Choisissez un fond céleste. Votre sélection apparaît immédiatement derrière Folder.';

  @override
  String get wallpaperSun => 'Soleil';

  @override
  String get wallpaperMercury => 'Mercure';

  @override
  String get wallpaperVenus => 'Vénus';

  @override
  String get wallpaperEarth => 'Terre';

  @override
  String get wallpaperMars => 'Mars';

  @override
  String get wallpaperJupiter => 'Jupiter';

  @override
  String get wallpaperSaturn => 'Saturne';

  @override
  String get wallpaperUranus => 'Uranus';

  @override
  String get wallpaperNeptune => 'Neptune';

  @override
  String get wallpaperPluto => 'Pluton';

  @override
  String get wallpaperMoon => 'Lune';

  @override
  String folderThemeChoice(String theme) {
    return 'Thème $theme Folder';
  }

  @override
  String get privacyAffiliation =>
      'La télémétrie d\'installation anonyme est contrôlée par les paramètres SkillsGo. SkillsGo n\'est pas affilié à OpenAI ou Codex.';

  @override
  String get commandCompleted => 'Commande terminée';

  @override
  String get commandFailed => 'La commande a échoué';

  @override
  String commandExit(int code) {
    return 'Quitter $code · développer le journal de cette session';
  }

  @override
  String get command => 'Commande';

  @override
  String get cancel => 'Annuler';

  @override
  String get updateUnknown => 'INCONNU';

  @override
  String get updateChecking => 'VÉRIFICATION';

  @override
  String get upToDate => 'À JOUR';

  @override
  String get updateAvailable => 'MISE À JOUR';

  @override
  String get updateUnavailable => 'INDISPONIBLE';

  @override
  String get updateCheckFailed => 'ÉCHEC DE LA VÉRIFICATION';

  @override
  String get installSkill => 'Installer Skill';

  @override
  String get installLocationTitle => 'Définir l\'emplacement d\'installation';

  @override
  String get userLevel => 'Niveau utilisateur';

  @override
  String get projectLevel => 'Niveau du projet';

  @override
  String get projects => 'Projets';

  @override
  String get loading => 'Chargement…';

  @override
  String get repositoryParsing => 'Référentiel d\'analyse…';

  @override
  String userInstallSummary(int agents) {
    return 'Disponible pour $agents Agents au niveau utilisateur';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return 'Projets $projects · $agents Agents';
  }

  @override
  String get installationResults => 'Résultats de l\'installation';

  @override
  String get installationInProgress => 'Installation en cours';

  @override
  String get installationSucceeded => 'Installation terminée';

  @override
  String get installationSucceededMessage =>
      'Le Skill est désormais disponible dans les emplacements sélectionnés.';

  @override
  String get projectUnavailable => 'Projet indisponible';

  @override
  String get installedCell => 'Installé';

  @override
  String get unsupportedCell => 'Indisponible';

  @override
  String get confirmInstall => 'Confirmer l\'installation';

  @override
  String installAllRepositorySkills(int count) {
    return 'Installer tous les référentiels skills ($count)';
  }

  @override
  String get installAllSkillsTo => 'Installez tous les skills sur';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Installez tous les $repository skills ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Installez $skill sur';
  }

  @override
  String get availableInAllProjects => 'Tous les projets';

  @override
  String get availableInSelectedProjects => 'Projets sélectionnés';

  @override
  String get usedBy => 'Pour Agents';

  @override
  String get backToTargets => 'Retour aux cibles';

  @override
  String get stayHere => 'Reste ici';

  @override
  String get viewInLibrary => 'Afficher dans la bibliothèque';

  @override
  String planCreateCount(int count) {
    return '$count créer';
  }

  @override
  String planSkipCount(int count) {
    return 'sauter $count';
  }

  @override
  String planReplaceCount(int count) {
    return '$count remplacer';
  }

  @override
  String planConflictCount(int count) {
    return 'Conflit $count';
  }

  @override
  String planRiskCount(int count) {
    return 'Risque $count bloqué';
  }

  @override
  String get refreshInstallationPlan => 'Appliquer les résolutions';

  @override
  String get replaceVersionConflict =>
      'Remplacer la version installée sur cette cible';

  @override
  String get replaceSkillIdCollision =>
      'Remplacer les différents Skill ID à cet objectif';

  @override
  String get replaceLocalModification =>
      'Ignorer les modifications locales et remplacer cette cible';

  @override
  String get sharedTargetConflict =>
      'Ce chemin est partagé par les cibles other Agent';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Revenez à la matrice cible et à select pour chaque Agent concerné avant de remplacer : $agents';
  }

  @override
  String get replaceConflictingTarget => 'Remplacer la cible en conflit';

  @override
  String get confirmHighRiskArtifact =>
      'Confirmation d\'artefacts à haut risque';

  @override
  String get confirmCriticalRiskArtifact =>
      'Confirmation de remplacement du risque critique';

  @override
  String get confirmRiskForSelectedTargets =>
      'J\'ai examiné les fichiers d\'artefacts et j\'accepte ce risque pour les cibles sélectionnées';

  @override
  String get criticalRiskBlocked =>
      'L\'installation à risque critique est bloquée';

  @override
  String get criticalRiskOverrideDisabled =>
      'Activez le remplacement explicite du risque critique dans les paramètres avant que ce plan puisse continuer.';

  @override
  String get workspaceManifestChanges =>
      'Modifications du manifeste de l\'espace de travail';

  @override
  String get noWorkspaceManifestChanges =>
      'Aucun fichier Workspace Manifest ne sera modifié.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'pas présent';

  @override
  String get planActionCreate => 'Créer';

  @override
  String get planActionReplace => 'Remplacer';

  @override
  String get planActionSkip => 'Sauter';

  @override
  String get planActionConflict => 'Conflit';

  @override
  String get planActionBlockedByRisk => 'Bloqué par le risque';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'Cibles $succeeded installées, échec de $failed';
  }

  @override
  String get installationProgressTitle => 'Installation en cours';

  @override
  String installationProgressSummary(int finished, int total) {
    return 'Les cibles $finished des $total sont terminées';
  }

  @override
  String get targetWaiting => 'En attendant';

  @override
  String get targetRunning => 'Installation';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Réessayer les cibles ayant échoué $count',
      one: 'Réessayer 1 cible ayant échoué',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Cibles Select à mettre à jour';

  @override
  String get updatePlanDescription =>
      'Choisissez des cibles d\'installation exactes. Les Agents non sélectionnés et les projets restent inchangés.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected des cibles actualisables $available sélectionnées';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Référence source : $reference';
  }

  @override
  String get fixedVersionTarget => 'Épinglé - aucune référence mobile';

  @override
  String get currentVersionTarget => 'À jour';

  @override
  String get updateCheckTargetFailed =>
      'La vérification de la mise à jour a échoué';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Réparer le manifeste de l’espace de travail';

  @override
  String get updateSelectedTargets => 'Mettre à jour les cibles sélectionnées';

  @override
  String get updateProgressTitle => 'Mise à jour des cibles';

  @override
  String get updateResultsTitle => 'Mettre à jour les résultats';

  @override
  String updateProgressSummary(int finished, int total) {
    return 'Les cibles $finished des $total sont terminées';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Réessayer $count mises à jour ayant échoué',
      one: 'Réessayer 1 mise à jour ayant échoué',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Aucune cible sélectionnée n\'a de mise à jour disponible.';

  @override
  String get closeUpdatePlan => 'Fermer';

  @override
  String get targetSucceeded => 'Installé';

  @override
  String get targetSkipped => 'Sauté';

  @override
  String get targetConflict => 'Conflit';

  @override
  String get targetFailed => 'Échoué';

  @override
  String get targetFailureRetryable =>
      'Cet emplacement n\'a pas pu être modifié. Vous pouvez réessayer.';

  @override
  String get targetFailureNeedsAttention =>
      'Cet emplacement nécessite votre attention avant de réessayer.';

  @override
  String get installationTargetFailureMessage =>
      'Rien n\'a été changé à cet endroit. Vérifiez que le folder est disponible et réessayez.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Rien n\'a été modifié car SkillsGo n\'a pas pu enregistrer les paramètres du projet. Vérifiez que le projet folder est accessible en écriture et réessayez.';

  @override
  String get installationStateChangedMessage =>
      'Cet emplacement a changé pendant que vous l\'examiniez. Vérifiez le dernier état avant de réessayer.';

  @override
  String get updateTargetFailureMessage =>
      'Cet emplacement n\'a pas pu être mis à jour. Les emplacements Other n’ont pas été affectés, vous pouvez donc réessayer uniquement celui-ci.';

  @override
  String get managementTargetFailureMessage =>
      'Cette action n\'a pas pu être effectuée ici. Les emplacements Other n’ont pas été affectés, vous pouvez donc réessayer uniquement celui-ci.';

  @override
  String get technicalDetails => 'Détails techniques';

  @override
  String get targetPathExists => 'Un autre élément existe déjà à cet endroit.';

  @override
  String get targetBlockedByRisk =>
      'Vos paramètres de sécurité actuels ont bloqué l\'installation à cet emplacement.';

  @override
  String get targetInstallFailed =>
      'Le skill n\'a pas pu être installé à cet emplacement.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Le skill a été installé, mais les paramètres du projet n\'ont pas pu être mis à jour.';

  @override
  String get installationPlanFailed =>
      'Le plan d\'installation n\'a pas pu continuer';

  @override
  String get installationFailed => 'L\'installation n\'a pas pu être terminée';

  @override
  String get localSource => 'Source locale';

  @override
  String get noDescriptionAvailable => 'Aucune description disponible';

  @override
  String moreCoverage(int count) {
    return '+$count plus d\'emplacements';
  }

  @override
  String get batchTakeoverAction => 'Gérer les skills existants';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Gérer ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Vérification du skills existant…';

  @override
  String get batchTakeoverRetry => 'Vérifiez à nouveau le skills gérable';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count peut être géré';
  }

  @override
  String get batchTakeoverPending => 'Ajout de skills à la gestion…';

  @override
  String get batchTakeoverTitle => 'Gérer un skills existant avec SkillsGo ?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo ajoutera des enregistrements de gestion locaux sans déplacer, écraser ou télécharger les fichiers skill. Les éléments non pris en charge ou modifiés seront ignorés.';

  @override
  String get batchTakeoverStoryTitle =>
      'Transformez les skills dispersés en une bibliothèque claire';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills existant',
      one: '1 skill existant',
    );
    return 'SkillsGo a trouvé $_temp0 qu\'il peut gérer à cet emplacement.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Avant la gestion, il n\'est pas clair où les skills existants sont installés, s\'ils sont à jour, comment les récupérer ou si les projets utilisent la même version.';

  @override
  String get batchTakeoverPainLocation => 'Emplacement d\'installation inconnu';

  @override
  String get batchTakeoverPainFreshness => 'Statut de mise à jour inconnu';

  @override
  String get batchTakeoverPainRecovery => 'Aucune récupération en cas de panne';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Différentes versions selon les projets';

  @override
  String get batchTakeoverFolderTitle => 'Skills existant';

  @override
  String get batchTakeoverFolderSubtitle => 'Statut peu clair';

  @override
  String get batchTakeoverAfterLabel => 'APRÈS';

  @override
  String get batchTakeoverAfterTitle => 'Une bibliothèque claire';

  @override
  String get batchTakeoverLibraryTitle => 'Bibliothèque SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Effacer les emplacements';

  @override
  String get batchTakeoverBenefitFreshness => 'Mises à jour visibles';

  @override
  String get batchTakeoverBenefitRecovery => 'Récupération facile';

  @override
  String get batchTakeoverBenefitVersions => 'Versions claires';

  @override
  String get batchTakeoverManagedSection => 'Géré par SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'En attente';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name est géré par SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name n\'a pas pu être ajouté à la gestion';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name est en attente d\'être géré';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills are',
      one: '1 skill is',
    );
    return 'Après gestion, $_temp0 organisés dans une seule bibliothèque avec un statut de gestion clair.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count plus';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Ajoutez ces skills existants à la gestion SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANISER';

  @override
  String get batchTakeoverStatusTitle => 'Statut de gestion';

  @override
  String get batchTakeoverStatusManaged => 'Géré';

  @override
  String get batchTakeoverStatusProgress => 'Organisation';

  @override
  String get batchTakeoverStatusSkipped => 'Sauté';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Les fichiers Skill restent à leur emplacement d\'origine';

  @override
  String get batchTakeoverBoardSemantics =>
      'Les Skills sont organisés en lignes complètes et enregistrés par SkillsGo sans déplacer leurs fichiers.';

  @override
  String get batchTakeoverBoardComplete => 'TOUT CLAIRE';

  @override
  String get batchTakeoverBoardPartial => 'COMPLET';

  @override
  String get batchTakeoverStatusTotal => 'Total';

  @override
  String get batchTakeoverQueueComplete => 'Aucun skills n\'attend';

  @override
  String get batchTakeoverQueueWaiting =>
      'Les Skills apparaîtront ici après vérification';

  @override
  String get batchTakeoverNextLabel => 'SUIVANT';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs organisateur SkillsGo',
      one: '1 bloc organisateur SkillsGo',
    );
    return '$_temp0 complètent les dernières lignes';
  }

  @override
  String get batchTakeoverPreservation =>
      'Vos fichiers, chemins et flux de travail actuels restent exactement là où ils se trouvent. SkillsGo complète uniquement ses dossiers de gestion locaux.';

  @override
  String get batchTakeoverLaterHint =>
      'Si vous ignorez, vous pouvez utiliser Gérer les skills existants à partir de la bibliothèque à tout moment.';

  @override
  String get batchTakeoverSkip => 'Pas maintenant';

  @override
  String get batchTakeoverConfirm => 'Ajouter à la gestion';

  @override
  String get batchTakeoverExecutionRetry => 'Réessayer';

  @override
  String get batchTakeoverResultTitle => 'Skills ajouté à la gestion';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver skills ajouté à la gestion, $skipped ignoré.';
  }

  @override
  String get batchTakeoverClose => 'Fermer';

  @override
  String get installMoreTargets => 'Installer dans plus d\'endroits';

  @override
  String get exportLocalSkill => 'Exporter';

  @override
  String get exportLocalSkillDescription =>
      'Exportez ce Skill local en tant qu\'archive ZIP portable.';

  @override
  String get detailRepository => 'Dépôt';

  @override
  String get detailStars => 'Étoiles';

  @override
  String get detailUpdated => 'Mis à jour';

  @override
  String get detailArchiveSize => 'Taille du code postal';

  @override
  String get pathLabel => 'Cheminement du projet';

  @override
  String get copyProjectPath => 'Copier le chemin du projet';

  @override
  String get projectPathCopied => 'Chemin du projet copié';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue à SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Découvrez, installez et gérez Skills sur votre Agents et vos projets.';

  @override
  String get onboardingDetectedAgents => 'Détecté Agents';

  @override
  String get onboardingNoAgents =>
      'Aucun Agents installé n\'a été détecté. Vous pouvez toujours continuer.';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingProjectsTitle => 'Ajoutez vos projets';

  @override
  String get onboardingProjectsDescription =>
      'Choisissez les projets que vous souhaitez que SkillsGo gère.';

  @override
  String get onboardingAddProject => 'Ajouter maintenant';

  @override
  String get onboardingAddProjectLater => 'ou plus tard';

  @override
  String get onboardingStartUsing => 'Commencez à utiliser SkillsGo';

  @override
  String get onboardingBack => 'Dos';

  @override
  String get restartOnboardingTitle => 'Intégration';

  @override
  String get restartOnboardingDescription =>
      'Consultez à nouveau le guide de premier lancement sans supprimer les projets, les paramètres ou les données Skills.';

  @override
  String get restartOnboardingAction => 'Redémarrer l\'intégration';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo n\'a pas pu redémarrer l\'intégration.';

  @override
  String get libraryRefreshSettingsTitle => 'Actualiser la bibliothèque locale';

  @override
  String get libraryRefreshSettingsDescription =>
      'Rescan a installé Skills, les projets ajoutés, Agents et Skills externe qui peuvent être gérés. Cela n’installe, ne met à jour ou ne supprime rien.';

  @override
  String get libraryRefreshSettingsAction => 'Actualiser la bibliothèque';

  @override
  String get libraryRefreshSettingsPending => 'Bibliothèque rafraîchissante…';

  @override
  String get libraryRefreshSettingsSuccess => 'Bibliothèque locale rafraîchie.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo n\'a pas pu actualiser la bibliothèque locale.';

  @override
  String get onboardingProjectError =>
      'SkillsGo n\'a pas pu ajouter de projets à partir de ce répertoire.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo n\'a pas pu charger vos projets ajoutés.';

  @override
  String get onboardingStartupError =>
      'SkillsGo n\'a pas pu charger la configuration.';

  @override
  String get onboardingStateError =>
      'SkillsGo n\'a pas pu enregistrer la progression de votre configuration. Essayer à nouveau.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI a besoin d’attention';

  @override
  String get onboardingCliErrorDescription =>
      'Réparez le CLI fourni, puis réessayez de continuer.';
}
