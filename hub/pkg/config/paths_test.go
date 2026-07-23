/*
 * [INPUT]: Depends on the config package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the config package behavior covered by paths_test.go.
 * [POS]: Serves as test coverage for the config package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestResolveHubCacheDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	tests := []struct {
		name       string
		configured string
		env        map[string]string
		want       string
	}{
		{name: "user home default", want: filepath.Join(home, ".skillsgo", "hub", "cache")},
		{name: "SkillsGo home", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo"}, want: "/data/skillsgo/hub/cache"},
		{name: "Hub home", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo", hubHomeEnv: "/srv/hub"}, want: "/srv/hub/cache"},
		{name: "configured cache", configured: "/configured/cache", env: map[string]string{hubHomeEnv: "/srv/hub"}, want: "/configured/cache"},
		{name: "specific environment wins", configured: "/configured/cache", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo", hubHomeEnv: "/srv/hub", hubCacheDirEnv: "/fast/cache"}, want: "/fast/cache"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv(skillsGoHomeEnv, "")
			t.Setenv(hubHomeEnv, "")
			t.Setenv(hubCacheDirEnv, "")
			for key, value := range tc.env {
				t.Setenv(key, value)
			}
			got, err := resolveHubCacheDir(tc.configured)
			require.NoError(t, err)
			require.Equal(t, filepath.Clean(tc.want), got)
		})
	}
}

func TestResolveHubDatabaseDSN(t *testing.T) {
	got, err := resolveHubDatabaseDSN("postgres", "postgres://hub")
	require.NoError(t, err)
	require.Equal(t, "postgres://hub", got)
	_, err = resolveHubDatabaseDSN("sqlite", "ignored")
	require.ErrorContains(t, err, "only postgres")
}

func TestResolveHubArtifactDir(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	tests := []struct {
		name       string
		configured string
		env        map[string]string
		want       string
	}{
		{name: "user home default", want: filepath.Join(home, ".skillsgo", "hub", "storage", "artifacts")},
		{name: "SkillsGo home", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo"}, want: "/data/skillsgo/hub/storage/artifacts"},
		{name: "Hub home", env: map[string]string{skillsGoHomeEnv: "/data/skillsgo", hubHomeEnv: "/srv/hub"}, want: "/srv/hub/storage/artifacts"},
		{name: "configured disk root wins", configured: "/configured/artifacts", env: map[string]string{hubHomeEnv: "/srv/hub"}, want: "/configured/artifacts"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv(skillsGoHomeEnv, "")
			t.Setenv(hubHomeEnv, "")
			for key, value := range tc.env {
				t.Setenv(key, value)
			}
			got, err := resolveHubArtifactDir(tc.configured)
			require.NoError(t, err)
			require.Equal(t, filepath.Clean(tc.want), got)
		})
	}
}

func TestDefaultConfigUsesPersistentArtifactStorage(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv(skillsGoHomeEnv, "")
	t.Setenv(hubHomeEnv, "")
	conf := defaultConfig()
	require.NoError(t, envOverride(conf))
	require.Equal(t, "disk", conf.StorageType)
	require.NotNil(t, conf.Storage)
	require.NotNil(t, conf.Storage.Disk)
	require.Equal(
		t,
		filepath.Join(home, ".skillsgo", "hub", "storage", "artifacts"),
		conf.Storage.Disk.RootPath,
	)
}

func TestNonCanonicalCacheEnvironmentIsIgnored(t *testing.T) {
	t.Setenv("SKILLSGO_HUB_SKILL_CACHE_DIR", "/wrong/cache")
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv(hubCacheDirEnv, "")

	conf := &Config{}
	require.NoError(t, envOverride(conf))
	require.Equal(t, filepath.Join(home, ".skillsgo", "hub", "cache"), conf.SkillCacheDir)
}
