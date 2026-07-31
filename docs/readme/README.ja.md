<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — Agent Skills を見つけ、検証し、管理">
</p>

<!-- README-I18N:START -->

<details>
  <summary><strong>日本語</strong> · 言語</summary>
  <br>
  <p>
    <a href="../../README.md">English</a> ·
    <a href="./README.zh-CN.md">简体中文</a> ·
    <a href="./README.zh-TW.md">繁體中文（台灣）</a> ·
    <a href="./README.zh-HK.md">繁體中文（香港）</a> ·
    <strong>日本語</strong> ·
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
    <a href="./README.uk.md">Українська</a>
  </p>
</details>

<!-- README-I18N:END -->

SkillsGo は、Agent Skills を見つけて管理するためのオープンなエコシステムです。デスクトップ App は、人が Skills を見つけて管理するための視覚的な操作環境を提供します。CLI は同じ Hub カタログを CI/CD と再現可能な環境ワークフローで利用できるようにします。

> [!IMPORTANT]
> SkillsGo はプレリリース段階で活発に開発されています。最初の安定版が公開されるまで、公開プロトコル、永続化形式、インストール動作が変更される可能性があります。

## SkillsGo の動作を見る

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="公開 Hub のリアルタイムランキングから Agent Skills を表示する SkillsGo デスクトップ App">
</p>

デスクトップ App は、発見、ソースの根拠、インストール先、ローカルインベントリを、分かりやすい一つの流れにまとめます。個人利用にアカウントは必要ありません。

### Hub から見つける

Skill またはソースリポジトリで検索し、リアルタイムランキングを確認して、単一の Skill またはコレクション全体をインストールできます。

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="ソースリポジトリと利用可能な Agent Skills を表示する SkillsGo Discover の検索結果">
</p>

### インストール前に確認

ローカル環境を変更する前に、ソースリポジトリ、変更不能なリリース、対応 Agents、翻訳された概要、レンダリング済みの `SKILL.md` を確認できます。

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="ソースの根拠、バージョン、対応 Agents、レンダリング済み手順を表示する SkillsGo の Skill 詳細">
</p>

### Skills の配置先を正確に選択

グローバルまたは選択したプロジェクトへインストールし、同じ Skill リリースを配置する Agent を選択します。

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="選択したプロジェクトと複数の Agent を表示する SkillsGo のインストール先選択画面">
</p>

### 一つのローカル Library で管理

インストール済み Skills をグローバルまたはプロジェクト単位で確認し、インベントリを検索して Agent で絞り込めます。

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="グローバルにインストールされた Skills と Agent の配置先を表示する SkillsGo Library">
</p>

### 影響を確認してから更新

リポジトリの更新を適用する前に、バージョンの移行と削除される Skills を確認できます。

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="バージョンの移行と削除される Skills を表示する SkillsGo Library の更新プレビュー">
</p>

<details>
  <summary><strong>プロジェクト単位の Library を見る</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="選択したプロジェクトにインストールされた Skills を表示する SkillsGo Library">
  </p>
</details>

## SkillsGo を選ぶ理由

- **実際のソース根拠** — インストール前にリポジトリの識別情報、バージョン、`SKILL.md`、ファイル、リスクを確認できます。
- **明確な Agent 配置先** — ファイルを手作業でコピーせず、選択した Agents へグローバルまたはプロジェクト単位でインストールできます。
- **検証可能な配布** — ソースリポジトリのリリースを変更不能な配布単位として扱います。
- **ローカル優先の管理** — Hub が利用できないときでも、ローカルインベントリを確認して安全に管理できます。
- **用途に合わせた二つのインターフェース** — App は対話的な個人ワークフロー、CLI は CI/CD、自動化、一貫した Skill 環境に適しています。

## 仕組み

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo のワークフロー：発見、確認、配置先の選択、インストール、管理">
</p>

公開 Hub は、Skill の識別情報、変更不能なリリース、メタデータ、検索、発見機能を共有する情報源です。App は視覚的なワークフローで人を Hub につなぎ、CLI は自動化と CI/CD を同じ Hub につなぐことで、環境間で Skill の選択を統一します。

## monorepo を見る

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

製品境界とドメイン用語については、[`CONTEXT-MAP.md`](../../CONTEXT-MAP.md) を参照してください。

## ローカルで実行

統合開発構成は現在 macOS を対象としており、Flutter、Go、Docker、[Process Compose](https://github.com/F1bonacc1/process-compose)、[Air](https://github.com/air-verse/air) が必要です。

```bash
make dev
```

このコマンドは、PostgreSQL、ローカル Hub、新しくビルドした CLI、Flutter デスクトップ App を一つの監視セッションで起動します。設定済みの全ワークスペースを検証するには、次を実行します。

```bash
make test
```

各ワークスペースには個別のエントリポイントもあります。

| ワークスペース | 開発または検証 |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

製品の動作を変更する前に、[CONTRIBUTING.md](../../CONTRIBUTING.md) を参照してください。

## プロジェクトの状況

SkillsGo は最初のリリースに向けて準備中です。Hub のリリースパイプラインを先に定義し、署名・公証済み App リリースと単独の CLI 配布には、それぞれ固有の準備基準を設けます。対応するリリース単位、成果物の完全性、サプライチェーン要件については、[リリース設計](../release-design.md)を参照してください。

## コミュニティ

- 質問、トラブルシューティング、初期段階のアイデアには [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) を利用してください。
- 再現可能な不具合、具体的な機能要望、ドキュメントの問題には、目的別の [issue フォーム](https://github.com/skillsgo/skillsgo/issues/new/choose)を利用してください。
- 脆弱性を非公開で報告するには、[SECURITY.md](../../SECURITY.md) に従ってください。
- 参加者には、[行動規範](../../CODE_OF_CONDUCT.md)と[ガバナンスモデル](../../GOVERNANCE.md)が適用されます。

## ライセンス

SkillsGo は [Apache License 2.0](../../LICENSE) の下で提供されます。

Hub には [Athens](https://github.com/gomods/athens) から派生したコードが含まれ、そのコードには引き続き Athens MIT License と帰属表示が適用されます。詳しくは [`NOTICE`](../../NOTICE) と [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE) を参照してください。
