package config

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestResolveRegistryCacheDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	tests := []struct {
		name       string
		configured string
		env        map[string]string
		want       string
	}{
		{name: "user home default", want: filepath.Join(home, ".skillsgo", "registry", "cache")},
		{name: "SkillsGo home", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo"}, want: "/data/skillsgo/registry/cache"},
		{name: "Registry home", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo", registryHomeEnv: "/srv/registry"}, want: "/srv/registry/cache"},
		{name: "configured cache", configured: "/configured/cache", env: map[string]string{registryHomeEnv: "/srv/registry"}, want: "/configured/cache"},
		{name: "specific environment wins", configured: "/configured/cache", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo", registryHomeEnv: "/srv/registry", registryCacheDirEnv: "/fast/cache"}, want: "/fast/cache"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv(skillsGoHomeEnv, "")
			t.Setenv(registryHomeEnv, "")
			t.Setenv(registryCacheDirEnv, "")
			for key, value := range tc.env {
				t.Setenv(key, value)
			}
			got, err := resolveRegistryCacheDir(tc.configured)
			require.NoError(t, err)
			require.Equal(t, filepath.Clean(tc.want), got)
		})
	}
}

func TestResolveRegistryDatabaseDSN(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv(skillsGoHomeEnv, "")
	t.Setenv(registryHomeEnv, "")

	got, err := resolveRegistryDatabaseDSN("sqlite", "")
	require.NoError(t, err)
	require.Equal(t, filepath.Join(home, ".skillsgo", "registry", "metadata", "registry.db"), got)

	got, err = resolveRegistryDatabaseDSN("postgres", "postgres://registry")
	require.NoError(t, err)
	require.Equal(t, "postgres://registry", got)
}

func TestResolveRegistryArtifactDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	tests := []struct {
		name       string
		configured string
		env        map[string]string
		want       string
	}{
		{name: "user home default", want: filepath.Join(home, ".skillsgo", "registry", "storage", "artifacts")},
		{name: "SkillsGo home", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo"}, want: "/data/skillsgo/registry/storage/artifacts"},
		{name: "Registry home", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo", registryHomeEnv: "/srv/registry"}, want: "/srv/registry/storage/artifacts"},
		{name: "configured disk root wins", configured: "/configured/artifacts", env: map[string]string{registryHomeEnv: "/srv/registry"}, want: "/configured/artifacts"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv(skillsGoHomeEnv, "")
			t.Setenv(registryHomeEnv, "")
			for key, value := range tc.env {
				t.Setenv(key, value)
			}
			got, err := resolveRegistryArtifactDir(tc.configured)
			require.NoError(t, err)
			require.Equal(t, filepath.Clean(tc.want), got)
		})
	}
}

func TestDefaultConfigUsesPersistentArtifactStorage(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv(skillsGoHomeEnv, "")
	t.Setenv(registryHomeEnv, "")
	conf := defaultConfig()
	require.NoError(t, envOverride(conf))
	require.Equal(t, "disk", conf.StorageType)
	require.NotNil(t, conf.Storage)
	require.NotNil(t, conf.Storage.Disk)
	require.Equal(
		t,
		filepath.Join(home, ".skillsgo", "registry", "storage", "artifacts"),
		conf.Storage.Disk.RootPath,
	)
}

func TestNonCanonicalCacheEnvironmentIsIgnored(t *testing.T) {
	t.Setenv("SKILLSGO_REGISTRY_SKILL_CACHE_DIR", "/wrong/cache")
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv(registryCacheDirEnv, "")

	conf := &Config{}
	require.NoError(t, envOverride(conf))
	require.Equal(t, filepath.Join(home, ".skillsgo", "registry", "cache"), conf.SkillCacheDir)
}
