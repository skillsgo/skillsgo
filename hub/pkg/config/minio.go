/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by minio.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// MinioConfig specifies the properties required to use Minio or DigitalOcean Spaces
// as the storage backend.
type MinioConfig struct {
	Endpoint  string `envconfig:"SKILLSGO_HUB_MINIO_ENDPOINT"          validate:"required"`
	Key       string `envconfig:"SKILLSGO_HUB_MINIO_ACCESS_KEY_ID"     validate:"required"`
	Secret    string `envconfig:"SKILLSGO_HUB_MINIO_SECRET_ACCESS_KEY" validate:"required"`
	Bucket    string `envconfig:"SKILLSGO_HUB_MINIO_BUCKET_NAME"       validate:"required"`
	Region    string `envconfig:"SKILLSGO_HUB_MINIO_REGION"`
	EnableSSL bool   `envconfig:"SKILLSGO_HUB_MINIO_USE_SSL"`
}
