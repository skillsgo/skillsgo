package config

import (
	"fmt"
	"os"
	"os/user"
	"path/filepath"
)

const (
	skillsGoHomeEnv          = "SKILLSGO_HOME"
	registryHomeEnv          = "SKILLSGO_REGISTRY_HOME"
	registryCacheDirEnv      = "SKILLSGO_REGISTRY_CACHE_DIR"
	defaultSkillsGoDirectory = ".skillsgo"
)

func resolveRegistryDatabaseDSN(databaseType, configured string) (string, error) {
	if configured != "" || databaseType == "postgres" {
		return configured, nil
	}
	var root string
	if value := os.Getenv(registryHomeEnv); value != "" {
		root = value
	} else if value := os.Getenv(skillsGoHomeEnv); value != "" {
		root = filepath.Join(value, "registry")
	} else {
		home, err := userHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolve SkillsGo home directory: %w", err)
		}
		root = filepath.Join(home, defaultSkillsGoDirectory, "registry")
	}
	return filepath.Join(root, "metadata", "registry.db"), nil
}

// resolveRegistryCacheDir applies the Registry directory precedence without
// creating directories. A configured value comes from TOML.
func resolveRegistryCacheDir(configured string) (string, error) {
	if value := os.Getenv(registryCacheDirEnv); value != "" {
		return filepath.Clean(value), nil
	}
	if configured != "" {
		return filepath.Clean(configured), nil
	}
	if value := os.Getenv(registryHomeEnv); value != "" {
		return filepath.Join(value, "cache"), nil
	}
	if value := os.Getenv(skillsGoHomeEnv); value != "" {
		return filepath.Join(value, "registry", "cache"), nil
	}
	home, err := userHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolve SkillsGo home directory: %w", err)
	}
	return filepath.Join(home, defaultSkillsGoDirectory, "registry", "cache"), nil
}

// resolveRegistryArtifactDir returns the persistent artifact storage directory.
// An explicitly configured disk root (including the environment override applied
// by envconfig) wins over the standard SkillsGo home layout.
func resolveRegistryArtifactDir(configured string) (string, error) {
	if configured != "" {
		return filepath.Clean(configured), nil
	}
	if value := os.Getenv(registryHomeEnv); value != "" {
		return filepath.Join(value, "storage", "artifacts"), nil
	}
	if value := os.Getenv(skillsGoHomeEnv); value != "" {
		return filepath.Join(value, "registry", "storage", "artifacts"), nil
	}
	home, err := userHomeDir()
	if err != nil {
		return "", fmt.Errorf("resolve SkillsGo home directory: %w", err)
	}
	return filepath.Join(home, defaultSkillsGoDirectory, "registry", "storage", "artifacts"), nil
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
