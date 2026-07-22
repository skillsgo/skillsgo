// ignore_for_file: text_direction_code_point_in_literal, text_direction_code_point_in_comment

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get discover => 'Відкрийте для себе';

  @override
  String get discoverSkills => 'Приємно знати трохи більше.';

  @override
  String get library => 'Бібліотека';

  @override
  String get settings => 'Налаштування';

  @override
  String get openSettings => 'Відкрийте налаштування';

  @override
  String get cliNeedsAttention =>
      'Необхідний компонент SkillsGo потребує уваги.';

  @override
  String get cliMissingBundled =>
      'Потрібний компонент SkillsGo відсутній або не запускається. Перевстановіть SkillsGo, щоб відновити його.';

  @override
  String get cliDamagedBundled =>
      'Потрібний компонент SkillsGo пошкоджено. Перевстановіть SkillsGo, щоб відновити його.';

  @override
  String get cliIncompatibleBundled =>
      'Необхідний компонент SkillsGo не відповідає цій версії програми. Оновіть або перевстановіть SkillsGo.';

  @override
  String get officialIndex => 'SkillsGo Hub';

  @override
  String get discoverTitle => 'Знайдіть навик для свого наступного кроку.';

  @override
  String get skillsLeaderboard => 'Приємно знати трохи більше.';

  @override
  String searchResultsFor(String query) {
    return 'Результати для “$query”';
  }

  @override
  String get searchSkills => 'Шукайте навички або вставте посилання Git…';

  @override
  String get search => 'Пошук';

  @override
  String get ranking => 'Рейтинг';

  @override
  String get trending => 'В тренді';

  @override
  String get hot => 'Гаряче';

  @override
  String get discoverNavigation => 'Відкрийте для себе навігацію';

  @override
  String get allTimeRanking => 'Рейтинг за весь час';

  @override
  String get trendingNow => 'Популярні за останні 24 години';

  @override
  String get hotNow => 'Гаряче прямо зараз';

  @override
  String get allTimeDescription =>
      'Загальнодоступний Skills, упорядкований за прийнятими встановленнями за весь час.';

  @override
  String get trendingDescription =>
      'Загальнодоступний Skills, упорядкований за прийнятими встановленнями протягом останнього 24-годинного вікна.';

  @override
  String get hotDescription =>
      'Загальнодоступний Skills, упорядкований за швидкістю короткочасного встановлення та зміною.';

  @override
  String get offlineTitle => 'Не вдається підключитися до SkillsGo';

  @override
  String get offlineMessage =>
      'Перевірте підключення до Інтернету та повторіть спробу. Якщо ви використовуєте проксі-сервер або спеціальну адресу служби, перегляньте її в налаштуваннях.';

  @override
  String get searchFailedTitle => 'Пошук спіткнувся';

  @override
  String get validationTitle => 'Перевірте, що ви ввели';

  @override
  String get validationMessage =>
      'SkillsGo не зміг скористатися цим запитом. Перегляньте введене та повторіть спробу.';

  @override
  String get serverTitle => 'Послуга тимчасово недоступна';

  @override
  String get serverMessage =>
      'SkillsGo зараз не може виконати цей запит. Повторіть спробу за мить.';

  @override
  String get timeoutTitle => 'Це триває надто довго';

  @override
  String get timeoutMessage =>
      'Служба не відповіла вчасно. Перевірте підключення або повторіть спробу.';

  @override
  String get invalidResponseTitle => 'SkillsGo потребує оновлення';

  @override
  String get invalidResponseMessage =>
      'Ця відповідь не може бути прочитана вашою версією SkillsGo. Оновіть додаток і повторіть спробу.';

  @override
  String get invalidLocalDataTitle =>
      'Не вдається прочитати встановлений навик';

  @override
  String get invalidLocalDataMessage =>
      'Деякі відомості про локальне встановлення пошкоджені або несумісні. Оновіть або перевстановіть SkillsGo, а потім повторіть спробу.';

  @override
  String get tryAgain => 'Спробуйте знову';

  @override
  String get searchEmptyTitle => 'Шукайте, не прокручуйте.';

  @override
  String get searchEmptyMessage =>
      'Введіть можливість, джерело або завдання для пошуку публічних навичок.';

  @override
  String get noSkillsTitle => 'Навички не знайдено';

  @override
  String get noSkillsMessage => 'Спробуйте ширшу фразу або перевірте правопис.';

  @override
  String get focusSearch => 'Пошук по фокусу';

  @override
  String get skillsFromLink => 'Skills за цим посиланням';

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
      other: '$count Skill із $source',
      many: '$count Skill із $source',
      few: '$count Skill із $source',
      one: '$count Skill із $source',
    );
    return '$_temp0';
  }

  @override
  String get sourceSearchEmptyTitle => 'Це посилання готове до перевірки';

  @override
  String sourceSearchEmptyMessage(String source) {
    return '$source немає в поточних результатах пошуку. SkillsGo може перевірити посилання безпосередньо на наступному кроці.';
  }

  @override
  String get inspectSource => 'Перегляньте навички за цим посиланням';

  @override
  String get collectionEmptyTitle => 'У цій колекції немає Skills';

  @override
  String get collectionEmptyMessage =>
      'Тут ще нічого немає. Повторіть спробу після встановлення.';

  @override
  String get loadMore => 'Завантажте більше';

  @override
  String get install => 'встановити';

  @override
  String get installAll => 'Встановити всі навички';

  @override
  String get latestCommit => 'Останній комміт';

  @override
  String get installToMoreTargets => 'Встановити в інших місцях';

  @override
  String localTargets(int count) {
    return '$count локальні цілі';
  }

  @override
  String allTimeMetric(String count) {
    return '$count встановлень за весь час';
  }

  @override
  String trendingMetric(String count) {
    return '$count встановлюється / 24 год';
  }

  @override
  String hotMetric(String value, String change) {
    return '$value цієї години · $change';
  }

  @override
  String get trustUnverified => 'Неперевірений';

  @override
  String get trustCommunityVerified => 'Перевірено спільнотою';

  @override
  String get trustPublisherVerified => 'Видавець перевірений';

  @override
  String get trustOfficial => 'Офіційний';

  @override
  String get trustWarned => 'Попереджений';

  @override
  String get trustDelisted => 'Вилучено зі списку';

  @override
  String get riskUnknown => 'Ризик невідомий';

  @override
  String get riskLow => 'Низький ризик';

  @override
  String get riskMedium => 'Середній ризик';

  @override
  String get riskHigh => 'Високий ризик';

  @override
  String get riskCritical => 'Критичний ризик';

  @override
  String openSkill(String name) {
    return 'Відкрийте $name';
  }

  @override
  String installs(String count) {
    return 'Встановлюється $count';
  }

  @override
  String get detailFailedTitle => 'Не вдалося завантажити цей Skill';

  @override
  String get detailLoading => 'Завантаження перевірених деталей Skill';

  @override
  String get artifactUnavailableTitle => 'Артефакт недоступний';

  @override
  String get artifactUnavailableMessage =>
      'Ця версія зараз недоступна. Повторіть спробу або виберіть іншу версію.';

  @override
  String get detailInvalidTitle => 'Метадані артефакту не підтримуються';

  @override
  String get detailInvalidMessage =>
      'Деякі деталі цієї навички неповні або їх неможливо прочитати. Оновіть SkillsGo і повторіть спробу.';

  @override
  String get instructionsTab => 'Інструкції';

  @override
  String get manifestTab => 'Маніфест';

  @override
  String immutableVersionLabel(String version) {
    return 'Незмінний $version';
  }

  @override
  String commitIdentity(String sha) {
    return 'Здійснити $sha';
  }

  @override
  String treeIdentity(String sha) {
    return 'Дерево $sha';
  }

  @override
  String contentIdentity(String digest) {
    return 'Вміст $digest';
  }

  @override
  String get trustDoesNotProveSafety =>
      'Довіра видавця підтверджує право власності чи обслуговування; це не засвідчує безпеку артефакту. Ризик оцінюється окремо для цієї незмінної версії.';

  @override
  String get knownInstallationTargets => 'Відомі цілі установки';

  @override
  String get installationRange => 'Встановлений приціл';

  @override
  String get targetDetails => 'Показати деталі мети';

  @override
  String get hideTargetDetails => 'Приховати цільові деталі';

  @override
  String installedVersionLabel(String version) {
    return 'Версія $version';
  }

  @override
  String targetSummary(String scope, String agent, String version) {
    return '$scope / $agent · $version';
  }

  @override
  String get projectScope => 'Проект';

  @override
  String get fileContentUnavailable =>
      'Двійковий або недоступний попередній перегляд';

  @override
  String get fileContentTruncated =>
      'Попередній перегляд скорочено обмеженням безпеки Hub.';

  @override
  String get retry => 'Повторіть спробу';

  @override
  String get backToSearch => 'Назад до пошуку';

  @override
  String get installForCodex => 'Встановити для Codex';

  @override
  String get cliNotDetected => 'навички (не виявлено)';

  @override
  String get snapshotFiles => 'Файли знімків';

  @override
  String get globalCodex => 'Глобальний · Codex';

  @override
  String get yourLibrary => 'Усе, що ви знаєте, тут.';

  @override
  String get libraryNavigation => 'Навігація по бібліотеці';

  @override
  String get all => 'все';

  @override
  String get allSkills => 'Всі Skills';

  @override
  String get updatesOnly => 'Оновлення';

  @override
  String get allAgents => 'Всі Agents';

  @override
  String get allProjects => 'Всі проекти';

  @override
  String get specificProject => 'Проект';

  @override
  String get userScope => 'Глобальний';

  @override
  String get addProject => 'Додати проект';

  @override
  String get relocateProject => 'Переїзд';

  @override
  String get removeFromList => 'Видалити зі списку';

  @override
  String removeProjectTitle(String name) {
    return 'Видалити $name з SkillsGo?';
  }

  @override
  String get removeProjectDescription =>
      'Буде видалено лише посилання на додаток. SkillsGo не змінюватиме та не видалятиме жодних файлів у цьому каталозі.';

  @override
  String projectRailUnavailable(String name) {
    return '$name — недоступний';
  }

  @override
  String get emptyProjectTitle => 'Ще немає Skills';

  @override
  String get browseSkills => 'Перегляньте Skills';

  @override
  String get projectMissingTitle => 'Відсутній каталог проекту';

  @override
  String get projectMissingMessage =>
      'Можливо, каталог переміщено або його том не в мережі. Перемістіть його або видаліть лише посилання на додаток.';

  @override
  String get projectPermissionTitle => 'Потрібен дозвіл на проект';

  @override
  String get projectPermissionMessage =>
      'SkillsGo не може перевірити цей вибраний корінь. Надайте доступ, перемістивши його за допомогою засобу вибору каталогу.';

  @override
  String get projectInaccessibleTitle => 'Каталог проекту недоступний';

  @override
  String get projectInaccessibleMessage =>
      'SkillsGo зберіг посилання на цей проект. Перевірте шлях або том, а потім перемістіть його.';

  @override
  String get checking => 'Перевірка…';

  @override
  String get checkUpdates => 'Перевірте оновлення';

  @override
  String get refresh => 'Оновити';

  @override
  String get libraryUnavailable => 'Бібліотека недоступна';

  @override
  String get libraryEmpty => 'Навички ще не встановлено';

  @override
  String get libraryEmptyMessage =>
      'Установіть Skill із Discover, і він з’явиться тут.';

  @override
  String get searchLibrary => 'Пошук встановлених навичок';

  @override
  String get libraryNoMatches => 'Немає збігів Skills';

  @override
  String get libraryNoMatchesMessage =>
      'Спробуйте іншу назву, джерело, Agent, проект або версію.';

  @override
  String agentsSummary(int count) {
    return '$count Agents';
  }

  @override
  String projectsSummary(int count) {
    return 'Проекти $count';
  }

  @override
  String versionsSummary(int count) {
    return 'Версії $count';
  }

  @override
  String get hubManaged => 'Hub вдалося';

  @override
  String get localManaged => 'Місцеве управління';

  @override
  String get externalInstallation => 'Зовнішній монтаж';

  @override
  String get readOnly => 'Тільки для читання';

  @override
  String get unversioned => 'Без версій';

  @override
  String get supportingFiles => 'Допоміжні файли';

  @override
  String get versionDivergence => 'Розбіжність версій';

  @override
  String get healthHealthy => 'Здоровий';

  @override
  String get healthMissing => 'Ціль відсутня';

  @override
  String get healthReplaced => 'Ціль замінено';

  @override
  String get healthLocalModification => 'Локальна модифікація';

  @override
  String get healthUnreadable => 'Ціль нечитабельна';

  @override
  String get healthUndeclared => 'Не оголошено';

  @override
  String get healthWorkspaceUnreadable => 'Стан робочої області не читається';

  @override
  String get healthLockMismatch => 'Невідповідність блокування';

  @override
  String get healthUnexpectedPath => 'Неочікуваний цільовий шлях';

  @override
  String get modeSymlink => 'Символьне посилання';

  @override
  String get modeCopy => 'Копія';

  @override
  String get modeExternal => 'зовнішній';

  @override
  String get notLinked => 'НЕ ПОВ\'ЯЗАНО';

  @override
  String get update => 'оновлення';

  @override
  String get backToLibrary => 'Назад до бібліотеки';

  @override
  String get remove => 'видалити';

  @override
  String get manageTargets => 'Керувати обсягом';

  @override
  String skillsSelected(int count) {
    return 'Вибрано $count';
  }

  @override
  String get clearSelection => 'Очистити вибір';

  @override
  String get selectCurrentResults => 'Виберіть поточні результати';

  @override
  String get clearCurrentResultSelection =>
      'Очистити поточний вибір результату';

  @override
  String get manageTargetsTitle => 'Керуйте цілями встановлення';

  @override
  String get manageTargetsDescription =>
      'Виберіть точну дію для кожної цілі. Невибрані цілі не зміняться.';

  @override
  String targetActionsSelected(int selected, int total) {
    return 'Вибрано $selected із $total цілей';
  }

  @override
  String get repairTarget => 'Ремонт';

  @override
  String get confirmRemoveTarget => 'Підтвердити видалення';

  @override
  String get applyTargetActions => 'Застосувати вибрані дії';

  @override
  String get managementProgressTitle => 'Застосування цільових дій';

  @override
  String get managementResultsTitle => 'Цільові результати дії';

  @override
  String managementResultSummary(int succeeded, int failed) {
    return '$succeeded вдалося, $failed не вдалося';
  }

  @override
  String get workspaceOwnershipChanges =>
      'Вибрані дії проекту оновлять skillsgo.yaml і skillsgo.lock.';

  @override
  String get targetContentPreserved =>
      'Поточний цільовий вміст буде збережено.';

  @override
  String get localReadFailed => 'Не можу прочитати цей Skill';

  @override
  String get localReadFailedMessage =>
      'SkillsGo не зміг прочитати цей встановлений навик. Переконайтеся, що його папка доступна та доступна, а потім повторіть спробу.';

  @override
  String get localConfiguration => 'НАЛАШТУВАННЯ SKILLSGO';

  @override
  String get settingsNavigation => 'Налаштування навігації';

  @override
  String get general => 'Персоналізація';

  @override
  String get agents => 'Agents';

  @override
  String get hub => 'Hub';

  @override
  String get installationPolicy => 'Політика встановлення';

  @override
  String get storage => 'Зберігання';

  @override
  String get colorScheme => 'Колірна схема';

  @override
  String get about => 'про';

  @override
  String get colorSchemeInspectorTitle => 'Згенеровані кольорові ролі Material';

  @override
  String get skillsColorTokensTitle => 'SkillsGo семантичні кольори';

  @override
  String get skillsColorTokensDescription =>
      'Кольори продукту, створені з Radix Sand і організовані за семантикою Primer, із Folder як спеціальною просторовою ієрархією.';

  @override
  String get colorSchemeInspectorDescription =>
      'Попередній перегляд кожного токена ColorScheme, створеного з поточного початкового числа, який не підтримується. Клацніть колір, щоб скопіювати його значення HEX.';

  @override
  String get colorSchemePairPreview => 'Смислові пари';

  @override
  String get colorSchemePairPreviewDescription =>
      'Ролі переднього плану та фону відтворюються разом, щоб відобразити контраст та ієрархію.';

  @override
  String get colorSchemeComponentPreview => 'Попередній перегляд компонентів';

  @override
  String get colorSchemeComponentPreviewDescription =>
      'Репрезентативні елементи керування Material, відтворені за цією точною схемою попереднього перегляду.';

  @override
  String get colorSchemeSampleTitle => 'Назва картки Skill';

  @override
  String get colorSchemeSampleBody =>
      'Вторинна копія використовує onSurfaceVariant.';

  @override
  String get colorSchemeCopied => 'Скопійовано';

  @override
  String get colorSchemeSampleGlyphs => 'Aa 123';

  @override
  String get colorSchemeGroupPrimary => 'Первинний';

  @override
  String get colorSchemeGroupPrimaryDescription =>
      'Основний наголос, контейнери та фіксовані ролі акценту.';

  @override
  String get colorSchemeGroupSecondary => 'Вторинний';

  @override
  String get colorSchemeGroupSecondaryDescription =>
      'Допоміжні акценти та фіксовані другорядні ролі.';

  @override
  String get colorSchemeGroupTertiary => 'Третинний';

  @override
  String get colorSchemeGroupTertiaryDescription =>
      'Контрастні акценти та фіксовані третьорядні ролі.';

  @override
  String get colorSchemeGroupSurface => 'Поверхня';

  @override
  String get colorSchemeGroupSurfaceDescription =>
      'Сторінка, контейнер, висота та ієрархія переднього плану.';

  @override
  String get colorSchemeGroupUtility => 'Структура та утиліта';

  @override
  String get colorSchemeGroupUtilityDescription =>
      'Межі, тіні, борти та зворотні поверхні.';

  @override
  String get colorSchemeGroupError => 'Помилка';

  @override
  String get colorSchemeGroupErrorDescription =>
      'Дії щодо помилок, повідомлення та контейнери.';

  @override
  String get colorSchemeUsagePrimary => 'Основні дії, фокус і сильні акценти.';

  @override
  String get colorSchemeUsageSecondary => 'Допоміжні дії та середні акценти.';

  @override
  String get colorSchemeUsageTertiary =>
      'Контрастні акценти, які доповнюють головне і другорядне.';

  @override
  String colorSchemeUsageContentOn(String token) {
    return 'Текст і значки, що відображаються на $token.';
  }

  @override
  String colorSchemeUsageContainer(String family) {
    return 'Контейнер $family з нижнім акцентом для виділення та акцентів.';
  }

  @override
  String colorSchemeUsageFixed(String family) {
    return 'Незалежний від яскравості фіксований контейнер $family.';
  }

  @override
  String colorSchemeUsageFixedDim(String family) {
    return 'Затемнений незалежний від яскравості фіксований контейнер $family.';
  }

  @override
  String colorSchemeUsageFixedContent(String family) {
    return 'Високий акцент вмісту на фіксованому контейнері $family.';
  }

  @override
  String colorSchemeUsageFixedVariantContent(String family) {
    return 'Вміст із меншим акцентом на фіксованому контейнері $family.';
  }

  @override
  String get colorSchemeUsageSurface =>
      'Базова сторінка та поверхня великої області.';

  @override
  String get colorSchemeUsageSurfaceDim =>
      'Затемнена базова поверхня використовується з найтемнішим тоном поверхні.';

  @override
  String get colorSchemeUsageSurfaceBright =>
      'Яскрава базова поверхня використовується з найсвітлішим тоном поверхні.';

  @override
  String colorSchemeUsageSurfaceElevation(String level) {
    return 'Висота надводного контейнера $level.';
  }

  @override
  String get colorSchemeElevationLowest => 'найнижчий';

  @override
  String get colorSchemeElevationLow => 'низький';

  @override
  String get colorSchemeElevationDefault => 'за замовчуванням';

  @override
  String get colorSchemeElevationHigh => 'висока';

  @override
  String get colorSchemeElevationHighest => 'найвищий';

  @override
  String get colorSchemeUsageOnSurface =>
      'Основний текст і значки, що відображаються на поверхнях.';

  @override
  String get colorSchemeUsageOnSurfaceVariant =>
      'Додатковий текст, мітки та приглушені значки на поверхнях.';

  @override
  String get colorSchemeUsageSurfaceTint =>
      'Відтінок висоти Material, отриманий від основного.';

  @override
  String get colorSchemeUsageOutline =>
      'Чіткі межі та чіткі контури компонентів.';

  @override
  String get colorSchemeUsageOutlineVariant =>
      'Тонкі межі, роздільники та слабкі контури.';

  @override
  String get colorSchemeUsageShadow => 'Тіньовий колір для високих поверхонь.';

  @override
  String get colorSchemeUsageScrim =>
      'Модальне накладання, яке використовується для зменшення акценту фонового вмісту.';

  @override
  String get colorSchemeUsageInverseSurface =>
      'Поверхня зі зворотним світлим і темним акцентом.';

  @override
  String get colorSchemeUsageInversePrimary =>
      'Основний акцент, винесений на виворітну поверхню.';

  @override
  String get colorSchemeUsageError =>
      'Дії щодо помилок, статус і зворотний зв’язок з великим акцентом.';

  @override
  String get save => 'зберегти';

  @override
  String get advancedSettings => 'Просунутий';

  @override
  String get remindersSettings => 'Нагадування';

  @override
  String get remindersSettingsTitle => 'Налаштування нагадувань';

  @override
  String get remindersSettingsDescription =>
      'Виберіть, які нагадування отримувати.';

  @override
  String get updateReminderTitle => 'Оновити нагадування';

  @override
  String get updateReminderDescription =>
      'Перевірте наявність оновлень, коли відкриється бібліотека.';

  @override
  String get securityReminderTitle => 'Сповіщення про високий ризик';

  @override
  String get securityReminderDescription =>
      'Сповіщати вас про нові високий або критичний ризик у встановлених навичках.';

  @override
  String availableUpdatesReminder(int count) {
    return 'Установлені навички $count мають оновлення';
  }

  @override
  String get openAvailableUpdates =>
      'Відкрийте вікно доступних оновлень, щоб переглянути й оновити їх.';

  @override
  String securityAdvisoriesReminder(int count) {
    return 'Установлені навички $count потребують перевірки безпеки';
  }

  @override
  String get reviewInstalledSkills =>
      'Перегляньте інформацію про ризики перед їх використанням або оновленням.';

  @override
  String get generalSettingsTitle => 'Зробіть SkillsGo своїм';

  @override
  String get generalSettingsDescription =>
      'Інтерфейс відповідає системній мові, доступності та налаштуванням руху.';

  @override
  String get agentsSettingsTitle => 'Час виконання Agent';

  @override
  String get hubSettingsTitle => 'Hub Походження';

  @override
  String get hubSettingsDescription =>
      'Використовуйте офіційне джерело Hub або HTTP(S), яке реалізує той самий протокол SkillsGo.';

  @override
  String get testConnection => 'Тестове підключення';

  @override
  String get saveOrigin => 'Зберегти походження';

  @override
  String get resetDefault => 'Скинути до замовчування';

  @override
  String get connectionReady => 'Підключення готове';

  @override
  String get connectionFailed => 'Помилка підключення';

  @override
  String get hubInvalidOrigin =>
      'Введіть дійсне джерело HTTP(S) без облікових даних, запиту чи фрагмента.';

  @override
  String hubHttpFailure(int status) {
    return 'Hub повернув HTTP $status. Перевірте джерело та конфігурацію сервера.';
  }

  @override
  String get hubInvalidProtocol =>
      'Сервер не повернув протокол пошуку SkillsGo Hub.';

  @override
  String get hubInvalidJson => 'Hub повернув недійсний JSON.';

  @override
  String get hubConnectionFailure =>
      'Не вдалося зв’язатися з Hub. Перевірте налаштування Origin, мережі, проксі та TLS.';

  @override
  String get hubConnectionTimeout =>
      'Час очікування підключення Hub минув. Перевірте мережу або повторіть спробу.';

  @override
  String get riskPolicyTitle => 'Політика персональних ризиків';

  @override
  String get riskPolicyDescription =>
      'Правила безпеки застосовуються під час встановлення або оновлення навичок.';

  @override
  String get confirmHighRisk => 'Вимагати підтвердження для високого ризику';

  @override
  String get confirmHighRiskDescription =>
      'Артефакти високого ризику завжди вимагають додаткового підтвердження перед встановленням.';

  @override
  String get allowCriticalOverride =>
      'Дозволити явне перевизначення критичного ризику';

  @override
  String get allowCriticalOverrideDescription =>
      'Артефакти критичного ризику залишаються заблокованими за умовчанням. Увімкніть це лише для надання окремої ручної перевизначення.';

  @override
  String get storageSettingsTitle => 'Змістово-адресований Store';

  @override
  String get storageHealthy => 'Читабельний';

  @override
  String get storageNotInitialized => 'Не ініціалізовано';

  @override
  String get storageUnavailable => 'Недоступний';

  @override
  String get storagePathUnavailable =>
      'Шлях Store недоступний, доки не буде готова діагностика CLI.';

  @override
  String get storageHealthyDescription =>
      'CLI може читати Store без зміни його вмісту.';

  @override
  String get storageNotInitializedDescription =>
      'Store ще не існує і не був створений цією перевіркою.';

  @override
  String get storageUnavailableDescription =>
      'CLI не може читати Store. Перевірте його дозволи та батьківський каталог.';

  @override
  String get storageInvalidResponse =>
      'Збірник CLI повернув непідтримувану діагностичну відповідь.';

  @override
  String get aboutSettingsTitle => 'Сумісність продукту';

  @override
  String get appVersion => 'Версія програми';

  @override
  String get cliVersion => 'Версія CLI в комплекті';

  @override
  String get compatible => 'сумісний';

  @override
  String get hubOriginSaved => 'Hub Початок збережено та застосовано.';

  @override
  String get policySaved => 'Політику встановлення збережено.';

  @override
  String get officialCli => 'SkillsGo CLI';

  @override
  String get ready => 'ГОТОВИЙ';

  @override
  String get unknown => 'НЕВІДОМО';

  @override
  String get missing => 'ВІДСУТИЙ';

  @override
  String get incompatible => 'НЕСУМІСНИЙ';

  @override
  String get detecting => 'Виявлення…';

  @override
  String get customCliPath => 'Настроюваний шлях до виконуваного файлу';

  @override
  String get saveAndDetect => 'Зберегти й виявити';

  @override
  String get detectAgain => 'Виявити знову';

  @override
  String get agentInstalled => 'встановлено';

  @override
  String get agentSupported => 'Підтримується';

  @override
  String agentCatalogSummary(int installed, int supported) {
    return 'Встановлено: $installed · підтримується: $supported';
  }

  @override
  String installedAgentsTitle(int count) {
    return 'Встановлено · $count';
  }

  @override
  String notInstalledAgentsTitle(int count) {
    return 'Не встановлено · $count';
  }

  @override
  String get notInstalledAgentsDescription =>
      'Підтримується SkillsGo, але не виявлено на цьому Mac.';

  @override
  String agentDiscoveryRoots(String paths) {
    return 'Шляхи завантаження Skill: $paths';
  }

  @override
  String get agentInspectionFailed =>
      'Дані виявлення Agent недоступні. Запустіть виявлення знову.';

  @override
  String get noInstalledAgentsTitle => 'Не виявлено встановлених Agents';

  @override
  String get noInstalledAgentsMessage =>
      'Ви можете й далі переглядати цей Skill, але цілі встановлення ще немає. Встановіть підтримуваний Agent і запустіть виявлення знову.';

  @override
  String get clearCustomPath => 'Очистити власний шлях';

  @override
  String get privacyProvenance => 'Конфіденційність і походження';

  @override
  String get privacySummary =>
      'Ваші пошукові запити не зберігаються, а SkillsGo не веде журнали команд.';

  @override
  String get language => 'Мова';

  @override
  String get personalizationTheme => 'Тема';

  @override
  String get folderColorTheme => 'Колір теми';

  @override
  String get folderColorThemeDescription =>
      'Виберіть колір теми папок SkillsGo.';

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
      'Виберіть світлий, темний або системний режим оформлення.';

  @override
  String get followSystem => 'Як у системі';

  @override
  String get lightMode => 'світло';

  @override
  String get darkMode => 'Темний';

  @override
  String get wallpaper => 'Шпалери';

  @override
  String get wallpaperDescription => 'Виберіть фоновий світ для SkillsGo.';

  @override
  String get wallpaperSun => 'сонце';

  @override
  String get wallpaperMercury => 'Меркурій';

  @override
  String get wallpaperVenus => 'Венера';

  @override
  String get wallpaperEarth => 'земля';

  @override
  String get wallpaperMars => 'Марс';

  @override
  String get wallpaperJupiter => 'Юпітер';

  @override
  String get wallpaperSaturn => 'Сатурн';

  @override
  String get wallpaperUranus => 'Уран';

  @override
  String get wallpaperNeptune => 'Нептун';

  @override
  String get wallpaperPluto => 'Плутон';

  @override
  String get wallpaperMoon => 'Місяць';

  @override
  String folderThemeChoice(String theme) {
    return 'Тема папок: $theme';
  }

  @override
  String get privacyAffiliation =>
      'SkillsGo не пов’язаний із постачальниками Agent або джерел.';

  @override
  String get commandCompleted => 'Команда виконана';

  @override
  String get commandFailed => 'Помилка команди';

  @override
  String commandExit(int code) {
    return 'Команда завершилася з кодом $code';
  }

  @override
  String get command => 'Команда';

  @override
  String get cancel => 'Скасувати';

  @override
  String get updateUnknown => 'НЕВІДОМО';

  @override
  String get updateChecking => 'ПЕРЕВІРКА';

  @override
  String get upToDate => 'АКТУАЛЬНО';

  @override
  String get updateAvailable => 'ОНОВЛЕННЯ';

  @override
  String get updateUnavailable => 'НЕДОСТУПНИЙ';

  @override
  String get updateCheckFailed => 'ПЕРЕВІРКА ПОМИЛАСЯ';

  @override
  String get installSkill => 'Встановіть Skill';

  @override
  String get installLocationTitle => 'Виберіть місце встановлення';

  @override
  String get userLevel => 'Рівень користувача';

  @override
  String get projectLevel => 'Рівень проекту';

  @override
  String get projects => 'Проекти';

  @override
  String get loading => 'Завантаження…';

  @override
  String get repositoryParsing => 'Розбір сховища…';

  @override
  String userInstallSummary(int agents) {
    return 'Встановити глобально для $agents';
  }

  @override
  String projectInstallSummary(int projects, int agents) {
    return '$projects проєктів · $agents Agents';
  }

  @override
  String get installationResults => 'Результати установки';

  @override
  String get installationInProgress => 'Триває встановлення';

  @override
  String get installationSucceeded => 'Встановлення завершено';

  @override
  String get installationSucceededMessage =>
      'Skill установлено у вибраних місцях.';

  @override
  String get projectUnavailable => 'Проект недоступний';

  @override
  String get installedCell => 'встановлено';

  @override
  String get unsupportedCell => 'Недоступний';

  @override
  String get confirmInstall => 'Підтвердити встановлення';

  @override
  String installAllRepositorySkills(int count) {
    return 'Встановити всі навички сховища ($count)';
  }

  @override
  String get installAllSkillsTo => 'Встановити всі навички для';

  @override
  String installRepositorySkills(String repository, int count) {
    return 'Встановити всі навички $repository ($count)';
  }

  @override
  String installSkillTo(String skill) {
    return 'Встановіть $skill в';
  }

  @override
  String get availableInAllProjects => 'Всі проекти';

  @override
  String get availableInSelectedProjects => 'Вибрані проекти';

  @override
  String get usedBy => 'Для Agents';

  @override
  String get backToTargets => 'Назад до цілей';

  @override
  String get stayHere => 'Залишайся тут';

  @override
  String get viewInLibrary => 'Переглянути в бібліотеці';

  @override
  String planCreateCount(int count) {
    return '$count створити';
  }

  @override
  String planSkipCount(int count) {
    return '$count пропустити';
  }

  @override
  String planReplaceCount(int count) {
    return '$count замінити';
  }

  @override
  String planConflictCount(int count) {
    return 'Конфлікт $count';
  }

  @override
  String planRiskCount(int count) {
    return 'Ризик $count заблоковано';
  }

  @override
  String get refreshInstallationPlan => 'Застосувати резолюції';

  @override
  String get replaceVersionConflict =>
      'Замініть встановлену версію на цій цілі';

  @override
  String get replaceSkillIdCollision =>
      'Замініть інший ідентифікатор Skill у цій цілі';

  @override
  String get replaceLocalModification =>
      'Відмовтеся від локальних змін і замініть цю ціль';

  @override
  String get sharedTargetConflict => 'Цей шлях спільний для інших цілей Agent';

  @override
  String sharedTargetConflictDescription(String agents) {
    return 'Поверніться до цільової матриці та виберіть кожен уражений Agent перед заміною: $agents';
  }

  @override
  String get replaceConflictingTarget => 'Замініть конфліктну ціль';

  @override
  String get confirmHighRiskArtifact =>
      'Підтвердження артефакту високого ризику';

  @override
  String get confirmCriticalRiskArtifact =>
      'Підтвердження перевизначення критичного ризику';

  @override
  String get confirmRiskForSelectedTargets =>
      'Я переглянув файли артефактів і приймаю цей ризик для вибраних цілей';

  @override
  String get criticalRiskBlocked => 'Інсталяцію критичного ризику заблоковано';

  @override
  String get criticalRiskOverrideDisabled =>
      'Увімкніть явне перевизначення критичного ризику в налаштуваннях, перш ніж цей план можна буде продовжити.';

  @override
  String get workspaceManifestChanges => 'Зміни Workspace Manifest';

  @override
  String get noWorkspaceManifestChanges =>
      'Файли Workspace Manifest не зміняться.';

  @override
  String lockVersionChange(String from, String to) {
    return '$from → $to';
  }

  @override
  String get notPresent => 'немає';

  @override
  String get planActionCreate => 'Створити';

  @override
  String get planActionReplace => 'Замінити';

  @override
  String get planActionSkip => 'Пропустити';

  @override
  String get planActionConflict => 'Конфлікт';

  @override
  String get planActionBlockedByRisk => 'Заблокований ризиком';

  @override
  String installationResultSummary(int succeeded, int failed) {
    return 'Цілі $succeeded установлено, $failed не вдалося';
  }

  @override
  String get installationProgressTitle => 'Триває встановлення';

  @override
  String installationProgressSummary(int finished, int total) {
    return '$finished з $total цілей завершено';
  }

  @override
  String get targetWaiting => 'Очікування';

  @override
  String get targetRunning => 'Встановлення';

  @override
  String retryFailedTargets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Повторити $count невдалої цілі',
      many: 'Повторити $count невдалих цілей',
      few: 'Повторити $count невдалі цілі',
      one: 'Повторити $count невдалу ціль',
    );
    return '$_temp0';
  }

  @override
  String get updatePlanTitle => 'Виберіть цілі для оновлення';

  @override
  String get updatePlanDescription =>
      'Виберіть точні цілі встановлення. Невибрані Agents і проекти залишаються без змін.';

  @override
  String updateTargetsSelected(int selected, int available) {
    return 'Вибрано $selected з $available оновлюваних цілей';
  }

  @override
  String updateVersionChange(String fromVersion, String toVersion) {
    return '$fromVersion → $toVersion';
  }

  @override
  String sourceReference(String reference) {
    return 'Посилання на джерело: $reference';
  }

  @override
  String get fixedVersionTarget => 'Закріплено — немає рухомого посилання';

  @override
  String get currentVersionTarget => 'В актуальному стані';

  @override
  String get updateCheckTargetFailed => 'Не вдалося перевірити оновлення';

  @override
  String get reconcileWorkspaceManifestTarget =>
      'Маніфест робочої області ремонту';

  @override
  String get updateSelectedTargets => 'Оновити вибрані цілі';

  @override
  String get updateProgressTitle => 'Оновлення цілей';

  @override
  String get updateResultsTitle => 'Оновити результати';

  @override
  String updateProgressSummary(int finished, int total) {
    return '$finished з $total цілей завершено';
  }

  @override
  String retryFailedUpdates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Повторити $count невдалого оновлення',
      many: 'Повторити $count невдалих оновлень',
      few: 'Повторити $count невдалі оновлення',
      one: 'Повторити $count невдале оновлення',
    );
    return '$_temp0';
  }

  @override
  String get noUpdateableTargets =>
      'Жодна вибрана ціль не має доступного оновлення.';

  @override
  String get closeUpdatePlan => 'Закрити';

  @override
  String get targetSucceeded => 'встановлено';

  @override
  String get targetSkipped => 'Пропущено';

  @override
  String get targetConflict => 'Конфлікт';

  @override
  String get targetFailed => 'Не вдалося';

  @override
  String get targetFailureRetryable =>
      'Це місце не можна змінити. Ви можете спробувати ще раз.';

  @override
  String get targetFailureNeedsAttention =>
      'Це місце потребує вашої уваги, перш ніж повторити спробу.';

  @override
  String get installationTargetFailureMessage =>
      'У цьому місці нічого не змінено. Переконайтеся, що папка доступна, і повторіть спробу.';

  @override
  String get workspacePersistenceFailureMessage =>
      'Нічого не було змінено, оскільки SkillsGo не зміг зберегти налаштування проекту. Перевірте, чи доступна для запису папка проекту, і повторіть спробу.';

  @override
  String get installationStateChangedMessage =>
      'Це місце змінилося, поки ви його переглядали. Перегляньте останній стан перед повторною спробою.';

  @override
  String get updateTargetFailureMessage =>
      'Це місце не вдалося оновити. Інші місця не вплинули, тому ви можете повторити спробу лише в цьому.';

  @override
  String get managementTargetFailureMessage =>
      'Цю дію не вдалося завершити тут. Інші місця не вплинули, тому ви можете повторити спробу лише в цьому.';

  @override
  String get technicalDetails => 'Технічні деталі';

  @override
  String get targetPathExists => 'У цьому місці вже існує інший елемент.';

  @override
  String get targetBlockedByRisk =>
      'Ваші поточні налаштування безпеки заблокували встановлення в цьому місці.';

  @override
  String get targetInstallFailed =>
      'Не вдалося встановити навик у цьому місці.';

  @override
  String get targetWorkspaceUpdateFailed =>
      'Навички встановлено, але не вдалося оновити налаштування проекту.';

  @override
  String get installationPlanFailed =>
      'План встановлення не вдалося продовжити';

  @override
  String get installationFailed => 'Не вдалося завершити встановлення';

  @override
  String get localSource => 'Місцеве джерело';

  @override
  String get noDescriptionAvailable => 'Немає опису';

  @override
  String moreCoverage(int count) {
    return '+$count більше місць';
  }

  @override
  String get batchTakeoverAction => 'Керуйте наявними навичками';

  @override
  String batchTakeoverActionCount(int count) {
    return 'Керувати ($count)';
  }

  @override
  String get batchTakeoverChecking => 'Перевірка наявних навичок…';

  @override
  String get batchTakeoverRetry => 'Ще раз перевірте керовані навички';

  @override
  String batchTakeoverEligibleCount(int count) {
    return '$count можна керувати';
  }

  @override
  String get batchTakeoverPending => 'Додавання навичок до управління…';

  @override
  String get batchTakeoverTitle =>
      'Керувати наявними навичками за допомогою SkillsGo?';

  @override
  String get batchTakeoverDescription =>
      'SkillsGo додасть локальні записи керування без переміщення, перезапису або завантаження файлів навичок. Непідтримувані або змінені елементи будуть пропущені.';

  @override
  String get batchTakeoverStoryTitle =>
      'Перетворіть розрізнені навички в одну чітку бібліотеку';

  @override
  String batchTakeoverStoryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count наявного Skill',
      many: '$count наявних Skill',
      few: '$count наявні Skill',
      one: '$count наявний Skill',
    );
    return 'SkillsGo знайшов тут $_temp0, якими можна керувати.';
  }

  @override
  String get batchTakeoverBeforeSemantics =>
      'Перед керівництвом незрозуміло, де встановлено наявні навички, чи вони актуальні, як їх відновити, чи проекти використовують ту саму версію.';

  @override
  String get batchTakeoverPainLocation => 'Невідоме місце встановлення';

  @override
  String get batchTakeoverPainFreshness => 'Невідомий статус оновлення';

  @override
  String get batchTakeoverPainRecovery => 'Немає відновлення при поломці';

  @override
  String get batchTakeoverPainVersionDrift => 'Різні версії для проектів';

  @override
  String get batchTakeoverFolderTitle => 'Існуючий Skills';

  @override
  String get batchTakeoverFolderSubtitle => 'Незрозумілий статус';

  @override
  String get batchTakeoverAfterLabel => 'ПІСЛЯ';

  @override
  String get batchTakeoverAfterTitle => 'Одна чітка бібліотека';

  @override
  String get batchTakeoverLibraryTitle => 'Бібліотека SkillsGo';

  @override
  String get batchTakeoverBenefitLocation => 'Очистити локації';

  @override
  String get batchTakeoverBenefitFreshness => 'Оновлення видно';

  @override
  String get batchTakeoverBenefitRecovery => 'Легке відновлення';

  @override
  String get batchTakeoverBenefitVersions => 'Версії зрозумілі';

  @override
  String get batchTakeoverManagedSection => 'Керується SkillsGo';

  @override
  String get batchTakeoverPendingSection => 'В очікуванні';

  @override
  String batchTakeoverItemManaged(String name) {
    return '$name управляється SkillsGo';
  }

  @override
  String batchTakeoverItemSkipped(String name) {
    return '$name не вдалося додати до керування';
  }

  @override
  String batchTakeoverItemPending(String name) {
    return '$name чекає на керування';
  }

  @override
  String batchTakeoverAfterSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Skill упорядковано',
      many: '$count Skill упорядковано',
      few: '$count Skill упорядковано',
      one: '$count Skill упорядковано',
    );
    return 'Після додавання $_temp0 в одній Library зі зрозумілим статусом керування.';
  }

  @override
  String batchTakeoverMoreSkills(int count) {
    return '+$count більше';
  }

  @override
  String get batchTakeoverTransitionSemantics =>
      'Додайте ці наявні навички до управління SkillsGo.';

  @override
  String get batchTakeoverTransitionLabel => 'ОРГАНІЗУЙТЕ';

  @override
  String get batchTakeoverStatusTitle => 'Статус управління';

  @override
  String get batchTakeoverStatusManaged => 'Керований';

  @override
  String get batchTakeoverStatusProgress => 'Організація';

  @override
  String get batchTakeoverStatusSkipped => 'Пропущено';

  @override
  String get batchTakeoverStatusFilesStay =>
      'Файли Skill залишаються у вихідних місцях';

  @override
  String get batchTakeoverBoardSemantics =>
      'Skills впорядковуються в повні ряди та записуються SkillsGo без переміщення файлів.';

  @override
  String get batchTakeoverBoardComplete => 'ВСЕ ЯСНО';

  @override
  String get batchTakeoverBoardPartial => 'ЗАВЕРШЕНО';

  @override
  String get batchTakeoverStatusTotal => 'Всього';

  @override
  String get batchTakeoverQueueComplete => 'Ніякі навички не чекають';

  @override
  String get batchTakeoverQueueWaiting =>
      'Після перевірки Skills з’являться тут';

  @override
  String get batchTakeoverNextLabel => 'ДАЛІ';

  @override
  String batchTakeoverFillerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count блока-органайзера SkillsGo',
      many: '$count блоків-органайзерів SkillsGo',
      few: '$count блоки-органайзери SkillsGo',
      one: '$count блок-органайзер SkillsGo',
    );
    return '$_temp0 завершують останні рядки.';
  }

  @override
  String get batchTakeoverPreservation =>
      'Ваші файли, шляхи та поточні робочі процеси залишаються там, де вони є. SkillsGo лише завершує свої локальні записи керування.';

  @override
  String get batchTakeoverLaterHint =>
      'Якщо ви пропустите, ви зможете будь-коли скористатися пунктом керування наявними навичками з бібліотеки.';

  @override
  String get batchTakeoverSkip => 'Не зараз';

  @override
  String get batchTakeoverConfirm => 'Додати до управління';

  @override
  String get batchTakeoverExecutionRetry => 'Повторіть спробу';

  @override
  String get batchTakeoverResultTitle => 'Skills додано до керування';

  @override
  String batchTakeoverSummary(int takenOver, int skipped) {
    return 'Навички $takenOver додано до керування, $skipped пропущено.';
  }

  @override
  String get batchTakeoverClose => 'Закрити';

  @override
  String get installMoreTargets => 'Встановити в інших місцях';

  @override
  String get exportLocalSkill => 'Експорт';

  @override
  String get exportLocalSkillDescription =>
      'Експортуйте цей локальний Skill як портативний архів ZIP.';

  @override
  String get detailRepository => 'Репозиторій';

  @override
  String get detailStars => 'Зірки';

  @override
  String get detailUpdated => 'Оновлено';

  @override
  String get detailArchiveSize => 'Розмір ZIP';

  @override
  String get pathLabel => 'Шлях проекту';

  @override
  String get copyProjectPath => 'Копіювати шлях проекту';

  @override
  String get projectPathCopied => 'Шлях проекту скопійовано';

  @override
  String get onboardingWelcomeTitle => 'Ласкаво просимо до SkillsGo';

  @override
  String get onboardingWelcomeDescription =>
      'Знаходьте, встановлюйте та керуйте Skills у своїх Agents і проектах.';

  @override
  String get onboardingDetectedAgents => 'Виявлено Agents';

  @override
  String get onboardingNoAgents =>
      'Не виявлено встановленого Agents. Ви все ще можете продовжувати.';

  @override
  String get onboardingNext => 'Далі';

  @override
  String get onboardingProjectsTitle => 'Додайте свої проекти';

  @override
  String get onboardingProjectsDescription =>
      'Виберіть проекти, якими SkillsGo має керувати.';

  @override
  String get onboardingAddProject => 'Додайте зараз';

  @override
  String get onboardingAddProjectLater => 'або пізніше';

  @override
  String get onboardingStartUsing => 'Почніть використовувати SkillsGo';

  @override
  String get onboardingBack => 'Назад';

  @override
  String get restartOnboardingTitle => 'Онбордінг';

  @override
  String get restartOnboardingDescription =>
      'Знову перегляньте посібник із першого запуску, не видаляючи проекти, налаштування чи дані Skills.';

  @override
  String get restartOnboardingAction => 'Перезапустіть Onboarding';

  @override
  String get restartOnboardingFailed =>
      'SkillsGo не вдалося перезапустити Onboarding.';

  @override
  String get libraryRefreshSettingsTitle => 'Оновіть локальну бібліотеку';

  @override
  String get libraryRefreshSettingsDescription =>
      'Перескануйте встановлений Skills, додані проекти, Agents і зовнішній Skills, якими можна керувати. Це не інсталює, не оновлює та не видаляє нічого.';

  @override
  String get libraryRefreshSettingsAction => 'Оновити бібліотеку';

  @override
  String get libraryRefreshSettingsPending => 'Оновлення бібліотеки…';

  @override
  String get libraryRefreshSettingsSuccess => 'Оновлено місцеву бібліотеку.';

  @override
  String get libraryRefreshSettingsFailed =>
      'SkillsGo не вдалося оновити локальну бібліотеку.';

  @override
  String get onboardingProjectError =>
      'SkillsGo не вдалося додати проекти з цього каталогу.';

  @override
  String get onboardingProjectsLoadError =>
      'SkillsGo не вдалося завантажити ваші додані проекти.';

  @override
  String get onboardingStartupError =>
      'SkillsGo не вдалося завантажити налаштування.';

  @override
  String get onboardingStateError =>
      'SkillsGo не вдалося зберегти хід налаштування. Спробуйте знову.';

  @override
  String get onboardingCliErrorTitle => 'SkillsGo CLI потребує уваги';

  @override
  String get onboardingCliErrorDescription =>
      'Відремонтуйте CLI, а потім повторіть спробу, щоб продовжити.';
}
