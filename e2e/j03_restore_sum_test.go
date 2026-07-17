/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J03 clean-machine Sum restoration.
 * [POS]: Serves as one executable user-journey contract in the cross-product E2E workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package e2e_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestJ03RestoreSum(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@main",
		"--agent", "codex",
		"--copy",
		"--yes",
		"--confirm-risk",
		"--allow-critical",
		"--output", "json",
	)
	require.Equal(t, 0, add.exitCode, add.output)

	var installed addResponse
	require.NoError(t, json.Unmarshal([]byte(add.output), &installed), add.output)
	require.NotEmpty(t, installed.Version)

	sumPath := filepath.Join(sandboxRoot, "project", "skillsgo.sum")
	sumBefore, err := os.ReadFile(sumPath)
	require.NoError(t, err)

	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "home", ".skillsgo", "store")))
	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "project", ".agents")))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "home", ".skillsgo", "store"))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents"))

	restore := execCLI(t, ctx, container, "install", "--output", "json")
	require.Equal(t, 0, restore.exitCode, restore.output)

	var restored []struct {
		Name    string `json:"name"`
		Version string `json:"version"`
		Targets int    `json:"targets"`
	}
	require.NoError(t, json.Unmarshal([]byte(restore.output), &restored), restore.output)
	require.Equal(t, []struct {
		Name    string `json:"name"`
		Version string `json:"version"`
		Targets int    `json:"targets"`
	}{{Name: "ask-matt", Version: installed.Version, Targets: 1}}, restored)

	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt", "SKILL.md"))
	require.FileExists(t, containerPathOnHost(t, sandboxRoot, installed.Store, "artifact", "SKILL.md"))
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, sumBefore, sumAfter, "checksum-backed restoration must not rewrite skillsgo.sum")

	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "project", ".agents")))
	nested := filepath.Join(sandboxRoot, "project", "packages", "demo")
	require.NoError(t, os.MkdirAll(nested, 0o755))
	nestedRestore := execCLIFrom(t, ctx, container, "/e2e/project/packages/demo", "install", "--output", "json")
	require.Equal(t, 0, nestedRestore.exitCode, nestedRestore.output)
	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "ask-matt", "SKILL.md"))
	require.NoFileExists(t, filepath.Join(nested, "skillsgo.yaml"))
}
