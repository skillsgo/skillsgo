---
status: ready-for-agent
---

# SkillsGo Personal Navigation and Unified Library

## Problem Statement

SkillsGo currently proves a narrow search-to-install loop, but it does not yet behave like a complete desktop manager for Agent Skills. Users see three top-level pages without the deeper navigation needed to browse rankings, manage multiple projects, understand which Agents use a Skill, or distinguish SkillsGo-managed targets from Skills already present on disk.

The current App assumes a user-level Codex installation, requires an externally installed CLI during development, and represents installed Skills as a mostly flat list. That model breaks down as soon as one Skill is installed for several Agents, different projects intentionally use different versions, or a user already has Skills installed by another tool. Users need one trustworthy Library that reflects the machine, preserves project intent, and makes every mutation explicit.

## Solution

Build the Personal desktop experience around three stable top-level destinations: Discover, Library, and Settings. Each destination receives a Burrow-inspired floating left rail and retains its own navigation state.

Discover provides Search, Ranking, Trending, and Hot views backed by the SkillsGo Registry. Library provides mutually exclusive All, User Scope, Added Project, and Installed Agent views. It aggregates all Installation Targets under one logical Library Entry while preserving Version Divergence and exposing External Installations.

Installing a Skill opens an Installation Plan represented as a multi-location by multi-Agent matrix. Users may select any set of cells. The bundled SkillsGo CLI validates and executes the explicit targets, returns structured per-target outcomes, retains successful targets after partial failure, and supports retrying failed targets.

Projects are added only through explicit directory selection. External Installations remain inspectable but read-only until the user associates them with an immutable Registry artifact or imports them as a Local Skill. Production App releases bundle a compatible SkillsGo CLI, so terminal setup is never a prerequisite for the GUI.

## User Stories

1. As a new Personal User, I want the App to open directly to Discover, so that I can understand its value without completing setup.
2. As a new Personal User, I want the App to use a bundled SkillsGo CLI, so that I do not need to install terminal tooling first.
3. As a returning Personal User, I want Discover, Library, and Settings to remain the stable top-level destinations, so that the product stays predictable as features grow.
4. As a desktop user, I want each top-level destination to have a visible left rail, so that its deeper capabilities remain one click away.
5. As a desktop user, I want project and Agent names to remain visible in the rail, so that I do not need to memorize icons.
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
16. As a user comparing discovery results, I want each card to show name, description, source, Trust Level, version, risk, and the relevant ranking metric, so that I can make an informed choice.
17. As a user with an existing installation, I want discovery cards to show the target count, so that I know the Skill is already present somewhere.
18. As a user with an existing installation, I want the action to say Install to More Targets, so that the App does not imply a duplicate installation.
19. As a user browsing a collection, I want empty results to distinguish a real empty collection from a Registry failure, so that I know whether to change my query or retry.
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
30. As a user with several projects, I want User Scope and every Added Project to appear as matrix rows, so that I can install across locations in one operation.
31. As a user with several Agents, I want every Installed Agent to appear as a matrix column, so that I can target all available Agent environments.
32. As a user creating a plan, I want to select individual cells, so that I can choose an arbitrary set of targets.
33. As a user creating a broad plan, I want to select a complete row or column, so that common multi-target operations remain fast.
34. As a user creating a plan, I want the App to create only explicitly selected cells, so that it never surprises me with an automatic Cartesian product.
35. As a user adding a new project during installation, I want Add Project available inside the plan, so that I do not lose the Skill or current selection.
36. As a user reinstalling an existing target, I want identical targets marked as already installed, so that the App does not create duplicates.
37. As a user encountering a different installed version, I want the affected cell to show the version conflict, so that replacement is deliberate.
38. As a user encountering a same-name different-source Skill, I want the identity collision explained, so that a familiar name is not treated as proof of equivalence.
39. As a user with a Local Modification, I want the affected target blocked from silent replacement, so that my changes are not lost.
40. As a user confirming an Installation Plan, I want counts for create, replace, skip, conflict, and risk outcomes, so that the plan is understandable at a glance.
41. As a project user, I want Workspace Locks that will change listed before execution, so that repository modifications are explicit.
42. As a security-conscious user, I want High and Critical Risk Assessments to trigger the configured confirmation policy, so that risky content is never installed silently.
43. As a user executing a multi-target plan, I want per-target progress and outcomes, so that one slow or failed target does not hide the rest.
44. As a user after partial failure, I want successful targets retained, so that unrelated locations are not rolled back.
45. As a user after partial failure, I want to retry only failed targets, so that recovery is efficient and predictable.
46. As a user after installation, I want an explicit View in Library action without forced navigation, so that I control the next step.
47. As a Personal User, I want one All view of every known Skill, so that I can understand my complete local inventory.
48. As a Personal User, I want a User Scope view, so that user-level Agent capabilities are easy to isolate.
49. As a project user, I want one rail entry per Added Project, so that project-specific inventories are one click away.
50. As a multi-Agent user, I want one rail entry per Installed Agent, so that I can inspect everything available to that Agent across locations.
51. As a user of an Agent with zero Skills, I want its rail entry to remain visible, so that the App can guide me to install its first Skill.
52. As a Library user, I want project and Agent entries to be mutually exclusive, so that one rail selection always has one clear meaning.
53. As a Library user, I want search within the current view, so that I can narrow a large inventory without changing navigation semantics.
54. As a Library user, I want one Library Entry per logical Skill, so that installing a Skill in many places does not flood the list.
55. As a Library user, I want each entry to summarize target count, projects, Agents, versions, provenance, risk, and health, so that important state is visible before detail.
56. As a user with Version Divergence, I want the number of active versions displayed, so that intentional project pinning is not presented as damage.
57. As a user opening a Library Entry, I want every relevant Installation Target listed with location, Agent, version, type, and health, so that I can act on individual targets.
58. As a user with a Registry Skill, I want to install it to more targets from Library detail, so that discovery is not the only entry point for distribution.
59. As a user checking updates, I want every managed target resolved independently, so that different references and versions remain accurate.
60. As a user updating a Skill, I want to select exact targets, so that project Locks are never changed implicitly.
61. As a project user, I want an updated target to update its Workspace Lock after confirmation, so that the project remains reproducible.
62. As a user with a fixed commit target, I want it excluded from misleading update prompts when it has no movable reference, so that pinning remains meaningful.
63. As a user removing a Skill, I want to choose exact targets, so that other Agents and projects remain unchanged.
64. As a user removing the last active target, I want Store cleanup to honor remaining Workspace Lock references, so that restore remains possible.
65. As a user with an unhealthy target, I want repair or stop-managing actions, so that SkillsGo never deletes an unexpected filesystem object automatically.
66. As a user with an existing Skill installed by another tool, I want it shown as an External Installation, so that the Library reflects the machine rather than only SkillsGo receipts.
67. As a user inspecting an External Installation, I want to read its instructions, files, and risk, so that unmanaged does not mean invisible.
68. As a user with an External Installation, I want update and removal disabled until adoption, so that SkillsGo does not claim ownership silently.
69. As a user adopting an External Installation, I want SkillsGo to attempt an immutable Registry match, so that known content can regain source and update metadata.
70. As a user reviewing a Registry match, I want source and version confirmed before association, so that content is not replaced by assumption.
71. As a user with custom content, I want to import an unmatched External Installation as a Local Skill, so that my own Skills can use the same management workflow.
72. As a Local Skill user, I want to install it elsewhere, export it, or remove it, so that local content remains useful without being published.
73. As a Local Skill author, I want import to remain local, so that adoption never publishes private content to a Registry.
74. As a project user, I want to add a project through the operating-system directory picker, so that access is explicit.
75. As a project user, I want a project to work without Git or existing SkillsGo files, so that local workspaces are not excluded.
76. As a project user, I want SkillsGo to read the Workspace Manifest, Workspace Lock, and known Agent Skill directories, so that declared and actual inventory can be reconciled.
77. As a project user, I want projects restored after App restart, so that navigation remains stable.
78. As a project user, I want removing a project from SkillsGo to leave its files untouched, so that navigation cleanup is not destructive.
79. As a user with a moved project, I want a Relocate action, so that its identity and history can be recovered.
80. As a user with an inaccessible project, I want a diagnosable state instead of silent removal, so that permission and storage problems are understandable.
81. As a privacy-conscious user, I want SkillsGo to avoid scanning the disk for projects, so that only explicitly selected directories are inspected.
82. As a user with no Installed Agent, I want discovery to remain available, so that I can evaluate Skills before configuring an Agent.
83. As a user with no Installed Agent, I want the installation sheet to explain the empty matrix and link to Agent guidance, so that the next step is clear.
84. As an offline user, I want Library, projects, Agent views, and local detail to remain usable, so that local management does not depend on Registry availability.
85. As a user configuring the product, I want separate General, Agents, Registry, Installation Policy, Storage, and About settings, so that unrelated concerns do not accumulate on one page.
86. As a user of a self-hosted Registry, I want to configure and test a custom Registry Origin, so that the App is not locked to the official deployment.
87. As a user diagnosing the App, I want the App and bundled CLI versions visible together, so that compatibility problems are actionable.
88. As an accessibility user, I want reduced transparency, reduced motion, keyboard navigation, and semantic labels supported throughout the new routes, so that visual polish does not reduce usability.
89. As a maintainer, I want all local mutations to remain owned by the SkillsGo CLI, so that Flutter and terminal workflows cannot diverge into separate package managers.
90. As a maintainer, I want App-to-CLI communication to use stable structured contracts, so that localized human output never breaks the GUI.
91. As a maintainer, I want every operation result associated with an explicit Installation Target, so that partial failure and retry are deterministic.
92. As an international contributor, I want repository documentation, specifications, ADRs, and issue content in English, so that collaboration is not language-gated.

## Implementation Decisions

- Keep Discover, Library, and Settings as the only top-level destinations. Use the existing white selected capsule and spring movement while preserving reduced-motion behavior.
- Add one floating rounded left rail per top-level destination. Rail items use visible labels; the rail is not an icon-only clone of Burrow.
- Discover rail order is Search, Ranking, Trending, and Hot. Search is the initial route.
- Library rail order is All, User Scope, Added Projects, Add Project, divider, and every Installed Agent. Location and Agent entries are mutually exclusive rather than combinable filters.
- Settings rail order is General, Agents, Registry, Installation Policy, Storage, and About.
- Preserve each top-level destination's last subroute, search input, scroll position, and in-flight operations for the current session. Detail navigation carries an explicit origin so Back restores the source view.
- Production App packages a platform-compatible SkillsGo CLI and verifies its availability and compatibility at startup. The bundled executable is not installed into the user's system `PATH`.
- Keep the App's highest test and orchestration seam as `SkillsGateway`. UI code receives domain objects and operations rather than directly invoking HTTP, processes, or the filesystem.
- Expand the Gateway domain around Installed Agents, Added Projects, Library Entries, Installation Targets, Installation Plans, Target Results, External Installations, Local Skills, Version Divergence, and Registry collection pages.
- Treat the SkillsGo CLI as the only owner of local Skill mutations, Content-addressed Store state, Agent Adapter behavior, Installation Receipts, Workspace Manifests, and Workspace Locks.
- Add a stable CLI machine contract for Installed Agent discovery. Each result includes canonical Agent ID, display name, installed state, supported scopes, and resolved user-level target information. Human CLI output is not part of the App contract.
- Add a stable CLI inventory contract that accepts User Scope plus an explicit list of Added Project roots. It returns logical Skill identity when known, provenance, versions, and every Installation Target with scope, project, Agent, path, mode, receipt state, and health.
- Inventory scans known Agent directories only. Project scanning is restricted to Added Projects passed by the App and never expands into general disk discovery.
- Aggregate Registry Skills by stable Skill Identity, Local Skills by local identity, and leave unidentified External Installations distinct even when names match.
- Persist the Added Project list as App state using stable directory references appropriate to the desktop platform. Removing an Added Project deletes only the reference.
- Model an Installation Plan as one Skill artifact plus an explicit list of location-and-Agent targets. Row and column selection are UI shortcuts that produce exact cells before execution.
- The CLI preflights every target before mutation and returns target-specific actions such as create, replace, skip, conflict, or blocked-by-risk.
- Multi-target execution commits each Installation Target independently. A failure does not roll back unrelated successful targets. The final structured response includes every Target Result and enough identity to retry only failed targets.
- Structured operation progress must remain machine-readable. The final result is stable JSON; if streaming progress is introduced, it uses a versioned structured event protocol rather than localized text parsing.
- Existing identical targets are skipped. Same-name different-identity collisions, Version Divergence, and Local Modifications require explicit resolutions.
- Updating targets resolves each target's own reference and current immutable version. Project updates modify the corresponding Workspace Lock only after confirmation. Fixed commits without a movable reference do not report an available update.
- Removing a target never removes other targets for the same Library Entry. Store pruning remains a separate reference-aware operation.
- Detect External Installations by reconciling known Agent directories with Installation Receipts. Inspection is read-only until adoption.
- External adoption first attempts a Registry match using content identity and source hints. A confirmed match becomes a managed Registry Skill; an unmatched item may be imported as a Local Skill without publication or an online update source.
- Registry collection contracts remain Search plus ranked Skills using `all_time`, `trending`, and `hot` semantics. Pagination and empty collections must return stable machine-readable shapes.
- Registry detail must provide the immutable metadata needed by the App to display source, Manifest, files, Trust Level, and Risk Assessment without relying on human web pages.
- Keep Registry Origin configurable. Official and self-hosted Origins use the same protocol and content verification rules.
- Risk policy remains artifact-specific: Personal requires additional confirmation for High, blocks Critical by default with an explicit override, and never silently deletes already installed content after a later warning.
- All process execution uses an executable plus argument array and never shell interpolation.
- All new repository documentation, ADRs, specifications, implementation plans, and issue content are written in English. User-facing copy continues through i18n and follows the system language by default.

## Testing Decisions

- A good test asserts behavior visible at an executable or user boundary: rendered navigation, stable JSON, HTTP responses, explicit filesystem effects, and recoverable errors. Tests must not depend on private Widget structure, Cobra helper functions, SQL query text, or implementation call counts.
- The App uses `SkillsGateway` as its primary seam. Widget tests drive a fake Gateway through complete journeys and assert visible states and user actions.
- Extend the existing high-level App journey coverage to include top-level and rail navigation, state restoration, all four Discover views, Skill detail origin restoration, Installation Plan matrix selection, per-target results, Library aggregation, Version Divergence, External Installation adoption, project lifecycle, offline behavior, and accessibility semantics.
- Gateway contract tests use controlled HTTP clients and process runners to verify Registry and CLI schemas, non-success status handling, malformed responses, timeout behavior, and error translation.
- The CLI uses its root `Execute` entry point as the primary seam. Tests provide arguments, stdout, stderr, temporary home and project directories, and controlled Registry HTTP servers.
- Extend CLI command-flow tests to cover Installed Agent discovery, inventory reconciliation, explicit multi-target plans, row and column expansion results, collisions, Local Modifications, per-target partial failure, retry, project Lock changes, External Installation import, and stable structured output.
- Lower-level Store, Agent Adapter, target, and project tests remain appropriate only for deterministic algorithms or safety invariants that are difficult to isolate through the command boundary.
- The Registry uses its HTTP Router as the primary seam. Tests exercise Search, Ranking, Trending, Hot, detail, immutable metadata, pagination, empty arrays, validation, and idempotent install events through HTTP requests.
- Registry HTTP tests run against SQLite for fast coverage. Existing PostgreSQL integration coverage verifies database portability for catalog and ranking behavior.
- Add contract fixtures shared conceptually across App, CLI, and Registry so field names, enum values, and versioned protocol behavior cannot drift. Fixtures test public JSON rather than language-specific internal types.
- Test partial failure with at least one writable target and one failing target, then assert the writable target remains installed and the failed target alone can be retried.
- Test that a same-name different-identity Skill is never merged or overwritten without explicit replacement.
- Test that an External Installation remains visible but cannot be updated or removed before adoption.
- Test that Local Skill import does not contact a publication endpoint and does not acquire a false online update state.
- Test that removing an Added Project leaves its directory, Workspace Manifest, Workspace Lock, and Agent Skill directories unchanged.
- Test session navigation state at the Widget seam rather than private state objects.
- Preserve the existing no-shell execution tests and add hostile coordinate, name, and path inputs to confirm they remain plain arguments.
- Manual desktop acceptance covers bundled CLI discovery, directory-picker permissions, a real multi-Agent matrix operation, partial failure presentation, keyboard navigation, reduced motion, and App restart with restored Added Projects.

## Out of Scope

- Authentication, organizations, Team Plan entitlements, seats, billing, approval, audit, and cloud synchronization.
- Private Skill hosting or enterprise source integration.
- Android and iOS applications.
- Automatic disk scanning for projects or repositories.
- Installing or configuring third-party Agents on the user's behalf.
- Publishing Local Skills to a Registry.
- Ratings, reviews, comments, favorites, personalized recommendations, and social feeds.
- Automatically making versions uniform across projects.
- Background auto-update of Skill content.
- Treating multi-location filesystem operations as one global transaction.
- Updating or removing an External Installation before adoption.
- Automatic merge of Local Modifications.
- Redesigning the Registry artifact protocol beyond metadata required by the agreed user journeys.
- Team-specific private distribution and policy controls.

## Further Notes

- The existing Registry already exposes Search and the three ranking sort modes, but the App currently consumes only Search.
- The existing CLI already models many Agent Adapters, User Scope, Workspace Scope, the Content-addressed Store, Installation Receipts, Workspace Manifests, and Workspace Locks. The missing work is primarily stable high-level discovery, reconciliation, and multi-target operation contracts.
- The current App Gateway is intentionally narrow and Codex-oriented. Expanding that seam should precede the nested navigation implementation so UI code is not built on temporary parsing logic.
- The original external `skills` CLI and `skills.sh` MVP specification is superseded. System ADR-0001 establishes the bundled SkillsGo CLI as the production architecture.
- The Burrow reference supplies visual language and motion quality, not its exact icon-only navigation. SkillsGo requires text because Added Projects and Installed Agents are dynamic user-owned entities.
