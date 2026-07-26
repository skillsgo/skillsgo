/*
 * [INPUT]: Depends on strict PostgreSQL identifier rules and Hub database environment configuration.
 * [OUTPUT]: Provides validated PostgreSQL-only Hub catalog configuration with one process-fixed schema defaulting to public.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import "regexp"

const DefaultDatabaseSchema = "public"

var databaseSchemaPattern = regexp.MustCompile(`^[a-z_][a-z0-9_]{0,62}$`)

// DatabaseConfig configures the Hub catalog and search metadata database.
// Artifacts remain in Storage; this database only stores queryable metadata.
type DatabaseConfig struct {
	Type            string `envconfig:"SKILLSGO_HUB_DATABASE_TYPE" validate:"eq=postgres"`
	DSN             string `envconfig:"SKILLSGO_HUB_DATABASE_DSN"`
	Schema          string `envconfig:"SKILLSGO_HUB_DATABASE_SCHEMA"`
	MaxOpenConns    int    `envconfig:"SKILLSGO_HUB_DATABASE_MAX_OPEN_CONNS" validate:"min=1"`
	MaxIdleConns    int    `envconfig:"SKILLSGO_HUB_DATABASE_MAX_IDLE_CONNS" validate:"min=0"`
	ConnMaxLifetime int    `envconfig:"SKILLSGO_HUB_DATABASE_CONN_MAX_LIFETIME" validate:"min=0"`
}

func ValidDatabaseSchema(schema string) bool {
	return databaseSchemaPattern.MatchString(schema)
}
