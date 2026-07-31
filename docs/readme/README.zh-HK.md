<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo——探索、驗證及管理 Agent Skills">
</p>

<!-- README-I18N:START -->

  <p>
    <a href="../../README.md">English</a> ·
    <a href="./README.zh-CN.md">简体中文</a> ·
    <a href="./README.zh-TW.md">繁體中文（台灣）</a> ·
    <strong>繁體中文（香港）</strong> ·
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
<!-- README-I18N:END -->

SkillsGo 是一個用於探索及管理 Agent Skills 的開放生態系統。桌面 App 為用戶提供視覺化的 Skill 探索與管理體驗，CLI 則將同一個 Hub 目錄帶入 CI/CD 及可重現的環境工作流程。

## 實際體驗 SkillsGo

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="SkillsGo 桌面 App 顯示來自公開 Hub 即時排行榜的 Agent Skills">
</p>

桌面 App 將探索、來源證據、安裝目標及本機清單串連成一套易用流程。個人使用毋須帳戶。

### 從 Hub 探索 Skills

按 Skill 或來源儲存庫搜尋、瀏覽即時排行榜，並安裝單一 Skill 或整個集合。

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="SkillsGo Discover 搜尋結果顯示一個來源儲存庫及其可用的 Agent Skills">
</p>

### 安裝前先作檢查

變更本機環境前，先查看來源儲存庫、不可變的發佈版本、支援的 Agents、翻譯摘要及經過算繪的 `SKILL.md`。

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="SkillsGo Skill 詳情顯示來源證據、版本、支援的 Agents 及經過算繪的說明">
</p>

### 準確選擇 Skills 的安裝位置

安裝至全域或指定項目，再選擇應接收相同 Skill 發佈版本的 Agent 目標。

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="SkillsGo 安裝目標選擇器顯示指定項目及多個 Agent 目標">
</p>

### 管理統一的本機 Library

按全域或項目範圍瀏覽已安裝的 Skills、搜尋本機清單，並按 Agent 篩選。

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="SkillsGo Library 顯示全域安裝的 Skills 及其 Agent 目標">
</p>

### 更新前看清影響

套用儲存庫更新前，查看版本變更及任何將被移除的 Skills。

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="SkillsGo Library 更新預覽顯示版本變更及將被移除的 Skills">
</p>

<details>
  <summary><strong>查看項目範圍的 Library</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="SkillsGo Library 顯示為指定項目安裝的 Skills">
  </p>
</details>

## 為何選擇 SkillsGo

- **真實的來源證據**——安裝前檢查儲存庫身份、版本、`SKILL.md`、檔案及風險。
- **明確的 Agent 目標**——將 Skills 安裝至全域或項目範圍內選定的 Agents，毋須手動複製檔案。
- **可驗證的發佈方式**——將來源儲存庫的發佈版本視為不可變的發佈單元。
- **本機優先的管理**——即使 Hub 無法使用，仍可檢查並安全管理本機清單。
- **兩種專用操作介面**——App 適合個人互動流程，CLI 則用於 CI/CD、自動化及一致的 Skill 環境。

## 運作方式

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo 工作流程：探索、檢查、選擇目標、安裝及管理">
</p>

公開 Hub 是 Skill 身份、不可變發佈版本、中繼資料、搜尋及探索功能的共同來源。App 透過視覺化流程將用戶連接至 Hub；CLI 將自動化及 CI/CD 連接至同一個 Hub，讓不同環境中的 Skill 選擇保持一致。

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

產品邊界及領域用語請參閱 [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md)。

## 在本機執行

統一開發拓撲目前以 macOS 為目標，並需要 Flutter、Go、Docker、[Process Compose](https://github.com/F1bonacc1/process-compose) 及 [Air](https://github.com/air-verse/air)。

```bash
make dev
```

此指令會在同一個受監督的工作階段中啟動 PostgreSQL、本機 Hub、新建置的 CLI 及 Flutter 桌面 App。若要驗證所有已設定的工作區：

```bash
make test
```

每個工作區亦提供各自的入口：

| 工作區 | 開發或驗證 |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

變更產品行為前，請先閱讀 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## 項目狀態

SkillsGo 正在為首批發佈版本作準備。Hub 的發佈流程會率先定義；經過簽署及公證的 App 發佈版本，以及獨立 CLI 發佈，均有各自的就緒門檻。支援的發佈單元、製品完整性及供應鏈要求請參閱[發佈設計](../release-design.md)。

## 社群

- 使用 [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) 提問、疑難排解及交流早期構想。
- 使用針對特定情況的 [issue 表格](https://github.com/skillsgo/skillsgo/issues/new/choose)回報可重現的錯誤、明確的功能需求及文件問題。
- 按照 [SECURITY.md](../../SECURITY.md) 的說明私下回報安全漏洞。
- 參與本項目須遵守[行為準則](../../CODE_OF_CONDUCT.md)及[管治模式](../../GOVERNANCE.md)。

## 授權條款

SkillsGo 採用 [Apache License 2.0](../../LICENSE)。

Hub 包含衍生自 [Athens](https://github.com/gomods/athens) 的程式碼，該程式碼仍受 Athens MIT License 及署名聲明約束。詳情請參閱 [`NOTICE`](../../NOTICE) 及 [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE)。
