/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by database.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// DatabaseConfig configures the Hub catalog and search metadata database.
// Artifacts remain in Storage; this database only stores queryable metadata.
type DatabaseConfig struct {
	Type            string `envconfig:"SKILLSGO_HUB_DATABASE_TYPE" validate:"oneof=sqlite postgres"`
	DSN             string `envconfig:"SKILLSGO_HUB_DATABASE_DSN"`
	MaxOpenConns    int    `envconfig:"SKILLSGO_HUB_DATABASE_MAX_OPEN_CONNS" validate:"min=1"`
	MaxIdleConns    int    `envconfig:"SKILLSGO_HUB_DATABASE_MAX_IDLE_CONNS" validate:"min=0"`
	ConnMaxLifetime int    `envconfig:"SKILLSGO_HUB_DATABASE_CONN_MAX_LIFETIME" validate:"min=0"`
}
