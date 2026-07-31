<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo——探索、驗證並管理 Agent Skills">
</p>

<!-- README-I18N:START -->

<details>
  <summary><strong>繁體中文（台灣）</strong> · 語言</summary>
  <br>
  <p>
    <a href="../../README.md">English</a> ·
    <a href="./README.zh-CN.md">简体中文</a> ·
    <strong>繁體中文（台灣）</strong> ·
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
    <a href="./README.uk.md">Українська</a>
  </p>
</details>

<!-- README-I18N:END -->

SkillsGo 是一個用於探索及管理 Agent Skills 的開放生態系。桌面 App 為使用者提供視覺化的 Skill 探索與管理體驗，CLI 則將同一份 Hub 目錄帶入 CI/CD 與可重現的環境工作流程。

> [!IMPORTANT]
> SkillsGo 仍處於積極開發的預發行階段。在第一個穩定版本推出前，公開協定、持久化格式及安裝行為都可能變更。

## 實際體驗 SkillsGo

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="SkillsGo 桌面 App 顯示來自公開 Hub 即時排行榜的 Agent Skills">
</p>

桌面 App 將探索、來源證據、安裝目標與本機清單串成一套易於使用的流程。個人使用不需要帳號。

### 從 Hub 探索 Skills

依 Skill 或來源儲存庫搜尋、瀏覽即時排行榜，並安裝單一 Skill 或整個集合。

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="SkillsGo Discover 搜尋結果顯示一個來源儲存庫及其可用的 Agent Skills">
</p>

### 安裝前先檢查

變更本機環境前，先查看來源儲存庫、不可變發行版本、支援的 Agents、翻譯摘要，以及算繪後的 `SKILL.md`。

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="SkillsGo Skill 詳細資料顯示來源證據、版本、支援的 Agents 與算繪後的說明">
</p>

### 精確選擇 Skills 的安裝位置

安裝至全域或指定專案，再選擇應接收相同 Skill 發行版本的 Agent 目標。

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="SkillsGo 安裝目標選擇器顯示指定專案與多個 Agent 目標">
</p>

### 管理統一的本機 Library

依全域或專案範圍瀏覽已安裝的 Skills、搜尋本機清單，並依 Agent 篩選。

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="SkillsGo Library 顯示全域安裝的 Skills 及其 Agent 目標">
</p>

### 更新前看清影響

套用儲存庫更新前，查看版本變更及任何將被移除的 Skills。

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="SkillsGo Library 更新預覽顯示版本變更與將被移除的 Skills">
</p>

<details>
  <summary><strong>查看專案範圍的 Library</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="SkillsGo Library 顯示為指定專案安裝的 Skills">
  </p>
</details>

## 為什麼選擇 SkillsGo

- **真實的來源證據**——安裝前檢查儲存庫身分、版本、`SKILL.md`、檔案與風險。
- **明確的 Agent 目標**——將 Skills 安裝至全域或專案範圍內選定的 Agents，不必手動複製檔案。
- **可驗證的散布方式**——將來源儲存庫的發行版本視為不可變的散布單元。
- **本機優先的管理**——即使 Hub 無法使用，也能檢查並安全管理本機清單。
- **兩種專用操作介面**——App 適合個人互動流程，CLI 則用於 CI/CD、自動化及一致的 Skill 環境。

## 運作方式

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo 工作流程：探索、檢查、選擇目標、安裝與管理">
</p>

公開 Hub 是 Skill 身分、不可變發行版本、中繼資料、搜尋與探索功能的共同來源。App 透過視覺化流程將使用者連接至 Hub；CLI 將自動化與 CI/CD 連接至同一個 Hub，讓不同環境中的 Skill 選擇保持一致。

## 瀏覽 monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

產品邊界與領域用語請參閱 [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md)。

## 在本機執行

統一開發拓撲目前以 macOS 為目標，並需要 Flutter、Go、Docker、[Process Compose](https://github.com/F1bonacc1/process-compose) 與 [Air](https://github.com/air-verse/air)。

```bash
make dev
```

此指令會在同一個受監督的工作階段中啟動 PostgreSQL、本機 Hub、新建置的 CLI 與 Flutter 桌面 App。若要驗證所有已設定的工作區：

```bash
make test
```

每個工作區也提供各自的進入點：

| 工作區 | 開發或驗證 |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

變更產品行為前，請先閱讀 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## 專案狀態

SkillsGo 正在為第一批發行版本做準備。Hub 的發行管線會先行定義；經過簽署與公證的 App 發行版本，以及獨立 CLI 散布，都有各自的就緒門檻。支援的發行單元、成品完整性與供應鏈需求請參閱[發行設計](../release-design.md)。

## 社群

- 使用 [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) 提問、疑難排解及交流早期構想。
- 使用針對特定情境的 [issue 表單](https://github.com/skillsgo/skillsgo/issues/new/choose)回報可重現的錯誤、明確的功能需求與文件問題。
- 依照 [SECURITY.md](../../SECURITY.md) 的說明私下回報安全漏洞。
- 參與本專案須遵守[行為準則](../../CODE_OF_CONDUCT.md)與[治理模式](../../GOVERNANCE.md)。

## 授權條款

SkillsGo 採用 [Apache License 2.0](../../LICENSE)。

Hub 包含衍生自 [Athens](https://github.com/gomods/athens) 的程式碼，該程式碼仍受 Athens MIT License 與署名聲明約束。詳細資訊請參閱 [`NOTICE`](../../NOTICE) 與 [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE)。
