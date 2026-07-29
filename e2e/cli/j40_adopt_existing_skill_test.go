/*
 * [INPUT]: Depends on the released CLI, a skills.sh-style Global canonical Skill directory, relative Agent symlinks, and the fixture Hub Package.
 * [OUTPUT]: Verifies current stdin JSON adoption replaces the complete skills.sh topology with ordinary Global managed state.
 * [POS]: Serves as the successful skills.sh Global adoption user journey in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ40AdoptSkillsShGlobalCanonicalDirectoryAndAgentSymlinks(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	home := filepath.Join(sandboxRoot, "home")
	canonical := filepath.Join(home, ".agents", "skills", "alpha")
	claude := filepath.Join(home, ".claude", "skills", "alpha")
	codex := filepath.Join(home, ".codex", "skills", "alpha")
	skillBytes := []byte("---\nname: alpha\ndescription: Alpha at v1.\n---\n# alpha\n")
	require.NoError(t, os.MkdirAll(canonical, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(canonical, "SKILL.md"), skillBytes, 0o644))
	for _, link := range []string{claude, codex} {
		require.NoError(t, os.MkdirAll(filepath.Dir(link), 0o755))
		relative, err := filepath.Rel(filepath.Dir(link), canonical)
		require.NoError(t, err)
		require.NoError(t, os.Symlink(relative, link))
	}

	report := executeAdoption(t, ctx, container, sandboxRoot, adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{fixtureAdoptionItem(
			"external:skills-sh-alpha", "alpha", "skills/alpha", "v1.0.0",
			adoptionTargetJSON{Agent: "claude-code", Scope: "global", Path: scenarioContainerPath(t, "home", ".claude", "skills", "alpha")},
			adoptionTargetJSON{Agent: "codex", Scope: "global", Path: scenarioContainerPath(t, "home", ".codex", "skills", "alpha")},
			adoptionTargetJSON{Agent: "zed", Scope: "global", Path: scenarioContainerPath(t, "home", ".agents", "skills", "alpha")},
		)},
	})
	require.Len(t, report.Results, 1)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	for _, projection := range []string{
		filepath.Join(home, ".claude", "skills", "alpha", "SKILL.md"),
		filepath.Join(home, ".codex", "skills", "alpha", "SKILL.md"),
		filepath.Join(home, ".agents", "skills", "alpha", "SKILL.md"),
	} {
		contents, err := os.ReadFile(projection)
		require.NoError(t, err)
		require.Equal(t, skillBytes, contents)
		info, err := os.Lstat(filepath.Dir(projection))
		require.NoError(t, err)
		require.NotZero(t, info.Mode()&os.ModeSymlink)
	}
	require.FileExists(t, filepath.Join(home, ".agents", "skills.yaml"))
	require.FileExists(t, filepath.Join(home, ".agents", "skills-lock.yaml"))
	require.FileExists(t, filepath.Join(home, ".agents", ".skillsgo", "packages", "fixtures.test", "group", "subgroup", "collection@v1.0.0", "skills", "alpha", "SKILL.md"))

	inventory := execCLI(t, ctx, container, "list", "--global", "--output", "json")
	require.Equal(t, 0, inventory.exitCode, inventory.output)
	require.Contains(t, inventory.output, `"inventoryKey":"hub:fixtures.test/group/subgroup/collection:alpha"`)
	require.NotContains(t, inventory.output, `"inventoryKey":"external:`)
}
