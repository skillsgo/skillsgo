/*
 * [INPUT]: Depends on all compiled English pages and their processed Markdown projections.
 * [OUTPUT]: Provides the backwards-compatible English corpus at /llms-full.txt.
 * [POS]: Serves as the legacy unprefixed bulk export for AI and agent consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { getLLMText, source } from '@/lib/source';
import { createFileRoute } from '@tanstack/react-router';

export const Route = createFileRoute('/llms-full.txt')({
  server: {
    handlers: {
      GET: async () => {
        const pages = await Promise.all(source.getPages('en').map(getLLMText));
        return new Response(pages.join('\n\n'), {
          headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        });
      },
    },
  },
});
