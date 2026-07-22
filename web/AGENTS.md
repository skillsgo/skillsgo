# SkillsGo Web
> F1/F2 Workspace Map | Parent: `/AGENTS.md` | Workspace: `@skillsgo/web`

## Runtime

- Node.js 22 or newer.
- pnpm 10.33.2, pinned by `package.json#packageManager`.
- React 19 rendered by TanStack Start through Vite.
- Fumadocs Core, UI, and MDX provide the documentation shell, content pipeline, and search surface.
- TanStack Start prerendering emits indexable product, Hub, and documentation pages suitable for CDN hosting.
- Production prerendering binds its ephemeral Vite preview server to IPv4 loopback so Linux and macOS resolve every internal crawl request to the same listener.

## Commands

```bash
pnpm install
pnpm dev
pnpm typecheck
pnpm build
pnpm preview
pnpm deploy
```

## Entry Points

- `vite.config.ts`: Vite, MDX, Tailwind, TanStack Start, and SPA prerendering integration.
- `wrangler.jsonc`: Cloudflare Workers Static Assets deployment from `dist/client`.
- `source.config.ts`: Fumadocs MDX collection definition for `content/docs`.
- `src/router.tsx`: TanStack Router creation entry.
- `src/routes/__root.tsx`: HTML document, global styles, localized Fumadocs providers, and search.
- `src/routes/$lang/docs/$.tsx`: locale-aware documentation page loading and rendering boundary.
- `src/routes/$lang/hub/index.tsx`: localized public Hub landing and discovery boundary.
- `content/docs/`: English source pages plus locale-suffixed user-facing translations.

## Top-Level Layout

| Path | Responsibility |
| --- | --- |
| `content/docs/` | Authored public documentation and navigation metadata. |
| `src/components/` | Fumadocs MDX, search, and not-found adapters. |
| `src/lib/` | Content source, shared branding, and layout options. |
| `src/routes/` | TanStack Start routes for pages, search, Markdown, and LLM indexes. |
| `src/styles/` | Tailwind and Fumadocs global style entry. |

## Architectural Boundary

This workspace publishes the public SkillsGo website: the product overview at `/`, Hub discovery under `/hub`, and user-facing documentation under `/docs`. It may present the App, CLI, and Hub, but it does not own their domain models or replace canonical ADRs, context maps, or reference standards under `/docs`.

Hub Web routes are a presentation and discovery boundary. The Go Hub remains authoritative for public Skill identity, metadata, search, rankings, and immutable artifacts. Web must not install Skills, mutate local files, or duplicate Hub domain rules.

Author public content in `content/docs` as Markdown or MDX. English files are the canonical documentation source. Locale-suffixed non-English files are user-facing translations only; they must not introduce repository standards, architecture decisions, or facts absent from the English source. This is the narrow localization exception to the repository-wide English documentation rule. Keep repository-internal standards and decisions under `/docs`. Prefer Fumadocs components and tokens over custom documentation UI primitives.

`package.json`, `pnpm-lock.yaml`, `tsconfig.json`, `meta.json`, generated `.source/`, and generated `src/routeTree.gen.ts` are exempt from inline F4 headers because their formats are generated or do not support comments; this map is their contract source of truth. Authored MDX pages are documentation artifacts rather than semantic source files and are also exempt from F4 headers.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
