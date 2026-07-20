/*
 * [INPUT]: Depends on route locale resolution, shared layout options, and Fumadocs' home not-found view.
 * [OUTPUT]: Provides the router-level not-found page.
 * [POS]: Serves as the consistent fallback for unknown documentation routes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { resolveLocale } from '@/lib/i18n';
import { baseOptions } from '@/lib/layout.shared';
import { useParams } from '@tanstack/react-router';
import { HomeLayout } from 'fumadocs-ui/layouts/home';
import { DefaultNotFound } from 'fumadocs-ui/layouts/home/not-found';

export function NotFound() {
  const params = useParams({ strict: false });
  const locale = resolveLocale(params.lang);

  return (
    <HomeLayout {...baseOptions(locale)}>
      <DefaultNotFound />
    </HomeLayout>
  );
}
