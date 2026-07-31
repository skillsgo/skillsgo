<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — découvrir, vérifier et gérer des Agent Skills">
</p>

<!-- README-I18N:START -->

<details>
  <summary><strong>Français</strong> · Langues</summary>
  <br>
  <p>
    <a href="../../README.md">English</a> ·
    <a href="./README.zh-CN.md">简体中文</a> ·
    <a href="./README.zh-TW.md">繁體中文（台灣）</a> ·
    <a href="./README.zh-HK.md">繁體中文（香港）</a> ·
    <a href="./README.ja.md">日本語</a> ·
    <a href="./README.ko.md">한국어</a> ·
    <strong>Français</strong> ·
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
    <a href="./README.uk.md">Українська</a>
  </p>
</details>

<!-- README-I18N:END -->

SkillsGo est un écosystème ouvert permettant de découvrir et de gérer des Agent Skills. L’App de bureau offre aux utilisateurs un parcours visuel pour découvrir et gérer leurs Skills, tandis que le CLI relie le même catalogue Hub aux pipelines CI/CD et aux environnements reproductibles.

> [!IMPORTANT]
> SkillsGo est en développement actif avant sa première version stable. Les protocoles publics, les formats persistants et le comportement d’installation sont susceptibles d’évoluer.

## SkillsGo en action

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="L’App de bureau SkillsGo affiche des Agent Skills provenant du classement en direct du Hub public">
</p>

L’App de bureau réunit la découverte, les preuves liées à la source, les cibles d’installation et l’inventaire local dans un parcours simple. Aucun compte n’est nécessaire pour un usage personnel.

### Découvrir depuis le Hub

Recherchez un Skill ou un dépôt source, parcourez le classement en direct, puis installez un Skill ou une collection complète.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="La recherche Discover de SkillsGo affiche un dépôt source et ses Agent Skills disponibles">
</p>

### Vérifier avant d’installer

Avant toute modification locale, examinez le dépôt source, la version immuable, les Agents compatibles, le résumé traduit et le fichier `SKILL.md` rendu.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="La fiche d’un Skill dans SkillsGo affiche la source, la version, les Agents compatibles et les instructions rendues">
</p>

### Choisir précisément la destination des Skills

Installez-les globalement ou dans les projets sélectionnés, puis choisissez les Agents qui doivent recevoir la même version du Skill.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="Le sélecteur de cibles SkillsGo affiche des projets sélectionnés et plusieurs Agents">
</p>

### Gérer une bibliothèque locale unique

Parcourez les Skills installés par portée globale ou par projet, recherchez dans l’inventaire et filtrez par Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="La Library SkillsGo affiche les Skills installés globalement et leurs Agents cibles">
</p>

### Voir les conséquences avant la mise à jour

Consultez le changement de version et les Skills qui seront supprimés avant d’appliquer une mise à jour du dépôt.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="L’aperçu de mise à jour de la Library SkillsGo affiche le changement de version et les Skills supprimés">
</p>

<details>
  <summary><strong>Voir une Library limitée à un projet</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="La Library SkillsGo affiche les Skills installés dans un projet sélectionné">
  </p>
</details>

## Pourquoi SkillsGo

- **Des preuves issues de la source** — vérifiez l’identité du dépôt, la version, le fichier `SKILL.md`, les fichiers et les risques avant l’installation.
- **Des cibles Agent explicites** — installez les Skills globalement ou dans un projet pour les Agents sélectionnés, sans copier les fichiers à la main.
- **Une distribution vérifiable** — traitez chaque version d’un dépôt source comme une unité de distribution immuable.
- **Une gestion locale en priorité** — examinez et gérez l’inventaire local en toute sécurité, même lorsque le Hub est indisponible.
- **Deux interfaces conçues pour leur usage** — l’App répond aux parcours personnels interactifs ; le CLI couvre le CI/CD, l’automatisation et la cohérence des environnements Skill.

## Fonctionnement

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="Parcours SkillsGo : découvrir, vérifier, choisir les cibles, installer et gérer">
</p>

Le Hub public constitue la source commune pour l’identité des Skills, les versions immuables, les métadonnées, la recherche et la découverte. L’App relie les utilisateurs au Hub par un parcours visuel ; le CLI relie l’automatisation et le CI/CD au même Hub afin de conserver des choix de Skills cohérents entre les environnements.

## Explorer le monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Consultez [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) pour les limites du produit et le vocabulaire du domaine.

## Exécuter le projet localement

La topologie de développement unifiée cible actuellement macOS et nécessite Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) et [Air](https://github.com/air-verse/air).

```bash
make dev
```

Cette commande démarre PostgreSQL, le Hub local, un CLI fraîchement compilé et l’App de bureau Flutter dans une même session supervisée. Pour vérifier tous les espaces de travail configurés :

```bash
make test
```

Chaque espace de travail possède également son propre point d’entrée :

| Espace de travail | Développement ou validation |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Consultez [CONTRIBUTING.md](../../CONTRIBUTING.md) avant de modifier le comportement du produit.

## État du projet

SkillsGo prépare ses premières versions. Le pipeline de publication du Hub est défini en premier ; les versions signées et notariées de l’App ainsi que la distribution autonome du CLI suivent leurs propres critères de disponibilité. Consultez la [conception des versions](../release-design.md) pour connaître les unités prises en charge, l’intégrité des artefacts et les exigences de la chaîne d’approvisionnement.

## Communauté

- Utilisez [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) pour les questions, le dépannage et les premières idées.
- Utilisez les [formulaires d’issue](https://github.com/skillsgo/skillsgo/issues/new/choose) dédiés aux bogues reproductibles, aux demandes de fonctionnalités concrètes et aux problèmes de documentation.
- Suivez [SECURITY.md](../../SECURITY.md) pour signaler une vulnérabilité de manière privée.
- Toute participation est régie par le [Code de conduite](../../CODE_OF_CONDUCT.md) et le [modèle de gouvernance](../../GOVERNANCE.md).

## Licence

SkillsGo est distribué sous [Apache License 2.0](../../LICENSE).

Le Hub contient du code dérivé d’[Athens](https://github.com/gomods/athens), qui reste soumis à Athens MIT License et à ses mentions d’attribution. Consultez [`NOTICE`](../../NOTICE) et [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
