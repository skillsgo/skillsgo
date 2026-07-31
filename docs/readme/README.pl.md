<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — odkrywaj, weryfikuj i zarządzaj Agent Skills">
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
    <strong>Polski</strong> ·
    <a href="./README.th.md">ไทย</a> ·
    <a href="./README.vi.md">Tiếng Việt</a> ·
    <a href="./README.ms.md">Bahasa Melayu</a> ·
    <a href="./README.sv.md">Svenska</a> ·
    <a href="./README.uk.md">Українська</a>
  </p>
<!-- README-I18N:END -->

SkillsGo to otwarty ekosystem do odkrywania i zarządzania Agent Skills. Aplikacja desktopowa App zapewnia użytkownikom wizualny sposób odkrywania i zarządzania Skills, a CLI udostępnia ten sam katalog Hub w CI/CD i odtwarzalnych przepływach środowisk.

## Zobacz SkillsGo w działaniu

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="Aplikacja desktopowa SkillsGo pokazuje Agent Skills z bieżącego rankingu publicznego Hub">
</p>

Aplikacja desktopowa łączy odkrywanie, dowody pochodzenia, cele instalacji i lokalny inwentarz w jeden przejrzysty proces. Do użytku osobistego nie jest potrzebne konto.

### Odkrywaj przez Hub

Wyszukuj według Skill lub repozytorium źródłowego, przeglądaj bieżący ranking i instaluj pojedynczy Skill albo całą kolekcję.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="Wyszukiwanie Discover w SkillsGo pokazuje repozytorium źródłowe i dostępne Agent Skills">
</p>

### Sprawdź przed instalacją

Przed zmianą lokalnego środowiska sprawdź repozytorium źródłowe, niezmienne wydanie, obsługiwane Agents, przetłumaczone podsumowanie i wyrenderowany plik `SKILL.md`.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="Szczegóły Skill pokazują dowód pochodzenia, wersję, obsługiwane Agents i wyrenderowane instrukcje">
</p>

### Precyzyjnie wybierz miejsce instalacji Skills

Zainstaluj globalnie lub w wybranych projektach, a następnie wybierz Agents, które mają otrzymać to samo wydanie Skill.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="Selektor celów instalacji SkillsGo pokazuje wybrane projekty i wiele Agents">
</p>

### Zarządzaj jedną lokalną Library

Przeglądaj zainstalowane Skills według zakresu globalnego lub projektu, przeszukuj inwentarz i filtruj według Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="Library SkillsGo pokazuje globalnie zainstalowane Skills i ich cele Agent">
</p>

### Poznaj skutki przed aktualizacją

Przed zastosowaniem aktualizacji repozytorium sprawdź zmianę wersji oraz Skills, które zostaną usunięte.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="Podgląd aktualizacji Library pokazuje zmianę wersji i Skills przeznaczone do usunięcia">
</p>

<details>
  <summary><strong>Zobacz Library dla wybranego projektu</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="Library SkillsGo pokazuje Skills zainstalowane w wybranym projekcie">
  </p>
</details>

## Dlaczego SkillsGo

- **Rzeczywiste dowody pochodzenia** — przed instalacją sprawdź tożsamość repozytorium, wersję, `SKILL.md`, pliki i ryzyka.
- **Jawne cele Agent** — instaluj Skills globalnie lub w zakresie projektu dla wybranych Agents bez ręcznego kopiowania plików.
- **Weryfikowalna dystrybucja** — traktuj wydanie repozytorium źródłowego jako niezmienną jednostkę dystrybucji.
- **Zarządzanie przede wszystkim lokalnie** — bezpiecznie sprawdzaj i zarządzaj lokalnym inwentarzem nawet wtedy, gdy Hub jest niedostępny.
- **Dwa interfejsy do różnych zadań** — używaj App do interaktywnych osobistych przepływów, a CLI do CI/CD, automatyzacji i spójnych środowisk Skill.

## Jak to działa

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="Proces SkillsGo: odkryj, sprawdź, wybierz cele, zainstaluj i zarządzaj">
</p>

Publiczny Hub jest wspólnym źródłem tożsamości Skills, niezmiennych wydań, metadanych, wyszukiwania i odkrywania. App łączy użytkowników z Hub przez wizualny przepływ; CLI łączy automatyzację i CI/CD z tym samym Hub, aby wybór Skills pozostawał spójny w różnych środowiskach.

## Poznaj monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Granice produktu i język domeny opisano w [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md).

## Uruchamianie lokalne

Ujednolicona topologia programistyczna jest obecnie przeznaczona dla macOS i wymaga Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) oraz [Air](https://github.com/air-verse/air).

```bash
make dev
```

To polecenie uruchamia PostgreSQL, lokalny Hub, świeżo zbudowany CLI i aplikację desktopową Flutter w jednej nadzorowanej sesji. Aby zweryfikować wszystkie skonfigurowane obszary robocze:

```bash
make test
```

Każdy obszar roboczy ma również osobny punkt wejścia:

| Obszar roboczy | Programowanie lub weryfikacja |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Przed zmianą zachowania produktu przeczytaj [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Stan projektu

SkillsGo przygotowuje pierwsze wydania. Najpierw definiowany jest proces wydawania Hub; podpisane i notarialnie poświadczone wydania App oraz niezależna dystrybucja CLI podlegają własnym kryteriom gotowości. Obsługiwane jednostki wydań, integralność artefaktów i wymagania łańcucha dostaw opisano w [projekcie wydań](../release-design.md).

## Społeczność

- Używaj [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) do zadawania pytań, rozwiązywania problemów i omawiania wczesnych pomysłów.
- Używaj dedykowanych [formularzy issues](https://github.com/skillsgo/skillsgo/issues/new/choose) do zgłaszania odtwarzalnych błędów, konkretnych próśb o funkcje i problemów z dokumentacją.
- Postępuj zgodnie z [SECURITY.md](../../SECURITY.md), aby prywatnie zgłaszać luki w zabezpieczeniach.
- Udział podlega [Kodeksowi postępowania](../../CODE_OF_CONDUCT.md) i [modelowi zarządzania](../../GOVERNANCE.md).

## Licencja

SkillsGo jest udostępniany na [Apache License 2.0](../../LICENSE).

Hub zawiera kod pochodzący z [Athens](https://github.com/gomods/athens), który nadal podlega Athens MIT License i informacjom o autorstwie. Zobacz [`NOTICE`](../../NOTICE) oraz [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
