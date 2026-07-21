/*
 * [INPUT]: Depends on locale validation, localized compiled pages, and processed Markdown projections.
 * [OUTPUT]: Provides a complete localized documentation corpus under each language prefix.
 * [POS]: Serves as the locale-specific bulk export for AI and agent consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { isLocale } from '@/lib/i18n';
import { getLLMText, source } from '@/lib/source';
import { createFileRoute, notFound } from '@tanstack/react-router';

export const Route = createFileRoute('/$lang/llms-full.txt')({
  server: {
    handlers: {
      GET: async ({ params }) => {
        if (!isLocale(params.lang)) throw notFound();
        const pages = await Promise.all(
          source.getPages(params.lang).map(getLLMText),
        );
        return new Response(pages.join('\n\n'), {
          headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        });
      },
    },
  },
});
