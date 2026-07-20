/*
 * [INPUT]: Depends on the generated Fumadocs server collection, locale configuration, and shared routes.
 * [OUTPUT]: Provides the localized documentation source, Markdown route mapping, and LLM text projection.
 * [POS]: Serves as the single content-query boundary for docs-site routes and search.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { i18n, type Locale } from '@/lib/i18n';
import { docsRoute } from '@/lib/shared';
import { loader } from 'fumadocs-core/source';
import { docs } from 'collections/server';

export const source = loader({
  source: docs.toFumadocsSource(),
  baseUrl: docsRoute,
  i18n,
});

export function markdownPathToSlugs(segments: string[]) {
  if (segments.length === 0) return [];

  const slugs = [...segments];
  slugs[slugs.length - 1] = slugs[slugs.length - 1].replace(/\.md$/, '');
  if (slugs.length === 1 && slugs[0] === 'index') slugs.pop();
  return slugs;
}

export function slugsToMarkdownPath(slugs: string[], locale: Locale) {
  const segments = [...slugs];
  if (segments.length === 0) {
    segments.push('index.md');
  } else {
    segments[segments.length - 1] += '.md';
  }

  return {
    segments,
    url: `/${locale}${docsRoute}/${segments.join('/')}`,
  };
}

export async function getLLMText(page: (typeof source)['$inferPage']) {
  const processed = await page.data.getText('processed');
  return `# ${page.data.title} (${page.url})\n\n${processed}`;
}
