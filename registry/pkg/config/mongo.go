package config

// MongoConfig specifies the properties required to use MongoDB as the storage backend.
type MongoConfig struct {
	URL                   string `envconfig:"SKILLSGO_REGISTRY_MONGO_STORAGE_URL" validate:"required"`
	DefaultDBName         string `default:"athens"                     envconfig:"SKILLSGO_REGISTRY_MONGO_DEFAULT_DATABASE"`
	DefaultCollectionName string `default:"skills"                     envconfig:"SKILLSGO_REGISTRY_MONGO_DEFAULT_COLLECTION"`
	CertPath              string `envconfig:"SKILLSGO_REGISTRY_MONGO_CERT_PATH"`
	InsecureConn          bool   `envconfig:"SKILLSGO_REGISTRY_MONGO_INSECURE"`
}
