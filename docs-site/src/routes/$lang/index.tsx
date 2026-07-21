/*
 * [INPUT]: Depends on locale validation, TanStack Router links, and the shared SkillsGo repository identity.
 * [OUTPUT]: Provides the bilingual editorial landing page at each supported language prefix.
 * [POS]: Serves as the public product overview before readers enter the localized documentation tree.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { resolveLocale, type Locale } from '@/lib/i18n';
import { createFileRoute, Link } from '@tanstack/react-router';

export const Route = createFileRoute('/$lang/')({
  component: Home,
  head: ({ params }) => {
    const locale = resolveLocale(params.lang);
    const isChinese = locale === 'zh-CN';
    return {
      meta: [
        { title: isChinese ? 'SkillsGo · 发现与管理 Agent Skills' : 'SkillsGo · Discover and manage Agent Skills' },
        {
          name: 'description',
          content: isChinese
            ? '发现、安装和管理 Agent Skills，同时保留本地文件所有权。'
            : 'Discover, install, and manage Agent Skills while keeping ownership of local files.',
        },
      ],
      links: [
        { rel: 'canonical', href: `/${locale}` },
        { rel: 'alternate', hrefLang: 'en', href: '/en' },
        { rel: 'alternate', hrefLang: 'zh-CN', href: '/zh-CN' },
      ],
    };
  },
});

const copy = {
  en: {
    nav: ['Overview', 'System', 'Workflow', 'Questions'],
    docs: 'Documentation',
    locale: '中文',
    title: 'SkillsGo',
    mark: '技',
    intro: 'Discovery, installation, updates, and reproducible Agent Skills in one open ecosystem.',
    primary: 'Get started',
    secondary: 'View on GitHub',
    facts: ['Desktop app', 'Local-first CLI', 'Public Hub', 'Open source'],
    sections: {
      overview: ['00 · See it', 'One home for every Skill', 'Search the public catalog, inspect stable identity and metadata, then choose exactly where a Skill belongs. SkillsGo keeps the path from discovery to local files visible.'],
      system: ['01 · The System', 'Three parts, one clear boundary', 'The desktop App handles the journey. The CLI owns every local change. The Hub publishes identity, search, ranking, and immutable artifacts.'],
      workflow: ['02 · Workflow', 'From discovery to a locked workspace', 'A short path for individuals, with the contracts teams need to reproduce the same setup across machines.'],
      questions: ['03 · Questions', 'Honest answers'],
    },
    preview: {
      label: 'Discover',
      title: 'Skills worth keeping',
      search: 'Search Agent Skills',
      chips: ['Featured', 'Development', 'Design', 'Writing'],
      cards: [
        ['frontend-design', 'Build polished product interfaces', 'Design'],
        ['code-review', 'Review changes against standards and spec', 'Engineering'],
        ['research', 'Investigate with primary sources', 'Knowledge'],
      ],
    },
    nodes: [
      ['Desktop App', 'Explore, compare, and plan installations through a visual desktop workflow.'],
      ['SkillsGo CLI', 'Resolve artifacts, mutate local files, and maintain manifests and locks.'],
      ['Public Hub', 'Publish canonical identity, metadata, search, ranking, and verified downloads.'],
    ],
    steps: [
      ['Discover', 'Search the Hub and inspect the source, version, and public identity.'],
      ['Choose', 'Select user-level or workspace-level targets before anything changes.'],
      ['Install', 'Let the local CLI execute one auditable plan against your filesystem.'],
      ['Reproduce', 'Commit the workspace manifest and lock so teammates stay aligned.'],
    ],
    faqs: [
      ['Does the desktop App call the Hub directly?', 'No. The App invokes the bundled CLI through stable machine contracts; the CLI is its only business-integration boundary.'],
      ['Who owns changes to my local files?', 'The CLI does. It plans and executes installations, maintains the content-addressed store, and projects Skills into supported Agent targets.'],
      ['Can a team reproduce the same setup?', 'Yes. Workspace manifests capture intent and locks pin resolved artifacts so the setup can travel across machines.'],
      ['Is SkillsGo open source?', 'Yes. The App, CLI, Hub, and documentation live together in the public SkillsGo repository.'],
    ],
    closing: ['Skills should travel.', 'Ownership should stay local.', 'Read the docs'],
    footer: ['App', 'CLI', 'Hub', 'Architecture'],
  },
  'zh-CN': {
    nav: ['概览', '系统', '流程', '问题'],
    docs: '文档',
    locale: 'English',
    title: 'SkillsGo',
    mark: '技',
    intro: '在一个开放生态中完成 Agent Skills 的发现、安装、更新与可复现管理。',
    primary: '开始使用',
    secondary: '在 GitHub 查看',
    facts: ['桌面应用', '本地优先 CLI', '公共 Hub', '开源'],
    sections: {
      overview: ['00 · 先睹为快', '每个 Skill，都有一个归处', '搜索公共目录，查看稳定身份与元数据，再精确选择 Skill 应该安装到哪里。SkillsGo 让从发现到本地文件的每一步都清晰可见。'],
      system: ['01 · 系统', '三部分，一条清晰边界', '桌面应用承载用户旅程，CLI 负责所有本地变更，Hub 提供公共身份、搜索、排序与不可变制品。'],
      workflow: ['02 · 流程', '从发现，到锁定整个工作区', '个人使用足够简洁，团队协作又拥有在不同机器上复现同一套配置所需的契约。'],
      questions: ['03 · 常见问题', '坦诚回答'],
    },
    preview: {
      label: '发现',
      title: '值得留下的 Skills',
      search: '搜索 Agent Skills',
      chips: ['精选', '开发', '设计', '写作'],
      cards: [
        ['frontend-design', '构建精致的产品界面', '设计'],
        ['code-review', '依据规范与需求审查变更', '工程'],
        ['research', '基于一手资料开展研究', '知识'],
      ],
    },
    nodes: [
      ['桌面应用', '通过可视化桌面流程探索、比较并规划安装。'],
      ['SkillsGo CLI', '解析制品、变更本地文件，并维护清单与锁文件。'],
      ['公共 Hub', '发布规范身份、元数据、搜索、排序与已验证下载。'],
    ],
    steps: [
      ['发现', '搜索 Hub，查看来源、版本与公共身份。'],
      ['选择', '在任何变更前，选择用户级或工作区级目标。'],
      ['安装', '由本地 CLI 对文件系统执行一份可审计计划。'],
      ['复现', '提交工作区清单与锁文件，让团队保持一致。'],
    ],
    faqs: [
      ['桌面应用会直接调用 Hub 吗？', '不会。应用通过稳定的机器契约调用内置 CLI；CLI 是它唯一的业务集成边界。'],
      ['谁负责修改我的本地文件？', 'CLI。它规划并执行安装，维护内容寻址存储，并将 Skills 投射到受支持的 Agent 目标。'],
      ['团队能复现同一套配置吗？', '可以。工作区清单记录意图，锁文件固定解析后的制品，让配置可以跨机器复现。'],
      ['SkillsGo 是开源的吗？', '是。App、CLI、Hub 与文档共同维护在公开的 SkillsGo 仓库中。'],
    ],
    closing: ['让 Skill 自由流动。', '让所有权留在本地。', '阅读文档'],
    footer: ['桌面应用', 'CLI', 'Hub', '架构'],
  },
} as const satisfies Record<Locale, unknown>;

function Home() {
  const { lang } = Route.useParams();
  const locale = resolveLocale(lang);
  const text = copy[locale];
  const otherLocale = locale === 'en' ? 'zh-CN' : 'en';

  return (
    <div className="sg-home">
      <a className="sg-skip" href="#main">Skip to main content</a>
      <nav className="sg-nav" aria-label="Primary navigation">
        <Link to="/$lang/" params={{ lang: locale }} className="sg-brand"><span aria-hidden="true">◆</span> SkillsGo</Link>
        <div className="sg-nav-links">
          {text.nav.map((item, index) => <a key={item} href={['#overview', '#system', '#workflow', '#questions'][index]}>{item}</a>)}
          <Link to="/$lang/docs/$" params={{ lang: locale, _splat: '' }}>{text.docs}</Link>
        </div>
        <Link to="/$lang/" params={{ lang: otherLocale }} className="sg-locale">{text.locale} <span>→</span></Link>
      </nav>

      <main id="main" className="sg-main">
        <header className="sg-hero">
          <h1>{text.title}<span>{text.mark}</span></h1>
          <p>{text.intro}</p>
          <div className="sg-facts">{text.facts.map((fact) => <span key={fact}>{fact}</span>)}</div>
          <div className="sg-actions">
            <Link to="/$lang/docs/$" params={{ lang: locale, _splat: 'getting-started' }} className="sg-button sg-button-primary">{text.primary}</Link>
            <a href="https://github.com/skillsgo/skillsgo" className="sg-button">{text.secondary}</a>
          </div>
        </header>

        <section id="overview" className="sg-section">
          <SectionHead values={text.sections.overview} />
          <ProductPreview preview={text.preview} />
        </section>

        <section id="system" className="sg-section">
          <SectionHead values={text.sections.system} />
          <div className="sg-orbit" aria-hidden="true"><i /><i /><i /><b>SG</b></div>
          <div className="sg-system-list">
            {text.nodes.map((node, index) => (
              <article key={node[0]}><span>0{index + 1}</span><h3>{node[0]}</h3><p>{node[1]}</p></article>
            ))}
          </div>
        </section>

        <section id="workflow" className="sg-section">
          <SectionHead values={text.sections.workflow} />
          <div className="sg-steps">
            {text.steps.map((step, index) => (
              <article key={step[0]}><span>{String(index + 1).padStart(2, '0')}</span><h3>{step[0]}</h3><p>{step[1]}</p></article>
            ))}
          </div>
        </section>

        <section id="questions" className="sg-section sg-questions">
          <SectionHead values={text.sections.questions} compact />
          <div className="sg-faqs">
            {text.faqs.map((faq) => <details key={faq[0]}><summary>{faq[0]}<span>+</span></summary><p>{faq[1]}</p></details>)}
          </div>
        </section>

        <section className="sg-closing">
          <p>{text.closing[0]}</p><h2>{text.closing[1]}</h2>
          <Link to="/$lang/docs/$" params={{ lang: locale, _splat: '' }} className="sg-button sg-button-primary">{text.closing[2]}</Link>
        </section>
      </main>

      <footer className="sg-footer">
        <div><strong>SkillsGo · 技</strong><p>{text.intro}</p></div>
        <div>{text.footer.map((item, index) => <Link key={item} to="/$lang/docs/$" params={{ lang: locale, _splat: ['', 'cli', 'hub', 'architecture'][index] }}>{item}</Link>)}</div>
        <p>Open source · Local ownership · Built for Agent Skills</p>
      </footer>
    </div>
  );
}

function SectionHead({ values, compact = false }: { values: readonly string[]; compact?: boolean }) {
  return <header className={compact ? 'sg-section-head sg-section-head-compact' : 'sg-section-head'}><p>{values[0]}</p><h2>{values[1]}</h2>{values[2] && <div>{values[2]}</div>}</header>;
}

function ProductPreview({ preview }: { preview: (typeof copy.en)['preview'] | (typeof copy)['zh-CN']['preview'] }) {
  return (
    <div className="sg-product-frame">
      <div className="sg-window">
        <div className="sg-window-bar"><span /><span /><span /><b>SkillsGo</b></div>
        <div className="sg-product-body">
          <aside><strong>SG</strong><i /><i /><i /><i /></aside>
          <div className="sg-product-content">
            <span className="sg-kicker">{preview.label}</span><h3>{preview.title}</h3>
            <div className="sg-search">⌕ <span>{preview.search}</span><kbd>⌘ K</kbd></div>
            <div className="sg-chips">{preview.chips.map((chip) => <span key={chip}>{chip}</span>)}</div>
            <div className="sg-skill-cards">{preview.cards.map((card) => <article key={card[0]}><i>{card[0].slice(0, 1).toUpperCase()}</i><div><h4>{card[0]}</h4><p>{card[1]}</p><span>{card[2]}</span></div></article>)}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
