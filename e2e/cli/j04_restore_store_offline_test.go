/*
 * [INPUT]: Depends on the disposable E2E environment and public CLI, Hub, JSON, and filesystem contracts.
 * [OUTPUT]: Provides black-box coverage for J04 Store-backed offline restoration.
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

func TestJ04RestoreStoreOffline(t *testing.T) {
	ctx := context.Background()
	container, sandboxRoot := startEnvironment(t, ctx)

	add := execCLI(t, ctx, container,
		"add", testSkillID+"@"+testSkillVersion,
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
	storeArtifact := storeArtifactPath(t, sandboxRoot, installed.Store, "SKILL.md")
	require.FileExists(t, storeArtifact)

	require.NoError(t, os.RemoveAll(filepath.Join(sandboxRoot, "project", ".agents")))
	require.NoDirExists(t, filepath.Join(sandboxRoot, "project", ".agents"))

	restore := execCLI(t, ctx, container,
		"install",
		"--hub", "http://127.0.0.1:1",
		"--output", "json",
	)
	require.Equal(t, 0, restore.exitCode, restore.output)

	var restored []struct {
		Name    string `json:"name"`
		Version string `json:"version"`
		Targets int    `json:"targets"`
	}
	require.NoError(t, json.Unmarshal([]byte(restore.output), &restored), restore.output)
	require.Len(t, restored, 1)
	require.Equal(t, "alpha", restored[0].Name)
	require.Equal(t, installed.Version, restored[0].Version)
	require.Equal(t, 1, restored[0].Targets)

	require.FileExists(t, filepath.Join(sandboxRoot, "project", ".agents", "skills", "alpha", "SKILL.md"))
	require.FileExists(t, storeArtifact)
	sumAfter, err := os.ReadFile(sumPath)
	require.NoError(t, err)
	require.Equal(t, sumBefore, sumAfter, "offline Store recovery must not rewrite skillsgo.sum")
}
