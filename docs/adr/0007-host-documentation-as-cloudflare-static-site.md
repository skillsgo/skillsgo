# ADR 0007: Host Public Documentation as an Independent Cloudflare Static Site

- Status: Accepted
- Date: 2026-07-20

## Context

SkillsGo needs public product and developer documentation authored in Markdown and MDX. The Hub runs as a Go service on Railway and already contains an inherited Athens/Hugo documentation tree. Serving a new documentation application from the Hub binary or Railway filesystem would couple documentation releases to Hub releases and make Railway handle traffic that can be served entirely as immutable static assets.

## Decision

Create `docs-site/` as an independent Node.js workspace using Fumadocs, MDX, TanStack Start, Vite, React, and Tailwind CSS. Use TanStack Start SPA prerendering to emit HTML, JavaScript, CSS, Markdown views, LLM indexes, and a static Orama search index under `dist/client`.

Deploy `dist/client` with Cloudflare Workers Static Assets. Documentation requests are served from Cloudflare storage and cache without reaching the Railway Hub origin. The workspace may document the App, CLI, and Hub but does not own their domain language or runtime contracts.

Keep the inherited `hub/docs/` Hugo tree unchanged until a separately reviewed migration selects material to preserve or retire. The new documentation workspace does not consume that tree automatically.

## Consequences

- Documentation development and releases are independent from Hub deployments.
- Static documentation traffic does not consume Railway compute or bandwidth.
- Root validation gains a Node.js 22 and pnpm requirement for documentation checks.
- Cross-context facts remain canonical in context maps and ADRs; public MDX pages must follow those sources rather than redefine them.
- A future same-origin deployment may use Cloudflare path routing to serve documentation assets and proxy only dynamic Hub routes to Railway without changing the workspace boundary.
