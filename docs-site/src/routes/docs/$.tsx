/*
 * [INPUT]: Depends on TanStack Router redirects and the canonical English docs route.
 * [OUTPUT]: Redirects legacy unprefixed documentation URLs while preserving their slugs.
 * [POS]: Serves as a compatibility boundary for links created before locale-prefixed routing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { createFileRoute, redirect } from '@tanstack/react-router';

export const Route = createFileRoute('/docs/$')({
  beforeLoad: ({ params }) => {
    const suffix = params._splat ? `/${params._splat}` : '';
    throw redirect({ href: `/en/docs${suffix}`, statusCode: 308 });
  },
});
