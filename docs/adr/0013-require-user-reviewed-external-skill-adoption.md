---
status: accepted
---

# Require user-reviewed External Skill adoption

SkillsGo adopts an External Installation only after presenting Hub-backed choices and receiving an explicit user-reviewed selection. Candidate discovery lowers the cost of adoption but never decides identity or version for the user. This decision supersedes ADR-0006 and the takeover-specific constraints in ADR-0010: skills.sh metadata no longer identifies an immutable Repository Version, and External bytes are not matched against a Git Tree SHA or required to equal the selected Repository member.

## Decision

The Library remains local-first. Inventory discovers External Installations and their local name, description, scope, Agent target, physical path, and any supported skills.sh source record without calling the Hub. Candidate discovery begins only when the user enters the adoption review for the currently selected Library location. All Skills covers User Scope and every accessible Added Project, Global covers only User Scope, and a Project location covers only that Workspace Scope.

A supported skills.sh record contributes only its canonical Repository ID. SkillsGo does not interpret `skillFolderHash`, `computedHash`, a movable ref, or other skills.sh fields as a version decision or content-authentication proof. The External Skill's canonical Skill Name identifies the logical Repository member. The user chooses one Hub-published immutable Repository Version that contains that Skill Name; the latest eligible version is selected by default, and versions that do not contain the member cannot form an executable selection.

An External Installation without a trusted source is manually matched. The App submits one deduplicated batch to the CLI `find --input` machine boundary, and the CLI submits one batch Find request to the Hub. Adoption queries set `exactName` so unrelated description or Repository matches cannot consume the ten-candidate bound. A supported skills.sh Repository ID becomes an optional exact Source restriction on its query; manual entries omit Source. The Hub returns bounded same-name Skill cards carrying Repository ID, Skill Name, description, and published-version metadata. The App compares each returned description with the local description, orders the candidates by that presentation-only similarity, and displays at most ten results without pagination. The highest-ranked candidate is selected by default. Similarity is not an identity proof, does not create an automatic execution permission, and does not cross the CLI boundary as a Hub-owned recommendation. An empty result set leaves the External Installation unmatched and unchanged.

After a Repository and Skill Name are selected, skills.sh-backed and manually matched installations use the same flow. The App presents eligible immutable Repository Versions, defaults to the latest, and automatically includes each complete row in the proposed adoption set. The user may opt out per row. One final confirmation authorizes only the complete, still-selected rows; incomplete and opted-out rows remain External Installations.

The App never calls the Hub directly. The CLI owns local evidence collection, source normalization, Hub requests, state-bound planning, execution, and filesystem mutations. The Hub returns published Repository, Version, member, and description facts; it does not rank adoption candidates or choose a version. Candidate ordering and default presentation remain App policy.

Execution revalidates the planned External path and selected immutable coordinate but does not compare the External bytes with the selected member. It installs the authenticated complete Repository Artifact through the ordinary Dependency, Lock, Scope Vendor, and Repository Projection transaction. Only after that transaction commits does it remove the External directory from its active Agent path. A changed, missing, conflicting, or otherwise non-executable row is skipped independently through the existing takeover result flow.

The dependency identity within one scope is `Repository ID + Repository Version`, not Repository ID alone. One scope may therefore vendor and project different immutable versions of the same Repository when independently adopted Skills require them. Each selected Skill remains associated with exactly one Repository coordinate, and one physical Agent target path still exposes only one active Skill.

The superseded External directory enters a SkillsGo recovery area for 30 days. Recovery is tracked per Skill, not per batch. Reverting removes that managed Skill selection through the ordinary managed-removal flow and restores the original External directory only when its original path is unoccupied; SkillsGo never overwrites a later occupant. Expired recovery content may be cleaned automatically.

## Consequences

Adoption becomes a user-reviewed mapping rather than a proof that local and published bytes are identical. This deliberately assigns candidate and version choice to the user while keeping artifact authentication, transaction integrity, path-state validation, and reversible filesystem handling within SkillsGo.

The existing Repository-ID-keyed Manifest and Lock model cannot represent two versions of one Repository in one scope and must be replaced before this adoption flow can execute. The UI may be implemented and refined first against typed in-memory fixtures, but it must not invoke the existing byte-verifying takeover command or imply that the new backend contract already exists.
