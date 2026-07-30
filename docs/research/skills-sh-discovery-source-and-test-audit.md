# skills.sh Discovery Source and Test Audit

Verified on 2026-07-30 against `vercel-labs/skills` commit
[`7cb7db64dc1201052dea305e508a2fc490f7e5e2`](https://github.com/vercel-labs/skills/tree/7cb7db64dc1201052dea305e508a2fc490f7e5e2).

## Scope and evidence

This note audits only first-party implementation and tests. The authoritative
sources are:

- [`src/skills.ts`](https://github.com/vercel-labs/skills/blob/7cb7db64dc1201052dea305e508a2fc490f7e5e2/src/skills.ts), the clone/on-disk discovery path;
- [`src/blob.ts`](https://github.com/vercel-labs/skills/blob/7cb7db64dc1201052dea305e508a2fc490f7e5e2/src/blob.ts), the GitHub tree and blob fast path;
- [`src/plugin-manifest.ts`](https://github.com/vercel-labs/skills/blob/7cb7db64dc1201052dea305e508a2fc490f7e5e2/src/plugin-manifest.ts), Claude plugin manifest expansion and grouping;
- the upstream discovery tests, especially
  [`full-depth-discovery.test.ts`](https://github.com/vercel-labs/skills/blob/cf4a3ea678b7ea5066caa90de94bf2dfacde5538/tests/full-depth-discovery.test.ts),
  [`nested-container-discovery.test.ts`](https://github.com/vercel-labs/skills/blob/cf4a3ea678b7ea5066caa90de94bf2dfacde5538/tests/nested-container-discovery.test.ts), and
  [`plugin-manifest-discovery.test.ts`](https://github.com/vercel-labs/skills/blob/cf4a3ea678b7ea5066caa90de94bf2dfacde5538/tests/plugin-manifest-discovery.test.ts).

This is an implementation audit, not a claim that every behavior is a stable
public specification. In particular, the two upstream discovery paths have
observable differences.

## On-disk discovery algorithm

`discoverSkills()` applies these stages when `fullDepth` is false:

1. Reject a requested subpath if its normalized target escapes the repository.
2. Read plugin manifests for later path expansion and plugin-name grouping.
3. If the search root itself has a valid `SKILL.md`, return that Skill
   immediately. A root file that is missing required frontmatter, internal and
   hidden, or identified as a previously installed project Skill does not stop
   discovery.
4. Scan every priority location in order. A priority location is not a
   fallback tier that stops the next location: valid Skills from all priority
   locations are accumulated and deduplicated by the exact parsed Skill name.
5. Only if the priority scan produced no Skills, recursively search the entire
   search root to a maximum directory depth of five.

With `fullDepth: true`, the valid root Skill is retained, all priority locations
are scanned, and the bounded recursive scan is also performed.

### Priority locations

The exact order in the on-disk implementation is:

1. repository or requested subpath root;
2. `skills`;
3. `skills/.curated`;
4. `skills/.experimental`;
5. `skills/.system`;
6. the following Agent project containers, in order:

   ```text
   .agents/skills
   .claude/skills
   .cline/skills
   .codebuddy/skills
   .codex/skills
   .commandcode/skills
   .continue/skills
   .github/skills
   .goose/skills
   .grok/skills
   .iflow/skills
   .junie/skills
   .kilocode/skills
   .kimchi/skills
   .kiro/skills
   .mux/skills
   .neovate/skills
   .opencode/skills
   .openhands/skills
   .pi/skills
   .qoder/skills
   .roo/skills
   .trae/skills
   .windsurf/skills
   .zcode/skills
   .zencoder/skills
   ```

7. directories derived from `.claude-plugin/marketplace.json`;
8. directories derived from `.claude-plugin/plugin.json`.

The root priority entry scans one child directory only. Every built-in
non-root container scans `container/<skill>/SKILL.md` and one additional
catalog level, `container/<category>/<skill>/SKILL.md`. A discovered Skill at
the first child level shadows descendants beneath that directory. Manifest-
derived directories scan only one child level, even when they happen to point
at a conventional container.

The deduplication key is the parsed, sanitized Skill `name`, not path or a
normalized name. Therefore the first priority occurrence of exactly the same
name wins, while case variants are distinct. An invalid first occurrence is
treated as a found child for descent control, but is not added or entered into
the name set. This means an invalid `container/foo/SKILL.md` still prevents
discovery of `container/foo/bar/SKILL.md` in the bounded priority walk; the
recursive fallback can recover it only when no valid priority Skill exists
anywhere.

### Recursive fallback and exclusions

The recursive walker:

- starts at depth zero and visits through depth five inclusively;
- includes a directory when it contains a case-sensitive file named exactly
  `SKILL.md`;
- continues below a discovered Skill rather than applying parent shadowing;
- does not enter `node_modules`, `.git`, `dist`, `build`, or `__pycache__`;
- runs only when priority discovery returned zero Skills, unless `fullDepth` is
  explicitly enabled.

Skill parsing requires string `name` and `description` frontmatter. Invalid
YAML, unreadable files, missing fields, and non-string fields are ignored.
`metadata.internal: true` is ignored by default and included when either
`INSTALL_INTERNAL_SKILLS` is `1`/`true` or `includeInternal` is set.

## Plugin manifest behavior

Only Claude manifests are read. `.codex-plugin/plugin.json` and
`.cursor-plugin/plugin.json` have no role in skills.sh discovery at the audited
commit.

### Marketplace manifest

`.claude-plugin/marketplace.json` supports:

- optional `metadata.pluginRoot`;
- multiple `plugins`;
- local string `plugin.source`, or an omitted source for a root plugin;
- explicit `plugin.skills` paths;
- a plugin `name` used to annotate explicitly declared Skill paths.

`pluginRoot`, a present string `source`, and every explicit Skill path must
start with `./`. Remote object sources are skipped. Resolved paths must remain
inside the repository root. Invalid JSON and invalid entries are silently
ignored.

For each accepted plugin, discovery always adds `<plugin base>/skills`, even
when `skills` is absent or empty. For every explicit Skill path, discovery adds
the path's **parent directory** to the search list and then scans all immediate
child directories in that parent. Consequently the implementation may discover
an undeclared sibling Skill next to an explicitly declared Skill.

Plugin-name grouping is narrower than discovery: only explicitly declared
Skill directories receive `pluginName`; conventionally discovered Skills under
`<plugin base>/skills` do not receive the plugin name unless also declared.

### Single-plugin manifest

`.claude-plugin/plugin.json` is interpreted at repository root. It supports
`name` and explicit `skills`, applies the same `./` and containment checks, and
always contributes root `skills/` as a conventional directory. Explicit paths
receive the manifest name for grouping.

When marketplace and single-plugin manifests both exist, both are processed;
ordinary priority order and name deduplication decide collisions.

## Blob fast-path differences

`findSkillMdPaths()` intends to mirror the on-disk priority list, including all
24 Agent containers and the five excluded directory names, but it is a separate
implementation with these differences:

- it does not read plugin manifests;
- it matches candidate filenames case-insensitively;
- a root `SKILL.md` does not short-circuit other priority Skills;
- it returns all built-in priority results together and falls back to all tree
  paths only when no priority path exists;
- the fallback depth check is based on the full repository path component
  count (`<= 6`), not depth relative to a requested subpath;
- fallback filtering does not apply the five skipped-directory names;
- parent shadowing in depth-two containers is path-based and
  case-insensitive, before frontmatter validity is known.

These are upstream implementation divergences. SkillsGo should define one
canonical discovery contract and test all acquisition paths against it rather
than reproduce both variants.

## Upstream executable coverage

| Behavior | Upstream coverage | Evidence and limitation |
| --- | --- | --- |
| Valid root Skill short-circuits on-disk discovery | Covered | `full-depth-discovery.test.ts` and `nested-container-discovery.test.ts` |
| `fullDepth` retains root and includes nested Skills | Covered | `full-depth-discovery.test.ts` |
| Flat and category-nested `skills/` layouts | Covered | Both on-disk and blob cases in `nested-container-discovery.test.ts` |
| Parent Skill shadows nested Skill | Covered | Both paths, including lowercase parent filename for blob only |
| Root does not perform depth-two priority descent | Covered | Both paths |
| Deeper-than-category discovery requires full depth | Covered on disk | No matching blob fallback assertion |
| Agent-specific container depth two | Partial | Only `.agents/skills` is exercised as discovery input |
| All 26 Agent container names | Not enumerated | They are constants, but no table-driven discovery test checks every entry |
| Special `skills/.curated`, `.experimental`, `.system` containers | Not behavior-tested | Path-format tests mention `.curated`, not discovery precedence |
| Excluded directories | Partial | Discovery tests exercise only `node_modules`; the other four are not enumerated |
| Priority suppresses recursive fallback | Partial | Root and unrelated `examples` behavior is covered; the complete invalid-root/invalid-priority/valid-fallback chain is not |
| Duplicate parsed names | Covered | Root versus nested duplicate under `fullDepth`; manifest versus conventional duplicate |
| Invalid Skill frontmatter | Not covered as a discovery-priority matrix | Parser behavior exists, but shadowing and fallback interactions are not exhaustively tested |
| Hidden internal Skills | Not covered in the reviewed discovery suites | No priority/fallback matrix for environment and explicit inclusion |
| Installed project Skill suppression through `skills-lock.json` | Covered | `.agents/skills` with and without a lock entry in `nested-container-discovery.test.ts` |
| Marketplace local source, no source, and multiple plugins | Covered | `plugin-manifest-discovery.test.ts` |
| `metadata.pluginRoot` | Test exists but contradicts the implementation | The fixture uses bare source `my-plugin`, while `getPluginSkillPaths()` rejects every present source that does not start with `./`; the audited source and asserted expectation cannot both hold |
| Missing/empty explicit Skill arrays and conventional plugin `skills/` | Covered | `plugin-manifest-discovery.test.ts` |
| Explicit plus conventional plugin Skills | Covered | Same suite |
| Remote source objects | Covered | Skipped |
| Invalid JSON | Covered | Marketplace invalid JSON only |
| Missing `./`, absolute paths, and traversal | Covered | Marketplace and single-plugin variants across the suite |
| Plugin grouping | Partial | Marketplace mappings and nested sources are covered; single-plugin grouping and security/error variants are not |
| Both manifest files present | Not covered | Processing and collision order are not asserted |
| Undeclared sibling discovery caused by parent-directory expansion | Not covered | Observable from implementation, not locked by an upstream test |
| On-disk/blob semantic parity | Not covered | The upstream tests assert selected shared cases, not a common conformance corpus |

## SkillsGo conformance matrix

The following matrix can be translated directly into table-driven Hub
discovery tests. Expected results should be asserted by relative Skill path and
name, and the same corpus should be run against every SkillsGo acquisition
path.

| ID | Fixture | Expected contract |
| --- | --- | --- |
| D01 | Valid root `SKILL.md` plus valid Skills in every lower tier | Root is the only result under default discovery |
| D02 | Invalid root; valid conventional Skill | Conventional Skill is returned |
| D03 | Invalid root; all conventional candidates invalid; valid recursive candidate | Recursive candidate is returned |
| D04 | One valid priority candidate plus unrelated recursive candidate | Recursive fallback does not run |
| D05 | Root plus nested candidates with explicit full-depth mode, if SkillsGo exposes such a mode | All nonduplicate valid candidates are returned |
| D06 | `skills/<skill>/SKILL.md` | Flat Skill is returned |
| D07 | `skills/<category>/<skill>/SKILL.md` | Category Skill is returned |
| D08 | `skills/<parent>/SKILL.md` plus `<parent>/<child>/SKILL.md` | Parent shadows child |
| D09 | Invalid parent Skill plus valid nested Skill | Specify deliberately whether validity permits descent; do not inherit the upstream accidental blocking behavior implicitly |
| D10 | Root `examples/<category>/<skill>/SKILL.md` plus valid priority Skill | Example is not discovered by default |
| D11 | Skill at recursive depths 0 through 6 with no priority candidates | Depths through the selected limit are included and the next depth excluded |
| D12 | Same Skill name in root child, `skills/`, Agent container, and manifest path | First documented tier wins deterministically |
| D13 | Same spelling with case and separator variations | Assert the SkillsGo identity normalization contract explicitly |
| D14 | Missing name, missing description, non-string fields, invalid YAML, unreadable file | Invalid candidates never become published Skills |
| D15 | Internal metadata under every tier | Assert default exclusion and any explicit inclusion policy |
| D16 | Each of `node_modules`, `.git`, `dist`, `build`, `__pycache__` at root, container child, and recursive depth | No Skill below an excluded directory is returned |
| D17 | Each of `skills`, `skills/.curated`, `skills/.experimental`, and `skills/.system`, flat and category-nested | Every supported conventional container is discovered |
| D18 | Each of the 26 Agent project containers, flat and category-nested | Every declared container works; test data and production list must share one source of truth |
| D19 | Exact `SKILL.md`, lowercase `skill.md`, and lookalike `my-SKILL.md` | Assert one consistent filename policy across local and remote paths |
| P01 | Valid marketplace local string source and explicit Skill | Declared Skill is found and associated with plugin name |
| P02 | Marketplace omitted source | Root plugin is supported |
| P03 | Valid `metadata.pluginRoot` plus `./`-prefixed local source, followed by a bare-source variant | Resolution is relative, contained, and deterministic; the bare-source expectation must be chosen explicitly because the audited skills.sh source and test disagree |
| P04 | Multiple local plugins with distinct and duplicate Skill names | All distinct Skills are returned; collision winner is deterministic |
| P05 | Remote object source | Entry is skipped without affecting valid local entries |
| P06 | Missing/empty `skills` plus conventional plugin `skills/` | Conventional discovery policy is explicit and tested |
| P07 | Explicit custom Skill plus conventional plugin Skill | Both are returned if that remains the intended contract |
| P08 | Missing `./`, absolute path, `..` traversal, and symlink escape for plugin root/source/Skill path | Every escape is rejected; valid siblings remain discoverable |
| P09 | Invalid marketplace JSON and invalid single-plugin JSON independently | Invalid file does not crash discovery or suppress valid conventional Skills |
| P10 | Marketplace and single-plugin manifests both present with overlap | Merge and precedence are deterministic |
| P11 | Explicit Skill path with undeclared sibling in the same parent | Assert whether only declared paths or the entire parent is searched; prefer exact declarations |
| P12 | Conventional plugin Skill not explicitly declared | Assert whether it receives the plugin namespace |
| P13 | `.codex-plugin`, `.claude-plugin`, and `.cursor-plugin` manifests independently and together | Assert SkillsGo's broader manifest compatibility and nearest/precedence rule; this intentionally exceeds skills.sh |
| X01 | Run D01-D19 and P01-P13 through filesystem, Git tree, and packaged-artifact inputs | Results are identical across acquisition implementations |
| X02 | Requested safe subpath and equivalent repository-root fixture | Relative depth and result identity are identical |
| X03 | Requested subpath containing traversal and symlink escape | Discovery fails safely before reading outside the Package root |

## Recommendation

Use skills.sh as evidence for ecosystem layouts, not as two algorithms to copy.
SkillsGo should expose a single pure candidate-classification function over
normalized repository entries. Filesystem, Git, and artifact readers should
only produce those entries. A shared conformance corpus can then make priority,
shadowing, exclusion, manifest expansion, and validation independent of the
transport used to obtain the repository.
