# ADR 0007: Host the Public Web Surface on Cloudflare

- Status: Accepted
- Date: 2026-07-20

## Context

SkillsGo needs one public Web surface for the product landing page, indexable Hub discovery, and product and developer documentation authored in Markdown and MDX. The Hub runs as a Go service on Railway. Serving public pages from the Hub binary or Railway filesystem would couple presentation releases to Hub releases and make Railway handle traffic that can be served as cached or immutable assets.

## Decision

Create `web/` as an independent Node.js workspace using Fumadocs, MDX, TanStack Start, Vite, React, and Tailwind CSS. It owns the product overview at each locale root, Hub discovery under `/hub`, and documentation under `/docs`. Use TanStack Start prerendering to emit indexable HTML, JavaScript, CSS, Markdown views, LLM indexes, and a static Orama documentation search index under `dist/client`.

Deploy `dist/client` with Cloudflare Workers Static Assets. Prerendered requests are served from Cloudflare storage and cache without reaching the Railway Hub origin. Web may present the App, CLI, Hub, and Cloud-owned ranking projections and may consume their public APIs, but it does not own their domain language or runtime contracts. The Go Hub remains authoritative for public Skill identity, metadata, search, and immutable artifacts; SkillsGo Cloud remains authoritative for installation events and rankings.

Retire the inherited `hub/docs/` Hugo tree after the independent documentation workspace is established. The Hub workspace does not contain or build a second documentation site.

## Consequences

- Public Web development and releases are independent from Hub deployments.
- The removed inherited Hugo tree remains recoverable from repository history but has no maintained build or deployment entry point.
- Static product, Hub entry, and documentation traffic does not consume Railway compute or bandwidth.
- Root validation gains a Node.js 22 and pnpm requirement for Web checks.
- Cross-context facts remain canonical in context maps and ADRs; public MDX pages must follow those sources rather than redefine them.
- A future same-origin deployment may use Cloudflare path routing to serve cached Web assets and proxy only explicit API requests to Railway without changing the public `/hub` route boundary.
