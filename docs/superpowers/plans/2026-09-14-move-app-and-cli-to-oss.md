# Move App and CLI to OSS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the current desktop App, App E2E, packaging, and release authority from `skillsgo-cloud` into `skillsgo-oss`, while making the OSS checkout the sole source for the bundled CLI.

**Architecture:** Import the Cloud App history and App-owned support files into the existing OSS monorepo, then rewrite only repository-relative integration points. The App continues to communicate through the CLI machine protocol; Cloud retains only private service composition and removes its App mirror, submodule, E2E, and release control plane after OSS validation.

**Tech Stack:** Flutter desktop, Dart, Go CLI/Hub/Protocol, GitHub Actions, shell packaging scripts, Git history filtering/import.

## Global Constraints

- Preserve existing uncommitted changes in both repositories; never reset, checkout, clean, or stage unrelated files.
- Repository documentation remains English.
- `skillsgo-oss/cli` remains the only CLI implementation source.
- App business operations continue to cross the bundled CLI machine protocol.
- Public OSS files must not disclose private production topology, persistence, provider ingestion, credentials, or operational identifiers.
- macOS release artifacts remain independent `arm64` and `x86_64` bundles.
- Do not claim completion until both repository test/build gates have been run or an explicit environment blocker is recorded.

---

### Task 1: Snapshot Worktrees and Migration Inputs

**Files:**
- Create: ignored temporary manifests outside both repositories under `/var/folders/71/_sx7yq7932b3nsf8dxhxwkdr0000gn/T/opencode/`
- Read: `skillsgo-cloud` commit `2963ad6`
- Read: `skillsgo-oss` commit `fa2f8556`

**Interfaces:**
- Produces immutable source commit IDs, dirty-file manifests, and an App source file list for every later task.

- [ ] **Step 1: Record repository status, HEAD, and dirty paths**

Run from each child repository:

```bash
git status --short --branch
git rev-parse HEAD
git diff --name-status
git ls-files --others --exclude-standard
```

- [ ] **Step 2: Record App-related Cloud history**

```bash
git log --format='%H %P %s' --all -- app e2e/app .github/workflows/app-release.yml scripts app/Makefile
```

- [ ] **Step 3: Verify the source commit is reachable and export the tracked App tree list**

```bash
git cat-file -e 2963ad6^{commit}
git ls-tree -r --name-only 2963ad6 app > /var/folders/71/_sx7yq7932b3nsf8dxhxwkdr0000gn/T/opencode/cloud-app-files.txt
```

- [ ] **Step 4: Check that no secret-like values are present in candidate source paths**

Search only tracked text files for private hostnames, credentials, and secret variable names; classify findings before moving any file.

- [ ] **Step 5: Commit no source changes**

This task produces only temporary manifests outside Git repositories.

### Task 2: Import the App History into OSS

**Files:**
- Create: `skillsgo-oss/app/**`
- Create: App-owned support files selected from Cloud history
- Modify: `skillsgo-oss` root integration files only after import

**Interfaces:**
- Consumes: Cloud App source at `2963ad6` and the App history rooted at `cd84f2d`.
- Produces: an OSS working tree containing the current App snapshot with recoverable Cloud commit provenance.

- [ ] **Step 1: Create a temporary filtered Cloud view without changing Cloud**

Use a temporary clone or `git filter-repo` output outside both repositories. Include `app/` and only App-owned E2E, packaging, and release files. Do not include Cloud Server, Web, private scripts, or private deployment documents.

- [ ] **Step 2: Import the filtered history into an OSS migration branch/worktree only if the user explicitly permits branch creation**

The workspace rule forbids creating or switching branches by default. If no approved isolated branch exists, import as an uncommitted tree into the current OSS worktree using path-safe file operations and retain the recorded source commit IDs.

- [ ] **Step 3: Ensure generated outputs and build directories are excluded**

Do not import `app/build/`, `.dart_tool/`, coverage, generated platform outputs, or machine-local caches.

- [ ] **Step 4: Verify imported file count and App entry points**

```bash
test -f app/pubspec.yaml
test -f app/lib/main.dart
test -f app/lib/app.dart
test -f app/macos/scripts/bundle_skillsgo_cli.sh
test -f app/macos/scripts/build_arch.sh
```

- [ ] **Step 5: Do not commit until path reconciliation is complete**

### Task 3: Reconcile OSS App and CLI Integration

**Files:**
- Modify: `app/macos/scripts/bundle_skillsgo_cli.sh`
- Modify: `app/**` references to `third_party/skillsgo`
- Modify: `app/AGENTS.md`, `app/README.md`, `app/CONTEXT.md`
- Modify: `AGENTS.md`, `CONTEXT-MAP.md`, `Makefile`
- Create/modify: App F3 maps and touched F4 headers where required

**Interfaces:**
- Consumes: same-repository `cli/` and `protocol/` modules.
- Produces: App packaging that compiles `cli/cmd/skillsgo` from the OSS checkout and validates the existing App protocol handshake.

- [ ] **Step 1: Replace Cloud submodule path resolution**

Change the bundle script default from the Cloud submodule path to the OSS checkout path derived from the App directory:

```bash
readonly cli_root="${SKILLSGO_CLI_SOURCE_DIR:-${SRCROOT}/../../cli}"
```

Keep `SKILLSGO_CLI_SOURCE_DIR` as a developer/CI override.

- [ ] **Step 2: Update App docs from private Cloud ownership to public OSS ownership**

Remove `private`, `closed-source`, `third_party/skillsgo`, and Cloud-repository ownership claims. Preserve public CLI-mediated behavior and Personal App boundaries.

- [ ] **Step 3: Update root OSS workspace maps and commands**

Add `app/` and App E2E to the OSS workspace map and provide `test-app`, `check-app`, `build-app-macos-arm64`, and `build-app-macos-x86_64` targets without removing existing CLI, Hub, or Protocol targets.

- [ ] **Step 4: Search for stale cross-repository paths**

```bash
git grep -n 'third_party/skillsgo\|skillsgo-cloud/app\|private desktop App\|closed-source' -- app Makefile AGENTS.md CONTEXT-MAP.md docs .github scripts || true
```

- [ ] **Step 5: Run focused static checks**

```bash
bash -n app/macos/scripts/bundle_skillsgo_cli.sh app/macos/scripts/build_arch.sh
git diff --check
```

### Task 4: Audit and Publicize App Capabilities

**Files:**
- Modify: App domain/infrastructure/discovery files that depend on Cloud-only ranking behavior
- Modify: App localization strings and documentation only where public wording is inaccurate
- Modify: `app/THIRD_PARTY_NOTICES.md`

**Interfaces:**
- Consumes: public Hub/CLI/Protocol contracts.
- Produces: an App that has no hard dependency on private Cloud implementation details.

- [ ] **Step 1: Trace ranking/trending/hot response paths**

Identify whether the existing routes and payloads are public Hub contracts or Cloud-only responses. Preserve only public behavior; isolate or remove Cloud-only ranking parsing instead of copying private server semantics.

- [ ] **Step 2: Audit assets and third-party notices**

Verify every font, logo, icon set, background, Mermaid asset, and vendored UI component has a redistributable license or an explicit attribution entry.

- [ ] **Step 3: Scan public files for prohibited private facts**

```bash
```

Classify generic technical references separately from private operational data and remove only the latter.

- [ ] **Step 4: Add tests for any changed public capability boundary**

Use existing App gateway/domain test seams rather than private widget implementation details.

### Task 5: Move App E2E, Build, and Release Control to OSS

**Files:**
- Create/modify: `skillsgo-oss/e2e/app/**`
- Create/modify: `skillsgo-oss/scripts/*app*`
- Create/modify: `skillsgo-oss/.github/workflows/app-release.yml`
- Modify: `skillsgo-oss/.github/workflows/ci.yml`
- Modify: `skillsgo-oss/Makefile`
- Modify: `skillsgo-oss/docs/release-design.md`

**Interfaces:**
- Consumes: OSS App, same-repository CLI, public Hub, and configurable release secrets.
- Produces: independent App validation, packaging, candidate rehearsal, checksum publication, and release workflow.

- [ ] **Step 1: Move only App-owned E2E orchestration**

Rewrite repository-root discovery from Cloud layout to OSS layout while preserving isolated HOME, Hub, filesystem, schema, and artifact boundaries.

- [ ] **Step 2: Add App CI matrix and bundled CLI smoke validation**

Keep existing CLI/Hub/Protocol CI jobs. Add Flutter dependency setup, `flutter analyze`, `flutter test`, and the smallest deterministic bundled-CLI smoke journey.

- [ ] **Step 3: Move App release packaging scripts**

Make scripts derive `repository_root` from their own location and accept release source/channel values only through environment variables or workflow inputs. Do not embed credentials or production identifiers.

- [ ] **Step 4: Add App release workflow**

Use `app/v*` tags, build macOS arm64 and x86_64 independently, build supported Linux/Windows artifacts, produce checksums and release assets, and publish update manifests only after immutable packages are present.

- [ ] **Step 5: Add release contract tests**

Assert architecture-specific output paths, bundled CLI version alignment, checksum generation, channel naming, and no universal macOS artifact is treated as a release artifact.

### Task 6: Validate OSS Before Cloud Cleanup

**Files:**
- Modify only files already part of the migration; no Cloud deletions yet.

**Interfaces:**
- Produces: evidence that OSS can build and release the App without Cloud.

- [ ] **Step 1: Install App dependencies and run static checks**

```bash
make app-deps
make check-app
```

- [ ] **Step 2: Run App and Go tests**

```bash
make test-app
make test-cli
make test-hub
make test-protocol
make test-e2e-cli
```

- [ ] **Step 3: Build App artifacts**

```bash
make build-app-macos-arm64
make build-app-macos-x86_64
```

Also run available Linux and Windows build commands on their supported runners or record the exact platform blocker.

- [ ] **Step 4: Verify no Cloud checkout is required**

Run App dependency setup, bundled CLI build, tests, and packaging from an OSS-only checkout or a temporary copied OSS tree.

- [ ] **Step 5: Commit the OSS migration in focused commits**

Commit App import, path/contract reconciliation, CI/release migration, and documentation separately where each commit is independently reviewable. Never stage existing unrelated OSS CLI changes.

### Task 7: Remove Cloud App Ownership

**Files:**
- Delete: `skillsgo-cloud/app/**`
- Delete: `skillsgo-cloud/e2e/app/**`
- Delete: `skillsgo-cloud/third_party/skillsgo` and `.gitmodules`
- Delete: `skillsgo-cloud/.github/workflows/app-release.yml`
- Modify: `skillsgo-cloud/Makefile`, `AGENTS.md`, `ARCHITECTURE.md`, `DEPLOYMENT.md`, CI, and App-related scripts/docs

**Interfaces:**
- Consumes: validated OSS App release and public CLI artifacts.
- Produces: Cloud repository with no App source, App E2E, CLI mirror, or App release authority.

- [ ] **Step 1: Confirm OSS validation evidence and source commit manifest**

Do not delete Cloud files before Task 6 passes or has an explicitly documented blocker approved by the user.

- [ ] **Step 2: Delete Cloud App-owned files using tracked-file-safe operations**

Use `git rm` only for migration-owned paths after checking their status; preserve unrelated dirty files and do not remove shared Cloud scripts until each reference is classified.

- [ ] **Step 3: Remove submodule metadata**

Delete `.gitmodules` only if it contains no remaining submodules. Remove all Makefile, CI, E2E, and documentation references to `third_party/skillsgo`.

- [ ] **Step 4: Rewrite Cloud architecture maps**

State that Cloud consumes public released artifacts/contracts and owns only private server-side composition, data, deployment, and operations.

- [ ] **Step 5: Run Cloud validation**

```bash
make check
make test
git grep -n 'app-release\|e2e/app\|third_party/skillsgo\|private desktop App' -- . ':!build' || true
```

### Task 8: Final Release and Repository Verification

**Files:**
- Modify only release/version files required by the selected App release.

**Interfaces:**
- Produces: verified OSS App release candidate and final migration report.

- [ ] **Step 1: Run repository-wide diff and status review**

```bash
```

Review both repositories and confirm no unrelated user changes were staged or rewritten.

- [ ] **Step 2: Run the public release workflow's local contract commands**

Run the exact shell syntax, archive, checksum, version, architecture, and update-feed checks used by `app-release.yml`.

- [ ] **Step 3: Publish only when credentials and protected environments are available**

Create/push an `app/vX.Y.Z` tag only after the release candidate is verified. Never fabricate signing, CDN, R2, or GitHub environment values locally.

- [ ] **Step 4: Verify published artifacts by read-back**

Check release asset names, checksums, architecture labels, immutable package URLs, and final channel manifest ordering.

- [ ] **Step 5: Produce the completion report**

Report migrated paths, commits, test/build evidence, release tag/assets, any platform limitations, and remaining non-blocking risks.
