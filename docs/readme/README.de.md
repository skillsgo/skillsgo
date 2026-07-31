<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — Agent Skills entdecken, prüfen und verwalten">
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
    <strong>Deutsch</strong> ·
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
    <a href="./README.uk.md">Українська</a>
  </p>
<!-- README-I18N:END -->

SkillsGo ist ein offenes Ökosystem zum Entdecken und Verwalten von Agent Skills. Die Desktop-App bietet Menschen einen visuellen Weg zum Entdecken und Verwalten von Skills. Das CLI bindet denselben Hub-Katalog in CI/CD und reproduzierbare Umgebungsabläufe ein.

## SkillsGo in Aktion

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="Die SkillsGo Desktop-App zeigt Agent Skills aus der Live-Rangliste des öffentlichen Hub">
</p>

Die Desktop-App verbindet Entdeckung, Herkunftsnachweise, Installationsziele und lokales Inventar zu einem verständlichen Ablauf. Für die persönliche Nutzung ist kein Konto erforderlich.

### Über den Hub entdecken

Suche nach einem Skill oder Quell-Repository, durchsuche die Live-Rangliste und installiere einen einzelnen Skill oder eine vollständige Sammlung.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="Die Discover-Suche von SkillsGo zeigt ein Quell-Repository und seine verfügbaren Agent Skills">
</p>

### Vor der Installation prüfen

Prüfe Quell-Repository, unveränderliche Version, unterstützte Agents, übersetzte Zusammenfassung und gerenderte `SKILL.md`, bevor sich lokal etwas ändert.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="Die Skill-Detailansicht zeigt Herkunftsnachweis, Version, unterstützte Agents und gerenderte Anweisungen">
</p>

### Installationsort genau festlegen

Installiere global oder in ausgewählten Projekten und wähle anschließend die Agents aus, die dieselbe Skill-Version erhalten sollen.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="Die SkillsGo-Zielauswahl zeigt ausgewählte Projekte und mehrere Agent-Ziele">
</p>

### Eine lokale Library verwalten

Durchsuche installierte Skills nach globalem oder Projektbereich, suche im Inventar und filtere nach Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="Die SkillsGo Library zeigt global installierte Skills und ihre Agent-Ziele">
</p>

### Auswirkungen vor dem Update sehen

Sieh dir den Versionswechsel und alle zu entfernenden Skills an, bevor du ein Repository-Update anwendest.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="Die Update-Vorschau der SkillsGo Library zeigt Versionswechsel und zu entfernende Skills">
</p>

<details>
  <summary><strong>Projektbezogene Library anzeigen</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="Die SkillsGo Library zeigt Skills eines ausgewählten Projekts">
  </p>
</details>

## Warum SkillsGo

- **Echte Herkunftsnachweise** — prüfe Repository-Identität, Version, `SKILL.md`, Dateien und Risiken vor der Installation.
- **Explizite Agent-Ziele** — installiere Skills global oder projektbezogen für ausgewählte Agents, statt Dateien manuell zu kopieren.
- **Überprüfbare Verteilung** — behandle eine Version des Quell-Repository als unveränderliche Verteilungseinheit.
- **Lokale Verwaltung zuerst** — prüfe und verwalte das lokale Inventar sicher, auch wenn der Hub nicht verfügbar ist.
- **Zwei zweckgebundene Oberflächen** — die App dient interaktiven persönlichen Abläufen; das CLI unterstützt CI/CD, Automatisierung und konsistente Skill-Umgebungen.

## Funktionsweise

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo-Ablauf: entdecken, prüfen, Ziele wählen, installieren und verwalten">
</p>

Der öffentliche Hub ist die gemeinsame Quelle für Skill-Identität, unveränderliche Versionen, Metadaten, Suche und Entdeckung. Die App verbindet Menschen über einen visuellen Ablauf mit dem Hub. Das CLI verbindet Automatisierung und CI/CD mit demselben Hub, damit die Skill-Auswahl über Umgebungen hinweg konsistent bleibt.

## Das Monorepo erkunden

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Produktgrenzen und Domänensprache sind in [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) beschrieben.

## Lokal ausführen

Die einheitliche Entwicklungstopologie ist derzeit auf macOS ausgerichtet und benötigt Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) und [Air](https://github.com/air-verse/air).

```bash
make dev
```

Der Befehl startet PostgreSQL, den lokalen Hub, ein frisch gebautes CLI und die Flutter-Desktop-App in einer überwachten Sitzung. Alle konfigurierten Arbeitsbereiche werden so geprüft:

```bash
make test
```

Für jeden Arbeitsbereich gibt es außerdem einen eigenen Einstieg:

| Arbeitsbereich | Entwicklung oder Prüfung |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Lies [CONTRIBUTING.md](../../CONTRIBUTING.md), bevor du das Produktverhalten änderst.

## Projektstatus

SkillsGo bereitet seine ersten Veröffentlichungen vor. Zuerst wird die Release-Pipeline des Hub definiert; signierte und notarisierte App-Versionen sowie die eigenständige CLI-Verteilung folgen eigenen Bereitschaftskriterien. Unterstützte Release-Einheiten, Artefaktintegrität und Lieferkettenanforderungen stehen im [Release-Design](../release-design.md).

## Community

- Nutze [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) für Fragen, Fehlerbehebung und frühe Ideen.
- Nutze die gezielten [Issue-Formulare](https://github.com/skillsgo/skillsgo/issues/new/choose) für reproduzierbare Fehler, konkrete Funktionswünsche und Dokumentationsprobleme.
- Folge [SECURITY.md](../../SECURITY.md), um Sicherheitslücken vertraulich zu melden.
- Die Teilnahme richtet sich nach dem [Verhaltenskodex](../../CODE_OF_CONDUCT.md) und dem [Governance-Modell](../../GOVERNANCE.md).

## Lizenz

SkillsGo steht unter der [Apache License 2.0](../../LICENSE).

Der Hub enthält von [Athens](https://github.com/gomods/athens) abgeleiteten Code, für den weiterhin die Athens MIT License und die Namensnennungen gelten. Siehe [`NOTICE`](../../NOTICE) und [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
