package config

// DatabaseConfig configures the Registry catalog and search metadata database.
// Artifacts remain in Storage; this database only stores queryable metadata.
type DatabaseConfig struct {
	Type            string `envconfig:"SKILLSGO_REGISTRY_DATABASE_TYPE" validate:"oneof=sqlite postgres"`
	DSN             string `envconfig:"SKILLSGO_REGISTRY_DATABASE_DSN"`
	MaxOpenConns    int    `envconfig:"SKILLSGO_REGISTRY_DATABASE_MAX_OPEN_CONNS" validate:"min=1"`
	MaxIdleConns    int    `envconfig:"SKILLSGO_REGISTRY_DATABASE_MAX_IDLE_CONNS" validate:"min=0"`
	ConnMaxLifetime int    `envconfig:"SKILLSGO_REGISTRY_DATABASE_CONN_MAX_LIFETIME" validate:"min=0"`
}
