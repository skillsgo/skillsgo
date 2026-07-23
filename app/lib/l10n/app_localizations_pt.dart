// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get discover => 'Descubra';

  @override
  String get discoverSkills => 'É bom saber um pouco mais.';

  @override
  String get library => 'Biblioteca';

  @override
  String get settings => 'Configurações';

  @override
  String get openSettings => 'Abra Configurações';

  @override
  String get cliNeedsAttention =>
      'Um componente SkillsGo necessário precisa de atenção.';

  @override
  String get cliMissingBundled =>
      'Um componente SkillsGo necessário está faltando ou não pode ser iniciado. Reinstale o SkillsGo para restaurá-lo.';

  @override
  String get cliDamagedBundled =>
      'Um componente SkillsGo necessário está danificado. Reinstale o SkillsGo para restaurá-lo.';

  @override
  String get cliIncompatibleBundled =>
      'Um componente SkillsGo necessário não corresponde a esta versão do aplicativo. Atualize ou reinstale o SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle =>
      'Encontre uma habilidade para seu próximo movimento.';

  @override
  String get skillsLeaderboard => 'É bom saber um pouco mais.';

  @override
  String searchResultsFor(String query) {
    return 'Resultados para “$query”';
  }

  @override
  String get searchSkills => 'Pesquise habilidades ou cole um link Git…';

  @override
  String get search => 'Pesquisar';

  @override
  String get ranking => 'Classificação';

  @override
  String get trending => 'Tendências';

  @override
  String get hot => 'Quente';

  @override
  String get discoverNavigation => 'Descubra a navegação';

  @override
  String get allTimeRanking => 'Classificação de todos os tempos';

  @override
  String get trendingNow => 'Tendências nas últimas 24 horas';

  @override
  String get hotNow => 'Quente agora';

  @override
  String get allTimeDescription =>
      'Skills público ordenado por instalações aceitas em todos os tempos.';

  @override
  String get trendingDescription =>
      'Skills público ordenado por instalações aceitas durante a última janela de 24 horas.';

  @override
  String get hotDescription =>
      'Skills público ordenado por velocidade e alteração de instalação de curto prazo.';

  @override
  String get offlineTitle => 'Não é possível conectar ao SkillsGo';

  @override
  String get offlineMessage =>
      'Verifique sua conexão com a Internet e tente novamente. Se você usa um proxy ou endereço de serviço personalizado, revise-o em Configurações.';

  @override
  String get searchFailedTitle => 'Pesquisa tropeçou';

  @override
  String get validationTitle => 'Verifique o que você digitou';

  @override
  String get validationMessage =>
      'SkillsGo não pôde usar esta solicitação. Revise o que você digitou e tente novamente.';

  @override
  String get serverTitle => 'Serviço temporariamente indisponível';

  @override
  String get serverMessage =>
      'SkillsGo não pode concluir esta solicitação no momento. Tente novamente em alguns instantes.';

  @override
  String get timeoutTitle => 'Isso está demorando muito';

  @override
  String get timeoutMessage =>
      'O serviço não respondeu a tempo. Verifique sua conexão ou tente novamente.';

  @override
  String get invalidResponseTitle => 'SkillsGo precisa de uma atualização';

  @override
  String get invalidResponseMessage =>
      'Esta resposta não pode ser lida pela sua versão do SkillsGo. Atualize o aplicativo e tente novamente.';

  @override
  String get invalidLocalDataTitle =>
      'Não consigo ler uma habilidade instalada';

  @override
  String get invalidLocalDataMessage =>
      'Algumas informações de instalação local estão danificadas ou incompatíveis. Atualize ou reinstale o SkillsGo e tente novamente.';

  @override
  String get tryAgain => 'Tente novamente';

  @override
  String get searchEmptyTitle => 'Pesquise, não role.';

  @override
  String get searchEmptyMessage =>
      'Insira uma capacidade, origem ou tarefa para pesquisar habilidades públicas.';

  @override
  String get noSkillsTitle => 'Nenhuma habilidade encontrada';

  @override
  String get noSkillsMessage =>
      'Experimente uma frase mais ampla ou verifique a ortografia.';

  @override
  String get focusSearch => 'Pesquisa de foco';

  @override
  String get skillsFromLink => 'Skills deste link';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skills',
      one: '1 Skill',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skills de $source',
      one: '1 Skill de $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Este link está pronto para inspecionar';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source não está nos resultados da pesquisa atual. SkillsGo pode inspecionar o link diretamente na próxima etapa.';
  }

  @override
  String get inspectSource => 'Veja as habilidades neste link';

  @override
  String get collectionEmptyTitle => 'Não há Skills nesta coleção';

  @override
  String get collectionEmptyMessage =>
      'Não há nada aqui ainda. Tente novamente após mais atividades de instalação.';

  @override
  String get loadMore => 'Carregar mais';

  @override
  String get install => 'Instalar';

  @override
  String get installAll => 'Instale todas as habilidades';

  @override
  String get latestCommit => 'Último commit';

  @override
  String get installToMoreTargets => 'Instale em mais locais';

  @override
  String localTargets(int count) {
    return 'Destinos locais $count';
  }

  @override
  String allTimeMetric(String count) {
    return 'Instalações $count de todos os tempos';
  }

  @override
  String trendingMetric(String count) {
    return 'Instalações $count / 24h';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value esta hora · $change';
  }

  @override
  String get trustUnverified => 'Não verificado';

  @override
  String get trustCommunityVerified => 'Comunidade verificada';

  @override
  String get trustPublisherVerified => 'Editor verificado';

  @override
  String get trustOfficial => 'Oficial';

  @override
  String get trustWarned => 'Avisado';

  @override
  String get trustDelisted => 'Removido';

  @override
  String get riskUnknown => 'Risco desconhecido';

  @override
  String get riskLow => 'Baixo risco';

  @override
  String get riskMedium => 'Risco médio';

  @override
  String get riskHigh => 'Alto risco';

  @override
  String get riskCritical => 'Risco crítico';

  @override
  String openSkill(String name) {
    return 'Abra $name';
  }

  @override
  String installs(String count) {
    return 'Instalações $count';
  }

  @override
  String get detailFailedTitle => 'Não foi possível carregar este Skill';

  @override
  String get detailLoading => 'Carregando detalhes Skill auditáveis';

  @override
  String get artifactUnavailableTitle => 'Artefato indisponível';

  @override
  String get artifactUnavailableMessage =>
      'Esta versão não está disponível no momento. Tente novamente ou escolha outra versão.';

  @override
  String get detailInvalidTitle => 'Metadados de artefato não suportados';

  @override
  String get detailInvalidMessage =>
      'Alguns detalhes desta habilidade estão incompletos ou não podem ser lidos. Atualize o SkillsGo e tente novamente.';

  @override
  String get instructionsTab => 'Instruções';

  @override
  String get manifestTab => 'Manifest';

  @override
  String immutableVersionLabel(String version) {
    return '$version imutável';
  }

  @override
  String commitIdentity(String sha) {
    return 'Confirmar $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Árvore $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Conteúdo $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'A confiança do editor verifica a propriedade ou manutenção; não certifica a segurança do artefato. O risco é avaliado separadamente para esta versão imutável.';

  @override
  String get knownInstallationTargets => 'Destinos de instalação conhecidos';

  @override
  String get installationRange => 'Escopo instalado';

  @override
  String get targetDetails => 'Mostrar detalhes do alvo';

  @override
  String get hideTargetDetails => 'Ocultar detalhes do alvo';

  @override
  String installedVersionLabel(String version) {
    return 'Versão $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Projeto';

  @override
  String get fileContentUnavailable => 'Visualização binária ou indisponível';

  @override
  String get fileContentTruncated =>
      'Visualização truncada pelo limite de segurança Hub.';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get backToSearch => 'Voltar à pesquisa';

  @override
  String get installForCodex => 'Instalar para Codex';

  @override
  String get cliNotDetected => 'habilidades (não detectadas)';

  @override
  String get snapshotFiles => 'Arquivos de instantâneo';

  @override
  String get globalCodex => 'Global · Codex';

  @override
  String get yourLibrary => 'O que você sabe está tudo aqui.';

  @override
  String get libraryNavigation => 'Navegação na biblioteca';

  @override
  String get all => 'Todos';

  @override
  String get allSkills => 'Todos Skills';

  @override
  String get updatesOnly => 'Atualizações';

  @override
  String get allAgents => 'Todos Agents';

  @override
  String get allProjects => 'Todos os projetos';

  @override
  String get specificProject => 'Projeto';

  @override
  String get userScope => 'Globais';

  @override
  String get addProject => 'Adicionar projeto';

  @override
  String get relocateProject => 'Realocar';

  @override
  String get removeFromList => 'Remover da lista';

  @override
  String removeProjectTitle(String name) {
    return 'Remover $name do SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Apenas a referência do aplicativo será removida. SkillsGo não alterará ou excluirá nenhum arquivo neste diretório.';

  @override
  String projectRailUnavailable(String name) {
    return '$name – indisponível';
  }

  @override
  String get emptyProjectTitle => 'Ainda não há Skills';

  @override
  String get browseSkills => 'Navegar Skills';

  @override
  String get projectMissingTitle => 'O diretório do projeto está faltando';

  @override
  String get projectMissingMessage =>
      'O diretório pode ter sido movido ou seu volume pode estar offline. Realoque-o ou remova apenas a referência do aplicativo.';

  @override
  String get projectPermissionTitle => 'A permissão do projeto é necessária';

  @override
  String get projectPermissionMessage =>
      'SkillsGo não pode inspecionar esta raiz selecionada. Conceda acesso realocando-o por meio do seletor de diretório.';

  @override
  String get projectInaccessibleTitle =>
      'O diretório do projeto está inacessível';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo manteve esta referência de projeto. Verifique o caminho ou volume e realoque-o.';

  @override
  String get checking => 'Verificando…';

  @override
  String get checkUpdates => 'Verifique as atualizações';

  @override
  String get refresh => 'Atualizar';

  @override
  String get libraryUnavailable => 'Biblioteca indisponível';

  @override
  String get libraryEmpty => 'Nenhuma habilidade instalada ainda';

  @override
  String get libraryEmptyMessage =>
      'Instale um Skill do Discover e ele aparecerá aqui.';

  @override
  String get searchLibrary => 'Pesquise habilidades instaladas';

  @override
  String get libraryNoMatches => 'Nenhuma correspondência Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Experimente um nome, fonte, Agent, projeto ou versão diferente.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return 'Projetos $count';
  }

  @override
  String versionsSummary(int count) {
    return 'Versões $count';
  }

  @override
  String get hubManaged => 'Hub gerenciado';

  @override
  String get localManaged => 'Gerenciado localmente';

  @override
  String get externalInstallation => 'Instalação externa';

  @override
  String get readOnly => 'Somente leitura';

  @override
  String get unversioned => 'Não versionado';

  @override
  String get supportingFiles => 'Arquivos de suporte';

  @override
  String get versionDivergence => 'Divergência de versão';

  @override
  String get healthHealthy => 'Saudável';

  @override
  String get healthMissing => 'Alvo ausente';

  @override
  String get healthReplaced => 'Alvo substituído';

  @override
  String get healthLocalModification => 'Modificação Local';

  @override
  String get healthUnreadable => 'Alvo ilegível';

  @override
  String get healthUndeclared => 'Não declarado';

  @override
  String get healthWorkspaceUnreadable =>
      'Estado do espaço de trabalho ilegível';

  @override
  String get healthLockMismatch => 'Incompatibilidade de bloqueio';

  @override
  String get healthUnexpectedPath => 'Caminho de destino inesperado';

  @override
  String get modeExternal => 'Externo';

  @override
  String get notLinked => 'NÃO VINCULADO';

  @override
  String get update => 'Atualizar';

  @override
  String get backToLibrary => 'Voltar para a biblioteca';

  @override
  String get remove => 'Remover';

  @override
  String get manageTargets => 'Gerenciar escopo';

  @override
  String skillsSelected(int count) {
    return '$count selecionado';
  }

  @override
  String get clearSelection => 'Limpar seleção';

  @override
  String get selectCurrentResults => 'Selecione os resultados atuais';

  @override
  String get clearCurrentResultSelection =>
      'Limpar seleção de resultados atual';

  @override
  String get manageTargetsTitle => 'Gerenciar destinos de instalação';

  @override
  String get manageTargetsDescription =>
      'Escolha uma ação exata para cada alvo. Os alvos não selecionados não serão alterados.';

  @override
  String targetActionsSelected(int selected, int total) {
    return '$selected dos alvos $total selecionados';
  }

  @override
  String get repairTarget => 'Reparar';

  @override
  String get confirmRemoveTarget => 'Confirmar remoção';

  @override
  String get applyTargetActions => 'Aplicar ações selecionadas';

  @override
  String get managementProgressTitle => 'Aplicando ações direcionadas';

  @override
  String get managementResultsTitle => 'Resultados da ação alvo';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded foi bem-sucedido, $failed falhou';
  }

  @override
  String get workspaceOwnershipChanges =>
      'As ações do projeto selecionadas atualizarão skillsgo.yaml e skillsgo.lock.';

  @override
  String get targetContentPreserved =>
      'O conteúdo de destino atual será preservado.';

  @override
  String get localReadFailed => 'Não consigo ler este Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo não conseguiu ler esta habilidade instalada. Verifique se a pasta está disponível e acessível e tente novamente.';

  @override
  String get localConfiguration => 'CONFIGURAÇÕES DE HABILIDADES';

  @override
  String get settingsNavigation => 'Navegação nas configurações';

  @override
  String get general => 'Personalizar';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Política de instalação';

  @override
  String get storage => 'Armazenamento';

  @override
  String get colorScheme => 'Esquema de cores';

  @override
  String get about => 'Sobre';

  @override
  String get colorSchemeInspectorTitle => 'Funções de cores Material geradas';

  @override
  String get skillsColorTokensTitle => 'Cores semânticas SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Cores de produtos criadas a partir de Radix Sand e organizadas com semântica Primer, com Folder como uma hierarquia espacial dedicada.';

  @override
  String get colorSchemeInspectorDescription =>
      'Visualize cada token ColorScheme não obsoleto gerado a partir da semente atual. Clique em uma cor para copiar seu valor HEX.';

  @override
  String get colorSchemePairPreview => 'Pares semânticos';

  @override
  String get colorSchemePairPreviewDescription =>
      'Funções de primeiro e segundo plano renderizadas juntas para expor contraste e hierarquia.';

  @override
  String get colorSchemeComponentPreview => 'Visualização do componente';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Controles Material representativos renderizados com este esquema de visualização exato.';

  @override
  String get colorSchemeSampleTitle => 'Título do cartão Skill';

  @override
  String get colorSchemeSampleBody =>
      'A cópia secundária usa onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Copiado';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Primário';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Ênfase primária, contêineres e papéis de acento fixos.';

  @override
  String get colorSchemeGroupSecondary => 'Secundário';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Ênfase de apoio e papéis secundários fixos.';

  @override
  String get colorSchemeGroupTertiary => 'Terciário';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Sotaques contrastantes e papéis terciários fixos.';

  @override
  String get colorSchemeGroupSurface => 'Superfície';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Hierarquia de página, contêiner, elevação e primeiro plano.';

  @override
  String get colorSchemeGroupUtility => 'Esboço e Utilidade';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Limites, sombras, telas e superfícies inversas.';

  @override
  String get colorSchemeGroupError => 'Erro';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Ações de erro, mensagens e contêineres.';

  @override
  String get colorSchemeUsagePrimary =>
      'Ações primárias, foco e acentos de alta ênfase.';

  @override
  String get colorSchemeUsageSecondary =>
      'Ações de apoio e acentos de ênfase média.';

  @override
  String get colorSchemeUsageTertiary =>
      'Acentos contrastantes que complementam o primário e o secundário.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Texto e ícones exibidos no $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Recipiente $family de menor ênfase para seleções e acentos.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Recipiente $family fixo independente de brilho.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Recipiente $family fixo independente de brilho esmaecido.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Conteúdo de alta ênfase no contêiner $family fixo.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Conteúdo com menor ênfase no contêiner $family fixo.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Página base e superfície de região grande.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Superfície de base escurecida usada no tom de superfície mais escuro.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Superfície de base brilhante usada no tom de superfície mais claro.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'A elevação do contêiner de superfície $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'mais baixo';

  @override
  String get colorSchemeElevationLow => 'baixo';

  @override
  String get colorSchemeElevationDefault => 'padrão';

  @override
  String get colorSchemeElevationHigh => 'alto';

  @override
  String get colorSchemeElevationHighest => 'mais alto';

  @override
  String get colorSchemeUsageOnSurface =>
      'Texto primário e ícones exibidos em superfícies.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Texto secundário, rótulos e ícones suaves nas superfícies.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Matiz de elevação Material derivado do primário.';

  @override
  String get colorSchemeUsageOutline =>
      'Limites proeminentes e contornos de componentes focados.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Limites sutis, separadores e contornos de baixa ênfase.';

  @override
  String get colorSchemeUsageShadow =>
      'Cor de sombra projetada para superfícies elevadas.';

  @override
  String get colorSchemeUsageScrim =>
      'Sobreposição modal usada para tirar a ênfase do conteúdo de fundo.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Superfície com ênfase invertida em claro e escuro.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Acento primário exibido em uma superfície inversa.';

  @override
  String get colorSchemeUsageError =>
      'Ações de erro, status e feedback de alta ênfase.';

  @override
  String get save => 'Salvar';

  @override
  String get advancedSettings => 'Avançado';

  @override
  String get remindersSettings => 'Lembretes';

  @override
  String get remindersSettingsTitle => 'Configurações de lembrete';

  @override
  String get remindersSettingsDescription => 'Escolha quais lembretes receber.';

  @override
  String get updateReminderTitle => 'Atualizar lembretes';

  @override
  String get updateReminderDescription =>
      'Verifique se há atualizações quando a Biblioteca for aberta.';

  @override
  String get securityReminderTitle => 'Alertas de alto risco';

  @override
  String get securityReminderDescription =>
      'Notificá-lo sobre novos riscos Altos ou Críticos nas habilidades instaladas.';

  @override
  String availableUpdatesReminder(int count) {
    return 'As habilidades instaladas do $count têm atualizações';
  }

  @override
  String get openAvailableUpdates =>
      'Abra a visualização de atualizações disponíveis para revisá-las e atualizá-las.';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'As habilidades instaladas do $count precisam de uma revisão de segurança';
  }

  @override
  String get reviewInstalledSkills =>
      'Revise suas informações de risco antes de usá-las ou atualizá-las.';

  @override
  String get generalSettingsTitle => 'Faça do SkillsGo seu';

  @override
  String get generalSettingsDescription =>
      'A interface segue o idioma do sistema, acessibilidade e preferências de movimento.';

  @override
  String get agentsSettingsTitle => 'Tempo de execução Agent';

  @override
  String get hubSettingsTitle => 'Origem Hub';

  @override
  String get hubSettingsDescription =>
      'Use o Hub oficial ou uma origem auto-hospedada HTTP(S) que implemente o mesmo protocolo SkillsGo.';

  @override
  String get testConnection => 'Conexão de teste';

  @override
  String get saveOrigin => 'Salvar origem';

  @override
  String get resetDefault => 'Redefinir para o padrão';

  @override
  String get connectionReady => 'Conexão pronta';

  @override
  String get connectionFailed => 'Falha na conexão';

  @override
  String get hubInvalidOrigin =>
      'Insira uma origem HTTP(S) válida sem credenciais, uma consulta ou um fragmento.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub retornou HTTP $status. Verifique a origem e a configuração do servidor.';
  }

  @override
  String get hubInvalidProtocol =>
      'O servidor não retornou o protocolo de pesquisa SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'O Hub retornou JSON inválido.';

  @override
  String get hubConnectionFailure =>
      'Não foi possível acessar o Hub. Verifique a configuração de origem, rede, proxy e TLS.';

  @override
  String get hubConnectionTimeout =>
      'A conexão Hub expirou. Verifique a rede ou tente novamente.';

  @override
  String get riskPolicyTitle => 'Política de risco pessoal';

  @override
  String get riskPolicyDescription =>
      'As regras de segurança se aplicam quando você instala ou atualiza uma habilidade.';

  @override
  String get confirmHighRisk => 'Exigir confirmação para alto risco';

  @override
  String get confirmHighRiskDescription =>
      'Artefatos de alto risco sempre exigem confirmação adicional antes da instalação.';

  @override
  String get allowCriticalOverride =>
      'Permitir uma substituição explícita de risco crítico';

  @override
  String get allowCriticalOverrideDescription =>
      'Os artefatos de risco crítico permanecem bloqueados por padrão. Habilite isto apenas para expor uma substituição manual separada.';

  @override
  String get storageHealthy => 'Legível';

  @override
  String get storageNotInitialized => 'Não inicializado';

  @override
  String get storageUnavailable => 'Indisponível';

  @override
  String get storageInvalidResponse =>
      'O CLI incluído retornou uma resposta de diagnóstico não suportada.';

  @override
  String get aboutSettingsTitle => 'Compatibilidade do produto';

  @override
  String get appVersion => 'Versão do aplicativo';

  @override
  String get cliVersion => 'Versão CLI empacotada';

  @override
  String get compatible => 'Compatível';

  @override
  String get hubOriginSaved => 'Hub Origin salva e aplicada.';

  @override
  String get policySaved => 'Política de instalação salva.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'PRONTO';

  @override
  String get unknown => 'DESCONHECIDO';

  @override
  String get missing => 'FALTANDO';

  @override
  String get incompatible => 'INCOMPATÍVEL';

  @override
  String get detecting => 'Detectando…';

  @override
  String get customCliPath => 'Caminho executável personalizado';

  @override
  String get saveAndDetect => 'Salvar e detectar';

  @override
  String get detectAgain => 'Detectar novamente';

  @override
  String get agentInstalled => 'Instalado';

  @override
  String get agentSupported => 'Suportado';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed instalado · $supported compatível';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Instalado · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Não instalado · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Compatível com SkillsGo, mas não detectado neste Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Caminhos de carregamento Skill: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Os dados de detecção Agent não estão disponíveis. Execute a detecção novamente.';

  @override
  String get noInstalledAgentsTitle => 'Nenhum Agents instalado detectado';

  @override
  String get noInstalledAgentsMessage =>
      'Você pode continuar navegando neste Skill, mas ainda não há um alvo de instalação. Instale um Agent compatível e execute a detecção novamente.';

  @override
  String get clearCustomPath => 'Limpar caminho personalizado';

  @override
  String get privacyProvenance => 'Privacidade e proveniência';

  @override
  String get privacySummary =>
      'Suas pesquisas não são salvas e o SkillsGo não mantém registros de comandos.';

  @override
  String get language => 'Idioma';

  @override
  String get personalizationTheme => 'Tema';

  @override
  String get folderColorTheme => 'Cor do tema';

  @override
  String get folderColorThemeDescription =>
      'Escolha uma cor que você gosta. SkillsGo construirá uma paleta de interface coordenada em torno dele.';

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
  String get appearanceMode => 'Modo';

  @override
  String get appearanceModeDescription =>
      'Siga a aparência do seu sistema ou use sempre um tema claro ou escuro.';

  @override
  String get followSystem => 'Sistema';

  @override
  String get lightMode => 'Luz';

  @override
  String get darkMode => 'Escuro';

  @override
  String get wallpaper => 'Papel de parede';

  @override
  String get wallpaperDescription =>
      'Escolha um fundo celestial. Sua seleção aparece imediatamente atrás de Folder.';

  @override
  String get wallpaperSun => 'Sol';

  @override
  String get wallpaperMercury => 'Mercúrio';

  @override
  String get wallpaperVenus => 'Vênus';

  @override
  String get wallpaperEarth => 'Terra';

  @override
  String get wallpaperMars => 'Marte';

  @override
  String get wallpaperJupiter => 'Júpiter';

  @override
  String get wallpaperSaturn => 'Saturno';

  @override
  String get wallpaperUranus => 'Urano';

  @override
  String get wallpaperNeptune => 'Netuno';

  @override
  String get wallpaperPluto => 'Plutão';

  @override
  String get wallpaperMoon => 'Lua';

  @override
  String folderThemeChoice(String theme) {
    return 'Tema $theme Folder';
  }

  @override
  String get privacyAffiliation =>
      'A telemetria de instalação anônima é controlada pelas configurações do SkillsGo. SkillsGo não é afiliado a OpenAI ou Codex.';

  @override
  String get commandCompleted => 'Comando concluído';

  @override
  String get commandFailed => 'Falha no comando';

  @override
  String commandExit(int code) {
    return 'Saia do $code · expanda para o log desta sessão';
  }

  @override
  String get command => 'Comando';

  @override
  String get cancel => 'Cancelar';

  @override
  String get updateUnknown => 'DESCONHECIDO';

  @override
  String get updateChecking => 'VERIFICAÇÃO';

  @override
  String get upToDate => 'ATUALIZADO';

  @override
  String get updateAvailable => 'ATUALIZAÇÃO';

  @override
  String get updateUnavailable => 'INDISPONÍVEL';

  @override
  String get updateCheckFailed => 'VERIFICAÇÃO FALHA';

  @override
  String get installSkill => 'Instale Skill';

  @override
  String get installLocationTitle => 'Definir local de instalação';

  @override
  String get userLevel => 'Nível de usuário';

  @override
  String get projectLevel => 'Nível do projeto';

  @override
  String get projects => 'Projetos';

  @override
  String get loading => 'Carregando…';

  @override
  String get repositoryParsing => 'Analisando Repositório…';

  @override
  String userInstallSummary(int agents) {
    return 'Disponível para $agents Agents em nível de usuário';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return 'Projetos $projects · $agents Agents';
  }

  @override
  String get installationResults => 'Resultados da instalação';

  @override
  String get installationInProgress => 'Instalação em andamento';

  @override
  String get installationSucceeded => 'Instalação concluída';

  @override
  String get installationSucceededMessage =>
      'O Skill agora está disponível nos locais selecionados.';

  @override
  String get projectUnavailable => 'Projeto indisponível';

  @override
  String get installedCell => 'Instalado';

  @override
  String get unsupportedCell => 'Indisponível';

  @override
  String get confirmInstall => 'Confirme a instalação';

  @override
  String installAllRepositorySkills(int count) {
    return 'Instale todas as habilidades do repositório ($count)';
  }

  @override
  String get installAllSkillsTo => 'Instale todas as habilidades para';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Instale todas as habilidades $repository ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Instale $skill para';
  }

  @override
  String get availableInAllProjects => 'Todos os projetos';

  @override
  String get availableInSelectedProjects => 'Projetos selecionados';

  @override
  String get usedBy => 'Para Agents';

  @override
  String get backToTargets => 'Voltar aos alvos';

  @override
  String get stayHere => 'Fique aqui';

  @override
  String get viewInLibrary => 'Ver na biblioteca';

  @override
  String planCreateCount(int count) {
    return '$count criar';
  }

  @override
  String planSkipCount(int count) {
    return '$count pular';
  }

  @override
  String planReplaceCount(int count) {
    return 'Substituição $count';
  }

  @override
  String planConflictCount(int count) {
    return 'Conflito $count';
  }

  @override
  String planRiskCount(int count) {
    return 'Risco $count bloqueado';
  }

  @override
  String get refreshInstallationPlan => 'Aplicar resoluções';

  @override
  String get replaceVersionConflict =>
      'Substitua a versão instalada neste destino';

  @override
  String get replaceSkillIdCollision =>
      'Substitua o ID Skill diferente neste destino';

  @override
  String get replaceLocalModification =>
      'Descarte as modificações locais e substitua este alvo';

  @override
  String get sharedTargetConflict =>
      'Este caminho é compartilhado por outros alvos Agent';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Retorne à matriz de destino e selecione cada Agent afetado antes de substituir: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Substitua o alvo conflitante';

  @override
  String get confirmHighRiskArtifact => 'Confirmação de artefato de alto risco';

  @override
  String get confirmCriticalRiskArtifact =>
      'Confirmação de substituição de risco crítico';

  @override
  String get confirmRiskForSelectedTargets =>
      'Analisei os arquivos do artefato e aceito esse risco para os alvos selecionados';

  @override
  String get criticalRiskBlocked =>
      'A instalação de risco crítico está bloqueada';

  @override
  String get criticalRiskOverrideDisabled =>
      'Habilite a substituição explícita de risco crítico em Configurações antes que este plano possa continuar.';

  @override
  String get workspaceManifestChanges => 'Mudanças no Workspace Manifest';

  @override
  String get noWorkspaceManifestChanges =>
      'Nenhum arquivo Workspace Manifest será alterado.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'não presente';

  @override
  String get planActionCreate => 'Criar';

  @override
  String get planActionReplace => 'Substituir';

  @override
  String get planActionSkip => 'Pular';

  @override
  String get planActionConflict => 'Conflito';

  @override
  String get planActionBlockedByRisk => 'Bloqueado por risco';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'Destinos $succeeded instalados, $failed falhou';
  }

  @override
  String get installationProgressTitle => 'Instalação em andamento';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished dos alvos $total concluídos';
  }

  @override
  String get targetWaiting => 'Esperando';

  @override
  String get targetRunning => 'Instalando';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tentar novamente $count destinos com falha',
      one: 'Tentar novamente 1 destino com falha',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Selecione alvos para atualizar';

  @override
  String get updatePlanDescription =>
      'Escolha os alvos de instalação exatos. Agents e projetos não selecionados permanecem inalterados.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return '$selected de destinos atualizáveis $available selecionados';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Referência da fonte: $reference';
  }

  @override
  String get fixedVersionTarget => 'Fixado – sem referência móvel';

  @override
  String get currentVersionTarget => 'Atualizado';

  @override
  String get updateCheckTargetFailed => 'Falha na verificação de atualização';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Reparar manifesto do espaço de trabalho';

  @override
  String get updateSelectedTargets => 'Atualizar alvos selecionados';

  @override
  String get updateProgressTitle => 'Atualizando metas';

  @override
  String get updateResultsTitle => 'Atualizar resultados';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished dos alvos $total concluídos';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tentar novamente $count atualizações com falha',
      one: 'Tentar novamente 1 atualização com falha',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Nenhum destino selecionado tem uma atualização disponível.';

  @override
  String get closeUpdatePlan => 'Fechar';

  @override
  String get targetSucceeded => 'Instalado';

  @override
  String get targetSkipped => 'Ignorado';

  @override
  String get targetConflict => 'Conflito';

  @override
  String get targetFailed => 'Falha';

  @override
  String get targetFailureRetryable =>
      'Este local não pôde ser alterado. Você pode tentar novamente.';

  @override
  String get targetFailureNeedsAttention =>
      'Este local precisa da sua atenção antes de tentar novamente.';

  @override
  String get installationTargetFailureMessage =>
      'Nada foi alterado neste local. Verifique se a pasta está disponível e tente novamente.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Nada foi alterado porque o SkillsGo não conseguiu salvar as configurações do projeto. Verifique se a pasta do projeto é gravável e tente novamente.';

  @override
  String get installationStateChangedMessage =>
      'Este local mudou enquanto você o revisava. Revise o estado mais recente antes de tentar novamente.';

  @override
  String get updateTargetFailureMessage =>
      'Este local não pôde ser atualizado. Outros locais não foram afetados, então você pode tentar novamente apenas este.';

  @override
  String get managementTargetFailureMessage =>
      'Esta ação não pôde ser concluída aqui. Outros locais não foram afetados, então você pode tentar novamente apenas este.';

  @override
  String get technicalDetails => 'Detalhes técnicos';

  @override
  String get targetPathExists => 'Outro item já existe neste local.';

  @override
  String get targetBlockedByRisk =>
      'Suas configurações de segurança atuais bloquearam a instalação neste local.';

  @override
  String get targetInstallFailed =>
      'A habilidade não pôde ser instalada neste local.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'A habilidade foi instalada, mas não foi possível atualizar as configurações do projeto.';

  @override
  String get installationPlanFailed =>
      'O plano de instalação não pôde continuar';

  @override
  String get installationFailed => 'Não foi possível concluir a instalação';

  @override
  String get localSource => 'Fonte local';

  @override
  String get noDescriptionAvailable => 'Nenhuma descrição disponível';

  @override
  String moreCoverage(int count) {
    return '+$count mais locais';
  }

  @override
  String get batchTakeoverAction => 'Gerenciar habilidades existentes';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Gerenciar ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Verificando as habilidades existentes…';

  @override
  String get batchTakeoverRetry =>
      'Verifique as habilidades gerenciáveis novamente';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count pode ser gerenciado';
  }

  @override
  String get batchTakeoverPending => 'Adicionando habilidades à gestão…';

  @override
  String get batchTakeoverTitle =>
      'Gerenciar habilidades existentes com SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo adicionará registros de gerenciamento local sem mover, substituir ou fazer upload de arquivos de habilidades. Itens não suportados ou alterados serão ignorados.';

  @override
  String get batchTakeoverStoryTitle =>
      'Transforme habilidades dispersas em uma biblioteca clara';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skills existentes',
      one: '1 Skill existente',
    );
    return 'O SkillsGo encontrou $_temp0 que pode gerenciar neste local.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Antes da gestão, não está claro onde as habilidades existentes estão instaladas, se são atuais, como recuperá-las ou se os projetos utilizam a mesma versão.';

  @override
  String get batchTakeoverPainLocation => 'Local de instalação desconhecido';

  @override
  String get batchTakeoverPainFreshness => 'Status de atualização desconhecido';

  @override
  String get batchTakeoverPainRecovery => 'Sem recuperação quando quebrado';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Versões diferentes entre projetos';

  @override
  String get batchTakeoverFolderTitle => 'Skills existente';

  @override
  String get batchTakeoverFolderSubtitle => 'Estado pouco claro';

  @override
  String get batchTakeoverAfterLabel => 'DEPOIS';

  @override
  String get batchTakeoverAfterTitle => 'Uma biblioteca clara';

  @override
  String get batchTakeoverLibraryTitle => 'Biblioteca SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Limpar locais';

  @override
  String get batchTakeoverBenefitFreshness => 'Atualizações visíveis';

  @override
  String get batchTakeoverBenefitRecovery => 'Recuperação fácil';

  @override
  String get batchTakeoverBenefitVersions => 'Versões claras';

  @override
  String get batchTakeoverManagedSection => 'Gerenciado por SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Pendente';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name é gerenciado por SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name não pôde ser adicionado ao gerenciamento';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name está aguardando para ser gerenciado';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skills ficam organizados',
      one: '1 Skill fica organizado',
    );
    return 'Após o gerenciamento, $_temp0 em uma única Library com um status de gerenciamento claro.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count mais';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Adicione essas habilidades existentes ao gerenciamento SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ORGANIZAR';

  @override
  String get batchTakeoverStatusTitle => 'Status de gerenciamento';

  @override
  String get batchTakeoverStatusManaged => 'Gerenciado';

  @override
  String get batchTakeoverStatusProgress => 'Organizando';

  @override
  String get batchTakeoverStatusSkipped => 'Ignorado';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Os arquivos Skill permanecem em seus locais originais';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills são organizados em linhas completas e gravados pelo SkillsGo sem mover seus arquivos.';

  @override
  String get batchTakeoverBoardComplete => 'TUDO CLARO';

  @override
  String get batchTakeoverBoardPartial => 'COMPLETO';

  @override
  String get batchTakeoverStatusTotal => 'Total';

  @override
  String get batchTakeoverQueueComplete => 'Nenhuma habilidade está esperando';

  @override
  String get batchTakeoverQueueWaiting =>
      'Os Skills aparecerão aqui após a verificação';

  @override
  String get batchTakeoverNextLabel => 'PRÓXIMO';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocos organizadores do SkillsGo',
      one: '1 bloco organizador do SkillsGo',
    );
    return '$_temp0 completam as linhas finais.';
  }

  @override
  String get batchTakeoverPreservation =>
      'Seus arquivos, caminhos e fluxos de trabalho atuais permanecem exatamente onde estão. SkillsGo apenas completa seus registros de gerenciamento local.';

  @override
  String get batchTakeoverLaterHint =>
      'Se você pular, poderá usar Gerenciar habilidades existentes na Biblioteca a qualquer momento.';

  @override
  String get batchTakeoverSkip => 'Agora não';

  @override
  String get batchTakeoverConfirm => 'Adicionar ao gerenciamento';

  @override
  String get batchTakeoverExecutionRetry => 'Tentar novamente';

  @override
  String get batchTakeoverResultTitle => 'Skills adicionados ao gerenciamento';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return 'Habilidades $takenOver adicionadas ao gerenciamento, $skipped ignoradas.';
  }

  @override
  String get batchTakeoverClose => 'Fechar';

  @override
  String get installMoreTargets => 'Instale em mais locais';

  @override
  String get exportLocalSkill => 'Exportar';

  @override
  String get exportLocalSkillDescription =>
      'Exporte este Skill local como um arquivo ZIP portátil.';

  @override
  String get detailRepository => 'Repositório';

  @override
  String get detailStars => 'Estrelas';

  @override
  String get detailUpdated => 'Atualizado';

  @override
  String get detailArchiveSize => 'Tamanho ZIP';

  @override
  String get pathLabel => 'Caminho do projeto';

  @override
  String get copyProjectPath => 'Copiar caminho do projeto';

  @override
  String get projectPathCopied => 'Caminho do projeto copiado';

  @override
  String get onboardingWelcomeTitle => 'Bem-vindo ao SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Descubra, instale e gerencie Skills nos seus Agents e projetos.';

  @override
  String get onboardingDetectedAgents => 'Agents detectados';

  @override
  String get onboardingNoAgents =>
      'Nenhum Agent instalado foi detectado. Você ainda pode continuar.';

  @override
  String get onboardingNext => 'Próximo';

  @override
  String get onboardingProjectsTitle => 'Adicione seus projetos';

  @override
  String get onboardingProjectsDescription =>
      'Escolha os projetos que você deseja que o SkillsGo gerencie.';

  @override
  String get onboardingAddProject => 'Adicionar agora';

  @override
  String get onboardingAddProjectLater => 'ou mais tarde';

  @override
  String get onboardingStartUsing => 'Comece a usar SkillsGo';

  @override
  String get onboardingBack => 'Voltar';

  @override
  String get restartOnboardingTitle => 'Integração';

  @override
  String get restartOnboardingDescription =>
      'Visualize o guia de primeira inicialização novamente sem remover projetos, configurações ou dados Skills.';

  @override
  String get restartOnboardingAction => 'Reinicie a integração';

  @override
  String get restartOnboardingFailed =>
      'O SkillsGo não conseguiu reiniciar a configuração inicial.';

  @override
  String get libraryRefreshSettingsTitle => 'Atualizar biblioteca local';

  @override
  String get libraryRefreshSettingsDescription =>
      'Verifique novamente os Skills instalados, os projetos adicionados, os Agents e os Skills externos que podem ser gerenciados. Isso não instala, atualiza nem remove nada.';

  @override
  String get libraryRefreshSettingsAction => 'Atualizar biblioteca';

  @override
  String get libraryRefreshSettingsPending => 'Atualizando Biblioteca…';

  @override
  String get libraryRefreshSettingsSuccess => 'Biblioteca local atualizada.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo não pôde atualizar a biblioteca local.';

  @override
  String get onboardingProjectError =>
      'SkillsGo não pôde adicionar projetos deste diretório.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo não pôde carregar seus projetos adicionados.';

  @override
  String get onboardingStartupError =>
      'SkillsGo não pôde carregar a configuração.';

  @override
  String get onboardingStateError =>
      'SkillsGo não conseguiu salvar seu progresso de configuração. Tente novamente.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI precisa de atenção';

  @override
  String get onboardingCliErrorDescription =>
      'Repare o CLI incluído e tente continuar novamente.';
}
