/*
 * [INPUT]: Depends on embedded PostgreSQL Atlas SQL files, Atlas statement parsing, the Catalog pgx pool, and configured PostgreSQL business and extension schemas.
 * [OUTPUT]: Provides schema and extension prerequisite validation plus ordered, checksummed, transactional migration with per-schema revision history and PostgreSQL serialization.
 * [POS]: Serves as the production schema-evolution boundary for the Hub Catalog module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package catalog

import (
	"context"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"sort"
	"strings"

	atlasmigrate "ariga.io/atlas/sql/migrate"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
)

// migrationFiles are reviewed PostgreSQL deployment artifacts generated and
// linted through Atlas's declarative migration workflow.
//
//go:embed migrations/postgres/*.sql migrations/postgres/atlas.sum
var migrationFiles embed.FS

func (c *Catalog) Migrate(ctx context.Context) error {
	extensionSchema := pgx.Identifier{c.extensionSchema()}.Sanitize()
	if _, err := c.pool.Exec(ctx, `CREATE SCHEMA IF NOT EXISTS `+extensionSchema); err != nil {
		return fmt.Errorf("initialize catalog PostgreSQL extension schema: %w", err)
	}
	if _, err := c.pool.Exec(ctx, `CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA `+extensionSchema); err != nil {
		return fmt.Errorf("initialize catalog PostgreSQL extensions: %w", err)
	}
	var installedSchema string
	if err := c.pool.QueryRow(ctx, `SELECT extnamespace::regnamespace::text FROM pg_extension WHERE extname = 'pg_trgm'`).Scan(&installedSchema); err != nil {
		return fmt.Errorf("inspect catalog PostgreSQL extensions: %w", err)
	}
	if installedSchema != c.extensionSchema() {
		return fmt.Errorf("pg_trgm must be installed in schema %q, found %q", c.extensionSchema(), installedSchema)
	}
	dir := "migrations/postgres"
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
		return fmt.Errorf("no catalog PostgreSQL migrations")
	}
	conn, err := c.pool.Acquire(ctx)
	if err != nil {
		return fmt.Errorf("reserve catalog migration connection: %w", err)
	}
	defer conn.Release()
	schema := c.schema
	if schema == "" {
		if err := conn.QueryRow(ctx, `SELECT current_schema()`).Scan(&schema); err != nil {
			return fmt.Errorf("resolve catalog migration schema: %w", err)
		}
	}
	searchPath := databaseSearchPath(schema, c.extensionSchema())
	if _, err := conn.Exec(ctx, `SELECT set_config('search_path', $1, false)`, searchPath); err != nil {
		return fmt.Errorf("bind catalog migration schema: %w", err)
	}
	revisions := pgx.Identifier{schema, "atlas_schema_revisions"}.Sanitize()
	if _, err := conn.Exec(ctx, `CREATE TABLE IF NOT EXISTS `+revisions+` (
version TEXT PRIMARY KEY, description TEXT NOT NULL, checksum TEXT NOT NULL, applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)`); err != nil {
		return fmt.Errorf("initialize catalog migration history: %w", err)
	}
	if _, err := conn.Exec(ctx, `SELECT pg_advisory_lock(721946031)`); err != nil {
		return fmt.Errorf("lock catalog migrations: %w", err)
	}
	defer func() { _, _ = conn.Exec(context.Background(), `SELECT pg_advisory_unlock(721946031)`) }()
	for _, name := range names {
		if err := c.applyMigration(ctx, conn, revisions, name); err != nil {
			return err
		}
	}
	return nil
}

func (c *Catalog) extensionSchema() string {
	// Catalogs constructed directly by package tests retain the self-host default.
	if c.extensionSchemaName == "" {
		return config.DefaultDatabaseSchema
	}
	return c.extensionSchemaName
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

func (c *Catalog) applyMigration(ctx context.Context, conn *pgxpool.Conn, revisions, name string) error {
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
	err = conn.QueryRow(ctx, `SELECT checksum FROM `+revisions+` WHERE version = $1`, version).Scan(&recorded)
	if err == nil {
		if recorded != checksum {
			return fmt.Errorf("catalog migration %s checksum changed after application", version)
		}
		return nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("read catalog migration %s revision: %w", version, err)
	}
	tx, err := conn.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin catalog migration %s: %w", version, err)
	}
	defer func() { _ = tx.Rollback(context.Background()) }()
	statements, err := atlasmigrate.NewLocalFile(base, data).Stmts()
	if err != nil {
		return fmt.Errorf("parse catalog migration %s: %w", version, err)
	}
	for _, statement := range statements {
		if _, err := tx.Exec(ctx, statement); err != nil {
			return fmt.Errorf("apply catalog migration %s: %w", version, err)
		}
	}
	_, err = tx.Exec(ctx, `INSERT INTO `+revisions+` (version, description, checksum) VALUES ($1, $2, $3)`, version, description, checksum)
	if err != nil {
		return fmt.Errorf("record catalog migration %s: %w", version, err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit catalog migration %s: %w", version, err)
	}
	return nil
}
