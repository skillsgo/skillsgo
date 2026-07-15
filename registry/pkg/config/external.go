package config

// External specifies configuration for an external http storage.
type External struct {
	URL string `envconfig:"SKILLSGO_REGISTRY_EXTERNAL_STORAGE_URL" validate:"required"`
}
