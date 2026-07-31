<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — ontdek, verifieer en beheer Agent Skills">
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
    <strong>Nederlands</strong> ·
    <a href="./README.pl.md">Polski</a> ·
    <a href="./README.th.md">ไทย</a> ·
    <a href="./README.vi.md">Tiếng Việt</a> ·
    <a href="./README.ms.md">Bahasa Melayu</a> ·
    <a href="./README.sv.md">Svenska</a> ·
    <a href="./README.uk.md">Українська</a>
  </p>
<!-- README-I18N:END -->

SkillsGo is een open ecosysteem voor het ontdekken en beheren van Agent Skills. De desktop-App biedt mensen een visuele manier om Skills te ontdekken en beheren, terwijl de CLI dezelfde Hub-catalogus inzet voor CI/CD en reproduceerbare omgevingsworkflows.

## Bekijk SkillsGo in actie

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="De SkillsGo desktop-App toont Agent Skills uit de live ranglijst van de openbare Hub">
</p>

De desktop-App brengt ontdekking, bronbewijs, installatiedoelen en lokale inventaris samen in één begrijpelijke route. Voor persoonlijk gebruik is geen account nodig.

### Ontdek via de Hub

Zoek op Skill of bronrepository, bekijk de live ranglijst en installeer één Skill of een volledige verzameling.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="De Discover-zoekfunctie van SkillsGo toont een bronrepository en de beschikbare Agent Skills">
</p>

### Controleer vóór installatie

Bekijk de bronrepository, onveranderlijke release, ondersteunde Agents, vertaalde samenvatting en gerenderde `SKILL.md` voordat je lokaal iets wijzigt.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="De Skill-details tonen bronbewijs, versie, ondersteunde Agents en gerenderde instructies">
</p>

### Kies precies waar Skills terechtkomen

Installeer wereldwijd of in geselecteerde projecten en kies vervolgens de Agents die dezelfde Skill-release moeten ontvangen.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="De installatiedoelkiezer van SkillsGo toont geselecteerde projecten en meerdere Agents">
</p>

### Beheer één lokale Library

Bekijk geïnstalleerde Skills per wereldwijd of projectbereik, doorzoek de inventaris en filter op Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="De SkillsGo Library toont wereldwijd geïnstalleerde Skills en hun Agent-doelen">
</p>

### Bekijk de gevolgen vóór een update

Bekijk de versiewijziging en de Skills die worden verwijderd voordat je een repository-update toepast.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="Het updatevoorbeeld van de Library toont de versiewijziging en te verwijderen Skills">
</p>

<details>
  <summary><strong>Bekijk een projectgebonden Library</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="De SkillsGo Library toont Skills die in een geselecteerd project zijn geïnstalleerd">
  </p>
</details>

## Waarom SkillsGo

- **Echt bronbewijs** — controleer repository-identiteit, versie, `SKILL.md`, bestanden en risico’s vóór installatie.
- **Expliciete Agent-doelen** — installeer Skills wereldwijd of per project voor geselecteerde Agents zonder bestanden handmatig te kopiëren.
- **Verifieerbare distributie** — behandel een release van de bronrepository als een onveranderlijke distributie-eenheid.
- **Lokaal beheer voorop** — controleer en beheer de lokale inventaris veilig, ook wanneer de Hub niet beschikbaar is.
- **Twee doelgerichte interfaces** — gebruik de App voor interactieve persoonlijke workflows en de CLI voor CI/CD, automatisering en consistente Skill-omgevingen.

## Hoe het werkt

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo-workflow: ontdekken, controleren, doelen kiezen, installeren en beheren">
</p>

De openbare Hub is de gedeelde bron voor Skill-identiteit, onveranderlijke releases, metadata, zoeken en ontdekken. De App verbindt mensen via een visuele workflow met de Hub; de CLI verbindt automatisering en CI/CD met dezelfde Hub, zodat Skill-keuzes in alle omgevingen consistent blijven.

## Verken de monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Lees [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) voor productgrenzen en domeintaal.

## Lokaal uitvoeren

De geïntegreerde ontwikkeltopologie richt zich momenteel op macOS en vereist Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) en [Air](https://github.com/air-verse/air).

```bash
make dev
```

Deze opdracht start PostgreSQL, de lokale Hub, een nieuw gebouwde CLI en de Flutter-desktop-App in één bewaakte sessie. Valideer alle geconfigureerde werkruimten met:

```bash
make test
```

Elke werkruimte heeft ook een eigen ingang:

| Werkruimte | Ontwikkeling of validatie |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Lees [CONTRIBUTING.md](../../CONTRIBUTING.md) voordat je productgedrag wijzigt.

## Projectstatus

SkillsGo bereidt de eerste releases voor. De releasepijplijn van de Hub wordt als eerste gedefinieerd; ondertekende en genotariseerde App-releases en zelfstandige CLI-distributie volgen hun eigen gereedheidscriteria. Raadpleeg het [releaseontwerp](../release-design.md) voor ondersteunde release-eenheden, artefactintegriteit en vereisten voor de toeleveringsketen.

## Community

- Gebruik [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) voor vragen, probleemoplossing en vroege ideeën.
- Gebruik de gerichte [issueformulieren](https://github.com/skillsgo/skillsgo/issues/new/choose) voor reproduceerbare fouten, concrete functieverzoeken en documentatieproblemen.
- Volg [SECURITY.md](../../SECURITY.md) om kwetsbaarheden vertrouwelijk te melden.
- Deelname valt onder de [Gedragscode](../../CODE_OF_CONDUCT.md) en het [governancemodel](../../GOVERNANCE.md).

## Licentie

SkillsGo valt onder de [Apache License 2.0](../../LICENSE).

De Hub bevat code die is afgeleid van [Athens](https://github.com/gomods/athens); daarop blijven de Athens MIT License en bijbehorende naamsvermeldingen van toepassing. Zie [`NOTICE`](../../NOTICE) en [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
