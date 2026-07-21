# SkillsGo Web

This workspace publishes the public SkillsGo product site, Hub discovery experience, and documentation with Fumadocs, MDX, TanStack Start, Vite, and Tailwind CSS.

## Development

Node.js 22 or newer is required.

```bash
pnpm install
pnpm dev
```

The development server is available at <http://localhost:3100>. Product pages live at `/en` and `/zh-CN`, Hub pages at `/en/hub` and `/zh-CN/hub`, and documentation at each locale's `/docs` path.

Edit or add English Markdown and MDX files under `content/docs`. Add the matching Simplified Chinese translation with a `.zh-CN.mdx` suffix, such as `getting-started.zh-CN.mdx`; Fumadocs rebuilds both locale collections automatically. Keep the English page as the canonical source and preserve the same slug in its translation.

## Validation

```bash
pnpm typecheck
pnpm build
```

The production build prerenders the product and Hub entry pages, both documentation locale trees, localized Markdown and LLM exports, and the bilingual documentation search index to `dist/client`. It can be hosted by any static file server or CDN.

## Cloudflare deployment

```bash
pnpm deploy
```

Wrangler uploads `dist/client` to Cloudflare Workers Static Assets. Attach the public Web domain to the `skillsgo-web` Worker in Cloudflare. Prerendered product, Hub, and documentation pages are served from Cloudflare storage and cache; future dynamic Hub reads remain explicit API calls to the authoritative Hub service.

## Content Boundary

This workspace owns public presentation only. The Go Hub remains authoritative for public Skill identity, metadata, search, rankings, and immutable artifacts. Repository-internal ADRs, context maps, agent instructions, implementation plans, and reusable standards remain in the repository's existing documentation locations and are not sourced automatically into this site.
