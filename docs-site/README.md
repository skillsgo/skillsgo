# SkillsGo Documentation Site

This workspace publishes the public SkillsGo documentation with Fumadocs, MDX, TanStack Start, Vite, and Tailwind CSS.

## Development

Node.js 22 or newer is required.

```bash
pnpm install
pnpm dev
```

The development server is available at <http://localhost:3100>. English pages live at `/en/docs`, and Simplified Chinese pages live at `/zh-CN/docs`.

Edit or add English Markdown and MDX files under `content/docs`. Add the matching Simplified Chinese translation with a `.zh-CN.mdx` suffix, such as `getting-started.zh-CN.mdx`; Fumadocs rebuilds both locale collections automatically. Keep the English page as the canonical source and preserve the same slug in its translation.

## Validation

```bash
pnpm typecheck
pnpm build
```

The production build prerenders both locale trees, localized Markdown and LLM exports, and the bilingual search index to `dist/client`. It can be hosted by any static file server or CDN.

## Cloudflare deployment

```bash
pnpm deploy
```

Wrangler uploads `dist/client` to Cloudflare Workers Static Assets. Attach the desired documentation domain to the `skillsgo-docs` Worker in Cloudflare. Static documentation requests are then served from Cloudflare's asset storage and cache; they do not reach the Railway-hosted Hub.

## Content Boundary

This site contains public product and developer documentation. Repository-internal ADRs, context maps, agent instructions, implementation plans, and reusable standards remain in the repository's existing documentation locations and are not sourced automatically into this site.
