/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by disk.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

// DiskConfig specifies the properties required to use Disk as the storage backend.
type DiskConfig struct {
	RootPath string `envconfig:"SKILLSGO_HUB_DISK_STORAGE_ROOT" validate:"required"`
}
