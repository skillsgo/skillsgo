/*
 * [INPUT]: Depends on a caller-owned pgx.Tx plus Ent's public dialect and SQL row contracts.
 * [OUTPUT]: Provides a transaction-bound Ent client and dialect.Driver without taking transaction ownership.
 * [POS]: Serves as the native pgx interoperability adapter between Catalog Ent builders and River transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package pgxent

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	catalogent "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent"
)

var errLastInsertIDUnsupported = errors.New("pgxent: PostgreSQL does not support LastInsertId")

// Driver binds Ent operations to an already-open pgx transaction. Transaction
// ownership always remains with the caller.
type Driver struct {
	tx pgx.Tx
}

// NewDriver wraps a caller-owned native pgx transaction.
func NewDriver(tx pgx.Tx) (*Driver, error) {
	if tx == nil {
		return nil, errors.New("pgxent: transaction is required")
	}
	return &Driver{tx: tx}, nil
}

// NewClient creates a generated Catalog Ent client bound to tx.
func NewClient(tx pgx.Tx) (*catalogent.Client, error) {
	driver, err := NewDriver(tx)
	if err != nil {
		return nil, err
	}
	return catalogent.NewClient(catalogent.Driver(driver)), nil
}

// Dialect identifies this adapter as PostgreSQL.
func (*Driver) Dialect() string { return dialect.Postgres }

// Close is deliberately a no-op because the caller owns the transaction.
func (*Driver) Close() error { return nil }

// Tx returns a no-op Ent transaction wrapper over the same external pgx
// transaction. This supports Ent graph operations that request an internal
// transaction without allowing them to commit or roll back the outer one.
func (d *Driver) Tx(context.Context) (dialect.Tx, error) { return dialect.NopTx(d), nil }

// Exec implements dialect.ExecQuerier using pgx.Tx.
func (d *Driver) Exec(ctx context.Context, query string, args, v any) error {
	argv, ok := args.([]any)
	if !ok {
		return fmt.Errorf("pgxent: invalid args type %T; expected []any", args)
	}
	tag, err := d.tx.Exec(ctx, query, argv...)
	if err != nil {
		return err
	}
	switch output := v.(type) {
	case nil:
		return nil
	case *sql.Result:
		*output = result{tag: tag}
		return nil
	default:
		return fmt.Errorf("pgxent: invalid result type %T; expected *sql.Result", v)
	}
}

// Query implements dialect.ExecQuerier using pgx.Tx.
func (d *Driver) Query(ctx context.Context, query string, args, v any) error {
	argv, ok := args.([]any)
	if !ok {
		return fmt.Errorf("pgxent: invalid args type %T; expected []any", args)
	}
	output, ok := v.(*entsql.Rows)
	if !ok {
		return fmt.Errorf("pgxent: invalid rows type %T; expected *sql.Rows", v)
	}
	rows, err := d.tx.Query(ctx, query, argv...)
	if err != nil {
		return err
	}
	output.ColumnScanner = &rowScanner{rows: rows}
	return nil
}

type result struct {
	tag pgconn.CommandTag
}

func (result) LastInsertId() (int64, error)   { return 0, errLastInsertIDUnsupported }
func (r result) RowsAffected() (int64, error) { return r.tag.RowsAffected(), nil }

type rowScanner struct {
	rows pgx.Rows
}

func (r *rowScanner) Close() error {
	r.rows.Close()
	return nil
}

// ColumnTypes returns no database/sql metadata. Ent falls back to scanning
// dynamic expressions into any; generated entity fields use explicit targets.
func (*rowScanner) ColumnTypes() ([]*sql.ColumnType, error) { return nil, nil }

func (r *rowScanner) Columns() ([]string, error) {
	fields := r.rows.FieldDescriptions()
	columns := make([]string, len(fields))
	for i := range fields {
		columns[i] = fields[i].Name
	}
	return columns, nil
}

func (r *rowScanner) Err() error             { return r.rows.Err() }
func (r *rowScanner) Next() bool             { return r.rows.Next() }
func (*rowScanner) NextResultSet() bool      { return false }
func (r *rowScanner) Scan(dest ...any) error { return r.rows.Scan(dest...) }

var _ dialect.Driver = (*Driver)(nil)
var _ entsql.ColumnScanner = (*rowScanner)(nil)
var _ sql.Result = result{}
