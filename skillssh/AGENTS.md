# skills.sh Bridge/
> F3 | Parent: `/AGENTS.md` | Workspace: repository utility

## Members

- `api/skills.mjs`: authenticated Vercel Function that validates Hub requests and fetches bounded pages from the skills.sh leaderboard API.
- `api/skills.test.mjs`: Node.js contract tests for authentication, validation, upstream forwarding, and failure handling.
- `.gitignore`: excludes Vercel linkage and local credentials from source control.
- `vercel.json`: Vercel Function deployment configuration.

## Architectural Boundary

This module is a stateless authentication bridge between the SkillsGo Hub and
the skills.sh API. It may validate a Hub bearer token, attach the request-scoped
Vercel OIDC token, and return bounded upstream page responses. It must not own
scheduling, crawl state, persistence, identity reconciliation, install deltas,
or leaderboard calculations.

The `vercel.json` deployment manifest is exempt from an inline F4 contract
because JSON does not support comments; this map is its contract source of
truth.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
