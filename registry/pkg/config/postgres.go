package config

// Postgres config.
type Postgres struct {
	Host     string            `envconfig:"SKILLSGO_REGISTRY_INDEX_POSTGRES_HOST"     validate:"required"`
	Port     int               `envconfig:"SKILLSGO_REGISTRY_INDEX_POSTGRES_PORT"     validate:"required"`
	User     string            `envconfig:"SKILLSGO_REGISTRY_INDEX_POSTGRES_USER"     validate:"required"`
	Password string            `envconfig:"SKILLSGO_REGISTRY_INDEX_POSTGRES_PASSWORD" validate:""`
	Database string            `envconfig:"SKILLSGO_REGISTRY_INDEX_POSTGRES_DATABASE" validate:"required"`
	Params   map[string]string `envconfig:"SKILLSGO_REGISTRY_INDEX_POSTGRES_PARAMS"   validate:"required"`
}
