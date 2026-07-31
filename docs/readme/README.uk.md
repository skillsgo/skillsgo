<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — знаходьте, перевіряйте й керуйте Agent Skills">
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
    <a href="./README.ru.md">Русский</a> ·
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
    <strong>Українська</strong>
  </p>
<!-- README-I18N:END -->

SkillsGo — це відкрита екосистема для пошуку й керування Agent Skills. Настільний App надає людям візуальний спосіб знаходити й керувати Skills, а CLI підключає той самий каталог Hub до CI/CD та відтворюваних робочих процесів середовища.

## SkillsGo у дії

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="Настільний App SkillsGo показує Agent Skills з актуального рейтингу публічного Hub">
</p>

Настільний App поєднує пошук, підтвердження джерела, цілі встановлення та локальний інвентар у зрозумілий процес. Для особистого використання обліковий запис не потрібен.

### Пошук через Hub

Шукайте за Skill або вихідним репозиторієм, переглядайте актуальний рейтинг і встановлюйте окремий Skill або всю колекцію.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="Пошук Discover у SkillsGo показує вихідний репозиторій і доступні Agent Skills">
</p>

### Перевірка перед встановленням

До локальних змін перевірте вихідний репозиторій, незмінний випуск, підтримувані Agents, перекладений опис і відтворений файл `SKILL.md`.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="Деталі Skill показують підтвердження джерела, версію, підтримувані Agents і відтворені інструкції">
</p>

### Точний вибір місця встановлення Skills

Установіть глобально або в обрані проєкти, а потім виберіть Agents, які мають отримати той самий випуск Skill.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="Вибір цілей встановлення SkillsGo показує обрані проєкти й кілька Agents">
</p>

### Керування єдиною локальною Library

Переглядайте встановлені Skills у глобальній області або за проєктами, шукайте в інвентарі та фільтруйте за Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="Library SkillsGo показує глобально встановлені Skills і відповідні цілі Agent">
</p>

### Наслідки оновлення видно заздалегідь

Перед застосуванням оновлення репозиторію перегляньте перехід між версіями та Skills, які буде видалено.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="Попередній перегляд оновлення Library показує перехід версії та Skills, які буде видалено">
</p>

<details>
  <summary><strong>Переглянути Library окремого проєкту</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="Library SkillsGo показує Skills, установлені в обраному проєкті">
  </p>
</details>

## Чому SkillsGo

- **Справжні підтвердження джерела** — перевіряйте ідентичність репозиторію, версію, `SKILL.md`, файли й ризики перед установленням.
- **Явні цілі Agent** — установлюйте Skills для обраних Agents глобально або в межах проєкту без ручного копіювання файлів.
- **Перевірюване розповсюдження** — розглядайте випуск вихідного репозиторію як незмінну одиницю розповсюдження.
- **Насамперед локальне керування** — безпечно перевіряйте й керуйте локальним інвентарем, навіть коли Hub недоступний.
- **Два спеціалізовані інтерфейси** — App призначено для інтерактивних особистих сценаріїв, а CLI — для CI/CD, автоматизації та узгоджених середовищ Skill.

## Як це працює

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="Процес SkillsGo: пошук, перевірка, вибір цілей, установлення та керування">
</p>

Публічний Hub є спільним джерелом ідентичності Skills, незмінних випусків, метаданих, пошуку та виявлення. App з’єднує людей із Hub через візуальний процес; CLI підключає автоматизацію та CI/CD до того самого Hub, щоб вибір Skills залишався узгодженим у різних середовищах.

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

Межі продукту й термінологію предметної області описано в [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md).

## Локальний запуск

Єдина конфігурація розробки зараз орієнтована на macOS і потребує Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) та [Air](https://github.com/air-verse/air).

```bash
make dev
```

Команда запускає PostgreSQL, локальний Hub, щойно зібраний CLI і настільний App на Flutter в одному контрольованому сеансі. Щоб перевірити всі налаштовані робочі області:

```bash
make test
```

Для кожної робочої області також є окрема точка входу:

| Робоча область | Розробка або перевірка |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Перед зміною поведінки продукту прочитайте [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Стан проєкту

SkillsGo готується до перших випусків. Спочатку визначається конвеєр випуску Hub; підписані й нотаріально засвідчені версії App та окреме розповсюдження CLI проходять власні етапи готовності. Підтримувані одиниці випуску, цілісність артефактів і вимоги до ланцюга постачання описано в [проєкті випуску](../release-design.md).

## Спільнота

- Використовуйте [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) для запитань, усунення несправностей і обговорення ранніх ідей.
- Використовуйте спеціалізовані [форми issues](https://github.com/skillsgo/skillsgo/issues/new/choose) для відтворюваних помилок, конкретних запитів функцій і проблем документації.
- Дотримуйтеся [SECURITY.md](../../SECURITY.md), щоб конфіденційно повідомляти про вразливості.
- Участь регулюється [Кодексом поведінки](../../CODE_OF_CONDUCT.md) і [моделлю керування](../../GOVERNANCE.md).

## Ліцензія

SkillsGo поширюється за [Apache License 2.0](../../LICENSE).

Hub містить код, похідний від [Athens](https://github.com/gomods/athens), на який і надалі поширюються Athens MIT License і вимоги щодо зазначення авторства. Див. [`NOTICE`](../../NOTICE) і [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
