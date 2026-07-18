# skills.sh Installation Model: Official Issue and Pull Request Review

## Research question

This note reviews first-party evidence in `vercel-labs/skills` about the current installation model: one canonical skill directory (`.agents/skills` or `~/.agents/skills`) plus agent-specific symlinks, with a copy-mode alternative. It focuses on structural weaknesses and the solutions discussed in the official repository.

Research date: 2026-07-17. Issue and pull request status is reported as of that date.

## Executive conclusion

The official issue history confirms that the canonical-directory model reduces duplication but creates a real semantic conflict:

- `.agents/skills` is both an installer-owned canonical location and a discovery location consumed directly by some agents.
- `--agent` presents an agent-specific selection, but writing a skill to a shared discovery location can make it visible to agents that were not selected.
- Removing an agent-specific link cannot hide a skill from an agent that also scans the canonical location.
- Project and global discovery paths are not necessarily symmetric, so classifying an agent as “universal” from its project path produces incorrect global behavior.
- The link set is derived state, but the CLI still lacks a stable, merged restore/relink workflow from either the canonical store or the lockfile.

There is no merged, comprehensive replacement model. Official-repository proposals currently split into four directions:

1. make “universal” classification scope-aware and honor explicit agent selection;
2. add repair/link/bind commands while retaining the canonical store;
3. install directly into agent-specific directories and accept small physical duplication;
4. add package-manager-style manifests, lockfile restore, and a content-addressable cache.

The evidence therefore supports treating `skills.sh` as a useful implementation reference, not as a settled package-management model that SkillsGo should copy without qualification.

## Baseline model and its original trade-off

The repository README describes symlink mode as the recommended method: agent directories link to a canonical copy, while `--copy` creates independent copies. It also describes project installs as content that can be committed and shared with the team ([README](https://github.com/vercel-labs/skills/blob/main/README.md)).

The shared `.agents` model originated in [Issue #23](https://github.com/vercel-labs/skills/issues/23), which proposed one copy plus agent-specific symlinks to avoid duplicated files and difficult multi-agent updates. Importantly, the proposal itself listed inconsistent symlink support as a concern and originally said centralization should be opt-in. The issue was closed after the implementation direction was accepted.

[Issue #128](https://github.com/vercel-labs/skills/issues/128) then exposed the unresolved repository boundary: if `.agents` is ignored, committed agent symlinks break and there was no project lockfile/install command; if `.agents` is committed, the dependency content is vendored into the repository. A collaborator answered that `.agents` should be committed. Thus, the official discussion does not define `.agents/skills` as an npm-like ignored installation directory.

## Findings

### 1. “Universal” visibility conflicts with explicit agent selection

This is the most important structural defect.

[Issue #810](https://github.com/vercel-labs/skills/issues/810) demonstrates that removing a skill from Codex can leave it visible because Codex also reads the retained `~/.agents/skills` canonical copy. The reporter proposes direct installation into each selected agent directory and explicitly accepts minor disk duplication. The report also states that `--copy` does not restore isolation for agents classified as universal: Codex and Amp still resolve to `~/.agents/skills`.

[Issue #1056](https://github.com/vercel-labs/skills/issues/1056) reports the complementary failure: if the same skill exists in both `~/.codex/skills` and `~/.agents/skills`, Codex can discover it twice. Suggested remedies include deduplicating visible locations, warning about the overlap, or defining a single canonical Codex path.

[PR #1186](https://github.com/vercel-labs/skills/pull/1186) attempts a narrower fix: when `-a` explicitly names an agent in project scope, bypass the “agent config directory must already exist” heuristic and create the requested link. It also proposes surfacing skipped agents. The PR remains open and deliberately does not solve global-scope behavior.

**Status:** #810 and #1056 are open user reports/proposals. #1186 is an open, unmerged implementation proposal. No merged change establishes true per-agent isolation.

**Implication for SkillsGo:** a shared discovery directory must be modeled as a discovery group, not as a private target for one agent. If the product promises precise `--agent` isolation, it cannot also place the physical canonical copy in a directory scanned by other agents.

### 2. Project and global path classification are incorrectly coupled

[Issue #1060](https://github.com/vercel-labs/skills/issues/1060) identifies the general defect: `isUniversalAgent()` is inferred from the project-level `skillsDir === '.agents/skills'`, then reused for global installs even when the agent has a different `globalSkillsDir`. The proposed correction is scope-aware universality: inspect the project path for project installs and the global path for global installs.

[Issue #537](https://github.com/vercel-labs/skills/issues/537) shows the operational result: a global install populates `~/.agents/skills`, but the chosen agent directory is absent and `skills list` reports “Agents: not linked.” [PR #538](https://github.com/vercel-labs/skills/pull/538) proposes creating `globalSkillsDir` first while preserving the canonical store; it remains open.

[Issue #693](https://github.com/vercel-labs/skills/issues/693) and [Issue #744](https://github.com/vercel-labs/skills/issues/744) report Claude-specific forms of the same mismatch: content exists under `~/.agents/skills`, but Claude Code cannot consume it because its own directory was not linked.

[Issue #1061](https://github.com/vercel-labs/skills/issues/1061) questions the agent catalog itself: Cline was classified as universal although the reporter found Cline documentation pointing to `.cline/skills` and `~/.cline/skills`.

**Status:** all cited issues and #538 remain open. The repository has diagnosed the category but has not merged a general scope-aware model.

**Implication for SkillsGo:** target capability must be recorded per scope. A single boolean such as `universal` is insufficient; the model needs `(agent, scope) -> discovery paths`, including path overlap between agents.

### 3. Link creation can silently produce an incomplete installation

[Issue #1138](https://github.com/vercel-labs/skills/issues/1138) documents a project install that writes the canonical skill but silently skips the Claude Code link when `.claude/` does not already exist. The installer reported success, even though the explicitly selected agent could not see the skill. The issue was closed on 2026-07-07, but both proposed fixes—[PR #1186](https://github.com/vercel-labs/skills/pull/1186) for explicit selection and [PR #1405](https://github.com/vercel-labs/skills/pull/1405) for accurate reporting—remain open as of the research date. The closure therefore is not evidence of a merged fix.

[Issue #465](https://github.com/vercel-labs/skills/issues/465) reports the same broad symptom for a global installation: the canonical copy was present but no agent links were created. It was closed without a general solution and is referenced by later repair proposals.

[Issue #1025](https://github.com/vercel-labs/skills/issues/1025) proposes a dedicated `relink`/`repair-links` command that treats `~/.agents/skills` as canonical, creates missing links, replaces incorrect links, preserves real directories as conflicts, and supports dry runs. It specifically argues that reinstalling from the canonical directory is unsafe because the install path may clear the source before copying.

**Status:** #1025 is an open user proposal. Link-command implementations [PR #674](https://github.com/vercel-labs/skills/pull/674) and [PR #1029](https://github.com/vercel-labs/skills/pull/1029) are also open and unmerged.

**Implication for SkillsGo:** installation success must mean every requested target is usable. Canonical materialization and target projection should have separately reported outcomes, and repair must be a safe, idempotent first-class operation rather than a reinstall side effect.

### 4. Symlink behavior has portability and topology edge cases

[Issue #481](https://github.com/vercel-labs/skills/issues/481) reports broken relative links when an agent’s parent skills directory is itself a symlink, a common dotfiles setup. It proposes absolute links or resolving the real parent before calculating a relative target. The current source contains parent-symlink resolution in `createSymlink`, but the issue remains open; this should be treated as an attempted mitigation, not a confirmed resolution.

[Issue #105](https://github.com/vercel-labs/skills/issues/105) reports that Cursor did not discover a symlinked skill while a copied installation worked. The issue is closed, but it establishes that filesystem link creation and agent discovery support are separate compatibility questions.

[Issue #23](https://github.com/vercel-labs/skills/issues/23), the original centralization proposal, explicitly acknowledged inconsistent cross-platform and cross-agent symlink support. Current source attempts a Windows junction and falls back to copy if link creation fails ([`src/installer.ts`](https://github.com/vercel-labs/skills/blob/main/src/installer.ts)), but fallback means the resulting topology can differ by machine even for the same command.

**Status:** #481 remains open; #105 is closed. The source contains mitigations, but there is no official claim that links are portable across every supported agent and platform.

**Implication for SkillsGo:** symlink capability is an environment property and should be verified, not assumed. If fallback to copy is allowed, the resolved installation mode should be observable and persisted where later remove/repair operations can use it.

### 5. Canonical content and agent bindings have coupled lifecycles

[Issue #1038](https://github.com/vercel-labs/skills/issues/1038) gives the clearest architectural diagnosis:

```text
add    = install + bind
remove = unbind + uninstall
```

It argues that the current coupling prevents reassignment without refetching, leaves “installed but not active for agent X” implicit, and makes broken links difficult to recover. The proposed `bind`/`unbind` operations are implementation-independent relationships that could use symlink, copy, or a future configuration mechanism.

Related official proposals include enable/disable management in [Issue #634](https://github.com/vercel-labs/skills/issues/634) and [PR #641](https://github.com/vercel-labs/skills/pull/641), as well as linking in [PR #674](https://github.com/vercel-labs/skills/pull/674) and [PR #1029](https://github.com/vercel-labs/skills/pull/1029). All remain open.

**Status:** open design proposals and unmerged PRs; no accepted command or state model.

**Implication for SkillsGo:** even if SkillsGo does not expose `bind` as a user command, its internal domain model should separate artifact presence, scope activation, and agent visibility. This prevents canonical deletion from being inferred only from a scan of current links.

### 6. Lockfiles do not yet provide reproducible restore on a new machine or CI

[Issue #283](https://github.com/vercel-labs/skills/issues/283) explains that the global `.skill-lock.json` acts as an update registry, not a deterministic installation manifest. On a new machine, `skills update` does not reinstall an absent skill when its recorded hash already matches the remote hash. The proposed `install`/`sync` command would ensure all tracked skills exist.

[Issue #683](https://github.com/vercel-labs/skills/issues/683) narrows the missing workflow further: there is no supported global command that both rehydrates `~/.agents/skills` from the global lock and recreates agent links. It also notes that the lock stores `lastSelectedAgents`, not a per-skill agent assignment, so exact binding restoration is impossible without defining new semantics.

[Issue #549](https://github.com/vercel-labs/skills/issues/549) separately proposes an npm-ci-equivalent restore command. [Issue #165](https://github.com/vercel-labs/skills/issues/165) proposes the broader package-manager model: a manifest plus content-addressable cache.

**Status:** all are open user proposals. The current README shows a CI-friendly noninteractive `add` command, but that is not the same as restoring a committed multi-source, exact-version environment from a lockfile.

**Implication for SkillsGo:** verified recovery is a differentiator that should not be discarded when simplifying installation. A lock must encode source identity, immutable resolution, integrity, scope, and the requested discovery targets; reconstruction should not depend on pre-existing links.

### 7. Copy mode does not consistently mean “install directly to the selected agent”

The README defines `--copy` as copying files instead of symlinking to agent directories. However, [Issue #810](https://github.com/vercel-labs/skills/issues/810) reports that copy mode still sends Codex and Amp to `~/.agents/skills` because target path resolution happens before the copy/symlink choice and retains universal-agent classification.

[Issue #1138](https://github.com/vercel-labs/skills/issues/1138) gives the opposite special case: copy mode bypasses the project symlink skip and can create `.claude/skills`, while symlink mode silently does not. Thus, installation mode changes both storage mechanism and which target is considered eligible.

**Status:** open structural report plus a closed symptom report without a merged general correction.

**Implication for SkillsGo:** “target selection” and “materialization mechanism” should be orthogonal. Copy versus symlink must not change agent-selection semantics or discovery-path resolution.

### 8. Same-name skills collide in both storage and lock identity

[Issue #606](https://github.com/vercel-labs/skills/issues/606) reports that lock entries are keyed only by visible skill name. Skills with the same name from different sources overwrite one another, making grouping, removal, and updates ambiguous; metadata rewrites can also lose unknown fields.

[Issue #897](https://github.com/vercel-labs/skills/issues/897) expands the collision across three layers: the on-disk canonical directory is overwritten, the lock entry is replaced, and discovery may be shadowed. Its proposed solution is source-aware lock identity, fail-closed install behavior for cross-source collisions, and validation between frontmatter name and directory name.

**Status:** both issues remain open; the proposed fixes are user recommendations, not merged repository policy.

**Implication for SkillsGo:** a public skill ID and immutable version/digest must own storage identity. A display name alone is insufficient for the canonical directory, lock key, update, or remove operation.

## Solution directions in the official repository

| Direction | Official evidence | Status | What it solves | What it does not solve |
| --- | --- | --- | --- | --- |
| Scope-aware universal classification | [#1060](https://github.com/vercel-labs/skills/issues/1060), [#538](https://github.com/vercel-labs/skills/pull/538) | Open | Correct project/global destination selection | Shared-directory unintended visibility |
| Honor explicit agent selection | [#1186](https://github.com/vercel-labs/skills/pull/1186) | Open PR | Fresh-project link omission for explicit `-a` | Global path semantics and shared discovery overlap |
| Repair/relink installed canonical skills | [#1025](https://github.com/vercel-labs/skills/issues/1025), [#674](https://github.com/vercel-labs/skills/pull/674), [#1029](https://github.com/vercel-labs/skills/pull/1029) | Open | Derived-link recovery and reassignment | New-machine artifact restore and visibility isolation |
| Separate install from bind | [#1038](https://github.com/vercel-labs/skills/issues/1038), [#634](https://github.com/vercel-labs/skills/issues/634) | Open proposals | Makes activation state explicit | Still needs an unambiguous discovery-target model |
| Direct per-agent copies | [#810](https://github.com/vercel-labs/skills/issues/810) | Open user proposal | True per-agent add/remove isolation; avoids link failures | Duplicates content and needs coordinated updates |
| Restore from lockfile | [#283](https://github.com/vercel-labs/skills/issues/283), [#549](https://github.com/vercel-labs/skills/issues/549), [#683](https://github.com/vercel-labs/skills/issues/683) | Open proposals | New-machine/CI reconstruction | Current lock lacks exact per-skill bindings and source-safe identity |
| Manifest plus content-addressable cache | [#165](https://github.com/vercel-labs/skills/issues/165) | Open proposal | Package-manager semantics and deduplicated cache | Larger redesign; not current behavior |

## Recommendations for SkillsGo

1. **Do not use an agent discovery directory as an invisible internal store.** Treat `.agents/skills` as a shared target whose visibility consequences are explicit.
2. **Resolve targets per scope.** Model project and user discovery paths separately and permit one path to be consumed by multiple agents.
3. **Separate requested target from transfer mechanism.** Copy/symlink is an implementation choice after the target set is resolved.
4. **Prefer simple physical copies for precise agent targets.** Skills are generally small, and this avoids link topology and removal ambiguity. Shared `.agents/skills` can remain an explicit universal-group target.
5. **Keep SkillsGo's lock-based verified recovery.** New-machine and CI restoration are still unresolved in `skills.sh`; abandoning this capability would copy a documented weakness.
6. **Use source-aware immutable identity.** Do not key canonical storage or lock entries by display name alone.
7. **Make installation atomic and outcome-based.** A command succeeds only when every requested target is discoverable; skipped and fallback results must be reported.
8. **Provide idempotent reconciliation internally.** Even without a public `bind` or `repair` command, `skillsgo install` should be able to reconstruct missing target projections safely from the manifest and lock.

## Bottom line

The strongest lesson from the official discussions is not “canonical plus symlink is wrong” in every case. It is that the model becomes wrong when three different concepts are collapsed into one directory:

- artifact ownership,
- current installation state,
- agent discovery visibility.

`skills.sh` has active proposals to separate these concepts, but no complete solution is merged. SkillsGo should preserve its stronger identity and recovery model, make `.agents/skills` an explicit shared discovery target, and use agent-specific physical installs when the user expects precise isolation.
