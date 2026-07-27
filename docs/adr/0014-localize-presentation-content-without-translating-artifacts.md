---
status: accepted
---

# Localize presentation content without translating artifacts

SkillsGo presents Package and Skill descriptions plus human-readable Skill documents in every language supported by the App. Source content may use any language. Hub-generated translations improve discovery and reading, but they never become installable or executable Skill content.

## Decision

The Hub owns presentation localization for Package descriptions, immutable-version Skill descriptions, and immutable-version Skill document bodies. The supported presentation-language set is `en`, `zh-Hans`, `zh-Hant`, `ja`, `ko`, `fr`, `de`, `it`, `es`, `pt-BR`, `ru`, `ar`, `hi`, `id`, `tr`, `nl`, `pl`, `th`, `vi`, `ms`, `sv`, and `uk`.

The public product parameter is named `lang` across Hub HTTP, Protocol JSON, CLI flags, and App-to-CLI calls. Omitting `lang` requests source content. Supplying `lang` requests that language, with Package or Skill description and Skill document resolving independently and falling back independently to source content.

Source descriptions remain in PostgreSQL. Source `SKILL.md` documents remain immutable sidecars beside Package Info and ZIP objects. Localized Skill document bodies use the deterministic sibling name `SKILL.{lang}.md`; they contain no frontmatter and are presentation documents rather than Agent Skills manifests. They never enter the Package ZIP, Package Sum, Scope Package Store, Package Projection, Agent installation path, or execution flow.

One Catalog localization projection records successful outcomes. A translated description stores its text in PostgreSQL. A translated Skill document stores only its successful localization identity; its object key is derived from Package Path, immutable Version, exact Skill Path, and canonical language. A source outcome records that the translation model determined the source already satisfies the requested language, preventing repeated work without duplicating source bytes.

Translation is asynchronous and idempotent. River owns queued, running, retry, and terminal-failure state. The Catalog records only usable translated or source outcomes, keyed by source digest and prompt revision. The translation model returns either `translate` with content or `keep_source`; no separate language-detection dependency is introduced.

Description and Skill-document translation share language normalization, identifier protection, prompt-injection resistance, source-digest identity, and result vocabulary. They use separate task prompts and validators because plain short descriptions and structured Markdown documents have incompatible output and preservation requirements. Frontmatter is parsed by the shared Skill manifest contract, Skill descriptions use the description translator, and only the Markdown body uses the document translator.

The App normally requests its selected language and offers a source-content control that repeats the detail request without `lang`. It does not require descriptions and documents to become localized atomically. Local installed-Skill detail continues to show the actual filesystem document by default.

## Consequences

Presentation localization can evolve without changing immutable distribution identity or Agent behavior. Missing, invalid, or unreadable localized content degrades to source content instead of failing discovery or detail. Fixed localized object names require validation before publication and revalidation through source digests and prompt revisions; localized objects are mutable presentation projections and must not use the immutable cache policy of source artifacts.

Search can index translated descriptions while retaining source identity. Historical Skill translations remain naturally version-scoped because they reference immutable Skill rows. Package-description translations are refreshed when their mutable source digest changes.
