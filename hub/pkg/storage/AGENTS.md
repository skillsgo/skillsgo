# Immutable Artifact Storage Module
> F3 | Parent: `/hub/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `backend.go`, `getter.go`, `saver.go`, `lister.go`, `deleter.go`, and `cataloger.go`: define the backend-neutral artifact storage capabilities.
- `immutable.go`, `immutable_test.go`: define bounded `PutIfAbsent`, identical-content idempotency, immutable conflict detection, and the process-local fallback used only when a backend has no stronger native implementation.
- `fs/`: persists Info and ZIP pairs through filesystem-native create-only publication and verifies existing bytes under cross-process races.
- `gcp/`, `s3/`, and `azureblob/`: adapt provider-native conditional object creation to the immutable coordinate contract.
- `mongo/`: reserves a unique coordinate and archive digest before GridFS upload so identical retries can complete interrupted publication.
- `external/`: makes one external storage server authoritative for cross-client `PutIfAbsent` decisions and exposes the corresponding HTTP client adapter.
- `mem/`: provides disposable in-memory storage for tests and development.
- `minio/`: retains the legacy backend implementation for source history only; Hub v1 runtime configuration rejects it because its pinned client cannot guarantee conditional creation.
- `artifact/` and `compliance/`: provide Repository artifact adapters and reusable backend behavior tests.

## Architectural Boundary

This module owns byte persistence and immutable coordinate collision behavior. Repository publication remains owned by the Hub service and Catalog transaction, while ZIP structure and Sum rules belong to the shared Protocol artifact package. A storage backend must never overwrite an existing coordinate with different Info or ZIP bytes; implementation-specific retries, reservations, and conditional requests must preserve identical-content idempotency.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
