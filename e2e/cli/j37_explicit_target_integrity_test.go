/*
 * [INPUT]: Depends on a disposable E2E environment, the App-facing explicit-target CLI contract, deterministic Repository fixtures, and offline Workspace restoration.
 * [OUTPUT]: Provides black-box coverage that explicit target installation persists complete Skill and Repository integrity before offline recovery.
 * [POS]: Serves as the App-driven installation integrity user journey in the cross-product E2E workspace.
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

func TestJ37ExplicitTargetIntegrity(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)
	repositoryID := "fixtures.test/group/subgroup/collection"
	skillID := repositoryID + "/-/skills/alpha"
	version := "v1.0.0"
	target := `{"scope":"project","projectRoot":"/e2e/project","agent":"codex","mode":"copy"}`

	add := execCLI(t, ctx, container,
		"add", skillID,
		"--skill", "alpha",
		"--target", target,
		"--version", version,
		"--yes",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	manifestBytes, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.mod"))
	require.NoError(t, err)
	require.Contains(t, string(manifestBytes), skillID+" "+version+" [codex]")
	sumBytes, err := os.ReadFile(filepath.Join(sandboxRoot, "project", "skillsgo.sum"))
	require.NoError(t, err)
	require.Contains(t, string(sumBytes), repositoryID+" "+version+"/repository.info h1:")
	require.Contains(t, string(sumBytes), skillID+" "+version+" h1:")

	targetRoot := filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha")
	require.FileExists(t, filepath.Join(targetRoot, "SKILL.md"))
	require.NoError(t, os.RemoveAll(targetRoot))
	restore := execCLI(t, ctx, container,
		"install",
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 0, restore.exitCode, restore.output)
	require.FileExists(t, filepath.Join(targetRoot, "SKILL.md"))
}
