package agent

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestCatalogMatchesSkillsSHAgentCount(t *testing.T) {
	catalog := NewCatalog(Paths{Home: "/home/user", ConfigHome: "/home/user/.config"})
	require.Len(t, catalog.All(), 73)
	codex, ok := catalog.Get("codex")
	require.True(t, ok)
	require.Equal(t, filepath.Join("/home/user", ".codex", "skills"), codex.UserDir)
	eve, ok := catalog.Get("eve")
	require.True(t, ok)
	require.Empty(t, eve.UserDir)
}

func TestSkillsSHSpecialDetectionRules(t *testing.T) {
	home, cwd, config := t.TempDir(), t.TempDir(), t.TempDir()
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".clawdbot"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(home, ".kimi"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(cwd, "agent", "subagents", "writer"), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Join(cwd, "agent", "subagents", "reviewer"), 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(cwd, "package.json"), []byte(`{"devDependencies":{"eve":"1.0.0"}}`), 0o644))
	catalog := NewCatalog(Paths{Home: home, ConfigHome: config, CWD: cwd})
	require.True(t, catalog.DetectInstalled("openclaw"))
	require.True(t, catalog.DetectInstalled("kimi-code-cli"))
	require.True(t, catalog.DetectInstalled("eve"))
	require.False(t, catalog.DetectInstalled("universal"))
	openclaw, ok := catalog.Get("openclaw")
	require.True(t, ok)
	require.Equal(t, filepath.Join(home, ".clawdbot", "skills"), openclaw.UserDir)
	require.Equal(t, []string{"reviewer", "writer"}, EveSubagents(cwd))
}

func TestSkillsSHUniversalVisibility(t *testing.T) {
	catalog := NewCatalog(Paths{Home: "/home/user", ConfigHome: "/home/user/.config", CWD: "/project"})
	all, visible := catalog.Universal(false), catalog.Universal(true)
	require.NotEmpty(t, all)
	require.Less(t, len(visible), len(all))
	for _, definition := range all {
		require.NotEqual(t, "replit", definition.ID)
		require.NotEqual(t, "universal", definition.ID)
	}
}

func TestCatalogAcceptsIsolatedTestAgent(t *testing.T) {
	home := t.TempDir()
	testAgent := Definition{ID: "test-agent", Display: "Test Agent", ProjectDir: ".test-agent/skills", UserDir: filepath.Join(home, ".test-agent", "skills"), ShowInUniversalList: true, ShowInUniversalPrompt: true}
	catalog := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")}, WithDefinition(testAgent))
	got, ok := catalog.Get("test-agent")
	require.True(t, ok)
	require.Equal(t, testAgent, got)
	require.Len(t, catalog.All(), 74)

	official := NewCatalog(Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})
	_, ok = official.Get("test-agent")
	require.False(t, ok)
	require.Len(t, official.All(), 73)
}
