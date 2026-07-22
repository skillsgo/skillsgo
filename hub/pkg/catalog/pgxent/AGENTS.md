# Catalog pgx Ent Adapter Module
> F3 | Parent: `/hub/pkg/catalog/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/hub`

## Members

- `driver.go`: binds generated Ent clients to caller-owned native `pgx.Tx` transactions.
- `driver_test.go`: ports the relevant Ent dialect driver contract checks for result handling, transaction ownership, and argument validation.
- `postgres_integration_test.go`: verifies generated Ent CRUD, relations, commit, rollback, and atomic River task visibility against real PostgreSQL.

## Architectural Boundary

This module adapts an already-open native PostgreSQL transaction to Ent's public `dialect.Driver` contract. It never begins, commits, rolls back, or closes the caller-owned pgx transaction, and it must not contain Catalog domain behavior.

## Ent and River Transaction Contract

Use `Catalog.WithPostgresTx` whenever one operation must atomically mutate Catalog entities through generated Ent builders and enqueue a River task. The callback receives an Ent client and the exact same native `pgx.Tx`; returning nil commits both sets of writes, while returning an error or panicking rolls both back.

```go
type reindexArgs struct {
    RepositoryID string `json:"repository_id" river:"unique"`
}

func (reindexArgs) Kind() string { return "repository_reindex" }

err := catalog.WithPostgresTx(ctx, func(entClient *catalogent.Client, tx pgx.Tx) error {
    if _, err := entClient.Repository.
        Create().
        SetRepositoryID(repositoryID).
        Save(ctx); err != nil {
        return err
    }
    return tasks.EnqueueTx(
        ctx,
        tx,
        reindexArgs{RepositoryID: repositoryID},
        taskqueue.InsertOptions{Unique: true, MaxAttempts: 8},
    )
})
```

The callback must not call `Commit`, `Rollback`, or `Close`. It must not replace `tx` with a transaction obtained from `database/sql`, another pool acquisition, or `entClient.Tx`. Catalog owns completion and `pgxent.Driver.Tx` is deliberately a no-op wrapper used only when an Ent graph operation requests an internal transaction.

Code that writes through the root Catalog SQLx or Ent clients does not automatically join this transaction. Transactional domain functions must use the callback-scoped `entClient`, and River submissions must use the callback-scoped `tx`. SQLite has no durable River transaction and `WithPostgresTx` rejects that dialect explicitly.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md
