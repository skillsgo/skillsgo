/*
 * [INPUT]: Depends on shared SkillsGo branding, the active locale, and Fumadocs layout contracts.
 * [OUTPUT]: Provides localized navigation and repository-link options for all layouts.
 * [POS]: Serves as the shared visual shell configuration for home, docs, and error pages.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { appName, gitConfig } from '@/lib/shared';
import type { Locale } from '@/lib/i18n';
import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';

export function baseOptions(locale: Locale): BaseLayoutProps {
  const isChinese = locale === 'zh-CN';

  return {
    nav: {
      title: appName,
      url: `/${locale}`,
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
    links: [
      {
        text: isChinese ? '文档' : 'Documentation',
        url: `/${locale}/docs`,
        active: 'nested-url',
      },
    ],
  };
}
