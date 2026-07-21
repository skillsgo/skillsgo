# skills.sh Leaderboard Data Fusion Research

Verified against the public skills.sh API documentation, public pages, live
unauthenticated HTTP behavior, and the official `vercel-labs/skills` source on
2026-07-21.

## Executive conclusion

skills.sh does not expose an install-event feed. Its supported API exposes
paginated leaderboard snapshots, without an event ID, installation timestamp,
incremental cursor, or a shared deduplication key. Therefore SkillsGo cannot
produce an exact, deduplicated union of skills.sh and SkillsGo install counts
for Ranking, Trending, or Hot from the current API contract.

The safe design is to ingest skills.sh as a provenance-preserving external
observation source:

- retain the latest upstream all-time and view snapshots separately from
  SkillsGo install events;
- map identity only through exact, normalized source and slug matches;
- expose source-separated counts or a clearly labelled rank-fusion score;
- never convert snapshot differences into authoritative install events; and
- request an upstream event feed or common time-bucket contract before claiming
  an exact combined count.

## Verified API contract

### Authentication and operations

Every supported `/api/v1/` endpoint requires a Vercel OIDC bearer token. The
token is scoped to a Vercel team and project, rotates approximately every 12
hours, and must be read per request or refreshed with `@vercel/oidc`. The API
also accepts `x-vercel-oidc-token`. skills.sh records the verified team,
project, and environment for each authenticated request. See the official
[authentication contract](https://skills.sh/docs/api#authentication).

A live request without a token to
`GET /api/v1/skills?view=all-time&per_page=2` returned HTTP 401 with
`authentication_required`, matching the documented
[error contract](https://skills.sh/docs/api#errors). This means a production
ingester needs a linked Vercel project with OIDC enabled; there is no documented
long-lived API key flow for a non-Vercel worker.

Authenticated traffic is limited to 600 requests per minute per `(team,
project)`. Responses carry `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and
`X-RateLimit-Reset`; HTTP 429 includes `Retry-After`, and HTTP 503 should be
retried with backoff. See the official
[rate-limit contract](https://skills.sh/docs/api#rate-limits).

### Snapshot pagination, not event pagination

`GET /api/v1/skills` supports `view=all-time|trending|hot`, a zero-based `page`,
and `per_page` from 1 to 500. Each response contains `pagination.page`,
`pagination.perPage`, `pagination.total`, and `pagination.hasMore`. The
documented request has no `since`, event cursor, change token, event ID, or
event timestamp. See the official
[leaderboard endpoint](https://skills.sh/docs/api#endpoints).

Consequently, a multi-page crawl is a sequence of independently cached page
snapshots, not a transactionally consistent snapshot. Rank movement while a
crawl is in progress can repeat or omit rows. An ingester should assign its own
`crawl_id`, retain response metadata per page, and publish a crawl only after
all pages succeed, but this still cannot make the upstream pages atomic.

Leaderboard and search responses are documented as cached for 30–60 seconds;
detail and curated responses are cached for five minutes. Polling must respect
the actual `Cache-Control` response header. See the official
[caching guidance](https://skills.sh/docs/api#caching).

### Fields and leaderboard windows

The common list object contains:

- `id`: a stable skills.sh identifier in `{source}/{slug}` format;
- `source`: `owner/repo` for GitHub, or a domain for well-known discovery;
- `slug`, `name`, `installs`, `sourceType`, `installUrl`, and `url`; and
- optional `isDuplicate: true` for a detected fork or copy.

The documentation defines list-object `installs` as the total deduplicated
install count. It also describes `trending` only as “recent growth”, without a
normative window formula, while the public tab currently labels it “Trending
(24h)”. For `hot`, the documentation says the last hour is compared with the
same hour yesterday and adds `installsYesterday` and `change`, where `change =
current hour installs - installsYesterday`. See the official
[leaderboard endpoint](https://skills.sh/docs/api#endpoints),
[skill object](https://skills.sh/docs/api#skill-object), public
[Trending page](https://skills.sh/trending), and public
[Hot page](https://skills.sh/hot).

There is an important contract ambiguity: the common object calls `installs`
the total count, but live public Trending and Hot page payloads use `installs`
as the view value; the Hot payload also includes `installsYesterday` and
`change`. Before implementing the authenticated client, capture fixtures from
all three authenticated views and confirm the value semantics with skills.sh.
The page label and HTML payload are useful observations, but the API contract
does not normatively define Trending's boundary, timezone, late-event policy,
or whether its interval is exactly rolling.

### Identity and duplicate handling

skills.sh documents `id` as stable across requests and always formatted as
`{source}/{slug}`. `sourceType` distinguishes GitHub from well-known sources.
This is sufficient for a stable upstream foreign key, but it is not proof that
a differently cased source, renamed repository, moved slug, mirror, or fork is
the same SkillsGo Skill. See the official
[stable-ID guidance](https://skills.sh/docs/api#stable-ids).

`isDuplicate` only identifies that a row was detected as a fork or copy. The
API supplies no `canonicalOf` identity, so SkillsGo cannot transfer the row's
counts to a guessed original. The safe default is to exclude flagged rows from
a canonical leaderboard while retaining the observation for audit, or display
them as separate rows. See the official
[duplicate-filtering guidance](https://skills.sh/docs/api#filtering-duplicates).

The detail endpoint's `hash` is a SHA-256 digest of the current file snapshot
for cache invalidation. It is neither a leaderboard identity nor an install
event ID, and can be null when no snapshot exists. See the official
[skill-detail endpoint](https://skills.sh/docs/api#endpoints).

## What the upstream count represents

The official CLI emits best-effort installation telemetry containing source,
selected skill names, target Agents, scope, skill paths, metadata, and source
type. Telemetry can be disabled with `DISABLE_TELEMETRY` or `DO_NOT_TRACK`;
delivery errors are swallowed and never fail installation. See the official
[`telemetry.ts` implementation](https://github.com/vercel-labs/skills/blob/777599e1159e401b11ce4c8a57c20f09a8f1596e/src/telemetry.ts#L1-L20)
and its
[enablement and delivery behavior](https://github.com/vercel-labs/skills/blob/777599e1159e401b11ce4c8a57c20f09a8f1596e/src/telemetry.ts#L84-L188).

The official install flow skips telemetry for local paths. For GitHub, it sends
telemetry only when the repository is confirmed public; private repositories
and repositories whose privacy cannot be determined are omitted. See the
official
[`add.ts` installation path](https://github.com/vercel-labs/skills/blob/777599e1159e401b11ce4c8a57c20f09a8f1596e/src/add.ts#L1740-L1805).

Thus “total deduplicated installs” is a deduplicated count within the telemetry
that skills.sh observes, not a census of every real installation. The public
API does not disclose its deduplication key or retention/correction policy.

## Correctness limits for combining the three leaderboards

Let `A` be the set of installations observed by SkillsGo and `B` the set
represented by a skills.sh aggregate. An exact combined count is
`|A union B| = |A| + |B| - |A intersection B|`. The current API provides
`|B|`, but provides no common installation identity from which to calculate the
intersection. Therefore only the bounds `max(|A|, |B|) <= |A union B| <=
|A| + |B|` are knowable. Summing silently assumes disjoint telemetry; taking
the maximum silently assumes complete overlap. Neither is an exact union.

### Ranking

Store the upstream all-time total as an external snapshot. Do not add it to the
SkillsGo event total unless the collection populations are contractually
disjoint. The UI may show both values, or a source-normalized rank-fusion score,
but should not label either as a deduplicated combined install count.

### Trending

Do not add the skills.sh Trending view value to SkillsGo's rolling 24-hour
events until the authenticated response semantics, boundary, timezone, and
late-event behavior are documented and aligned. Even after window alignment,
the unknown intersection remains.

Polling all-time totals and calculating `max(0, current - previous)` is only an
estimate for the interval between two cached observations. It attributes late
arrivals and upstream reconciliation to polling time, misses intermediate
changes, and cannot recover event timestamps. A negative delta is a
reconciliation signal and must not become a negative install event.

### Hot

The current skills.sh Hot signal compares its last-hour count with the same
hour yesterday. SkillsGo's selected Hot model compares one-hour velocity with a
24-hour baseline. These scores have different units and baselines and cannot be
added. Either display both source signals, fuse normalized ranks/percentiles
with explicit provenance, or first adopt one shared definition backed by
authoritative hourly buckets from both systems.

## Recommended ingestion model

1. Run a server-side Vercel OIDC ingester. Refresh credentials per request,
   obey `Cache-Control`, rate-limit headers, `Retry-After`, and exponential
   backoff for transient failures.
2. Crawl each view with `per_page=500`; retain raw responses keyed by
   `(provider, view, crawl_id, page)` and capture `observed_at`, response Date,
   cache metadata, and API schema version.
3. Upsert upstream identity by `(provider, sourceType, normalized source,
   slug)`. Keep the original `id`, source, and install URL. Require an explicit
   alias table and review for renames, moves, case conflicts, and cross-provider
   matches.
4. Keep external observations separate from SkillsGo's accepted install-event
   ledger. Never manufacture accepted events from snapshots.
5. Exclude `isDuplicate: true` from canonical leaderboards by policy, but do not
   merge its count into another Skill without an authoritative canonical ID.
6. Publish only complete crawls. Mark the external source stale after a defined
   freshness deadline; never carry a stale value forward as if it were current.
7. Initially expose provenance-separated metrics. If one ordering is required,
   combine within-view percentiles or reciprocal ranks and call the result a
   composite discovery score, not installs.

## Requirement for exact fusion

Exact count fusion requires at least one of the following upstream contracts:

- an incremental feed containing a stable, globally namespaced `event_id`,
  canonical Skill ID, `occurred_at`, and correction/tombstone semantics, with a
  deduplication identity shared by both systems; or
- authoritative UTC buckets for an agreed Ranking/Trending/Hot definition plus
  a guarantee that SkillsGo and skills.sh observation populations are disjoint.

For exact Hot under the SkillsGo definition, hourly totals covering the whole
baseline are required; a current-hour and same-hour-yesterday pair is
insufficient. Until one of these contracts exists, source-separated facts or
explicit rank fusion is the only correct presentation.
