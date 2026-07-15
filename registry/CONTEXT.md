# SkillsGo Registry

The Registry context turns public Skill sources into stable identities and immutable artifacts, then serves discovery and distribution APIs.

## Language

**Skill**:
A set of Agent instructions and supporting resources rooted at a valid `SKILL.md`. A Skill's name and description are mutable metadata, not its identity.
_Avoid_: plugin, application, extension

**Skill Source**:
A GitHub, GitLab, well-known endpoint, or other supported public source containing a `SKILL.md` and its resources.
_Avoid_: Registry-owned repository, cloud Skill

**Skill Identity**:
The stable identity of a logical Skill. For GitHub, identity combines the repository identity with the normalized directory containing `SKILL.md`; a fork or directory move creates a new identity unless an explicit migration relates it.
_Avoid_: Skill name, slug, repository URL alone

**Skill Coordinate**:
The human-readable protocol address of a Skill, such as `github.com/owner/repository/-/skills/example`. The `/-/` separator is omitted for a repository-root Skill.
_Avoid_: opaque artifact ID, name-only lookup

**Manifest**:
The normalized metadata extracted from the `SKILL.md` frontmatter, including at least the Skill name and description while preserving supported specification fields.
_Avoid_: complete Skill archive, rendered Markdown body

**Info**:
The immutable resolution metadata for one Skill version, including the resolved version, source commit, directory tree SHA, origin, audited Risk Assessment, and Content Digest for the exact artifact bytes served by the Registry.
_Avoid_: Manifest, mutable branch response

**Immutable Skill Artifact**:
The installable file set for one Skill at one resolved source commit. A branch such as `main` is a movable reference that resolves to an immutable artifact before download and caching.
_Avoid_: live repository directory, mutable cache entry

**Content Digest**:
The deterministic SHA-256 identity of a normalized Skill artifact. Archive compression has its own digest and must not change the content identity.
_Avoid_: archive hash, Git tree SHA

**Content Match**:
An exact lookup of immutable Registry artifacts by Content Digest, optionally ranked by a source hint. It supports reviewed association of existing content and never treats a matching name as evidence of identity.
_Avoid_: fuzzy name match, mutable branch lookup, automatic ownership claim

**Registry Origin**:
The trusted Registry base used to resolve metadata and download an artifact. Clients may use the official service or a self-hosted Origin and still verify content digests.
_Avoid_: Registry account, mirror name

**Trust Level**:
The Registry's statement about source ownership and maintenance, including unverified, community verified, publisher verified, official, warned, and delisted states.
_Avoid_: safety score, popularity rank

**Risk Assessment**:
An append-only assessment bound to an immutable artifact. Re-scanning creates a new assessment rather than overwriting historical evidence.
_Avoid_: mutable Skill status, trust level

**Install Event**:
An idempotent, privacy-limited event reporting that a Skill version was installed for a scope and set of Agents. Install events power aggregate ranking without becoming an account activity log.
_Avoid_: Agent invocation telemetry, user tracking event

**All-time Ranking**:
The ordering of public Skills by total accepted install events.
_Avoid_: recommendation feed

**Trending Ranking**:
The ordering of public Skills by install events during the latest 24-hour window.
_Avoid_: all-time ranking

**Hot Ranking**:
The ordering of public Skills by short-term installation velocity and its change from the comparison period.
_Avoid_: editorial recommendation, trending alias
