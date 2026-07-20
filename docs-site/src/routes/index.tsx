/*
 * [INPUT]: Depends on TanStack Router redirects and the default locale route.
 * [OUTPUT]: Redirects the unprefixed root URL to the canonical English landing page.
 * [POS]: Serves as the backwards-compatible entry point for language-prefixed docs-site routes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { createFileRoute, redirect } from '@tanstack/react-router';

export const Route = createFileRoute('/')({
  beforeLoad: () => {
    throw redirect({ href: '/en', statusCode: 308 });
  },
});
