// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get discover => 'Descubrir';

  @override
  String get discoverSkills => 'Es bueno saber un poco más.';

  @override
  String get library => 'Biblioteca';

  @override
  String get settings => 'Ajustes';

  @override
  String get openSettings => 'Abrir configuración';

  @override
  String get cliNeedsAttention =>
      'Un componente SkillsGo requerido necesita atención.';

  @override
  String get cliMissingBundled =>
      'Falta un componente SkillsGo requerido o no se puede iniciar. Reinstale SkillsGo para restaurarlo.';

  @override
  String get cliDamagedBundled =>
      'Un componente SkillsGo requerido está dañado. Reinstale SkillsGo para restaurarlo.';

  @override
  String get cliIncompatibleBundled =>
      'Un componente SkillsGo requerido no coincide con la versión de esta aplicación. Actualice o reinstale SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Encuentre un skill para su próximo movimiento.';

  @override
  String get skillsLeaderboard => 'Es bueno saber un poco más.';

  @override
  String searchResultsFor(String query) {
    return 'Resultados para “$query”';
  }

  @override
  String get searchSkills => 'Busque skills o pegue un enlace de Git...';

  @override
  String get search => 'Buscar';

  @override
  String get ranking => 'Categoría';

  @override
  String get trending => 'Tendencia';

  @override
  String get hot => 'Caliente';

  @override
  String get discoverNavigation => 'Descubre la navegación';

  @override
  String get allTimeRanking => 'Clasificación de todos los tiempos';

  @override
  String get trendingNow => 'Tendencia en las últimas 24 horas';

  @override
  String get hotNow => 'Caliente ahora mismo';

  @override
  String get allTimeDescription =>
      'Skills públicos ordenados por el total de instalaciones aceptadas.';

  @override
  String get trendingDescription =>
      'Skills públicos ordenados por las instalaciones aceptadas durante las últimas 24 horas.';

  @override
  String get hotDescription =>
      'Skills públicos ordenados por el ritmo reciente de instalaciones y su variación.';

  @override
  String get offlineTitle => 'No se puede conectar a SkillsGo';

  @override
  String get offlineMessage =>
      'Verifique su conexión a Internet e inténtelo nuevamente. Si utiliza un proxy o una dirección de servicio personalizada, revíselo en Configuración.';

  @override
  String get searchFailedTitle => 'Error de búsqueda';

  @override
  String get validationTitle => 'Comprueba lo que ingresaste';

  @override
  String get validationMessage =>
      'SkillsGo no pudo utilizar esta solicitud. Revise lo que ingresó y vuelva a intentarlo.';

  @override
  String get serverTitle => 'Servicio no disponible temporalmente';

  @override
  String get serverMessage =>
      'SkillsGo no puede completar esta solicitud en este momento. Inténtalo de nuevo en un momento.';

  @override
  String get timeoutTitle => 'Esto está tardando demasiado';

  @override
  String get timeoutMessage =>
      'El servicio no respondió a tiempo. Comprueba tu conexión o inténtalo de nuevo.';

  @override
  String get invalidResponseTitle => 'SkillsGo necesita una actualización';

  @override
  String get invalidResponseMessage =>
      'Esta respuesta no puede ser leída por su versión de SkillsGo. Actualice la aplicación y vuelva a intentarlo.';

  @override
  String get invalidLocalDataTitle => 'No se puede leer un skill instalado';

  @override
  String get invalidLocalDataMessage =>
      'Parte de la información de instalación local está dañada o es incompatible. Actualice o reinstale SkillsGo y vuelva a intentarlo.';

  @override
  String get tryAgain => 'Intentar otra vez';

  @override
  String get searchEmptyTitle => 'Busca, no te desplaces.';

  @override
  String get searchEmptyMessage =>
      'Ingrese una capacidad, fuente o tarea para buscar skills público.';

  @override
  String get noSkillsTitle => 'No se encontró skills';

  @override
  String get noSkillsMessage =>
      'Pruebe con una frase más amplia o revise la ortografía.';

  @override
  String get focusSearch => 'Búsqueda de enfoque';

  @override
  String get skillsFromLink => 'Skills desde este enlace';

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
  String get sourceSearchEmptyTitle =>
      'Este enlace está listo para inspeccionar.';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source no está en los resultados de búsqueda actuales. SkillsGo puede inspeccionar el enlace directamente en el siguiente paso.';
  }

  @override
  String get inspectSource => 'Ver skills en este enlace';

  @override
  String get collectionEmptyTitle => 'No hay Skills en esta colección.';

  @override
  String get collectionEmptyMessage =>
      'No hay nada aquí todavía. Inténtelo de nuevo después de realizar más actividades de instalación.';

  @override
  String get loadMore => 'Cargar más';

  @override
  String get install => 'Instalar';

  @override
  String get installAll => 'Instalar todos los skills';

  @override
  String get latestCommit => 'Último compromiso';

  @override
  String get installToMoreTargets => 'Instalar en más ubicaciones';

  @override
  String localTargets(int count) {
    return 'Objetivos locales $count';
  }

  @override
  String allTimeMetric(String count) {
    return 'Instalaciones de todos los tiempos de $count';
  }

  @override
  String trendingMetric(String count) {
    return 'Instalaciones $count / 24h';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value esta hora · $change';
  }

  @override
  String get trustUnverified => 'Inconfirmado';

  @override
  String get trustCommunityVerified => 'Comunidad verificada';

  @override
  String get trustPublisherVerified => 'Editor verificado';

  @override
  String get trustOfficial => 'Oficial';

  @override
  String get trustWarned => 'Prevenido';

  @override
  String get trustDelisted => 'Eliminado de la lista';

  @override
  String get riskUnknown => 'Riesgo desconocido';

  @override
  String get riskLow => 'Bajo riesgo';

  @override
  String get riskMedium => 'Riesgo medio';

  @override
  String get riskHigh => 'Alto riesgo';

  @override
  String get riskCritical => 'Riesgo crítico';

  @override
  String openSkill(String name) {
    return 'Abrir $name';
  }

  @override
  String installs(String count) {
    return 'Instalaciones $count';
  }

  @override
  String get detailFailedTitle => 'No se pudo cargar este Skill';

  @override
  String get detailLoading => 'Cargando detalle auditable de Skill';

  @override
  String get artifactUnavailableTitle => 'Artefacto no disponible';

  @override
  String get artifactUnavailableMessage =>
      'Esta versión no está disponible en este momento. Inténtalo de nuevo o elige otra versión.';

  @override
  String get detailInvalidTitle => 'Metadatos de artefactos no compatibles';

  @override
  String get detailInvalidMessage =>
      'Algunos detalles de este skill están incompletos o no se pueden leer. Actualice SkillsGo y vuelva a intentarlo.';

  @override
  String get instructionsTab => 'Instrucciones';

  @override
  String get manifestTab => 'Manifiesto';

  @override
  String immutableVersionLabel(String version) {
    return 'Inmutable $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Confirmar $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Árbol $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Contenido $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'La confianza del editor verifica la propiedad o el mantenimiento; no certifica la seguridad de los artefactos. El riesgo se evalúa por separado para esta versión inmutable.';

  @override
  String get knownInstallationTargets => 'Objetivos de instalación conocidos';

  @override
  String get installationRange => 'Alcance instalado';

  @override
  String get targetDetails => 'Mostrar detalles del objetivo';

  @override
  String get hideTargetDetails => 'Ocultar detalles del objetivo';

  @override
  String installedVersionLabel(String version) {
    return 'Versión $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Proyecto';

  @override
  String get fileContentUnavailable => 'Vista previa binaria o no disponible';

  @override
  String get fileContentTruncated =>
      'Vista previa truncada por el límite de seguridad Hub.';

  @override
  String get retry => 'Rever';

  @override
  String get backToSearch => 'Volver a buscar';

  @override
  String get installForCodex => 'Instalar para Codex';

  @override
  String get cliNotDetected => 'skills (no detectado)';

  @override
  String get snapshotFiles => 'Archivos de instantáneas';

  @override
  String get globalCodex => 'Mundial · Codex';

  @override
  String get yourLibrary => 'Lo que sabes está todo aquí.';

  @override
  String get libraryNavigation => 'Navegación de la biblioteca';

  @override
  String get all => 'Todo';

  @override
  String get allSkills => 'Todo Skills';

  @override
  String get updatesOnly => 'Actualizaciones';

  @override
  String get allAgents => 'Todo Agents';

  @override
  String get allProjects => 'Todos los proyectos';

  @override
  String get specificProject => 'Proyecto';

  @override
  String get userScope => 'Global';

  @override
  String get addProject => 'Agregar proyecto';

  @override
  String get relocateProject => 'Trasladarse';

  @override
  String get removeFromList => 'Eliminar de la lista';

  @override
  String removeProjectTitle(String name) {
    return '¿Quitar $name de SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Sólo se eliminará la referencia de la aplicación. SkillsGo no cambiará ni eliminará ningún archivo en este directorio.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — no disponible';
  }

  @override
  String get emptyProjectTitle => 'Aún no hay Skills';

  @override
  String get browseSkills => 'Explorar Skills';

  @override
  String get projectMissingTitle => 'Falta el directorio del proyecto';

  @override
  String get projectMissingMessage =>
      'Es posible que el directorio se haya movido o que su volumen esté desconectado. Reubíquelo o elimine solo la referencia de su aplicación.';

  @override
  String get projectPermissionTitle => 'Se requiere permiso del proyecto.';

  @override
  String get projectPermissionMessage =>
      'SkillsGo no puede inspeccionar esta raíz seleccionada. Conceda acceso reubicándolo a través del selector de directorio.';

  @override
  String get projectInaccessibleTitle =>
      'El directorio del proyecto es inaccesible';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo mantuvo la referencia de este proyecto. Verifique la ruta o el volumen y luego reubíquelo.';

  @override
  String get checking => 'De cheques…';

  @override
  String get checkUpdates => 'comprobar actualizaciones';

  @override
  String get refresh => 'Refrescar';

  @override
  String get libraryUnavailable => 'Biblioteca no disponible';

  @override
  String get libraryEmpty => 'Aún no hay ningún skills instalado.';

  @override
  String get libraryEmptyMessage =>
      'Instale un Skill desde Discover y aparecerá aquí.';

  @override
  String get searchLibrary => 'Buscar instalado skills';

  @override
  String get libraryNoMatches => 'No hay coincidencias Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Pruebe con un nombre, fuente, Agent, proyecto o versión diferente.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return 'Proyectos $count';
  }

  @override
  String versionsSummary(int count) {
    return 'Versiones $count';
  }

  @override
  String get hubManaged => 'Hub gestionado';

  @override
  String get localManaged => 'Gestionado localmente';

  @override
  String get externalInstallation => 'Instalación externa';

  @override
  String get readOnly => 'Solo lectura';

  @override
  String get unversioned => 'no versionado';

  @override
  String get supportingFiles => 'Archivos de soporte';

  @override
  String get versionDivergence => 'Divergencia de versiones';

  @override
  String get healthHealthy => 'Saludable';

  @override
  String get healthMissing => 'Falta el objetivo';

  @override
  String get healthReplaced => 'Objetivo reemplazado';

  @override
  String get healthLocalModification => 'Modificación Local';

  @override
  String get healthUnreadable => 'Objetivo ilegible';

  @override
  String get healthUndeclared => 'No declarado';

  @override
  String get healthWorkspaceUnreadable =>
      'Estado del espacio de trabajo ilegible';

  @override
  String get healthLockMismatch => 'El bloqueo no coincide';

  @override
  String get healthUnexpectedPath => 'Ruta de destino inesperada';

  @override
  String get modeExternal => 'Externo';

  @override
  String get notLinked => 'NO VINCULADO';

  @override
  String get update => 'Actualizar';

  @override
  String get backToLibrary => 'Volver a la biblioteca';

  @override
  String get remove => 'Eliminar';

  @override
  String get manageTargets => 'Administrar alcance';

  @override
  String skillsSelected(int count) {
    return '$count seleccionado';
  }

  @override
  String get clearSelection => 'Borrar selección';

  @override
  String get selectCurrentResults => 'Resultados actuales de Select';

  @override
  String get clearCurrentResultSelection =>
      'Borrar la selección de resultados actual';

  @override
  String get manageTargetsTitle => 'Administrar destinos de instalación';

  @override
  String get manageTargetsDescription =>
      'Elige una acción exacta para cada objetivo. Los objetivos no seleccionados no cambiarán.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$selected de objetivos $total seleccionados';
  }

  @override
  String get confirmRemoveTarget => 'Confirmar eliminación';

  @override
  String get applyTargetActions => 'Aplicar acciones seleccionadas';

  @override
  String get managementProgressTitle => 'Aplicar acciones objetivo';

  @override
  String get managementResultsTitle => 'Resultados de la acción objetivo';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded tuvo éxito, $failed falló';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Las acciones del proyecto seleccionadas actualizarán skillsgo.yaml y skillsgo.lock.';

  @override
  String get targetContentPreserved =>
      'Se conservará el contenido de destino actual.';

  @override
  String get localReadFailed => 'No puedo leer esto Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo no pudo leer este skill instalado. Verifique que su folder esté disponible y accesible, luego inténtelo nuevamente.';

  @override
  String get localConfiguration => 'CONFIGURACIÓN DE SKILLSGO';

  @override
  String get settingsNavigation => 'Navegación de configuración';

  @override
  String get general => 'Personalizar';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Política de instalación';

  @override
  String get storage => 'Almacenamiento';

  @override
  String get colorScheme => 'Esquema de colores';

  @override
  String get about => 'Acerca de';

  @override
  String get colorSchemeInspectorTitle => 'Roles de color Material generados';

  @override
  String get skillsColorTokensTitle => 'Colores semánticos SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Colores de producto creados a partir de Radix Sand y organizados con la semántica Primer, con Folder como una jerarquía espacial dedicada.';

  @override
  String get colorSchemeInspectorDescription =>
      'Obtenga una vista previa de cada token ColorScheme no obsoleto generado a partir de la semilla actual. Haga clic en un color para copiar su valor HEX.';

  @override
  String get colorSchemePairPreview => 'Pares semánticos';

  @override
  String get colorSchemePairPreviewDescription =>
      'Roles de primer plano y de fondo representados juntos para exponer el contraste y la jerarquía.';

  @override
  String get colorSchemeComponentPreview => 'Vista previa del componente';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Controles representativos de Material renderizados con este esquema de vista previa exacto.';

  @override
  String get colorSchemeSampleTitle => 'Título de la tarjeta Skill';

  @override
  String get colorSchemeSampleBody =>
      'La copia secundaria utiliza onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'copiado';

  @override
  String get colorSchemeSampleGlyphs => 'aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Primario';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Énfasis primario, contenedores y roles de acento fijo.';

  @override
  String get colorSchemeGroupSecondary => 'Secundario';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Énfasis de apoyo y roles secundarios fijos.';

  @override
  String get colorSchemeGroupTertiary => 'Terciario';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Acentos contrastantes y roles terciarios fijos.';

  @override
  String get colorSchemeGroupSurface => 'Superficie';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Jerarquía de página, contenedor, elevación y primer plano.';

  @override
  String get colorSchemeGroupUtility => 'Esquema y utilidad';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Límites, sombras, mallas y superficies inversas.';

  @override
  String get colorSchemeGroupError => 'Error';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Acciones de error, mensajes y contenedores.';

  @override
  String get colorSchemeUsagePrimary =>
      'Acciones primarias, enfoque y acentos de alto énfasis.';

  @override
  String get colorSchemeUsageSecondary =>
      'Acciones de apoyo y acentos de énfasis medio.';

  @override
  String get colorSchemeUsageTertiary =>
      'Acentos contrastantes que complementan primaria y secundaria.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Texto e iconos mostrados en $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Contenedor $family de menor énfasis para selecciones y acentos.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Contenedor fijo $family independiente del brillo.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Contenedor fijo $family regulable, independiente de la luminosidad.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Contenido de alto énfasis en el contenedor fijo $family.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Contenido con menor énfasis en el contenedor fijo $family.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Página base y superficie de gran región.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Superficie base atenuada utilizada en el tono de superficie más oscuro.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Superficie base brillante utilizada en el tono de superficie más claro.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'Elevación de contenedor de superficie $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'más bajo';

  @override
  String get colorSchemeElevationLow => 'bajo';

  @override
  String get colorSchemeElevationDefault => 'por defecto';

  @override
  String get colorSchemeElevationHigh => 'alto';

  @override
  String get colorSchemeElevationHighest => 'más alto';

  @override
  String get colorSchemeUsageOnSurface =>
      'Texto principal e íconos mostrados en las superficies.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Texto secundario, etiquetas e íconos atenuados en superficies.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Tono de elevación Material derivado del primario.';

  @override
  String get colorSchemeUsageOutline =>
      'Límites prominentes y esquemas de componentes enfocados.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Límites sutiles, separadores y contornos con poco énfasis.';

  @override
  String get colorSchemeUsageShadow =>
      'Color de sombra paralela para superficies elevadas.';

  @override
  String get colorSchemeUsageScrim =>
      'Superposición modal utilizada para restar importancia al contenido de fondo.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Superficie con énfasis claro y oscuro invertido.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Acento principal mostrado en una superficie inversa.';

  @override
  String get colorSchemeUsageError =>
      'Acciones de error, estado y comentarios de alto énfasis.';

  @override
  String get save => 'Ahorrar';

  @override
  String get advancedSettings => 'Avanzado';

  @override
  String get remindersSettings => 'Recordatorios';

  @override
  String get remindersSettingsTitle => 'Configuración de recordatorio';

  @override
  String get remindersSettingsDescription => 'Elija qué recordatorios recibir.';

  @override
  String get updateReminderTitle => 'Recordatorios de actualización';

  @override
  String get updateReminderDescription =>
      'Busque actualizaciones cuando se abra la biblioteca.';

  @override
  String get securityReminderTitle => 'Alertas de alto riesgo';

  @override
  String get securityReminderDescription =>
      'Notificarle sobre nuevos riesgos Altos o Críticos en skills instalado.';

  @override
  String availableUpdatesReminder(int count) {
    return '$count instalado skills tiene actualizaciones';
  }

  @override
  String get openAvailableUpdates =>
      'Abra la vista de actualizaciones disponibles para revisarlas y actualizarlas.';

  @override
  String securityAdvisoriesReminder(int count) {
    return '$count instalado skills necesita una revisión de seguridad';
  }

  @override
  String get reviewInstalledSkills =>
      'Revise su información de riesgos antes de usarlos o actualizarlos.';

  @override
  String get generalSettingsTitle => 'Haz tuyo SkillsGo';

  @override
  String get generalSettingsDescription =>
      'La interfaz sigue las preferencias de idioma, accesibilidad y movimiento de su sistema.';

  @override
  String get agentsSettingsTitle => 'Tiempo de ejecución Agent';

  @override
  String get hubSettingsTitle => 'Origen Hub';

  @override
  String get hubSettingsDescription =>
      'Utilice el Hub oficial o un origen autohospedado HTTP(S) que implemente el mismo protocolo SkillsGo.';

  @override
  String get testConnection => 'Conexión de prueba';

  @override
  String get saveOrigin => 'Guardar origen';

  @override
  String get resetDefault => 'Restablecer los valores predeterminados';

  @override
  String get connectionReady => 'Conexión lista';

  @override
  String get connectionFailed => 'La conexión falló';

  @override
  String get hubInvalidOrigin =>
      'Ingrese un origen HTTP(S) válido sin credenciales, una consulta o un fragmento.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub devolvió HTTP $status. Verifique el origen y la configuración del servidor.';
  }

  @override
  String get hubInvalidProtocol =>
      'El servidor no devolvió el protocolo de búsqueda SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'El Hub devolvió JSON no válido.';

  @override
  String get hubConnectionFailure =>
      'No se pudo alcanzar el Hub. Verifique la configuración de Origen, red, proxy y TLS.';

  @override
  String get hubConnectionTimeout =>
      'Se agotó el tiempo de espera de la conexión Hub. Verifique la red o inténtelo nuevamente.';

  @override
  String get riskPolicyTitle => 'Póliza de riesgos personales';

  @override
  String get riskPolicyDescription =>
      'Se aplican reglas de seguridad al instalar o actualizar un skill.';

  @override
  String get confirmHighRisk => 'Requerir confirmación para Alto riesgo';

  @override
  String get confirmHighRiskDescription =>
      'Los artefactos de alto riesgo siempre requieren una confirmación adicional antes de la instalación.';

  @override
  String get allowCriticalOverride =>
      'Permitir una anulación explícita del riesgo crítico';

  @override
  String get allowCriticalOverrideDescription =>
      'Los artefactos de riesgo crítico permanecen bloqueados de forma predeterminada. Habilite esto solo para exponer una anulación manual separada.';

  @override
  String get storageHealthy => 'Legible';

  @override
  String get storageNotInitialized => 'No inicializado';

  @override
  String get storageUnavailable => 'Indisponible';

  @override
  String get storageInvalidResponse =>
      'El CLI incluido devolvió una respuesta de diagnóstico no compatible.';

  @override
  String get aboutSettingsTitle => 'Compatibilidad del producto';

  @override
  String get appVersion => 'Versión de la aplicación';

  @override
  String get cliVersion => 'Versión CLI incluida';

  @override
  String get compatible => 'Compatible';

  @override
  String get hubOriginSaved => 'Hub Origen guardado y aplicado.';

  @override
  String get policySaved => 'Política de instalación guardada.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'LISTO';

  @override
  String get unknown => 'DESCONOCIDO';

  @override
  String get missing => 'DESAPARECIDO';

  @override
  String get incompatible => 'INCOMPATIBLE';

  @override
  String get detecting => 'Detector…';

  @override
  String get customCliPath => 'Ruta ejecutable personalizada';

  @override
  String get saveAndDetect => 'Guardar y detectar';

  @override
  String get detectAgain => 'Detectar de nuevo';

  @override
  String get agentInstalled => 'Instalado';

  @override
  String get agentSupported => 'Apoyado';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed instalado · $supported compatible';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Instalado · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'No instalado · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Compatible con SkillsGo, pero no detectado en esta Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Rutas de carga Skill: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Los datos de detección de Agent no están disponibles. Ejecute la detección nuevamente.';

  @override
  String get noInstalledAgentsTitle => 'No se detectó ningún Agents instalado';

  @override
  String get noInstalledAgentsMessage =>
      'Puedes seguir navegando por este Skill, pero aún no hay un destino de instalación. Instale un Agent compatible y luego ejecute la detección nuevamente.';

  @override
  String get clearCustomPath => 'Borrar ruta personalizada';

  @override
  String get privacyProvenance => 'Privacidad y procedencia';

  @override
  String get privacySummary =>
      'Sus búsquedas no se guardan y SkillsGo no mantiene registros de comandos.';

  @override
  String get language => 'Idioma';

  @override
  String get personalizationTheme => 'Tema';

  @override
  String get folderColorTheme => 'Color del tema';

  @override
  String get folderColorThemeDescription =>
      'Elige un color que te guste. SkillsGo construirá una paleta de interfaz coordinada a su alrededor.';

  @override
  String get brandNameNeteaseCloudMusic => 'Música en la nube NetEase';

  @override
  String get brandNameRaspberryPi => 'Frambuesa Pi';

  @override
  String get brandNameChinaEasternAirlines => 'Aerolíneas del Este de China';

  @override
  String get brandNameNvidia => 'Nvidia';

  @override
  String get brandNameTaobao => 'taobao';

  @override
  String get brandNameBitcoin => 'bitcóin';

  @override
  String get appearanceMode => 'Modo';

  @override
  String get appearanceModeDescription =>
      'Siga la apariencia de su sistema o utilice siempre un tema claro u oscuro.';

  @override
  String get followSystem => 'Sistema';

  @override
  String get lightMode => 'Luz';

  @override
  String get darkMode => 'Oscuro';

  @override
  String get wallpaper => 'Papel pintado';

  @override
  String get wallpaperDescription =>
      'Elige un fondo celeste. Su selección aparece inmediatamente detrás de Folder.';

  @override
  String get wallpaperSun => 'Sol';

  @override
  String get wallpaperMercury => 'Mercurio';

  @override
  String get wallpaperVenus => 'Venus';

  @override
  String get wallpaperEarth => 'Tierra';

  @override
  String get wallpaperMars => 'Marte';

  @override
  String get wallpaperJupiter => 'Júpiter';

  @override
  String get wallpaperSaturn => 'Saturno';

  @override
  String get wallpaperUranus => 'Urano';

  @override
  String get wallpaperNeptune => 'Neptuno';

  @override
  String get wallpaperPluto => 'Plutón';

  @override
  String get wallpaperMoon => 'Luna';

  @override
  String folderThemeChoice(String theme) {
    return 'Tema $theme Folder';
  }

  @override
  String get privacyAffiliation =>
      'La telemetría de instalación anónima está controlada por la configuración de SkillsGo. SkillsGo no está afiliado a OpenAI ni a Codex.';

  @override
  String get commandCompleted => 'Comando completado';

  @override
  String get commandFailed => 'El comando falló';

  @override
  String commandExit(int code) {
    return 'Salga de $code · expandir para ver el registro de esta sesión';
  }

  @override
  String get command => 'Dominio';

  @override
  String get cancel => 'Cancelar';

  @override
  String get updateUnknown => 'DESCONOCIDO';

  @override
  String get updateChecking => 'DE CHEQUES';

  @override
  String get upToDate => 'A HOY';

  @override
  String get updateAvailable => 'ACTUALIZAR';

  @override
  String get updateUnavailable => 'INDISPONIBLE';

  @override
  String get updateCheckFailed => 'COMPROBACIÓN FALLIDA';

  @override
  String get installSkill => 'Instalar Skill';

  @override
  String get installLocationTitle => 'Establecer ubicación de instalación';

  @override
  String get userLevel => 'Nivel de usuario';

  @override
  String get projectLevel => 'Nivel de proyecto';

  @override
  String get projects => 'Proyectos';

  @override
  String get loading => 'Cargando…';

  @override
  String get repositoryParsing => 'Analizando el repositorio…';

  @override
  String userInstallSummary(int agents) {
    return 'Disponible para $agents Agents a nivel de usuario';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return 'Proyectos $projects · $agents Agents';
  }

  @override
  String get installationResults => 'Resultados de la instalación';

  @override
  String get installationInProgress => 'Instalación en progreso';

  @override
  String get installationSucceeded => 'Instalación completa';

  @override
  String get installationSucceededMessage =>
      'El Skill ya está disponible en las ubicaciones seleccionadas.';

  @override
  String get projectUnavailable => 'Proyecto no disponible';

  @override
  String get installedCell => 'Instalado';

  @override
  String get unsupportedCell => 'Indisponible';

  @override
  String get confirmInstall => 'Confirmar instalación';

  @override
  String installAllRepositorySkills(int count) {
    return 'Instalar todo el repositorio skills ($count)';
  }

  @override
  String get installAllSkillsTo => 'Instale todos los skills en';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Instalar todos los $repository skills ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Instale $skill en';
  }

  @override
  String get availableInAllProjects => 'Todos los proyectos';

  @override
  String get availableInSelectedProjects => 'Proyectos seleccionados';

  @override
  String get usedBy => 'Para Agents';

  @override
  String get backToTargets => 'Volver a objetivos';

  @override
  String get stayHere => 'Quédate aquí';

  @override
  String get viewInLibrary => 'Ver en la biblioteca';

  @override
  String planCreateCount(int count) {
    return '$count crear';
  }

  @override
  String planSkipCount(int count) {
    return 'Saltar $count';
  }

  @override
  String planReplaceCount(int count) {
    return '$count reemplazar';
  }

  @override
  String planConflictCount(int count) {
    return 'Conflicto $count';
  }

  @override
  String planRiskCount(int count) {
    return 'Riesgo $count bloqueado';
  }

  @override
  String get refreshInstallationPlan => 'Aplicar resoluciones';

  @override
  String get replaceVersionConflict =>
      'Reemplace la versión instalada en este destino';

  @override
  String get replaceSkillIdCollision =>
      'Reemplace los diferentes Skill ID en este objetivo';

  @override
  String get replaceLocalModification =>
      'Descarta las modificaciones locales y reemplaza este objetivo.';

  @override
  String get sharedTargetConflict =>
      'Esta ruta es compartida por objetivos other Agent';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Regrese a la matriz objetivo y select cada Agent afectado antes de reemplazar: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Reemplace el objetivo en conflicto';

  @override
  String get confirmHighRiskArtifact =>
      'Confirmación de artefactos de alto riesgo';

  @override
  String get confirmCriticalRiskArtifact =>
      'Confirmación de anulación de riesgo crítico';

  @override
  String get confirmRiskForSelectedTargets =>
      'Revisé los archivos de artefactos y acepto este riesgo para los objetivos seleccionados.';

  @override
  String get criticalRiskBlocked =>
      'La instalación de riesgo crítico está bloqueada';

  @override
  String get criticalRiskOverrideDisabled =>
      'Habilite la anulación explícita de riesgos críticos en Configuración antes de que este plan pueda continuar.';

  @override
  String get workspaceManifestChanges =>
      'Cambios en el manifiesto del espacio de trabajo';

  @override
  String get noWorkspaceManifestChanges =>
      'Ningún archivo de manifiesto del espacio de trabajo cambiará.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'no presente';

  @override
  String get planActionCreate => 'Crear';

  @override
  String get planActionReplace => 'Reemplazar';

  @override
  String get planActionSkip => 'Saltar';

  @override
  String get planActionConflict => 'Conflicto';

  @override
  String get planActionBlockedByRisk => 'Bloqueado por el riesgo';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'Objetivos $succeeded instalados, $failed falló';
  }

  @override
  String get installationProgressTitle => 'Instalación en progreso';

  @override
  String installationProgressSummary(int finished, int total) {
    return 'Objetivos $finished de $total terminados';
  }

  @override
  String get targetWaiting => 'Espera';

  @override
  String get targetRunning => 'Instalación';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reintentar $count objetivos fallidos',
      one: 'Reintentar 1 objetivo fallido',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Objetivos Select para actualizar';

  @override
  String get updatePlanDescription =>
      'Elija objetivos de instalación exactos. Agents no seleccionado y los proyectos permanecen sin cambios.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected de objetivos actualizables $available seleccionados';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Referencia de la fuente: $reference';
  }

  @override
  String get fixedVersionTarget => 'Fijado: sin referencia móvil';

  @override
  String get currentVersionTarget => 'A hoy';

  @override
  String get updateCheckTargetFailed =>
      'Error en la comprobación de actualización';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Manifiesto del espacio de trabajo de reparación';

  @override
  String get updateSelectedTargets => 'Actualizar objetivos seleccionados';

  @override
  String get updateProgressTitle => 'Actualizando objetivos';

  @override
  String get updateResultsTitle => 'Actualizar resultados';

  @override
  String updateProgressSummary(int finished, int total) {
    return 'Objetivos $finished de $total terminados';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reintentar $count actualizaciones fallidas',
      one: 'Reintentar 1 actualización fallida',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Ningún objetivo seleccionado tiene una actualización disponible.';

  @override
  String get closeUpdatePlan => 'Cerca';

  @override
  String get targetSucceeded => 'Instalado';

  @override
  String get targetSkipped => 'Saltado';

  @override
  String get targetConflict => 'Conflicto';

  @override
  String get targetFailed => 'Fallido';

  @override
  String get targetFailureRetryable =>
      'Esta ubicación no se pudo cambiar. Puedes intentarlo de nuevo.';

  @override
  String get targetFailureNeedsAttention =>
      'Esta ubicación necesita tu atención antes de volver a intentarlo.';

  @override
  String get installationTargetFailureMessage =>
      'No se cambió nada en esta ubicación. Comprueba que el folder esté disponible y vuelve a intentarlo.';

  @override
  String get workspacePersistenceFailureMessage =>
      'No se cambió nada porque SkillsGo no pudo guardar la configuración del proyecto. Compruebe que se pueda escribir en el proyecto folder y vuelva a intentarlo.';

  @override
  String get installationStateChangedMessage =>
      'Esta ubicación cambió mientras la revisabas. Revise el estado más reciente antes de volver a intentarlo.';

  @override
  String get updateTargetFailureMessage =>
      'Esta ubicación no se pudo actualizar. Las ubicaciones Other no se vieron afectadas, por lo que solo puedes volver a intentarlo.';

  @override
  String get managementTargetFailureMessage =>
      'Esta acción no se pudo completar aquí. Las ubicaciones Other no se vieron afectadas, por lo que solo puedes volver a intentarlo.';

  @override
  String get technicalDetails => 'Detalles técnicos';

  @override
  String get targetPathExists => 'Ya existe otro elemento en esta ubicación.';

  @override
  String get targetBlockedByRisk =>
      'Su configuración de seguridad actual bloqueó la instalación en esta ubicación.';

  @override
  String get targetInstallFailed =>
      'El skill no se pudo instalar en esta ubicación.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Se instaló el skill, pero no se pudo actualizar la configuración del proyecto.';

  @override
  String get installationPlanFailed =>
      'El plan de instalación no pudo continuar';

  @override
  String get installationFailed => 'No se pudo completar la instalación';

  @override
  String get localSource => 'fuente local';

  @override
  String get noDescriptionAvailable => 'No hay descripción disponible';

  @override
  String moreCoverage(int count) {
    return '+$count más ubicaciones';
  }

  @override
  String get batchTakeoverAction => 'Administrar skills existente';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Administrar ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Comprobando el skills existente...';

  @override
  String get batchTakeoverRetry => 'Verifique el manejable skills nuevamente';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count se puede gestionar';
  }

  @override
  String get batchTakeoverPending => 'Agregando skills a la gestión...';

  @override
  String get batchTakeoverTitle =>
      '¿Administrar skills existente con SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo agregará registros de administración local sin mover, sobrescribir ni cargar archivos skill. Se omitirán los elementos no admitidos o modificados.';

  @override
  String get batchTakeoverStoryTitle =>
      'Convierta skills dispersos en una biblioteca clara';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills existente',
      one: '1 skill existente',
    );
    return 'SkillsGo encontró $_temp0 que puede administrar en esta ubicación.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Antes de la administración, no está claro dónde están instalados los skills existentes, si están actualizados, cómo recuperarlos o si los proyectos usan la misma versión.';

  @override
  String get batchTakeoverPainLocation =>
      'Ubicación de instalación desconocida';

  @override
  String get batchTakeoverPainFreshness =>
      'Estado de actualización desconocido';

  @override
  String get batchTakeoverPainRecovery => 'No hay recuperación cuando se rompe';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Diferentes versiones entre proyectos';

  @override
  String get batchTakeoverFolderTitle => 'Skills existente';

  @override
  String get batchTakeoverFolderSubtitle => 'Estado poco claro';

  @override
  String get batchTakeoverAfterLabel => 'DESPUÉS';

  @override
  String get batchTakeoverAfterTitle => 'Una biblioteca clara';

  @override
  String get batchTakeoverLibraryTitle => 'Biblioteca SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Limpiar ubicaciones';

  @override
  String get batchTakeoverBenefitFreshness => 'Actualizaciones visibles';

  @override
  String get batchTakeoverBenefitRecovery => 'Fácil recuperación';

  @override
  String get batchTakeoverBenefitVersions => 'Versiones claras';

  @override
  String get batchTakeoverManagedSection => 'Gestionado por SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Pendiente';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name es administrado por SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name no se pudo agregar a la administración';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name está esperando ser administrado';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skills son',
      one: '1 skill es',
    );
    return 'Después de la administración, $_temp0 organizados en una biblioteca con un estado de administración claro.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count más';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Agregue estos skills existentes a la gestión de SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANIZAR';

  @override
  String get batchTakeoverStatusTitle => 'Estado de gestión';

  @override
  String get batchTakeoverStatusManaged => 'Administrado';

  @override
  String get batchTakeoverStatusProgress => 'organizando';

  @override
  String get batchTakeoverStatusSkipped => 'Saltado';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Los archivos Skill permanecen en sus ubicaciones originales';

  @override
  String get batchTakeoverBoardSemantics =>
      'Los Skills se organizan en filas completas y los graba SkillsGo sin mover sus archivos.';

  @override
  String get batchTakeoverBoardComplete => 'TODO CLARO';

  @override
  String get batchTakeoverBoardPartial => 'COMPLETO';

  @override
  String get batchTakeoverStatusTotal => 'Total';

  @override
  String get batchTakeoverQueueComplete => 'No hay skills esperando.';

  @override
  String get batchTakeoverQueueWaiting =>
      'Los Skills aparecerán aquí después de la verificación';

  @override
  String get batchTakeoverNextLabel => 'PRÓXIMO';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SkillsGo bloques organizadores',
      one: '1 bloque organizador SkillsGo',
    );
    return '$_temp0 completa las filas finales';
  }

  @override
  String get batchTakeoverPreservation =>
      'Sus archivos, rutas y flujos de trabajo actuales permanecen exactamente donde están. SkillsGo sólo completa sus registros de gestión local.';

  @override
  String get batchTakeoverLaterHint =>
      'Si omite, puede usar Administrar skills existente desde la Biblioteca en cualquier momento.';

  @override
  String get batchTakeoverSkip => 'Ahora no';

  @override
  String get batchTakeoverConfirm => 'Añadir a la gestión';

  @override
  String get batchTakeoverExecutionRetry => 'Reintentar';

  @override
  String get batchTakeoverResultTitle => 'Skills añadido a la gestión.';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return '$takenOver skills agregado a la administración, $skipped omitido.';
  }

  @override
  String get batchTakeoverClose => 'Cerrar';

  @override
  String get installMoreTargets => 'Instalar en más ubicaciones';

  @override
  String get detailRepository => 'Repositorio';

  @override
  String get detailStars => 'estrellas';

  @override
  String get detailUpdated => 'Actualizado';

  @override
  String get detailArchiveSize => 'Tamaño postal';

  @override
  String get pathLabel => 'Ruta del proyecto';

  @override
  String get copyProjectPath => 'Copiar ruta del proyecto';

  @override
  String get projectPathCopied => 'Ruta del proyecto copiada';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Descubra, instale y administre Skills en todos sus proyectos y Agents.';

  @override
  String get onboardingDetectedAgents => 'Detectado Agents';

  @override
  String get onboardingNoAgents =>
      'No se detectó ningún Agents instalado. Aún puedes continuar.';

  @override
  String get onboardingNext => 'Próximo';

  @override
  String get onboardingProjectsTitle => 'Añade tus proyectos';

  @override
  String get onboardingProjectsDescription =>
      'Elija los proyectos que desea que gestione SkillsGo.';

  @override
  String get onboardingAddProject => 'Añadir ahora';

  @override
  String get onboardingAddProjectLater => 'o más tarde';

  @override
  String get onboardingStartUsing => 'Comience a usar SkillsGo';

  @override
  String get onboardingBack => 'Atrás';

  @override
  String get restartOnboardingTitle => 'Incorporación';

  @override
  String get restartOnboardingDescription =>
      'Vea la guía de primer lanzamiento nuevamente sin eliminar proyectos, configuraciones o datos Skills.';

  @override
  String get restartOnboardingAction => 'Reiniciar la incorporación';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo no pudo reiniciar la incorporación.';

  @override
  String get libraryRefreshSettingsTitle => 'Actualizar biblioteca local';

  @override
  String get libraryRefreshSettingsDescription =>
      'Rescanee el Skills instalado, los proyectos agregados, el Agents y el Skills externo que se puede administrar. Esto no instala, actualiza ni elimina nada.';

  @override
  String get libraryRefreshSettingsAction => 'Actualizar biblioteca';

  @override
  String get libraryRefreshSettingsPending => 'Biblioteca refrescante...';

  @override
  String get libraryRefreshSettingsSuccess => 'Biblioteca local renovada.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo no pudo actualizar la biblioteca local.';

  @override
  String get onboardingProjectError =>
      'SkillsGo no pudo agregar proyectos desde este directorio.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo no pudo cargar sus proyectos agregados.';

  @override
  String get onboardingStartupError =>
      'SkillsGo no pudo cargar la configuración.';

  @override
  String get onboardingStateError =>
      'SkillsGo no pudo guardar el progreso de su configuración. Intentar otra vez.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI necesita atención';

  @override
  String get onboardingCliErrorDescription =>
      'Repare el CLI incluido y luego vuelva a intentar continuar.';
}
