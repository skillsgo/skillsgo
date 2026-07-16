/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by mongo.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// MongoConfig specifies the properties required to use MongoDB as the storage backend.
type MongoConfig struct {
	URL                   string `envconfig:"SKILLSGO_HUB_MONGO_STORAGE_URL" validate:"required"`
	DefaultDBName         string `default:"athens"                     envconfig:"SKILLSGO_HUB_MONGO_DEFAULT_DATABASE"`
	DefaultCollectionName string `default:"skills"                     envconfig:"SKILLSGO_HUB_MONGO_DEFAULT_COLLECTION"`
	CertPath              string `envconfig:"SKILLSGO_HUB_MONGO_CERT_PATH"`
	InsecureConn          bool   `envconfig:"SKILLSGO_HUB_MONGO_INSECURE"`
}
