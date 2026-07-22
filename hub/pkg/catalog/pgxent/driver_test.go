/*
 * [INPUT]: Depends on the pgx Ent adapter and Ent's public dialect driver result contract.
 * [OUTPUT]: Specifies transaction ownership, PostgreSQL result semantics, and defensive argument validation.
 * [POS]: Serves as unit-level contract coverage adapted from Ent's SQL driver expectations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package pgxent

import (
	"context"
	"database/sql"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/require"
)

type stubTx struct {
	pgx.Tx
	tag       pgconn.CommandTag
	execCalls int
}

func (tx *stubTx) Exec(context.Context, string, ...any) (pgconn.CommandTag, error) {
	tx.execCalls++
	return tx.tag, nil
}

func TestDriverContract(t *testing.T) {
	_, err := NewDriver(nil)
	require.EqualError(t, err, "pgxent: transaction is required")

	underlying := &stubTx{tag: pgconn.NewCommandTag("UPDATE 3")}
	driver, err := NewDriver(underlying)
	require.NoError(t, err)
	require.Equal(t, "postgres", driver.Dialect())
	require.NoError(t, driver.Close())

	tx, err := driver.Tx(t.Context())
	require.NoError(t, err)
	require.NoError(t, tx.Commit())
	require.NoError(t, tx.Rollback())
	require.Zero(t, underlying.execCalls, "Ent's no-op transaction must not complete the caller-owned pgx transaction")
}

func TestDriverExecResult(t *testing.T) {
	underlying := &stubTx{tag: pgconn.NewCommandTag("UPDATE 3")}
	driver, err := NewDriver(underlying)
	require.NoError(t, err)

	var got sql.Result
	require.NoError(t, driver.Exec(t.Context(), "UPDATE widgets", []any{}, &got))
	affected, err := got.RowsAffected()
	require.NoError(t, err)
	require.EqualValues(t, 3, affected)
	_, err = got.LastInsertId()
	require.ErrorIs(t, err, errLastInsertIDUnsupported)

	require.EqualError(t,
		driver.Exec(t.Context(), "UPDATE widgets", "invalid", nil),
		"pgxent: invalid args type string; expected []any",
	)
	require.EqualError(t,
		driver.Exec(t.Context(), "UPDATE widgets", []any{}, new(int)),
		"pgxent: invalid result type *int; expected *sql.Result",
	)
	require.EqualError(t,
		driver.Query(t.Context(), "SELECT 1", []any{}, new(int)),
		"pgxent: invalid rows type *int; expected *sql.Rows",
	)
	require.EqualError(t,
		driver.Query(t.Context(), "SELECT 1", "invalid", &entsql.Rows{}),
		"pgxent: invalid args type string; expected []any",
	)
}
