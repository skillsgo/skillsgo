/*
 * [INPUT]: Depends on the active locale, display mode, the optimized public brand asset, React state, and TanStack Router links.
 * [OUTPUT]: Provides site and documentation variants of the shared SkillsGo header.
 * [POS]: Serves as the single header implementation whose mode adapts navigation to the current user task.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import type { Locale } from '@/lib/i18n';
import { Link } from '@tanstack/react-router';
import { useEffect, useRef, useState } from 'react';

const labels = {
  en: {
    overview: 'Problems',
    system: 'Change',
    workflow: 'Workflow',
    questions: 'Questions',
    hub: 'Hub',
    docs: 'Docs',
    languageLabel: 'Choose a language',
  },
  'zh-CN': {
    overview: '痛点',
    system: '改变',
    workflow: '流程',
    questions: '问题',
    hub: 'Hub',
    docs: '文档',
    languageLabel: '选择语言',
  },
} as const;

export function SiteHeader({ locale, mode = 'site' }: { locale: Locale; mode?: 'site' | 'docs' }) {
  const text = labels[locale];
  const [languageOpen, setLanguageOpen] = useState(false);
  const languageSwitch = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function closeLanguageMenu(event: PointerEvent) {
      if (!languageSwitch.current?.contains(event.target as Node)) setLanguageOpen(false);
    }
    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === 'Escape') setLanguageOpen(false);
    }
    document.addEventListener('pointerdown', closeLanguageMenu);
    document.addEventListener('keydown', closeOnEscape);
    return () => {
      document.removeEventListener('pointerdown', closeLanguageMenu);
      document.removeEventListener('keydown', closeOnEscape);
    };
  }, []);

  return (
    <header className="sg-site-header" data-mode={mode}>
      <nav className="sg-nav" aria-label="Primary navigation">
        <Link to="/$lang" params={{ lang: locale }} className="sg-brand">
          <img src="/branding/skillsgo-logo.png" width="26" height="26" alt="" decoding="async" />
          <span>SkillsGo</span>
          {mode === 'docs' ? <span className="sg-brand-context">/ {text.docs}</span> : null}
        </Link>
        <div className="sg-nav-links">
          {mode === 'site' ? <>
            <Link to="/$lang" params={{ lang: locale }} hash="problems">{text.overview}</Link>
            <Link to="/$lang" params={{ lang: locale }} hash="overview">{text.system}</Link>
            <Link to="/$lang" params={{ lang: locale }} hash="workflow">{text.workflow}</Link>
            <Link to="/$lang" params={{ lang: locale }} hash="questions">{text.questions}</Link>
          </> : null}
          <Link to="/$lang/hub" params={{ lang: locale }}>{text.hub}</Link>
          {mode === 'site' ? <Link to="/$lang/docs/$" params={{ lang: locale, _splat: '' }}>{text.docs}</Link> : <a href="https://github.com/skillsgo/skillsgo" target="_blank" rel="noreferrer">GitHub</a>}
        </div>
        <div className="sg-language-switch" ref={languageSwitch}>
          <button className="sg-language-trigger" type="button" aria-expanded={languageOpen} aria-haspopup="true" aria-controls="sg-language-menu" aria-label={text.languageLabel} onClick={() => setLanguageOpen((open) => !open)}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true"><circle cx="12" cy="12" r="9" /><path d="M3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9c-2.5-2.6-3.8-5.6-3.8-9S9.5 5.6 12 3z" /></svg>
            <span className="sg-language-code">{locale === 'en' ? 'EN' : '中'}</span>
            <span className="sg-language-name">{locale === 'en' ? 'English' : '简体中文'}</span>
          </button>
          <div id="sg-language-menu" className="sg-language-menu" aria-hidden={!languageOpen}>
            <Link to={mode === 'docs' ? '/$lang/docs/$' : '/$lang'} params={mode === 'docs' ? { lang: 'en', _splat: '' } : { lang: 'en' }} className={locale === 'en' ? 'active' : undefined} aria-current={locale === 'en' ? 'page' : undefined} onClick={() => setLanguageOpen(false)}><span>English</span><span>EN</span></Link>
            <Link to={mode === 'docs' ? '/$lang/docs/$' : '/$lang'} params={mode === 'docs' ? { lang: 'zh-CN', _splat: '' } : { lang: 'zh-CN' }} className={locale === 'zh-CN' ? 'active' : undefined} aria-current={locale === 'zh-CN' ? 'page' : undefined} onClick={() => setLanguageOpen(false)}><span>简体中文</span><span>中</span></Link>
          </div>
        </div>
      </nav>
    </header>
  );
}
