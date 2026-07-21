/*
 * [INPUT]: Depends on the locale registry and TanStack Router layout primitives.
 * [OUTPUT]: Provides validation and a shared outlet for every language-prefixed route.
 * [POS]: Serves as the routing boundary that rejects unsupported locale prefixes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { isLocale } from '@/lib/i18n';
import { createFileRoute, notFound, Outlet } from '@tanstack/react-router';

export const Route = createFileRoute('/$lang')({
  beforeLoad: ({ params }) => {
    if (!isLocale(params.lang)) throw notFound();
    return { locale: params.lang };
  },
  component: Outlet,
});
