---
status: superseded
superseded_by:
  - ../../CONTEXT.md
  - ../mvp.md
  - ../user-routes.md
---

# SkillsGo Personal Navigation and Unified Library

This proposal records the original matrix-plan and External Adoption design. It
is no longer an implementation source: the current domain language, direct
Installation Request, Batch Takeover, and shipped navigation are defined by the
documents listed in `superseded_by`.

## Problem Statement

SkillsGo currently proves a narrow search-to-install loop, but it does not yet behave like a complete desktop manager for Agent Skills. Users see three top-level pages without the deeper navigation needed to browse rankings, manage multiple projects, understand which Agents use a Skill, or distinguish SkillsGo-managed targets from Skills already present on disk.

The current App assumes a user-level Codex installation, requires an externally installed CLI during development, and represents installed Skills as a mostly flat list. That model breaks down as soon as one Skill is installed for several Agents, different projects intentionally use different versions, or a user already has Skills installed by another tool. Users need one trustworthy Library that reflects the machine, preserves project intent, and makes every mutation explicit.

## Solution

Build the Personal desktop experience around three stable top-level destinations: Discover, Library, and Settings. Library and Settings use the same Burrow-inspired floating left-rail shell and retain their own navigation state.

Discover provides Hub-backed Search plus Cloud-backed Ranking, Trending, and Hot views. Library provides All Skills, Global, and one location route per Added Project in its left rail. Agent selection remains a combinable multi-select filter in the content toolbar. The Library aggregates all Installation Targets under one logical Library Entry while preserving Version Divergence and exposing External Installations.

Installing a Skill opens an Installation Plan represented as a multi-location by multi-Agent matrix. Users may select any set of cells. The bundled SkillsGo CLI validates and executes the explicit targets, returns structured per-target outcomes, retains successful targets after partial failure, and supports retrying failed targets.

Clean installations first complete the two-step Mandatory Onboarding defined in `mandatory-onboarding.md`. Projects are added through explicit directory selection. External Installations remain inspectable until exact-path removal or verified Repository-backed Batch Takeover. Production App releases bundle a compatible SkillsGo CLI, so terminal setup is never a prerequisite for the GUI.

## User Stories

1. As a new Personal User, I want a short mandatory introduction and project choice before entering the App, so that SkillsGo starts with an explicit local management boundary.
2. As a new Personal User, I want the App to use a bundled SkillsGo CLI, so that I do not need to install terminal tooling first.
3. As a returning Personal User, I want Discover, Library, and Settings to remain the stable top-level destinations, so that the product stays predictable as features grow.
4. As a desktop user, I want Library and Settings to share a visible left-rail shell, so that their deeper capabilities remain one click away without forcing the same navigation pattern onto Discover.
5. As a desktop user, I want project names visible in the rail and Agent names visible in the filter, so that I do not need to memorize icons.
6. As a desktop user, I want long rail labels to truncate and reveal their complete values on hover, so that the layout remains compact without hiding information.
7. As a desktop user, I want dynamic rail content to scroll, so that many projects or Agents do not make navigation unusable.
8. As a user switching between top-level destinations, I want each destination to retain its subpage, query, scroll position, and input state, so that navigation does not destroy my work.
9. As a user running an installation or update, I want the operation to continue when I navigate elsewhere, so that the App behaves like a desktop tool rather than a disposable page.
10. As a reduced-motion user, I want navigation motion to degrade to immediate changes or short fades, so that the interface remains comfortable.
11. As a user looking for a capability, I want to search by name, description, source, and capability terms, so that I can find a relevant Skill without knowing its exact identifier.
12. As a user who wants established Skills, I want an all-time Ranking view, so that I can see widely installed Skills.
13. As a user following current adoption, I want a Trending view based on the latest 24 hours, so that I can see what the ecosystem is using now.
14. As a user looking for fast-rising Skills, I want a Hot view based on short-term velocity, so that sudden changes are visible separately from total popularity.
15. As an international user, I want the four discovery destinations localized through the App's i18n system, so that navigation follows my system language.
16. As a user comparing discovery results, I want each compact card to show the repository identity, name, description, source, and relevant ranking metric, while keeping trust, immutable version, and risk evidence in detail, so that I can scan quickly without losing the deeper audit path.
17. As a user with an existing installation, I want discovery cards to show the target count, so that I know the Skill is already present somewhere.
18. As a user scanning discovery cards, I want every card action to use the concise Install label, while the Installation Plan visibly excludes existing targets, so that compact copy does not permit duplicate installation.
19. As a user browsing a collection, I want empty results to distinguish a real empty collection from a Hub failure, so that I know whether to change my query or retry.
20. As an offline user, I want Discover to show a recoverable offline state, so that an empty screen is not mistaken for no available Skills.
21. As a cautious user, I want to open a Skill before installation, so that I can inspect its real instructions.
22. As a cautious user, I want rendered `SKILL.md` content, so that I can understand the behavior the Agent will receive.
23. As a cautious user, I want source, immutable version, commit, and directory tree information, so that I can audit exactly what will be installed.
24. As a cautious user, I want file and executable-content signals, so that scripts and supporting resources are visible before installation.
25. As a cautious user, I want Risk Assessment and Trust Level to remain separate concepts, so that publisher ownership is not presented as a safety guarantee.
26. As a user returning from Skill detail, I want the originating query, collection position, and scroll offset restored, so that inspection does not reset browsing.
27. As a user viewing an already installed Skill, I want its current Installation Targets and versions visible in remote detail, so that discovery connects to local state.
28. As a keyboard user, I want search, results, detail, and actions to expose clear focus order and focus styling, so that I can complete discovery without a mouse.
29. As a user installing a Skill, I want an Installation Plan matrix, so that locations and Agents are explicit before any files change.
30. As a user with several projects, I want Global and every Added Project to appear as matrix rows, so that I can install across locations in one operation.
31. As a user with several Agents, I want every Installed Agent to appear as a matrix column, so that I can target all available Agent environments.
32. As a user creating a plan, I want to select individual cells, so that I can choose an arbitrary set of targets.
33. As a user creating a broad plan, I want to select a complete row or column, so that common multi-target operations remain fast.
34. As a user creating a plan, I want the App to create only explicitly selected cells, so that it never surprises me with an automatic Cartesian product.
35. As a user adding a new project during installation, I want Add Project available inside the plan, so that I do not lose the Skill or current selection.
36. As a user reinstalling an existing target, I want identical targets marked as already installed, so that the App does not create duplicates.
37. As a user encountering a different installed version, I want the affected cell to show the version conflict, so that replacement is deliberate.
38. As a user encountering a same-name different-source Skill, I want the Skill ID collision explained, so that a familiar name is not treated as proof of equivalence.
39. As a user with a Local Modification, I want the affected target blocked from silent replacement, so that my changes are not lost.
40. As a user confirming an Installation Plan, I want counts for create, replace, skip, conflict, and risk outcomes, so that the plan is understandable at a glance.
41. As a project user, I want Workspace Manifests that will change listed before execution, so that repository modifications are explicit.
42. As a security-conscious user, I want High and Critical Risk Assessments to trigger the configured confirmation policy, so that risky content is never installed silently.
43. As a user executing a multi-target plan, I want per-target progress and outcomes, so that one slow or failed target does not hide the rest.
44. As a user after partial failure, I want successful targets retained, so that unrelated locations are not rolled back.
45. As a user after partial failure, I want to retry only failed targets, so that recovery is efficient and predictable.
46. As a user after installation, I want an explicit View in Library action without forced navigation, so that I control the next step.
47. As a Personal User, I want one All view of every known Skill, so that I can understand my complete local inventory.
48. As a Personal User, I want a Global view, so that user-level Agent capabilities are easy to isolate without exposing scope terminology in navigation.
49. As a project user, I want one rail entry per Added Project, so that project-specific inventories are one click away.
50. As a multi-Agent user, I want every Installed Agent available in a multi-select filter, so that I can inspect Agent coverage within All Skills, Global, or one project.
51. As a user of an Agent with zero Skills, I want it to remain available in the Agent filter, so that the App can guide me to install its first Skill.
52. As a Library user, I want location navigation and Agent filtering to remain separate, so that I can combine one location with any useful Agent subset without duplicate controls.
53. As a Library user, I want search within the current view, so that I can narrow a large inventory without changing navigation semantics.
54. As a Library user, I want one Library Entry per logical Skill, so that installing a Skill in many places does not flood the list.
55. As a Library user, I want compact, selectable rows with Skill identity and Agent coverage, so that I can scan a large inventory without card chrome.
56. As a Library user, I want existing Update and Manage Targets journeys to appear in a floating selection bar, so that row actions remain uncluttered without weakening exact-target review.
57. As a user opening a Library Entry, I want every relevant Installation Target listed with location, Agent, version, type, and health, so that I can act on individual targets.
58. As a user with a Hub Skill, I want to install it to more targets from Library detail, so that discovery is not the only entry point for distribution.
59. As a user checking updates, I want every managed target resolved independently, so that different references and versions remain accurate.
60. As a user updating a Skill, I want to select exact targets, so that project Manifests are never changed implicitly.
61. As a project user, I want an updated target to update its Workspace Manifest after confirmation, so that the project remains reproducible.
62. As a user with a fixed commit target, I want it excluded from misleading update prompts when it has no movable reference, so that pinning remains meaningful.
63. As a user removing a Skill, I want to choose exact targets, so that other Agents and projects remain unchanged.
64. As a user removing the last selected member, I want the Repository dependency, Vendor, and Projections updated atomically, so that no partial managed state remains.
65. As a user with an unhealthy target, I want SkillsGo to report the conflict without repair or destructive removal, so that it never overwrites or deletes an unexpected filesystem object automatically.
66. As a user with an existing Skill installed by another tool, I want it shown as an External Installation, so that the Library reflects the machine rather than only SkillsGo receipts.
67. As a user inspecting an External Installation, I want to read its instructions, files, and risk, so that unmanaged does not mean invisible.
68. As a user with a healthy External Installation, I want update disabled while exact-path removal and explicit Batch Takeover remain available, so that SkillsGo never claims ownership silently.
69. External Adoption is deferred beyond the first release; reinstalling from an explicit source is the only way to create managed ownership.
70. As a user reviewing a Hub match, I want source and version confirmed before association, so that content is not replaced by assumption.
71. As a user pasting an explicit Git source, I want the App to resolve it through the bundled CLI and render the returned Repository members or single Skill with the existing discovery cards, so that uncataloged public sources remain installable without direct App-to-Hub protocol coupling.

GitHub `owner/repository`, `github/owner/repository`, `github.com/owner/repository`, and HTTPS URL forms are equivalent explicit-source inputs. The App sends each form directly to the CLI, which normalizes it to the canonical `github.com/owner/repository` identity before Hub resolution; these inputs do not run keyword search first.
71. As a user with custom content, I want to import an unmatched External Installation as a Local Skill, so that my own Skills can use the same management workflow.
72. As a Local Skill user, I want to install it elsewhere, export it, or remove it, so that local content remains useful without being published.
73. As a Local Skill author, I want import to remain local, so that adoption never publishes private content to a Hub.
74. As a project user, I want to add one or more projects through an operating-system picker that accepts only directories, so that access is explicit and batch setup is efficient.
75. As a project user, I want a project to work without Git or existing SkillsGo files, so that local workspaces are not excluded.
76. As a project user, I want SkillsGo to read the Workspace Manifest, Workspace Manifest, and known Agent Skill directories, so that declared and actual inventory can be reconciled.
77. As a project user, I want projects restored after App restart, so that navigation remains stable.
78. As a project user, I want removing a project from SkillsGo to leave its files untouched, so that navigation cleanup is not destructive.
79. As a user with a moved project, I want a Relocate action, so that its identity and history can be recovered.
80. As a user with an inaccessible project, I want a diagnosable state instead of silent removal, so that permission and storage problems are understandable.
81. As a privacy-conscious user, I want SkillsGo to avoid scanning the disk for projects, so that only explicitly selected directories are inspected.
82. As a user with no Installed Agent, I want discovery to remain available, so that I can evaluate Skills before configuring an Agent.
83. As a user with no Installed Agent, I want the installation sheet to explain the empty matrix and link to Agent guidance, so that the next step is clear.
84. As an offline user, I want Library, projects, Agent-filtered views, and local detail to remain usable, so that local management does not depend on Hub availability.
85. As a user configuring the product, I want separate General, Agents, Hub, Installation Policy, Storage, and About settings, so that unrelated concerns do not accumulate on one page.
86. As a user of a self-hosted Hub, I want to configure and test a custom Hub Origin, so that the App is not locked to the official deployment.
87. As a user diagnosing the App, I want the App and bundled CLI versions visible together, so that compatibility problems are actionable.
88. As an accessibility user, I want reduced transparency, reduced motion, keyboard navigation, and semantic labels supported throughout the new routes, so that visual polish does not reduce usability.
89. As a maintainer, I want all local mutations to remain owned by the SkillsGo CLI, so that Flutter and terminal workflows cannot diverge into separate package managers.
90. As a maintainer, I want App-to-CLI communication to use stable structured contracts, so that localized human output never breaks the GUI.
91. As a maintainer, I want every operation result associated with an explicit Installation Target, so that partial failure and retry are deterministic.
92. As an international contributor, I want repository documentation, specifications, ADRs, and issue content in English, so that collaboration is not language-gated.
93. As a user with manageable existing Skills, I want one localized and truthful Before/After introduction only after Library preflight succeeds, so that I understand the value before choosing once and can still use the counted manual action after skipping.

## Implementation Decisions

- Keep Discover, Library, and Settings as the only top-level destinations. Use the existing white selected capsule and spring movement while preserving reduced-motion behavior.
- Use the shared floating rounded left-rail shell for Library and Settings. Rail items use visible labels; the rail is not an icon-only clone of Burrow. Discover keeps its compact collection navigation above the result surface.
- Discover rail order is Search, Ranking, Trending, and Hot. Search is the initial route.
- Library rail order is All Skills, Global, and every Added Project. All Skills and Global remain fixed at the top, only the Added Project list scrolls, and Add Project remains pinned at the bottom. Fixed dividers separate the scrollable project list from both the leading destinations and footer action; neither divider moves with project scrolling. The project list uses one slim, rounded desktop scrollbar that does not compete with project labels or selected capsules; the platform must not add a second hover scrollbar. Added Project rows use a compact desktop density while the fixed destinations and Add Project retain their larger navigation targets. The toolbar owns search, update status, and a combinable Agent multi-select; it does not repeat project selection. An empty Added Project uses a concise, project-name-independent title and a Browse Skills action that returns to Discover without setup guidance.
- Present the first eligible Batch Takeover plan in the active Library as a one-time, persisted Before/After introduction. Keep the illustration count-bound, localized, accessible, reduced-motion-aware, and separate from authorization; both Confirm and Skip complete the introduction, while the existing counted action remains the permanent manual entry.
- Settings rail order is General, Reminders, Agents, and Advanced. Advanced ends with an explicit local Library refresh that rescans local inventory without mutating installations.
- Preserve each top-level destination's last subroute, search input, scroll position, and in-flight operations for the current session. Detail navigation carries an explicit origin so Back restores the source view.
- Production App packages a platform-compatible SkillsGo CLI and verifies its availability and compatibility at startup. The bundled executable is not installed into the user's system `PATH`.
- Keep the App's highest test and orchestration seam as `SkillsGateway`. UI code receives domain objects and operations rather than directly invoking HTTP, processes, or the filesystem.
- Expand the Gateway domain around Installed Agents, Added Projects, Library Entries, Installation Targets, Installation Plans, Target Results, External Installations, Local Skills, Version Divergence, and Hub collection pages.
- Treat the SkillsGo CLI as the only owner of local Skill mutations, Agent Adapter behavior, Repository Dependencies, Workspace Locks, Scope Vendor, and Repository Projections.
- Add a stable CLI machine contract for Installed Agent discovery. Each result includes canonical Agent ID, display name, installed state, supported scopes, and resolved user-level target information. Human CLI output is not part of the App contract.
- Add a stable CLI inventory contract that accepts User Scope plus an explicit list of Added Project roots. It returns Repository ID plus canonical Skill Name when known, an inventory key, provenance, versions, and every target with scope, project, Agent, path, and health.
- Inventory scans known Agent directories only. Project scanning is restricted to Added Projects passed by the App and never expands into general disk discovery.
- Aggregate Hub Skills by Repository ID plus canonical Skill Name, Local Skills by inventory key, and leave External Installations without managed Repository-member identity distinct even when names match.
- The Add Project journey uses the operating system's multi-directory picker. Files are not selectable; canonical duplicate directories are retained only once, and one batch persists all newly selected project references together.
- Persist the Added Project list as App state using stable directory references appropriate to the desktop platform. Removing an Added Project deletes only the reference.
- Model installation as one immutable Repository transaction plus selected member paths and explicit Agents within one declaration scope.
- The CLI preflights every target before mutation and returns target-specific actions such as create, replace, skip, conflict, or blocked-by-risk.
- A Repository transaction atomically commits its Dependency, Lock, Vendor, and Projections. Independent declaration scopes remain independent retry units.
- Structured operation progress must remain machine-readable. The final result is stable JSON; if streaming progress is introduced, it uses a versioned structured event protocol rather than localized text parsing.
- Existing identical targets are skipped. Same-name different-source collisions, Version Divergence, and Local Modifications require explicit resolutions.
- Updating targets resolves each target's own reference and current immutable version. Project updates modify the corresponding Workspace Manifest only after confirmation. Fixed commits without a movable reference do not report an available update.
- Removing a managed member updates the owning Repository dependency and every affected Agent Projection in that declaration scope. Modified Projections are never overwritten.
- Detect External Installations by reconciling known Agent directories with declared Repository Projections. Inspection is read-only until takeover.
- External removal uses the exact discovered target and reviewed filesystem state. It creates no Workspace declaration or inferred source metadata.
- Hub collection contracts remain Search plus ranked Skills using `all_time`, `trending`, and `hot` semantics. Pagination and empty collections must return stable machine-readable shapes.
- Hub detail must provide the immutable metadata needed by the App to display source, Manifest, files, Trust Level, and Risk Assessment without relying on human web pages.
- Keep Hub Origin configurable. Official and self-hosted Origins use the same protocol and content verification rules.
- Risk policy remains artifact-specific: Personal requires additional confirmation for High, blocks Critical by default with an explicit override, and never silently deletes already installed content after a later warning.
- All process execution uses an executable plus argument array and never shell interpolation.
- All new repository documentation, ADRs, specifications, implementation plans, and issue content are written in English. User-facing copy continues through i18n and follows the system language by default.

## Testing Decisions

- A good test asserts behavior visible at an executable or user boundary: rendered navigation, stable JSON, HTTP responses, explicit filesystem effects, and recoverable errors. Tests must not depend on private Widget structure, Cobra helper functions, SQL query text, or implementation call counts.
- The App uses `SkillsGateway` as its primary seam. Widget tests drive a fake Gateway through complete journeys and assert visible states and user actions.
- Extend the existing high-level App journey coverage to include top-level and rail navigation, state restoration, all four Discover views, Skill detail origin restoration, Installation Plan matrix selection, per-target results, Library aggregation, Version Divergence, External Installation adoption, project lifecycle, offline behavior, and accessibility semantics.
- Gateway contract tests use controlled process runners to verify CLI schemas, non-success exit handling, malformed responses, timeout behavior, and error translation; Hub HTTP behavior is tested behind the CLI Hub adapter rather than through an App HTTP client.
- The CLI uses its root `Execute` entry point as the primary seam. Tests provide arguments, stdout, stderr, temporary home and project directories, and controlled Hub HTTP servers.
- Extend CLI command-flow tests to cover Installed Agent discovery, inventory reconciliation, explicit multi-target plans, row and column expansion results, collisions, Local Modifications, per-target partial failure, retry, project Manifest changes, External Installation import, and stable structured output.
- Lower-level Agent Adapter, Repository artifact, Vendor, Projection, and project tests remain appropriate only for deterministic algorithms or safety invariants that are difficult to isolate through the command boundary.
- The Hub HTTP Router tests Search, detail, immutable metadata, pagination, empty arrays, and validation. The independent Cloud service tests Ranking, Trending, Hot, pagination, and idempotent install events through the shared public Protocol conformance suite.
- Hub HTTP tests verify catalog behavior across SQLite and PostgreSQL. Private Cloud tests verify its independent SQLite statistics database and ranking projections.
- Add contract fixtures shared conceptually across App, CLI, and Hub so field names, enum values, and versioned protocol behavior cannot drift. Fixtures test public JSON rather than language-specific internal types.
- Test partial failure with at least one writable target and one failing target, then assert the writable target remains installed and the failed target alone can be retried.
- Test that a same-name different-identity Skill is never merged or overwritten without explicit replacement.
- Test that an External Installation remains visible, cannot be updated or repaired, and can be removed only through an exact reviewed target.
- Test that Local Skill import does not contact a publication endpoint and does not acquire a false online update state.
- Test that removing an Added Project leaves its directory, Workspace Manifest, Workspace Manifest, and Agent Skill directories unchanged.
- Test session navigation state at the Widget seam rather than private state objects.
- Preserve the existing no-shell execution tests and add hostile Skill ID, name, and path inputs to confirm they remain plain arguments.
- Manual desktop acceptance covers bundled CLI discovery, directory-picker permissions, a real multi-Agent matrix operation, partial failure presentation, keyboard navigation, reduced motion, and App restart with restored Added Projects.

## Out of Scope

- Authentication, organizations, Team Plan entitlements, seats, billing, approval, audit, and cloud synchronization.
- Private Skill hosting or enterprise source integration.
- Android and iOS applications.
- Automatic disk scanning for projects or repositories.
- Installing or configuring third-party Agents on the user's behalf.
- Publishing Local Skills to a Hub.
- Ratings, reviews, comments, favorites, personalized recommendations, and social feeds.
- Automatically making versions uniform across projects.
- Background auto-update of Skill content.
- Treating multi-location filesystem operations as one global transaction.
- Updating or automatically repairing an External Installation in the first release.
- Automatic merge of Local Modifications.
- Redesigning the Hub artifact protocol beyond metadata required by the agreed user journeys.
- Team-specific private distribution and policy controls.

## Further Notes

- The Hub exposes Search and Skill hydration. In Cloud mode the App reads ordered ranking IDs and metrics directly from Cloud, then hydrates their authoritative Skill cards through the CLI-mediated Hub boundary.
- The CLI owns Agent Adapters, User Scope, Workspace Scope, Repository Dependencies, Workspace Locks, Scope Vendor, and Repository Projections; the App integrates only through stable machine contracts.
- The current App Gateway is intentionally narrow and Codex-oriented. Expanding that seam should precede the nested navigation implementation so UI code is not built on temporary parsing logic.
- The original external `skills` CLI and `skills.sh` MVP specification is superseded. System ADR-0001 establishes the bundled SkillsGo CLI as the production architecture.
- The Burrow reference supplies visual language and motion quality, not its exact icon-only navigation. SkillsGo requires text because Added Projects and Installed Agents are dynamic user-owned entities.
