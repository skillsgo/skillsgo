/*
 * [INPUT]: Depends on the shared SiteHeader, locale contracts, React content, and TanStack Router links.
 * [OUTPUT]: Provides stable product, documentation-theme, and footer shells for all SkillsGo Web surfaces.
 * [POS]: Serves as the page-composition seam between route adapters and the shared design system.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { SiteHeader } from '@/components/site-header';
import type { Locale } from '@/lib/i18n';
import { Link } from '@tanstack/react-router';
import type { ReactNode } from 'react';

export function SiteShell({ locale, children, mainClassName }: { locale: Locale; children: ReactNode; mainClassName?: string }) {
  return (
    <div className="sg-home">
      <a className="sg-skip" href="#main">Skip to main content</a>
      <SiteHeader locale={locale} />
      <main id="main" className={mainClassName}>{children}</main>
      <SiteFooter locale={locale} />
    </div>
  );
}

export function DocsShell({ children }: { children: ReactNode }) {
  return <div className="sg-docs-theme">{children}</div>;
}

export function SiteFooter({ locale }: { locale: Locale }) {
  const intro = locale === 'zh-CN' ? '在一个开放生态中完成 Agent Skills 的发现、安装、更新与可复现管理。' : 'Discovery, installation, updates, and reproducible Agent Skills in one open ecosystem.';
  const labels = locale === 'zh-CN' ? ['桌面应用', 'CLI', 'Hub', '架构'] : ['App', 'CLI', 'Hub', 'Architecture'];
  return (
    <footer className="sg-footer">
      <div><strong>SkillsGo</strong><p>{intro}</p></div>
      <div>{labels.map((label, index) => <Link key={label} to="/$lang/docs/$" params={{ lang: locale, _splat: ['', 'cli', 'hub', 'architecture'][index] }}>{label}</Link>)}</div>
      <p>Open source · Local ownership · Built for Agent Skills</p>
    </footer>
  );
}
