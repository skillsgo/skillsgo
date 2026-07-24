/*
 * [INPUT]: Depends on the public design-system modules in this directory.
 * [OUTPUT]: Provides the intentionally small React interface consumed by Web route adapters.
 * [POS]: Serves as the external seam of the repository-local SkillsGo design system.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
export { ArticleList, EditorialSectionHeader } from './content';
export type { ArticleListItem, EditorialSectionHeaderProps } from './content';
export { DocsShell, SiteFooter, SiteShell } from './shells';
