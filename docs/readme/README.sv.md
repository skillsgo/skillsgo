<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — upptäck, verifiera och hantera Agent Skills">
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
    <strong>Svenska</strong> ·
    <a href="./README.uk.md">Українська</a>
  </p>
<!-- README-I18N:END -->

SkillsGo är ett öppet ekosystem för att upptäcka och hantera Agent Skills. Desktop-Appen ger människor ett visuellt sätt att upptäcka och hantera Skills, medan CLI gör samma Hub-katalog tillgänglig för CI/CD och reproducerbara miljöarbetsflöden.

## Se SkillsGo i praktiken

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="SkillsGo desktop-App visar Agent Skills från den offentliga Hubens liverankning">
</p>

Desktop-Appen förenar upptäckt, källbevis, installationsmål och lokalt inventarium i ett lättbegripligt flöde. För personlig användning krävs inget konto.

### Upptäck via Hub

Sök efter Skill eller källkodsförråd, utforska liverankningen och installera en Skill eller en hel samling.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="SkillsGo Discover-sökning visar ett källkodsförråd och dess tillgängliga Agent Skills">
</p>

### Kontrollera före installation

Granska källkodsförrådet, den oföränderliga versionen, Agents som stöds, den översatta sammanfattningen och renderad `SKILL.md` innan något ändras lokalt.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="Skill-detaljer visar källbevis, version, Agents som stöds och renderade instruktioner">
</p>

### Välj exakt var Skills ska installeras

Installera globalt eller i valda projekt och välj sedan vilka Agents som ska få samma Skill-version.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="SkillsGo installationsmålväljare visar valda projekt och flera Agents">
</p>

### Hantera ett lokalt Library

Bläddra bland installerade Skills efter globalt omfång eller projekt, sök i inventariet och filtrera efter Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="SkillsGo Library visar globalt installerade Skills och deras Agent-mål">
</p>

### Se konsekvenserna före uppdatering

Se versionsbytet och vilka Skills som tas bort innan du tillämpar en uppdatering av förrådet.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="Förhandsvisning av Library-uppdatering visar versionsbytet och Skills som tas bort">
</p>

<details>
  <summary><strong>Visa ett projektavgränsat Library</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="SkillsGo Library visar Skills installerade i ett valt projekt">
  </p>
</details>

## Varför SkillsGo

- **Verkliga källbevis** — kontrollera förrådets identitet, version, `SKILL.md`, filer och risker före installation.
- **Tydliga Agent-mål** — installera Skills globalt eller per projekt för valda Agents utan att kopiera filer manuellt.
- **Verifierbar distribution** — behandla en version av källkodsförrådet som en oföränderlig distributionsenhet.
- **Lokal hantering först** — kontrollera och hantera det lokala inventariet säkert även när Hub inte är tillgänglig.
- **Två ändamålsenliga gränssnitt** — använd App för interaktiva personliga flöden och CLI för CI/CD, automatisering och enhetliga Skill-miljöer.

## Så fungerar det

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo-flöde: upptäck, kontrollera, välj mål, installera och hantera">
</p>

Den offentliga Huben är den gemensamma källan för Skill-identitet, oföränderliga versioner, metadata, sökning och upptäckt. App kopplar människor till Hub genom ett visuellt flöde; CLI kopplar automatisering och CI/CD till samma Hub så att valet av Skills förblir enhetligt mellan miljöer.

## Utforska monorepot

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Läs [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) för produktgränser och domänspråk.

## Kör lokalt

Den enhetliga utvecklingstopologin riktar sig för närvarande till macOS och kräver Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) och [Air](https://github.com/air-verse/air).

```bash
make dev
```

Kommandot startar PostgreSQL, den lokala Huben, ett nybyggt CLI och Flutter-desktop-Appen i en övervakad session. Verifiera alla konfigurerade arbetsytor med:

```bash
make test
```

Varje arbetsyta har också en egen startpunkt:

| Arbetsyta | Utveckling eller verifiering |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Läs [CONTRIBUTING.md](../../CONTRIBUTING.md) innan du ändrar produktens beteende.

## Projektstatus

SkillsGo förbereder sina första versioner. Hubens releasepipeline definieras först; signerade och notariserade App-versioner och fristående CLI-distribution följer egna beredskapskrav. Se [releaseutformningen](../release-design.md) för stödda releaseenheter, artefaktintegritet och krav på leveranskedjan.

## Community

- Använd [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) för frågor, felsökning och tidiga idéer.
- Använd de särskilda [issueformulären](https://github.com/skillsgo/skillsgo/issues/new/choose) för reproducerbara fel, konkreta funktionsförslag och dokumentationsproblem.
- Följ [SECURITY.md](../../SECURITY.md) för att rapportera sårbarheter privat.
- Deltagande regleras av [uppförandekoden](../../CODE_OF_CONDUCT.md) och [styrningsmodellen](../../GOVERNANCE.md).

## Licens

SkillsGo licensieras under [Apache License 2.0](../../LICENSE).

Hub innehåller kod som härrör från [Athens](https://github.com/gomods/athens); den omfattas fortsatt av Athens MIT License och tillhörande erkännanden. Se [`NOTICE`](../../NOTICE) och [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
