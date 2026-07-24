/*
 * [INPUT]: Depends on shared SkillsGo branding, the active locale, the public brand asset, and Fumadocs layout contracts.
 * [OUTPUT]: Provides localized editorial navigation, light-only theme controls, and repository-link options for all layouts.
 * [POS]: Serves as the shared visual shell configuration for home, docs, and error pages.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { appName, gitConfig } from '@/lib/shared';
import type { Locale } from '@/lib/i18n';
import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';

export function baseOptions(locale: Locale): BaseLayoutProps {
  const isChinese = locale === 'zh-CN';

  return {
    themeSwitch: {
      enabled: false,
    },
    nav: {
      title: (
        <span className="sg-docs-brand">
          <img src="/branding/skillsgo-logo.png" width="28" height="28" alt="" decoding="async" />
          <span>{appName} {isChinese ? '文档' : 'Docs'}</span>
        </span>
      ),
      url: `/${locale}`,
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
