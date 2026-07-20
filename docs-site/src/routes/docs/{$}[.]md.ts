/*
 * [INPUT]: Depends on route slug conversion and English processed Markdown from the Fumadocs source.
 * [OUTPUT]: Provides a backwards-compatible English Markdown representation of each documentation page.
 * [POS]: Serves as the legacy unprefixed companion to the canonical locale-prefixed Markdown route.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { getLLMText, markdownPathToSlugs, source } from '@/lib/source';
import { createFileRoute, notFound } from '@tanstack/react-router';

export const Route = createFileRoute('/docs/{$}.md')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        const slugs = markdownPathToSlugs(
          params._splat?.split('/').filter(Boolean) ?? [],
        );
        const page = source.getPage(slugs, 'en');
        if (!page) throw notFound();

        return new Response(await getLLMText(page), {
          headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
        });
      },
    },
  },
});
