/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by postgres.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// Postgres config.
type Postgres struct {
	Host     string            `envconfig:"SKILLSGO_HUB_INDEX_POSTGRES_HOST"     validate:"required"`
	Port     int               `envconfig:"SKILLSGO_HUB_INDEX_POSTGRES_PORT"     validate:"required"`
	User     string            `envconfig:"SKILLSGO_HUB_INDEX_POSTGRES_USER"     validate:"required"`
	Password string            `envconfig:"SKILLSGO_HUB_INDEX_POSTGRES_PASSWORD" validate:""`
	Database string            `envconfig:"SKILLSGO_HUB_INDEX_POSTGRES_DATABASE" validate:"required"`
	Params   map[string]string `envconfig:"SKILLSGO_HUB_INDEX_POSTGRES_PARAMS"   validate:"required"`
}
