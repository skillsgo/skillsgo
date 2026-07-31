<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo——发现、验证和管理 Agent Skills">
</p>

<!-- README-I18N:START -->

<details>
  <summary><strong>简体中文</strong> · 语言</summary>
  <br>
  <p>
    <a href="../../README.md">English</a> ·
    <strong>简体中文</strong> ·
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
    <a href="./README.sv.md">Svenska</a> ·
    <a href="./README.uk.md">Українська</a>
  </p>
</details>

<!-- README-I18N:END -->

SkillsGo 是一个用于发现和管理 Agent Skills 的开放生态系统。桌面 App 为用户提供可视化的 Skill 发现与管理体验，CLI 则把同一个 Hub 目录接入 CI/CD 和可重复的环境工作流。

> [!IMPORTANT]
> SkillsGo 仍处于活跃的预发布开发阶段。在首个稳定版本发布前，公共协议、持久化格式和安装行为可能发生变化。

## 实际体验 SkillsGo

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="SkillsGo 桌面 App 展示来自公共 Hub 实时排行榜的 Agent Skills">
</p>

桌面 App 将发现、来源证据、安装目标和本地清单串联成一条易于使用的流程。个人使用无需账户。

### 从 Hub 发现 Skills

按 Skill 或来源仓库搜索，浏览实时排行榜，并安装单个 Skill 或整个集合。

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="SkillsGo Discover 搜索结果展示一个来源仓库及其可用的 Agent Skills">
</p>

### 安装前先检查

在更改本地环境前，查看来源仓库、不可变版本、支持的 Agents、翻译后的摘要以及渲染后的 `SKILL.md`。

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="SkillsGo Skill 详情展示来源证据、版本、支持的 Agents 和渲染后的说明">
</p>

### 精确选择 Skills 的安装位置

安装到全局或指定项目，然后选择需要接收同一 Skill 版本的 Agent 目标。

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="SkillsGo 安装目标选择器展示指定项目和多个 Agent 目标">
</p>

### 管理统一的本地 Library

按全局或项目范围浏览已安装的 Skills，搜索本地清单，并按 Agent 筛选。

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="SkillsGo Library 展示全局安装的 Skills 及其 Agent 目标">
</p>

### 更新前看清影响

应用仓库更新前，查看版本变化以及将被移除的 Skills。

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="SkillsGo Library 更新预览展示版本变化和将被移除的 Skills">
</p>

<details>
  <summary><strong>查看项目范围的 Library</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="SkillsGo Library 展示为指定项目安装的 Skills">
  </p>
</details>

## 为什么选择 SkillsGo

- **真实的来源证据**——安装前检查仓库身份、版本、`SKILL.md`、文件和风险。
- **明确的 Agent 目标**——将 Skills 安装到全局或项目范围内选定的 Agents，无需手动复制文件。
- **可验证的分发**——将来源仓库的发布版本作为不可变的分发单元。
- **本地优先的管理**——即使 Hub 不可用，也能检查并安全管理本地清单。
- **两种专用交互方式**——App 面向个人交互流程，CLI 面向 CI/CD、自动化和一致的 Skill 环境。

## 工作原理

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo 工作流：发现、检查、选择目标、安装和管理">
</p>

公共 Hub 是 Skill 身份、不可变版本、元数据、搜索和发现的共享来源。App 通过可视化流程将用户连接到 Hub；CLI 将自动化和 CI/CD 连接到同一个 Hub，使不同环境中的 Skill 选择保持一致。

## 浏览 monorepo

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

产品边界和领域语言请参阅 [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md)。

## 在本地运行

统一开发拓扑目前面向 macOS，需要安装 Flutter、Go、Docker、[Process Compose](https://github.com/F1bonacc1/process-compose) 和 [Air](https://github.com/air-verse/air)。

```bash
make dev
```

该命令会在同一个受监管会话中启动 PostgreSQL、本地 Hub、新构建的 CLI 和 Flutter 桌面 App。验证所有已配置的工作区：

```bash
make test
```

每个工作区也提供独立入口：

| 工作区 | 开发或验证 |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

更改产品行为前，请阅读 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## 项目状态

SkillsGo 正在为首批版本做准备。Hub 的发布流水线会率先确定；经过签名和公证的 App 版本以及独立 CLI 分发各自遵循对应的就绪门槛。支持的发布单元、产物完整性和供应链要求请参阅[发布设计](../release-design.md)。

## 社区

- 使用 [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions) 提问、排查问题和交流早期想法。
- 使用针对具体场景的 [issue 表单](https://github.com/skillsgo/skillsgo/issues/new/choose)报告可复现的问题、明确的功能需求和文档问题。
- 按照 [SECURITY.md](../../SECURITY.md) 的说明私下报告安全漏洞。
- 参与项目须遵守[行为准则](../../CODE_OF_CONDUCT.md)和[治理模型](../../GOVERNANCE.md)。

## 许可证

SkillsGo 采用 [Apache License 2.0](../../LICENSE)。

Hub 包含衍生自 [Athens](https://github.com/gomods/athens) 的代码，该代码仍受 Athens MIT License 和署名声明约束。详情请参阅 [`NOTICE`](../../NOTICE) 和 [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE)。
