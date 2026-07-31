<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — scopri, verifica e gestisci gli Agent Skills">
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
    <strong>Italiano</strong> ·
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

SkillsGo è un ecosistema aperto per scoprire e gestire gli Agent Skills. L’App desktop offre alle persone un percorso visuale per scoprire e gestire gli Skills, mentre la CLI porta lo stesso catalogo Hub nei flussi CI/CD e negli ambienti riproducibili.

## SkillsGo in azione

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="L’App desktop SkillsGo mostra gli Agent Skills dalla classifica in tempo reale dell’Hub pubblico">
</p>

L’App desktop unisce scoperta, prove sulla provenienza, destinazioni di installazione e inventario locale in un unico percorso intuitivo. Per l’uso personale non è necessario un account.

### Scopri dall’Hub

Cerca uno Skill o un repository sorgente, esplora la classifica in tempo reale e installa un singolo Skill o un’intera raccolta.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="La ricerca Discover di SkillsGo mostra un repository sorgente e gli Agent Skills disponibili">
</p>

### Verifica prima di installare

Prima di modificare il sistema locale, controlla il repository sorgente, la release immutabile, gli Agents supportati, il riepilogo tradotto e il file `SKILL.md` renderizzato.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="Il dettaglio di uno Skill mostra provenienza, versione, Agents supportati e istruzioni renderizzate">
</p>

### Scegli con precisione dove installare gli Skills

Installa a livello globale o nei progetti selezionati, quindi scegli gli Agents che devono ricevere la stessa release dello Skill.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="Il selettore delle destinazioni di SkillsGo mostra i progetti selezionati e più Agents">
</p>

### Gestisci un’unica Library locale

Esplora gli Skills installati per ambito globale o per progetto, cerca nell’inventario e filtra per Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="La Library di SkillsGo mostra gli Skills installati globalmente e i relativi Agents">
</p>

### Controlla le conseguenze prima di aggiornare

Visualizza il passaggio di versione e gli Skills che verranno rimossi prima di applicare un aggiornamento del repository.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="L’anteprima di aggiornamento della Library mostra il passaggio di versione e gli Skills da rimuovere">
</p>

<details>
  <summary><strong>Visualizza una Library limitata a un progetto</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="La Library di SkillsGo mostra gli Skills installati nel progetto selezionato">
  </p>
</details>

## Perché SkillsGo

- **Prove reali sulla provenienza** — controlla identità del repository, versione, `SKILL.md`, file e rischi prima dell’installazione.
- **Destinazioni Agent esplicite** — installa gli Skills a livello globale o di progetto per gli Agents selezionati, senza copiare manualmente i file.
- **Distribuzione verificabile** — considera una release del repository sorgente come un’unità di distribuzione immutabile.
- **Gestione locale prioritaria** — controlla e gestisci in sicurezza l’inventario locale anche quando l’Hub non è disponibile.
- **Due interfacce dedicate** — usa l’App per i flussi personali interattivi e la CLI per CI/CD, automazione e ambienti Skill coerenti.

## Come funziona

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="Flusso SkillsGo: scopri, verifica, scegli le destinazioni, installa e gestisci">
</p>

L’Hub pubblico è la fonte condivisa per identità degli Skills, release immutabili, metadati, ricerca e scoperta. L’App collega le persone all’Hub tramite un flusso visuale; la CLI collega automazione e CI/CD allo stesso Hub per mantenere coerenti le scelte degli Skills tra gli ambienti.

## Esplora il monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Consulta [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) per i confini del prodotto e il linguaggio del dominio.

## Esegui in locale

La topologia di sviluppo unificata è attualmente destinata a macOS e richiede Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) e [Air](https://github.com/air-verse/air).

```bash
make dev
```

Il comando avvia PostgreSQL, l’Hub locale, una CLI appena compilata e l’App desktop Flutter in un’unica sessione supervisionata. Per verificare tutti i workspace configurati:

```bash
make test
```

Ogni workspace dispone anche di un proprio punto di ingresso:

| Workspace | Sviluppo o verifica |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Consulta [CONTRIBUTING.md](../../CONTRIBUTING.md) prima di modificare il comportamento del prodotto.

## Stato del progetto

SkillsGo sta preparando le prime release. La pipeline di release dell’Hub viene definita per prima; le release dell’App firmate e notarizzate e la distribuzione autonoma della CLI seguono criteri di disponibilità specifici. Consulta il [progetto delle release](../release-design.md) per unità supportate, integrità degli artefatti e requisiti della catena di fornitura.

## Community

- Usa [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) per domande, risoluzione dei problemi e idee iniziali.
- Usa i [moduli issue](https://github.com/skillsgo/skillsgo/issues/new/choose) dedicati per bug riproducibili, richieste concrete di funzionalità e problemi di documentazione.
- Segui [SECURITY.md](../../SECURITY.md) per segnalare privatamente le vulnerabilità.
- La partecipazione è regolata dal [Codice di condotta](../../CODE_OF_CONDUCT.md) e dal [modello di governance](../../GOVERNANCE.md).

## Licenza

SkillsGo è distribuito con [Apache License 2.0](../../LICENSE).

L’Hub contiene codice derivato da [Athens](https://github.com/gomods/athens), che rimane soggetto alla Athens MIT License e alle relative note di attribuzione. Consulta [`NOTICE`](../../NOTICE) e [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
