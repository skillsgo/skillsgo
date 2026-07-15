package config

// MinioConfig specifies the properties required to use Minio or DigitalOcean Spaces
// as the storage backend.
type MinioConfig struct {
	Endpoint  string `envconfig:"SKILLSGO_REGISTRY_MINIO_ENDPOINT"          validate:"required"`
	Key       string `envconfig:"SKILLSGO_REGISTRY_MINIO_ACCESS_KEY_ID"     validate:"required"`
	Secret    string `envconfig:"SKILLSGO_REGISTRY_MINIO_SECRET_ACCESS_KEY" validate:"required"`
	Bucket    string `envconfig:"SKILLSGO_REGISTRY_MINIO_BUCKET_NAME"       validate:"required"`
	Region    string `envconfig:"SKILLSGO_REGISTRY_MINIO_REGION"`
	EnableSSL bool   `envconfig:"SKILLSGO_REGISTRY_MINIO_USE_SSL"`
}
