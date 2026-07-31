<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — находите, проверяйте и управляйте Agent Skills">
</p>

<!-- README-I18N:START -->

  <p>
    <a href="../../README.md">English</a> ·
    <a href="./README.zh-CN.md">简体中文</a> ·
    <a href="./README.zh-TW.md">繁體中文（台灣）</a> ·
    <a href="./README.zh-HK.md">繁體中文（香港）</a> ·
    <a href="./README.ja.md">日本語</a> ·
    <a href="./README.ko.md">한국어</a> ·
    <a href="./README.fr.md">Français</a> ·
    <a href="./README.de.md">Deutsch</a> ·
    <a href="./README.it.md">Italiano</a> ·
    <a href="./README.es.md">Español</a> ·
    <a href="./README.pt-BR.md">Português (Brasil)</a> ·
    <strong>Русский</strong> ·
    <a href="./README.ar.md">العربية</a> ·
    <a href="./README.hi.md">हिन्दी</a> ·
    <a href="./README.id.md">Bahasa Indonesia</a> ·
    <a href="./README.tr.md">Türkçe</a> ·
    <a href="./README.nl.md">Nederlands</a> ·
    <a href="./README.pl.md">Polski</a> ·
    <a href="./README.th.md">ไทย</a> ·
    <a href="./README.vi.md">Tiếng Việt</a> ·
    <a href="./README.ms.md">Bahasa Melayu</a> ·
    <a href="./README.sv.md">Svenska</a> ·
    <a href="./README.uk.md">Українська</a>
  </p>
<!-- README-I18N:END -->

SkillsGo — открытая экосистема для поиска и управления Agent Skills. Настольное App предоставляет людям наглядный способ находить и управлять Skills, а CLI подключает тот же каталог Hub к CI/CD и воспроизводимым рабочим процессам окружений.

## SkillsGo в действии

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="Настольное App SkillsGo показывает Agent Skills из актуального рейтинга публичного Hub">
</p>

Настольное App объединяет поиск, подтверждение источника, цели установки и локальный инвентарь в единый понятный процесс. Для личного использования учетная запись не нужна.

### Поиск через Hub

Ищите по Skill или исходному репозиторию, просматривайте актуальный рейтинг и устанавливайте отдельный Skill либо всю коллекцию.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="Поиск Discover в SkillsGo показывает исходный репозиторий и доступные в нем Agent Skills">
</p>

### Проверка перед установкой

До локальных изменений проверьте исходный репозиторий, неизменяемую версию, поддерживаемые Agents, переведенное описание и отрисованный файл `SKILL.md`.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="Карточка Skill в SkillsGo показывает источник, версию, поддерживаемые Agents и отрисованные инструкции">
</p>

### Точный выбор места установки Skills

Установите Skills глобально или в выбранные проекты, затем выберите Agents, которые должны получить ту же версию Skill.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="Выбор целей установки SkillsGo с выбранными проектами и несколькими Agents">
</p>

### Управление единой локальной Library

Просматривайте установленные Skills в глобальной области или по проектам, ищите в инвентаре и фильтруйте по Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="Library SkillsGo показывает глобально установленные Skills и соответствующие цели Agent">
</p>

### Последствия обновления видны заранее

До обновления репозитория просмотрите переход между версиями и список Skills, которые будут удалены.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="Предварительный просмотр обновления Library показывает переход версии и удаляемые Skills">
</p>

<details>
  <summary><strong>Посмотреть Library отдельного проекта</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="Library SkillsGo показывает Skills, установленные в выбранном проекте">
  </p>
</details>

## Почему SkillsGo

- **Подтвержденный источник** — проверяйте идентификатор репозитория, версию, `SKILL.md`, файлы и риски до установки.
- **Явные цели Agent** — устанавливайте Skills для выбранных Agents глобально или в рамках проекта без ручного копирования файлов.
- **Проверяемое распространение** — рассматривайте версию исходного репозитория как неизменяемую единицу распространения.
- **Управление в первую очередь локально** — безопасно проверяйте и управляйте локальным инвентарем, даже если Hub недоступен.
- **Два специализированных интерфейса** — App предназначено для интерактивных личных сценариев, а CLI — для CI/CD, автоматизации и согласованных окружений Skill.

## Как это работает

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="Процесс SkillsGo: поиск, проверка, выбор целей, установка и управление">
</p>

Публичный Hub служит общим источником идентификаторов Skills, неизменяемых версий, метаданных, поиска и обнаружения. App связывает людей с Hub через наглядный рабочий процесс; CLI подключает автоматизацию и CI/CD к тому же Hub, чтобы выбор Skills оставался согласованным во всех окружениях.

## Структура monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Границы продукта и предметная терминология описаны в [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md).

## Локальный запуск

Единая конфигурация разработки сейчас предназначена для macOS и требует Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) и [Air](https://github.com/air-verse/air).

```bash
make dev
```

Команда запускает PostgreSQL, локальный Hub, заново собранный CLI и настольное App на Flutter в одной контролируемой сессии. Для проверки всех настроенных рабочих областей:

```bash
make test
```

Для каждой рабочей области также предусмотрена отдельная точка входа:

| Рабочая область | Разработка или проверка |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Перед изменением поведения продукта прочитайте [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Состояние проекта

SkillsGo готовится к первым выпускам. Сначала определяется конвейер выпуска Hub; подписанные и нотариально заверенные версии App и отдельное распространение CLI проходят собственные этапы готовности. Поддерживаемые единицы выпуска, целостность артефактов и требования к цепочке поставок описаны в [проекте выпуска](../release-design.md).

## Сообщество

- Используйте [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) для вопросов, устранения неполадок и обсуждения ранних идей.
- Используйте специализированные [формы issues](https://github.com/skillsgo/skillsgo/issues/new/choose) для воспроизводимых ошибок, конкретных запросов функций и проблем документации.
- Следуйте [SECURITY.md](../../SECURITY.md), чтобы сообщать об уязвимостях конфиденциально.
- Участие регулируется [Кодексом поведения](../../CODE_OF_CONDUCT.md) и [моделью управления](../../GOVERNANCE.md).

## Лицензия

SkillsGo распространяется по [Apache License 2.0](../../LICENSE).

Hub содержит код, производный от [Athens](https://github.com/gomods/athens), на который по-прежнему распространяются Athens MIT License и требования об указании авторства. См. [`NOTICE`](../../NOTICE) и [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
