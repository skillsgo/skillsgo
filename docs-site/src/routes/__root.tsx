/*
 * [INPUT]: Depends on locale resolution, TanStack document primitives, global CSS, Fumadocs providers, and static search.
 * [OUTPUT]: Provides the localized HTML document shell and root route for every docs-site page.
 * [POS]: Serves as the top-level rendering and provider boundary for the application.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import SkillsGoSearchDialog from '@/components/search';
import { resolveLocale, translations } from '@/lib/i18n';
import appCss from '@/styles/app.css?url';
import {
  createRootRoute,
  HeadContent,
  Outlet,
  Scripts,
  useParams,
} from '@tanstack/react-router';
import { i18nProvider } from 'fumadocs-ui/i18n';
import { RootProvider } from 'fumadocs-ui/provider/tanstack';

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      {
        name: 'viewport',
        content: 'width=device-width, initial-scale=1',
      },
      {
        title: 'SkillsGo Documentation',
      },
      {
        name: 'description',
        content: 'Discover, install, and manage Agent Skills with SkillsGo.',
      },
    ],
    links: [{ rel: 'stylesheet', href: appCss }],
  }),
  component: RootComponent,
});

function RootComponent() {
  const params = useParams({ strict: false });
  const locale = resolveLocale(params.lang);

  return (
    <html lang={locale} suppressHydrationWarning>
      <head>
        <HeadContent />
      </head>
      <body className="flex min-h-screen flex-col">
        <RootProvider
          i18n={i18nProvider(translations, locale)}
          search={{ SearchDialog: SkillsGoSearchDialog }}
        >
          <Outlet />
        </RootProvider>
        <Scripts />
      </body>
    </html>
  );
}
