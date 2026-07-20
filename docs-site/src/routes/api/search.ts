/*
 * [INPUT]: Depends on both locale collections, Fumadocs' Orama search server, and Mandarin tokenization.
 * [OUTPUT]: Provides statically prerendered English and Simplified Chinese search indexes at /api/search.
 * [POS]: Serves as the build-time search export consumed by the browser search dialog.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { source } from '@/lib/source';
import { createTokenizer } from '@orama/tokenizers/mandarin';
import { createFileRoute } from '@tanstack/react-router';
import { createFromSource } from 'fumadocs-core/search/server';

const searchServer = createFromSource(source, {
  localeMap: {
    en: 'english',
    'zh-CN': {
      components: { tokenizer: createTokenizer() },
    },
  },
});

export const Route = createFileRoute('/api/search')({
  server: {
    handlers: {
      GET: () => searchServer.staticGET(),
    },
  },
});
