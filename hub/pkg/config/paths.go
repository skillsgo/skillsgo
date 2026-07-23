/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Provides the config package behavior implemented by paths.go.
 * [POS]: Serves as maintained source in the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import (
	"fmt"
	"os"
	"os/user"
	"path/filepath"
)

const (
	skillsGoHomeEnv          = "SKILLSGO_HOME"
	hubHomeEnv               = "SKILLSGO_HUB_HOME"
	hubCacheDirEnv           = "SKILLSGO_HUB_CACHE_DIR"
	defaultSkillsGoDirectory = ".skillsgo"
)

func resolveHubDatabaseDSN(databaseType, configured string) (string, error) {
	if databaseType != "postgres" {
		return "", fmt.Errorf("unsupported Hub database type %q; only postgres is supported", databaseType)
	}
	return configured, nil
}

// resolveHubCacheDir applies the Hub directory precedence without
// creating directories. A configured value comes from TOML.
func resolveHubCacheDir(configured string) (string, error) {
	if value := os.Getenv(hubCacheDirEnv); value != "" {
		return filepath.Clean(value), nil
	}
	if configured != "" {
		return filepath.Clean(configured), nil
	}
	if value := os.Getenv(hubHomeEnv); value != "" {
		return filepath.Join(value, "cache"), nil
	}
	if value := os.Getenv(skillsGoHomeEnv); value != "" {
		return filepath.Join(value, "hub", "cache"), nil
	}
	home, err := userHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolve SkillsGo home directory: %w", err)
	}
	return filepath.Join(home, defaultSkillsGoDirectory, "hub", "cache"), nil
}

// resolveHubArtifactDir returns the persistent artifact storage directory.
// An explicitly configured disk root (including the environment override applied
// by envconfig) wins over the standard SkillsGo home layout.
func resolveHubArtifactDir(configured string) (string, error) {
	if configured != "" {
		return filepath.Clean(configured), nil
	}
	if value := os.Getenv(hubHomeEnv); value != "" {
		return filepath.Join(value, "storage", "artifacts"), nil
	}
	if value := os.Getenv(skillsGoHomeEnv); value != "" {
		return filepath.Join(value, "hub", "storage", "artifacts"), nil
	}
	home, err := userHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolve SkillsGo home directory: %w", err)
	}
	return filepath.Join(home, defaultSkillsGoDirectory, "hub", "storage", "artifacts"), nil
}

func userHomeDir() (string, error) {
	home, err := os.UserHomeDir()
	if err == nil && home != "" {
		return home, nil
	}
	current, currentErr := user.Current()
	if currentErr != nil || current.HomeDir == "" {
		return "", err
	}
	return current.HomeDir, nil
}
