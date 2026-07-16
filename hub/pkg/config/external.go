/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by external.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// External specifies configuration for an external http storage.
type External struct {
	URL string `envconfig:"SKILLSGO_HUB_EXTERNAL_STORAGE_URL" validate:"required"`
}
