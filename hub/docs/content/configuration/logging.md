---
title: Logging
description: Configure structured, correlated, and credential-safe Hub logs
weight: 9
---

SkillsGo Hub emits structured operator logs for HTTP requests, Catalog failures, artifact caching, upstream fetches, and Repository publication.

## Standard

Configure output as `plain` or `json` with `LogFormat` or `SKILLSGO_HUB_LOG_FORMAT`. Configure verbosity with `LogLevel` or `SKILLSGO_HUB_LOG_LEVEL`. Supported levels are `debug`, `info`, `warn`/`warning`, and `error`; legacy `trace` maps to `debug`, while `fatal` and `panic` map to `error`.

Use JSON in production so fields remain queryable. Every HTTP completion event includes `request_id`, `http_method`, `http_path`, `route`, `http_status`, `duration_ms`, `response_bytes`, and `handler_error`. Query strings are deliberately excluded. Health and readiness successes are Debug events; normal requests and expected client failures are Info; rate limits are Warn; server failures are Error.

Repository publication adds `repository_id`, `requested_ref`, immutable `version`, `commit_sha`, `member_count`, cache outcome, Singleflight sharing, and duration. Artifact delivery adds cache resource/result, requested and resolved versions, download mode, and upstream duration.

Repository source-metadata refreshes report provider-neutral cache outcomes (`hit`, `revalidated`, `refreshed`, `retry_blocked`, or `unsupported`) by `repository_id`. Provider adapters may add safe diagnostics such as an upstream request ID, status, rate-limit remaining count, and reset time.

Git source synchronization reports the Repository, source host, phase (`network_validation`, `clone`, or `fetch`), outcome, duration, and whether an existing local Repository remains usable. Failed Git commands retain bounded stderr for diagnosis. GitHub REST metadata calls additionally report the operation, conditional-request state, response status, request ID, rate-limit remainder, and duration. Credential redaction applies to both paths.

The logger redacts sensitive field names and common credential forms in messages, including authorization values, passwords, tokens, secrets, API keys, Bearer credentials, GitHub tokens, and URL userinfo. Operators must still avoid adding artifact content, request bodies, environment dumps, or authentication headers to logs.

Public API error messages remain sanitized. The corresponding private log retains `request_id`, `operation`, `error_code`, typed error kind, and the redacted underlying diagnostic.

## Runtimes

The **GCP** runtime emits Google Cloud-compatible `timestamp`, `severity`, and `message` fields while preserving the same structured attributes and level filtering.
