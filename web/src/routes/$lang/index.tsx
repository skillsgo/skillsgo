/*
 * [INPUT]: Depends on locale resolution, shared design-system shells and content patterns, the authorized Mole content snapshot, and local Mole assets.
 * [OUTPUT]: Provides the localized route with shared SkillsGo chrome and a faithful React implementation of the Mole landing body.
 * [POS]: Serves as the public landing adapter while keeping copied presentation isolated from design-system ownership.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { ArticleList, EditorialSectionHeader, SiteShell } from '@/design-system';
import { resolveLocale } from '@/lib/i18n';
import '@/styles/mole-landing.css';
import { createFileRoute } from '@tanstack/react-router';
import { useEffect, useState } from 'react';

export const Route = createFileRoute('/$lang/')({
  component: Home,
  head: ({ params }) => {
    const locale = resolveLocale(params.lang);
    const isChinese = locale === 'zh-CN';
    return {
      meta: [
        { title: isChinese ? 'SkillsGo · 发现与管理 Agent Skills' : 'SkillsGo · Discover and manage Agent Skills' },
        { name: 'description', content: isChinese ? '发现、安装和管理 Agent Skills，同时保留本地文件所有权。' : 'Discover, install, and manage Agent Skills while keeping ownership of local files.' },
      ],
      links: [
        { rel: 'canonical', href: `/${locale}` },
        { rel: 'alternate', hrefLang: 'en', href: '/en' },
        { rel: 'alternate', hrefLang: 'zh-CN', href: '/zh-CN' },
      ],
    };
  },
});

const asset = (path: string) => `/mole/img/${path}`;
const purchaseUrl = 'https://checkout.dodopayments.com/buy/pdt_0NeAQjL4YEqzkukadjRUT';

const galleryItems = [
  ['clean', '清理', '雨洗旧土，尘随潮去。', 'ch/clean.webp', 'Clean 页面，显示地球和扫描按钮'],
  ['uninstall', '软件', '红尘覆旧，轻装再行。', 'ch/uninstall.webp', '软件页面，显示应用更新、启动项管理和卸载控制'],
  ['optimize', '优化', '近轨疾行，小修有声。', 'ch/optimize.webp', 'Optimize 页面，显示水星'],
  ['analyze', '分析', '远目成图，微处可见。', 'ch/analyze.webp', 'Analyze 页面，显示磁盘 treemap'],
  ['status', '状态', '光华不寐，心跳长明。', 'ch/status.webp', 'Status 页面，显示系统实时状态面板'],
  ['menubar', '菜单栏 HUD', '实时指标常驻菜单栏，一眼可见。', 'ch/menubar.webp', '菜单栏 HUD，显示小动物动画、实时指标、隐私占用、保持唤醒、硬件卡片和高负载进程'],
  ['worlds', '五个世界', '小爪无声，长径入尘。', 'ch/lore.webp', 'About 页面，列出五个星球和工具'],
] as const;

const features = [
  ['清理', '山雨涤尘垢，潮退万象新', 'planet/clean.webp', ['十类缓存分类扫描，按删除安全度排序。', '先看后删，每一项都能勾选或跳过。', '缓存可选择永久清理或移到废纸篓。', '全程本地运行，数据不离开电脑。']],
  ['软件', '红沙湮旧迹，长风启远征', 'planet/software.webp', ['Sparkle、App Store、Homebrew 等来源统一更新。', '卸载连残留一起清干净。', '启动项也在同一页统一管理。', '移除前先看清每个应用能腾出多少空间。']],
  ['优化', '近日疾如电，纤毫定乾坤', 'planet/optimize.webp', ['一键维护 Quick Look、缓存和元数据。', '管理员任务合并成一次授权。', '拿不准的项自动跳过，绝不硬来。', '几秒完成，并告诉你清理了多少。']],
  ['分析', '极目收万象，秋毫尽分明', 'planet/analyze.webp', ['treemap 一眼看清空间去向。', '逐层下钻，快速定位大文件。', '右键直达 Finder 和废纸篓。', '系统目录默认排除，操作更安心。']],
  ['状态', '光华贯昼夜，脉动照山河', 'planet/status.webp', ['实时 CPU、内存、GPU、磁盘、网络与风扇，电量覆盖 Mac、iPhone 和蓝牙配件。', '进程按真实占用排序，还能看懂它在干嘛。', '菜单栏 HUD 常驻，随时瞄一眼。', '点开任意进程，看它为何忙碌。']],
] as const;

type Quote = { text?: string; name?: string; handle?: string; href: string; image?: string; short?: boolean; video?: boolean; github?: boolean };
const quoteColumns: Quote[][] = [
  [
    { text: 'Asked the Mole author how it actually works, then dug into why macOS junk piles up.', name: 'Paul Graham', handle: '@paulg', href: 'https://x.com/paulg/status/2009279786158272820', image: 'avatars/paulg.jpg' },
    { text: 'Si usas macOS necesitas esta herramienta. Se llama Mole y limpia/optimiza tu sistema. Es una alternativa gratuita y de código abierto a CleanMyMac y AppCleaner.', name: 'Miguel Ángel Durán', handle: '@midudev', href: 'https://x.com/midudev/status/2004581862329471120', image: 'avatars/midudev.jpg' },
    { text: 'คนที่ใช้ macbook ปีเก่าๆ แล้วรู้สึกมันช้า ลอง clean เครื่องดูครับ พวก cach file , app data เก่าๆ ที่ไม่ใช้แล้ว\nผมใช้ opensource ตัวนึงชื่อ mole\n- ฟรี ไม่ต้องไปเสียตังซื้อพวก app 3rd party\n- มันทำได้เหมือนๆกันอะแหละแค่สะดวกกว่า\n- ใช้ง่าย ไม่วุ่นวายดี\nวิธีลงอาจจะยากนิดนึง', name: 'sapiens', handle: '@sapiensp_', href: 'https://x.com/sapiensp_/status/2054260600067559795', image: 'avatars/sapiensp_.jpg' },
    { text: 'Для каго тэрмінал нешта страшнае і незразумелае', name: 'Ivan Klimčuk', handle: '@klmivn', href: 'https://x.com/klmivn/status/2053871201169100902', image: 'avatars/klmivn.jpg' },
    { text: 'I came across this very cool tool to clean up your macOS environment. It consolidates features from CleanMyMac, AppCleaner, DaisyDisk, and iStat. Open source and gratis!', name: 'Pedro Piñera', handle: '@pepicrft', href: 'https://x.com/pepicrft/status/2003772976718581923', image: 'avatars/pepicrft.jpg' },
  ],
  [
    { text: 'Mole is brilliant.', name: 'Peter Steinberger', handle: '@steipete', href: 'https://x.com/steipete/status/2003922592001036760', image: 'avatars/steipete.png', short: true },
    { text: "My Mac was slow. I found an amazing free solution that cleaned it up, and now it's fast. Very good, runs in terminal.", name: 'Sheel Mohnot', handle: '@pitdesi', href: 'https://x.com/pitdesi/status/2009268352422957248', image: 'avatars/pitdesi.jpg' },
    { text: 'Nouvelle version de Mole, l’utilitaire gratuit pour nettoyer votre Mac', name: 'Gonzague 👨🏼‍💻', handle: '@gonzague', href: 'https://x.com/gonzague/status/2022926541114740832', image: 'avatars/gonzague.jpg' },
    { text: 'How to Clean your Mac for FREE with MOLE (Open Source Terminal App)', name: 'Arthur Brassart', handle: 'YouTube', href: 'https://www.youtube.com/watch?v=6qM0wwfI3bo', video: true },
    { text: 'Если что, как установить правильно, а не как в статье\nbrew install tw93/tap/mole', name: 'neolol', handle: '@neolol', href: 'https://x.com/neolol/status/2004857712254091490', image: 'avatars/neolol.jpg' },
    { text: 'Cleanmymac要完了。', name: '猫总', handle: '@catmangox', href: 'https://x.com/catmangox/status/2054019229805060421', image: 'avatars/catmangox.jpg' },
  ],
  [
    { href: 'https://github.com/tw93/Mole', github: true },
    { text: 'Mole 直接清理了 39 GB 的空间\n拯救我的 512 小硬盘于水火之中\n付费了', name: 'Orange AI', handle: '@oran_ge', href: 'https://x.com/oran_ge/status/2058678690624791013', image: 'avatars/oran_ge.png' },
    { text: 'システムのクリーンアップや高速化を設定できるmacOS向けCLIツール。moというコマンド名は他と被ってしまいそうではあるが。 / “GitHub - tw93/Mole: 🐹 Deep clean and optimize your Mac.”', name: 'matsuu', handle: '@matsuu', href: 'https://x.com/matsuu/status/2005164921953439936', image: 'avatars/matsuu.jpg' },
    { text: '9GB Free up!!\nHasil cleaning dari MOLE\nAplikasi gratis, kalo mau yang berbayar beli CleanMyMac\nHasilnya? Sama aja :))\nYang mau clean MacOS bisa coba,\nInstall via homebrew di terminal\nRun\nBrew install mole', name: 'if someday', handle: '@Agungrizki7', href: 'https://x.com/Agungrizki7/status/2069250988213723405', image: 'avatars/agungrizki7.jpg' },
    { text: 'Terminal tool for deep Mac cleanup and app uninstall.', name: 'Tom Dörr', handle: '@tom_doerr', href: 'https://x.com/tom_doerr/status/1975169790516895966', image: 'avatars/tom_doerr.jpg' },
  ],
];

const githubAvatars = ['tw93.jpg', 'sebastianbreguel.jpg', 'jackphallen.jpg', 'bhadraagada.jpg', 'yuzeguitarist.jpg', 'm-hassan-raza.jpg', 'iamxorum.jpg', 'dwjoss.jpg', 'alexandear.jpg', 'noah-qin.jpg', 'xronocode.jpg', 'amanthanvi.jpg', 'hhh2210.jpg'];
const verifiedHandles = new Set(['@paulg', '@midudev', '@sapiensp_', '@pepicrft', '@steipete', '@pitdesi', '@gonzague', '@catmangox', '@oran_ge', '@matsuu', '@tom_doerr']);

const faqItems = [
  ['Mac App 和命令行版有什么区别？', <>Mac 版把完整的 Mole 做成原生应用：清理缓存、卸载应用和残留、修复 Quick Look、缓存与系统元数据、查看整盘空间，并实时显示 CPU、内存、GPU、磁盘、电池和风扇。菜单栏面板、风扇控制、启动项管理、应用内更新和隐私提醒也都包含在内。<a href="https://github.com/tw93/Mole" target="_blank" rel="noreferrer">命令行版</a>继续面向终端用户免费开源。</>],
  ['和 CleanMyMac 相比有什么不同？', <>一次买断，没有订阅，也不用续费。Mole 每次都先列出文件，确认后才清理，可恢复的删除会进入废纸篓。除了开发和 AI 工具缓存、设计软件、云盘、浏览器残留与大日志，还提供整盘空间图、实时状态、菜单栏面板、风扇控制和隐私提醒。一个原生应用，一个价格，没有功能分级。</>],
  ['Mole 会不会误删我的文件？', <>每次操作都先显示文件清单和大小，确认后才会动手。应用卸载走系统废纸篓；缓存按所选清理方式执行，清空废纸篓本身不可恢复。系统路径和已知缓存位置之外的一切直接拒绝，拿不准安全性的文件宁可跳过，并告诉你原因。</>],
  ['为什么 Mole 需要完全磁盘访问权限和管理员密码？', <>完全磁盘访问权限让扫描器能读到用户资料库里的缓存和残留，macOS 14 起系统对这些目录有强制要求。管理员密码只在清理系统级缓存时出现，并且始终通过同一个经过审计的助手执行，所有操作都在本机完成。两者都不给也能用，只是能清理的范围会小一些。</>],
  ['Mole 会上传文件名或扫描结果吗？', <>不会。Mac App 不含统计或遥测，也不会上传文件内容、文件名、路径或扫描结果。只有验证授权、检查 Mole 签名更新、检查选定的应用更新源，以及打开网络详情时查询公网 IP 会联网。</>],
  ['购买时 Mole 会看到什么？', <>只有许可证邮箱和用于收据的姓名会到 Mole 这边。付款、税务和发票都由 Dodo Payments 处理，Mole 不会接触银行卡信息，也不接触清理数据。</>],
  ['收不到许可证邮件或找回密钥？', <>打开 <a href="https://customer.dodopayments.com/" target="_blank" rel="noreferrer">Dodo Payments 客户门户</a>，输入购买时填写的邮箱，Dodo 会发送一次性登录链接。登录后可以查看订单、下载发票，并找到这笔 Mole 购买对应的许可证密钥。仍然找不到的话，把购买邮箱或 Payment ID 发到 <a href="mailto:hi@mole.fit">hi@mole.fit</a>。</>],
  ['激活失败？', <>先重新复制 Dodo Payments 邮件里的完整密钥，Mole 会自动清掉空格、换行和被邮件应用改写的连字符。提示网络连接失败时，先关闭 VPN 或代理，或切换手机热点后重试。一份授权可用于 2 台 Mac：设备数已满时，激活窗口会列出已激活的设备，点一下即可释放旧机器。仍然失败的话，可以看看<a href="https://mole.fit/zh/help">帮助页面</a>，或把报错信息发到 <a href="mailto:hi@mole.fit">hi@mole.fit</a>。</>],
] as const;

function Home() {
  const { lang } = Route.useParams();
  const locale = resolveLocale(lang);
  return (
    <SiteShell locale={locale} mainClassName="sg-mole-page page">
        <MoleHero />
        <GallerySection />
        <FeaturesSection />
        <VoicesSection />
        <PricingSection />
        <FaqSection />
        <BlogSection />
    </SiteShell>
  );
}

function MoleHero() {
  return (
    <header id="problems" className="hero">
      <h1>Mole<span className="cn-orbit"><span className="cn" lang="zh">鼴</span></span></h1>
      <p className="tagline">{['清理缓存、', '管理 App、', '运行维护、', '分析磁盘、', '查看实时状态，', '一个原生 Mac App 就够了。'].map(text => <span className="tagline-cluster" key={text}>{text}</span>)}</p>
      <div className="hero-offer"><span className="hero-trust">{['$19 一次购买', '免费试用', '永久更新', '2 台 Mac', '14 天退款', 'macOS 14+', '无障碍'].map(text => <span key={text}>{text}</span>)}<a className="hero-version" href="https://mole.fit/zh/releases">v1.11.0</a></span></div>
      <div className="hero-cta"><a className="btn-primary" href={purchaseUrl} target="_blank" rel="noreferrer">购买</a><a className="btn-ghost" href="https://mole.fit/download">Mac 下载</a></div>
    </header>
  );
}

function GallerySection() {
  const [activeId, setActiveId] = useState('analyze');
  useEffect(() => {
    if (window.matchMedia('(max-width: 600px)').matches) setActiveId('clean');
  }, []);
  const active = galleryItems.find(item => item[0] === activeId) ?? galleryItems[3];
  return (
    <section id="overview">
      <EditorialSectionHeader eyebrow="00 · 先看看" title="五个工具，一个入口" description="清理、软件、优化、分析、状态，加上菜单栏 HUD、隐私提醒、电池充电限制、风扇控制、屏幕常亮和擦屏幕，全都在这一个 App 里。" />
      <div className="gallery">
        <div className="gallery-frame">{galleryItems.map(item => <figure key={item[0]} id={`gallery-panel-${item[0]}`} className={`gallery-panel${item[0] === activeId ? ' is-active' : ''}`} role="tabpanel" aria-hidden={item[0] !== activeId}><img src={asset(item[3])} alt={item[4]} width="2584" height="1741" loading={item[0] === 'clean' ? 'eager' : 'lazy'} decoding="async" /></figure>)}</div>
        <div className="gallery-tabs" role="tablist" aria-label="选择 Mole 工具截图">{galleryItems.map(item => <button key={item[0]} type="button" role="tab" className={item[0] === activeId ? 'is-active' : undefined} aria-selected={item[0] === activeId} aria-controls={`gallery-panel-${item[0]}`} tabIndex={item[0] === activeId ? 0 : -1} onClick={() => setActiveId(item[0])}>{item[0] === 'menubar' ? '菜单栏' : item[0] === 'worlds' ? '星球' : item[1]}</button>)}</div>
        <div className="gallery-caption"><p className="title">{active[1]}</p><p className="line">{active[2]}</p></div>
      </div>
    </section>
  );
}

function FeaturesSection() {
  return <section id="workflow" className="feature-summary"><EditorialSectionHeader eyebrow="01 · 五个星球" title="五颗星球，五件小事" description="每颗星球对应一项任务，让你在运行前看清 Mole 会检查什么、可能改动什么，以及何时需要确认。" /><div className="feature-cards">{features.map(([name, poem, image, points]) => <article className="fcard" key={name}><figure className="fcard-media"><img src={asset(image)} alt={name} width="1000" height="640" loading="lazy" decoding="async" /><figcaption className="fcard-poem">{poem}</figcaption><p className="fcard-name">{name}</p></figure><div className="fcard-body"><ul className="fcard-points">{points.map(point => <li key={point}>{point}</li>)}</ul></div></article>)}</div></section>;
}

function QuoteCard({ quote }: { quote: Quote }) {
  if (quote.github) return <a className="quote-card gh-card" href={quote.href} target="_blank" rel="noreferrer"><div className="gh-head"><span className="gh-logo" aria-hidden="true"><svg viewBox="0 0 16 16" width="18" height="18"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82A7.6 7.6 0 018 3.55c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z" /></svg></span><b>tw93 / Mole</b></div><span className="gh-avatars">{githubAvatars.map(name => <img className="gh-av" key={name} src={asset(`github/${name}`)} width="24" height="24" alt="" loading="lazy" />)}</span><p className="gh-people"><b>111</b> 贡献者</p><div className="gh-stats"><span><b>58.5k</b> Stars</span><span><b>2.1k</b> Forks</span><span><b>761</b> 已解决 Issue</span></div></a>;
  return <a className={`quote-card${quote.short ? ' is-short' : ''}${quote.video ? ' video-card' : ''}`} href={quote.href} target="_blank" rel="noreferrer">{quote.video && <span className="video-thumb"><img className="video-img" src={asset('youtube/6qM0wwfI3bo.jpg')} width="480" height="360" alt="" loading="lazy" /><span className="video-play" aria-hidden="true" /></span>}<p className={`quote-text${quote.video ? ' video-title' : ''}`}>{quote.text}</p><span className="quote-author">{quote.image ? <img className="quote-avatar" src={asset(quote.image)} width="40" height="40" alt="" loading="lazy" /> : <span className="quote-avatar quote-avatar-yt" aria-hidden="true" />}<span className="quote-meta"><b className="quote-name">{quote.name}{quote.handle && verifiedHandles.has(quote.handle) && <span className="quote-verified" aria-hidden="true" />}</b><span className="quote-handle">{quote.handle}</span></span></span></a>;
}

function VoicesSection() {
  const [expanded, setExpanded] = useState(false);
  const [mobile, setMobile] = useState(false);
  useEffect(() => {
    const media = window.matchMedia('(max-width: 560px)');
    const sync = () => setMobile(media.matches);
    sync();
    media.addEventListener('change', sync);
    return () => media.removeEventListener('change', sync);
  }, []);
  const mobileFeatured = [quoteColumns[0][0], quoteColumns[1][0], quoteColumns[2][0], quoteColumns[1][1]];
  const columns = mobile ? [expanded ? quoteColumns.flat() : mobileFeatured] : quoteColumns;
  return <section id="voices"><EditorialSectionHeader eyebrow="02 · 口碑" title="大家怎么说" description="折腾党、独立开发者和重度用户，桌面应用与命令行都有人在用。" /><div id="voices-wall" className={`quotes is-masonry${expanded ? '' : ' is-collapsed'}`} style={!mobile && !expanded ? { maxHeight: 951 } : undefined}>{columns.map((column, index) => <div className="quotes-col" key={index}>{column.map(quote => <QuoteCard quote={quote} key={quote.href} />)}</div>)}</div><button type="button" className={`quotes-more${expanded ? ' is-expanded' : ''}`} aria-controls="voices-wall" aria-expanded={expanded} onClick={() => setExpanded(value => !value)}>{expanded ? '收起' : '展开全部'}</button><p className="voices-search"><span className="voices-search-lead">来自全球开发者的真实声音，更多见于</span> <span className="voices-search-links"><a href="https://x.com/search?q=mole%20mac&f=top">X</a> · <a href="https://www.google.com/search?q=tw93%20Mole%20mac%20cleaner">Google</a> · <a href="https://www.youtube.com/results?search_query=tw93%20mole%20mac%20cleaner">YouTube</a></span></p></section>;
}

function CheckIcon() {
  return <svg className="pb-check" width="15" height="15" viewBox="0 0 16 16" aria-hidden="true"><circle cx="8" cy="8" r="8" /><path d="M4.7 8.4l2.2 2.2 4.5-4.9" fill="none" stroke="#faf9f5" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" /></svg>;
}

function PricingSection() {
  const benefits = ['五个工具，一个原生应用', '终身免费更新，无需订阅', '一份授权可用于 2 台 Mac', '14 天全额退款，不问原因', '每个付费工具免费试用两次', 'Swift 原生打造，快而轻量'];
  return <section id="pricing"><EditorialSectionHeader eyebrow="03 · 定价" title="一次购买，永久更新" description="买一个 Mole，相当于同时购买了 CleanMyMac、App Cleaner & Uninstaller、DaisyDisk、iStat Menus 和 Sensei。" /><div className="price-card"><div className="price-lead"><p className="price-amount"><span className="price-currency">$</span><span className="price-number">19</span></p><p className="price-vs">永久使用，无需订阅</p></div><a className="btn-primary" href={purchaseUrl} target="_blank" rel="noreferrer">立即购买</a><ul className="price-benefits">{benefits.map(item => <li key={item}><CheckIcon /><span className="pb-line">{item}</span></li>)}</ul></div></section>;
}

function FaqSection() {
  return <section id="questions"><EditorialSectionHeader eyebrow="04 · 问题" title="你会关心的事" /><div className="faq">{faqItems.map(([question, answer]) => <details className="faq-item" key={question}><summary><h3>{question}</h3><span className="faq-chevron" aria-hidden="true" /></summary><div className="faq-answer">{answer}</div></details>)}</div><div className="contact"><p className="contact-title">有问题？直接找我</p><p className="contact-sub">开源打造，上百人参与，发票、退款、换 Mac 激活请看<a href="https://mole.fit/zh/help">帮助页</a></p><div className="contact-cards"><ContactCard href="https://x.com/HiTw93" image="tw93.png" name="Tw93" handle="@HiTw93" stat="151.4K 粉丝">我是 Kaku、Pake、MiaoYan、Waza、Kami 和 Mole 的作者，私信一直开放，产品进展和日常都由我自己更新。</ContactCard><ContactCard href="https://github.com/tw93/Mole" image="mole-cli.png" name="tw93 / Mole" handle="GitHub" stat="58.5K 星标" github>Mole 的免费开源命令行版本，在终端里完成清理和监控，每一行实现都公开可读。</ContactCard></div></div></section>;
}

function ContactCard({ href, image, name, handle, stat, github = false, children }: { href: string; image: string; name: string; handle: string; stat: string; github?: boolean; children: React.ReactNode }) {
  return <a className={`contact-card${github ? ' contact-card-gh' : ''}`} href={href} target="_blank" rel="noreferrer"><span className="contact-head"><img className="contact-avatar" src={asset(image)} width="34" height="34" alt="" loading="lazy" /><span className="contact-meta"><b>{name}</b><span className="contact-handle">{handle}</span></span><span className="contact-stat">{stat}</span></span><p className="contact-desc">{children}</p></a>;
}

function BlogSection() {
  const posts = [['Fix Google Chrome Helper High CPU on Mac', '2026-07-19', 'google-chrome-helper-high-cpu-mac'], ['How to Check Mac Temperature and Fan Speed', '2026-07-19', 'how-to-check-mac-temperature'], ['Clean Up Ollama and LM Studio Models on Mac', '2026-07-18', 'how-to-remove-ai-tool-leftovers-mac']] as const;
  const items = posts.map(([title, date, slug]) => ({ href: `https://mole.fit/blog/${slug}`, title, date, language: 'en' }));
  return <section id="blog" className="blog-latest"><EditorialSectionHeader eyebrow="05 · 博客" title="近期文章" titleHref="https://mole.fit/blog" /><ArticleList items={items} /></section>;
}
