/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by gcp.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// GCPConfig specifies the properties required to use GCP as the storage backend.
type GCPConfig struct {
	ProjectID string `envconfig:"GOOGLE_CLOUD_PROJECT"`
	Bucket    string `envconfig:"SKILLSGO_HUB_STORAGE_GCP_BUCKET"   validate:"required"`
	JSONKey   string `envconfig:"SKILLSGO_HUB_STORAGE_GCP_JSON_KEY"`
}
