package config

// MySQL config.
type MySQL struct {
	Protocol string            `envconfig:"SKILLSGO_REGISTRY_INDEX_MYSQL_PROTOCOL" validate:"required"`
	Host     string            `envconfig:"SKILLSGO_REGISTRY_INDEX_MYSQL_HOST"     validate:"required"`
	Port     int               `envconfig:"SKILLSGO_REGISTRY_INDEX_MYSQL_PORT"     validate:""`
	User     string            `envconfig:"SKILLSGO_REGISTRY_INDEX_MYSQL_USER"     validate:"required"`
	Password string            `envconfig:"SKILLSGO_REGISTRY_INDEX_MYSQL_PASSWORD" validate:""`
	Database string            `envconfig:"SKILLSGO_REGISTRY_INDEX_MYSQL_DATABASE" validate:"required"`
	Params   map[string]string `envconfig:"SKILLSGO_REGISTRY_INDEX_MYSQL_PARAMS"   validate:"required"`
}
