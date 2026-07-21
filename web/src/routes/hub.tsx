/*
 * [INPUT]: Depends on TanStack Router redirects and the canonical English Hub route.
 * [OUTPUT]: Redirects the unprefixed Hub URL to the canonical English Hub landing page.
 * [POS]: Serves as the stable public entry point for the language-prefixed Hub Web surface.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { createFileRoute, redirect } from '@tanstack/react-router';

export const Route = createFileRoute('/hub')({
  beforeLoad: () => {
    throw redirect({ href: '/en/hub', statusCode: 308 });
  },
});
