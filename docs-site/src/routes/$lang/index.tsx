/*
 * [INPUT]: Depends on locale validation, TanStack Router links, Fumadocs HomeLayout, and shared layout options.
 * [OUTPUT]: Provides localized docs-site landing pages under each supported language prefix.
 * [POS]: Serves as the public orientation page before readers enter a localized documentation tree.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { resolveLocale, type Locale } from '@/lib/i18n';
import { baseOptions } from '@/lib/layout.shared';
import { createFileRoute, Link } from '@tanstack/react-router';
import { HomeLayout } from 'fumadocs-ui/layouts/home';

export const Route = createFileRoute('/$lang/')({
  component: Home,
  head: ({ params }) => {
    const locale = resolveLocale(params.lang);
    const isChinese = locale === 'zh-CN';
    return {
      meta: [
        {
          title: isChinese
            ? 'SkillsGo 文档'
            : 'SkillsGo Documentation',
        },
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
    eyebrow: 'THE OPEN AGENT SKILLS ECOSYSTEM',
    title: 'Skills should travel. Ownership should stay local.',
    intro:
      'SkillsGo connects a desktop App, a local CLI, and a public Hub so people can discover, install, and manage Agent Skills without surrendering control of their files.',
    docs: 'Read the documentation',
    github: 'View on GitHub',
    direction: 'SYSTEM DIRECTION',
    flow: 'Desktop App\n    ↓\nSkillsGo CLI → Local targets\n    ↓\nSkillsGo Hub',
    capabilities: [
      {
        eyebrow: 'DISCOVER',
        title: 'Find useful Skills',
        copy: 'Search a public catalog with stable identity, metadata, and immutable artifacts.',
      },
      {
        eyebrow: 'INSTALL',
        title: 'Keep local ownership',
        copy: 'Project Skills into supported Agent targets through one auditable local engine.',
      },
      {
        eyebrow: 'REPRODUCE',
        title: 'Share intent, not drift',
        copy: 'Use workspace manifests and locks to keep teams aligned across machines.',
      },
    ],
  },
  'zh-CN': {
    eyebrow: '开放的 AGENT SKILLS 生态系统',
    title: '让 Skill 自由流动，让所有权留在本地。',
    intro:
      'SkillsGo 连接桌面应用、本地 CLI 与公共 Hub，帮助你发现、安装和管理 Agent Skills，同时始终掌控自己的文件。',
    docs: '阅读文档',
    github: '在 GitHub 查看',
    direction: '系统调用方向',
    flow: '桌面应用\n    ↓\nSkillsGo CLI → 本地目标\n    ↓\nSkillsGo Hub',
    capabilities: [
      {
        eyebrow: '发现',
        title: '找到实用的 Skills',
        copy: '在具有稳定身份、元数据和不可变制品的公共目录中搜索。',
      },
      {
        eyebrow: '安装',
        title: '保留本地所有权',
        copy: '通过一个可审计的本地引擎，将 Skills 投射到受支持的 Agent 目标。',
      },
      {
        eyebrow: '复现',
        title: '共享意图，避免漂移',
        copy: '使用工作区清单和锁文件，让团队在不同机器上保持一致。',
      },
    ],
  },
} as const satisfies Record<Locale, unknown>;

function Home() {
  const { lang } = Route.useParams();
  const locale = resolveLocale(lang);
  const text = copy[locale];

  return (
    <HomeLayout {...baseOptions(locale)}>
      <main className="sg-hero-grid flex flex-1 flex-col">
        <section className="mx-auto grid w-full max-w-6xl gap-12 px-6 py-20 md:grid-cols-[1.3fr_0.7fr] md:px-10 md:py-28">
          <div>
            <p className="mb-5 font-mono text-xs font-semibold tracking-[0.22em] text-fd-muted-foreground">
              {text.eyebrow}
            </p>
            <h1 className="max-w-3xl text-balance text-5xl font-semibold tracking-[-0.05em] text-fd-foreground md:text-7xl">
              {text.title}
            </h1>
            <p className="mt-7 max-w-2xl text-pretty text-lg leading-8 text-fd-muted-foreground">
              {text.intro}
            </p>
            <div className="mt-9 flex flex-wrap gap-3">
              <Link
                to="/$lang/docs/$"
                params={{ lang: locale, _splat: '' }}
                className="rounded-full bg-fd-primary px-5 py-2.5 text-sm font-semibold text-fd-primary-foreground transition-opacity hover:opacity-85"
              >
                {text.docs}
              </Link>
              <a
                href="https://github.com/skillsgo/skillsgo"
                className="rounded-full border border-fd-border bg-fd-background px-5 py-2.5 text-sm font-semibold text-fd-foreground transition-colors hover:bg-fd-accent"
              >
                {text.github}
              </a>
            </div>
          </div>

          <aside className="self-end border-l border-fd-border pl-6 md:pl-8">
            <p className="font-mono text-xs tracking-[0.18em] text-fd-muted-foreground">
              {text.direction}
            </p>
            <pre className="mt-5 overflow-x-auto text-sm leading-7 text-fd-foreground">
              <code>{text.flow}</code>
            </pre>
          </aside>
        </section>

        <section className="border-y border-fd-border bg-fd-background/90">
          <div className="mx-auto grid max-w-6xl md:grid-cols-3">
            {text.capabilities.map((capability) => (
              <article
                key={capability.title}
                className="border-b border-fd-border p-7 last:border-b-0 md:border-r md:border-b-0 md:last:border-r-0"
              >
                <p className="font-mono text-[11px] font-semibold tracking-[0.18em] text-fd-muted-foreground">
                  {capability.eyebrow}
                </p>
                <h2 className="mt-4 text-xl font-semibold tracking-tight text-fd-foreground">
                  {capability.title}
                </h2>
                <p className="mt-3 text-sm leading-6 text-fd-muted-foreground">
                  {capability.copy}
                </p>
              </article>
            ))}
          </div>
        </section>
      </main>
    </HomeLayout>
  );
}
