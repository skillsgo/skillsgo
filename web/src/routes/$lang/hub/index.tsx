/*
 * [INPUT]: Depends on locale resolution, the shared site header, and TanStack Router links.
 * [OUTPUT]: Provides the bilingual, prerenderable public Hub landing page under each locale.
 * [POS]: Serves as Web's discovery handoff into Hub search, rankings, and future Skill detail routes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { SiteHeader } from '@/components/site-header';
import { resolveLocale, type Locale } from '@/lib/i18n';
import { createFileRoute, Link } from '@tanstack/react-router';

export const Route = createFileRoute('/$lang/hub/')({
  component: HubHome,
  head: ({ params }) => {
    const locale = resolveLocale(params.lang);
    const isChinese = locale === 'zh-CN';
    return {
      meta: [
        { title: isChinese ? 'SkillsGo Hub · 发现可信的 Agent Skills' : 'SkillsGo Hub · Discover trusted Agent Skills' },
        {
          name: 'description',
          content: isChinese
            ? '发现来源明确、版本可追溯、制品可验证的 Agent Skills。'
            : 'Discover Agent Skills with clear provenance, traceable versions, and verifiable artifacts.',
        },
      ],
      links: [
        { rel: 'canonical', href: `/${locale}/hub` },
        { rel: 'alternate', hrefLang: 'en', href: '/en/hub' },
        { rel: 'alternate', hrefLang: 'zh-CN', href: '/zh-CN/hub' },
      ],
    };
  },
});

const copy = {
  en: {
    eyebrow: 'The public directory for Agent Skills',
    title: ['Discover Skills', 'you can trust.'],
    body: 'Explore public Skills with canonical identity, traceable versions, source context, and immutable artifacts. Keep discovery public and management local.',
    search: 'Search Agent Skills',
    searchHint: 'Search will connect to the Hub catalog API.',
    sections: [
      ['Trending', 'See what the community is installing now.'],
      ['Verified sources', 'Evaluate provenance, trust, and immutable version details.'],
      ['Open locally', 'Hand an installation decision to SkillsGo App and its bundled CLI.'],
    ],
    docs: 'Understand the Hub',
  },
  'zh-CN': {
    eyebrow: 'Agent Skills 公共目录',
    title: ['发现值得信任的', 'Agent Skills。'],
    body: '通过规范身份、可追溯版本、来源上下文和不可变制品发现公共 Skills。公开发现，本地管理。',
    search: '搜索 Agent Skills',
    searchHint: '搜索将接入 Hub 目录 API。',
    sections: [
      ['趋势榜单', '了解社区正在安装哪些 Skills。'],
      ['可验证来源', '判断来源、信任等级与不可变版本信息。'],
      ['在本地打开', '将安装决定交给 SkillsGo App 及其内置 CLI。'],
    ],
    docs: '了解 Hub 的工作方式',
  },
} as const satisfies Record<Locale, unknown>;

function HubHome() {
  const { lang } = Route.useParams();
  const locale = resolveLocale(lang);
  const text = copy[locale];

  return (
    <div className="sg-home sg-hub-home">
      <a className="sg-skip" href="#main">Skip to main content</a>
      <SiteHeader locale={locale} />
      <main id="main" className="sg-main sg-hub-main">
        <header className="sg-hub-hero">
          <p>{text.eyebrow}</p>
          <h1><span>{text.title[0]}</span><span>{text.title[1]}</span></h1>
          <div>{text.body}</div>
          <form className="sg-hub-search" role="search" onSubmit={(event) => event.preventDefault()}>
            <label htmlFor="hub-search">{text.search}</label>
            <div><input id="hub-search" name="q" type="search" placeholder={text.search} disabled /><button type="submit" disabled aria-disabled="true">→</button></div>
            <small>{text.searchHint}</small>
          </form>
        </header>
        <section className="sg-hub-pillars" aria-label="Hub capabilities">
          {text.sections.map((section, index) => <article key={section[0]}><span>0{index + 1}</span><h2>{section[0]}</h2><p>{section[1]}</p></article>)}
        </section>
        <div className="sg-hub-doc-link"><Link to="/$lang/docs/$" params={{ lang: locale, _splat: 'hub' }}>{text.docs} →</Link></div>
      </main>
    </div>
  );
}
