/*
 * [INPUT]: Depends on locale validation, the compiled Fumadocs source, and its LLM index generator.
 * [OUTPUT]: Provides a localized compact documentation index under each language prefix.
 * [POS]: Serves as the locale-specific discovery entry for AI and agent documentation consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { isLocale } from '@/lib/i18n';
import { source } from '@/lib/source';
import { createFileRoute, notFound } from '@tanstack/react-router';
import { llms } from 'fumadocs-core/source';

export const Route = createFileRoute('/$lang/llms.txt')({
  server: {
    handlers: {
      GET: ({ params }) => {
        if (!isLocale(params.lang)) throw notFound();
        return new Response(llms(source).index(params.lang), {
          headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        });
      },
    },
  },
});
