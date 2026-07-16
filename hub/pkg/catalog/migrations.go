/*
 * [INPUT]: Depends on embedded dialect-specific Atlas SQL files, Atlas statement parsing, and the Catalog SQL connection.
 * [OUTPUT]: Provides ordered, checksummed, transactional schema migration with persistent revision history and PostgreSQL serialization.
 * [POS]: Serves as the production schema-evolution boundary for the Hub Catalog module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"embed"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"strings"

	atlasmigrate "ariga.io/atlas/sql/migrate"
)

// migrationFiles are reviewed deployment artifacts. Ent/Atlas generates future
// structural diffs; database-specific search features remain explicit SQL.
//
//go:embed migrations/sqlite/*.sql migrations/sqlite/atlas.sum migrations/postgres/*.sql migrations/postgres/atlas.sum
var migrationFiles embed.FS

func (c *Catalog) Migrate(ctx context.Context) error {
	dir := "migrations/" + string(c.dialect)
	sub, err := fs.Sub(migrationFiles, dir)
	if err != nil {
		return fmt.Errorf("open catalog migration directory: %w", err)
	}
	if err := atlasmigrate.Validate(readOnlyMigrationDir{FS: sub}); err != nil {
		return fmt.Errorf("validate catalog migration directory: %w", err)
	}
	names, err := fs.Glob(migrationFiles, dir+"/*.sql")
	if err != nil {
		return fmt.Errorf("list catalog migrations: %w", err)
	}
	sort.Strings(names)
	if len(names) == 0 {
		return fmt.Errorf("no catalog migrations for %s", c.dialect)
	}
	if _, err := c.db.ExecContext(ctx, `CREATE TABLE IF NOT EXISTS atlas_schema_revisions (
version TEXT PRIMARY KEY, description TEXT NOT NULL, checksum TEXT NOT NULL, applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)`); err != nil {
		return fmt.Errorf("initialize catalog migration history: %w", err)
	}
	if c.dialect == Postgres {
		conn, err := c.db.Connx(ctx)
		if err != nil {
			return fmt.Errorf("reserve catalog migration connection: %w", err)
		}
		defer func() { _ = conn.Close() }()
		if _, err := conn.ExecContext(ctx, `SELECT pg_advisory_lock(721946031)`); err != nil {
			return fmt.Errorf("lock catalog migrations: %w", err)
		}
		defer func() { _, _ = conn.ExecContext(context.Background(), `SELECT pg_advisory_unlock(721946031)`) }()
	}
	for _, name := range names {
		if err := c.applyMigration(ctx, name); err != nil {
			return err
		}
	}
	return nil
}

type readOnlyMigrationDir struct{ fs.FS }

func (readOnlyMigrationDir) WriteFile(string, []byte) error {
	return errors.New("embedded catalog migration directory is read-only")
}

func (d readOnlyMigrationDir) Files() ([]atlasmigrate.File, error) {
	names, err := fs.Glob(d.FS, "*.sql")
	if err != nil {
		return nil, err
	}
	sort.Strings(names)
	files := make([]atlasmigrate.File, 0, len(names))
	for _, name := range names {
		data, err := fs.ReadFile(d.FS, name)
		if err != nil {
			return nil, err
		}
		files = append(files, atlasmigrate.NewLocalFile(name, data))
	}
	return files, nil
}

func (d readOnlyMigrationDir) Checksum() (atlasmigrate.HashFile, error) {
	files, err := d.Files()
	if err != nil {
		return nil, err
	}
	return atlasmigrate.NewHashFile(files)
}

func (c *Catalog) applyMigration(ctx context.Context, name string) error {
	data, err := migrationFiles.ReadFile(name)
	if err != nil {
		return fmt.Errorf("read catalog migration %s: %w", name, err)
	}
	base := name[strings.LastIndex(name, "/")+1:]
	version, description, ok := strings.Cut(strings.TrimSuffix(base, ".sql"), "_")
	if !ok || version == "" || description == "" {
		return fmt.Errorf("invalid catalog migration name %q", base)
	}
	digest := sha256.Sum256(data)
	checksum := hex.EncodeToString(digest[:])
	var recorded string
	err = c.db.GetContext(ctx, &recorded, c.db.Rebind(`SELECT checksum FROM atlas_schema_revisions WHERE version = ?`), version)
	if err == nil {
		if recorded != checksum {
			return fmt.Errorf("catalog migration %s checksum changed after application", version)
		}
		return nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return fmt.Errorf("read catalog migration %s revision: %w", version, err)
	}
	tx, err := c.db.BeginTxx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin catalog migration %s: %w", version, err)
	}
	defer func() { _ = tx.Rollback() }()
	statements, err := atlasmigrate.NewLocalFile(base, data).Stmts()
	if err != nil {
		return fmt.Errorf("parse catalog migration %s: %w", version, err)
	}
	for _, statement := range statements {
		if _, err := tx.ExecContext(ctx, statement); err != nil {
			return fmt.Errorf("apply catalog migration %s: %w", version, err)
		}
	}
	_, err = tx.ExecContext(ctx, c.db.Rebind(`INSERT INTO atlas_schema_revisions (version, description, checksum) VALUES (?, ?, ?)`), version, description, checksum)
	if err != nil {
		return fmt.Errorf("record catalog migration %s: %w", version, err)
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit catalog migration %s: %w", version, err)
	}
	return nil
}
