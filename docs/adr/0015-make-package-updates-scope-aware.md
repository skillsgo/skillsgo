---
status: accepted
---

# Make Package updates Scope-aware

SkillsGo already stores, locks, downloads, reconciles, and updates one Package version per Scope. Every Skill selected from one Package in one Scope therefore shares that Package version. The remaining update-availability path contradicts this model: the App expands one installed Package into many Skill coordinates, the CLI compares the same Package version once per Skill, and the Hub performs serial Skill membership reads before resolving the Package's latest version. A Package containing thirty selected Skills consequently appears as thirty updates and incurs work proportional to its Skill count even though execution performs one Package mutation.

This decision makes `Scope × Package Path` the only update target across the CLI, App, and Hub. Skills remain selected Package members and may be listed as update impact, but they are never independently versioned, checked, selected for update, or mutated.

## Decision

### Command model

`skillsgo update` is the single update-check and update-execution command:

```text
skillsgo update [<package>[@<version>]]
                [--global | --project <path> | --all]
                [--dry-run]
                [--yes]
                [--output human|json]
```

The optional Package argument selects one Package. Omitting it selects every declared Package in the selected Scope or Scope set. Human-friendly Package input such as `mattpocock/skills` is normalized immediately; manifests, locks, Hub requests, and machine output use the canonical Package Path such as `github.com/mattpocock/skills`.

Scope selection is distinct from Package selection:

| Invocation | Selected update targets |
| --- | --- |
| `skillsgo update --global` | Every Package in Global Scope |
| `skillsgo update mattpocock/skills --global` | One Package in Global Scope |
| `skillsgo update --project ./work` | Every Package in that Workspace Scope |
| `skillsgo update mattpocock/skills --project ./work` | One Package in that Workspace Scope |
| `skillsgo update` | Every Package in the Workspace Scope resolved from the current directory |
| `skillsgo update mattpocock/skills` | One Package in the Workspace Scope resolved from the current directory |
| `skillsgo update --all` | Every Package in every Managed Scope |

`--global`, `--project`, and `--all` are mutually exclusive. An explicit `@<version>` continues to accept a Version Query, resolves it once to an immutable Package Version, and never permits a downgrade through `update`; callers use `add` for an intentional downgrade.

### Managed Scope registry

`--all` means Global Scope plus every explicitly registered Workspace Scope. It never scans the filesystem or infers projects from recent directories. The CLI owns the Managed Scope registry, and the App delegates Added Project registration and removal to the CLI so terminal and App callers observe the same set.

The CLI exposes explicit project registration commands, including `skillsgo project add`, `skillsgo project remove`, and `skillsgo project list`. Removing a Workspace from the registry stops managing it through cross-Scope commands and does not delete its manifest, lock, Package Store, or Projections. Missing or relocated Workspace roots produce an independent Scope result and do not prevent other Managed Scopes from being checked or updated.

### Preview and execution

`--dry-run` produces a Package Update Preview and performs no managed-state mutation. It may read manifests, locks, immutable Package Info, Package Stores, Projections, and caches; query the Hub; verify current state; and calculate target membership. It must not change manifests, locks, Package Stores, Projections, selected Skills, or installation telemetry. It does not require `--yes`, and `--dry-run` plus `--yes` is rejected as contradictory intent.

Removing `--dry-run` executes the exact same target selection and consumes the same preview model. Human execution presents the complete preview and requests confirmation once. JSON execution requires `--yes`. Before applying, the CLI revalidates the Scope declaration and Package state token so a preview cannot overwrite state that changed after preparation.

A preview has one result per `Scope × Package Path` and reports at least:

- Scope kind and canonical root;
- Package Path;
- current immutable version and resolved target immutable version;
- target Sum;
- `up_to_date`, `update_available`, `blocked`, or `failed` status;
- selected Skill and Agent counts;
- selected Skills unavailable in the target Package Version;
- locally detected conflicts that would block execution.

The primary summary counts Package update targets. A selected-Skill count is impact information only. For example, one Package moving from `v1.0.0` to `v1.1.0` with thirty selected Skills is one available Package update affecting thirty Skills, not thirty available updates.

### Package membership across versions

Update preserves the intersection of the declared selection and the target Package membership. A selected Skill that remains in the target version remains selected. A selected Skill absent from the target version is reported explicitly by preview and removed from the declaration and Projections only during confirmed execution. Skills newly introduced by the target version are not selected automatically.

The atomic mutation boundary remains one Package in one Scope. It reconciles that Scope's manifest, lock, Package Store, and all affected Agent Projections together. Multi-Package and cross-Scope operations are deterministic best-effort batches: each target prepares and commits independently, failures are retained in the final report, and one failure does not roll back or prevent unrelated successful Package updates.

### Package-level Hub contract

The Skill-level `/api/v1/skills/check-update` contract and repeated installed-Skill CLI input are transitional and will be removed after all callers migrate. The replacement is a bounded Package-level batch read, exposed as `POST /api/v1/packages/check-update`, containing unique canonical Package Paths rather than Skill coordinates or local Scope details.

The Hub returns the latest currently published immutable Package Version, Sum, and complete Package membership for each requested Package. It performs bounded set-based Catalog reads and work proportional to the number of unique Packages, never to the number of locally selected Skills or Scopes.

An interactive update check does not synchronously fetch or synchronize a Source Repository. The Hub answers from its published Catalog state. Upstream discovery and publication freshness run independently through Hub-owned background work. This keeps ordinary update checks bounded by Hub and database latency rather than Git-provider latency. The CLI deduplicates Package Paths across selected Scopes, reads each Package result once, and projects it locally onto every corresponding Scope declaration.

Preview resolves Package Info but does not need the complete Package ZIP merely to report availability and membership impact. Confirmed execution downloads and verifies the immutable artifact before mutation. The immutable coordinate and state-token revalidation bind execution to the previewed target without making a fast availability check claim that artifact application cannot fail.

### App behavior

The App consumes Package Update Previews through the bundled CLI and does not call Hub HTTP or reconstruct update plans from Skill rows. Its update count and primary update list are Package-based. Within the currently selected Global or Workspace Scope, each `Scope × Package Path` update target appears as one Package card visually consistent with the Discover journey's Skill cards while retaining Package identity. A card shows Package avatar and name, current and target versions, affected selected-Skill count, member-removal impact when present, status, and one Update action. The Library does not render a separate available-update alert or instructional banner above the list; Package cards and the update filter communicate availability without duplicating the same state.

The App intentionally exposes only one-Package-at-a-time execution. It has no Package selection checkboxes, select-all control, multi-Package update button, or batch confirmation surface. Clicking a card's Update action directly begins that exact Package update from the represented preview state, publishes progress and outcome on that card, disables only duplicate action for the same target, and leaves other cards and navigation interactive. Completion refreshes the affected Scope inventory and update preview. The CLI retains single-Scope and cross-Scope batch preview and execution for terminal users and automation; the App is deliberately less expansive because multi-Package desktop updates are expected to be uncommon and individual actions keep impact legible.

The App does not expose `--dry-run` terminology. Preview is an internal prerequisite for rendering each Package card and binding its Update action. A Package may expand or navigate to detail for member impact, but Skills have no independent update checkbox or action. The App may retain a short-lived preview while the represented inventory and Scope state tokens remain unchanged, avoiding repeated checks when a user changes filters or opens Package detail.

Machine output is language-neutral and ordered deterministically by Scope and Package Path. Dry-run returns success when the requested check completed, regardless of whether updates are available; availability is expressed in structured status. Resolution, validation, or partial execution failures retain stable nonzero process behavior and complete per-target JSON results where execution reached a reportable batch boundary.

## Rollout

Implementation proceeds in compatibility-preserving stages:

1. Add the Package-level Hub update-check contract backed only by published Catalog state, with latency and one-query-per-batch regression coverage. Keep the Skill-level route temporarily.
2. Add Package preview domain models and the CLI Hub client. Deduplicate Package Paths across local inputs before transport.
3. Add `skillsgo update --dry-run` for Global, current Workspace, and explicit Workspace scopes. Omitting the Package selects every Package in that one Scope.
4. Refactor confirmed `skillsgo update` to consume the same preview and state-token validation path. Preserve per-Package atomicity and batch best-effort behavior.
5. Migrate the App update count, Package-card list, detail, and one-Package execution flows from Skill availability to Package previews; remove the separate update banner, update selection, and batch controls from the App while retaining CLI batch behavior.
6. Move Added Project ownership into the CLI Managed Scope registry and migrate existing App registrations without scanning disk.
7. Enable cross-Scope `skillsgo update --all` using the registry, deduplicated Hub reads, and independent Scope results.
8. Remove the Skill-level Hub route, `hub check-update --installed`, Skill update-availability DTOs, and App logic that merges Skill selections back into Packages.

Stages one through four form the minimum terminal and performance correction. Cross-Scope `--all` is not enabled until the Managed Scope registry is authoritative.

## Considered options

- **Retain Skill-level checks and optimize their SQL**: removes the immediate N+1 query but preserves a false domain model, Skill-count-based payloads, misleading UI counts, and redundant version comparison.
- **Use `update --dry-run` for one Scope but keep `--all` as all Packages in that Scope**: avoids a registry but overloads `--all` and cannot express the requested cross-Scope operation predictably.
- **Discover every Workspace by scanning disk**: makes `--all` convenient but violates explicit project ownership, creates unbounded work, and can mutate projects the user never authorized SkillsGo to manage.
- **Synchronously query Git providers for every check**: maximizes freshness at request time but makes availability depend on provider latency and availability. Published Catalog state with background refresh provides a bounded product read and preserves Hub ownership of publication.
- **Make a cross-Scope batch globally atomic**: offers a simple headline but requires distributed filesystem rollback across unrelated roots and prevents independent progress. Per-Package, per-Scope transactions match existing reconciliation boundaries.
- **Expose CLI-equivalent batch update controls in the App**: maximizes surface parity but adds selection, confirmation, partial-failure, and progress complexity for an uncommon desktop workflow. Package cards with one direct Update action preserve clear impact while the CLI serves batch users and automation.

## Consequences

Update vocabulary, transport, UI, and execution align with the Package Store and manifest model established by ADR-0010. A large Package has the same Hub check complexity whether one or one hundred Skills are selected. Multiple Scopes using the same Package share one Hub resolution while retaining independent local versions and transactions.

The CLI gains durable Managed Scope registry responsibility, and the App must migrate Added Projects to that authority. Hub background freshness becomes product-significant because checks no longer force an upstream synchronization. Operators must observe publication-refresh age and failures separately from interactive update latency. The App and CLI intentionally expose different orchestration breadth over the same Package transaction: the App updates one visible Package card at a time, while the CLI retains deterministic batch operations.

The transition temporarily carries both Skill-level and Package-level contracts. Compatibility code is bounded by the rollout and must be deleted after App and CLI migration rather than retained as a permanent alternate update model.
