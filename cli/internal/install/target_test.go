/*
 * [INPUT]: Depends on Agent Catalog path resolution and installation target scopes/modes.
 * [OUTPUT]: Specifies path-safe Skill-name validation plus canonical and projected target paths for project and user installations.
 * [POS]: Serves as target-path contract coverage for the installation module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"path/filepath"
	"testing"

	"github.com/skillsgo/skillsgo/cli/internal/agent"
	"github.com/stretchr/testify/require"
)

func TestResolveProjectAndUserTargets(t *testing.T) {
	home := t.TempDir()
	catalog := agent.NewCatalog(agent.Paths{Home: home, ConfigHome: filepath.Join(home, ".config")})

	projectTargets, err := ResolveTargets(catalog, []string{"codex", "claude-code"}, ScopeProject, ModeSymlink, "/workspace", "pdf")
	require.NoError(t, err)
	require.Equal(t, filepath.Join("/workspace", ".agents", "skills", "pdf"), projectTargets[0].Path)
	require.Equal(t, filepath.Join("/workspace", ".agents", "skills", "pdf"), projectTargets[0].CanonicalPath)
	require.Equal(t, filepath.Join("/workspace", ".claude", "skills", "pdf"), projectTargets[1].Path)
	require.Equal(t, filepath.Join("/workspace", ".agents", "skills", "pdf"), projectTargets[1].CanonicalPath)

	userTargets, err := ResolveTargets(catalog, []string{"codex"}, ScopeUser, ModeCopy, "/ignored", "pdf")
	require.NoError(t, err)
	require.Equal(t, filepath.Join(home, ".codex", "skills", "pdf"), userTargets[0].Path)
	require.Equal(t, filepath.Join(home, ".agents", "skills", "pdf"), userTargets[0].CanonicalPath)
	require.Equal(t, ModeCopy, userTargets[0].Mode)
}

func TestResolveEveSubagentTargets(t *testing.T) {
	catalog := agent.NewCatalog(agent.Paths{Home: t.TempDir(), ConfigHome: t.TempDir(), CWD: "/workspace"})
	targets, err := ResolveTargetsWithSubagents(catalog, []string{"eve"}, []string{"writer"}, ScopeProject, ModeCopy, "/workspace", "pdf")
	require.NoError(t, err)
	path := filepath.Join("/workspace", "agent", "subagents", "writer", "skills", "pdf")
	require.Equal(t, []Target{{Agent: "eve:writer", Scope: ScopeProject, Mode: ModeCopy, Path: path, CanonicalPath: path}}, targets)

	targets, err = ResolveTargetsWithSubagents(catalog, []string{"eve"}, []string{"root", "writer"}, ScopeProject, ModeCopy, "/workspace", "pdf")
	require.NoError(t, err)
	require.Len(t, targets, 2)
}

func TestResolveInjectedTestAgent(t *testing.T) {
	home, project := t.TempDir(), t.TempDir()
	catalog := agent.NewCatalog(
		agent.Paths{Home: home, ConfigHome: filepath.Join(home, ".config"), CWD: project},
		agent.WithDefinition(agent.Definition{ID: "test-agent", Display: "Test Agent", ProjectDir: ".test-agent/skills", UserDir: filepath.Join(home, ".test-agent", "skills")}),
	)
	projectTargets, err := ResolveTargets(catalog, []string{"test-agent"}, ScopeProject, ModeSymlink, project, "demo")
	require.NoError(t, err)
	require.Equal(t, filepath.Join(project, ".test-agent", "skills", "demo"), projectTargets[0].Path)
	userTargets, err := ResolveTargets(catalog, []string{"test-agent"}, ScopeUser, ModeCopy, project, "demo")
	require.NoError(t, err)
	require.Equal(t, filepath.Join(home, ".test-agent", "skills", "demo"), userTargets[0].Path)
}

func TestValidateSkillNameAllowsXAndZeroButRejectsPathCharacters(t *testing.T) {
	require.NoError(t, ValidateSkillName("project-existing-0x"))
	for _, name := range []string{"nested/demo", `nested\demo`, "nul\x00name", ".", ".."} {
		require.Error(t, ValidateSkillName(name), name)
	}
}
