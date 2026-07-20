/*
 * [INPUT]: Depends on fumadocs-mdx configuration helpers and MDX files under content/docs.
 * [OUTPUT]: Provides the generated, type-safe SkillsGo documentation collection.
 * [POS]: Serves as the content compilation contract for the docs-site workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { defineConfig, defineDocs } from 'fumadocs-mdx/config';

export const docs = defineDocs({
  dir: 'content/docs',
  docs: {
    postprocess: {
      includeProcessedMarkdown: true,
    },
  },
});

export default defineConfig();
