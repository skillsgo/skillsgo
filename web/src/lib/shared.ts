/*
 * [INPUT]: Depends only on stable SkillsGo public naming and repository coordinates.
 * [OUTPUT]: Provides shared Web branding, route, and source-link constants.
 * [POS]: Serves as the leaf configuration module for routes and layouts.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
export const appName = 'SkillsGo';
export const docsRoute = '/docs';

export const gitConfig = {
  user: 'skillsgo',
  repo: 'skillsgo',
  branch: 'main',
} as const;
