/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by mysql.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// MySQL config.
type MySQL struct {
	Protocol string            `envconfig:"SKILLSGO_HUB_INDEX_MYSQL_PROTOCOL" validate:"required"`
	Host     string            `envconfig:"SKILLSGO_HUB_INDEX_MYSQL_HOST"     validate:"required"`
	Port     int               `envconfig:"SKILLSGO_HUB_INDEX_MYSQL_PORT"     validate:""`
	User     string            `envconfig:"SKILLSGO_HUB_INDEX_MYSQL_USER"     validate:"required"`
	Password string            `envconfig:"SKILLSGO_HUB_INDEX_MYSQL_PASSWORD" validate:""`
	Database string            `envconfig:"SKILLSGO_HUB_INDEX_MYSQL_DATABASE" validate:"required"`
	Params   map[string]string `envconfig:"SKILLSGO_HUB_INDEX_MYSQL_PARAMS"   validate:"required"`
}
