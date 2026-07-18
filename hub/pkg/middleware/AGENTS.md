# HTTP Middleware
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `requestid.go` and `log_entry.go`: establish request identity and correlated structured logging context.
- `request.go`: emits one completion event per HTTP request with route, status, size, duration, and handler outcome.
- `cache_control.go`, `content_type.go`, `filter.go`, and `validation.go`: enforce shared HTTP response and input policies.
- `*_test.go`: verify request correlation, completion events, protocol headers, and validation behavior.

## Architectural Boundary

This module owns transport-wide HTTP policies and request lifecycle observability. It must not contain Catalog business rules, log query strings or request bodies, or convert private diagnostics into public error details.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
