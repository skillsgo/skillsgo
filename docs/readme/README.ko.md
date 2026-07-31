<p align="center">
  <img src="../../assets/readme/hero.svg" width="100%" alt="SkillsGo — Agent Skills 탐색, 검증 및 관리">
</p>

<!-- README-I18N:START -->

<details>
  <summary><strong>한국어</strong> · 언어</summary>
  <br>
  <p>
    <a href="../../README.md">English</a> ·
    <a href="./README.zh-CN.md">简体中文</a> ·
    <a href="./README.zh-TW.md">繁體中文（台灣）</a> ·
    <a href="./README.zh-HK.md">繁體中文（香港）</a> ·
    <a href="./README.ja.md">日本語</a> ·
    <strong>한국어</strong> ·
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

SkillsGo는 Agent Skills를 탐색하고 관리하기 위한 개방형 생태계입니다. 데스크톱 App은 사람이 Skills를 탐색하고 관리할 수 있는 시각적 환경을 제공하며, CLI는 동일한 Hub 카탈로그를 CI/CD와 재현 가능한 환경 워크플로에 연결합니다.

> [!IMPORTANT]
> SkillsGo는 현재 프리릴리스 단계에서 활발히 개발되고 있습니다. 첫 안정 버전이 출시되기 전까지 공개 프로토콜, 영구 저장 형식, 설치 동작이 변경될 수 있습니다.

## SkillsGo 실제 화면

<p align="center">
  <img src="../../assets/readme/discover-ranking.png" width="100%" alt="공개 Hub의 실시간 순위에서 Agent Skills를 보여 주는 SkillsGo 데스크톱 App">
</p>

데스크톱 App은 탐색, 소스 근거, 설치 대상, 로컬 인벤토리를 하나의 이해하기 쉬운 흐름으로 연결합니다. 개인 사용에는 계정이 필요하지 않습니다.

### Hub에서 탐색

Skill 또는 소스 저장소로 검색하고, 실시간 순위를 살펴본 뒤, Skill 하나 또는 전체 모음을 설치할 수 있습니다.

<p align="center">
  <img src="../../assets/readme/discover-find.png" width="100%" alt="소스 저장소와 사용 가능한 Agent Skills를 보여 주는 SkillsGo Discover 검색 결과">
</p>

### 설치 전에 확인

로컬 환경을 변경하기 전에 소스 저장소, 변경 불가능한 릴리스, 지원 Agents, 번역된 요약, 렌더링된 `SKILL.md`를 검토할 수 있습니다.

<p align="center">
  <img src="../../assets/readme/discover-skill-detail.png" width="100%" alt="소스 근거, 버전, 지원 Agents, 렌더링된 지침을 보여 주는 SkillsGo Skill 상세 화면">
</p>

### Skills 설치 위치를 정확하게 선택

전역 또는 선택한 프로젝트에 설치한 다음, 동일한 Skill 릴리스를 받을 Agent 대상을 선택합니다.

<p align="center">
  <img src="../../assets/readme/discover-install-skill.png" width="100%" alt="선택한 프로젝트와 여러 Agent 대상을 보여 주는 SkillsGo 설치 대상 선택기">
</p>

### 하나의 로컬 Library에서 관리

설치된 Skills를 전역 또는 프로젝트 범위별로 살펴보고, 인벤토리를 검색하며, Agent별로 필터링할 수 있습니다.

<p align="center">
  <img src="../../assets/readme/library-global-skills.png" width="100%" alt="전역으로 설치된 Skills와 Agent 대상을 보여 주는 SkillsGo Library">
</p>

### 영향을 확인한 뒤 업데이트

저장소 업데이트를 적용하기 전에 버전 전환과 제거될 Skills를 확인할 수 있습니다.

<p align="center">
  <img src="../../assets/readme/library-update-skills.png" width="100%" alt="버전 전환과 제거될 Skills를 보여 주는 SkillsGo Library 업데이트 미리보기">
</p>

<details>
  <summary><strong>프로젝트 범위 Library 보기</strong></summary>
  <br>
  <p align="center">
    <img src="../../assets/readme/library-project.png" width="100%" alt="선택한 프로젝트에 설치된 Skills를 보여 주는 SkillsGo Library">
  </p>
</details>

## SkillsGo를 선택하는 이유

- **실제 소스 근거** — 설치 전에 저장소 식별 정보, 버전, `SKILL.md`, 파일, 위험 요소를 확인합니다.
- **명확한 Agent 대상** — 파일을 직접 복사하지 않고, 선택한 Agents에 전역 또는 프로젝트 범위로 설치합니다.
- **검증 가능한 배포** — 소스 저장소 릴리스를 변경 불가능한 배포 단위로 취급합니다.
- **로컬 우선 관리** — Hub를 사용할 수 없을 때도 로컬 인벤토리를 확인하고 안전하게 관리합니다.
- **목적에 맞춘 두 가지 인터페이스** — App은 대화형 개인 워크플로에, CLI는 CI/CD, 자동화, 일관된 Skill 환경에 적합합니다.

## 작동 방식

<p align="center">
  <img src="../../assets/readme/workflow.svg" width="100%" alt="SkillsGo 워크플로: 탐색, 확인, 대상 선택, 설치 및 관리">
</p>

공개 Hub는 Skill 식별 정보, 변경 불가능한 릴리스, 메타데이터, 검색, 탐색을 위한 공동 소스입니다. App은 시각적 워크플로를 통해 사람을 Hub에 연결하고, CLI는 자동화와 CI/CD를 동일한 Hub에 연결하여 환경 전반에서 Skill 선택을 일관되게 유지합니다.

## monorepo 살펴보기

```text
skillsgo/
├── app/       Flutter desktop client and user experience
├── cli/       Go CLI and local Skill execution engine
├── hub/       Public Skill Hub service and reusable runtime
├── protocol/  Shared executable contracts used by CLI and Hub
├── web/       Public product, Hub, and documentation surface
└── e2e/       Cross-product CLI/Hub and desktop journeys
```

제품 경계와 도메인 용어는 [`CONTEXT-MAP.md`](../../CONTEXT-MAP.md)를 참고하세요.

## 로컬에서 실행

통합 개발 구성은 현재 macOS를 대상으로 하며 Flutter, Go, Docker, [Process Compose](https://github.com/F1bonacc1/process-compose), [Air](https://github.com/air-verse/air)가 필요합니다.

```bash
make dev
```

이 명령은 PostgreSQL, 로컬 Hub, 새로 빌드한 CLI, Flutter 데스크톱 App을 하나의 감독 세션에서 시작합니다. 구성된 모든 워크스페이스를 검증하려면 다음을 실행하세요.

```bash
make test
```

각 워크스페이스에는 별도의 진입점도 있습니다.

| 워크스페이스 | 개발 또는 검증 |
| --- | --- |
| App | `cd app && flutter run -d macos` |
| CLI | `cd cli && go test ./...` |
| Hub | `cd hub && go test ./...` |
| Protocol | `cd protocol && go test ./...` |
| Web | `cd web && pnpm install && pnpm dev` |

제품 동작을 변경하기 전에 [CONTRIBUTING.md](../../CONTRIBUTING.md)를 확인하세요.

## 프로젝트 상태

SkillsGo는 첫 릴리스를 준비하고 있습니다. Hub 릴리스 파이프라인을 먼저 정의하며, 서명 및 공증된 App 릴리스와 독립형 CLI 배포에는 각각 별도의 준비 기준이 적용됩니다. 지원되는 릴리스 단위, 산출물 무결성, 공급망 요구 사항은 [릴리스 설계](../release-design.md)를 참고하세요.

## 커뮤니티

- 질문, 문제 해결, 초기 아이디어에는 [GitHub Discussions](https://github.com/skillsgo/skillsgo/discussions)를 이용하세요.
- 재현 가능한 버그, 구체적인 기능 요청, 문서 문제에는 목적별 [issue 양식](https://github.com/skillsgo/skillsgo/issues/new/choose)을 이용하세요.
- 취약점을 비공개로 신고하려면 [SECURITY.md](../../SECURITY.md)를 따르세요.
- 참여에는 [행동 강령](../../CODE_OF_CONDUCT.md)과 [거버넌스 모델](../../GOVERNANCE.md)이 적용됩니다.

## 라이선스

SkillsGo는 [Apache License 2.0](../../LICENSE)에 따라 제공됩니다.

Hub에는 [Athens](https://github.com/gomods/athens)에서 파생된 코드가 포함되어 있으며, 해당 코드에는 Athens MIT License와 저작자 표시 고지가 계속 적용됩니다. 자세한 내용은 [`NOTICE`](../../NOTICE)와 [`THIRD_PARTY_LICENSES/ATHENS-LICENSE`](../../THIRD_PARTY_LICENSES/ATHENS-LICENSE)를 참고하세요.
