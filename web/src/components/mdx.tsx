/*
 * [INPUT]: Depends on Fumadocs UI's default MDX component map.
 * [OUTPUT]: Provides the MDX component resolver used by generated documentation modules.
 * [POS]: Serves as the rendering adapter between authored MDX and the Fumadocs design system.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import defaultMdxComponents from 'fumadocs-ui/mdx';
import type { MDXComponents } from 'mdx/types';

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    ...components,
  } satisfies MDXComponents;
}

export const useMDXComponents = getMDXComponents;

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>;
}
