/*
 * [INPUT]: Depends on the English Fumadocs source and its LLM index generator.
 * [OUTPUT]: Provides the backwards-compatible English documentation index at /llms.txt.
 * [POS]: Serves as the legacy unprefixed discovery entry for AI and agent consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { source } from '@/lib/source';
import { createFileRoute } from '@tanstack/react-router';
import { llms } from 'fumadocs-core/source';

export const Route = createFileRoute('/llms.txt')({
  server: {
    handlers: {
      GET: () =>
        new Response(llms(source).index('en'), {
          headers: { 'Content-Type': 'text/plain; charset=utf-8' },
        }),
    },
  },
});
