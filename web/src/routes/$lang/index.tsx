/*
 * [INPUT]: Depends on locale validation, TanStack Router links, and the shared site header.
 * [OUTPUT]: Provides the bilingual editorial landing page at each supported language prefix.
 * [POS]: Serves as the public product overview before readers enter the localized documentation tree.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { resolveLocale, type Locale } from '@/lib/i18n';
import { SiteHeader } from '@/components/site-header';
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
    docs: 'Documentation',
    title: 'SkillsGo',
    intro: 'Discovery, installation, updates, and reproducible Agent Skills in one open ecosystem.',
    primary: 'Get started',
    secondary: 'View on GitHub',
    facts: ['Desktop app', 'Local-first CLI', 'Public Hub', 'Open source'],
    eyebrow: 'Your Skills already work. They should not become harder to manage.',
    heroTitle: ['Skills are spreading.', 'Bring them back under control.'],
    heroBody: 'SkillsGo finds the Skills already living across your agents, projects, and machines—then makes their location, version, updates, and recovery visible without taking ownership of your files.',
    painTitle: 'Does your Skill setup look like this?',
    pains: [
      ['Skills are hard to find', 'Folders · Projects · Agents', 'The same Skill may live globally, inside one project, or under a different Agent directory. Over time, no one knows how many copies remain.'],
      ['Agents cannot see them', 'Install · Load · Invoke', 'A file exists on disk, but it is unclear whether Claude, Codex, or Cursor actually discovers and can invoke it.'],
      ['Project copies drift', 'Projects · Machines · Versions', 'After copying a Skill across projects and computers, each copy quietly changes and stops matching the others.'],
      ['Upstream updates disappear', 'Source · Version · Changes', 'The author ships a fix, but local installations give no reliable signal about which copies are now behind.'],
      ['Local edits block updates', 'Edits · Overwrites · Conflicts', 'A customized Skill becomes difficult to update because reinstalling may overwrite work or conflict with upstream changes.'],
      ['Failures are hard to recover', 'Interruptions · Rollback · Data', 'If installation or update stops halfway through, it is difficult to prove the files are complete or return to the last working state.'],
      ['Every environment starts over', 'Projects · Devices · Teams', 'A new project, computer, or teammate still means copying everything again—and each setup ends up slightly different.'],
      ['Provenance and risk are unclear', 'Authors · Scripts · Permissions', 'It is hard to confirm where a Skill came from, what it can execute, and whether local content still matches its source.'],
    ],
    transformation: {
      label: 'One safe handoff',
      title: 'Keep the files. Add the missing certainty.',
      body: 'SkillsGo scans first and writes only after you confirm. Existing files stay in place while management metadata is completed around them.',
      before: 'Before',
      after: 'Managed with SkillsGo',
      scattered: ['Claude · user', 'Codex · project A', 'Cursor · project B', 'Laptop copy'],
      outcomes: ['Location clear', 'Updates visible', 'Recoverable', 'Version clear'],
      action: 'Bring under management',
    },
    simpleSteps: [
      ['01', 'Find what is already there', 'Scan personal and authorized project locations across supported Agents.'],
      ['02', 'Review one clear plan', 'See exactly which Skills can be managed before SkillsGo writes anything.'],
      ['03', 'Manage without losing work', 'Complete provenance, version, lock, and Store metadata while preserving local content.'],
    ],
    trustTitle: 'Local files remain the source of truth.',
    trustBody: 'The App never mutates your filesystem directly. The bundled CLI applies explicit, transactional plans; the Hub never sees or controls your private local files.',
    sections: {
      overview: ['00 · See it', 'One home for every Skill', 'Search the public catalog, inspect stable identity and metadata, then choose exactly where a Skill belongs. SkillsGo keeps the path from discovery to local files visible.'],
      system: ['01 · The System', 'Three parts, one clear boundary', 'The desktop App handles the journey. The CLI owns every local change. The Hub publishes identity, search, ranking, and immutable artifacts.'],
      workflow: ['02 · Workflow', 'From discovery to a locked workspace', 'A short path for individuals, with the contracts teams need to reproduce the same setup across machines.'],
      ownership: ['03 · Ownership', 'Open source, local by design', 'The public catalog can travel everywhere. Installation authority and local files remain on your machine.'],
      questions: ['04 · Questions', 'Honest answers'],
      reading: ['05 · Documentation', 'From the docs', 'Continue with the product and architecture guides.'],
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
      ['Content Store', 'Keep downloaded artifacts in a local content-addressed store with stable identity.'],
      ['Agent Targets', 'Project each Skill into explicit user-level or workspace-level destinations.'],
      ['Public Hub', 'Publish canonical identity, metadata, search, ranking, and verified downloads.'],
    ],
    steps: [
      ['Discover', 'Search the Hub and inspect the source, version, and public identity.'],
      ['Choose', 'Select user-level or workspace-level targets before anything changes.'],
      ['Install', 'Let the local CLI execute one auditable plan against your filesystem.'],
      ['Reproduce', 'Commit the workspace manifest and lock so teammates stay aligned.'],
      ['Inspect', 'Review source metadata, version identity, and the resolved artifact before installation.'],
      ['Verify', 'Use verified immutable artifacts rather than mutable copies with unclear provenance.'],
      ['Store', 'Keep resolved content in the local content-addressed Store.'],
      ['Project', 'Project one stored Skill into each explicitly selected Agent target.'],
      ['Manifest', 'Record workspace intent in a manifest that belongs with the project.'],
      ['Lock', 'Pin the exact resolved artifacts needed to reproduce the workspace.'],
      ['Update', 'Plan and apply managed updates through the same local engine.'],
      ['Remove', 'Remove managed projections without hiding which local paths will change.'],
    ],
    faqs: [
      ['Does the desktop App call the Hub directly?', 'No. The App invokes the bundled CLI through stable machine contracts; the CLI is its only business-integration boundary.'],
      ['Who owns changes to my local files?', 'The CLI does. It plans and executes installations, maintains the content-addressed store, and projects Skills into supported Agent targets.'],
      ['Can a team reproduce the same setup?', 'Yes. Workspace manifests capture intent and locks pin resolved artifacts so the setup can travel across machines.'],
      ['Is SkillsGo open source?', 'Yes. The App, CLI, Hub, and documentation live together in the public SkillsGo repository.'],
      ['Does the Hub modify my filesystem?', 'No. The Hub owns public identity, metadata, search, ranking, and artifacts; local mutation belongs exclusively to the CLI.'],
      ['Can I choose installation scope?', 'Yes. SkillsGo distinguishes user-level and workspace-level Agent targets before executing a plan.'],
      ['Does the App parse terminal output?', 'No. The App consumes stable machine contracts from the bundled CLI rather than parsing human-oriented output.'],
      ['Can I update or remove an installation?', 'Yes. Managed installations can be updated or removed through SkillsGo using the same explicit local planning boundary.'],
    ],
    ownership: ['Your files stay yours.', 'Explore the public repository', 'No hidden filesystem changes · Stable machine contracts · Reproducible workspaces'],
    reading: [
      ['Getting started', 'The shortest path from discovery to an installed Agent Skill.', 'getting-started'],
      ['CLI', 'The local execution engine and terminal interface.', 'cli'],
      ['Architecture', 'How the App, CLI, Hub, Store, and Agent targets fit together.', 'architecture'],
    ],
    closing: ['Skills should travel.', 'Ownership should stay local.', 'Read the docs'],
    footer: ['App', 'CLI', 'Hub', 'Architecture'],
  },
  'zh-CN': {
    docs: '文档',
    title: 'SkillsGo',
    intro: '在一个开放生态中完成 Agent Skills 的发现、安装、更新与可复现管理。',
    primary: '开始使用',
    secondary: '在 GitHub 查看',
    facts: ['桌面应用', '本地优先 CLI', '公共 Hub', '开源'],
    eyebrow: '你的 Skills 已经能用，不该因此越来越难管理。',
    heroTitle: ['Skills 正在散落。', '把它们重新纳入秩序。'],
    heroBody: 'SkillsGo 找到散落在不同 Agent、项目与电脑中的现有 Skills，在不夺走本地文件所有权的前提下，让位置、版本、更新与恢复都清晰可见。',
    painTitle: '你的 Skills，也开始出现这些问题了吗？',
    pains: [
      ['Skills 散落难找', '目录 · 项目 · Agent', '同一个 Skill 可能出现在用户目录、某个项目或不同 Agent 的专属目录里，时间久了已经不知道还留下多少副本。'],
      ['Agent 发现不了', '安装 · 加载 · 调用', '文件明明存在，却不知道 Claude、Codex 或 Cursor 是否真的发现并能够调用它。'],
      ['不同项目版本分叉', '项目 · 电脑 · 版本', '复制到不同项目和电脑后，各份内容悄悄发生变化，已经无法确认它们是不是同一版。'],
      ['上游更新不可见', '来源 · 版本 · 变更', '作者已经修复问题，但本地没有提示，也不知道哪些安装仍然停留在旧版本。'],
      ['本地修改不敢更新', '修改 · 覆盖 · 冲突', '自己调整过的 Skill 无法直接更新，担心重新安装覆盖修改，或与上游版本发生冲突。'],
      ['出问题难以恢复', '中断 · 回滚 · 数据', '安装或更新过程中意外退出，无法确认文件是否完整，也不知道怎样回到之前可用的状态。'],
      ['换环境还要重来', '项目 · 设备 · 团队', '新项目、新电脑或新成员加入时，仍然需要重新复制，最终每个人使用的配置都不一样。'],
      ['来源和风险不清', '作者 · 脚本 · 权限', '不确定 Skill 来自哪里、包含哪些脚本、会执行什么操作，也无法判断当前内容是否仍与原始来源一致。'],
    ],
    transformation: {
      label: '一次安全的纳入',
      title: '文件不用搬，缺失的确定性补回来。',
      body: 'SkillsGo 先扫描、后确认，只有你同意之后才写入。现有文件保留在原位，管理所需的完整元数据围绕它们建立。',
      before: '纳入前',
      after: 'SkillsGo 管理中',
      scattered: ['Claude · 全局', 'Codex · 项目 A', 'Cursor · 项目 B', '笔记本副本'],
      outcomes: ['位置清晰', '更新可见', '可以恢复', '版本清晰'],
      action: '纳入管理',
    },
    simpleSteps: [
      ['01', '找到已经存在的 Skills', '扫描用户目录和已授权项目中受支持 Agent 的真实安装位置。'],
      ['02', '确认一份清晰的计划', '写入之前，准确看到哪些 Skills 可以纳入、哪些会被跳过。'],
      ['03', '保留数据，补齐管理信息', '在不覆盖本地内容的前提下，补齐来源、版本、锁文件与 Store 元数据。'],
    ],
    trustTitle: '本地文件，始终是你的。',
    trustBody: 'App 不直接修改文件系统；内置 CLI 通过明确、事务性的计划执行变更；Hub 不读取也不控制你的私有本地文件。',
    sections: {
      overview: ['00 · 先睹为快', '每个 Skill，都有一个归处', '搜索公共目录，查看稳定身份与元数据，再精确选择 Skill 应该安装到哪里。SkillsGo 让从发现到本地文件的每一步都清晰可见。'],
      system: ['01 · 系统', '三部分，一条清晰边界', '桌面应用承载用户旅程，CLI 负责所有本地变更，Hub 提供公共身份、搜索、排序与不可变制品。'],
      workflow: ['02 · 流程', '从发现，到锁定整个工作区', '个人使用足够简洁，团队协作又拥有在不同机器上复现同一套配置所需的契约。'],
      ownership: ['03 · 所有权', '开源，也坚持本地优先', '公共目录可以自由流动，安装权限与本地文件始终留在你的机器上。'],
      questions: ['04 · 常见问题', '坦诚回答'],
      reading: ['05 · 文档', '继续阅读', '从产品与架构指南继续了解 SkillsGo。'],
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
      ['内容存储', '以稳定身份将下载制品保存在本地内容寻址存储中。'],
      ['Agent 目标', '将每个 Skill 投射到明确的用户级或工作区级目标。'],
      ['公共 Hub', '发布规范身份、元数据、搜索、排序与已验证下载。'],
    ],
    steps: [
      ['发现', '搜索 Hub，查看来源、版本与公共身份。'],
      ['选择', '在任何变更前，选择用户级或工作区级目标。'],
      ['安装', '由本地 CLI 对文件系统执行一份可审计计划。'],
      ['复现', '提交工作区清单与锁文件，让团队保持一致。'],
      ['检查', '安装前查看来源元数据、版本身份与解析后的制品。'],
      ['验证', '使用经过验证的不可变制品，避免来源不明的可变副本。'],
      ['存储', '将解析后的内容保存在本地内容寻址 Store 中。'],
      ['投射', '把同一份 Skill 投射到每个明确选择的 Agent 目标。'],
      ['清单', '在随项目维护的清单中记录工作区意图。'],
      ['锁定', '固定复现工作区所需的精确制品。'],
      ['更新', '通过同一个本地引擎规划并应用托管更新。'],
      ['移除', '移除托管投射，同时清晰展示将发生变化的本地路径。'],
    ],
    faqs: [
      ['桌面应用会直接调用 Hub 吗？', '不会。应用通过稳定的机器契约调用内置 CLI；CLI 是它唯一的业务集成边界。'],
      ['谁负责修改我的本地文件？', 'CLI。它规划并执行安装，维护内容寻址存储，并将 Skills 投射到受支持的 Agent 目标。'],
      ['团队能复现同一套配置吗？', '可以。工作区清单记录意图，锁文件固定解析后的制品，让配置可以跨机器复现。'],
      ['SkillsGo 是开源的吗？', '是。App、CLI、Hub 与文档共同维护在公开的 SkillsGo 仓库中。'],
      ['Hub 会修改我的文件系统吗？', '不会。Hub 负责公共身份、元数据、搜索、排序与制品；本地变更只属于 CLI。'],
      ['可以选择安装范围吗？', '可以。执行计划前，SkillsGo 会明确区分用户级和工作区级 Agent 目标。'],
      ['桌面应用会解析终端文本吗？', '不会。应用消费内置 CLI 的稳定机器契约，而不是解析面向人的终端输出。'],
      ['可以更新或移除安装吗？', '可以。托管安装可以通过同一个明确的本地规划边界完成更新或移除。'],
    ],
    ownership: ['你的文件，始终属于你。', '查看公开仓库', '无隐藏文件变更 · 稳定机器契约 · 可复现工作区'],
    reading: [
      ['快速开始', '从发现到安装 Agent Skill 的最短路径。', 'getting-started'],
      ['CLI', '本地执行引擎与终端界面。', 'cli'],
      ['架构', '了解 App、CLI、Hub、Store 与 Agent 目标如何协作。', 'architecture'],
    ],
    closing: ['让 Skill 自由流动。', '让所有权留在本地。', '阅读文档'],
    footer: ['桌面应用', 'CLI', 'Hub', '架构'],
  },
} as const satisfies Record<Locale, unknown>;

function Home() {
  const { lang } = Route.useParams();
  const locale = resolveLocale(lang);
  const text = copy[locale];
  return (
    <div className="sg-home">
      <a className="sg-skip" href="#main">Skip to main content</a>
      <SiteHeader locale={locale} />

      <main id="main" className="sg-main sg-landing-main">
        <header className="sg-landing-hero">
          <p className="sg-hero-eyebrow">{text.eyebrow}</p>
          <h1><span>{text.heroTitle[0]}</span><span>{text.heroTitle[1]}</span></h1>
          <p className="sg-hero-body">{text.heroBody}</p>
          <div className="sg-actions">
            <Link to="/$lang/docs/$" params={{ lang: locale, _splat: 'getting-started' }} className="sg-button sg-button-primary">{text.primary}</Link>
            <a href="https://github.com/skillsgo/skillsgo" className="sg-text-link">{text.secondary} <span>↗</span></a>
          </div>
          <div className="sg-facts">{text.facts.map((fact) => <span key={fact}>{fact}</span>)}</div>
        </header>

        <section id="problems" className="sg-landing-section sg-pain-section">
          <header className="sg-landing-section-title"><span>{locale === 'zh-CN' ? '01 · 这些问题' : '01 · These problems'}</span><h2>{text.painTitle}</h2></header>
          <ol className="sg-pain-list">
            {text.pains.map((pain) => (
              <li key={pain[0]}><h3>{pain[0]}<small>{pain[1]}</small></h3><p>{pain[2]}</p></li>
            ))}
          </ol>
        </section>

        <section id="overview" className="sg-landing-section sg-transform-section">
          <div className="sg-transform-copy">
            <p>{text.transformation.label}</p>
            <h2>{text.transformation.title}</h2>
            <div>{text.transformation.body}</div>
          </div>
          <TransformationBoard transformation={text.transformation} />
        </section>

        <section id="workflow" className="sg-landing-section sg-simple-workflow">
          <header className="sg-landing-section-title"><span>02</span><h2>{locale === 'zh-CN' ? '只有三个核心步骤' : 'Only three steps matter'}</h2></header>
          <div className="sg-simple-steps">
            {text.simpleSteps.map((step) => <article key={step[0]}><span>{step[0]}</span><div><h3>{step[1]}</h3><p>{step[2]}</p></div></article>)}
          </div>
        </section>

        <section id="ownership" className="sg-landing-section sg-trust-section">
          <div><p>03 · {locale === 'zh-CN' ? '为什么可以放心' : 'Why it is safe'}</p><h2>{text.trustTitle}</h2></div>
          <div><p>{text.trustBody}</p><Link to="/$lang/docs/$" params={{ lang: locale, _splat: 'architecture' }}>{locale === 'zh-CN' ? '查看工作原理' : 'See how it works'} →</Link></div>
        </section>

        <section id="questions" className="sg-landing-section sg-questions">
          <SectionHead values={text.sections.questions} compact />
          <div className="sg-faqs">
            {text.faqs.map((faq) => <details key={faq[0]}><summary>{faq[0]}<span>+</span></summary><p>{faq[1]}</p></details>)}
          </div>
          <div className="sg-doc-contact">
            <p>{locale === 'zh-CN' ? '还有问题？从文档继续' : 'More questions? Continue in the docs'}</p>
            <Link to="/$lang/docs/$" params={{ lang: locale, _splat: '' }}>{locale === 'zh-CN' ? '打开完整文档' : 'Open the complete documentation'} →</Link>
          </div>
        </section>

        <section className="sg-landing-section sg-reading">
          <SectionHead values={text.sections.reading} />
          <div className="sg-reading-list">
            {text.reading.map((item) => <Link key={item[0]} to="/$lang/docs/$" params={{ lang: locale, _splat: item[2] }}><strong>{item[0]}</strong><span>{item[1]}</span><i>→</i></Link>)}
          </div>
        </section>
      </main>

      <footer className="sg-footer">
        <div><strong>SkillsGo</strong><p>{text.intro}</p></div>
        <div>{text.footer.map((item, index) => <Link key={item} to="/$lang/docs/$" params={{ lang: locale, _splat: ['', 'cli', 'hub', 'architecture'][index] }}>{item}</Link>)}</div>
        <p>Open source · Local ownership · Built for Agent Skills</p>
      </footer>
    </div>
  );
}

function SectionHead({ values, compact = false }: { values: readonly string[]; compact?: boolean }) {
  return <header className={compact ? 'sg-section-head sg-section-head-compact' : 'sg-section-head'}><p>{values[0]}</p><h2>{values[1]}</h2>{values[2] && <div>{values[2]}</div>}</header>;
}

function TransformationBoard({ transformation }: { transformation: (typeof copy.en)['transformation'] | (typeof copy)['zh-CN']['transformation'] }) {
  return (
    <div className="sg-transform-board">
      <div className="sg-before-state">
        <strong>{transformation.before}</strong>
        <div>{transformation.scattered.map((item, index) => <span key={item} className={`sg-scattered sg-scattered-${index + 1}`}>{item}</span>)}</div>
      </div>
      <div className="sg-handoff" aria-hidden="true"><span>→</span><small>{transformation.action}</small></div>
      <div className="sg-after-state">
        <strong>{transformation.after}</strong>
        <div className="sg-managed-stack">
          <span className="sg-managed-skill">SKILL.md</span>
          <span className="sg-managed-line" />
          <span className="sg-managed-line" />
          <span className="sg-managed-line" />
        </div>
        <ul>{transformation.outcomes.map((outcome) => <li key={outcome}><span>✓</span>{outcome}</li>)}</ul>
      </div>
    </div>
  );
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
