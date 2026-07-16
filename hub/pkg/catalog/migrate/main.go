//go:build ignore

/*
 * [INPUT]: Depends on a disposable Atlas development database, generated Ent migration metadata, and the dialect migration directory.
 * [OUTPUT]: Provides a developer command that writes a named, versioned schema diff and refreshes atlas.sum.
 * [POS]: Serves as the reviewed migration-authoring entry point for the Hub Catalog module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"path/filepath"

	"ariga.io/atlas/sql/migrate"
	"entgo.io/ent/dialect"
	"entgo.io/ent/dialect/sql/schema"
	entmigrate "github.com/skillsgo/skillsgo/hub/pkg/catalog/ent/migrate"
)

func main() {
	var databaseDialect, devURL, name string
	flag.StringVar(&databaseDialect, "dialect", "", "target dialect: sqlite or postgres")
	flag.StringVar(&devURL, "dev-url", "", "Atlas URL for a disposable development database")
	flag.StringVar(&name, "name", "", "short migration description")
	flag.Parse()
	if devURL == "" || name == "" {
		log.Fatal("-dev-url and -name are required")
	}
	var entDialect string
	switch databaseDialect {
	case "sqlite":
		entDialect = dialect.SQLite
	case "postgres":
		entDialect = dialect.Postgres
	default:
		log.Fatalf("unsupported dialect %q", databaseDialect)
	}
	dir, err := migrate.NewLocalDir(filepath.Join("pkg", "catalog", "migrations", databaseDialect))
	if err != nil {
		log.Fatal(err)
	}
	opts := []schema.MigrateOption{
		schema.WithDir(dir),
		schema.WithMigrationMode(schema.ModeReplay),
		schema.WithDialect(entDialect),
	}
	if err := entmigrate.NamedDiff(context.Background(), devURL, name, opts...); err != nil {
		log.Fatal(fmt.Errorf("generate %s catalog migration: %w", databaseDialect, err))
	}
}
