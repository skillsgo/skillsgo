<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — descubra, verifique e gerencie Agent Skills">
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
    <strong>Português (Brasil)</strong> ·
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

SkillsGo é um ecossistema aberto para descobrir e gerenciar Agent Skills. O App para desktop oferece às pessoas uma forma visual de descobrir e gerenciar Skills, enquanto a CLI leva o mesmo catálogo do Hub para CI/CD e fluxos de ambientes reproduzíveis.

## SkillsGo em ação

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="O App para desktop SkillsGo mostra Agent Skills do ranking ao vivo do Hub público">
</p>

O App para desktop reúne descoberta, evidências da origem, destinos de instalação e inventário local em uma jornada simples. O uso pessoal não exige uma conta.

### Descubra pelo Hub

Pesquise por Skill ou repositório de origem, explore o ranking ao vivo e instale um Skill ou uma coleção inteira.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="A pesquisa Discover do SkillsGo mostra um repositório de origem e seus Agent Skills disponíveis">
</p>

### Verifique antes de instalar

Antes de fazer alterações locais, analise o repositório de origem, a versão imutável, os Agents compatíveis, o resumo traduzido e o arquivo `SKILL.md` renderizado.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="Os detalhes de um Skill mostram origem, versão, Agents compatíveis e instruções renderizadas">
</p>

### Escolha exatamente onde instalar os Skills

Instale globalmente ou nos projetos selecionados e escolha os Agents que devem receber a mesma versão do Skill.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="O seletor de destinos do SkillsGo mostra projetos selecionados e vários Agents">
</p>

### Gerencie uma única Library local

Explore os Skills instalados por escopo global ou de projeto, pesquise no inventário e filtre por Agent.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="A Library do SkillsGo mostra Skills instalados globalmente e seus Agents de destino">
</p>

### Veja as consequências antes de atualizar

Confira a mudança de versão e os Skills que serão removidos antes de aplicar uma atualização do repositório.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="A prévia de atualização da Library mostra a mudança de versão e os Skills que serão removidos">
</p>

<details>
  <summary><strong>Veja uma Library limitada a um projeto</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="A Library do SkillsGo mostra os Skills instalados em um projeto selecionado">
  </p>
</details>

## Por que usar o SkillsGo

- **Evidências reais da origem** — confira a identidade do repositório, a versão, o `SKILL.md`, os arquivos e os riscos antes da instalação.
- **Destinos Agent explícitos** — instale Skills globalmente ou por projeto para os Agents selecionados, sem copiar arquivos manualmente.
- **Distribuição verificável** — trate uma versão do repositório de origem como uma unidade de distribuição imutável.
- **Gerenciamento local em primeiro lugar** — confira e gerencie o inventário local com segurança mesmo quando o Hub estiver indisponível.
- **Duas interfaces para finalidades específicas** — use o App em fluxos pessoais interativos e a CLI em CI/CD, automação e ambientes Skill consistentes.

## Como funciona

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="Fluxo do SkillsGo: descobrir, verificar, escolher destinos, instalar e gerenciar">
</p>

O Hub público é a fonte compartilhada para identidade dos Skills, versões imutáveis, metadados, pesquisa e descoberta. O App conecta as pessoas ao Hub por meio de um fluxo visual; a CLI conecta automação e CI/CD ao mesmo Hub para manter as escolhas de Skills consistentes entre ambientes.

## Explore o monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

Consulte [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) para entender os limites do produto e a linguagem do domínio.

## Execute localmente

A topologia de desenvolvimento unificada atualmente tem como alvo o macOS e requer Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose) e [Air](https://github.com/air-verse/air).

```bash
make dev
```

Esse comando inicia PostgreSQL, o Hub local, uma CLI recém-compilada e o App Flutter para desktop em uma única sessão supervisionada. Para validar todos os workspaces configurados:

```bash
make test
```

Cada workspace também tem seu próprio ponto de entrada:

| Workspace | Desenvolvimento ou validação |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

Consulte [CONTRIBUTING.md](../../CONTRIBUTING.md) antes de alterar o comportamento do produto.

## Status do projeto

SkillsGo está preparando suas primeiras versões. O pipeline de lançamento do Hub é definido primeiro; as versões assinadas e notarizadas do App e a distribuição independente da CLI seguem seus próprios critérios de prontidão. Consulte o [projeto de lançamento](../release-design.md) para conhecer as unidades compatíveis, a integridade dos artefatos e os requisitos da cadeia de suprimentos.

## Comunidade

- Use [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) para perguntas, solução de problemas e ideias iniciais.
- Use os [formulários de issue](https://github.com/skillsgo/skillsgo/issues/new/choose) específicos para bugs reproduzíveis, solicitações concretas de funcionalidades e problemas de documentação.
- Siga [SECURITY.md](../../SECURITY.md) para relatar vulnerabilidades de forma privada.
- A participação é regida pelo [Código de Conduta](../../CODE_OF_CONDUCT.md) e pelo [modelo de governança](../../GOVERNANCE.md).

## Licença

SkillsGo é licenciado sob a [Apache License 2.0](../../LICENSE).

O Hub contém código derivado do [Athens](https://github.com/gomods/athens), que continua sujeito à Athens MIT License e aos avisos de atribuição. Consulte [`NOTICE`](../../NOTICE) e [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE).
