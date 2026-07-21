/*
 * [INPUT]: Depends on the generated TanStack route tree and the shared not-found component.
 * [OUTPUT]: Provides the router factory consumed by TanStack Start.
 * [POS]: Serves as the client and server routing composition root for Web.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { NotFound } from '@/components/not-found';
import { createRouter as createTanStackRouter } from '@tanstack/react-router';
import { routeTree } from './routeTree.gen';

export function getRouter() {
  return createTanStackRouter({
    routeTree,
    defaultPreload: 'intent',
    scrollRestoration: true,
    defaultNotFoundComponent: NotFound,
  });
}
