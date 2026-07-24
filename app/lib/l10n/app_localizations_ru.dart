// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get discover => 'Откройте для себя';

  @override
  String get discoverSkills => 'Приятно узнать немного больше.';

  @override
  String get library => 'Библиотека';

  @override
  String get settings => 'Настройки';

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get cliNeedsAttention =>
      'Требуемый компонент SkillsGo требует внимания.';

  @override
  String get cliMissingBundled =>
      'Необходимый компонент SkillsGo отсутствует или не может запуститься. Переустановите SkillsGo, чтобы восстановить его.';

  @override
  String get cliDamagedBundled =>
      'Необходимый компонент SkillsGo поврежден. Переустановите SkillsGo, чтобы восстановить его.';

  @override
  String get cliIncompatibleBundled =>
      'Требуемый компонент SkillsGo не соответствует этой версии приложения. Обновите или переустановите SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Найдите навык для своего следующего шага.';

  @override
  String get skillsLeaderboard => 'Приятно узнать немного больше.';

  @override
  String searchResultsFor(String query) {
    return 'Результаты для «$query»';
  }

  @override
  String get searchSkills => 'Найдите навыки или вставьте ссылку Git…';

  @override
  String get search => 'Поиск';

  @override
  String get ranking => 'Рейтинг';

  @override
  String get trending => 'Тенденции';

  @override
  String get hot => 'Горячий';

  @override
  String get discoverNavigation => 'Откройте для себя навигацию';

  @override
  String get allTimeRanking => 'Рейтинг за все время';

  @override
  String get trendingNow => 'Тенденции за последние 24 часа';

  @override
  String get hotNow => 'Горячо сейчас';

  @override
  String get allTimeDescription =>
      'Публичный Skills отсортирован по количеству принятых установок за все время.';

  @override
  String get trendingDescription =>
      'Публичный Skills упорядочен по количеству принятых установок за последние 24 часа.';

  @override
  String get hotDescription =>
      'Публичный Skills упорядочен по краткосрочной скорости установки и изменениям.';

  @override
  String get offlineTitle => 'Не могу подключиться к SkillsGo';

  @override
  String get offlineMessage =>
      'Проверьте подключение к Интернету и повторите попытку. Если вы используете прокси-сервер или специальный адрес службы, проверьте его в настройках.';

  @override
  String get searchFailedTitle => 'Поиск наткнулся';

  @override
  String get validationTitle => 'Проверьте, что вы ввели';

  @override
  String get validationMessage =>
      'SkillsGo не смог использовать этот запрос. Проверьте введенные данные и повторите попытку.';

  @override
  String get serverTitle => 'Сервис временно недоступен';

  @override
  String get serverMessage =>
      'SkillsGo не может выполнить этот запрос прямо сейчас. Повторите попытку через минуту.';

  @override
  String get timeoutTitle => 'Это занимает слишком много времени';

  @override
  String get timeoutMessage =>
      'Служба не ответила вовремя. Проверьте подключение или повторите попытку.';

  @override
  String get invalidResponseTitle => 'SkillsGo нуждается в обновлении';

  @override
  String get invalidResponseMessage =>
      'Этот ответ не может быть прочитан вашей версией SkillsGo. Обновите приложение и повторите попытку.';

  @override
  String get invalidLocalDataTitle => 'Не могу прочитать установленный навык';

  @override
  String get invalidLocalDataMessage =>
      'Некоторая информация о локальной установке повреждена или несовместима. Обновите или переустановите SkillsGo, затем повторите попытку.';

  @override
  String get tryAgain => 'Попробуйте еще раз';

  @override
  String get searchEmptyTitle => 'Ищите, не прокручивайте.';

  @override
  String get searchEmptyMessage =>
      'Введите способность, источник или задачу для поиска общедоступных навыков.';

  @override
  String get noSkillsTitle => 'Навыки не найдены';

  @override
  String get noSkillsMessage =>
      'Попробуйте использовать более широкую фразу или проверьте написание.';

  @override
  String get focusSearch => 'Фокус поиска';

  @override
  String get skillsFromLink => 'Skills по этой ссылке';

  @override
  String skillCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skill',
      many: '$count Skill',
      few: '$count Skill',
      one: '$count Skill',
    );
    return '$_temp0';
  }

  @override
  String sourceResultsSummary(String source, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skill из $source',
      many: '$count Skill из $source',
      few: '$count Skill из $source',
      one: '$count Skill из $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Эта ссылка готова для проверки';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source нет в текущих результатах поиска. SkillsGo может проверить ссылку непосредственно на следующем шаге.';
  }

  @override
  String get inspectSource => 'Посмотреть навыки можно по этой ссылке';

  @override
  String get collectionEmptyTitle => 'В этой коллекции нет Skills.';

  @override
  String get collectionEmptyMessage =>
      'Здесь пока ничего нет. Повторите попытку после дальнейших действий по установке.';

  @override
  String get loadMore => 'Загрузить больше';

  @override
  String get install => 'Установить';

  @override
  String get installAll => 'Установить все навыки';

  @override
  String get latestCommit => 'Последний коммит';

  @override
  String get installToMoreTargets => 'Установить в других местах';

  @override
  String localTargets(int count) {
    return '$count локальные цели';
  }

  @override
  String allTimeMetric(String count) {
    return '$count количество установок за все время';
  }

  @override
  String trendingMetric(String count) {
    return '$count устанавливает / 24 часа';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value в этот час · $change';
  }

  @override
  String get trustUnverified => 'Непроверенный';

  @override
  String get trustCommunityVerified => 'Сообщество проверено';

  @override
  String get trustPublisherVerified => 'Издатель проверен';

  @override
  String get trustOfficial => 'Официальный';

  @override
  String get trustWarned => 'Предупреждён';

  @override
  String get trustDelisted => 'исключен из списка';

  @override
  String get riskUnknown => 'Риск неизвестен';

  @override
  String get riskLow => 'Низкий риск';

  @override
  String get riskMedium => 'Средний риск';

  @override
  String get riskHigh => 'Высокий риск';

  @override
  String get riskCritical => 'Критический риск';

  @override
  String openSkill(String name) {
    return 'Открыть $name';
  }

  @override
  String installs(String count) {
    return '$count устанавливает';
  }

  @override
  String get detailFailedTitle => 'Не удалось загрузить Skill.';

  @override
  String get detailLoading => 'Загрузка проверяемой детали Skill';

  @override
  String get artifactUnavailableTitle => 'Артефакт недоступен';

  @override
  String get artifactUnavailableMessage =>
      'Эта версия сейчас недоступна. Попробуйте еще раз или выберите другую версию.';

  @override
  String get detailInvalidTitle => 'Метаданные артефакта не поддерживаются';

  @override
  String get detailInvalidMessage =>
      'Некоторые сведения об этом навыке неполны или не могут быть прочитаны. Обновите SkillsGo и повторите попытку.';

  @override
  String get instructionsTab => 'Инструкции';

  @override
  String get manifestTab => 'Манифест';

  @override
  String immutableVersionLabel(String version) {
    return 'Неизменяемый $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Зафиксировать $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Дерево $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Содержимое $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Доверие издателя подтверждает право собственности или обслуживание; он не подтверждает безопасность артефактов. Для этой неизменяемой версии риск оценивается отдельно.';

  @override
  String get knownInstallationTargets => 'Известные цели установки';

  @override
  String get installationRange => 'Установленный объем';

  @override
  String get targetDetails => 'Показать сведения о цели';

  @override
  String get hideTargetDetails => 'Скрыть сведения о цели';

  @override
  String installedVersionLabel(String version) {
    return 'Версия $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Проект';

  @override
  String get fileContentUnavailable =>
      'Двоичный или недоступный предварительный просмотр';

  @override
  String get fileContentTruncated =>
      'Предварительный просмотр усечен до предела безопасности Hub.';

  @override
  String get retry => 'Повторить попытку';

  @override
  String get backToSearch => 'Вернуться к поиску';

  @override
  String get installForCodex => 'Установить для Codex';

  @override
  String get cliNotDetected => 'навыки (не обнаружено)';

  @override
  String get snapshotFiles => 'Файлы снимков';

  @override
  String get globalCodex => 'Глобальный · Codex';

  @override
  String get yourLibrary => 'Все, что вы знаете, здесь.';

  @override
  String get libraryNavigation => 'Навигация по библиотеке';

  @override
  String get all => 'Все';

  @override
  String get allSkills => 'Все Skills';

  @override
  String get updatesOnly => 'Обновления';

  @override
  String get allAgents => 'Все Agents';

  @override
  String get allProjects => 'Все проекты';

  @override
  String get specificProject => 'Проект';

  @override
  String get userScope => 'Глобальный';

  @override
  String get addProject => 'Добавить проект';

  @override
  String get relocateProject => 'Переместить';

  @override
  String get removeFromList => 'Удалить из списка';

  @override
  String removeProjectTitle(String name) {
    return 'Удалить $name из SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Будет удалена только ссылка на приложение. SkillsGo не будет изменять или удалять файлы в этом каталоге.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — недоступен';
  }

  @override
  String get emptyProjectTitle => 'Skills пока нет';

  @override
  String get browseSkills => 'Просмотр Skills';

  @override
  String get projectMissingTitle => 'Каталог проекта отсутствует';

  @override
  String get projectMissingMessage =>
      'Возможно, каталог был перемещен или его том отключен от сети. Переместите его или удалите только ссылку на его приложение.';

  @override
  String get projectPermissionTitle => 'Требуется разрешение проекта';

  @override
  String get projectPermissionMessage =>
      'SkillsGo не может проверить выбранный корень. Предоставьте доступ, переместив его через средство выбора каталога.';

  @override
  String get projectInaccessibleTitle => 'Каталог проекта недоступен';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo сохранил ссылку на этот проект. Проверьте путь или том, а затем переместите его.';

  @override
  String get checking => 'Проверка…';

  @override
  String get checkUpdates => 'Проверить обновления';

  @override
  String get refresh => 'Обновить';

  @override
  String get libraryUnavailable => 'Библиотека недоступна';

  @override
  String get libraryEmpty => 'Навыки еще не установлены';

  @override
  String get libraryEmptyMessage =>
      'Установите Skill из Discover, и он появится здесь.';

  @override
  String get searchLibrary => 'Поиск установленных навыков';

  @override
  String get libraryNoMatches => 'Нет соответствия Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Попробуйте другое имя, источник, Agent, проект или версию.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return '$count проекты';
  }

  @override
  String versionsSummary(int count) {
    return 'версии $count';
  }

  @override
  String get hubManaged => 'Hub управляемый';

  @override
  String get localManaged => 'Локальное управление';

  @override
  String get externalInstallation => 'Внешняя установка';

  @override
  String get readOnly => 'Только чтение';

  @override
  String get unversioned => 'Неверсированный';

  @override
  String get supportingFiles => 'Дополнительные файлы';

  @override
  String get versionDivergence => 'Расхождение версий';

  @override
  String get healthHealthy => 'Здоровый';

  @override
  String get healthMissing => 'Цель отсутствует';

  @override
  String get healthReplaced => 'Цель заменена';

  @override
  String get healthLocalModification => 'Локальная модификация';

  @override
  String get healthUnreadable => 'Цель нечитаема';

  @override
  String get healthUndeclared => 'Не заявлено';

  @override
  String get healthWorkspaceUnreadable => 'Состояние рабочей области нечитаемо';

  @override
  String get healthLockMismatch => 'Несоответствие блокировки';

  @override
  String get healthUnexpectedPath => 'Неожиданный целевой путь';

  @override
  String get modeExternal => 'Внешний';

  @override
  String get notLinked => 'НЕ СВЯЗАНО';

  @override
  String get update => 'Обновить';

  @override
  String get backToLibrary => 'Вернуться в библиотеку';

  @override
  String get remove => 'Удалить';

  @override
  String get manageTargets => 'Управление областью действия';

  @override
  String skillsSelected(int count) {
    return '$count выбрано';
  }

  @override
  String get clearSelection => 'Очистить выбор';

  @override
  String get selectCurrentResults => 'Выберите текущие результаты';

  @override
  String get clearCurrentResultSelection =>
      'Очистить текущий выбор результатов';

  @override
  String get manageTargetsTitle => 'Управление целями установки';

  @override
  String get manageTargetsDescription =>
      'Выберите точное действие для каждой цели. Невыбранные цели не изменятся.';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'Выбрано $selected из $total целей';
  }

  @override
  String get confirmRemoveTarget => 'Подтвердить удаление';

  @override
  String get applyTargetActions => 'Применить выбранные действия';

  @override
  String get managementProgressTitle => 'Применение целевых действий';

  @override
  String get managementResultsTitle => 'Целевые результаты действий';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded удалось, $failed не удалось.';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Выбранные действия проекта обновят skillsgo.yaml и skillsgo-lock.yaml.';

  @override
  String get targetContentPreserved =>
      'Текущий целевой контент будет сохранен.';

  @override
  String get localReadFailed => 'Не могу прочитать это Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo не удалось прочитать этот установленный Skill. Убедитесь, что папка существует и доступна, затем повторите попытку.';

  @override
  String get localConfiguration => 'НАВЫКИGO НАСТРОЙКИ';

  @override
  String get settingsNavigation => 'Навигация по настройкам';

  @override
  String get general => 'Персонализация';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Политика установки';

  @override
  String get storage => 'Хранение';

  @override
  String get colorScheme => 'Цветовая схема';

  @override
  String get about => 'О';

  @override
  String get colorSchemeInspectorTitle =>
      'Сгенерированные цветовые роли Material';

  @override
  String get skillsColorTokensTitle => 'Семантические цвета SkillsGo';

  @override
  String get skillsColorTokensDescription =>
      'Цвета продуктов созданы на основе Radix Sand и организованы с помощью семантики Primer, где Folder является специальной пространственной иерархией.';

  @override
  String get colorSchemeInspectorDescription =>
      'Предварительный просмотр каждого неустаревшего токена ColorScheme, сгенерированного из текущего начального числа. Щелкните цвет, чтобы скопировать его значение HEX.';

  @override
  String get colorSchemePairPreview => 'Семантические пары';

  @override
  String get colorSchemePairPreviewDescription =>
      'Роли переднего плана и фона визуализируются вместе, чтобы показать контраст и иерархию.';

  @override
  String get colorSchemeComponentPreview =>
      'Предварительный просмотр компонента';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Типичные элементы управления Material отображаются именно по этой схеме предварительного просмотра.';

  @override
  String get colorSchemeSampleTitle => 'Название карты Skill';

  @override
  String get colorSchemeSampleBody =>
      'Вторичная копия использует onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Скопировано';

  @override
  String get colorSchemeSampleGlyphs => 'Аа 123';

  @override
  String get colorSchemeGroupPrimary => 'Первичный';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Первичный акцент, контейнеры и фиксированные акцентные роли.';

  @override
  String get colorSchemeGroupSecondary => 'вторичный';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Поддерживающие акценты и фиксированные второстепенные роли.';

  @override
  String get colorSchemeGroupTertiary => 'Третичный';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Контрастные акценты и фиксированные третичные роли.';

  @override
  String get colorSchemeGroupSurface => 'Поверхность';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Иерархия страницы, контейнера, высоты и переднего плана.';

  @override
  String get colorSchemeGroupUtility => 'Схема и полезность';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Границы, тени, сетки и обратные поверхности.';

  @override
  String get colorSchemeGroupError => 'Ошибка';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Действия, сообщения и контейнеры при ошибках.';

  @override
  String get colorSchemeUsagePrimary => 'Основные действия, фокус и акценты.';

  @override
  String get colorSchemeUsageSecondary =>
      'Вспомогательные действия и акценты средней выразительности.';

  @override
  String get colorSchemeUsageTertiary =>
      'Контрастные акценты, дополняющие основное и второстепенное.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Текст и значки отображаются на $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Контейнер $family с нижним выделением для выделений и акцентов.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Независимый от яркости фиксированный контейнер $family.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Затемненный, независимый от яркости фиксированный контейнер $family.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Выделенный контент в фиксированном контейнере $family.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Содержимое с меньшим акцентом в фиксированном контейнере $family.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Базовая страница и большая область поверхности.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Затемненная базовая поверхность используется с самым темным тоном поверхности.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Яркая базовая поверхность, используемая в самом светлом тоне поверхности.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'Высота надводного контейнера $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'самый низкий';

  @override
  String get colorSchemeElevationLow => 'низкий';

  @override
  String get colorSchemeElevationDefault => 'по умолчанию';

  @override
  String get colorSchemeElevationHigh => 'высокий';

  @override
  String get colorSchemeElevationHighest => 'самый высокий';

  @override
  String get colorSchemeUsageOnSurface =>
      'Основной текст и значки, отображаемые на поверхностях.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Вторичный текст, надписи и приглушенные значки на поверхностях.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Оттенок высоты Material получен из основного.';

  @override
  String get colorSchemeUsageOutline =>
      'Выраженные границы и четкие очертания компонентов.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Тонкие границы, разделители и контуры с низким акцентом.';

  @override
  String get colorSchemeUsageShadow =>
      'Цвет тени для приподнятых поверхностей.';

  @override
  String get colorSchemeUsageScrim =>
      'Модальное наложение используется для приглушения фонового содержимого.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Поверхность с перевернутыми светлыми и темными акцентами.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Основной акцент отображается на обратной поверхности.';

  @override
  String get colorSchemeUsageError =>
      'Действия при ошибках, статус и обратная связь.';

  @override
  String get save => 'Сохранить';

  @override
  String get advancedSettings => 'Расширенный';

  @override
  String get remindersSettings => 'Напоминания';

  @override
  String get remindersSettingsTitle => 'Настройки напоминаний';

  @override
  String get remindersSettingsDescription =>
      'Выберите, какие напоминания получать.';

  @override
  String get updateReminderTitle => 'Обновить напоминания';

  @override
  String get updateReminderDescription =>
      'Проверьте наличие обновлений, когда откроется библиотека.';

  @override
  String get securityReminderTitle => 'Оповещения о высоком риске';

  @override
  String get securityReminderDescription =>
      'Уведомлять вас о новых высоких или критических рисках в установленных навыках.';

  @override
  String availableUpdatesReminder(int count) {
    return 'Установленные навыки $count имеют обновления.';
  }

  @override
  String get openAvailableUpdates =>
      'Откройте представление доступных обновлений, чтобы просмотреть и обновить их.';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'Установленные навыки $count требуют проверки безопасности';
  }

  @override
  String get reviewInstalledSkills =>
      'Просмотрите информацию о рисках, прежде чем использовать или обновлять ее.';

  @override
  String get generalSettingsTitle => 'Сделайте SkillsGo своим';

  @override
  String get generalSettingsDescription =>
      'Интерфейс соответствует языку вашей системы, доступности и предпочтениям движения.';

  @override
  String get agentsSettingsTitle => 'Среда выполнения Agent';

  @override
  String get hubSettingsTitle => 'Hub Происхождение';

  @override
  String get hubSettingsDescription =>
      'Используйте официальный Hub или самостоятельный источник HTTP(S), который реализует тот же протокол SkillsGo.';

  @override
  String get testConnection => 'Тестовое соединение';

  @override
  String get saveOrigin => 'Сохранить происхождение';

  @override
  String get resetDefault => 'Сбросить настройки по умолчанию';

  @override
  String get connectionReady => 'Подключение готово';

  @override
  String get connectionFailed => 'Соединение не удалось';

  @override
  String get hubInvalidOrigin =>
      'Введите действительный источник HTTP(S) без учетных данных, запроса или фрагмента.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub вернул HTTP $status. Проверьте Origin и конфигурацию сервера.';
  }

  @override
  String get hubInvalidProtocol =>
      'Сервер не вернул протокол поиска SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Hub вернул неверный JSON.';

  @override
  String get hubConnectionFailure =>
      'Не удалось связаться с Hub. Проверьте источник, сеть, прокси и конфигурацию TLS.';

  @override
  String get hubConnectionTimeout =>
      'Время ожидания соединения Hub истекло. Проверьте сеть или повторите попытку.';

  @override
  String get riskPolicyTitle => 'Политика личного риска';

  @override
  String get riskPolicyDescription =>
      'Правила безопасности применяются при установке или обновлении навыка.';

  @override
  String get confirmHighRisk => 'Требовать подтверждения для высокого риска';

  @override
  String get confirmHighRiskDescription =>
      'Артефакты высокого риска всегда требуют дополнительного подтверждения перед установкой.';

  @override
  String get allowCriticalOverride =>
      'Разрешить явное переопределение критического риска';

  @override
  String get allowCriticalOverrideDescription =>
      'Артефакты критического риска остаются заблокированными по умолчанию. Включите это только для того, чтобы предоставить отдельное ручное переопределение.';

  @override
  String get storageHealthy => 'Читабельный';

  @override
  String get storageNotInitialized => 'Не инициализирован';

  @override
  String get storageUnavailable => 'Недоступно';

  @override
  String get storageInvalidResponse =>
      'Входящий в комплект CLI вернул неподдерживаемый диагностический ответ.';

  @override
  String get aboutSettingsTitle => 'Совместимость продукта';

  @override
  String get appVersion => 'Версия приложения';

  @override
  String get cliVersion => 'Комплектная версия CLI';

  @override
  String get compatible => 'Совместимый';

  @override
  String get hubOriginSaved => 'Hub Origin сохранен и применен.';

  @override
  String get policySaved => 'Политика установки сохранена.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'ГОТОВО';

  @override
  String get unknown => 'НЕИЗВЕСТНО';

  @override
  String get missing => 'ОТСУТСТВУЕТ';

  @override
  String get incompatible => 'НЕСОВМЕСТИМЫЙ';

  @override
  String get detecting => 'Обнаружение…';

  @override
  String get customCliPath => 'Пользовательский путь к исполняемому файлу';

  @override
  String get saveAndDetect => 'Сохранить и обнаружить';

  @override
  String get detectAgain => 'Обнаружить снова';

  @override
  String get agentInstalled => 'Установлено';

  @override
  String get agentSupported => 'Поддерживается';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return '$installed установлен · $supported поддерживается';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Установлено · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Не установлено · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Поддерживается SkillsGo, но не обнаружен на этом Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Skill Пути загрузки: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Данные обнаружения Agent недоступны. Запустите обнаружение еще раз.';

  @override
  String get noInstalledAgentsTitle => 'Установленный Agents не обнаружен';

  @override
  String get noInstalledAgentsMessage =>
      'Вы можете продолжать просматривать этот Skill, но цели для установки пока нет. Установите поддерживаемый Agent, затем снова запустите обнаружение.';

  @override
  String get clearCustomPath => 'Очистить собственный путь';

  @override
  String get privacyProvenance => 'Конфиденциальность и происхождение';

  @override
  String get privacySummary =>
      'Ваши поисковые запросы не сохраняются, а SkillsGo не ведет журналы команд.';

  @override
  String get language => 'Язык';

  @override
  String get personalizationTheme => 'Тема';

  @override
  String get folderColorTheme => 'Цвет темы';

  @override
  String get folderColorThemeDescription =>
      'Выберите цвет, который вам нравится. SkillsGo построит вокруг него согласованную палитру интерфейса.';

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
  String get appearanceMode => 'Режим';

  @override
  String get appearanceModeDescription =>
      'Следите за внешним видом вашей системы или всегда используйте светлую или темную тему.';

  @override
  String get followSystem => 'Система';

  @override
  String get lightMode => 'Свет';

  @override
  String get darkMode => 'Темный';

  @override
  String get wallpaper => 'Обои';

  @override
  String get wallpaperDescription =>
      'Выберите небесный фон. Ваш выбор появится сразу за Folder.';

  @override
  String get wallpaperSun => 'Солнце';

  @override
  String get wallpaperMercury => 'Меркурий';

  @override
  String get wallpaperVenus => 'Венера';

  @override
  String get wallpaperEarth => 'Земля';

  @override
  String get wallpaperMars => 'Марс';

  @override
  String get wallpaperJupiter => 'Юпитер';

  @override
  String get wallpaperSaturn => 'Сатурн';

  @override
  String get wallpaperUranus => 'Уран';

  @override
  String get wallpaperNeptune => 'Нептун';

  @override
  String get wallpaperPluto => 'Плутон';

  @override
  String get wallpaperMoon => 'Луна';

  @override
  String folderThemeChoice(String theme) {
    return '$theme Folder тема';
  }

  @override
  String get privacyAffiliation =>
      'Телеметрия анонимной установки контролируется настройками SkillsGo. SkillsGo не связан с OpenAI или Codex.';

  @override
  String get commandCompleted => 'Команда выполнена';

  @override
  String get commandFailed => 'Команда не выполнена';

  @override
  String commandExit(int code) {
    return 'Выход $code · разверните журнал этого сеанса';
  }

  @override
  String get command => 'Команда';

  @override
  String get cancel => 'Отмена';

  @override
  String get updateUnknown => 'НЕИЗВЕСТНО';

  @override
  String get updateChecking => 'ПРОВЕРКА';

  @override
  String get upToDate => 'АКТУАЛЬНО';

  @override
  String get updateAvailable => 'ОБНОВЛЕНИЕ';

  @override
  String get updateUnavailable => 'НЕДОСТУПНО';

  @override
  String get updateCheckFailed => 'ПРОВЕРКА НЕ удалась';

  @override
  String get installSkill => 'Установить Skill';

  @override
  String get installLocationTitle => 'Установить место установки';

  @override
  String get userLevel => 'Уровень пользователя';

  @override
  String get projectLevel => 'Уровень проекта';

  @override
  String get projects => 'Проекты';

  @override
  String get loading => 'Загрузка…';

  @override
  String get repositoryParsing => 'Разбор репозитория…';

  @override
  String userInstallSummary(int agents) {
    return 'Доступно для $agents Agents на уровне пользователя.';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects проекты · $agents Agents';
  }

  @override
  String get installationResults => 'Результаты установки';

  @override
  String get installationInProgress => 'Установка в процессе';

  @override
  String get installationSucceeded => 'Установка завершена';

  @override
  String get installationSucceededMessage =>
      'Skill теперь доступен в выбранных местах.';

  @override
  String get projectUnavailable => 'Проект недоступен';

  @override
  String get installedCell => 'Установлено';

  @override
  String get unsupportedCell => 'Недоступно';

  @override
  String get confirmInstall => 'Подтвердить установку';

  @override
  String installAllRepositorySkills(int count) {
    return 'Установите все навыки репозитория ($count)';
  }

  @override
  String get installAllSkillsTo => 'Установите все навыки, чтобы';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Установите все навыки $repository ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Установите $skill в';
  }

  @override
  String get availableInAllProjects => 'Все проекты';

  @override
  String get availableInSelectedProjects => 'Избранные проекты';

  @override
  String get usedBy => 'Для Agents';

  @override
  String get backToTargets => 'Вернуться к целям';

  @override
  String get stayHere => 'Оставайся здесь';

  @override
  String get viewInLibrary => 'Посмотреть в библиотеке';

  @override
  String planCreateCount(int count) {
    return '$count создать';
  }

  @override
  String planSkipCount(int count) {
    return '$count пропустить';
  }

  @override
  String planReplaceCount(int count) {
    return '$count заменить';
  }

  @override
  String planConflictCount(int count) {
    return '$count конфликт';
  }

  @override
  String planRiskCount(int count) {
    return 'Риск $count заблокирован';
  }

  @override
  String get refreshInstallationPlan => 'Применить разрешения';

  @override
  String get replaceVersionConflict =>
      'Замените установленную версию на этой цели.';

  @override
  String get replaceSkillIdCollision =>
      'Замените другой идентификатор Skill в этой цели.';

  @override
  String get replaceLocalModification =>
      'Отменить локальные модификации и заменить эту цель';

  @override
  String get sharedTargetConflict =>
      'Этот путь используется другими целями Agent.';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Вернитесь к целевой матрице и выберите каждый затронутый Agent перед заменой: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Замените конфликтующую цель';

  @override
  String get confirmHighRiskArtifact =>
      'Подтверждение артефакта высокого риска';

  @override
  String get confirmCriticalRiskArtifact =>
      'Подтверждение отмены критического риска';

  @override
  String get confirmRiskForSelectedTargets =>
      'Я проверил файлы артефактов и принимаю этот риск для выбранных целей.';

  @override
  String get criticalRiskBlocked =>
      'Установка критического риска заблокирована';

  @override
  String get criticalRiskOverrideDisabled =>
      'Включите явное переопределение критического риска в настройках, прежде чем этот план сможет продолжиться.';

  @override
  String get workspaceManifestChanges => 'Изменения Workspace Manifest';

  @override
  String get noWorkspaceManifestChanges =>
      'Никакие файлы Workspace Manifest не изменятся.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'нет';

  @override
  String get planActionCreate => 'Создать';

  @override
  String get planActionReplace => 'Заменить';

  @override
  String get planActionSkip => 'Пропустить';

  @override
  String get planActionConflict => 'Конфликт';

  @override
  String get planActionBlockedByRisk => 'Заблокировано из-за риска';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'Цели $succeeded установлены, $failed не работает.';
  }

  @override
  String get installationProgressTitle => 'Установка в процессе';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished из $total целей завершен';
  }

  @override
  String get targetWaiting => 'Ожидание';

  @override
  String get targetRunning => 'Установка';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Повторить $count неудачной цели',
      many: 'Повторить $count неудачных целей',
      few: 'Повторить $count неудачные цели',
      one: 'Повторить $count неудачную цель',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Выберите цели для обновления';

  @override
  String get updatePlanDescription =>
      'Выберите точные цели установки. Невыбранный Agents и проекты остаются без изменений.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return 'Выбран $selected из обновляемых целей $available.';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Ссылка на источник: $reference';
  }

  @override
  String get fixedVersionTarget => 'Закреплено — нет перемещаемой ссылки';

  @override
  String get currentVersionTarget => 'Актуально';

  @override
  String get updateCheckTargetFailed => 'Проверка обновлений не удалась';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Восстановить манифест рабочей области';

  @override
  String get updateSelectedTargets => 'Обновить выбранные цели';

  @override
  String get updateProgressTitle => 'Обновление целей';

  @override
  String get updateResultsTitle => 'Обновить результаты';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished из $total целей завершен';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Повторить $count неудачного обновления',
      many: 'Повторить $count неудачных обновлений',
      few: 'Повторить $count неудачных обновления',
      one: 'Повторить $count неудачное обновление',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Ни для одной выбранной цели нет доступных обновлений.';

  @override
  String get closeUpdatePlan => 'Закрыть';

  @override
  String get targetSucceeded => 'Установлено';

  @override
  String get targetSkipped => 'Пропущено';

  @override
  String get targetConflict => 'Конфликт';

  @override
  String get targetFailed => 'Не удалось';

  @override
  String get targetFailureRetryable =>
      'Это местоположение невозможно изменить. Вы можете попробовать еще раз.';

  @override
  String get targetFailureNeedsAttention =>
      'Прежде чем повторить попытку, это место требует вашего внимания.';

  @override
  String get installationTargetFailureMessage =>
      'В этом месте ничего не менялось. Убедитесь, что папка доступна, и повторите попытку.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Ничего не менялось, потому что SkillsGo не смог сохранить настройки проекта. Убедитесь, что папка проекта доступна для записи, и повторите попытку.';

  @override
  String get installationStateChangedMessage =>
      'Местоположение изменилось, пока вы его просматривали. Прежде чем повторить попытку, просмотрите последнее состояние.';

  @override
  String get updateTargetFailureMessage =>
      'Не удалось обновить это местоположение. Другие местоположения не были затронуты, поэтому вы можете повторить попытку только для этого.';

  @override
  String get managementTargetFailureMessage =>
      'Это действие не может быть выполнено здесь. Другие местоположения не были затронуты, поэтому вы можете повторить попытку только для этого.';

  @override
  String get technicalDetails => 'Технические детали';

  @override
  String get targetPathExists =>
      'По этому адресу уже существует другой предмет.';

  @override
  String get targetBlockedByRisk =>
      'Ваши текущие настройки безопасности заблокировали установку в этом месте.';

  @override
  String get targetInstallFailed =>
      'Навык не может быть установлен в этом месте.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Навык установился, но настройки проекта обновить не удалось.';

  @override
  String get installationPlanFailed =>
      'План установки не может быть продолжен.';

  @override
  String get installationFailed => 'Установка не может быть завершена';

  @override
  String get localSource => 'Местный источник';

  @override
  String get noDescriptionAvailable => 'Нет описания';

  @override
  String moreCoverage(int count) {
    return '+$count больше локаций';
  }

  @override
  String get batchTakeoverAction => 'Управляйте существующими навыками';

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
    return 'Управление ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Проверка имеющихся навыков…';

  @override
  String get batchTakeoverRetry => 'Еще раз проверьте управляемые навыки';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count можно управлять';
  }

  @override
  String get batchTakeoverPending => 'Добавляем навыки управления…';

  @override
  String get batchTakeoverTitle =>
      'Управлять имеющимися навыками с помощью SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo добавит локальные записи управления без перемещения, перезаписи или загрузки файлов навыков. Неподдерживаемые или измененные элементы будут пропущены.';

  @override
  String get batchTakeoverStoryTitle =>
      'Превратите разбросанные навыки в одну понятную библиотеку';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count существующего Skill',
      many: '$count существующих Skill',
      few: '$count существующих Skill',
      one: '$count существующий Skill',
    );
    return 'SkillsGo обнаружил здесь $_temp0, которыми можно управлять.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Перед руководством неясно, где установлены существующие навыки, актуальны ли они, как их восстановить и используют ли проекты одну и ту же версию.';

  @override
  String get batchTakeoverPainLocation => 'Неизвестное место установки';

  @override
  String get batchTakeoverPainFreshness => 'Неизвестный статус обновления';

  @override
  String get batchTakeoverPainRecovery => 'Нет восстановления при поломке';

  @override
  String get batchTakeoverPainVersionDrift =>
      'Различные версии в разных проектах';

  @override
  String get batchTakeoverFolderTitle => 'Существующий Skills';

  @override
  String get batchTakeoverFolderSubtitle => 'Непонятный статус';

  @override
  String get batchTakeoverAfterLabel => 'ПОСЛЕ';

  @override
  String get batchTakeoverAfterTitle => 'Одна чистая библиотека';

  @override
  String get batchTakeoverLibraryTitle => 'Библиотека SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Очистить локации';

  @override
  String get batchTakeoverBenefitFreshness => 'Обновления видны';

  @override
  String get batchTakeoverBenefitRecovery => 'Легкое восстановление';

  @override
  String get batchTakeoverBenefitVersions => 'Версии очищены';

  @override
  String get batchTakeoverManagedSection => 'Управляется SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'Ожидается';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name управляется SkillsGo.';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name не удалось добавить в управление.';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name ожидает управления';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skill упорядочено',
      many: '$count Skill упорядочены',
      few: '$count Skill упорядочены',
      one: '$count Skill упорядочен',
    );
    return 'После добавления $_temp0 в единой Library с понятным статусом управления.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count ещё';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Добавьте эти существующие навыки к управлению SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ОРГАНИЗОВАТЬ';

  @override
  String get batchTakeoverStatusTitle => 'Статус управления';

  @override
  String get batchTakeoverStatusManaged => 'Управляемый';

  @override
  String get batchTakeoverStatusProgress => 'Организация';

  @override
  String get batchTakeoverStatusSkipped => 'Пропущено';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Файлы Skill остаются в исходных местах.';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills располагаются в полные строки и записываются SkillsGo без перемещения их файлов.';

  @override
  String get batchTakeoverBoardComplete => 'ВСЕ ЧИСТО';

  @override
  String get batchTakeoverBoardPartial => 'ПОЛНЫЙ';

  @override
  String get batchTakeoverStatusTotal => 'Итого';

  @override
  String get batchTakeoverQueueComplete => 'Никакие навыки не ждут';

  @override
  String get batchTakeoverQueueWaiting =>
      'После проверки Skills появятся здесь';

  @override
  String get batchTakeoverNextLabel => 'СЛЕДУЮЩИЙ';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count блока-органайзера SkillsGo',
      many: '$count блоков-органайзеров SkillsGo',
      few: '$count блока-органайзера SkillsGo',
      one: '$count блок-органайзер SkillsGo',
    );
    return '$_temp0 завершают последние строки.';
  }

  @override
  String get batchTakeoverPreservation =>
      'Ваши файлы, пути и текущие рабочие процессы остаются там, где они есть. SkillsGo только заполняет свои локальные записи управления.';

  @override
  String get batchTakeoverLaterHint =>
      'Если вы пропустите этот раздел, вы сможете в любое время воспользоваться функцией «Управление существующими навыками из библиотеки».';

  @override
  String get batchTakeoverSkip => 'Не сейчас';

  @override
  String get batchTakeoverConfirm => 'Добавить в управление';

  @override
  String get batchTakeoverExecutionRetry => 'Повторить попытку';

  @override
  String get batchTakeoverResultTitle => 'Skills добавлен в управление';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return 'Навыки $takenOver добавлены в управление, $skipped пропущены.';
  }

  @override
  String get batchTakeoverClose => 'Закрыть';

  @override
  String get installMoreTargets => 'Установить в большем количестве мест';

  @override
  String get detailRepository => 'Репозиторий';

  @override
  String get detailStars => 'Звезды';

  @override
  String get detailUpdated => 'Обновлено';

  @override
  String get detailArchiveSize => 'Размер ZIP';

  @override
  String get pathLabel => 'Путь проекта';

  @override
  String get copyProjectPath => 'Скопировать путь проекта';

  @override
  String get projectPathCopied => 'Путь к проекту скопирован.';

  @override
  String get onboardingWelcomeTitle => 'Добро пожаловать в SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Находите, устанавливайте и управляйте Skills в Agents и проектах.';

  @override
  String get onboardingDetectedAgents => 'Обнаруженные Agents';

  @override
  String get onboardingNoAgents =>
      'Установленные Agents не обнаружены. Продолжить всё равно можно.';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingProjectsTitle => 'Добавляйте свои проекты';

  @override
  String get onboardingProjectsDescription =>
      'Выберите проекты, которыми будет управлять SkillsGo.';

  @override
  String get onboardingAddProject => 'Добавить сейчас';

  @override
  String get onboardingAddProjectLater => 'или позже';

  @override
  String get onboardingStartUsing => 'Начните использовать SkillsGo';

  @override
  String get onboardingBack => 'Назад';

  @override
  String get restartOnboardingTitle => 'Регистрация';

  @override
  String get restartOnboardingDescription =>
      'Просмотрите руководство по первому запуску еще раз, не удаляя проекты, настройки или данные Skills.';

  @override
  String get restartOnboardingAction => 'Перезапустить регистрацию';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo не удалось перезапустить первоначальную настройку.';

  @override
  String get libraryRefreshSettingsTitle => 'Обновить местную библиотеку';

  @override
  String get libraryRefreshSettingsDescription =>
      'Повторно просканируйте установленный Skills, добавленные проекты, Agents и внешний Skills, которым можно управлять. При этом ничего не устанавливается, не обновляется и не удаляется.';

  @override
  String get libraryRefreshSettingsAction => 'Обновить библиотеку';

  @override
  String get libraryRefreshSettingsPending => 'Обновление библиотеки…';

  @override
  String get libraryRefreshSettingsSuccess => 'Обновлена местная библиотека.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo не удалось обновить локальную библиотеку.';

  @override
  String get onboardingProjectError =>
      'SkillsGo не удалось добавить проекты из этого каталога.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo не удалось загрузить добавленные вами проекты.';

  @override
  String get onboardingStartupError =>
      'SkillsGo не удалось загрузить настройку.';

  @override
  String get onboardingStateError =>
      'SkillsGo не удалось сохранить ход установки. Попробуйте еще раз.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI требует внимания';

  @override
  String get onboardingCliErrorDescription =>
      'Восстановите прилагаемый CLI, затем повторите попытку, чтобы продолжить.';
}
