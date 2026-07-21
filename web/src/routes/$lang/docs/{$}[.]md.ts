/*
 * [INPUT]: Depends on locale validation, route slug conversion, and processed Markdown from the Fumadocs source.
 * [OUTPUT]: Provides a localized plain Markdown representation of each documentation page.
 * [POS]: Serves as the machine-readable per-page companion to each localized docs route.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { isLocale } from '@/lib/i18n';
import { getLLMText, markdownPathToSlugs, source } from '@/lib/source';
import { createFileRoute, notFound } from '@tanstack/react-router';

export const Route = createFileRoute('/$lang/docs/{$}.md')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        if (!isLocale(params.lang)) throw notFound();
        const slugs = markdownPathToSlugs(
          params._splat?.split('/').filter(Boolean) ?? [],
        );
        const page = source.getPage(slugs, params.lang);
        if (!page) throw notFound();

        return new Response(await getLLMText(page), {
          headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
        });
      },
    },
  },
});
