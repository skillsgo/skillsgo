/*
 * [INPUT]: Depends on the released CLI, a user-owned Project clone, a skills.sh-style canonical symlink plus chained Agent symlink, and the fixture Hub Package.
 * [OUTPUT]: Verifies Project adoption removes only discovery links, preserves the clone, and creates ordinary Project manifest, lock, store, and projections.
 * [POS]: Serves as the user-clone and Project-symlink adoption journey in the cross-product E2E workspace.
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

func TestJ41AdoptProjectSymlinksWithoutDeletingUserClone(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	project := filepath.Join(sandboxRoot, "project")
	clone := filepath.Join(project, "codes", "collection")
	cloned := execInContainer(t, ctx, container, "git", "clone", "/e2e/git/group/subgroup/collection", scenarioContainerPath(t, "project", "codes", "collection"))
	require.Equal(t, 0, cloned.exitCode, cloned.output)
	checkedOut := execInContainer(t, ctx, container, "git", "-C", scenarioContainerPath(t, "project", "codes", "collection"), "checkout", "v1.0.0")
	require.Equal(t, 0, checkedOut.exitCode, checkedOut.output)
	cloneSkill := filepath.Join(clone, "skills", "alpha")
	original, err := os.ReadFile(filepath.Join(cloneSkill, "SKILL.md"))
	require.NoError(t, err)

	canonical := filepath.Join(project, ".agents", "skills", "alpha")
	claude := filepath.Join(project, ".claude", "skills", "alpha")
	require.NoError(t, os.MkdirAll(filepath.Dir(canonical), 0o755))
	require.NoError(t, os.MkdirAll(filepath.Dir(claude), 0o755))
	require.NoError(t, os.Symlink(filepath.Join("..", "..", "codes", "collection", "skills", "alpha"), canonical))
	require.NoError(t, os.Symlink(filepath.Join("..", "..", ".agents", "skills", "alpha"), claude))

	projectContainerPath := scenarioContainerPath(t, "project")
	report := executeAdoption(t, ctx, container, sandboxRoot, adoptionRequestJSON{
		SchemaVersion: 1,
		Items: []adoptionItemJSON{fixtureAdoptionItem(
			"external:clone-alpha", "alpha", "skills/alpha", "v1.0.0",
			adoptionTargetJSON{Agent: "claude-code", Scope: "project", ProjectRoot: projectContainerPath, Path: scenarioContainerPath(t, "project", ".claude", "skills", "alpha")},
			adoptionTargetJSON{Agent: "zed", Scope: "project", ProjectRoot: projectContainerPath, Path: scenarioContainerPath(t, "project", ".agents", "skills", "alpha")},
		)},
	})
	require.Len(t, report.Results, 1)
	require.Equal(t, "adopted", report.Results[0].Status, report.Results[0].Reason)
	after, err := os.ReadFile(filepath.Join(cloneSkill, "SKILL.md"))
	require.NoError(t, err)
	require.Equal(t, original, after, "adoption must retire links without mutating a user-owned clone")
	require.DirExists(t, filepath.Join(clone, ".git"))

	require.FileExists(t, filepath.Join(project, ".claude", "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(project, ".agents", "skills", "alpha", "SKILL.md"))
	for _, projection := range []string{canonical, claude} {
		info, statErr := os.Lstat(projection)
		require.NoError(t, statErr)
		require.NotZero(t, info.Mode()&os.ModeSymlink)
	}
	require.FileExists(t, filepath.Join(project, ".skillsgo", "packages", "fixtures.test", "group", "subgroup", "collection@v1.0.0", "skills", "alpha", "SKILL.md"))
	require.FileExists(t, filepath.Join(project, "skills.yaml"))
	require.FileExists(t, filepath.Join(project, "skills-lock.yaml"))
}
