/*
 * [INPUT]: Depends on localized browser collections, static server functions, the content source, shared site header, and Fumadocs layouts.
 * [OUTPUT]: Provides prerenderable, editorially themed documentation pages for every locale and content slug.
 * [POS]: Serves as the primary localized content loading and MDX rendering boundary for Web documentation.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { useMDXComponents } from '@/components/mdx';
import { SiteHeader } from '@/components/site-header';
import { isLocale } from '@/lib/i18n';
import { baseOptions } from '@/lib/layout.shared';
import { gitConfig } from '@/lib/shared';
import { slugsToMarkdownPath, source } from '@/lib/source';
import { createFileRoute, Link, notFound } from '@tanstack/react-router';
import { createServerFn } from '@tanstack/react-start';
import { staticFunctionMiddleware } from '@tanstack/start-static-server-functions';
import browserCollections from 'collections/browser';
import { useFumadocsLoader } from 'fumadocs-core/source/client';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import {
  DocsBody,
  DocsDescription,
  DocsPage,
  DocsTitle,
  MarkdownCopyButton,
  ViewOptionsPopover,
} from 'fumadocs-ui/layouts/docs/page';
import { Suspense } from 'react';

export const Route = createFileRoute('/$lang/docs/$')({
  component: Page,
  loader: async ({ params }) => {
    if (!isLocale(params.lang)) throw notFound();
    const slugs = params._splat?.split('/').filter(Boolean) ?? [];
    const data = await loadPage({ data: { locale: params.lang, slugs } });
    await clientLoader.preload(data.path);
    return data;
  },
  head: ({ loaderData }) => {
    if (!loaderData) return {};
    const suffix = loaderData.pageUrl.replace(/^\/(?:en|zh-CN)/, '');
    return {
      meta: [
        { title: `${loaderData.title} | SkillsGo` },
        { name: 'description', content: loaderData.description },
      ],
      links: [
        { rel: 'canonical', href: loaderData.pageUrl },
        { rel: 'alternate', hrefLang: 'en', href: `/en${suffix}` },
        {
          rel: 'alternate',
          hrefLang: 'zh-CN',
          href: `/zh-CN${suffix}`,
        },
      ],
    };
  },
});

const loadPage = createServerFn({ method: 'GET' })
  .validator((input: { locale: string; slugs: string[] }) => input)
  .middleware([staticFunctionMiddleware])
  .handler(async ({ data: { locale, slugs } }) => {
    if (!isLocale(locale)) throw notFound();
    const page = source.getPage(slugs, locale);
    if (!page) throw notFound();

    return {
      locale,
      path: page.path,
      pageUrl: page.url,
      title: page.data.title,
      description: page.data.description,
      markdownUrl: slugsToMarkdownPath(page.slugs, locale).url,
      pageTree: await source.serializePageTree(source.getPageTree(locale)),
    };
  });

const clientLoader = browserCollections.docs.createClientLoader({
  component(
    { toc, frontmatter, default: MDX },
    {
      markdownUrl,
      path,
    }: {
      markdownUrl: string;
      path: string;
    },
  ) {
    return (
      <DocsPage toc={toc}>
        <DocsTitle>{frontmatter.title}</DocsTitle>
        <DocsDescription>{frontmatter.description}</DocsDescription>
        <div className="-mt-4 flex flex-row items-center gap-2 border-b pb-6">
          <MarkdownCopyButton markdownUrl={markdownUrl} />
          <ViewOptionsPopover
            markdownUrl={markdownUrl}
            githubUrl={`https://github.com/${gitConfig.user}/${gitConfig.repo}/blob/${gitConfig.branch}/web/content/docs/${path}`}
          />
        </div>
        <DocsBody>
          <MDX components={useMDXComponents()} />
        </DocsBody>
      </DocsPage>
    );
  },
});

function Page() {
  const { locale, pageTree, path, markdownUrl } = useFumadocsLoader(
    Route.useLoaderData(),
  );

  return (
    <div className="sg-docs-theme">
      <SiteHeader locale={locale} />
      <DocsLayout {...baseOptions(locale)} tree={pageTree}>
        <Link to={markdownUrl} hidden />
        <Suspense>{clientLoader.useContent(path, { markdownUrl, path })}</Suspense>
      </DocsLayout>
    </div>
  );
}
